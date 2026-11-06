# ==============================================================================
# SYNAPSE-7 One-Click Bitstream Programmer for Digilent Arty S7
# ==============================================================================
open_hw_manager
connect_hw_server -allow_non_jtag

set targets [get_hw_targets]
if {[llength $targets] == 0} {
    puts "ERROR: No hardware targets detected! Please ensure Arty S7 USB cable is plugged in."
    exit 1
}

open_hw_target [lindex $targets 0]
set device [lindex [get_hw_devices] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

set bitfile "./build/synapse7_arty_s7.bit"
if {![file exists $bitfile]} {
    set bitfile "./synth_check_out/synapse7_top.bit"
}

puts "=== [SYNAPSE-7] Programming Spartan-7 Device: $device with $bitfile ==="
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device [lindex [get_hw_devices] 0]
puts "=== [SYNAPSE-7] FPGA Programmed Successfully! Running SYNAPSE-7 Core. ==="
close_hw_manager
exit
