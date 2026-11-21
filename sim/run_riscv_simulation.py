#!/usr/bin/env python3
"""
SYNAPSE-7 RISC-V Quantum SoC Simulation Runner
Compiles RV32I Processor Core, Quantum Neuromorphic Engine, and executes verification testbench.
"""

import os
import subprocess
import sys

VIVADO_BIN = r"C:\AMDDesignTools\2025.2\Vivado\bin"

def run_cmd(cmd, desc):
    print(f"\n[RISC-V SIM] === {desc} ===")
    res = subprocess.run(cmd, shell=True)
    if res.returncode != 0:
        print(f"[ERROR] Step '{desc}' failed with exit code {res.returncode}")
        sys.exit(res.returncode)

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_root)
    print(f"[RISC-V SIM] Running in: {repo_root}")

    # Gather sources
    verilog_files = []
    for root, _, files in os.walk(os.path.join(repo_root, "rtl")):
        for f in files:
            if f.endswith(".v") and "synapse7_top.v" not in f:
                verilog_files.append(os.path.join(root, f))
    
    # Add RISC-V testbench
    verilog_files.append(os.path.join(repo_root, "sim", "tb_riscv_quantum_soc.v"))

    xvlog = os.path.join(VIVADO_BIN, "xvlog.bat")
    xelab = os.path.join(VIVADO_BIN, "xelab.bat")
    xsim  = os.path.join(VIVADO_BIN, "xsim.bat")

    file_args = " ".join([f'"{f}"' for f in verilog_files])
    run_cmd(f'"{xvlog}" -sv {file_args}', "Compiling RISC-V SoC SystemVerilog Sources (xvlog)")
    run_cmd(f'"{xelab}" -top tb_riscv_quantum_soc -snapshot tb_riscv_snap', "Elaborating RISC-V SoC Snapshot (xelab)")
    run_cmd(f'"{xsim}" tb_riscv_snap -R', "Executing RISC-V Simulation (xsim)")
    print("\n[SUCCESS] RISC-V Quantum Neuromorphic Processor Architecture Passed Flawlessly!\n")

if __name__ == "__main__":
    main()
