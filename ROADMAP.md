# SYNAPSE-7 Day-Wise Research & Implementation Roadmap
**Principal Investigator:** Arunjyoti Sarma  
**Institution:** Department of Electronics Engineering, Indian Institute of Technology (BHU) Varanasi  
**Hardware Platforms:** Digilent Arty S7-50 (AMD-Xilinx Spartan-7) + Espressif ESP8266 NodeMCU  

---

## 🎯 High-Level Objective
Construct a real-time, hardware-accelerated, quantum-resilient cryptographic engine that shields decentralized cryptocurrency transactions and edge communications from Shor's algorithm, Grover's search, and side-channel power attacks, backed by rigorous [[7, 1, 3]] Steane Quantum Error Correction.

---

## 🗓️ Phase Breakdown

### 🟢 DAY 1 (TODAY) — BRUTAL SOFTWARE GENESIS & CO-PROCESSOR DESIGN
- [x] **Mathematical Statevector Engine:** High-performance matrix-free tensor-contraction engine for $n$-qubit simulations.
- [x] **Quirk Quantum Bridge:** Bi-directional Quirk JSON/URL circuit exporter with Bloch sphere coordinate projection.
- [x] **[[7, 1, 3]] Steane QEC Engine:** Full Calderbank-Shor-Steane (CSS) code encoding 1 logical qubit over 7 physical qubits, with $X$ and $Z$ syndrome decoders recovering 100% fidelity under single-qubit errors.
- [x] **Post-Quantum NTT Lattice Engine:** Cooley-Tukey Radix-2 NTT over $\mathbb{Z}_q[x]/(x^{256}+1)$ with $q=12289$, designed for 1:1 mapping into Spartan-7 DSP48E1 slices.
- [x] **Ring-LWE Key Encapsulation & Encryption:** 128-bit quantum security public key cryptosystem with 0% bit-error rate.
- [x] **BB84 QKD Protocol Simulator:** Quantum channel with eavesdropping detection via QBER threshold analysis ($11\%$).
- [x] **CyberVault-7 Cryptocurrency Shield:** Lattice-signed transaction ledger and comparative Shor's algorithm breakdown.
- [x] **Synthesizable Verilog RTL Core:** `synapse7_qpu_core.v`, `synapse7_ntt_butterfly.v`, `synapse7_uart_rx_tx.v`, `synapse7_qpu_tb.v`, `arty_s7_50.xdc`.
- [x] **ESP8266 Firmware Blueprint:** `esp8266_quantum_node.ino` WiFi-to-UART transceiver.
- [x] **Cyberpunk CLI Telemetry HUD & Quirk Web Dashboard:** Interactive browser dashboard and console HUD.
- [x] **100% Automated Test Suite:** 18 pytest tests covering all subsystems.

---

### 🟡 DAY 2 — VIVADO RTL SYNTHESIS & WAVEFORM BENCHMARKING
- [ ] Create Vivado 2024.x project targeting Spartan-7 `xc7s50csga324-1`.
- [ ] Run behavioral simulation on `synapse7_qpu_tb.v` and capture VCD / WDB waveforms.
- [ ] Execute synthesis and examine resource utilization:
  - Target DSP48E1 slices: $\le 4$ slices
  - Target BRAM (RAMB18E1/RAMB36E1): $\le 8$ blocks
  - Target LUT/FF: $< 15\%$ of XC7S50 fabric
- [ ] Run static timing analysis (STA) ensuring zero setup/hold slack at 100MHz.

---

### 🟠 DAY 3 — ERROR RECONCILIATION & HIGH-THROUGHPUT TOEPLITZ PIPELINE
- [ ] Implement Modified Cascade reconciliation protocol for QKD raw key bit-error correction.
- [ ] Implement hardware Toeplitz hashing matrix generator for privacy amplification.
- [ ] Build high-speed Python-to-UART loopback harness benchmarking transmission throughput.

---

### 🔴 DAY 4 — ARTY S7 & ESP8266 PHYSICAL HARDWARE INTEGRATION
- [ ] Unbox and inspect physical Digilent Arty S7-50 and ESP8266 boards.
- [ ] Wire Pmod Header JA (Pins L17, L18, GND, 3V3) to ESP8266 hardware UART pins.
- [ ] Flash synthesis bitstream `synapse7_top.bit` onto Spartan-7 SPI Flash (Quad-SPI Spansion 128Mb).
- [ ] Flash ESP8266 firmware via Arduino IDE / esptool.py.
- [ ] Verify two-way communication: Send 'Q', 'S', 'N' from ESP8266 and verify Arty S7 RGB LED status changes live.

---

### 🟣 DAY 5 — OVER-THE-AIR QUANTUM-IMMUNE LEDGER & MESH NETWORK
- [ ] Establish ESP8266 wireless mesh bridging transactions from phone/laptop to FPGA.
- [ ] Execute live Ring-LWE lattice signature generation inside Arty S7 hardware registers.
- [ ] Commit real-time quantum-safe cryptocurrency transfers over the air.

---

### 🔵 DAY 6 — ADVERSARIAL SIDE-CHANNEL & STRESS ATTACKS
- [ ] Simulate Differential Power Analysis (DPA) on NTT polynomial arithmetic.
- [ ] Add constant-time masking and shuffling countermeasures to prevent power leakage.
- [ ] Differential Fault Analysis (DFA) testing: inject voltage glitches and verify Steane stabilizer triggers red alert LED.

---

### ⚪ DAY 7 — FINAL RELEASE & RESEARCH PUBLICATION
- [ ] Compile comprehensive hardware demonstration video.
- [ ] Finalize benchmarking data (latency in clock cycles, throughput in Mbps, power in mW).
- [ ] Prepare preprint manuscript for IEEE Transactions on Computer-Aided Design / Quantum Engineering.
