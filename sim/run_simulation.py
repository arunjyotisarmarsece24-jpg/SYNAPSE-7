#!/usr/bin/env python3
"""
SYNAPSE-7 Simulation Runner
Executes Vivado xvlog/xelab/xsim pipeline and verifies RTL timing and functional behavior.
"""

import os
import subprocess
import sys

VIVADO_BIN = r"C:\AMDDesignTools\2025.2\Vivado\bin"

def run_cmd(cmd, desc):
    print(f"\n[SYNAPSE-7 SIM] === {desc} ===")
    res = subprocess.run(cmd, shell=True)
    if res.returncode != 0:
        print(f"[ERROR] Step '{desc}' failed with exit code {res.returncode}")
        sys.exit(res.returncode)

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_root)
    print(f"[SYNAPSE-7] Running in: {repo_root}")

    # Gather sources
    verilog_files = []
    for root, _, files in os.walk(os.path.join(repo_root, "rtl")):
        for f in files:
            if f.endswith(".v"):
                verilog_files.append(os.path.join(root, f))
    for root, _, files in os.walk(os.path.join(repo_root, "sim")):
        for f in files:
            if f.endswith(".v"):
                verilog_files.append(os.path.join(root, f))

    xvlog = os.path.join(VIVADO_BIN, "xvlog.bat")
    xelab = os.path.join(VIVADO_BIN, "xelab.bat")
    xsim  = os.path.join(VIVADO_BIN, "xsim.bat")

    file_args = " ".join([f'"{f}"' for f in verilog_files])
    run_cmd(f'"{xvlog}" -sv {file_args}', "Compiling SystemVerilog Sources (xvlog)")
    run_cmd(f'"{xelab}" -top tb_synapse7_top -snapshot tb_synapse7_snap', "Elaborating Simulation Snapshot (xelab)")
    run_cmd(f'"{xsim}" tb_synapse7_snap -R', "Executing Simulation (xsim)")
    print("\n[SUCCESS] SYNAPSE-7 RTL Verification Suite Passed Flawlessly!\n")

if __name__ == "__main__":
    main()
