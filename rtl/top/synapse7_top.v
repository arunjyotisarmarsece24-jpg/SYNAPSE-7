// ============================================================================
// Module Name: synapse7_top
// Project:     SYNAPSE-7: Neuromorphic Post-Quantum Edge Security Engine
// Target:      Digilent Arty S7 (Xilinx Spartan-7 XC7S25 / XC7S50)
// ============================================================================

`timescale 1ns / 1ps

module synapse7_top (
    input  wire        CLK100MHZ,
    
    // User Switches & Buttons
    input  wire [3:0]  sw,
    input  wire [3:0]  btn,
    
    // Discrete LEDs
    output wire [3:0]  led,
    
    // RGB Status LEDs (LD0, LD1)
    output wire        led0_r,
    output wire        led0_g,
    output wire        led0_b,
    output wire        led1_r,
    output wire        led1_g,
    output wire        led1_b,
    
    // USB-UART Bridge
    input  wire        uart_rxd,    // PC -> FPGA (Receive)
    output wire        uart_txd     // FPGA -> PC (Transmit)
);

    // ------------------------------------------------------------------------
    // Reset Conditioning & Timestep Generator
    // ------------------------------------------------------------------------
    wire sys_rst_n = ~btn[0];

    // Global Neuromorphic Timestep Divider (e.g. 10 kHz timestep = 10,000 cycles at 100 MHz)
    reg [15:0] timestep_divider;
    reg        timestep_tick;

    always @(posedge CLK100MHZ or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            timestep_divider <= 16'd0;
            timestep_tick    <= 1'b0;
        end else begin
            if (timestep_divider == 16'd9999) begin
                timestep_divider <= 16'd0;
                timestep_tick    <= 1'b1;
            end else begin
                timestep_divider <= timestep_divider + 1'b1;
                timestep_tick    <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Rate & Temporal Spike Encoder
    // ------------------------------------------------------------------------
    reg [63:0] raw_synthetic_traffic;
    wire [7:0] encoded_input_spikes;

    // Traffic generator: switch[1] triggers synthetic high-intensity anomaly bursts
    reg [15:0] traffic_lfsr;
    always @(posedge CLK100MHZ or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            traffic_lfsr <= 16'h5A5A;
        end else begin
            traffic_lfsr <= {traffic_lfsr[14:0], traffic_lfsr[15] ^ traffic_lfsr[14] ^ traffic_lfsr[12] ^ traffic_lfsr[3]};
        end
    end

    always @(posedge CLK100MHZ) begin
        if (sw[1]) begin
            // Anomaly burst injection: high activity across all 8 channels
            raw_synthetic_traffic <= {8{8'hE8 | traffic_lfsr[7:0]}};
        end else if (btn[2]) begin
            // Manual injection pulse
            raw_synthetic_traffic <= {8{8'hFF}};
        end else begin
            // Normal background traffic profile
            raw_synthetic_traffic <= {8'h12, 8'h05, traffic_lfsr[7:0] & 8'h3F, 8'h18, 
                                      8'h02, traffic_lfsr[15:8] & 8'h1F, 8'h0E, 8'h08};
        end
    end

    spike_encoder #(
        .CHANNELS(8)
    ) u_spike_encoder (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .enable(timestep_tick),
        .raw_inputs_flat(raw_synthetic_traffic),
        .encoded_spikes(encoded_input_spikes)
    );

    // ------------------------------------------------------------------------
    // SNN Synaptic Mesh & Parallel LIF Neurons
    // ------------------------------------------------------------------------
    wire [7:0]  neuron_spikes;
    wire [127:0] all_v_mem_flat;

    snn_synapse_mesh #(
        .NUM_INPUTS(8),
        .NUM_NEURONS(8),
        .DATA_WIDTH(16),
        .WEIGHT_WIDTH(8)
    ) u_snn_mesh (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .timestep_tick(timestep_tick),
        .input_spikes(encoded_input_spikes),
        .v_th_tune(16'sd120),
        .weight_wr_en(1'b0),
        .weight_addr(6'd0),
        .weight_data(8'sd0),
        .neuron_spikes(neuron_spikes),
        .all_v_mem_flat(all_v_mem_flat)
    );

    // ------------------------------------------------------------------------
    // NIST ML-KEM Post-Quantum NTT Butterfly Accelerator
    // ------------------------------------------------------------------------
    reg  pqc_start;
    wire [31:0] pqc_cycles;
    wire [15:0] pqc_u_out, pqc_v_out;
    wire pqc_valid;

    // Synthetic NTT stimulus generator when sw[0] or btn[3] active
    reg [7:0] pqc_trig_cnt;
    always @(posedge CLK100MHZ or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pqc_trig_cnt <= 8'd0;
            pqc_start    <= 1'b0;
        end else begin
            pqc_start <= 1'b0;
            if (sw[0] || btn[3]) begin
                if (pqc_trig_cnt == 8'd63) begin
                    pqc_trig_cnt <= 8'd0;
                    pqc_start    <= 1'b1;
                end else begin
                    pqc_trig_cnt <= pqc_trig_cnt + 1'b1;
                end
            end
        end
    end

    pqc_ntt_butterfly #(
        .Q(3329)
    ) u_pqc_ntt (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .start(pqc_start),
        .u_in(16'sd1452),
        .v_in(16'sd2187),
        .zeta_twiddle(16'sd961), // Canonical Kyber twiddle factor
        .u_out(pqc_u_out),
        .v_out(pqc_v_out),
        .valid_out(pqc_valid),
        .butterfly_cycles_cnt(pqc_cycles)
    );

    // ------------------------------------------------------------------------
    // Physical Ring Oscillator TRNG & Entropy Source
    // ------------------------------------------------------------------------
    wire [7:0] trng_random_byte;
    wire       trng_valid;
    wire [3:0] ro_taps;

    ro_trng_entropy u_ro_trng (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .sample_enable(timestep_tick),
        .random_byte_out(trng_random_byte),
        .random_valid(trng_valid),
        .ro_raw_taps(ro_taps)
    );

    // ------------------------------------------------------------------------
    // XADC Side-Channel & Physical Glitch Probe
    // ------------------------------------------------------------------------
    wire [11:0] die_temp_raw;
    wire [11:0] vccint_raw;
    wire        voltage_glitch;
    wire        thermal_glitch;

    xadc_sidechannel_probe u_xadc_probe (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .sim_fault_inject(sw[2]), // SW[2] triggers voltage brownout / laser fault
        .die_temp_raw(die_temp_raw),
        .vccint_raw(vccint_raw),
        .voltage_glitch_alert(voltage_glitch),
        .thermal_glitch_alert(thermal_glitch)
    );

    // ------------------------------------------------------------------------
    // Neuromorphic Hardware Intrusion Detection Arbiter
    // ------------------------------------------------------------------------
    wire [7:0]  threat_score;
    wire [1:0]  threat_level;
    wire        hardware_tripwire;
    wire [31:0] total_threat_events;

    nhids_threat_arbiter #(
        .NUM_NEURONS(8),
        .WINDOW_SIZE(128),
        .ALERT_THRESH_LOW(8'd25),
        .ALERT_THRESH_HIGH(8'd60)
    ) u_threat_arbiter (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .timestep_tick(timestep_tick),
        .neuron_spikes(neuron_spikes),
        .xadc_voltage_glitch(voltage_glitch),
        .xadc_thermal_warning(thermal_glitch),
        .manual_trip_clear(btn[1]), // BTN[1] clears locked tripwire
        .threat_score(threat_score),
        .threat_level(threat_level),
        .hardware_tripwire(hardware_tripwire),
        .total_threat_events(total_threat_events)
    );

    // ------------------------------------------------------------------------
    // UART Telemetry Transceiver & Packetizer
    // ------------------------------------------------------------------------
    wire       uart_tx_busy;
    wire [7:0] uart_tx_data;
    wire       uart_tx_start;

    telemetry_packetizer #(
        .CLK_FREQ(100_000_000),
        .STREAM_RATE_HZ(200)
    ) u_packetizer (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .neuron_spikes(neuron_spikes),
        .threat_score(threat_score),
        .threat_level(threat_level),
        .hardware_tripwire(hardware_tripwire),
        .trng_byte(trng_random_byte),
        .pqc_cycles(pqc_cycles),
        .v_mem_sample(all_v_mem_flat[15:0]), // Neuron 0 trace
        .die_temp_raw(die_temp_raw),
        .vccint_raw(vccint_raw),
        .system_status_flags({sw, btn}),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_data(uart_tx_data),
        .uart_tx_start(uart_tx_start)
    );

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) u_uart_tx (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .tx_data(uart_tx_data),
        .tx_start(uart_tx_start),
        .tx_busy(uart_tx_busy),
        .tx_out(uart_txd)
    );

    // UART RX for external host commands (future interactive control)
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    uart_rx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) u_uart_rx (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .rx_in(uart_rxd),
        .rx_data(uart_rx_data),
        .rx_valid(uart_rx_valid)
    );

    // ------------------------------------------------------------------------
    // Physical Board I/O & Visual Status Indicators
    // ------------------------------------------------------------------------
    // Discrete LEDs:
    // LED0: System heartbeat pulse
    // LED1: SNN Firing activity (OR reduction of all 8 neurons)
    // LED2: PQC NTT busy
    // LED3: Tripwire / Anomaly lock active
    reg [24:0] heartbeat_cnt;
    always @(posedge CLK100MHZ) heartbeat_cnt <= heartbeat_cnt + 1'b1;

    assign led[0] = heartbeat_cnt[24];
    assign led[1] = |neuron_spikes;
    assign led[2] = pqc_start | pqc_valid;
    assign led[3] = hardware_tripwire;

    // RGB LEDs (Active High PWM / Logic on Arty S7):
    // LD0 & LD1 reflect threat level:
    // Level 00 (SAFE): Solid GREEN
    // Level 01 (CAUTION): Solid BLUE / AMBER
    // Level 10 (CRITICAL / TRIPWIRE): Blinking RED
    wire alert_blink = heartbeat_cnt[22];

    assign led0_r = (threat_level == 2'b10) ? alert_blink : 1'b0;
    assign led0_g = (threat_level == 2'b00) ? 1'b1 : 1'b0;
    assign led0_b = (threat_level == 2'b01) ? 1'b1 : 1'b0;

    assign led1_r = led0_r;
    assign led1_g = led0_g;
    assign led1_b = led0_b;

endmodule
