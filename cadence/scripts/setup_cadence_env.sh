#!/bin/bash
# ==============================================================================
# Script: setup_cadence_env.sh
# Project: SYNAPSE-7 (Quantum Neuromorphic Hardware Engine)
# Target: Linux Lab Server (dse@172.16.36.157 / dtiresearch)
# Description: Configures Cadence EDA environment (Virtuoso, Genus, Innovus, Spectre)
#              with X11 Remote Display forwarding and GPU Acceleration checks.
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

# 3. Environment & License Configuration for Cadence
echo -e "\n[*] Step 3: Setting up Cadence Licenses & Paths..."

# License file environment
if [ -z "$CDS_LIC_FILE" ] && [ -z "$LM_LICENSE_FILE" ]; then
    export CDS_LIC_FILE="5280@172.16.36.157:5280@172.16.36.1:5280@licserver.iitbhu.ac.in"
    export LM_LICENSE_FILE=$CDS_LIC_FILE
    echo "[+] Set default Cadence license pointers: $CDS_LIC_FILE"
else
    echo "[+] License pointer already active: ${CDS_LIC_FILE:-$LM_LICENSE_FILE}"
fi

# If Environment Modules are used in the lab:
if command -v module &> /dev/null; then
    echo "[+] Environment Modules detected. Loading Cadence tools..."
    module load cadence/virtuoso 2>/dev/null || module load virtuoso 2>/dev/null || true
    module load cadence/genus 2>/dev/null || module load genus 2>/dev/null || true
    module load cadence/innovus 2>/dev/null || module load innovus 2>/dev/null || true
    module load cadence/spectre 2>/dev/null || module load spectre 2>/dev/null || true
fi

# Auto-discover common Cadence installation paths if binaries not in PATH
POSSIBLE_CADENCE_ROOTS=(
    "/tools/cadence"
    "/opt/cadence"
    "/eda/cadence"
    "/cadence"
    "/usr/local/cadence"
)

for root in "${POSSIBLE_CADENCE_ROOTS[@]}"; do
    if [ -d "$root" ]; then
        echo "[+] Found Cadence root at: $root"
        for bindir in $(find "$root" -maxdepth 3 -type d -name "bin" 2>/dev/null); do
            export PATH="$bindir:$PATH"
        done
        break
    fi
done

# Set Multi-Threading Defaults for Cadence Spectre
NUM_CORES=$(nproc 2>/dev/null || echo 8)
export SPECTRE_DEFAULTS="-+preset=cx -+aps -+mt=$NUM_CORES"
echo "[+] Spectre parallel acceleration set to $NUM_CORES CPU threads."

# Summary of Cadence Binaries
echo -e "\n[*] Tool Availability Status:"
for tool in genus innovus spectre virtuoso simvision; do
    if command -v $tool &> /dev/null; then
        echo "    [OK] $tool -> $(which $tool)"
    else
        echo "    [--] $tool not in PATH (check module load or ask lab admin)"
    fi
done

echo -e "\n======================================================================"
echo " Cadence Environment Ready!"
echo " Quick Execution Commands:"
echo "   1. Genus Synthesis:   genus -f cadence/scripts/run_genus_synth.tcl"
echo "   2. Innovus PnR:       innovus -f cadence/scripts/run_innovus_pnr.tcl"
echo "   3. Spectre SPICE:     spectre cadence/scripts/quantum_memristor_spectre.scs"
echo "   4. Virtuoso GUI:      virtuoso &"
echo "   5. Automated Flow:    bash cadence/scripts/run_full_cadence_flow.sh"
echo "======================================================================"
