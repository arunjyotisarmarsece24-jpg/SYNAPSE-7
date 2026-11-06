// ============================================================================
// Module Name: nhids_threat_arbiter
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 (XC7S25 / XC7S50)
// Description: Neuromorphic Hardware Intrusion Detection System (N-HIDS)
//              Threat Arbiter with Hardware Tripwire and Zero-Trust Isolation.
// ============================================================================

`timescale 1ns / 1ps

module nhids_threat_arbiter #(
    parameter NUM_NEURONS       = 8,
    parameter WINDOW_SIZE       = 128,
    parameter ALERT_THRESH_LOW  = 8'd25,
    parameter ALERT_THRESH_HIGH = 8'd60
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   timestep_tick,
    input  wire [NUM_NEURONS-1:0] neuron_spikes,
    input  wire                   xadc_voltage_glitch,
    input  wire                   xadc_thermal_warning,
    input  wire                   manual_trip_clear,
    
    // Outputs to System & Telemetry
    output reg  [7:0]             threat_score,        // 0 to 100 percentage
    output reg  [1:0]             threat_level,        // 00=SAFE, 01=CAUTION, 10=CRITICAL
    output reg                    hardware_tripwire,   // Physical zero-trust lock
    output reg  [31:0]            total_threat_events  // Event counter for analytics
);

    // Sliding window spike accumulator
    reg [6:0] window_cnt;
    reg [7:0] window_spike_sum;
    reg [7:0] latched_spike_rate;

    // Count 1s in neuron_spikes
    integer i;
    reg [3:0] current_step_spikes;
    always @(*) begin
        current_step_spikes = 4'd0;
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin
            if (neuron_spikes[i])
                current_step_spikes = current_step_spikes + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_cnt         <= 7'd0;
            window_spike_sum   <= 8'd0;
            latched_spike_rate <= 8'd0;
        end else if (timestep_tick) begin
            if (window_cnt == (WINDOW_SIZE - 1)) begin
                window_cnt         <= 7'd0;
                latched_spike_rate <= window_spike_sum;
                window_spike_sum   <= current_step_spikes;
            end else begin
                window_cnt       <= window_cnt + 1'b1;
                window_spike_sum <= window_spike_sum + current_step_spikes;
            end
        end
    end

    // Threat Score Calculation Engine
    // Fuses Neuromorphic Spike density + XADC physical side-channel glitches
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            threat_score        <= 8'd0;
            threat_level        <= 2'b00;
            hardware_tripwire   <= 1'b0;
            total_threat_events <= 32'd0;
        end else begin
            // Base score derived from spike rate
            reg [8:0] calculated_score;
            calculated_score = {1'b0, latched_spike_rate};

            // Physical fault injection / side-channel penalties
            if (xadc_voltage_glitch)
                calculated_score = calculated_score + 9'd40;
            if (xadc_thermal_warning)
                calculated_score = calculated_score + 9'd25;

            // Clamp threat score to 100
            if (calculated_score > 9'd100)
                threat_score <= 8'd100;
            else
                threat_score <= calculated_score[7:0];

            // Threat level state evaluation
            if (threat_score >= ALERT_THRESH_HIGH || xadc_voltage_glitch) begin
                threat_level      <= 2'b10; // CRITICAL ATTACK
                hardware_tripwire <= 1'b1; // Lock down PQC registers & RoT
            end else if (threat_score >= ALERT_THRESH_LOW) begin
                threat_level <= 2'b01;     // SUSPICIOUS ANOMALY
            end else begin
                threat_level <= 2'b00;     // NORMAL OPERATION
            end

            // Manual unlock logic
            if (manual_trip_clear) begin
                hardware_tripwire <= 1'b0;
            end

            // Threat event logging
            if (threat_level == 2'b10 && !hardware_tripwire) begin
                total_threat_events <= total_threat_events + 1'b1;
            end
        end
    end

endmodule
