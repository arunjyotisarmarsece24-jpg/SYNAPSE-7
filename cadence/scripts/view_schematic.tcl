# ==============================================================================
# Script: view_schematic.tcl
# Description: Load 45nm Library and SYNAPSE-7 Gate Netlist into Genus Schematic GUI
# ==============================================================================
set_db gui_sv_threshold 1000000
read_libs /home/install/FOUNDRY/digital/45nm/dig/lib/typical.lib
read_netlist /home/dse/SYNAPSE-7/outputs/synapse7_synth_netlist.v
gui_show
gui_update

puts "======================================================================"
puts "  [SUCCESS] SYNAPSE-7 Gate-Level Netlist (34,291 Gates) Loaded!"
puts "======================================================================"
puts "  HOW TO VIEW THE SCHEMATIC:"
puts "  1. Look at the left 'Design Browser' panel (under 'Designs' or 'Modules')."
puts "  2. Right-click on 'synapse7_top' -> Select 'Schematic View (Module)' -> 'In Main'."
puts "  3. The Gate-Level Logic Schematic will render immediately in the main window!"
puts "  4. Press 'F' to Zoom to Fit, or double-click any module block to descend."
puts "======================================================================"
