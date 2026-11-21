// ============================================================================
// Module Name: riscv_soc_top
// Project:     SYNAPSE-7 (Quantum-Neuromorphic RISC-V Computer Architecture)
// Target:      Xilinx Spartan-7 (XC7S25/50) / Cadence ASIC Flow
// Description: Full RISC-V System-on-Chip (SoC) Computer Architecture.
//              Integrates RV32I Processor Core with High-Speed On-Chip RAM
//              and Memory-Mapped Quantum Neuromorphic Coprocessor Enclave,
//              PQC Enclave, TRNG Silicon Harvester, and Telemetry Transceiver.
// ============================================================================

`timescale 1ns / 1ps

module riscv_soc_top (
    input  wire        CLK100MHZ,
    input  wire [3:0]  sw,
    input  wire [3:0]  btn,
    output wire [3:0]  led,
    output wire        led0_r, led0_g, led0_b,
    output wire        led1_r, led1_g, led1_b,
    input  wire        uart_rxd,
    output wire        uart_txd
);

    wire sys_rst_n = ~btn[0];

    // ------------------------------------------------------------------------
    // Clock Divider & Timestep Generator
    // ------------------------------------------------------------------------
    reg [15:0] timestep_cnt;
    reg        timestep_tick;
    always @(posedge CLK100MHZ or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            timestep_cnt  <= 16'd0;
            timestep_tick <= 1'b0;
        end else if (timestep_cnt == 16'd9999) begin
            timestep_cnt  <= 16'd0;
            timestep_tick <= 1'b1;
        end else begin
            timestep_cnt  <= timestep_cnt + 1'b1;
            timestep_tick <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // RISC-V Processor Core Buses
    // ------------------------------------------------------------------------
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_we;
    reg  [31:0] dmem_rdata;

    riscv_core u_cpu (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_we(dmem_we),
        .dmem_rdata(dmem_rdata)
    );

    // ------------------------------------------------------------------------
    // Dual-Port On-Chip RAM (Instruction + Data Memory, 16 KB)
    // Address Range: 0x0000_0000 to 0x0000_3FFF (4096 32-bit words)
    // ------------------------------------------------------------------------
    localparam RAM_WORDS = 4096;
    reg [31:0] ram [0:RAM_WORDS-1];

    // Initialize with embedded Quantum-Neuromorphic control firmware
    initial begin
        $readmemh("firmware.mem", ram);
    end

    // Port A: Instruction Fetch (Word Addressed)
    wire [11:0] imem_word_addr = imem_addr[13:2];
    assign imem_rdata = ram[imem_word_addr];

    // Port B: Data Memory Read/Write
    wire is_ram_access = (dmem_addr < 32'h0000_4000);
    wire [11:0] dmem_word_addr = dmem_addr[13:2];

    always @(posedge CLK100MHZ) begin
        if (dmem_we && is_ram_access) begin
            if (dmem_wstrb[0]) ram[dmem_word_addr][7:0]   <= dmem_wdata[7:0];
            if (dmem_wstrb[1]) ram[dmem_word_addr][15:8]  <= dmem_wdata[15:8];
            if (dmem_wstrb[2]) ram[dmem_word_addr][23:16] <= dmem_wdata[23:16];
            if (dmem_wstrb[3]) ram[dmem_word_addr][31:24] <= dmem_wdata[31:24];
        end
    end

    wire [31:0] ram_rdata = ram[dmem_word_addr];

    // ------------------------------------------------------------------------
    // Hardware Ring Oscillator TRNG Harvester
    // ------------------------------------------------------------------------
    wire [7:0] trng_byte;
    wire       trng_valid;
    wire [3:0] ro_taps;

    ro_trng_entropy u_ro_trng (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .sample_enable(timestep_tick),
        .random_byte_out(trng_byte),
        .random_valid(trng_valid),
        .ro_raw_taps(ro_taps)
    );

    // ------------------------------------------------------------------------
    // Quantum Neuromorphic Coprocessor Enclave
    // ------------------------------------------------------------------------
    reg  [31:0] qnc_ctrl_reg;
    reg  [15:0] qnc_pth_reg;
    reg  [7:0]  qnc_syn_inject_reg;
    wire [7:0]  quantum_spikes;
    wire [15:0] q_prob_one_sample;
    wire signed [15:0] q_bloch_z_sample;
    wire signed [15:0] q_coherence_avg;
    wire [31:0] total_qspikes_cnt;
    wire [127:0] all_q_prob_flat;

    // Controls: bit 0: quantum_en, bit 1: entanglement_en, bit 2: stochastic_mode
    wire qnc_enable          = qnc_ctrl_reg[0] | sw[3];
    wire qnc_entanglement_en = qnc_ctrl_reg[1] | 1'b1;
    wire qnc_stochastic_mode = qnc_ctrl_reg[2];

    wire [7:0] qnc_input_spikes = qnc_syn_inject_reg | {7'd0, timestep_tick};

    quantum_neuromorphic_core #(
        .NUM_NEURONS(8),
        .DATA_WIDTH(16),
        .WEIGHT_WIDTH(8)
    ) u_quantum_core (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .enable(timestep_tick),
        .quantum_en(qnc_enable),
        .input_spikes(qnc_input_spikes),
        .entanglement_en(qnc_entanglement_en),
        .stochastic_mode(qnc_stochastic_mode),
        .entropy_byte(trng_byte),
        .p_th_tune(qnc_pth_reg),
        .quantum_spikes(quantum_spikes),
        .prob_one_sample(q_prob_one_sample),
        .bloch_z_sample(q_bloch_z_sample),
        .coherence_avg(q_coherence_avg),
        .total_qspikes_cnt(total_qspikes_cnt),
        .all_prob_one_flat(all_q_prob_flat)
    );

    // ------------------------------------------------------------------------
    // NIST ML-KEM Kyber NTT Butterfly Enclave
    // ------------------------------------------------------------------------
    reg  pqc_trigger_reg;
    wire [31:0] pqc_cycles;
    wire [15:0] pqc_u_out, pqc_v_out;
    wire pqc_valid;

    pqc_ntt_butterfly #(
        .Q(3329)
    ) u_pqc_ntt (
        .clk(CLK100MHZ),
        .rst_n(sys_rst_n),
        .start(pqc_trigger_reg | sw[0]),
        .u_in(16'sd1452),
        .v_in(16'sd2187),
        .zeta_twiddle(16'sd961),
        .u_out(pqc_u_out),
        .v_out(pqc_v_out),
        .valid_out(pqc_valid),
        .butterfly_cycles_cnt(pqc_cycles)
    );

    // ------------------------------------------------------------------------
    // GPIO & Discrete Outputs
    // ------------------------------------------------------------------------
    reg [3:0] riscv_gpio_leds;

    assign led[0] = riscv_gpio_leds[0];
    assign led[1] = |quantum_spikes;
    assign led[2] = riscv_gpio_leds[2] | pqc_valid;
    assign led[3] = riscv_gpio_leds[3];

    assign led0_r = riscv_gpio_leds[3];
    assign led0_g = ~riscv_gpio_leds[3];
    assign led0_b = qnc_enable;
    assign led1_r = led0_r;
    assign led1_g = led0_g;
    assign led1_b = led0_b;

    // ------------------------------------------------------------------------
    // MMIO Memory Decoder (Base: 0x8000_0000)
    // ------------------------------------------------------------------------
    wire is_mmio_access = (dmem_addr[31] == 1'b1);
    wire [7:0] mmio_offset = dmem_addr[7:0];

    // MMIO Write Handling
    always @(posedge CLK100MHZ or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            qnc_ctrl_reg       <= 32'h0000_0003; // Default: Quantum + Entanglement Enabled
            qnc_pth_reg        <= 16'd8192;      // 50% Born collapse threshold
            qnc_syn_inject_reg <= 8'd0;
            pqc_trigger_reg    <= 1'b0;
            riscv_gpio_leds    <= 4'b0001;
        end else begin
            pqc_trigger_reg <= 1'b0;
            if (dmem_we && is_mmio_access) begin
                case (mmio_offset)
                    8'h00: qnc_ctrl_reg       <= dmem_wdata;
                    8'h04: qnc_pth_reg        <= dmem_wdata[15:0];
                    8'h18: qnc_syn_inject_reg <= dmem_wdata[7:0];
                    8'h20: pqc_trigger_reg    <= dmem_wdata[0];
                    8'h28: riscv_gpio_leds    <= dmem_wdata[3:0];
                endcase
            end
        end
    end

    // MMIO Read Multiplexer
    reg [31:0] mmio_rdata;
    always @(*) begin
        case (mmio_offset)
            8'h00: mmio_rdata = qnc_ctrl_reg;
            8'h04: mmio_rdata = {16'd0, qnc_pth_reg};
            8'h08: mmio_rdata = {24'd0, quantum_spikes};
            8'h0C: mmio_rdata = {16'd0, q_prob_one_sample};
            8'h10: mmio_rdata = {{16{q_coherence_avg[15]}}, q_coherence_avg};
            8'h14: mmio_rdata = total_qspikes_cnt;
            8'h1C: mmio_rdata = {24'd0, trng_byte};
            8'h20: mmio_rdata = {31'd0, pqc_valid};
            8'h24: mmio_rdata = pqc_cycles;
            8'h28: mmio_rdata = {28'd0, riscv_gpio_leds};
            8'h2C: mmio_rdata = {28'd0, sw};
            default: mmio_rdata = 32'd0;
        endcase
    end

    // Bus Read Data Select
    always @(*) begin
        if (is_ram_access)
            dmem_rdata = ram_rdata;
        else if (is_mmio_access)
            dmem_rdata = mmio_rdata;
        else
            dmem_rdata = 32'd0;
    end

    // ------------------------------------------------------------------------
    // UART Telemetry Packetizer
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
        .neuron_spikes(quantum_spikes),
        .threat_score(8'd12),
        .threat_level(2'b00),
        .hardware_tripwire(1'b0),
        .trng_byte(trng_byte),
        .pqc_cycles(pqc_cycles),
        .v_mem_sample(q_prob_one_sample),
        .die_temp_raw(12'd2500),
        .vccint_raw(12'd1365),
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

endmodule
