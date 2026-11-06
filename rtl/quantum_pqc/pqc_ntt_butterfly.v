// ============================================================================
// Module Name: pqc_ntt_butterfly
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Cooley-Tukey Number Theoretic Transform (NTT) Butterfly Core
//              Standardized for NIST FIPS 203 Post-Quantum Cryptography (ML-KEM)
//              Polynomial Ring: Z_3329[X]/(X^256 + 1)
// ============================================================================

`timescale 1ns / 1ps

module pqc_ntt_butterfly #(
    parameter Q = 3329
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   start,
    input  wire signed [15:0]     u_in,
    input  wire signed [15:0]     v_in,
    input  wire signed [15:0]     zeta_twiddle, // Twiddle factor omega^k
    output reg  signed [15:0]     u_out,
    output reg  signed [15:0]     v_out,
    output reg                    valid_out,
    output reg  [31:0]            butterfly_cycles_cnt // Live hardware performance counter
);

    // Register inputs to ensure clean pipeline timing
    reg signed [15:0] u_pipe1, u_pipe2;
    always @(posedge clk) begin
        u_pipe1 <= u_in;
        u_pipe2 <= u_pipe1;
    end

    // Montgomery product: v_mult = (v_in * zeta_twiddle) mod 3329
    wire signed [15:0] v_mult;
    wire mult_done;

    montgomery_reducer #(
        .Q(Q)
    ) u_mont_mul (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a(v_in),
        .b(zeta_twiddle),
        .res(v_mult),
        .done(mult_done)
    );

    // Butterfly stage: u' = u + v_mult, v' = u - v_mult
    wire signed [16:0] sum  = $signed(u_pipe2) + $signed(v_mult);
    wire signed [16:0] diff = $signed(u_pipe2) - $signed(v_mult);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_out                <= 16'd0;
            v_out                <= 16'd0;
            valid_out            <= 1'b0;
            butterfly_cycles_cnt <= 32'd0;
        end else begin
            valid_out <= mult_done;
            if (mult_done) begin
                butterfly_cycles_cnt <= butterfly_cycles_cnt + 1'b1;
                
                // Fast modular bounds clamping to [0, Q-1]
                if (sum >= $signed(Q))
                    u_out <= sum - $signed(Q);
                else if (sum < 0)
                    u_out <= sum + $signed(Q);
                else
                    u_out <= sum[15:0];

                if (diff < 0)
                    v_out <= diff + $signed(Q);
                else if (diff >= $signed(Q))
                    v_out <= diff - $signed(Q);
                else
                    v_out <= diff[15:0];
            end
        end
    end

endmodule
