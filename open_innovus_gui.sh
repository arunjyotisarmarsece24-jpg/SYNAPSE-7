#!/bin/bash
# ==============================================================================
# Helper: open_innovus_gui.sh
# Description: Launch Cadence Innovus GUI with SYNAPSE-7 Silicon Layout
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cadence/scripts/setup_cadence_env.sh"
cd "$SCRIPT_DIR"

echo "======================================================================"
echo " Launching Cadence Innovus Silicon Layout GUI..."
echo " Loading DEF: outputs/synapse7_pnr.def (34,321 instances, 6 metal layers)"
echo "======================================================================"

innovus -win -files "$SCRIPT_DIR/cadence/scripts/view_layout.tcl"
