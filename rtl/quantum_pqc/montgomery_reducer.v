// ============================================================================
// Module Name: montgomery_reducer
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Constant-Time Modular Arithmetic Unit for NIST ML-KEM (Kyber)
//              Modulus q = 3329, R = 2^16.
//              Guarantees zero timing side-channel leakage for PQC acceleration.
// ============================================================================

`timescale 1ns / 1ps

module montgomery_reducer #(
    parameter Q       = 3329,
    parameter Q_INV   = 16'hF301  // -q^(-1) mod 2^16 = 62209
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,
    output reg  signed [15:0] res,
    output reg         done
);

    // Pipeline registers for 100MHz timing closure on Spartan-7
    reg signed [31:0] prod_stage1;
    reg               valid_stage1;

    // Stage 1: Full 16x16 signed DSP multiplication
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prod_stage1  <= 32'd0;
            valid_stage1 <= 1'b0;
        end else begin
            valid_stage1 <= start;
            if (start) begin
                prod_stage1 <= a * b;
            end
        end
    end

    // Stage 2: Montgomery Reduction
    // k = (prod * Q_INV) & 16'hFFFF;
    // t = (prod - k * Q) >>> 16;
    wire [15:0] k_val = (prod_stage1[15:0] * Q_INV);
    wire signed [31:0] k_times_q = $signed({{16{1'b0}}, k_val}) * $signed(Q);
    wire signed [31:0] diff = prod_stage1 - k_times_q;
    wire signed [15:0] t_reduced = diff[31:16];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            res  <= 16'd0;
            done <= 1'b0;
        end else begin
            done <= valid_stage1;
            if (valid_stage1) begin
                // Constant-time conditional correction without branching
                if (t_reduced < 0)
                    res <= t_reduced + $signed(Q);
                else
                    res <= t_reduced;
            end
        end
    end

endmodule
