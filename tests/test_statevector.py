import numpy as np
import pytest
from synapse7.core.statevector import QuantumState
from synapse7.core.gates import GATE_H, GATE_X, GATE_Z, GATE_Y

def test_ground_state_initialization():
    qs = QuantumState(3)
    assert qs.dim == 8
    assert np.isclose(qs.state[0], 1.0)
    assert np.allclose(qs.state[1:], 0.0)

def test_hadamard_superposition():
    qs = QuantumState(1)
    qs.apply_single_gate(GATE_H, 0)
    expected = (1.0 / np.sqrt(2.0)) * np.array([1.0, 1.0])
    assert np.allclose(qs.state, expected)
    rx, ry, rz = qs.get_bloch_coordinates(0)
    assert np.isclose(rx, 1.0)
    assert np.isclose(ry, 0.0)
    assert np.isclose(rz, 0.0)

def test_bell_state_entanglement():
    qs = QuantumState(2)
    qs.apply_single_gate(GATE_H, 0)
    qs.apply_cnot(0, 1)
    # (|00> + |11>) / sqrt(2)
    expected = np.zeros(4, dtype=complex)
    expected[0] = 1.0 / np.sqrt(2.0)
    expected[3] = 1.0 / np.sqrt(2.0)
    assert np.allclose(qs.state, expected)

    # Entangled qubits have maximally mixed reduced states
    rx0, ry0, rz0 = qs.get_bloch_coordinates(0)
    rx1, ry1, rz1 = qs.get_bloch_coordinates(1)
    assert np.allclose([rx0, ry0, rz0], [0.0, 0.0, 0.0])
    assert np.allclose([rx1, ry1, rz1], [0.0, 0.0, 0.0])

def test_toffoli_gate():
    qs = QuantumState(3)
    # Set q0 = 1, q1 = 1 -> target q2 should flip to 1
    qs.apply_single_gate(GATE_X, 0)
    qs.apply_single_gate(GATE_X, 1)
    qs.apply_toffoli(0, 1, 2)
    # Resulting state should be |111> (index 7)
    assert np.isclose(abs(qs.state[7]), 1.0)
