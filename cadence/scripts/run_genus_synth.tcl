# ==============================================================================
# Script: run_genus_synth.tcl
# Project: SYNAPSE-7 (Quantum-Neuromorphic Hardware Engine)
# Target: Cadence Genus Synthesis Solution (ASIC Standard Cell Flow)
# Description: Synthesizes the Quantum-Neuromorphic Coprocessor & Top-Level RTL
#              into a gate-level netlist with full timing, area, and power reports.
# ==============================================================================

puts "======================================================================"
puts "  SYNAPSE-7 // Cadence Genus RTL-to-GDS Synthesis"
puts "  Module: synapse7_top with Quantum Neuromorphic Engine"
puts "======================================================================"

# 1. Environment & Multi-Thread Settings
set_db max_cpus_per_server 16
set_db information_level 7

# 2. Target Technology Library (Generic or TSMC / FreePDK45 / Sky130)
# If proprietary PDK is not set, Genus uses generic technology mapping
set TECH_LIB [getenv "CADENCE_TECH_LIB" ""]
if {$TECH_LIB ne ""} {
    set_db target_library $TECH_LIB
    set_db link_library $TECH_LIB
    puts "\[INFO\] Using target technology library: $TECH_LIB"
} else {
    puts "\[INFO\] No CADENCE_TECH_LIB specified. Synthesizing with Genus Generic Library."
}

# 3. Read RTL Design Sources
set RTL_DIR "../rtl"
set_db init_hdl_search_path [list \
    "$RTL_DIR/top" \
    "$RTL_DIR/quantum_neuromorphic" \
    "$RTL_DIR/neuromorphic" \
    "$RTL_DIR/quantum_pqc" \
    "$RTL_DIR/security" \
    "$RTL_DIR/comms" \
]

read_hdl -language sv [list \
    "$RTL_DIR/comms/uart_tx.v" \
    "$RTL_DIR/comms/uart_rx.v" \
    "$RTL_DIR/comms/telemetry_packetizer.v" \
    "$RTL_DIR/neuromorphic/spike_encoder.v" \
    "$RTL_DIR/neuromorphic/lif_neuron.v" \
    "$RTL_DIR/neuromorphic/snn_synapse_mesh.v" \
    "$RTL_DIR/quantum_neuromorphic/quantum_spiking_neuron.v" \
    "$RTL_DIR/quantum_neuromorphic/quantum_synapse_entangler.v" \
    "$RTL_DIR/quantum_neuromorphic/quantum_neuromorphic_core.v" \
    "$RTL_DIR/quantum_pqc/montgomery_reducer.v" \
    "$RTL_DIR/quantum_pqc/pqc_ntt_butterfly.v" \
    "$RTL_DIR/quantum_pqc/ro_trng_entropy.v" \
    "$RTL_DIR/security/xadc_sidechannel_probe.v" \
    "$RTL_DIR/security/nhids_threat_arbiter.v" \
    "$RTL_DIR/top/synapse7_top.v" \
]

# 4. Elaborate Top-Level Module
elaborate synapse7_top
check_design -unresolved

# 5. Timing Constraints (SDC)
puts "\[INFO\] Applying SDC timing constraints: 100 MHz clock (10.0 ns)..."
create_clock -name "CLK100MHZ" -period 10.0 [get_ports CLK100MHZ]
set_clock_uncertainty 0.25 [get_clocks CLK100MHZ]
set_clock_transition 0.15 [get_clocks CLK100MHZ]

# Input/Output Delays
set_input_delay -clock CLK100MHZ 2.0 [remove_from_collection [all_inputs] [get_ports CLK100MHZ]]
set_output_delay -clock CLK100MHZ 2.0 [all_outputs]

# 6. Generic Synthesis & Optimization
puts "\[INFO\] Starting Generic Synthesis (syn_generic)..."
syn_generic

puts "\[INFO\] Starting Technology Mapping (syn_map)..."
syn_map

puts "\[INFO\] Starting Gate-Level Optimization (syn_opt)..."
syn_opt

# 7. Generate ASIC Reports
file mkdir "../reports"
file mkdir "../outputs"

report_timing > "../reports/synapse7_timing_report.rpt"
report_area   > "../reports/synapse7_area_report.rpt"
report_power  > "../reports/synapse7_power_report.rpt"
report_qor    > "../reports/synapse7_qor_report.rpt"

# 8. Export Gate-Level Netlist & SDC for Innovus PnR
write_hdl -mapped > "../outputs/synapse7_synth_netlist.v"
write_sdc > "../outputs/synapse7_synth_constraints.sdc"

puts "======================================================================"
puts "  Cadence Genus Synthesis Completed Successfully!"
puts "  Netlist: outputs/synapse7_synth_netlist.v"
puts "  Reports: reports/synapse7_area_report.rpt"
puts "======================================================================"
exit
