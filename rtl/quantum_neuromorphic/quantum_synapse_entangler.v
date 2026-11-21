// ============================================================================
// Module Name: quantum_synapse_entangler
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 / Cadence ASIC Flow
// Description: Multi-Qubit Synaptic Interconnect with Quantum Phase Interference
//              and Inter-Neuron Entanglement Coupling (H_int = J * sigma_z_i * sigma_z_j).
//              Computes constructive/destructive quantum synaptic currents.
// ============================================================================

`timescale 1ns / 1ps

module quantum_synapse_entangler #(
    parameter NUM_INPUTS    = 8,
    parameter NUM_NEURONS   = 8,
    parameter DATA_WIDTH    = 16,
    parameter WEIGHT_WIDTH  = 8
)(
    input  wire                                     clk,
    input  wire                                     rst_n,
    input  wire                                     timestep_tick,
    input  wire [NUM_INPUTS-1:0]                    input_spikes,
    input  wire                                     entanglement_en,
    input  wire signed [DATA_WIDTH-1:0]             coupling_strength_J,
    
    // Feedback from neuron expectation values <sigma_z>
    input  wire signed [DATA_WIDTH*NUM_NEURONS-1:0] bloch_z_flat,
    
    // Synaptic parameters write port
    input  wire                                     param_wr_en,
    input  wire [$clog2(NUM_INPUTS*NUM_NEURONS)-1:0] param_addr,
    input  wire signed [WEIGHT_WIDTH-1:0]           param_weight,
    input  wire signed [7:0]                        param_phase,
    
    // Outputs driving quantum neurons
    output reg  signed [DATA_WIDTH*NUM_NEURONS-1:0] syn_current_flat,
    output reg  signed [DATA_WIDTH*NUM_NEURONS-1:0] detuning_delta_flat
);

    // Quantum Synaptic Weight Amplitude (W_ij) and Phase Angle (theta_ij)
    reg signed [WEIGHT_WIDTH-1:0] weight_amp  [0:(NUM_INPUTS*NUM_NEURONS)-1];
    reg signed [7:0]              weight_phase[0:(NUM_INPUTS*NUM_NEURONS)-1];

    // ROM Table for cos(theta): 8 discrete phase angles in [-pi, +pi]
    // Values scaled to Q1.7 (-128 to +127, where 127 ~= 1.0)
    function signed [7:0] phase_cos;
        input [2:0] p_idx;
        case (p_idx)
            3'd0: phase_cos = 8'sd127;  // cos(0)   = +1.0
            3'd1: phase_cos = 8'sd90;   // cos(pi/4) = +0.707
            3'd2: phase_cos = 8'sd0;    // cos(pi/2) =  0.0
            3'd3: phase_cos = -8'sd90;  // cos(3pi/4)= -0.707
            3'd4: phase_cos = -8'sd128; // cos(pi)   = -1.0
            3'd5: phase_cos = -8'sd90;  // cos(5pi/4)= -0.707
            3'd6: phase_cos = 8'sd0;    // cos(3pi/2)=  0.0
            3'd7: phase_cos = 8'sd90;   // cos(7pi/4)= +0.707
        endcase
    endfunction

    // Initialize quantum synaptic parameters with quantum interference patterns
    integer init_i;
    initial begin
        for (init_i = 0; init_i < NUM_INPUTS*NUM_NEURONS; init_i = init_i + 1) begin
            if ((init_i % NUM_NEURONS) == (init_i / NUM_NEURONS)) begin
                weight_amp[init_i]   = 8'sd80; // Resonant driving amplitude
                weight_phase[init_i] = 8'd0;   // Constructive in-phase (cos=1.0)
            end else if (((init_i % NUM_NEURONS) + 1) % NUM_NEURONS == (init_i / NUM_NEURONS)) begin
                weight_amp[init_i]   = 8'sd50;
                weight_phase[init_i] = 8'd4;   // Destructive anti-phase (cos=-1.0)
            end else begin
                weight_amp[init_i]   = 8'sd25;
                weight_phase[init_i] = init_i[2:0]; // Dispersed quantum phases
            end
        end
    end

    // Parameter write port
    always @(posedge clk) begin
        if (param_wr_en) begin
            weight_amp[param_addr]   <= param_weight;
            weight_phase[param_addr] <= param_phase;
        end
    end

    // Unpack bloch_z expectation values
    wire signed [DATA_WIDTH-1:0] bloch_z_arr [0:NUM_NEURONS-1];
    genvar bz_idx;
    generate
        for (bz_idx = 0; bz_idx < NUM_NEURONS; bz_idx = bz_idx + 1) begin : gen_bz_unpack
            assign bloch_z_arr[bz_idx] = bloch_z_flat[bz_idx*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // Compute Quantum Synaptic Currents (Constructive/Destructive Interference)
    // and Entanglement Detuning Shifts
    integer n, in_i, prev_n;
    reg signed [7:0]  cos_val;
    reg signed [15:0] eff_weight;
    reg signed [31:0] j_shift;
    reg signed [DATA_WIDTH-1:0] syn_accum [0:NUM_NEURONS-1];
    reg signed [DATA_WIDTH-1:0] delta_accum [0:NUM_NEURONS-1];

    always @(*) begin
        for (n = 0; n < NUM_NEURONS; n = n + 1) begin
            syn_accum[n] = {DATA_WIDTH{1'b0}};

            for (in_i = 0; in_i < NUM_INPUTS; in_i = in_i + 1) begin
                if (input_spikes[in_i]) begin
                    // Effective weight = W_ij * cos(theta_ij)
                    cos_val = phase_cos(weight_phase[in_i * NUM_NEURONS + n][2:0]);
                    eff_weight = (weight_amp[in_i * NUM_NEURONS + n] * cos_val) >>> 7;
                    syn_accum[n] = syn_accum[n] + eff_weight;
                end
            end

            // Entanglement Coupling: Detuning shift delta_n = Delta_bias + J * <sigma_z_(n-1)>
            if (entanglement_en) begin
                prev_n = (n == 0) ? (NUM_NEURONS - 1) : (n - 1);
                j_shift = (coupling_strength_J * bloch_z_arr[prev_n]) >>> 14;
                delta_accum[n] = 16'sd120 + j_shift[15:0];
            end else begin
                delta_accum[n] = 16'sd120; // Static baseline Larmor detuning
            end
        end
    end

    // Pack into flat output vectors
    integer out_n;
    always @(*) begin
        for (out_n = 0; out_n < NUM_NEURONS; out_n = out_n + 1) begin
            syn_current_flat[out_n*DATA_WIDTH +: DATA_WIDTH]    = syn_accum[out_n];
            detuning_delta_flat[out_n*DATA_WIDTH +: DATA_WIDTH] = delta_accum[out_n];
        end
    end

endmodule
