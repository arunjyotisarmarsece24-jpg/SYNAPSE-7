"""
Statevector Quantum Simulation Engine for SYNAPSE-7
Matrix-free tensor-contraction simulator supporting up to 24+ qubits with
Bloch sphere projection, reduced density matrix extraction, and projective measurements.
"""

from typing import List, Tuple, Optional, Union
import numpy as np
from .gates import GATE_X, GATE_Y, GATE_Z, GATE_H, GATE_CNOT, GATE_CZ, GATE_SWAP

class QuantumState:
    def __init__(self, num_qubits: int):
        if num_qubits < 1:
            raise ValueError("Number of qubits must be at least 1.")
        self.num_qubits = num_qubits
        self.dim = 1 << num_qubits
        # Ground state |0...0>
        self.state = np.zeros(self.dim, dtype=np.complex128)
        self.state[0] = 1.0 + 0.0j

    @classmethod
    def from_vector(cls, vector: np.ndarray) -> "QuantumState":
        dim = len(vector)
        num_qubits = int(np.round(np.log2(dim)))
        if (1 << num_qubits) != dim:
            raise ValueError("Vector length must be a power of 2.")
        norm = np.linalg.norm(vector)
        if norm < 1e-12:
            raise ValueError("Cannot initialize from zero norm vector.")
        qs = cls(num_qubits)
        qs.state = (vector / norm).astype(np.complex128)
        return qs

    def clone(self) -> "QuantumState":
        cloned = QuantumState(self.num_qubits)
        cloned.state = np.copy(self.state)
        return cloned

    def reset(self):
        self.state.fill(0.0)
        self.state[0] = 1.0 + 0.0j

    def apply_single_gate(self, gate: np.ndarray, target: int) -> "QuantumState":
        if not (0 <= target < self.num_qubits):
            raise IndexError(f"Target qubit {target} out of range [0, {self.num_qubits - 1}]")
        
        # Reshape statevector into tensor of rank num_qubits
        shape = [2] * self.num_qubits
        tensor = self.state.reshape(shape)
        
        # Contract axis target with gate: (i, j) * (... j ...) -> (i, ... ...)
        contracted = np.tensordot(gate, tensor, axes=(1, target))
        # Move axis 0 (the new target axis) back to index target
        contracted = np.moveaxis(contracted, 0, target)
        self.state = contracted.reshape(-1)
        return self

    def apply_cnot(self, control: int, target: int) -> "QuantumState":
        return self.apply_two_qubit_gate(GATE_CNOT, control, target)

    def apply_cz(self, control: int, target: int) -> "QuantumState":
        return self.apply_two_qubit_gate(GATE_CZ, control, target)

    def apply_swap(self, q1: int, q2: int) -> "QuantumState":
        return self.apply_two_qubit_gate(GATE_SWAP, q1, q2)

    def apply_two_qubit_gate(self, gate_4x4: np.ndarray, q1: int, q2: int) -> "QuantumState":
        if q1 == q2:
            raise ValueError("Control and target qubits cannot be identical.")
        if not (0 <= q1 < self.num_qubits and 0 <= q2 < self.num_qubits):
            raise IndexError("Qubit indices out of range.")

        # Gate representation in rank-4 tensor (out1, out2, in1, in2)
        gate_tensor = gate_4x4.reshape((2, 2, 2, 2))
        shape = [2] * self.num_qubits
        tensor = self.state.reshape(shape)

        # Contract input indices with target axes
        # We need to be careful with axis ordering
        if q1 < q2:
            # First contract q2, then q1
            contracted = np.tensordot(gate_tensor, tensor, axes=([2, 3], [q1, q2]))
            # contracted has shape (2, 2, remaining...)
            # Move axis 0 to q1, axis 1 to q2
            res = np.moveaxis(contracted, [0, 1], [q1, q2])
        else:
            # Gate expects (q1, q2) input order
            # Swap input indices of gate to match tensor contraction
            transposed_gate = np.transpose(gate_tensor, (0, 1, 3, 2))
            contracted = np.tensordot(transposed_gate, tensor, axes=([2, 3], [q2, q1]))
            res = np.moveaxis(contracted, [0, 1], [q1, q2])

        self.state = res.reshape(-1)
        return self

    def apply_toffoli(self, c1: int, c2: int, target: int) -> "QuantumState":
        """Decompose Toffoli into standard universal Clifford+T gates."""
        # Standard optimal fault-tolerant Clifford+T decomposition
        self.apply_single_gate(GATE_H, target)
        self.apply_cnot(c2, target)
        self.apply_single_gate(np.array([[1, 0], [0, np.exp(-1j * np.pi / 4)]], dtype=np.complex128), target)
        self.apply_cnot(c1, target)
        self.apply_single_gate(np.array([[1, 0], [0, np.exp(1j * np.pi / 4)]], dtype=np.complex128), target)
        self.apply_cnot(c2, target)
        self.apply_single_gate(np.array([[1, 0], [0, np.exp(-1j * np.pi / 4)]], dtype=np.complex128), target)
        self.apply_cnot(c1, target)
        self.apply_single_gate(np.array([[1, 0], [0, np.exp(1j * np.pi / 4)]], dtype=np.complex128), c2)
        self.apply_single_gate(np.array([[1, 0], [0, np.exp(1j * np.pi / 4)]], dtype=np.complex128), target)
        self.apply_cnot(c1, c2)
        self.apply_single_gate(GATE_H, target)
        self.apply_single_gate(np.array([[1, 0], [0, np.exp(1j * np.pi / 4)]], dtype=np.complex128), c1)
        self.apply_single_gate(np.array([[1, 0], [0, np.exp(-1j * np.pi / 4)]], dtype=np.complex128), c2)
        self.apply_cnot(c1, c2)
        return self

    def get_probabilities(self) -> np.ndarray:
        return np.abs(self.state) ** 2

    def get_reduced_density_matrix(self, qubit: int) -> np.ndarray:
        """Trace out all qubits except `qubit`, returning a 2x2 density matrix."""
        if not (0 <= qubit < self.num_qubits):
            raise IndexError("Qubit index out of bounds.")
        
        shape = [2] * self.num_qubits
        tensor = self.state.reshape(shape)
        # Permute target qubit to axis 0
        axes = [qubit] + [i for i in range(self.num_qubits) if i != qubit]
        transposed = np.transpose(tensor, axes)
        # Flatten remaining into (2, 2^(n-1))
        matrix = transposed.reshape((2, -1))
        # rho = matrix @ matrix^dagger
        rho = matrix @ np.conjugate(matrix.T)
        return rho

    def get_bloch_coordinates(self, qubit: int) -> Tuple[float, float, float]:
        """Compute (x, y, z) Bloch sphere coordinates for target qubit."""
        rho = self.get_reduced_density_matrix(qubit)
        # rx = Tr(rho * sigma_x) = 2 * Re(rho_01)
        # ry = Tr(rho * sigma_y) = 2 * Im(rho_10) = -2 * Im(rho_01)
        # rz = Tr(rho * sigma_z) = rho_00 - rho_11
        rx = float(2.0 * np.real(rho[0, 1]))
        ry = float(2.0 * np.imag(rho[1, 0]))
        rz = float(np.real(rho[0, 0] - rho[1, 1]))
        return rx, ry, rz

    def measure(self, qubit: int, collapse: bool = True, rng: Optional[np.random.Generator] = None) -> int:
        """Projective measurement of a single qubit in computational basis Z."""
        if rng is None:
            rng = np.random.default_rng()
        
        rho = self.get_reduced_density_matrix(qubit)
        prob_0 = np.clip(np.real(rho[0, 0]), 0.0, 1.0)
        
        outcome = 0 if rng.random() < prob_0 else 1
        
        if collapse:
            # Projective projector: zero out states where target != outcome and re-normalize
            shape = [2] * self.num_qubits
            tensor = self.state.reshape(shape)
            indexer = [slice(None)] * self.num_qubits
            indexer[qubit] = 1 - outcome  # Invalidate the unmeasured branch
            tensor[tuple(indexer)] = 0.0
            norm = np.linalg.norm(tensor)
            if norm > 1e-12:
                tensor /= norm
            self.state = tensor.reshape(-1)
            
        return outcome

    def measure_all(self, rng: Optional[np.random.Generator] = None) -> str:
        """Measure all qubits and return bitstring 'b_0 b_1 ... b_{n-1}'."""
        if rng is None:
            rng = np.random.default_rng()
        probs = self.get_probabilities()
        idx = rng.choice(len(probs), p=probs)
        bitstring = format(idx, f"0{self.num_qubits}b")
        self.state.fill(0.0)
        self.state[idx] = 1.0 + 0.0j
        return bitstring

    def fidelity(self, other: "QuantumState") -> float:
        """Fidelity |<psi|phi>|^2."""
        if self.dim != other.dim:
            raise ValueError("State dimension mismatch.")
        overlap = np.vdot(self.state, other.state)
        return float(np.abs(overlap) ** 2)

    def __repr__(self) -> str:
        return f"QuantumState(qubits={self.num_qubits}, norm={np.linalg.norm(self.state):.4f})"
