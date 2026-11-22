# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.14-s082_1 on Sun Nov 22 14:33:15 IST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design synapse7_top

create_clock -name "CLK100MHZ" -period 10.0 -waveform {0.0 5.0} [get_ports CLK100MHZ]
set_clock_transition 0.15 [get_clocks CLK100MHZ]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {sw[3]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {sw[2]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {sw[1]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {sw[0]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {btn[3]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {btn[2]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {btn[1]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {btn[0]}]
set_input_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports uart_rxd]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {led[3]}]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {led[2]}]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {led[1]}]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports {led[0]}]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports led0_r]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports led0_g]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports led0_b]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports led1_r]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports led1_g]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports led1_b]
set_output_delay -clock [get_clocks CLK100MHZ] -add_delay 2.0 [get_ports uart_txd]
set_wire_load_mode "enclosed"
set_clock_uncertainty -setup 0.25 [get_clocks CLK100MHZ]
set_clock_uncertainty -hold 0.25 [get_clocks CLK100MHZ]
