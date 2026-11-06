// ============================================================================
// Module Name: telemetry_packetizer
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Real-Time Hardware Telemetry Packet Streaming Engine.
//              Serializes neural raster, quantum NTT cycles, physical XADC vitals,
//              and security threat arbitration into framed 16-byte telemetry.
// ============================================================================

`timescale 1ns / 1ps

module telemetry_packetizer #(
    parameter CLK_FREQ       = 100_000_000,
    parameter STREAM_RATE_HZ = 200            // 200 Hz telemetry refresh
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Telemetry Payloads
    input  wire [7:0]  neuron_spikes,
    input  wire [7:0]  threat_score,
    input  wire [1:0]  threat_level,
    input  wire        hardware_tripwire,
    input  wire [7:0]  trng_byte,
    input  wire [31:0] pqc_cycles,
    input  wire [15:0] v_mem_sample,
    input  wire [11:0] die_temp_raw,
    input  wire [11:0] vccint_raw,
    input  wire [7:0]  system_status_flags,
    
    // UART TX interface
    input  wire        uart_tx_busy,
    output reg  [7:0]  uart_tx_data,
    output reg         uart_tx_start
);

    localparam INTERVAL_CYCLES = CLK_FREQ / STREAM_RATE_HZ;
    localparam TOTAL_BYTES     = 16;

    reg [23:0] timer_cnt;
    reg [4:0]  byte_idx;
    reg        transmitting;
    reg [7:0]  frame_seq;
    reg [7:0]  packet_buf [0:TOTAL_BYTES-1];
    reg [7:0]  chksum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_cnt     <= 24'd0;
            byte_idx      <= 5'd0;
            transmitting  <= 1'b0;
            frame_seq     <= 8'd0;
            uart_tx_data  <= 8'd0;
            uart_tx_start <= 1'b0;
            chksum        <= 8'd0;
        end else begin
            uart_tx_start <= 1'b0;

            if (!transmitting) begin
                if (timer_cnt < (INTERVAL_CYCLES - 1)) begin
                    timer_cnt <= timer_cnt + 1'b1;
                end else begin
                    timer_cnt <= 24'd0;
                    frame_seq <= frame_seq + 1'b1;

                    // Assemble fresh telemetry frame
                    packet_buf[0]  <= 8'hAA; // Sync byte 1
                    packet_buf[1]  <= 8'h55; // Sync byte 2
                    packet_buf[2]  <= frame_seq;
                    packet_buf[3]  <= neuron_spikes;
                    packet_buf[4]  <= threat_score;
                    packet_buf[5]  <= {hardware_tripwire, threat_level, 5'd0};
                    packet_buf[6]  <= trng_byte;
                    packet_buf[7]  <= pqc_cycles[7:0];
                    packet_buf[8]  <= pqc_cycles[15:8];
                    packet_buf[9]  <= v_mem_sample[7:0];
                    packet_buf[10] <= v_mem_sample[15:8];
                    packet_buf[11] <= die_temp_raw[7:0];
                    packet_buf[12] <= {die_temp_raw[11:8], vccint_raw[11:8]};
                    packet_buf[13] <= vccint_raw[7:0];
                    packet_buf[14] <= system_status_flags;
                    
                    // Simple XOR Checksum across bytes 2..14
                    packet_buf[15] <= frame_seq ^ neuron_spikes ^ threat_score ^ 
                                      {hardware_tripwire, threat_level, 5'd0} ^ 
                                      trng_byte ^ pqc_cycles[7:0] ^ pqc_cycles[15:8] ^ 
                                      v_mem_sample[7:0] ^ v_mem_sample[15:8] ^ 
                                      die_temp_raw[7:0] ^ vccint_raw[7:0] ^ system_status_flags;

                    byte_idx     <= 5'd0;
                    transmitting <= 1'b1;
                end
            end else begin
                // Stream packet bytes sequentially into UART TX
                if (!uart_tx_busy && !uart_tx_start) begin
                    uart_tx_data  <= packet_buf[byte_idx];
                    uart_tx_start <= 1'b1;
                    if (byte_idx < (TOTAL_BYTES - 1)) begin
                        byte_idx <= byte_idx + 1'b1;
                    end else begin
                        transmitting <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
