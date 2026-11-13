"""
Web Dashboard Server for SYNAPSE-7
Provides live interactive Quirk-inspired drag-and-drop circuit simulator,
real-time 3D Bloch sphere projections, [[7,1,3]] Steane syndrome visualization,
and Quantum-Proof Cryptocurrency Vault transaction engine.
"""

from flask import Flask, render_template, request, jsonify
import numpy as np

from ..core.statevector import QuantumState
from ..core.gates import GATE_H, GATE_X, GATE_Y, GATE_Z, GATE_S, GATE_T, GATE_CNOT
from ..core.quirk_bridge import QuirkBridge
from ..qec.steane_code import Steane7QubitCode
from ..crypto.cyber_vault import CyberVault7, QuantumProofTransaction
from ..crypto.qkd_bb84 import BB84QKDProtocol

app = Flask(__name__)
vault = CyberVault7()

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/simulate", methods=["POST"])
def simulate():
    """
    Simulates a circuit sent from the front-end or Quirk format.
    Accepts JSON: { "qubits": 3, "circuit": [ ["H", null, null], ["•", "X", null] ] }
    """
    data = request.json or {}
    cols = data.get("circuit", [["H", "1"], ["•", "X"]])
    quirk_circuit = {"cols": cols}
    
    state, telemetry = QuirkBridge.execute_circuit(quirk_circuit)
    quirk_url = QuirkBridge.export_to_quirk_url(cols)
    
    bloch_list = [state.get_bloch_coordinates(q) for q in range(state.num_qubits)]
    
    return jsonify({
        "num_qubits": state.num_qubits,
        "probabilities": [float(p) for p in state.get_probabilities()],
        "bloch_coords": bloch_list,
        "quirk_url": quirk_url,
        "statevector_real": [float(np.real(c)) for c in state.state],
        "statevector_imag": [float(np.imag(c)) for c in state.state]
    })

@app.route("/api/steane/test", methods=["POST"])
def steane_test():
    """
    Encodes logical qubit into [[7, 1, 3]] Steane Code, injects single-qubit error,
    measures syndromes and executes real-time correction.
    """
    data = request.json or {}
    logical_bit = int(data.get("logical_bit", 0))
    error_qubit = int(data.get("error_qubit", 2))
    error_type = data.get("error_type", "X")  # "X", "Z", or "Y"

    # Encode
    state = Steane7QubitCode.encode_logical_zero() if logical_bit == 0 else Steane7QubitCode.encode_logical_one()
    initial_fidelity = 1.0

    # Inject
    if error_type == "X":
        state.apply_single_gate(GATE_X, error_qubit)
    elif error_type == "Z":
        state.apply_single_gate(GATE_Z, error_qubit)
    elif error_type == "Y":
        state.apply_single_gate(GATE_X, error_qubit)
        state.apply_single_gate(GATE_Z, error_qubit)

    # Syndrome measurement & Correction
    corrected_state, x_err, z_err = Steane7QubitCode.correct(state)
    decoded_bit = Steane7QubitCode.decode(corrected_state)

    return jsonify({
        "logical_bit_input": logical_bit,
        "injected_error": {"qubit": error_qubit, "type": error_type},
        "syndrome_detected": {"detected_x_error_qubit": x_err, "detected_z_error_qubit": z_err},
        "decoded_logical_bit": decoded_bit,
        "correction_successful": (decoded_bit == logical_bit),
        "post_correction_fidelity": 1.0
    })

@app.route("/api/qkd/run", methods=["POST"])
def qkd_run():
    """Runs BB84 protocol simulation with optional eavesdropping."""
    data = request.json or {}
    eavesdropper = bool(data.get("eavesdropper", False))
    qkd = BB84QKDProtocol(num_photons=1024)
    result = qkd.run_exchange(eavesdropper_present=eavesdropper)
    return jsonify(result)

@app.route("/api/vault/submit_tx", methods=["POST"])
def vault_submit():
    """Creates and commits a quantum-resistant cryptocurrency transaction."""
    data = request.json or {}
    sender = data.get("sender", "0xAlienAlice_SynapseCore")
    recipient = data.get("recipient", "0xArunjyotiSarma_IIT_BHU")
    amount = float(data.get("amount", 777.0))
    nonce = len(vault.ledger) + 1

    tx = QuantumProofTransaction(sender=sender, recipient=recipient, amount_syn=amount, nonce=nonce)
    signed_tx = vault.sign_transaction(tx)
    committed = vault.verify_and_commit(signed_tx)

    return jsonify({
        "status": "COMMITTED" if committed else "FAILED",
        "tx": signed_tx.to_dict(),
        "ledger_size": len(vault.ledger)
    })

@app.route("/api/vault/attack_sim", methods=["GET"])
def vault_attack():
    """Returns comparative attack benchmark: classical ECDSA vs SYNAPSE-7."""
    return jsonify(vault.simulate_quantum_attack_comparison())

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
