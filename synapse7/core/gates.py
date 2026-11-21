"""
Quantum Gates Library for SYNAPSE-7
High-precision unitary operators for statevector and density matrix evolution.
"""

import numpy as np

# Single-Qubit Standard Basis Gates
GATE_I = np.array([[1.0, 0.0],
                   [0.0, 1.0]], dtype=np.complex128)

GATE_X = np.array([[0.0, 1.0],
                   [1.0, 0.0]], dtype=np.complex128)

GATE_Y = np.array([[0.0, -1.0j],
                   [1.0j, 0.0]], dtype=np.complex128)

GATE_Z = np.array([[1.0, 0.0],
                   [0.0, -1.0]], dtype=np.complex128)

GATE_H = (1.0 / np.sqrt(2.0)) * np.array([[1.0, 1.0],
                                          [1.0, -1.0]], dtype=np.complex128)

GATE_S = np.array([[1.0, 0.0],
                   [0.0, 1.0j]], dtype=np.complex128)

GATE_S_DAG = np.array([[1.0, 0.0],
                       [0.0, -1.0j]], dtype=np.complex128)

GATE_T = np.array([[1.0, 0.0],
                   [0.0, np.exp(1.0j * np.pi / 4.0)]], dtype=np.complex128)

GATE_T_DAG = np.array([[1.0, 0.0],
                       [0.0, np.exp(-1.0j * np.pi / 4.0)]], dtype=np.complex128)

# Parametric Rotation Gates
def rx(theta: float) -> np.ndarray:
    half = theta / 2.0
    return np.array([[np.cos(half), -1.0j * np.sin(half)],
                     [-1.0j * np.sin(half), np.cos(half)]], dtype=np.complex128)

def ry(theta: float) -> np.ndarray:
    half = theta / 2.0
    return np.array([[np.cos(half), -np.sin(half)],
                     [np.sin(half), np.cos(half)]], dtype=np.complex128)

def rz(theta: float) -> np.ndarray:
    half = theta / 2.0
    return np.array([[np.exp(-1.0j * half), 0.0],
                     [0.0, np.exp(1.0j * half)]], dtype=np.complex128)

def phase_gate(phi: float) -> np.ndarray:
    return np.array([[1.0, 0.0],
                     [0.0, np.exp(1.0j * phi)]], dtype=np.complex128)

# Multi-Qubit Entangling Gates
GATE_CNOT = np.array([
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 1.0],
    [0.0, 0.0, 1.0, 0.0]
], dtype=np.complex128)

GATE_CZ = np.array([
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, -1.0]
], dtype=np.complex128)

GATE_SWAP = np.array([
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 1.0]
], dtype=np.complex128)

GATE_TOFFOLI = np.eye(8, dtype=np.complex128)
GATE_TOFFOLI[6, 6] = 0.0
GATE_TOFFOLI[6, 7] = 1.0
GATE_TOFFOLI[7, 6] = 1.0
GATE_TOFFOLI[7, 7] = 0.0

NAMED_GATES = {
    "I": GATE_I,
    "X": GATE_X,
    "Y": GATE_Y,
    "Z": GATE_Z,
    "H": GATE_H,
    "S": GATE_S,
    "S^†": GATE_S_DAG,
    "T": GATE_T,
    "T^†": GATE_T_DAG,
    "CNOT": GATE_CNOT,
    "CZ": GATE_CZ,
    "SWAP": GATE_SWAP,
    "TOFFOLI": GATE_TOFFOLI
}
