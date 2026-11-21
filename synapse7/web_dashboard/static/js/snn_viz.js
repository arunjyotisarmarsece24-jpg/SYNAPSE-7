/**
 * SYNAPSE-7 Neuromorphic SNN Live Visualization Engine
 * Renders biological Membrane Potential Oscilloscope, Spike Raster Plots,
 * and Synaptic Plasticity Heatmaps at 60 FPS.
 * Author: Arunjyoti Sarma (IIT BHU)
 */

let isAutoTraining = false;
let autoTrainInterval = null;

// Initialize on page load
document.addEventListener("DOMContentLoaded", () => {
    initOscilloscope();
    initRasterPlot();
    initHeatmap();
    // Run an initial train step to populate with live telemetry
    trainOneEpoch();
});

// ----------------------------------------------------------------------------
// API Interactions & Training Controls
// ----------------------------------------------------------------------------
async function trainOneEpoch() {
    try {
        const response = await fetch("/api/snn/train_step", {
            method: "POST",
            headers: { "Content-Type": "application/json" }
        });
        const data = await response.json();

        // Update Metrics Ribbon
        document.getElementById("metric-epoch").textContent = data.epoch;
        document.getElementById("metric-loss").textContent = data.loss.toFixed(4);
        document.getElementById("metric-accuracy").textContent = `${data.accuracy_percent.toFixed(1)}%`;
        document.getElementById("metric-sops").textContent = Math.round(data.epoch * 1536).toLocaleString();
        document.getElementById("metric-energy").textContent = `${data.est_energy_pj} pJ (38x vs GPU)`;

        // Update Visualizers
        renderOscilloscope(data.sample_membrane_v);
        renderRasterPlot(data.sample_raster);
        renderHeatmap(data.hidden_weight_matrix);

    } catch (err) {
        console.error("SNN Training step error:", err);
    }
}

function toggleAutoTraining() {
    const btn = document.getElementById("btn-toggle-auto");
    const statusText = document.getElementById("snn-status-text");

    if (isAutoTraining) {
        clearInterval(autoTrainInterval);
        isAutoTraining = false;
        btn.textContent = "▶ AUTO-LEARN (CONTINUOUS STREAM)";
        btn.classList.remove("btn-active-stream");
        statusText.textContent = "TRAINING PAUSED (READY)";
    } else {
        isAutoTraining = true;
        btn.textContent = "⏸ PAUSE AUTO-LEARN";
        btn.classList.add("btn-active-stream");
        statusText.textContent = "CONTINUOUS STBP STREAMING & SYNAPSE TUNING...";
        // Stream train epochs every 600ms
        autoTrainInterval = setInterval(() => {
            trainOneEpoch();
        }, 600);
    }
}

async function triggerStdpPulse() {
    try {
        const response = await fetch("/api/snn/stdp_step", { method: "POST" });
        const data = await response.json();
        renderHeatmap(data.weights);
        document.getElementById("metric-sops").textContent = data.sops_total.toLocaleString();
        
        const statusText = document.getElementById("snn-status-text");
        statusText.textContent = `STDP PULSE COMMITTED: Pre-Trace = ${data.pre_trace[0].toFixed(2)}, Post-Trace = ${data.post_trace[0].toFixed(2)}`;
    } catch (err) {
        console.error("STDP step error:", err);
    }
}

async function injectDpaGlitch() {
    try {
        // High correlation glitch pattern
        const glitchVector = [0.95, 0.98, 0.89, 0.92, 0.85, 0.99, 0.88, 0.91, 0.94, 0.87, 0.96, 0.93, 0.89, 0.95, 0.90, 0.97];
        const response = await fetch("/api/snn/guard_inspect", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ telemetry_vector: glitchVector })
        });
        const data = await response.json();

        const statusText = document.getElementById("snn-status-text");
        statusText.innerHTML = `<span style="color:#ff0055;font-weight:bold;">⚠️ ALERT: ${data.classification} DETECTED! Confidence: ${data.confidence}% (FPGA INTERRUPT ASSERTED)</span>`;

        // Run an epoch to visualize the reaction
        trainOneEpoch();
    } catch (err) {
        console.error("Glitch injection error:", err);
    }
}

// ----------------------------------------------------------------------------
// 1. Membrane Potential Oscilloscope Rendering
// ----------------------------------------------------------------------------
function initOscilloscope() {
    const canvas = document.getElementById("canvas-oscilloscope");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#04060a";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
}

function renderOscilloscope(voltagesArray) {
    const canvas = document.getElementById("canvas-oscilloscope");
    if (!canvas || !voltagesArray || voltagesArray.length === 0) return;
    const ctx = canvas.getContext("2d");
    const w = canvas.width;
    const h = canvas.height;

    // Clear background
    ctx.fillStyle = "#04060a";
    ctx.fillRect(0, 0, w, h);

    // Grid lines
    ctx.strokeStyle = "rgba(30, 41, 59, 0.7)";
    ctx.lineWidth = 1;
    for (let x = 0; x < w; x += 40) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    }
    for (let y = 0; y < h; y += 30) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
    }

    // Draw V_threshold line (V = 1.0)
    const yTh = h * 0.28;
    ctx.strokeStyle = "rgba(255, 215, 0, 0.6)";
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.moveTo(0, yTh);
    ctx.lineTo(w, yTh);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = "#ffd700";
    ctx.font = "9px monospace";
    ctx.fillText("V_th (1.0V)", 10, yTh - 4);

    // Draw V_rest line (V = 0.0)
    const yRest = h * 0.85;
    ctx.strokeStyle = "rgba(148, 163, 184, 0.4)";
    ctx.beginPath();
    ctx.moveTo(0, yRest);
    ctx.lineTo(w, yRest);
    ctx.stroke();
    ctx.fillText("V_rest (0.0V)", 10, yRest - 4);

    const T = voltagesArray.length;
    const numTraces = Math.min(voltagesArray[0].length, 2);
    const colors = ["#00f3ff", "#ff0055"];

    for (let n = 0; n < numTraces; n++) {
        ctx.strokeStyle = colors[n];
        ctx.lineWidth = 2;
        ctx.beginPath();

        for (let t = 0; t < T; t++) {
            const v = voltagesArray[t][n];
            const px = (t / (T - 1)) * (w - 20) + 10;
            // Map v in [0.0, 1.4] to height [yRest, 20]
            const py = yRest - (v / 1.4) * (yRest - 20);

            if (t === 0) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);

            // If action potential fired (v was clamped or above th)
            if (v >= 0.95) {
                ctx.fillStyle = "#00ff66";
                ctx.beginPath();
                ctx.arc(px, pyTh, 4, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
        ctx.stroke();
    }
}

// ----------------------------------------------------------------------------
// 2. Temporal Spike Raster Plot Rendering
// ----------------------------------------------------------------------------
function initRasterPlot() {
    const canvas = document.getElementById("canvas-raster");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#04060a";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
}

function renderRasterPlot(rasterData) {
    const canvas = document.getElementById("canvas-raster");
    if (!canvas || !rasterData) return;
    const ctx = canvas.getContext("2d");
    const w = canvas.width;
    const h = canvas.height;

    ctx.fillStyle = "#04060a";
    ctx.fillRect(0, 0, w, h);

    const inSpikes = rasterData.input_spikes;    // (T, 16)
    const hSpikes = rasterData.hidden_spikes;   // (T, 32)
    const oSpikes = rasterData.output_spikes;   // (T, 2)

    if (!inSpikes || inSpikes.length === 0) return;
    const T = inSpikes.length;

    // Total neurons = 16 + 32 + 2 = 50 rows
    const totalNeurons = 50;
    const rowHeight = (h - 20) / totalNeurons;

    // Dividing lines between layers
    ctx.strokeStyle = "rgba(255, 255, 255, 0.15)";
    ctx.lineWidth = 1;
    const ySplit1 = 10 + 16 * rowHeight;
    const ySplit2 = ySplit1 + 32 * rowHeight;
    ctx.beginPath(); ctx.moveTo(0, ySplit1); ctx.lineTo(w, ySplit1); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, ySplit2); ctx.lineTo(w, ySplit2); ctx.stroke();

    // 1. Draw Input Spikes (Cyan)
    ctx.fillStyle = "#00f3ff";
    for (let t = 0; t < T; t++) {
        const x = (t / (T - 1)) * (w - 20) + 10;
        for (let i = 0; i < 16; i++) {
            if (inSpikes[t][i] > 0.5) {
                const y = 10 + i * rowHeight;
                ctx.fillRect(x - 1, y, 2, rowHeight * 0.9);
            }
        }
    }

    // 2. Draw Hidden Spikes (Magenta)
    ctx.fillStyle = "#ff00a0";
    for (let t = 0; t < T; t++) {
        const x = (t / (T - 1)) * (w - 20) + 10;
        for (let i = 0; i < 32; i++) {
            if (hSpikes[t][i] > 0.5) {
                const y = ySplit1 + i * rowHeight;
                ctx.fillRect(x - 1, y, 2, rowHeight * 0.9);
            }
        }
    }

    // 3. Draw Output Spikes (Class 0: Green, Class 1: Red)
    for (let t = 0; t < T; t++) {
        const x = (t / (T - 1)) * (w - 20) + 10;
        if (oSpikes[t][0] > 0.5) {
            ctx.fillStyle = "#00ff66";
            ctx.fillRect(x - 1, ySplit2, 3, rowHeight * 1.5);
        }
        if (oSpikes[t][1] > 0.5) {
            ctx.fillStyle = "#ff0055";
            ctx.fillRect(x - 1, ySplit2 + rowHeight * 1.5, 3, rowHeight * 1.5);
        }
    }
}

// ----------------------------------------------------------------------------
// 3. Synaptic Weight Crossbar Heatmap Rendering
// ----------------------------------------------------------------------------
function initHeatmap() {
    const canvas = document.getElementById("canvas-heatmap");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#04060a";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
}

function renderHeatmap(weightsMatrix) {
    const canvas = document.getElementById("canvas-heatmap");
    if (!canvas || !weightsMatrix || weightsMatrix.length === 0) return;
    const ctx = canvas.getContext("2d");
    const w = canvas.width;
    const h = canvas.height;

    const rows = weightsMatrix.length;      // 32 or 16
    const cols = weightsMatrix[0].length;   // 16

    const cellW = (w - 20) / cols;
    const cellH = (h - 20) / rows;

    ctx.fillStyle = "#04060a";
    ctx.fillRect(0, 0, w, h);

    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            const val = weightsMatrix[r][c];
            // Normalize in [0, 1]
            const normVal = Math.min(Math.max((val + 0.5) / 1.5, 0.0), 1.0);

            // Interpolate color: Dark Indigo (0.0) -> Cyan (0.5) -> Neon Gold/Magenta (1.0)
            let red = Math.round(normVal > 0.5 ? 255 * (normVal - 0.5) * 2 : 10);
            let green = Math.round(normVal < 0.5 ? 200 * normVal * 2 : 200 * (1 - (normVal - 0.5) * 2));
            let blue = Math.round(normVal < 0.5 ? 255 : 80);

            ctx.fillStyle = `rgb(${red}, ${green}, ${blue})`;
            ctx.fillRect(10 + c * cellW, 10 + r * cellH, cellW - 1, cellH - 1);
        }
    }
}
