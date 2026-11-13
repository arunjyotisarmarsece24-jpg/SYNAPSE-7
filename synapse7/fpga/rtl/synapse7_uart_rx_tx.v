// ============================================================================
// Module Name:  synapse7_uart_rx_tx
// Project:      SYNAPSE-7 Post-Quantum Hardware Accelerator
// Target:       AMD-Xilinx Spartan-7 (Digilent Arty S7-50)
// Description:  Full-duplex UART Transceiver (115200 baud @ 100MHz sysclk)
//               Provides telemetry bridge between FPGA and ESP8266 WiFi SoC
// ============================================================================

`timescale 1ns / 1ps

module synapse7_uart_rx_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    
    // Physical UART lines
    input  wire       rx_pin,
    output reg        tx_pin,
    
    // Internal interface
    input  wire [7:0] tx_byte,
    input  wire       tx_start,
    output reg        tx_busy,
    
    output reg  [7:0] rx_byte,
    output reg        rx_ready
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // ~868 cycles

    // -------------------------------------------------------------------------
    // UART Transmitter FSM
    // -------------------------------------------------------------------------
    localparam TX_IDLE  = 2'b00;
    localparam TX_START = 2'b01;
    localparam TX_DATA  = 2'b10;
    localparam TX_STOP  = 2'b11;

    reg [1:0]  tx_state;
    reg [15:0] tx_clk_cnt;
    reg [2:0]  tx_bit_idx;
    reg [7:0]  tx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state   <= TX_IDLE;
            tx_pin     <= 1'b1;
            tx_busy    <= 1'b0;
            tx_clk_cnt <= 16'd0;
            tx_bit_idx <= 3'd0;
            tx_shift   <= 8'd0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_pin  <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_shift   <= tx_byte;
                        tx_busy    <= 1'b1;
                        tx_clk_cnt <= 16'd0;
                        tx_state   <= TX_START;
                    end
                end

                TX_START: begin
                    tx_pin <= 1'b0; // Start bit
                    if (tx_clk_cnt < CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end else begin
                        tx_clk_cnt <= 16'd0;
                        tx_bit_idx <= 3'd0;
                        tx_state   <= TX_DATA;
                    end
                end

                TX_DATA: begin
                    tx_pin <= tx_shift[tx_bit_idx];
                    if (tx_clk_cnt < CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end else begin
                        tx_clk_cnt <= 16'd0;
                        if (tx_bit_idx < 3'd7) begin
                            tx_bit_idx <= tx_bit_idx + 1'b1;
                        end else begin
                            tx_state <= TX_STOP;
                        end
                    end
                end

                TX_STOP: begin
                    tx_pin <= 1'b1; // Stop bit
                    if (tx_clk_cnt < CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end else begin
                        tx_clk_cnt <= 16'd0;
                        tx_state   <= TX_IDLE;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // UART Receiver FSM (Filtered with 868 clk center-sampling)
    // -------------------------------------------------------------------------
    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;

    reg [1:0]  rx_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_idx;
    reg [7:0]  rx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state   <= RX_IDLE;
            rx_ready   <= 1'b0;
            rx_byte    <= 8'd0;
            rx_clk_cnt <= 16'd0;
            rx_bit_idx <= 3'd0;
            rx_shift   <= 8'd0;
        end else begin
            rx_ready <= 1'b0;
            case (rx_state)
                RX_IDLE: begin
                    if (!rx_pin) begin // Falling edge detection
                        if (rx_clk_cnt == (CLKS_PER_BIT / 2)) begin
                            if (!rx_pin) begin
                                rx_clk_cnt <= 16'd0;
                                rx_state   <= RX_DATA;
                            end else begin
                                rx_clk_cnt <= 16'd0;
                            end
                        end else begin
                            rx_clk_cnt <= rx_clk_cnt + 1'b1;
                        end
                    end else begin
                        rx_clk_cnt <= 16'd0;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt < CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end else begin
                        rx_clk_cnt           <= 16'd0;
                        rx_shift[rx_bit_idx] <= rx_pin;
                        if (rx_bit_idx < 3'd7) begin
                            rx_bit_idx <= rx_bit_idx + 1'b1;
                        end else begin
                            rx_state <= RX_STOP;
                        end
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt < CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end else begin
                        rx_byte    <= rx_shift;
                        rx_ready   <= 1'b1;
                        rx_clk_cnt <= 16'd0;
                        rx_state   <= RX_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
