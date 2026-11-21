#!/usr/bin/env python3
"""
SYNAPSE-7 Live FPGA USB Scanner
Monitors Windows PnP and Serial Ports for Digilent Arty S7 (FTDI FT2232HQ).
"""

import time
import serial.tools.list_ports

def scan():
    print("=" * 65)
    print("  SYNAPSE-7 Real-Time FPGA Hardware Connection Monitor")
    print("  Target: Digilent Arty S7 (FTDI FT2232HQ VID:0403 PID:6010)")
    print("=" * 65)
    print("[*] Scanning USB buses for Arty S7... (Press Ctrl+C to cancel)\n")

    detected = False
    for attempt in range(1, 31):
        ports = list(serial.tools.list_ports.comports())
        for p in ports:
            # Check for FTDI / Digilent VID:PID 0403:6010 or FTDI description
            if p.vid == 0x0403 or "FTDI" in (p.manufacturer or "").upper() or "DIGILENT" in (p.description or "").upper():
                print(f"\n[+] SUCCESS! FPGA BOARD DETECTED!")
                print(f"    * Port:         {p.device}")
                print(f"    * Description:  {p.description}")
                print(f"    * Hardware ID:  {p.hwid}")
                print(f"    * Manufacturer: {p.manufacturer}")
                print("\n[+] The Arty S7 is now electrically connected and ready for programming!")
                detected = True
                return True
        sys_dots = "." * (attempt % 4)
        print(f"\r[-] Waiting for Arty S7 connection{sys_dots:<4} (Attempt {attempt}/30)", end="", flush=True)
        time.sleep(1)

    print("\n\n[!] Scan timed out. Please check cable and jumper settings.")
    return False

if __name__ == "__main__":
    scan()
