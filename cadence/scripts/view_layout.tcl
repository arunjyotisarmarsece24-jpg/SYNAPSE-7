# ==============================================================================
# Script: view_layout.tcl
# Project: SYNAPSE-7 (Quantum Neuromorphic Hardware Engine)
# Description: Silicon Layout & Routing Inspection in Cadence Innovus GUI
# ==============================================================================
set TECH_LEF "/home/install/FOUNDRY/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef"
set MACRO_LEF "/home/install/FOUNDRY/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef"
set init_lef_file [list $TECH_LEF $MACRO_LEF]
set init_verilog "outputs/synapse7_pnr_netlist.v"
set init_top_cell "synapse7_top"
set init_pwr_net "VDD"
set init_gnd_net "VSS"
set init_mmmc_file "outputs/synapse7_mmmc.view"

init_design
defIn outputs/synapse7_pnr.def
win
fit

puts "======================================================================"
puts "  SYNAPSE-7 Physical ASIC Silicon Layout Loaded Successfully!"
puts "  - Press 'F' to Fit the whole chip"
puts "  - Press 'Z' then drag to Zoom in on gates/wires"
puts "  - Use the Layer Control panel on the right to toggle Metal1-Metal6"
puts "======================================================================"
