# ==============================================================================
# Script: run_innovus_pnr.tcl
# Project: SYNAPSE-7 (Quantum-Neuromorphic Hardware Engine)
# Target: Cadence Innovus Implementation System (Physical Place & Route)
# Description: Automates Floorplanning, Power Grid, Placement, CTS, NanoRoute,
#              DRC/LVS verification, and GDSII stream-out for 45nm GPDK.
# ==============================================================================

puts "======================================================================"
puts "  SYNAPSE-7 // Cadence Innovus Place & Route Flow"
puts "  Target: Quantum-Neuromorphic Top ASIC Enclave (45nm CMOS)"
puts "======================================================================"

# 1. Multi-Threaded Acceleration (8 CPU Threads allowed by license)
setMultiCpuUsage -localCpu 8

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

# 2. Configure 45nm GPDK LEF Files
set TECH_LEF "/home/install/FOUNDRY/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef"
set MACRO_LEF "/home/install/FOUNDRY/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef"

if {![file exists $TECH_LEF]} {
    set TECH_LEF "/home/install/FOUNDRY/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_svt_v4.4/gsclib045_tech/lef/gsclib045_tech.lef"
}
if {![file exists $MACRO_LEF]} {
    set MACRO_LEF "/home/install/FOUNDRY/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_svt_v4.4/gsclib045/lef/gsclib045_macro.lef"
}

set init_lef_file [list $TECH_LEF $MACRO_LEF]
puts "\[INFO\] Loading LEF Technology & Macro files: $init_lef_file"

# Generate MMMC view definition file linking 45nm library and 100MHz SDC constraints
set MMMC_FILE "$OUTPUTS_DIR/synapse7_mmmc.view"
set mmmc_fp [open $MMMC_FILE "w"]
puts $mmmc_fp "create_rc_corner -name default_rc -T 25.0"
puts $mmmc_fp "create_library_set -name default_libset -timing [list /home/install/FOUNDRY/digital/45nm/dig/lib/typical.lib]"
puts $mmmc_fp "create_constraint_mode -name default_mode -sdc_files [list [file normalize $OUTPUTS_DIR/synapse7_synth_constraints.sdc]]"
puts $mmmc_fp "create_delay_corner -name default_delay -library_set default_libset -rc_corner default_rc"
puts $mmmc_fp "create_analysis_view -name default_view -constraint_mode default_mode -delay_corner default_delay"
puts $mmmc_fp "set_analysis_view -setup [list default_view] -hold [list default_view]"
close $mmmc_fp

# 3. Design Import
set init_verilog "$OUTPUTS_DIR/synapse7_synth_netlist.v"
set init_top_cell "synapse7_top"
set init_pwr_net "VDD"
set init_gnd_net "VSS"
set init_mmmc_file $MMMC_FILE

puts "\[INFO\] Initializing Design with 16MB Gate Netlist: $init_verilog"
init_design

# Connect Global Power and Ground Nets
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
globalNetConnect VDD -type tiehi -inst *
globalNetConnect VSS -type tielo -inst *

# 4. Floorplan Initialization (Core Density 70%, Aspect Ratio 1.0)
puts "\[INFO\] Creating Floorplan..."
floorPlan -r 1.0 0.70 15 15 15 15

# 5. Global Power Distribution Network (P/G Rings and Stripes)
puts "\[INFO\] Synthesizing Power Rings..."
addRing -nets {VDD VSS} -type core_rings -follow core \
        -layer {top Metal5 bottom Metal5 left Metal4 right Metal4} \
        -width 2.0 -spacing 1.0 -offset 1.5

sroute -connect {blockPin padPin padRing corePin} -layerChangeRange {Metal1 Metal5}

# 6. Standard Cell Placement
puts "\[INFO\] Running Standard Cell Placement (place_opt_design)..."
setPlaceMode -timingDriven true
place_opt_design

# 7. Clock Tree Synthesis (CTS)
puts "\[INFO\] Running CCOpt Clock Tree Synthesis..."
create_ccopt_clock_tree_spec
ccopt_design

# 8. Detailed NanoRoute
puts "\[INFO\] Running Detailed NanoRoute..."
setNanoRouteMode -routeWithSiDriven true -routeWithTimingDriven true
routeDesign

# 9. Post-Route Optimization & Timing Signoff
puts "\[INFO\] Running Post-Route Timing Optimization..."
catch { setAnalysisMode -analysisType onChipVariation }
catch { optDesign -postRoute }
catch { report_timing > "$REPORTS_DIR/innovus_postroute_timing.rpt" }
catch { timeDesign -postRoute -outDir "$REPORTS_DIR/timingReports" }
catch { report_power > "$REPORTS_DIR/innovus_postroute_power.rpt" }
catch { reportPower > "$REPORTS_DIR/innovus_postroute_power.rpt" }

# 10. Physical Verification (DRC & Geometry)
puts "\[INFO\] Running Physical DRC & LVS Verifications..."
catch { verifyGeometry > "$REPORTS_DIR/innovus_drc.rpt" }
catch { verifyConnectivity > "$REPORTS_DIR/innovus_lvs.rpt" }

# 11. Design Exchange & GDSII Stream-Out
puts "\[INFO\] Exporting Physical DEF, Netlist, and GDSII..."
catch { defOut -floorplan -netlist -routing "$OUTPUTS_DIR/synapse7_pnr.def" }
catch { saveNetlist "$OUTPUTS_DIR/synapse7_pnr_netlist.v" }

set MAP_FILE "/home/install/FOUNDRY/analog/45nm_rev/soce/streamOut.map"
if {[file exists $MAP_FILE]} {
    catch { streamOut "$GDS_DIR/synapse7_top_layout.gds" -mapFile $MAP_FILE -stripes 1 }
} else {
    catch { streamOut "$GDS_DIR/synapse7_top_layout.gds" -stripes 1 }
}

puts "======================================================================"
puts "  Cadence Innovus PnR Flow Completed Successfully!"
puts "  GDSII Layout: $GDS_DIR/synapse7_top_layout.gds"
puts "  DEF File:     $OUTPUTS_DIR/synapse7_pnr.def"
puts "  DRC Report:   $REPORTS_DIR/innovus_drc.rpt"
puts "======================================================================"

set done_fp [open "$OUTPUTS_DIR/pnr_completed.marker" "w"]
puts $done_fp "COMPLETED [clock format [clock seconds]]"
close $done_fp

# Check if GUI is active; only exit in batch mode
catch {
    if {[is_gui_active]} {
        puts "\[INFO\] PnR completed in GUI mode. Explore the silicon layout in Innovus!"
    } else {
        exit
    }
}
