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

# 2. Design Import
set init_verilog "../outputs/synapse7_synth_netlist.v"
set init_top_cell "synapse7_top"
set init_pwr_net "VDD"
set init_gnd_net "VSS"
set init_mmmc_file "../outputs/synapse7_synth_constraints.sdc"

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
optDesign -postRoute
report_timing > "../reports/innovus_postroute_timing.rpt"
report_power  > "../reports/innovus_postroute_power.rpt"

# 9. Physical Verification (DRC & Geometry)
verifyGeometry > "../reports/innovus_drc.rpt"
verifyConnectivity > "../reports/innovus_lvs.rpt"

# 10. GDSII Stream-Out
file mkdir "../gds"
streamOut "../gds/synapse7_top_layout.gds" -mapFile "gds2.map" -merge "standard_cells.gds" -stripes 1

puts "======================================================================"
puts "  Cadence Innovus PnR Flow Completed Successfully!"
puts "  GDSII Layout: gds/synapse7_top_layout.gds"
puts "======================================================================"
exit
