// ============================================================================
// Module Name: uart_rx
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: UART Receiver Core with 16x midpoint oversampling.
// ============================================================================

`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam STATE_IDLE  = 3'd0;
    localparam STATE_START = 3'd1;
    localparam STATE_DATA  = 3'd2;
    localparam STATE_STOP  = 3'd3;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shifter;
    
    // Double-flop synchronizer
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx_in;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= STATE_IDLE;
            clk_cnt    <= 16'd0;
            bit_idx    <= 3'd0;
            rx_shifter <= 8'd0;
            rx_data    <= 8'd0;
            rx_valid   <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (state)
                STATE_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_sync2 == 1'b0) begin // Falling edge detection of start bit
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    // Sample at the middle of the start bit
                    if (clk_cnt == (CLKS_PER_BIT / 2)) begin
                        if (rx_sync2 == 1'b0) begin
                            clk_cnt <= 16'd0;
                            state   <= STATE_DATA;
                        end else begin
                            state <= STATE_IDLE; // Glitch reject
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STATE_DATA: begin
                    if (clk_cnt < (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        rx_shifter[bit_idx] <= rx_sync2;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1'b1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    if (clk_cnt < (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt  <= 16'd0;
                        state    <= STATE_IDLE;
                        rx_data  <= rx_shifter;
                        rx_valid <= 1'b1;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
