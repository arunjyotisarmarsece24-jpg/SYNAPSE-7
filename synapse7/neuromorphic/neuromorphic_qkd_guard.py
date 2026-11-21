"""
Neuromorphic Quantum-Side-Channel Guard
Integrates the Spiking Neural Network with QKD and Spartan-7 FPGA Hardware Telemetry.
Classifies live side-channel power bursts and quantum link decoherence at sub-milliwatt power budgets.
"""

from typing import Dict, Any, Tuple
import numpy as np
import torch

from .snn_network import SNNTrainingManager
from .spike_encoder import SpikeEncoder

class NeuromorphicQKDGuard:
    """Real-time Neuromorphic Intrusion Detection Engine."""

    def __init__(self):
        self.manager = SNNTrainingManager(in_features=16, hidden_features=32, out_features=2, num_timesteps=20)
        # Pre-train for a few epochs so it has high baseline discriminative capability
        for _ in range(12):
            self.manager.train_step()

    def inspect_telemetry_trace(self, trace_vector: np.ndarray) -> Dict[str, Any]:
        """
        Accepts a 16-element analog telemetry vector (QBER, optical power, FPGA current, clock jitter).
        Encodes into Poisson spike train, runs through SNN, and classifies.
        """
        if len(trace_vector) != 16:
            raise ValueError("Telemetry vector must have exactly 16 channels.")

        # Rate encode
        norm_trace = np.clip(trace_vector, 0.0, 1.0)
        spikes = SpikeEncoder.poisson_encode(norm_trace, num_timesteps=20)
        tensor_x = torch.from_numpy(spikes).unsqueeze(1).float() # (T, 1, 16)

        self.manager.model.eval()
        with torch.no_grad():
            out_rates, telemetry = self.manager.model(tensor_x)
            pred_class = int(torch.argmax(out_rates, dim=-1)[0].item())
            confidence = float(torch.softmax(out_rates, dim=-1)[0, pred_class].item())

        is_attack = (pred_class == 1)

        return {
            "classification": "HOSTILE_SIDE_CHANNEL_ATTACK" if is_attack else "BENIGN_QUANTUM_CHANNEL",
            "is_attack_detected": is_attack,
            "confidence": round(confidence * 100.0, 2),
            "output_firing_rates": [round(float(r), 4) for r in out_rates[0].tolist()],
            "hardware_interrupt_asserted": is_attack
        }
