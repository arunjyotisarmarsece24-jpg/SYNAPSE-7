/* ==========================================================================
   SYNAPSE-7 Live Telemetry Engine Client
   ========================================================================== */

let ws;
const WS_URL = `ws://${window.location.hostname}:8765`;

// Canvases
const rasterCanvas = document.getElementById("rasterCanvas");
const rasterCtx = rasterCanvas.getContext("2d");

const vmemCanvas = document.getElementById("vmemCanvas");
const vmemCtx = vmemCanvas.getContext("2d");

// Data buffers for rendering
const RASTER_HISTORY_LEN = 120;
let rasterHistory = []; // Array of [s0, s1, ..., s7]

const VMEM_HISTORY_LEN = 120;
let vmemHistory = [];

function initWebSocket() {
    ws = new WebSocket(WS_URL);

    ws.onopen = () => {
        document.getElementById("conn-dot").className = "pulse-dot active";
        document.getElementById("conn-status").innerText = "ONLINE (WS-SYNC)";
        logTerminal("Connected to SYNAPSE-7 WebSocket Telemetry Bus.");
    };

    ws.onclose = () => {
        document.getElementById("conn-dot").className = "pulse-dot";
        document.getElementById("conn-status").innerText = "DISCONNECTED - RETRYING";
        setTimeout(initWebSocket, 2000);
    };

    ws.onerror = (err) => {
        console.error("WS error:", err);
    };

    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        updateDashboard(data);
    };
}

function updateDashboard(data) {
    // Header
    document.getElementById("source-val").innerText = data.source;
    document.getElementById("seq-val").innerText = String(data.seq).padStart(3, '0');

    // Tripwire badge
    const tripBadge = document.getElementById("tripwire-badge");
    if (data.tripwire) {
        tripBadge.innerText = "LOCKED";
        tripBadge.className = "chip-val trip-danger";
    } else {
        tripBadge.innerText = "SECURE";
        tripBadge.className = "chip-val trip-safe";
    }

    // Engine mode badge
    const engBadge = document.getElementById("engine-badge");
    if (engBadge) {
        if (data.quantum_mode) {
            engBadge.innerText = "QUANTUM Q-LIF";
            engBadge.style.color = "#00ffcc";
        } else {
            engBadge.innerText = "CLASSICAL SNN";
            engBadge.style.color = "var(--accent-cyan)";
        }
    }

    // Raster buffer update
    rasterHistory.push(data.neuron_spikes);
    if (rasterHistory.length > RASTER_HISTORY_LEN) {
        rasterHistory.shift();
    }
    renderRaster();

    // Vmem buffer update
    vmemHistory.push(data.v_mem);
    if (vmemHistory.length > VMEM_HISTORY_LEN) {
        vmemHistory.shift();
    }
    renderVmem();
    if (data.quantum_mode) {
        document.getElementById("vmem-val").innerText = `P(|1|) = ${(data.v_mem / 16384.0).toFixed(3)} (Q-State)`;
    } else {
        document.getElementById("vmem-val").innerText = `${data.v_mem} mV`;
    }

    // PQC metrics
    document.getElementById("pqc-cycles-val").innerText = data.pqc_cycles.toLocaleString();
    const entropyPct = Math.min(100, Math.max(0, data.trng_entropy * 100));
    document.getElementById("entropy-bar").style.width = `${entropyPct}%`;
    document.getElementById("entropy-val").innerText = `${data.trng_entropy} / 1.000 (Shannon)`;

    // XADC
    const tempEl = document.getElementById("temp-val");
    tempEl.innerText = data.die_temp.toFixed(1);
    const tempStatus = document.getElementById("temp-status");
    if (data.die_temp > 85) {
        tempEl.style.color = "var(--accent-red)";
        tempStatus.innerText = "CRITICAL THERMAL INJECTION!";
    } else if (data.die_temp > 65) {
        tempEl.style.color = "var(--accent-amber)";
        tempStatus.innerText = "WARNING HIGH TEMP";
    } else {
        tempEl.style.color = "var(--accent-green)";
        tempStatus.innerText = "NOMINAL (< 65°C)";
    }

    const vccEl = document.getElementById("vcc-val");
    vccEl.innerText = data.vccint.toFixed(3);
    const vccStatus = document.getElementById("vcc-status");
    if (data.vccint < 0.90 || data.vccint > 1.10) {
        vccEl.style.color = "var(--accent-red)";
        vccStatus.innerText = "BROWNOUT / OVERVOLTAGE GLITCH!";
    } else {
        vccEl.style.color = "var(--accent-green)";
        vccStatus.innerText = "NOMINAL (1.00V ±5%)";
    }

    // Threat Arbiter
    document.getElementById("threat-fill").style.width = `${data.threat_score}%`;
    document.getElementById("threat-score-val").innerText = `${data.threat_score}%`;

    const threatBadge = document.getElementById("threat-level-badge");
    threatBadge.innerText = `LEVEL: ${data.threat_level}`;
    threatBadge.className = `threat-badge ${data.threat_level.toLowerCase()}`;

    // Hex Inspector
    const rawSpikeByte = data.neuron_spikes.reduce((acc, bit, idx) => acc | (bit << idx), 0);
    const hexStr = `AA 55 ${hex(data.seq)} ${hex(rawSpikeByte)} ${hex(data.threat_score)} ${hex(data.tripwire ? 0x80 : 0x00)} ${hex(data.trng_byte)} ${hex(data.pqc_cycles & 0xFF)} ${hex((data.pqc_cycles >> 8) & 0xFF)} ${hex(data.v_mem & 0xFF)} ${hex((data.v_mem >> 8) & 0xFF)} 99 9A 00 3C`;
    document.getElementById("hexDump").innerText = hexStr;
}

function hex(val) {
    return ((val & 0xFF).toString(16).toUpperCase().padStart(2, '0'));
}

function renderRaster() {
    const w = rasterCanvas.width;
    const h = rasterCanvas.height;
    rasterCtx.fillStyle = "#04060a";
    rasterCtx.fillRect(0, 0, w, h);

    const numNeurons = 8;
    const rowHeight = h / numNeurons;
    const colWidth = w / RASTER_HISTORY_LEN;

    // Draw grid tracks
    rasterCtx.strokeStyle = "rgba(255, 255, 255, 0.04)";
    rasterCtx.lineWidth = 1;
    for (let i = 0; i < numNeurons; i++) {
        rasterCtx.beginPath();
        rasterCtx.moveTo(0, i * rowHeight);
        rasterCtx.lineTo(w, i * rowHeight);
        rasterCtx.stroke();
    }

    // Draw active spikes
    for (let t = 0; t < rasterHistory.length; t++) {
        const spikes = rasterHistory[t];
        const x = t * colWidth;
        for (let n = 0; n < numNeurons; n++) {
            if (spikes[n]) {
                const y = n * rowHeight + rowHeight / 2;
                rasterCtx.fillStyle = "#00f3ff";
                rasterCtx.shadowColor = "#00f3ff";
                rasterCtx.shadowBlur = 8;
                rasterCtx.beginPath();
                rasterCtx.arc(x, y, 3, 0, Math.PI * 2);
                rasterCtx.fill();
                rasterCtx.shadowBlur = 0; // reset
            }
        }
    }
}

function renderVmem() {
    const w = vmemCanvas.width;
    const h = vmemCanvas.height;
    vmemCtx.fillStyle = "#04060a";
    vmemCtx.fillRect(0, 0, w, h);

    // Draw threshold line (Vth = 120 mV)
    // Scale: -20 to 140 mV -> 0 to h
    const scaleY = (val) => h - ((val + 20) / 160) * h;

    const yTh = scaleY(120);
    vmemCtx.strokeStyle = "rgba(255, 34, 85, 0.6)";
    vmemCtx.setLineDash([4, 4]);
    vmemCtx.beginPath();
    vmemCtx.moveTo(0, yTh);
    vmemCtx.lineTo(w, yTh);
    vmemCtx.stroke();
    vmemCtx.setLineDash([]);

    // Draw baseline zero
    const yZero = scaleY(0);
    vmemCtx.strokeStyle = "rgba(255, 255, 255, 0.1)";
    vmemCtx.beginPath();
    vmemCtx.moveTo(0, yZero);
    vmemCtx.lineTo(w, yZero);
    vmemCtx.stroke();

    // Plot membrane trace
    if (vmemHistory.length < 2) return;

    const colWidth = w / VMEM_HISTORY_LEN;
    vmemCtx.strokeStyle = "#00ff88";
    vmemCtx.lineWidth = 2;
    vmemCtx.shadowColor = "#00ff88";
    vmemCtx.shadowBlur = 6;
    vmemCtx.beginPath();

    for (let i = 0; i < vmemHistory.length; i++) {
        const x = i * colWidth;
        const y = scaleY(vmemHistory[i]);
        if (i === 0) vmemCtx.moveTo(x, y);
        else vmemCtx.lineTo(x, y);
    }
    vmemCtx.stroke();
    vmemCtx.shadowBlur = 0;
}

function logTerminal(msg) {
    const term = document.getElementById("terminalLog");
    const now = new Date().toTimeString().split(' ')[0];
    term.innerHTML += `<br>[${now}] ${msg}`;
    term.scrollTop = term.scrollHeight;
}

function setMode(mode) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ cmd: "SET_MODE", mode: mode }));
        logTerminal(`COMMAND SENT -> Mode: ${mode}`);
    }
}

function clearTripwire() {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ cmd: "CLEAR_TRIPWIRE" }));
        logTerminal("COMMAND SENT -> Zero-Trust Tripwire Cleared.");
    }
}

// Window load init
window.addEventListener("load", () => {
    initWebSocket();
});
