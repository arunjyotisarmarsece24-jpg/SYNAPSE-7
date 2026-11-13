## ============================================================================
## SYNAPSE-7 Physical Constraints File (.xdc)
## Target Board: Digilent Arty S7-50 (AMD-Xilinx Spartan-7 XC7S50-CSGA324-1)
## ============================================================================

## 100MHz System Clock
set_property -dict { PACKAGE_PIN R2    IOSTANDARD SSTL135 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports { clk }];

## Active-Low Reset (Button 0)
set_property -dict { PACKAGE_PIN C18   IOSTANDARD LVCMOS33 } [get_ports { rst_btn }];

## Diagnostic LEDs (LD2..LD5)
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { leds[0] }];
set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33 } [get_ports { leds[1] }];
set_property -dict { PACKAGE_PIN E13   IOSTANDARD LVCMOS33 } [get_ports { leds[2] }];
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { leds[3] }];

## RGB LED 0 (LD0)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { rgb0_red }];
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { rgb0_green }];
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { rgb0_blue }];

## USB-UART Interface (Default On-Board FTDI)
set_property -dict { PACKAGE_PIN R12   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { uart_rx }];

## Pmod Header JA (Dedicated ESP8266 WiFi Bridge Interface)
## Pin 1 (L17): ESP8266 RX (FPGA TX alternative)
## Pin 2 (L18): ESP8266 TX (FPGA RX alternative)
## Pin 3 (M14): ESP8266 GPIO0 / Handshake
## Pin 4 (N14): ESP8266 Reset
# set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { pmod_ja_pin1 }];
# set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { pmod_ja_pin2 }];

## Timing & Voltage Configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
