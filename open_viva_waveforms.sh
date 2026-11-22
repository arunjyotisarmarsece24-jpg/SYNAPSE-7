#!/bin/bash
# ==============================================================================
# Helper: open_viva_waveforms.sh
# Description: Launch Cadence ViVA Waveform Viewer for Spectre SPICE Results
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cadence/scripts/setup_cadence_env.sh"
cd "$SCRIPT_DIR"

echo "======================================================================"
echo " Launching Cadence ViVA (Virtuoso Visualization & Analysis)..."
echo " Dataset: cadence/scripts/quantum_memristor_spectre.raw/tran_sim.tran.tran"
echo "======================================================================"

/home/install/IC618/bin/viva &
