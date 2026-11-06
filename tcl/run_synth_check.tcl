# Quick synthesis check script for utilization extraction
set outputDir ./synth_check_out
file mkdir $outputDir

read_verilog -sv [glob ./rtl/neuromorphic/*.v]
read_verilog -sv [glob ./rtl/quantum_pqc/*.v]
read_verilog -sv [glob ./rtl/security/*.v]
read_verilog -sv [glob ./rtl/comms/*.v]
read_verilog -sv [glob ./rtl/top/*.v]
read_xdc ./constraints/arty_s7_master.xdc

synth_design -top synapse7_top -part xc7s25csga324-1
report_utilization -file $outputDir/utilization.rpt
report_timing_summary -file $outputDir/timing.rpt
