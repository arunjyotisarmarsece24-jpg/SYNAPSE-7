// ============================================================================
// Module Name: lif_neuron
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Synthesizable Leaky Integrate-and-Fire (LIF) Neuromorphic Unit
//              with programmable exponential leakage, threshold detection,
//              and hardware refractory state machine.
// ============================================================================

`timescale 1ns / 1ps

module lif_neuron #(
    parameter DATA_WIDTH       = 16,
    parameter DECAY_SHIFT      = 3,        // Membrane leak fraction = 1 / (2^DECAY_SHIFT)
    parameter V_TH_DEFAULT     = 16'sd1024,// Firing threshold
    parameter V_RESET_DEFAULT  = 16'sd0,   // Post-spike reset level
    parameter REFRAC_CYCLES    = 4         // Inactivity cycles after firing
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   enable,      // Global timestep clock enable
    input  wire signed [DATA_WIDTH-1:0] syn_current, // Weighted input current from synaptic mesh
    input  wire signed [DATA_WIDTH-1:0] v_th_in,     // Dynamically tunable threshold
    output reg                    spike_out,   // Event-driven firing output
    output wire signed [DATA_WIDTH-1:0] v_mem_out   // Live membrane potential for telemetry
);

    reg signed [DATA_WIDTH-1:0] v_mem;
    reg [3:0]                   refrac_cnt;

    assign v_mem_out = v_mem;

    wire signed [DATA_WIDTH-1:0] active_v_th = (v_th_in == 0) ? V_TH_DEFAULT : v_th_in;

    // Fixed-point leaky decay calculation
    wire signed [DATA_WIDTH-1:0] v_leak = v_mem >>> DECAY_SHIFT;
    wire signed [DATA_WIDTH-1:0] v_decayed = v_mem - v_leak;
    wire signed [DATA_WIDTH-1:0] v_next = v_decayed + syn_current;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_mem       <= V_RESET_DEFAULT;
            spike_out   <= 1'b0;
            refrac_cnt  <= 4'd0;
        end else if (enable) begin
            if (refrac_cnt > 0) begin
                // In refractory period: clamp membrane potential and decrement timer
                v_mem       <= V_RESET_DEFAULT;
                spike_out   <= 1'b0;
                refrac_cnt  <= refrac_cnt - 1'b1;
            end else begin
                if (v_next >= active_v_th) begin
                    // Membrane exceeds threshold: FIRE ACTION POTENTIAL
                    spike_out   <= 1'b1;
                    v_mem       <= V_RESET_DEFAULT;
                    refrac_cnt  <= REFRAC_CYCLES[3:0];
                end else begin
                    // Sub-threshold integration with lower bound saturation
                    spike_out   <= 1'b0;
                    if (v_next < -16'sd16384)
                        v_mem <= -16'sd16384; // Prevent underflow saturation
                    else
                        v_mem <= v_next;
                end
            end
        end else begin
            spike_out <= 1'b0;
        end
    end

endmodule
