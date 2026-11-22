# ==============================================================================
# Script: run_innovus_pnr.tcl
# Project: SYNAPSE-7 (Quantum-Neuromorphic Hardware Engine)
# Target: Cadence Innovus Implementation System (Physical Place & Route)
# Description: Automates Floorplanning, Power Grid, Placement, CTS, NanoRoute,
#              DRC/LVS verification, and GDSII stream-out.
# ==============================================================================

puts "======================================================================"
puts "  SYNAPSE-7 // Cadence Innovus Place & Route Flow"
puts "  Target: Quantum-Neuromorphic Top ASIC Enclave"
puts "======================================================================"

# 1. Multi-Threaded Acceleration
setMultiCpuUsage -localCpu 16

# Determine Project Root Directory automatically
if {[file exists "outputs/synapse7_synth_netlist.v"]} {
    set PROJ_ROOT "."
} elseif {[file exists "../outputs/synapse7_synth_netlist.v"]} {
    set PROJ_ROOT ".."
} else {
    set PROJ_ROOT [file normalize "[file dirname [info script]]/../.."]
}
set OUTPUTS_DIR "$PROJ_ROOT/outputs"
set REPORTS_DIR "$PROJ_ROOT/reports"
set GDS_DIR "$PROJ_ROOT/gds"

file mkdir $REPORTS_DIR
file mkdir $OUTPUTS_DIR
file mkdir $GDS_DIR

# 2. Design Import
set init_verilog "$OUTPUTS_DIR/synapse7_synth_netlist.v"
set init_top_cell "synapse7_top"
set init_pwr_net "VDD"
set init_gnd_net "VSS"
set init_mmmc_file "$OUTPUTS_DIR/synapse7_synth_constraints.sdc"

puts "\[INFO\] Loading gate-level netlist: $init_verilog"
init_design

# 3. Floorplan Initialization (Core Utilization 70%, Aspect Ratio 1.0)
puts "\[INFO\] Initializing Floorplan..."
floorPlan -site CoreSite -r 1.0 0.70 15 15 15 15

# 4. Global Power Network (P/G Rings and Stripes)
puts "\[INFO\] Synthesizing Power Rings..."
addRing -nets {VDD VSS} -type core_rings -follow core \
        -layer {top Metal5 bottom Metal5 left Metal4 right Metal4} \
        -width 2.0 -spacing 1.0 -offset 1.5

sroute -connect {blockPin padPin padRing corePin} -layerChangeRange {Metal1 Metal5}

# 5. Standard Cell Placement
puts "\[INFO\] Running Standard Cell Placement (place_opt_design)..."
setPlaceMode -prerouteResourceBudget true
place_opt_design

# 6. Clock Tree Synthesis (CTS)
puts "\[INFO\] Running CCOpt Clock Tree Synthesis..."
create_ccopt_clock_tree_spec
ccopt_design

# 7. Detailed NanoRoute
puts "\[INFO\] Running Detailed NanoRoute..."
setNanoRouteMode -routeWithSiDriven true -routeWithTimingDriven true
routeDesign

# 8. Post-Route Optimization & Timing Signoff
puts "\[INFO\] Running Post-Route Timing Optimization..."
optDesign -postRoute
report_timing > "$REPORTS_DIR/innovus_postroute_timing.rpt"
report_power  > "$REPORTS_DIR/innovus_postroute_power.rpt"

# 9. Physical Verification (DRC & Geometry)
puts "\[INFO\] Running Physical DRC & LVS Verifications..."
verifyGeometry > "$REPORTS_DIR/innovus_drc.rpt"
verifyConnectivity > "$REPORTS_DIR/innovus_lvs.rpt"

# 10. Design Exchange & GDSII Stream-Out
puts "\[INFO\] Exporting Physical DEF, Netlist, and GDSII..."
defOut -floorplan -netlist -routing "$OUTPUTS_DIR/synapse7_pnr.def"
saveNetlist "$OUTPUTS_DIR/synapse7_pnr_netlist.v"

if {[file exists "gds2.map"]} {
    streamOut "$GDS_DIR/synapse7_top_layout.gds" -mapFile "gds2.map" -merge "standard_cells.gds" -stripes 1
} else {
    streamOut "$GDS_DIR/synapse7_top_layout.gds" -stripes 1
}

puts "======================================================================"
puts "  Cadence Innovus PnR Flow Completed Successfully!"
puts "  GDSII Layout: $GDS_DIR/synapse7_top_layout.gds"
puts "  DEF File:     $OUTPUTS_DIR/synapse7_pnr.def"
puts "  Reports:      $REPORTS_DIR/innovus_drc.rpt"
puts "======================================================================"
exit
