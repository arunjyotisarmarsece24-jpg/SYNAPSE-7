"""
Brutal Cyberpunk Terminal HUD for SYNAPSE-7
Real-time telemetry, quantum statevector matrix display, Steane syndrome tracker,
and Money-Heist cryptocurrency transaction defense monitor.
"""

import sys
import time
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.layout import Layout
from rich.live import Live
from rich.text import Text

from ..core.statevector import QuantumState
from ..core.gates import GATE_H, GATE_X
from ..qec.steane_code import Steane7QubitCode
from ..crypto.cyber_vault import CyberVault7, QuantumProofTransaction
from ..crypto.qkd_bb84 import BB84QKDProtocol

def generate_header() -> Panel:
    title = """
   ███████╗██╗   ██╗███╗   ██╗ █████╗ ██████╗ ███████╗███████╗      ███████╗
   ██╔════╝╚██╗ ██╔╝████╗  ██║██╔══██╗██╔══██╗██╔════╝██╔════╝      ╚════██║
   ███████╗ ╚████╔╝ ██╔██╗ ██║███████║██████╔╝███████╗█████╗  █████╗    ██╔╝
   ╚════██║  ╚██╔╝  ██║╚██╗██║██╔══██║██╔═══╝ ╚════██║██╔══╝  ╚════╝   ██╔╝ 
   ███████║   ██║   ██║ ╚████║██║  ██║██║     ███████║███████╗         ██║  
   ╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝         ╚═╝  
    [SCALABLE YIELD NON-ABELIAN ACCELERATED POST-QUANTUM ENGINE FOR SPARTAN-7]
    IIT BHU Department of Electronics Engineering | Lead: Arunjyoti Sarma
    """
    return Panel(Text(title, style="bold cyan"), border_style="bright_magenta")

def build_status_table(vault: CyberVault7, qkd_data: dict) -> Table:
    table = Table(title="[bold yellow]HARDWARE & CRYPTOGRAPHIC TELEMETRY[/bold yellow]", border_style="cyan")
    table.add_column("Subsystem", style="bold green", width=22)
    table.add_column("Operational State", style="white", width=24)
    table.add_column("Quantum Metric / Entropy", style="bold magenta", width=34)

    table.add_row("FPGA Target", "Arty S7-50 (Spartan-7)", "XC7S50-CSGA324 (100MHz DSP48E1)")
    table.add_row("Wireless Edge Node", "ESP8266 NodeMCU", "UART 115200 bps Mesh Escrow")
    table.add_row("QEC Architecture", "[[7, 1, 3]] Steane Code", "CSS Dual-Hamming (Distance d=3)")
    table.add_row("PQC Algorithm", "Ring-LWE Lattice", "Z_q[x]/(x^256+1), q=12289 (128-bit PQC)")
    table.add_row("BB84 QKD Channel", qkd_data["status"], f"QBER: {qkd_data['qber_percent']}% (Threshold < 11%)")
    table.add_row("CyberVault Ledger", f"{len(vault.ledger)} TXs Committed", f"Entropy Pool: {len(vault.entropy_pool)} Bytes")
    return table

def launch_cyber_hud():
    console = Console()
    console.clear()
    console.print(generate_header())

    vault = CyberVault7()
    console.print("[bold yellow]⚡ Initializing Quantum Core & Steane Stabilizers...[/bold yellow]")
    
    # Run initial QKD key generation
    qkd = BB84QKDProtocol(num_photons=512)
    qkd_res = qkd.run_exchange(eavesdropper_present=False)
    vault.recharge_quantum_entropy()

    console.print(build_status_table(vault, qkd_res))
    console.print("\n[bold green]✓ Master Quantum Software Engine Active.[/bold green]")
    console.print("[dim cyan]Ready for Spartan-7 bitstream deployment and ESP8266 telemetry link.[/dim cyan]\n")

if __name__ == "__main__":
    launch_cyber_hud()
