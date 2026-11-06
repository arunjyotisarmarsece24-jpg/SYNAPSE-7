// ============================================================================
// Module Name: spike_encoder
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Multi-Channel Rate & Temporal Spike Encoder.
//              Converts 8 parallel byte streams (e.g. packet headers, XADC
//              telemetry, bus traffic) into spike trains using LFSR-based
//              pseudo-random rate coding and temporal delta thresholding.
// ============================================================================

`timescale 1ns / 1ps

module spike_encoder #(
    parameter CHANNELS = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 enable,
    input  wire [CHANNELS*8-1:0] raw_inputs_flat, // 8 channels of 8-bit unsigned data
    output reg  [CHANNELS-1:0]  encoded_spikes
);

    // 16-bit Galois Linear Feedback Shift Register (LFSR) for Poisson probability generation
    reg [15:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1;
        end else if (enable) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        end
    end

    integer c;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            encoded_spikes <= {CHANNELS{1'b0}};
        end else if (enable) begin
            for (c = 0; c < CHANNELS; c = c + 1) begin
                // Rate coding: Fire if raw intensity exceeds pseudo-random LFSR slice
                // Channel c compares against LFSR shifted slice for decorrelation
                if (raw_inputs_flat[c*8 +: 8] > (lfsr[7:0] ^ (c * 8'd29))) begin
                    encoded_spikes[c] <= 1'b1;
                end else begin
                    encoded_spikes[c] <= 1'b0;
                end
            end
        end else begin
            encoded_spikes <= {CHANNELS{1'b0}};
        end
    end

endmodule
