/**
 * SYNAPSE-7 Live Quantum Visualization & Quirk Bridge Engine
 * Renders real-time Bloch Sphere projections and communicates with Flask backend.
 */

let activeCircuit = [
    ["H", "1"],
    ["•", "X"]
];

// Initialize on page load
document.addEventListener("DOMContentLoaded", () => {
    renderCircuitColumns();
    runCircuitSimulation();
    initBlochSphere("blochCanvas0", 0, 0, 1);
    initBlochSphere("blochCanvas1", 0, 0, 1);
});

function renderCircuitColumns() {
    const container = document.getElementById("circuit-wire-display");
    container.innerHTML = "";

    activeCircuit.forEach((col, cIdx) => {
        const colDiv = document.createElement("div");
        colDiv.className = "circuit-col";

        col.forEach((gate, wIdx) => {
            const cell = document.createElement("div");
            cell.className = "circuit-cell";
            cell.textContent = gate === "1" ? "—" : gate;
            colDiv.appendChild(cell);
        });

        container.appendChild(colDiv);
    });
}

function addGateToCircuit(gateSymbol) {
    activeCircuit.push([gateSymbol, "1"]);
    renderCircuitColumns();
    runCircuitSimulation();
}

function addBellPair() {
    activeCircuit = [
        ["H", "1"],
        ["•", "X"]
    ];
    renderCircuitColumns();
    runCircuitSimulation();
}

function resetCircuit() {
    activeCircuit = [
        ["1", "1"]
    ];
    renderCircuitColumns();
    runCircuitSimulation();
}

async function runCircuitSimulation() {
    try {
        const response = await fetch("/api/simulate", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ circuit: activeCircuit })
        });
        const data = await response.json();

        // Update Quirk Link
        const quirkBtn = document.getElementById("btn-open-quirk");
        if (quirkBtn && data.quirk_url) {
            quirkBtn.href = data.quirk_url;
        }

        // Update Bloch Spheres
        if (data.bloch_coords && data.bloch_coords.length >= 2) {
            const b0 = data.bloch_coords[0];
            const b1 = data.bloch_coords[1];
            drawBlochVector("blochCanvas0", b0[0], b0[1], b0[2]);
            drawBlochVector("blochCanvas1", b1[0], b1[1], b1[2]);
            document.getElementById("blochLabel0").textContent = `q[0]: (x=${b0[0].toFixed(2)}, y=${b0[1].toFixed(2)}, z=${b0[2].toFixed(2)})`;
            document.getElementById("blochLabel1").textContent = `q[1]: (x=${b1[0].toFixed(2)}, y=${b1[1].toFixed(2)}, z=${b1[2].toFixed(2)})`;
        }
    } catch (err) {
        console.error("Simulation error:", err);
    }
}

// ----------------------------------------------------------------------------
// Canvas Bloch Sphere 3D Wireframe Projection
// ----------------------------------------------------------------------------
function initBlochSphere(canvasId, x, y, z) {
    drawBlochVector(canvasId, x, y, z);
}

function drawBlochVector(canvasId, x, y, z) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    const w = canvas.width;
    const h = canvas.height;
    const cx = w / 2;
    const cy = h / 2;
    const r = w * 0.38;

    ctx.clearRect(0, 0, w, h);

    // Draw Sphere Outline
    ctx.strokeStyle = "rgba(0, 243, 255, 0.4)";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
    ctx.stroke();

    // Equator ellipse
    ctx.strokeStyle = "rgba(0, 243, 255, 0.2)";
    ctx.beginPath();
    ctx.ellipse(cx, cy, r, r * 0.35, 0, 0, 2 * Math.PI);
    ctx.stroke();

    // Z-axis line (Poles |0> and |1>)
    ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
    ctx.beginPath();
    ctx.moveTo(cx, cy - r - 6);
    ctx.lineTo(cx, cy + r + 6);
    ctx.stroke();

    // Axis labels
    ctx.fillStyle = "#ffd700";
    ctx.font = "10px monospace";
    ctx.fillText("|0⟩", cx - 8, cy - r - 8);
    ctx.fillText("|1⟩", cx - 8, cy + r + 15);

    // Project (x, y, z) to 2D
    // Isometric-ish projection
    const px = cx + (x - 0.5 * y) * r * 0.85;
    const py = cy - z * r + (0.35 * y * r * 0.5);

    // Draw State Vector
    ctx.strokeStyle = "#ff0055";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(px, py);
    ctx.stroke();

    // Vector tip dot
    ctx.fillStyle = "#00ff66";
    ctx.beginPath();
    ctx.arc(px, py, 4, 0, 2 * Math.PI);
    ctx.fill();
}

// ----------------------------------------------------------------------------
// Steane QEC API Interaction
// ----------------------------------------------------------------------------
async function triggerSteaneTest() {
    const qSelect = document.getElementById("steane-qubit-select").value;
    const errType = document.getElementById("steane-error-type").value;
    const resBox = document.getElementById("steane-results");

    resBox.innerHTML += `<p class='log-line'>[QEC] Injecting Pauli ${errType} fault on Physical Qubit ${qSelect}...</p>`;

    try {
        const response = await fetch("/api/steane/test", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ logical_bit: 0, error_qubit: parseInt(qSelect), error_type: errType })
        });
        const data = await response.json();

        resBox.innerHTML += `<p class='log-line'>[STABILIZER] Syndrome Check: X-Error Qubit = ${data.syndrome_detected.detected_x_error_qubit}, Z-Error Qubit = ${data.syndrome_detected.detected_z_error_qubit}</p>`;
        resBox.innerHTML += `<p class='log-line'>[CORRECTED] Logical Fidelity Restored: ${data.post_correction_fidelity * 100}% | Output Bit = |${data.decoded_logical_bit}L⟩</p>`;
        resBox.scrollTop = resBox.scrollHeight;
    } catch (err) {
        resBox.innerHTML += `<p class='log-alert'>Error executing QEC test: ${err}</p>`;
    }
}

// ----------------------------------------------------------------------------
// BB84 QKD API Interaction
// ----------------------------------------------------------------------------
async function runQkdLink() {
    const eveCheck = document.getElementById("qkd-eve-check").checked;
    const resBox = document.getElementById("qkd-results");

    resBox.innerHTML += `<p class='log-line'>[QKD] Transmitting 1024 polarized photons across quantum link (Eve=${eveCheck})...</p>`;

    try {
        const response = await fetch("/api/qkd/run", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ eavesdropper: eveCheck })
        });
        const data = await response.json();

        if (data.is_secure) {
            resBox.innerHTML += `<p class='log-line'>[QKD SECURE] Sifted: ${data.sifted_key_length} bits | QBER: ${data.qber_percent}% < 11%</p>`;
            resBox.innerHTML += `<p class='log-line'>[KEY ESTABLISHED] 256-bit Key: ${data.final_quantum_key_hex.substring(0, 32)}...</p>`;
        } else {
            resBox.innerHTML += `<p class='log-alert'>[SECURITY BREACH DETECTED] Eve intercepted photons! QBER spiked to ${data.qber_percent}% (> 11% threshold)!</p>`;
            resBox.innerHTML += `<p class='log-alert'>[LINK ABORTED] Optical transmission terminated to prevent key compromise.</p>`;
        }
        resBox.scrollTop = resBox.scrollHeight;
    } catch (err) {
        resBox.innerHTML += `<p class='log-alert'>Error in QKD exchange: ${err}</p>`;
    }
}

// ----------------------------------------------------------------------------
// CyberVault-7 Cryptocurrency API Interaction
// ----------------------------------------------------------------------------
async function submitQuantumTx() {
    const resBox = document.getElementById("vault-results");
    resBox.innerHTML += `<p class='log-line'>[TX SUBMIT] Generating Lattice Ring-LWE Signature for 777.0 SYN...</p>`;

    try {
        const response = await fetch("/api/vault/submit_tx", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ amount: 777.0 })
        });
        const data = await response.json();

        resBox.innerHTML += `<p class='log-line'>[TX MINED] TxID: ${data.tx.tx_id.substring(0, 20)}... | PQC Sig: ${data.tx.pqc_signature.substring(0, 16)}...</p>`;
        resBox.innerHTML += `<p class='log-line'>[LEDGER] Total Committed Blocks: ${data.ledger_size}</p>`;
        resBox.scrollTop = resBox.scrollHeight;
    } catch (err) {
        resBox.innerHTML += `<p class='log-alert'>Transaction failed: ${err}</p>`;
    }
}

async function runAttackComparison() {
    const resBox = document.getElementById("vault-results");
    resBox.innerHTML += `<p class='log-alert'>[SIMULATING SHOR'S HEIST ON ECDSA VS SYNAPSE-7 LATTICE]...</p>`;

    try {
        const response = await fetch("/api/vault/attack_sim");
        const data = await response.json();

        resBox.innerHTML += `<p class='log-alert'>1. CLASSICAL BITCOIN/ECDSA: ${data.classical_ecdsa.result} (${data.classical_ecdsa.time_to_crack})</p>`;
        resBox.innerHTML += `<p class='log-line'>2. SYNAPSE-7 LATTICE DEFENSE: ${data.synapse7_quantum_defense.result} (Req: ${data.synapse7_quantum_defense.attack_complexity})</p>`;
        resBox.scrollTop = resBox.scrollHeight;
    } catch (err) {
        resBox.innerHTML += `<p class='log-alert'>Attack sim failed: ${err}</p>`;
    }
}
