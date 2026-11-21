"""
[[7, 1, 3]] Steane Quantum Error Correction (QEC) Engine for SYNAPSE-7
The foundational 7-qubit CSS code providing fault-tolerant protection of 1 logical
qubit against arbitrary physical Pauli errors (X, Y, Z).
"""

from typing import Tuple, List, Optional
import numpy as np

from ..core.statevector import QuantumState
from ..core.gates import GATE_X, GATE_Z, GATE_H

class Steane7QubitCode:
    """
    Implementation of the Calderbank-Shor-Steane (CSS) [[7, 1, 3]] Steane Code.
    Encodes 1 logical qubit across 7 physical qubits.
    Corrects any arbitrary single-qubit error (bit-flip X, phase-flip Z, or both Y).
    """
    
    # 8 classical [7, 4, 3] dual Hamming codewords (even parity)
    # Binary representation: q0 q1 q2 q3 q4 q5 q6
    CODEWORDS_EVEN = [
        0b0000000,
        0b1010101,
        0b0110011,
        0b1100110,
        0b0001111,
        0b1011010,
        0b0111100,
        0b1101001
    ]

    # Parity check matrix generators:
    # Row 0 checks {q3, q4, q5, q6} (binary 4, 5, 6, 7)
    # Row 1 checks {q1, q2, q5, q6} (binary 2, 3, 6, 7)
    # Row 2 checks {q0, q2, q4, q6} (binary 1, 3, 5, 7)
    STABILIZER_MASKS = [
        [3, 4, 5, 6],  # Bit 2 of 1-based index (val 4)
        [1, 2, 5, 6],  # Bit 1 of 1-based index (val 2)
        [0, 2, 4, 6],  # Bit 0 of 1-based index (val 1)
    ]

    @classmethod
    def encode_logical_zero(cls) -> QuantumState:
        """Construct logical |0_L> state: equal superposition of all 8 dual Hamming codewords."""
        state = QuantumState(7)
        state.state.fill(0.0)
        amplitude = 1.0 / np.sqrt(8.0)
        for cw in cls.CODEWORDS_EVEN:
            state.state[cw] = amplitude
        return state

    @classmethod
    def encode_logical_one(cls) -> QuantumState:
        """Construct logical |1_L> state: X^(x7) |0_L>."""
        state = cls.encode_logical_zero()
        for q in range(7):
            state.apply_single_gate(GATE_X, q)
        return state

    @classmethod
    def encode_arbitrary(cls, alpha: complex, beta: complex) -> QuantumState:
        """Encode arbitrary logical state alpha |0_L> + beta |1_L>."""
        norm = np.sqrt(abs(alpha)**2 + abs(beta)**2)
        if norm < 1e-12:
            raise ValueError("State vector amplitude norm cannot be zero.")
        alpha /= norm
        beta /= norm
        
        q0 = cls.encode_logical_zero()
        q1 = cls.encode_logical_one()
        
        combined = QuantumState(7)
        combined.state = alpha * q0.state + beta * q1.state
        return combined

    @classmethod
    def measure_z_syndrome(cls, state: QuantumState) -> int:
        """
        Measure Z-stabilizers to detect Bit-Flip (X) errors.
        Returns 0 if no error, or 1-7 corresponding to the corrupted physical qubit.
        """
        # In a fault-tolerant simulation, the syndrome is computed via stabilizer expectation
        probs = state.get_probabilities()
        syndrome = 0

        for bit_pos, qubits in enumerate(cls.STABILIZER_MASKS):
            # Compute parity of bits in basis states that have non-zero probability
            # Parity of selected qubits across the state
            # For each basis state, parity = sum(bits in qubits) % 2
            parity_exp = 0.0
            for idx, p in enumerate(probs):
                if p > 1e-9:
                    par = sum((idx >> (6 - q)) & 1 for q in qubits) % 2
                    parity_exp += p * (1.0 if par == 0 else -1.0)
            
            # If eigenvalue is -1 (parity odd), stabilizer triggered
            if parity_exp < 0.0:
                syndrome |= (1 << (2 - bit_pos))
        
        return syndrome

    @classmethod
    def measure_x_syndrome(cls, state: QuantumState) -> int:
        """
        Measure X-stabilizers to detect Phase-Flip (Z) errors.
        Applies Hadamard on all qubits, checks parity, and returns syndrome 0-7.
        """
        # Transform X stabilizers to Z stabilizers via H^⊗7
        temp = state.clone()
        for q in range(7):
            temp.apply_single_gate(GATE_H, q)
        
        return cls.measure_z_syndrome(temp)

    @classmethod
    def correct(cls, state: QuantumState) -> Tuple[QuantumState, int, int]:
        """
        Full fault-tolerant syndrome measurement & error correction.
        Detects bit flips (X) via Z-syndrome and phase flips (Z) via X-syndrome,
        applies corrective Pauli operators, and returns (corrected_state, x_error_qubit, z_error_qubit).
        """
        # 1. Detect bit-flips
        z_syn = cls.measure_z_syndrome(state)
        bit_error_qubit = -1
        if z_syn > 0:
            bit_error_qubit = z_syn - 1  # 0-indexed qubit
            state.apply_single_gate(GATE_X, bit_error_qubit)

        # 2. Detect phase-flips
        x_syn = cls.measure_x_syndrome(state)
        phase_error_qubit = -1
        if x_syn > 0:
            phase_error_qubit = x_syn - 1
            state.apply_single_gate(GATE_Z, phase_error_qubit)

        return state, bit_error_qubit, phase_error_qubit

    @classmethod
    def decode(cls, state: QuantumState) -> int:
        """
        Measure logical operator Z_L = Z^⊗7 to decode logical bit (0 or 1).
        Every basis state in |0_L> has even weight (parity 0).
        Every basis state in |1_L> has odd weight (parity 1).
        """
        temp = state.clone()
        bitstring = temp.measure_all()
        # Parity of 1s in codeword gives exact logical eigenvalue
        ones = sum(int(b) for b in bitstring)
        return ones % 2
