import serial
import time

try:
    print("[*] Opening COM5 @ 115200 baud...")
    ser = serial.Serial("COM5", 115200, timeout=1.0)
    print("[+] Successfully opened COM5. Listening for live telemetry packets...")
    t_end = time.time() + 2.0
    total_bytes = 0
    frames = 0
    while time.time() < t_end:
        b = ser.read(16)
        if len(b) > 0:
            total_bytes += len(b)
            if b.startswith(b'\xaa\x55'):
                frames += 1
                print(f"    [FRAME] Seq: {b[2]} Spikes: {bin(b[3])} Threat: {b[4]}% Raw: {b.hex()}")
    print(f"[*] Read total {total_bytes} bytes, {frames} valid frames.")
    ser.close()
except Exception as e:
    print(f"[!] Serial error: {e}")
