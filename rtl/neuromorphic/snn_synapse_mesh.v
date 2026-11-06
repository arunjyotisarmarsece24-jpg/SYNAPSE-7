// ============================================================================
// Module Name: snn_synapse_mesh
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Multi-Neuron Synaptic Interconnect Layer with configurable 
//              weight crossbar and real-time membrane potential readout.
// ============================================================================

`timescale 1ns / 1ps

module snn_synapse_mesh #(
    parameter NUM_INPUTS    = 8,
    parameter NUM_NEURONS   = 8,
    parameter DATA_WIDTH    = 16,
    parameter WEIGHT_WIDTH  = 8
)(
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire                             timestep_tick,
    input  wire [NUM_INPUTS-1:0]            input_spikes,
    input  wire signed [DATA_WIDTH-1:0]     v_th_tune,
    // Weight update interface for runtime on-chip learning / reconfiguration
    input  wire                             weight_wr_en,
    input  wire [$clog2(NUM_INPUTS*NUM_NEURONS)-1:0] weight_addr,
    input  wire signed [WEIGHT_WIDTH-1:0]   weight_data,
    
    // Telemetry and Spike outputs
    output wire [NUM_NEURONS-1:0]           neuron_spikes,
    output wire signed [DATA_WIDTH*NUM_NEURONS-1:0] all_v_mem_flat
);

    // Synaptic Weight Matrix Memory: NUM_INPUTS x NUM_NEURONS
    reg signed [WEIGHT_WIDTH-1:0] weight_matrix [0:(NUM_INPUTS*NUM_NEURONS)-1];
    
    // Initialize default weights: Pre-configured threat detection filters
    integer init_i;
    initial begin
        for (init_i = 0; init_i < NUM_INPUTS*NUM_NEURONS; init_i = init_i + 1) begin
            // Structured diagonal excitation with lateral inhibition pattern
            if ((init_i % NUM_NEURONS) == (init_i / NUM_NEURONS))
                weight_matrix[init_i] = 8'sd65;   // Strong positive synaptic weight
            else if (((init_i % NUM_NEURONS) + 1) % NUM_NEURONS == (init_i / NUM_NEURONS))
                weight_matrix[init_i] = -8'sd25;  // Lateral inhibitory weight
            else
                weight_matrix[init_i] = 8'sd10;
        end
    end

    // Weight write port for live reconfiguration over UART
    always @(posedge clk) begin
        if (weight_wr_en) begin
            weight_matrix[weight_addr] <= weight_data;
        end
    end

    // Compute synaptic currents for each neuron
    reg signed [DATA_WIDTH-1:0] syn_current_accum [0:NUM_NEURONS-1];
    integer n_idx, in_idx;

    always @(*) begin
        for (n_idx = 0; n_idx < NUM_NEURONS; n_idx = n_idx + 1) begin
            syn_current_accum[n_idx] = {DATA_WIDTH{1'b0}};
            for (in_idx = 0; in_idx < NUM_INPUTS; in_idx = in_idx + 1) begin
                if (input_spikes[in_idx]) begin
                    syn_current_accum[n_idx] = syn_current_accum[n_idx] + 
                        {{(DATA_WIDTH-WEIGHT_WIDTH){weight_matrix[in_idx * NUM_NEURONS + n_idx][WEIGHT_WIDTH-1]}}, 
                         weight_matrix[in_idx * NUM_NEURONS + n_idx]};
                end
            end
        end
    end

    // Instantiate Parallel LIF Neurons
    genvar g;
    generate
        for (g = 0; g < NUM_NEURONS; g = g + 1) begin : gen_lif_neurons
            wire signed [DATA_WIDTH-1:0] single_v_mem;
            wire single_spike;

            lif_neuron #(
                .DATA_WIDTH(DATA_WIDTH),
                .DECAY_SHIFT(3),
                .V_TH_DEFAULT(16'sd120),
                .V_RESET_DEFAULT(16'sd0),
                .REFRAC_CYCLES(3)
            ) u_neuron (
                .clk(clk),
                .rst_n(rst_n),
                .enable(timestep_tick),
                .syn_current(syn_current_accum[g]),
                .v_th_in(v_th_tune),
                .spike_out(single_spike),
                .v_mem_out(single_v_mem)
            );

            assign neuron_spikes[g] = single_spike;
            assign all_v_mem_flat[g*DATA_WIDTH +: DATA_WIDTH] = single_v_mem;
        end
    endgenerate

endmodule
