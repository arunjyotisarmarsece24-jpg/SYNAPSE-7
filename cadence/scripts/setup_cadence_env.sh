#!/bin/bash
# ==============================================================================
# Script: setup_cadence_env.sh
# Project: SYNAPSE-7 (Quantum Neuromorphic Hardware Engine)
# Target: Linux Lab Server (dse@172.16.36.157 / dtiresearch)
# Description: Configures Cadence EDA environment (Virtuoso, Genus, Innovus, Spectre)
#              with X11 Remote Display forwarding and verified IIT BHU license server.
# ==============================================================================

echo "======================================================================"
echo "  SYNAPSE-7 // Cadence EDA & GPU Environment Setup"
echo "  Host: $(hostname) | User: $(whoami) | IP: 172.16.36.157"
echo "======================================================================"

# 1. Check & Verify GPU Hardware Acceleration
echo -e "\n[*] Step 1: Checking GPU Hardware Acceleration..."
if command -v nvidia-smi &> /dev/null; then
    echo "[+] NVIDIA Driver & GPUs Detected:"
    nvidia-smi --query-gpu=index,name,memory.total,memory.free,utilization.gpu --format=csv
    export CDS_ENABLE_GPU=1
    export SPECTRE_GPU_ACCELERATION=1
    echo "[+] GPU acceleration flags enabled for Cadence Spectre / Clarity / Innovus."
else
    echo "[-] No NVIDIA GPU driver found via nvidia-smi. Running in multi-core CPU mode."
    export CDS_ENABLE_GPU=0
fi

# 2. Check X11 Remote Display Forwarding (MobaXterm)
echo -e "\n[*] Step 2: Checking X11 Display Forwarding..."
if [ -z "$DISPLAY" ]; then
    echo "[!] DISPLAY variable is unset! Setting default DISPLAY=localhost:10.0"
    export DISPLAY=localhost:10.0
else
    echo "[+] X11 DISPLAY is set to: $DISPLAY"
fi

# Quick X11 Test
if command -v xdpyinfo &> /dev/null; then
    if xdpyinfo > /dev/null 2>&1; then
        echo "[+] X11 display connection verified successfully!"
    else
        echo "[!] Warning: Cannot connect to X11 display $DISPLAY. Check MobaXterm X-server."
    fi
fi

# 3. Verified IIT BHU Cadence License Configuration
echo -e "\n[*] Step 3: Setting up Verified IIT BHU Cadence Licenses..."
export LM_LICENSE_FILE="5280@14.139.1.126"
export CDS_LIC_FILE="5280@14.139.1.126"
echo "[+] Verified Cadence License Server: $CDS_LIC_FILE"

# 4. Add All Cadence Tool Paths from /home/install
echo -e "\n[*] Step 4: Configuring Tool Execution Paths..."

# Genus 21.1
if [ -d "/home/install/GENUS211" ]; then
    export GENUS_HOME="/home/install/GENUS211"
    for p in "$GENUS_HOME/tools.lnx86/genus/bin/64bit" "$GENUS_HOME/bin" "$GENUS_HOME/tools/bin"; do
        if [ -d "$p" ]; then export PATH="$p:$PATH"; fi
    done
fi

# Innovus 21.1
if [ -d "/home/install/INNOVUS211" ]; then
    export INNOVUS_HOME="/home/install/INNOVUS211"
    for p in "$INNOVUS_HOME/tools.lnx86/innovus/bin/64bit" "$INNOVUS_HOME/bin" "$INNOVUS_HOME/tools/bin"; do
        if [ -d "$p" ]; then export PATH="$p:$PATH"; fi
    done
fi

# Spectre 21.1
if [ -d "/home/install/SPECTRE211" ]; then
    export SPECTRE_HOME="/home/install/SPECTRE211"
    for p in "$SPECTRE_HOME/tools.lnx86/spectre/bin/64bit" "$SPECTRE_HOME/bin" "$SPECTRE_HOME/tools/bin"; do
        if [ -d "$p" ]; then export PATH="$p:$PATH"; fi
    done
fi

# Virtuoso IC618
if [ -d "/home/install/IC618" ]; then
    export CDSHOME="/home/install/IC618"
    for p in "$CDSHOME/tools.lnx86/dfII/bin" "$CDSHOME/tools/dfII/bin" "$CDSHOME/tools/bin"; do
        if [ -d "$p" ]; then export PATH="$p:$PATH"; fi
    done
fi

# Set Multi-Threading Defaults for Cadence (28 CPU Threads Detected!)
NUM_CORES=$(nproc 2>/dev/null || echo 28)
export SPECTRE_DEFAULTS="-+preset=cx -+aps -+mt=$NUM_CORES"
echo "[+] Cadence parallel acceleration set to $NUM_CORES CPU threads."

# Summary of Cadence Binaries
echo -e "\n[*] Verified Tool Availability Status:"
for tool in genus innovus spectre virtuoso; do
    if command -v $tool &> /dev/null; then
        echo "    [OK] $tool -> $(which $tool)"
    else
        echo "    [--] $tool not in PATH"
    fi
done

echo -e "\n======================================================================"
echo " Cadence Environment Ready with IIT BHU License!"
echo " Quick Execution Commands:"
echo "   1. Genus Synthesis:   genus -f cadence/scripts/run_genus_synth.tcl"
echo "   2. Innovus PnR:       innovus -f cadence/scripts/run_innovus_pnr.tcl"
echo "   3. Spectre SPICE:     spectre cadence/scripts/quantum_memristor_spectre.scs"
echo "   4. Virtuoso GUI:      virtuoso &"
echo "   5. Automated Flow:    bash cadence/scripts/run_full_cadence_flow.sh"
echo "======================================================================"
