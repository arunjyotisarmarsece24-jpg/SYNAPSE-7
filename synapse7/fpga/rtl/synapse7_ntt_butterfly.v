// ============================================================================
// Module Name:  synapse7_ntt_butterfly
// Project:      SYNAPSE-7 Post-Quantum Hardware Accelerator
// Target:       AMD-Xilinx Spartan-7 (Digilent Arty S7-50 / XC7S50-CSGA324)
// Description:  Constant-time Cooley-Tukey Radix-2 NTT Butterfly Processing Unit
//               Computes U_out = (U + V*W) mod q and V_out = (U - V*W) mod q
//               Optimized for DSP48E1 slice utilization with q = 12289 (14-bit)
// ============================================================================

`timescale 1ns / 1ps

module synapse7_ntt_butterfly #(
    parameter DATA_WIDTH = 14,
    parameter MODULUS    = 14'd12289  // 0x3001
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   enable,
    input  wire [DATA_WIDTH-1:0]  u_in,
    input  wire [DATA_WIDTH-1:0]  v_in,
    input  wire [DATA_WIDTH-1:0]  w_in,   // Twiddle factor
    output reg  [DATA_WIDTH-1:0]  u_out,
    output reg  [DATA_WIDTH-1:0]  v_out,
    output reg                    valid_out
);

    // Stage 1: Multiplication v_in * w_in (DSP48E1 input: 14x14 -> 28 bits)
    reg [27:0] mult_reg;
    reg [DATA_WIDTH-1:0] u_pipe;
    reg enable_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_reg    <= 28'd0;
            u_pipe      <= {DATA_WIDTH{1'b0}};
            enable_pipe <= 1'b0;
        end else if (enable) begin
            mult_reg    <= v_in * w_in;
            u_pipe      <= u_in;
            enable_pipe <= 1'b1;
        end else begin
            enable_pipe <= 1'b0;
        end
    end

    // Stage 2: Barrett / Modulo reduction of product: V_W_mod = mult_reg % MODULUS
    // For q = 12289, direct modulo or hardware divider
    wire [DATA_WIDTH-1:0] vw_mod = mult_reg % MODULUS;

    // Stage 3: Addition and Subtraction modulo q
    wire [DATA_WIDTH:0] sum_raw = u_pipe + vw_mod;
    wire [DATA_WIDTH:0] sub_raw = (u_pipe >= vw_mod) ? 
                                  (u_pipe - vw_mod) : 
                                  (u_pipe + MODULUS - vw_mod);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_out     <= {DATA_WIDTH{1'b0}};
            v_out     <= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (enable_pipe) begin
            u_out     <= (sum_raw >= MODULUS) ? (sum_raw - MODULUS) : sum_raw[DATA_WIDTH-1:0];
            v_out     <= sub_raw[DATA_WIDTH-1:0];
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
