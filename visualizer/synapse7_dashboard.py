#!/usr/bin/env python3
"""
===============================================================================
SYNAPSE-7 Real-Time Hardware Telemetry & Neural Visualization Engine
Project: SYNAPSE-7 (Neuromorphic-Quantum Edge Security on Xilinx Spartan-7)
===============================================================================
Serves an ultra-low-latency defense cockpit dashboard over HTTP/WebSocket.
Bridges directly to Digilent Arty S7 UART (COM port) or runs in high-fidelity
digital twin hardware emulation mode when FPGA is disconnected.
"""

import os
import sys
import time
import math
import json
import random
import asyncio
import threading
import http.server
import socketserver
import serial
import serial.tools.list_ports
import websockets

HTTP_PORT = 8080
WS_PORT   = 8765
BAUD_RATE = 115200

# Global state for telemetry
latest_telemetry = {
    "source": "EMULATOR",
    "seq": 0,
    "neuron_spikes": [0] * 8,
    "threat_score": 0,
    "threat_level": "SAFE",
    "tripwire": False,
    "trng_byte": 0x42,
    "trng_entropy": 0.98,
    "pqc_cycles": 1024,
    "v_mem": 0,
    "die_temp": 42.5,
    "vccint": 1.01,
    "quantum_mode": False,
    "born_prob": 0.0,
    "coherence": 0.95,
    "fps": 60,
    "switches": [0, 0, 0, 0],
    "buttons": [0, 0, 0, 0],
    "status_msg": "SYNAPSE-7 Zero-Trust Core Active"
}

connected_websockets = set()
simulated_threat_mode = "NORMAL"

# -----------------------------------------------------------------------------
# Static HTTP Server
# -----------------------------------------------------------------------------
class StaticHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        static_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
        super().__init__(*args, directory=static_dir, **kwargs)

    def log_message(self, format, *args):
        pass  # Quiet HTTP logs

def start_http_server():
    with socketserver.TCPServer(("", HTTP_PORT), StaticHandler) as httpd:
        print(f"[SYNAPSE-7] HTTP Dashboard Server listening on http://localhost:{HTTP_PORT}")
        httpd.serve_forever()

# -----------------------------------------------------------------------------
# Telemetry Frame Parser (16-byte protocol)
# -----------------------------------------------------------------------------
def parse_telemetry_frame(frame_bytes):
    if len(frame_bytes) != 16 or frame_bytes[0] != 0xAA or frame_bytes[1] != 0x55:
        return None

    seq_num         = frame_bytes[2]
    spikes_raw      = frame_bytes[3]
    threat_score    = frame_bytes[4]
    flags           = frame_bytes[5]
    trng_byte       = frame_bytes[6]
    pqc_cycles      = frame_bytes[7] | (frame_bytes[8] << 8)
    v_mem_raw       = frame_bytes[9] | (frame_bytes[10] << 8)
    if v_mem_raw >= 32768:
        v_mem_raw -= 65536
    
    die_temp_raw    = frame_bytes[11] | ((frame_bytes[12] >> 4) << 8)
    vccint_raw      = frame_bytes[13] | ((frame_bytes[12] & 0x0F) << 8)
    status_flags    = frame_bytes[14]

    # Convert XADC 12-bit values to human engineering units
    # XADC Temp = (raw * 503.975 / 4096) - 273.15
    die_temp_c = (die_temp_raw * 503.975 / 4096.0) - 273.15
    # XADC VCCINT = (raw * 3.0 / 4096)
    vccint_v   = (vccint_raw * 3.0 / 4096.0)

    tripwire     = bool((flags >> 7) & 1)
    threat_code  = (flags >> 5) & 3
    level_map    = {0: "SAFE", 1: "CAUTION", 2: "CRITICAL"}
    threat_level = level_map.get(threat_code, "UNKNOWN")

    spikes_list = [(spikes_raw >> i) & 1 for i in range(8)]
    quantum_mode = bool((status_flags >> 7) & 1)
    born_prob    = round(max(0, v_mem_raw) / 16384.0, 4) if quantum_mode else 0.0

    return {
        "source": "FPGA_HARDWARE",
        "seq": seq_num,
        "neuron_spikes": spikes_list,
        "threat_score": threat_score,
        "threat_level": threat_level,
        "tripwire": tripwire,
        "trng_byte": trng_byte,
        "trng_entropy": round(0.95 + 0.05 * (trng_byte % 7) / 7.0, 3),
        "pqc_cycles": pqc_cycles,
        "v_mem": v_mem_raw,
        "quantum_mode": quantum_mode,
        "born_prob": born_prob,
        "die_temp": round(die_temp_c, 2),
        "vccint": round(vccint_v, 3),
        "status_msg": "SYNAPSE-7 Quantum-Neuromorphic FPGA Enclave Active"
    }

# -----------------------------------------------------------------------------
# Background Hardware Poller / Digital Twin Emulator
# -----------------------------------------------------------------------------
def hardware_telemetry_loop():
    global latest_telemetry, simulated_threat_mode
    ser = None
    v_mem_sim = 0
    pqc_sim_cycles = 1000
    seq = 0

    while True:
        # Check for Arty S7 FTDI USB Serial Port
        if ser is None:
            ports = list(serial.tools.list_ports.comports())
            arty_port = None
            for p in ports:
                # Digilent / FTDI VID:PID or description
                if "FTDI" in p.description.upper() or "USB SERIAL" in p.description.upper() or "DIGILENT" in p.description.upper():
                    arty_port = p.device
                    break
            
            if arty_port:
                try:
                    ser = serial.Serial(arty_port, BAUD_RATE, timeout=0.1)
                    print(f"[SYNAPSE-7] Attached to Arty S7 Hardware on {arty_port} at {BAUD_RATE} baud.")
                except Exception:
                    ser = None

        if ser and ser.is_open:
            try:
                # Read 16-byte synced frame
                header = ser.read(2)
                if header == b'\xAA\x55':
                    payload = ser.read(14)
                    if len(payload) == 14:
                        parsed = parse_telemetry_frame(header + payload)
                        if parsed:
                            latest_telemetry.update(parsed)
                else:
                    time.sleep(0.005)
            except Exception:
                ser = None
        else:
            # High-fidelity Digital Twin Emulation
            seq = (seq + 1) & 0xFF
            pqc_sim_cycles += random.randint(12, 35)
            
            q_active = False
            born_prob = 0.0
            coherence = 0.95

            # Neural dynamics simulation (LIF & Quantum Q-LIF)
            if simulated_threat_mode == "QUANTUM_MODE":
                q_active = True
                theta = (seq * 0.18) % math.pi
                born_prob = round((math.sin(theta) ** 2), 3)
                coherence = round(abs(math.cos(theta)), 3)
                q_fire = (born_prob >= 0.50)
                spikes = [1 if (q_fire and random.random() < 0.85) else (1 if random.random() < 0.08 else 0) for _ in range(8)]
                v_mem_sim = int(born_prob * 16384)
                threat_score = max(12, min(80, int(born_prob * 75)))
                tripwire = False
                temp = 42.1 + 0.4 * math.sin(seq * 0.05)
                vcc = 1.003
            elif simulated_threat_mode == "PACKET_BURST":
                spikes = [random.choice([0, 1, 1, 1]) for _ in range(8)]
                threat_score = min(100, latest_telemetry["threat_score"] + random.randint(8, 15))
                tripwire = threat_score >= 60
                v_mem_sim = min(120, v_mem_sim + random.randint(25, 45))
                if v_mem_sim >= 120: v_mem_sim = 0
                temp = 48.0 + random.uniform(0.5, 2.5)
                vcc = 1.00 + random.uniform(-0.02, 0.02)
            elif simulated_threat_mode == "VOLTAGE_GLITCH":
                spikes = [random.choice([0, 0, 1]) for _ in range(8)]
                threat_score = 98
                tripwire = True
                v_mem_sim = 40
                vcc = 0.76 + random.uniform(-0.05, 0.05) # Brownout glitch!
                temp = 44.0 + random.uniform(0.1, 0.8)
            elif simulated_threat_mode == "THERMAL_FAULT":
                spikes = [random.choice([0, 1]) for _ in range(8)]
                threat_score = 85
                tripwire = True
                temp = 92.5 + random.uniform(0.5, 3.5) # Laser heating!
                vcc = 0.98 + random.uniform(-0.01, 0.01)
            else:
                # NORMAL baseline
                spikes = [1 if random.random() < 0.08 else 0 for _ in range(8)]
                threat_score = max(5, latest_telemetry["threat_score"] - 2)
                tripwire = False
                # Leaky integrate & fire waveform
                leak = v_mem_sim // 8
                v_mem_sim = max(0, v_mem_sim - leak + (random.randint(10, 25) if any(spikes) else 0))
                if v_mem_sim >= 115:
                    v_mem_sim = 0
                temp = 41.5 + 0.8 * math.sin(seq * 0.05)
                vcc = 1.008 + 0.005 * math.cos(seq * 0.1)

            threat_level = "CRITICAL" if tripwire else ("CAUTION" if threat_score >= 25 else "SAFE")
            trng_val = random.randint(0, 255)

            latest_telemetry.update({
                "source": "DIGITAL_TWIN_EMULATOR",
                "seq": seq,
                "neuron_spikes": spikes,
                "threat_score": threat_score,
                "threat_level": threat_level,
                "tripwire": tripwire,
                "trng_byte": trng_val,
                "trng_entropy": round(0.96 + random.uniform(0.01, 0.039), 3),
                "pqc_cycles": pqc_sim_cycles,
                "v_mem": v_mem_sim,
                "quantum_mode": q_active,
                "born_prob": born_prob,
                "coherence": coherence,
                "die_temp": round(temp, 2),
                "vccint": round(vcc, 3),
                "status_msg": "SYNAPSE-7 Digital Twin Emulation Running"
            })
            time.sleep(0.05) # 20 Hz update rate

# -----------------------------------------------------------------------------
# WebSocket Telemetry Server
# -----------------------------------------------------------------------------
async def ws_handler(websocket):
    global simulated_threat_mode
    connected_websockets.add(websocket)
    print(f"[SYNAPSE-7] WebSocket client connected: {websocket.remote_address}")
    try:
        async for message in websocket:
            data = json.loads(message)
            cmd = data.get("cmd")
            if cmd == "SET_MODE":
                simulated_threat_mode = data.get("mode", "NORMAL")
                print(f"[SYNAPSE-7] Threat mode set to: {simulated_threat_mode}")
            elif cmd == "CLEAR_TRIPWIRE":
                simulated_threat_mode = "NORMAL"
                latest_telemetry["tripwire"] = False
                latest_telemetry["threat_score"] = 10
                print("[SYNAPSE-7] Tripwire cleared by user console.")
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        connected_websockets.remove(websocket)

async def ws_broadcast_loop():
    while True:
        if connected_websockets:
            payload = json.dumps(latest_telemetry)
            await asyncio.gather(*[ws.send(payload) for ws in connected_websockets], return_exceptions=True)
        await asyncio.sleep(0.05)

async def main():
    # Start HTTP server thread
    http_thread = threading.Thread(target=start_http_server, daemon=True)
    http_thread.start()

    # Start Hardware polling / digital twin thread
    hw_thread = threading.Thread(target=hardware_telemetry_loop, daemon=True)
    hw_thread.start()

    # Start WebSocket server
    print(f"[SYNAPSE-7] WebSocket Telemetry Server listening on ws://localhost:{WS_PORT}")
    async with websockets.serve(ws_handler, "0.0.0.0", WS_PORT):
        await ws_broadcast_loop()

if __name__ == "__main__":
    print("=" * 70)
    print("  SYNAPSE-7 Real-Time Hardware Telemetry & Security Engine")
    print("  Dashboard UI: http://localhost:8080")
    print("  Target:       Digilent Arty S7 (Spartan-7 XC7S25 / XC7S50)")
    print("=" * 70)
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[SYNAPSE-7] Server stopped by user.")
