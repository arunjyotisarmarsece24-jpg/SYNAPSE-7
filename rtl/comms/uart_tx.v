// ============================================================================
// Module Name: uart_tx
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Baud-programmable UART Transmitter Core for high-rate telemetry.
// ============================================================================

`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_busy,
    output reg        tx_out
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam STATE_IDLE  = 3'd0;
    localparam STATE_START = 3'd1;
    localparam STATE_DATA  = 3'd2;
    localparam STATE_STOP  = 3'd3;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_shifter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= STATE_IDLE;
            clk_cnt    <= 16'd0;
            bit_idx    <= 3'd0;
            tx_shifter <= 8'd0;
            tx_busy    <= 1'b0;
            tx_out     <= 1'b1;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx_out  <= 1'b1;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        tx_shifter <= tx_data;
                        tx_busy    <= 1'b1;
                        state      <= STATE_START;
                    end else begin
                        tx_busy    <= 1'b0;
                    end
                end

                STATE_START: begin
                    tx_out <= 1'b0; // Start bit
                    if (clk_cnt < (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    tx_out <= tx_shifter[bit_idx];
                    if (clk_cnt < (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1'b1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    tx_out <= 1'b1; // Stop bit
                    if (clk_cnt < (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= STATE_IDLE;
                        tx_busy <= 1'b0;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
