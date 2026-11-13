"""
Quantum Noise Channel and Adversarial Fault Injector for SYNAPSE-7
Simulates environmental decoherence, cosmic ray bit-flips, and hostile adversary injection.
"""

from typing import Tuple, Optional
import numpy as np
from ..core.statevector import QuantumState
from ..core.gates import GATE_X, GATE_Y, GATE_Z

class QuantumNoiseChannel:
    """Simulates realistic physical noise channels on multi-qubit registers."""

    def __init__(self, seed: Optional[int] = None):
        self.rng = np.random.default_rng(seed)

    def inject_bit_flip(self, state: QuantumState, qubit: int) -> QuantumState:
        """Adversarial deterministic Pauli X injection."""
        return state.apply_single_gate(GATE_X, qubit)

    def inject_phase_flip(self, state: QuantumState, qubit: int) -> QuantumState:
        """Adversarial deterministic Pauli Z injection."""
        return state.apply_single_gate(GATE_Z, qubit)

    def inject_depolarizing_noise(self, state: QuantumState, qubit: int, error_prob: float) -> Tuple[QuantumState, str]:
        """
        Applies depolarizing channel: with probability p, applies uniformly
        random Pauli X, Y, or Z error.
        """
        if self.rng.random() < error_prob:
            error_type = self.rng.choice(["X", "Y", "Z"])
            if error_type == "X":
                state.apply_single_gate(GATE_X, qubit)
            elif error_type == "Y":
                state.apply_single_gate(GATE_Y, qubit)
            elif error_type == "Z":
                state.apply_single_gate(GATE_Z, qubit)
            return state, error_type
        return state, "NONE"
