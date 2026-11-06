// ============================================================================
// Module Name: ro_trng_entropy
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Physical Silicon Entropy Source (TRNG / PUF) utilizing
//              multi-ring oscillator phase jitter and Von Neumann whitening.
//              Provides high-entropy seeds for Post-Quantum Ephemeral Keys.
// ============================================================================

`timescale 1ns / 1ps

module ro_trng_entropy (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_enable,
    output reg  [7:0]  random_byte_out,
    output reg         random_valid,
    output wire [3:0]  ro_raw_taps     // Telemetry monitor taps
);

    // ------------------------------------------------------------------------
    // Ring Oscillator 0 (3-stage ring)
    // ------------------------------------------------------------------------
    (* DONT_TOUCH = "TRUE", ALLOW_COMBINATORIAL_LOOPS = "TRUE" *)
    wire ro0_n1, ro0_n2, ro0_n3;
    assign ro0_n1 = ~ro0_n3;
    assign ro0_n2 = ~ro0_n1;
    assign ro0_n3 = ~ro0_n2;

    // ------------------------------------------------------------------------
    // Ring Oscillator 1 (5-stage ring)
    // ------------------------------------------------------------------------
    (* DONT_TOUCH = "TRUE", ALLOW_COMBINATORIAL_LOOPS = "TRUE" *)
    wire ro1_n1, ro1_n2, ro1_n3, ro1_n4, ro1_n5;
    assign ro1_n1 = ~ro1_n5;
    assign ro1_n2 = ~ro1_n1;
    assign ro1_n3 = ~ro1_n2;
    assign ro1_n4 = ~ro1_n3;
    assign ro1_n5 = ~ro1_n4;

    // ------------------------------------------------------------------------
    // Ring Oscillator 2 (7-stage ring)
    // ------------------------------------------------------------------------
    (* DONT_TOUCH = "TRUE", ALLOW_COMBINATORIAL_LOOPS = "TRUE" *)
    wire ro2_n1, ro2_n2, ro2_n3, ro2_n4, ro2_n5, ro2_n6, ro2_n7;
    assign ro2_n1 = ~ro2_n7;
    assign ro2_n2 = ~ro2_n1;
    assign ro2_n3 = ~ro2_n2;
    assign ro2_n4 = ~ro2_n3;
    assign ro2_n5 = ~ro2_n4;
    assign ro2_n6 = ~ro2_n5;
    assign ro2_n7 = ~ro2_n6;

    // ------------------------------------------------------------------------
    // Ring Oscillator 3 (9-stage ring)
    // ------------------------------------------------------------------------
    (* DONT_TOUCH = "TRUE", ALLOW_COMBINATORIAL_LOOPS = "TRUE" *)
    wire ro3_n1, ro3_n2, ro3_n3, ro3_n4, ro3_n5, ro3_n6, ro3_n7, ro3_n8, ro3_n9;
    assign ro3_n1 = ~ro3_n9;
    assign ro3_n2 = ~ro3_n1;
    assign ro3_n3 = ~ro3_n2;
    assign ro3_n4 = ~ro3_n3;
    assign ro3_n5 = ~ro3_n4;
    assign ro3_n6 = ~ro3_n5;
    assign ro3_n7 = ~ro3_n6;
    assign ro3_n8 = ~ro3_n7;
    assign ro3_n9 = ~ro3_n8;

    assign ro_raw_taps = {ro3_n1, ro2_n1, ro1_n1, ro0_n1};

    // Synchronizers to prevent metastability across clock domains
    (* ASYNC_REG = "TRUE" *) reg [3:0] ro_sync1, ro_sync2;
    always @(posedge clk) begin
        ro_sync1 <= {ro3_n1, ro2_n1, ro1_n1, ro0_n1};
        ro_sync2 <= ro_sync1;
    end

    wire raw_entropy_bit = ^ro_sync2; // Parity XOR of all 4 free-running RO phases

    // Von Neumann Whitener to eliminate systemic bias:
    // Takes bit pairs: (0, 1) -> 0; (1, 0) -> 1; (0, 0) and (1, 1) are discarded.
    reg vn_state;
    reg prev_bit;
    reg [2:0] bit_accum_cnt;
    reg [7:0] byte_shifter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vn_state        <= 1'b0;
            prev_bit        <= 1'b0;
            bit_accum_cnt   <= 3'd0;
            byte_shifter    <= 8'd0;
            random_byte_out <= 8'd0;
            random_valid    <= 1'b0;
        end else if (sample_enable) begin
            random_valid <= 1'b0;
            if (!vn_state) begin
                prev_bit <= raw_entropy_bit;
                vn_state <= 1'b1;
            end else begin
                vn_state <= 1'b0;
                if (prev_bit != raw_entropy_bit) begin
                    // Accepted unbiased random bit (prev_bit)
                    byte_shifter <= {byte_shifter[6:0], prev_bit};
                    if (bit_accum_cnt == 3'd7) begin
                        random_byte_out <= {byte_shifter[6:0], prev_bit};
                        random_valid    <= 1'b1;
                        bit_accum_cnt   <= 3'd0;
                    end else begin
                        bit_accum_cnt <= bit_accum_cnt + 1'b1;
                    end
                end
            end
        end else begin
            random_valid <= 1'b0;
        end
    end

endmodule
