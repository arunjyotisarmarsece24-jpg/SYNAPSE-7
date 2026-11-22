#!/bin/bash
# ==============================================================================
# Helper: open_genus_gui.sh
# Description: Launch Cadence Genus with SYNAPSE-7 Logic Schematic GUI
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cadence/scripts/setup_cadence_env.sh"
cd "$SCRIPT_DIR"

echo "======================================================================"
echo " Launching Cadence Genus Schematic GUI..."
echo " Loading Netlist: outputs/synapse7_synth_netlist.v (45nm GPDK)"
echo "======================================================================"

genus -gui -files "$SCRIPT_DIR/cadence/scripts/view_schematic.tcl"
