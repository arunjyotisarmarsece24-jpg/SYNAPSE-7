import pytest
import numpy as np
from synapse7.core.quirk_bridge import QuirkBridge

def test_quirk_circuit_execution():
    circuit = {
        "cols": [
            ["H", "1"],
            ["•", "X"]
        ]
    }
    state, telemetry = QuirkBridge.execute_circuit(circuit)
    assert state.num_qubits == 2
    probs = state.get_probabilities()
    assert np.isclose(probs[0], 0.5)
    assert np.isclose(probs[3], 0.5)
    assert len(telemetry) == 2

def test_quirk_url_export():
    cols = [["H", "1"], ["•", "X"]]
    url = QuirkBridge.export_to_quirk_url(cols)
    assert url.startswith("https://algassert.com/quirk#circuit=")
    assert "cols" in url

def test_steane_quirk_circuit_builder():
    cols = QuirkBridge.build_steane_7qubit_quirk_circuit()
    assert len(cols) > 0
    url = QuirkBridge.export_to_quirk_url(cols)
    assert len(url) > 50
