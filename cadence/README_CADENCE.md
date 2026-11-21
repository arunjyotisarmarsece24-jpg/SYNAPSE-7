# Cadence EDA & GPU Simulation Guide for SYNAPSE-7

This document provides complete instructions for executing Cadence EDA flows (Virtuoso, Genus, Innovus, and Spectre) and utilizing Free / Lab GPUs for the **SYNAPSE-7 Quantum-Neuromorphic Engine**.

---

## 1. Remote Server Access & Credentials (`dse@172.16.36.157`)

### About Server Passwords
- **Private University Server**: The IP `172.16.36.157` (`dtiresearch`) is a private internal network server at your lab (IIT BHU Research Lab).
- **Passwords are Managed Locally**: As an AI assistant, I do not possess or store private institutional credentials. Your department system administrator or research supervisor manages user passwords.
- **Good News**: In your MobaXterm terminal snippet, **you are ALREADY successfully authenticated and logged in**:
  ```text
  Last login: Sat Nov 21 15:27:17 2026
  [dse@dtiresearch ~]$
  ```
  While your terminal is at `[dse@dtiresearch ~]$`, you can directly run all commands, check GPUs, compile code, and launch Cadence without needing to re-enter a password (unless executing root commands via `sudo`).

---

## 2. Checking & Activating GPUs on `dtiresearch`

Run these commands directly in your active MobaXterm shell to check for hardware GPUs:

```bash
# 1. Check NVIDIA GPU presence and memory
nvidia-smi

# 2. Check PCI hardware bus for graphics controllers
lspci | grep -i -E "nvidia|vga|3d"

# 3. Check CPU core count and system memory
lscpu | grep "CPU(s):"
free -h
```

### If NVIDIA GPUs are Present:
You can immediately accelerate Cadence Spectre matrix solvers and run PyTorch/PennyLane Quantum SNN simulations:
```bash
# Check CUDA version
nvcc --version
```

---

## 3. Controlling Cadence Tools with MobaXterm (X11 Forwarding)

Your MobaXterm session already indicates:
```text
• X11-forwarding : ✓ (remote display is forwarded through SSH)
```
This means graphical windows launched on `dtiresearch` will seamlessly render as desktop windows on your Windows computer!

### Step 3.1: Initialize Cadence Environment
In your MobaXterm terminal on `dtiresearch`:
```bash
# Clone or copy your project repository if not already on the server:
git clone https://github.com/arunjyotisarmarsece24-jpg/SYNAPSE-7.git
cd SYNAPSE-7

# Make the setup script executable and source it:
chmod +x cadence/scripts/setup_cadence_env.sh
source cadence/scripts/setup_cadence_env.sh
```

### Step 3.2: Launch Cadence Virtuoso (Schematic & Layout GUI)
```bash
virtuoso &
```
*A native Cadence Virtuoso window will appear on your Windows monitor.*

### Step 3.3: Run Cadence Genus ASIC Synthesis (Batch Mode)
To synthesize the full Quantum-Neuromorphic RTL:
```bash
genus -f cadence/scripts/run_genus_synth.tcl
```
*Outputs: Gate-level netlist in `outputs/` and timing/area/power reports in `reports/`.*

### Step 3.4: Run Cadence Innovus Place & Route (Physical Layout)
```bash
innovus -f cadence/scripts/run_innovus_pnr.tcl
```
*Outputs: GDSII physical layout in `gds/synapse7_top_layout.gds`.*

### Step 3.5: Run Cadence Spectre (Analog Quantum Memristor Simulation)
```bash
# Run multi-threaded Spectre simulation:
spectre +preset=cx +aps +mt=16 cadence/scripts/quantum_memristor_spectre.scs
```

---

## 4. Free GPU Alternatives for Quantum Neuromorphic Training

If `dtiresearch` does not have dedicated GPUs or you want free cloud GPU compute:

| Platform | Free GPU Specs | Free Allocation | Best Use Case |
| :--- | :--- | :--- | :--- |
| **Google Colab** | NVIDIA T4 (15 GB VRAM) | Free continuous sessions | Training Q-SNN models, PyTorch, PennyLane |
| **Kaggle** | 2x NVIDIA T4 or P100 (16 GB) | 30 hours / week | Large batch quantum phase benchmark |
| **Lightning AI** | NVIDIA T4 / A10G | 15-22 free credits/month | Interactive VSCode IDE with cloud GPUs |
| **Hugging Face Spaces** | Community T4 / ZeroGPU | Free community tier | Hosting live WebGL/API dashboards |

See `software/quantum_neuromorphic_sim.py` and `software/SYNAPSE7_Quantum_Neuromorphic_Colab.ipynb` for complete GPU simulation code.
