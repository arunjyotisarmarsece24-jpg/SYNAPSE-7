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

# Determine Project Root Directory automatically
if {[file exists "rtl"]} {
    set PROJ_ROOT "."
} elseif {[file exists "../rtl"]} {
    set PROJ_ROOT ".."
} else {
    set PROJ_ROOT [file normalize "[file dirname [info script]]/../.."]
}
set RTL_DIR "$PROJ_ROOT/rtl"
set REPORTS_DIR "$PROJ_ROOT/reports"
set OUTPUTS_DIR "$PROJ_ROOT/outputs"

puts "\[INFO\] Project Root: $PROJ_ROOT"
puts "\[INFO\] RTL Directory: $RTL_DIR"

# 2. Target Technology Library
# Prioritize Nangate FreePDK45 for physical micron area dimensions (um^2)
set TECH_LIB ""
if {[info exists ::env(CADENCE_TECH_LIB)] && $::env(CADENCE_TECH_LIB) ne ""} {
    set TECH_LIB $::env(CADENCE_TECH_LIB)
} elseif {[file exists "/home/install/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/liberty/FreePDK45_lib_v1.0_typical.lib"]} {
    set TECH_LIB "/home/install/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/liberty/FreePDK45_lib_v1.0_typical.lib"
} elseif {[file exists "/home/install/FOUNDRY/digital/45nm/dig/lib/typical.lib"]} {
    set TECH_LIB "/home/install/FOUNDRY/digital/45nm/dig/lib/typical.lib"
} elseif {[file exists "/home/install/FOUNDRY/digital/90nm/dig/lib/typical.lib"]} {
    set TECH_LIB "/home/install/FOUNDRY/digital/90nm/dig/lib/typical.lib"
} elseif {[file exists "/home/install/FOUNDRY/digital/180nm/dig/lib/typical.lib"]} {
    set TECH_LIB "/home/install/FOUNDRY/digital/180nm/dig/lib/typical.lib"
} elseif {[file exists "/home/install/GENUS211/share/synth/tutorials/tech/tutorial.lib"]} {
    set TECH_LIB "/home/install/GENUS211/share/synth/tutorials/tech/tutorial.lib"
}

if {$TECH_LIB ne ""} {
    puts "\[INFO\] Loading target technology library: $TECH_LIB"
    read_libs $TECH_LIB
} else {
    puts "\[ERROR\] No target technology library found!"
    exit 1
}

# 3. Read RTL Design Sources
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
puts "\[INFO\] Elaborating design synapse7_top..."
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
file mkdir $REPORTS_DIR
file mkdir $OUTPUTS_DIR

report_timing > "$REPORTS_DIR/synapse7_timing_report.rpt"
report_area   > "$REPORTS_DIR/synapse7_area_report.rpt"
report_power  > "$REPORTS_DIR/synapse7_power_report.rpt"
report_qor    > "$REPORTS_DIR/synapse7_qor_report.rpt"

# 8. Export Gate-Level Netlist & SDC for Innovus PnR
write_hdl -mapped > "$OUTPUTS_DIR/synapse7_synth_netlist.v"
write_sdc > "$OUTPUTS_DIR/synapse7_synth_constraints.sdc"

puts "======================================================================"
puts "  Cadence Genus Synthesis Completed Successfully!"
puts "  Netlist:     $OUTPUTS_DIR/synapse7_synth_netlist.v"
puts "  Constraints: $OUTPUTS_DIR/synapse7_synth_constraints.sdc"
puts "  Area Report: $REPORTS_DIR/synapse7_area_report.rpt"
puts "======================================================================"

# Check if GUI is active; only exit in batch mode
catch {
    if {[get_db is_gui_active] eq "true"} {
        puts "\[INFO\] Synthesis completed in GUI mode. Explore the schematic and timing in Genus!"
        gui_show
    } else {
        exit
    }
}
