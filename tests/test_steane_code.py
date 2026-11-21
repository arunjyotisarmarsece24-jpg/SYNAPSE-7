import pytest
import numpy as np
from synapse7.qec.steane_code import Steane7QubitCode
from synapse7.core.gates import GATE_X, GATE_Z, GATE_Y

def test_steane_encode_and_decode_clean():
    s0 = Steane7QubitCode.encode_logical_zero()
    assert Steane7QubitCode.decode(s0) == 0

    s1 = Steane7QubitCode.encode_logical_one()
    assert Steane7QubitCode.decode(s1) == 1

def test_steane_correct_all_bit_flips():
    """Verify that any single-qubit Pauli X error across all 7 physical qubits is corrected with 100% fidelity."""
    original = Steane7QubitCode.encode_logical_zero()
    
    for corrupted_qubit in range(7):
        corrupted = original.clone()
        corrupted.apply_single_gate(GATE_X, corrupted_qubit)
        
        # Verify state is damaged
        assert corrupted.fidelity(original) < 0.5
        
        # Correct
        corrected, x_err, z_err = Steane7QubitCode.correct(corrupted)
        assert x_err == corrupted_qubit
        assert z_err == -1
        assert np.isclose(corrected.fidelity(original), 1.0)
        assert Steane7QubitCode.decode(corrected) == 0

def test_steane_correct_all_phase_flips():
    """Verify that any single-qubit Pauli Z error across all 7 physical qubits is corrected with 100% fidelity."""
    original = Steane7QubitCode.encode_logical_zero()
    
    for corrupted_qubit in range(7):
        corrupted = original.clone()
        corrupted.apply_single_gate(GATE_Z, corrupted_qubit)
        
        corrected, x_err, z_err = Steane7QubitCode.correct(corrupted)
        assert z_err == corrupted_qubit
        assert x_err == -1
        assert np.isclose(corrected.fidelity(original), 1.0)
        assert Steane7QubitCode.decode(corrected) == 0

def test_steane_correct_pauli_y():
    """Verify Pauli Y (simultaneous X and Z) error correction."""
    original = Steane7QubitCode.encode_logical_zero()
    corrupted = original.clone()
    corrupted.apply_single_gate(GATE_Y, 4)
    
    corrected, x_err, z_err = Steane7QubitCode.correct(corrupted)
    assert x_err == 4
    assert z_err == 4
    assert np.isclose(corrected.fidelity(original), 1.0)
