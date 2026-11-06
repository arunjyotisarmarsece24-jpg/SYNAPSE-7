@echo off
title SYNAPSE-7 // FPGA Programmer
echo ==============================================================================
echo   SYNAPSE-7: Programming Spartan-7 on Digilent Arty S7
echo ==============================================================================
"C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -source tcl/program_fpga.tcl -nolog -nojournal
pause
