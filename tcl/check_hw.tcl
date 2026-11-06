open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets]
puts "=== HW TARGETS DETECTED ==="
puts $targets
puts "==========================="
close_hw_manager
exit
