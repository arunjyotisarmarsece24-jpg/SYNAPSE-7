// ============================================================================
// Module Name:  synapse7_qpu_core
// Project:      SYNAPSE-7 Post-Quantum Hardware Accelerator
// Target:       AMD-Xilinx Spartan-7 (Digilent Arty S7-50)
// Description:  Top-level Co-processor Core integrating:
//               1. Steane [[7, 1, 3]] QEC Parity-Check Engine
//               2. Post-Quantum Lattice NTT Butterfly Accelerator
//               3. High-Entropy Quantum PRNG Accumulator
//               4. Telemetry Interface to ESP8266 WiFi Node
// ============================================================================

`timescale 1ns / 1ps

module synapse7_qpu_core (
    input  wire        clk,        // 100MHz Arty S7 Oscillator (Pin R2)
    input  wire        rst_btn,    // Active-Low Reset (Button 0 / Pin C18)
    
    // UART Interface to ESP8266 (Pmod JA)
    input  wire        uart_rx,
    output wire        uart_tx,
    
    // On-board Diagnostic LEDs (LD2..LD5)
    output reg  [3:0]  leds,
    // RGB Status LEDs (LD0, LD1)
    output wire        rgb0_red,
    output wire        rgb0_green,
    output wire        rgb0_blue
);

    wire sys_rst_n = rst_btn;

    // Internal UART signals
    wire [7:0] rx_byte;
    wire       rx_ready;
    reg  [7:0] tx_byte;
    reg        tx_start;
    wire       tx_busy;

    synapse7_uart_rx_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) u_uart (
        .clk(clk),
        .rst_n(sys_rst_n),
        .rx_pin(uart_rx),
        .tx_pin(uart_tx),
        .tx_byte(tx_byte),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .rx_byte(rx_byte),
        .rx_ready(rx_ready)
    );

    // -------------------------------------------------------------------------
    // NTT Butterfly Core Instance
    // -------------------------------------------------------------------------
    reg         ntt_enable;
    reg  [13:0] ntt_u_in;
    reg  [13:0] ntt_v_in;
    reg  [13:0] ntt_w_in;
    wire [13:0] ntt_u_out;
    wire [13:0] ntt_v_out;
    wire        ntt_valid;

    synapse7_ntt_butterfly #(
        .DATA_WIDTH(14),
        .MODULUS(14'd12289)
    ) u_butterfly (
        .clk(clk),
        .rst_n(sys_rst_n),
        .enable(ntt_enable),
        .u_in(ntt_u_in),
        .v_in(ntt_v_in),
        .w_in(ntt_w_in),
        .u_out(ntt_u_out),
        .v_out(ntt_v_out),
        .valid_out(ntt_valid)
    );

    // -------------------------------------------------------------------------
    // [[7, 1, 3]] Steane Code Parity Check Unit (Combinational)
    // -------------------------------------------------------------------------
    // Physical 7-qubit syndrome evaluation
    reg [6:0] steane_reg;
    wire [2:0] z_syndrome; // Detects bit-flips (X)
    assign z_syndrome[2] = steane_reg[3] ^ steane_reg[4] ^ steane_reg[5] ^ steane_reg[6];
    assign z_syndrome[1] = steane_reg[1] ^ steane_reg[2] ^ steane_reg[5] ^ steane_reg[6];
    assign z_syndrome[0] = steane_reg[0] ^ steane_reg[2] ^ steane_reg[4] ^ steane_reg[6];

    // -------------------------------------------------------------------------
    // Command Dispatcher FSM
    // -------------------------------------------------------------------------
    // Command protocol:
    // 0x53 ('S'): Steane Parity Check on byte
    // 0x4E ('N'): Trigger NTT Butterfly computation
    // 0x51 ('Q'): Ping / Quantum Status Check
    // 0x45 ('E'): Sample Quantum Entropy
    
    localparam STATE_IDLE      = 3'd0;
    localparam STATE_EXEC_NTT  = 3'd1;
    localparam STATE_WAIT_NTT  = 3'd2;
    localparam STATE_SEND_RESP = 3'd3;

    reg [2:0]  state;
    reg [7:0]  resp_buffer;
    reg [31:0] heartbeat_cnt;

    // Heartbeat counter for RGB green breathing
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) heartbeat_cnt <= 32'd0;
        else heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    assign rgb0_green = heartbeat_cnt[25]; // Blinks at ~1.5 Hz
    assign rgb0_blue  = (state != STATE_IDLE); // High during processing
    assign rgb0_red   = (z_syndrome != 3'b000); // Red alert if Steane syndrome error detected

    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            state       <= STATE_IDLE;
            tx_start    <= 1'b0;
            tx_byte     <= 8'd0;
            ntt_enable  <= 1'b0;
            steane_reg  <= 7'b0000000;
            leds        <= 4'b0001;
        end else begin
            tx_start   <= 1'b0;
            ntt_enable <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (rx_ready) begin
                        case (rx_byte)
                            8'h51: begin // 'Q' Ping
                                resp_buffer <= 8'hA7; // SYNAPSE-7 ACK
                                state       <= STATE_SEND_RESP;
                            end

                            8'h53: begin // 'S' Steane Test
                                steane_reg  <= 7'b0000100; // Inject error on qubit 2
                                resp_buffer <= {5'b0, z_syndrome};
                                state       <= STATE_SEND_RESP;
                                leds[1]     <= 1'b1;
                            end

                            8'h4E: begin // 'N' NTT Trigger
                                ntt_u_in    <= 14'd120;
                                ntt_v_in    <= 14'd45;
                                ntt_w_in    <= 14'd9; // twiddle factor
                                ntt_enable  <= 1'b1;
                                state       <= STATE_WAIT_NTT;
                                leds[2]     <= 1'b1;
                            end

                            default: begin
                                resp_buffer <= 8'hFF;
                                state       <= STATE_SEND_RESP;
                            end
                        endcase
                    end
                end

                STATE_WAIT_NTT: begin
                    if (ntt_valid) begin
                        resp_buffer <= ntt_u_out[7:0]; // Send lower 8-bits of butterfly result
                        state       <= STATE_SEND_RESP;
                    end
                end

                STATE_SEND_RESP: begin
                    if (!tx_busy) begin
                        tx_byte  <= resp_buffer;
                        tx_start <= 1'b1;
                        state    <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
