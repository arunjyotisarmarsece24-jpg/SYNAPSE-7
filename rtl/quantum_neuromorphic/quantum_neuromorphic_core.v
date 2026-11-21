// ============================================================================
// Module Name: quantum_neuromorphic_core
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 / Cadence ASIC Flow
// Description: Top-Level 8-Qubit Quantum Neuromorphic Processing Engine.
//              Integrates 8x Quantum Spiking Neurons (Q-LIF) with Multi-Qubit
//              Synaptic Entanglement Crossbar, Born-Rule Measurement Collapsers,
//              and Real-Time Quantum Telemetry Metric Analyzers.
// ============================================================================

`timescale 1ns / 1ps

module quantum_neuromorphic_core #(
    parameter NUM_NEURONS   = 8,
    parameter DATA_WIDTH    = 16,
    parameter WEIGHT_WIDTH  = 8
)(
    input  wire                                     clk,
    input  wire                                     rst_n,
    input  wire                                     enable,          // Timestep tick enable
    input  wire                                     quantum_en,      // Master quantum accelerator enable
    input  wire [NUM_NEURONS-1:0]                   input_spikes,    // Input spike vector
    input  wire                                     entanglement_en, // Multi-qubit entanglement enable
    input  wire                                     stochastic_mode, // TRNG Born stochastic collapse
    input  wire [7:0]                               entropy_byte,    // From RO-TRNG
    input  wire [15:0]                              p_th_tune,       // Tunable collapse threshold
    
    // Quantum Telemetry & Spike Outputs
    output wire [NUM_NEURONS-1:0]                   quantum_spikes,  // Firing events from Born collapse
    output wire [DATA_WIDTH-1:0]                    prob_one_sample, // Born probability P(|1>) of Q-Neuron 0
    output wire signed [DATA_WIDTH-1:0]             bloch_z_sample,  // Expectation <sigma_z> of Q-Neuron 0
    output wire signed [DATA_WIDTH-1:0]             coherence_avg,   // Mean superposition coherence across array
    output reg  [31:0]                              total_qspikes_cnt,// Cumulative Q-Spike performance counter
    output wire [DATA_WIDTH*NUM_NEURONS-1:0]        all_prob_one_flat
);

    // ------------------------------------------------------------------------
    // Interconnect Buses
    // ------------------------------------------------------------------------
    wire signed [DATA_WIDTH*NUM_NEURONS-1:0] syn_current_flat;
    wire signed [DATA_WIDTH*NUM_NEURONS-1:0] detuning_delta_flat;
    wire signed [DATA_WIDTH*NUM_NEURONS-1:0] bloch_z_flat;
    wire signed [DATA_WIDTH*NUM_NEURONS-1:0] coherence_flat;
    wire [NUM_NEURONS-1:0]                   raw_q_spikes;

    assign quantum_spikes = quantum_en ? raw_q_spikes : {NUM_NEURONS{1'b0}};

    // ------------------------------------------------------------------------
    // Quantum Synaptic Entanglement & Interference Interconnect
    // ------------------------------------------------------------------------
    quantum_synapse_entangler #(
        .NUM_INPUTS(NUM_NEURONS),
        .NUM_NEURONS(NUM_NEURONS),
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH)
    ) u_quantum_mesh (
        .clk(clk),
        .rst_n(rst_n),
        .timestep_tick(enable),
        .input_spikes(input_spikes),
        .entanglement_en(entanglement_en),
        .coupling_strength_J(16'sd400), // Entanglement coupling J
        .bloch_z_flat(bloch_z_flat),
        .param_wr_en(1'b0),
        .param_addr(6'd0),
        .param_weight(8'sd0),
        .param_phase(8'd0),
        .syn_current_flat(syn_current_flat),
        .detuning_delta_flat(detuning_delta_flat)
    );

    // ------------------------------------------------------------------------
    // Parallel Array of 8 Quantum Spiking Neurons (Q-LIF)
    // ------------------------------------------------------------------------
    genvar qn;
    generate
        for (qn = 0; qn < NUM_NEURONS; qn = qn + 1) begin : gen_quantum_neurons
            wire signed [DATA_WIDTH-1:0] syn_curr = syn_current_flat[qn*DATA_WIDTH +: DATA_WIDTH];
            wire signed [DATA_WIDTH-1:0] delta    = detuning_delta_flat[qn*DATA_WIDTH +: DATA_WIDTH];
            wire                         single_q_spike;
            wire [DATA_WIDTH-1:0]        single_prob_one;
            wire signed [DATA_WIDTH-1:0] single_bloch_z;
            wire signed [DATA_WIDTH-1:0] single_coherence;

            // Pseudo-decorrelate entropy bytes per neuron
            wire [7:0] local_noise = entropy_byte ^ (qn * 8'h37);

            quantum_spiking_neuron #(
                .DATA_WIDTH(DATA_WIDTH),
                .DECAY_T1_SHIFT(5),
                .DECAY_T2_SHIFT(4),
                .P_TH_DEFAULT(16'd8192),
                .REFRAC_CYCLES(4)
            ) u_qneuron (
                .clk(clk),
                .rst_n(rst_n),
                .enable(enable & quantum_en),
                .syn_current(syn_curr),
                .detuning_delta(delta),
                .entropy_noise(local_noise),
                .stochastic_mode(stochastic_mode),
                .p_th_tune(p_th_tune),
                .q_spike_out(single_q_spike),
                .prob_one_out(single_prob_one),
                .bloch_z_out(single_bloch_z),
                .coherence_out(single_coherence)
            );

            assign raw_q_spikes[qn] = single_q_spike;
            assign bloch_z_flat[qn*DATA_WIDTH +: DATA_WIDTH] = single_bloch_z;
            assign coherence_flat[qn*DATA_WIDTH +: DATA_WIDTH] = single_coherence;
            assign all_prob_one_flat[qn*DATA_WIDTH +: DATA_WIDTH] = single_prob_one;
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Performance Counter & Telemetry Aggregators
    // ------------------------------------------------------------------------
    assign prob_one_sample = all_prob_one_flat[15:0]; // Q-Neuron 0 live Born probability
    assign bloch_z_sample  = bloch_z_flat[15:0];      // Q-Neuron 0 Bloch Z projection

    // Sum and average coherence across all 8 neurons (Q1.14 fixed point)
    wire signed [31:0] sum_coherence = 
        coherence_flat[0*DATA_WIDTH +: DATA_WIDTH] +
        coherence_flat[1*DATA_WIDTH +: DATA_WIDTH] +
        coherence_flat[2*DATA_WIDTH +: DATA_WIDTH] +
        coherence_flat[3*DATA_WIDTH +: DATA_WIDTH] +
        coherence_flat[4*DATA_WIDTH +: DATA_WIDTH] +
        coherence_flat[5*DATA_WIDTH +: DATA_WIDTH] +
        coherence_flat[6*DATA_WIDTH +: DATA_WIDTH] +
        coherence_flat[7*DATA_WIDTH +: DATA_WIDTH];

    assign coherence_avg = sum_coherence[18:3]; // Divide by 8

    // Hardware Q-Spike Event Counter
    integer i;
    reg [3:0] spike_popcnt;
    always @(*) begin
        spike_popcnt = 4'd0;
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin
            if (raw_q_spikes[i]) spike_popcnt = spike_popcnt + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_qspikes_cnt <= 32'd0;
        end else if (quantum_en) begin
            total_qspikes_cnt <= total_qspikes_cnt + spike_popcnt;
        end
    end

endmodule
