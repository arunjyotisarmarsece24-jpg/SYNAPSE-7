// ============================================================================
// Module Name:  synapse7_lif_neuron_array
// Project:      SYNAPSE-7 Neuromorphic Subsystem
// Target:       AMD-Xilinx Spartan-7 (Digilent Arty S7-50 / XC7S50-CSGA324)
// Description:  Synthesizable Array of Fixed-Point Leaky Integrate-and-Fire (LIF)
//               Neurons with Shift-Based Exponential Leak and Hard Reset.
//               Format: Q4.12 Fixed-Point (16-bit signed, 12 fractional bits)
// ============================================================================

`timescale 1ns / 1ps

module synapse7_lif_neuron_array #(
    parameter NUM_NEURONS   = 16,
    parameter DATA_WIDTH    = 16,
    parameter LEAK_SHIFT    = 3,        // beta = 1 - 2^(-3) = 0.875
    parameter THRESHOLD_VAL = 16'h1000  // 1.0 in Q4.12 (0x1000)
)(
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire                             timestep_tick, // 1 ms simulation step
    
    // Synaptic Current inputs per neuron (Q4.12)
    input  wire [NUM_NEURONS*DATA_WIDTH-1:0] syn_current_bus,
    
    // Output Spike vector (1 bit per neuron)
    output reg  [NUM_NEURONS-1:0]           spike_out_bus,
    
    // Optional telemetry read port for single neuron monitoring
    input  wire [$clog2(NUM_NEURONS)-1:0]   mon_neuron_idx,
    output wire [DATA_WIDTH-1:0]            mon_voltage_out
);

    // Membrane potential registers
    reg signed [DATA_WIDTH-1:0] v_membrane [0:NUM_NEURONS-1];

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : lif_neuron_gen
            wire signed [DATA_WIDTH-1:0] i_syn = syn_current_bus[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
            wire signed [DATA_WIDTH-1:0] v_current = v_membrane[i];
            
            // Fixed-point leaky decay: V_leak = V - (V >>> LEAK_SHIFT)
            wire signed [DATA_WIDTH-1:0] v_decayed = v_current - (v_current >>> LEAK_SHIFT);
            
            // Integrated potential: V_next = V_decayed + I_syn
            wire signed [DATA_WIDTH-1:0] v_next = v_decayed + i_syn;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    v_membrane[i]    <= 16'sh0000;
                    spike_out_bus[i] <= 1'b0;
                end else if (timestep_tick) begin
                    if (v_next >= THRESHOLD_VAL) begin
                        spike_out_bus[i] <= 1'b1;        // Fire action potential
                        v_membrane[i]    <= 16'sh0000;    // Hard reset to 0.0
                    end else begin
                        spike_out_bus[i] <= 1'b0;
                        v_membrane[i]    <= (v_next < 16'sh0000) ? 16'sh0000 : v_next; // Clamp at rest
                    end
                end else begin
                    spike_out_bus[i] <= 1'b0;
                end
            end
        end
    endgenerate

    // Diagnostic oscilloscope read port
    assign mon_voltage_out = v_membrane[mon_neuron_idx];

endmodule
