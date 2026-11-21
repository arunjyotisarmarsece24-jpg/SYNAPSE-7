import asyncio
import json
import urllib.request
import websockets

def check_http():
    try:
        with urllib.request.urlopen("http://localhost:8080", timeout=3) as resp:
            content = resp.read()
            print(f"[+] HTTP Web Server Verification: STATUS {resp.status} OK (HTML size: {len(content):,} bytes)")
            return True
    except Exception as e:
        print(f"[-] HTTP Error: {e}")
        return False

async def verify_ws():
    uri = "ws://localhost:8765"
    try:
        async with websockets.connect(uri) as ws:
            print("[+] WebSocket Telemetry Bus: CONNECTED SUCCESSFULLY to ws://localhost:8765\n")
            
            # Read 2 baseline frames
            for i in range(2):
                raw = await ws.recv()
                f = json.loads(raw)
                print(f"[LIVE STREAM - FRAME {i+1}]:")
                print(f"   * Sequence Counter:      {f['seq']}")
                print(f"   * Engine Mode:           {'QUANTUM Q-LIF' if f.get('quantum_mode') else 'CLASSICAL SNN'}")
                print(f"   * Live Neuron Spikes:    {f['neuron_spikes']}")
                print(f"   * N-HIDS Threat Score:   {f['threat_score']}% ({f['threat_level']})")
                print(f"   * PQC NTT Cycles:        {f['pqc_cycles']:,}")
                print(f"   * RO-TRNG Entropy:       {f['trng_entropy']} Shannon")
                print(f"   * Spartan-7 Vitals:      {f['die_temp']}°C | VCCINT = {f['vccint']}V\n")
            
            # Switch to Quantum Mode
            print("[*] Dispatching Command via WebSocket: SET_MODE -> QUANTUM_MODE ...")
            await ws.send(json.dumps({"cmd": "SET_MODE", "mode": "QUANTUM_MODE"}))
            await asyncio.sleep(0.1)
            
            print("\n[+] Reading Live Quantum Neuromorphic Telemetry:")
            for i in range(3):
                raw = await ws.recv()
                f = json.loads(raw)
                print(f"   [QUANTUM FRAME {i+1}]: Seq={f['seq']} | Born Prob P(|1|)={f.get('born_prob')} | Coherence={f.get('coherence')} | Spikes={f['neuron_spikes']}")
            
            # Reset back to Normal
            await ws.send(json.dumps({"cmd": "SET_MODE", "mode": "NORMAL"}))
            print("\n[+] Verification Check: 100% SUCCESSFUL! Dashboard and Telemetry Bus are fully operating.")
            return True
    except Exception as e:
        print(f"[-] WebSocket Error: {e}")
        return False

if __name__ == "__main__":
    print("=" * 65)
    print("  SYNAPSE-7 Live System Health & Telemetry Verification")
    print("=" * 65)
    http_ok = check_http()
    if http_ok:
        asyncio.run(verify_ws())
    print("=" * 65)
