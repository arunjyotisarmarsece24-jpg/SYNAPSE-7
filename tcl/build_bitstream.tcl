# ==============================================================================
# Vivado Non-Project Batch Compilation Script for SYNAPSE-7
# Target Board: Digilent Arty S7 (Spartan-7 XC7S25-CSGA324-1)
# ==============================================================================

set outputDir ./build
file mkdir $outputDir

# 1. Read Verilog Sources
read_verilog -sv [glob ./rtl/neuromorphic/*.v]
read_verilog -sv [glob ./rtl/quantum_pqc/*.v]
read_verilog -sv [glob ./rtl/security/*.v]
read_verilog -sv [glob ./rtl/comms/*.v]
read_verilog -sv [glob ./rtl/top/*.v]

# 2. Read Timing and Physical Constraints
read_xdc ./constraints/arty_s7_master.xdc

# 3. Run Synthesis
puts "=== {SYNAPSE-7} Running Synthesis ==="
synth_design -top synapse7_top -part xc7s25csga324-1 -flatten_hierarchy rebuilt
write_checkpoint -force $outputDir/post_synth.dcp
report_utilization -file $outputDir/post_synth_utilization.rpt
report_timing_summary -file $outputDir/post_synth_timing.rpt

# 4. Run Logic Optimization and Placement
puts "=== {SYNAPSE-7} Running Logic Optimization and Placement ==="
opt_design
place_design
phys_opt_design
write_checkpoint -force $outputDir/post_place.dcp

# 5. Run Routing and Timing Closure
puts "=== {SYNAPSE-7} Running Routing ==="
route_design
write_checkpoint -force $outputDir/post_route.dcp
report_route_status -file $outputDir/post_route_status.rpt
report_timing_summary -file $outputDir/post_route_timing.rpt
report_power -file $outputDir/post_route_power.rpt
report_utilization -hierarchical -file $outputDir/hierarchical_utilization.rpt

# 6. Generate Bitstream
puts "=== {SYNAPSE-7} Generating Bitstream ==="
write_bitstream -force $outputDir/synapse7_arty_s7.bit
puts "=== {SYNAPSE-7} Build Completed Successfully! Bitstream: $outputDir/synapse7_arty_s7.bit ==="
