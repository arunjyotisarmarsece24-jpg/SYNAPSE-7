#!/usr/bin/env python3
"""
===============================================================================
SYNAPSE-7 CLI Host Controller & Hardware Diagnostic Suite
Project: SYNAPSE-7 (Neuromorphic-Quantum Hardware Security on Spartan-7)
===============================================================================
Provides direct serial communication, continuous live ASCII telemetry streaming,
and command injection directly into the Arty S7 FPGA.
"""

import sys
import time
import serial
import serial.tools.list_ports

BAUD_RATE = 115200

def find_arty_s7():
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        desc = p.description.upper()
        if "FTDI" in desc or "USB SERIAL" in desc or "DIGILENT" in desc:
            return p.device
    return None

def monitor_live(port_name):
    print(f"[SYNAPSE-7] Connecting to Arty S7 on {port_name} @ {BAUD_RATE} baud...")
    ser = serial.Serial(port_name, BAUD_RATE, timeout=0.5)

    print("\n" + "=" * 80)
    print("  SEQ | SPIKES   | THREAT | LEVEL    | TRIPWIRE | TEMP(C) | VCCINT(V) | PQC CYC")
    print("=" * 80)

    try:
        while True:
            header = ser.read(2)
            if header == b'\xAA\x55':
                payload = ser.read(14)
                if len(payload) == 14:
                    seq = payload[0]
                    spikes = f"{payload[1]:08b}"
                    threat = payload[2]
                    flags = payload[3]
                    tripwire = "LOCKED" if (flags >> 7) & 1 else "SECURE"
                    lvl_code = (flags >> 5) & 3
                    levels = ["SAFE", "CAUTION", "CRITICAL", "UNKNOWN"]
                    level = levels[lvl_code]
                    
                    pqc_cyc = payload[5] | (payload[6] << 8)
                    temp_raw = payload[9] | ((payload[10] >> 4) << 8)
                    vcc_raw = payload[11] | ((payload[10] & 0x0F) << 8)
                    temp = (temp_raw * 503.975 / 4096.0) - 273.15
                    vcc = (vcc_raw * 3.0 / 4096.0)

                    print(f"  {seq:03d} | {spikes} | {threat:03d}%   | {level:<8} | {tripwire:<8} | {temp:6.1f}  | {vcc:7.3f}   | {pqc_cyc:7d}")
            else:
                time.sleep(0.01)
    except KeyboardInterrupt:
        print("\n[SYNAPSE-7] Monitoring halted.")
        ser.close()

def main():
    print("=" * 70)
    print("  SYNAPSE-7: Digilent Arty S7 Host Controller")
    print("=" * 70)

    port = find_arty_s7()
    if not port:
        print("[WARNING] Digilent Arty S7 not detected on physical USB COM ports.")
        print("[INFO] You can run the Web Telemetry Dashboard in Digital Twin Mode:")
        print("       python visualizer/synapse7_dashboard.py\n")
        return

    monitor_live(port)

if __name__ == "__main__":
    main()
