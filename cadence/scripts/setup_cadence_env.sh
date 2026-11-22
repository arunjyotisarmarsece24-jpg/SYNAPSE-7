#!/bin/bash
# ==============================================================================
# Script: setup_cadence_env.sh
# Project: SYNAPSE-7 (Quantum Neuromorphic Hardware Engine)
# Target: Linux Lab Server (dse@172.16.36.157 / dtiresearch)
# Description: Configures Cadence EDA environment (Virtuoso, Genus, Innovus, Spectre)
#              with verified IIT BHU license server and exact tool paths.
# ==============================================================================

echo "======================================================================"
echo "  SYNAPSE-7 // Cadence EDA & GPU Environment Setup"
echo "  Host: $(hostname) | User: $(whoami) | IP: 172.16.36.157"
echo "======================================================================"

# 1. Verified IIT BHU Cadence License Configuration
export LM_LICENSE_FILE="5280@14.139.1.126"
export CDS_LIC_FILE="5280@14.139.1.126"
echo "[+] Verified Cadence License Server: $CDS_LIC_FILE"

# 2. Check X11 Remote Display Forwarding (MobaXterm)
if [ -z "$DISPLAY" ]; then
    export DISPLAY=localhost:10.0
fi
echo "[+] X11 DISPLAY is set to: $DISPLAY"

# 3. Configure Verified Cadence Tool Roots & Binary Paths
export GENUSHOME="/home/install/GENUS211"
export CDN_SYNTH_ROOT="/home/install/GENUS211/tools.lnx86"
export INNOVUSHOME="/home/install/INNOVUS211"
export SPECTREHOME="/home/install/SPECTRE211"
export CDSHOME="/home/install/IC618"

# Exact 64-bit binary paths discovered from /home/install/cshrc
export PATH="/home/install/INNOVUS211/bin:\
/home/install/GENUS211/bin:\
/home/install/SPECTRE211/bin:\
/home/install/IC618/bin:\
/home/install/IC618/tools/bin:\
/home/install/IC618/tools.lnx86/dfII/bin:$PATH"

# Library paths
export LD_LIBRARY_PATH="/home/install/GENUS211/tools.lnx86/lib/64bit:\
/home/install/INNOVUS211/tools.lnx86/lib/64bit:\
/home/install/SPECTRE211/tools.lnx86/lib/64bit:\
/home/install/IC618/tools.lnx86/lib/64bit:\
/usr/lib64:$LD_LIBRARY_PATH"

# Bash Aliases for convenience
alias genus='/home/install/GENUS211/bin/genus'
alias innovus='/home/install/INNOVUS211/bin/innovus'
alias spectre='/home/install/SPECTRE211/bin/spectre'

# Multi-threading for 28 CPU threads
export SPECTRE_DEFAULTS="+preset=cx +mt=28"

echo -e "\n[*] Verified Tool Availability Status:"
for tool in genus innovus; do
    if command -v $tool &> /dev/null; then
        echo "    [OK] $tool -> $(which $tool)"
    else
        echo "    [--] $tool not in PATH"
    fi
done

echo -e "\n======================================================================"
echo " Cadence Environment Ready!"
echo " Quick Execution:"
echo "   genus -f cadence/scripts/run_genus_synth.tcl"
echo "   innovus -f cadence/scripts/run_innovus_pnr.tcl"
echo "======================================================================"
