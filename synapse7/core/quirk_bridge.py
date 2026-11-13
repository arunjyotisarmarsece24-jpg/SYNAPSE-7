"""
Quirk Quantum Circuit Bridge for SYNAPSE-7
Provides seamless bi-directional integration with Craig Gidney's Quirk quantum simulator.
Parses Quirk circuit JSON, runs simulations, computes live Bloch coordinates,
and generates direct Quirk URLs for browser drag-and-drop live inspection.
"""

import json
import urllib.parse
from typing import List, Dict, Any, Tuple, Optional
import numpy as np

from .statevector import QuantumState
from .gates import (
    GATE_I, GATE_X, GATE_Y, GATE_Z, GATE_H,
    GATE_S, GATE_S_DAG, GATE_T, GATE_T_DAG,
    rx, ry, rz
)

# Quirk gate symbol mapping to Synapse-7 operators
QUIRK_SINGLE_GATE_MAP = {
    "H": GATE_H,
    "X": GATE_X,
    "Y": GATE_Y,
    "Z": GATE_Z,
    "S": GATE_S,
    "S^†": GATE_S_DAG,
    "Z^½": GATE_S,
    "Z^-½": GATE_S_DAG,
    "T": GATE_T,
    "T^†": GATE_T_DAG,
    "Z^¼": GATE_T,
    "Z^-¼": GATE_T_DAG,
    "1": GATE_I
}

class QuirkBridge:
    """Bi-directional bridge between SYNAPSE-7 engine and Quirk browser simulator."""
    
    BASE_QUIRK_URL = "https://algassert.com/quirk#circuit="

    @staticmethod
    def parse_circuit(circuit_json_or_dict: Any) -> Dict[str, Any]:
        if isinstance(circuit_json_or_dict, str):
            return json.loads(circuit_json_or_dict)
        return circuit_json_or_dict

    @staticmethod
    def execute_circuit(circuit_dict: Dict[str, Any], initial_qubits: Optional[int] = None) -> Tuple[QuantumState, List[Dict[str, Any]]]:
        """
        Simulate a Quirk circuit column-by-column.
        Returns:
            final_state: The resulting QuantumState.
            telemetry_history: Step-by-step state telemetry (probabilities, Bloch vectors) after each column.
        """
        cols = circuit_dict.get("cols", [])
        
        # Infer qubit count from largest column width
        max_wire = 0
        for col in cols:
            max_wire = max(max_wire, len(col))
        
        num_qubits = max(initial_qubits or 0, max_wire, 1)
        state = QuantumState(num_qubits)
        telemetry = []

        for col_idx, col in enumerate(cols):
            controls = []
            targets_cnot = []
            targets_cz = []

            # First pass: identify multi-qubit controls and targets
            for wire, gate in enumerate(col):
                if gate == "•" or gate == "control":
                    controls.append(wire)
                elif gate == "X" or gate == "⊕":
                    targets_cnot.append(wire)
                elif gate == "Z":
                    targets_cz.append(wire)

            # If there's a control and target, apply multi-qubit gate
            if controls and targets_cnot:
                for c in controls:
                    for t in targets_cnot:
                        state.apply_cnot(c, t)
            elif controls and targets_cz:
                for c in controls:
                    for t in targets_cz:
                        state.apply_cz(c, t)
            else:
                # Apply single-qubit gates
                for wire, gate in enumerate(col):
                    gate_str = str(gate)
                    if gate_str in QUIRK_SINGLE_GATE_MAP:
                        g_matrix = QUIRK_SINGLE_GATE_MAP[gate_str]
                        state.apply_single_gate(g_matrix, wire)

            # Record column telemetry for live visualization
            bloch_vectors = [state.get_bloch_coordinates(q) for q in range(num_qubits)]
            telemetry.append({
                "column": col_idx,
                "bloch": bloch_vectors,
                "probabilities": state.get_probabilities().tolist()
            })

        return state, telemetry

    @staticmethod
    def export_to_quirk_url(cols: List[List[Any]]) -> str:
        """Generate a clickable, instant Quirk URL for browser drag-and-drop live inspection."""
        circuit_data = {"cols": cols}
        encoded = urllib.parse.quote(json.dumps(circuit_data, separators=(",", ":")))
        return f"{QuirkBridge.BASE_QUIRK_URL}{encoded}"

    @staticmethod
    def build_steane_7qubit_quirk_circuit() -> List[List[Any]]:
        """
        Construct the [[7, 1, 3]] Steane Code encoding circuit for Quirk.
        Encodes logical qubit q0 into 7 physical qubits (q0 through q6).
        """
        return [
            # Initialize ancillas in |+> states
            ["H", 1, 1, "H", 1, "H", 1],
            # CSS generator entanglement lattice
            ["•", 1, 1, "X", 1, 1, 1],
            [1, 1, 1, "•", "X", 1, 1],
            [1, 1, 1, "•", 1, "X", 1],
            [1, 1, 1, 1, 1, "•", "X"],
            ["•", 1, "X", 1, 1, 1, 1],
            [1, "•", 1, 1, "X", 1, 1],
            [1, 1, 1, 1, 1, "•", "X"]
        ]
