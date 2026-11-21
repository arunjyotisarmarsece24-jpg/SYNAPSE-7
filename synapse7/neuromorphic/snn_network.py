"""
Deep Spiking Neural Network (SNN) Architecture with STBP Learning
Trained via Spatio-Temporal Backpropagation with Surrogate Gradients.
Performs real-time neuromorphic detection of Quantum Hardware Side-Channel
Power Glitches and Eavesdropping Anomalies.
"""

from typing import Dict, Any, Tuple, List, Optional
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim

from .lif_neuron import LIFNeuronLayer
from .spike_encoder import SpikeEncoder

class NeuromorphicCryptoGuardSNN(nn.Module):
    """
    Two-layer Deep Spiking Neural Network:
    Input (N_in) -> Hidden LIF (N_hidden, Adaptive Threshold) -> Output LIF (N_out classes)
    Trained end-to-end through time (STBP).
    """

    def __init__(self, in_features: int = 16, hidden_features: int = 48, out_features: int = 2,
                 num_timesteps: int = 25, dt_ms: float = 1.0):
        super().__init__()
        self.in_features = in_features
        self.hidden_features = hidden_features
        self.out_features = out_features
        self.num_timesteps = num_timesteps
        self.dt = dt_ms

        # Hidden Layer with Adaptive Threshold
        self.hidden_layer = LIFNeuronLayer(
            in_features=in_features,
            out_features=hidden_features,
            tau_m_ms=20.0,
            tau_adapt_ms=100.0,
            v_threshold=1.0,
            adaptive_threshold=True,
            soft_reset=False
        )

        # Readout / Output Layer
        self.output_layer = LIFNeuronLayer(
            in_features=hidden_features,
            out_features=out_features,
            tau_m_ms=15.0,
            v_threshold=0.8,
            adaptive_threshold=False,
            soft_reset=True
        )

    def forward(self, spike_inputs_temporal: torch.Tensor) -> Tuple[torch.Tensor, Dict[str, torch.Tensor]]:
        """
        Input shape: (T, Batch, in_features)
        Returns:
            out_rates: (Batch, out_features) - normalized firing rate per class
            telemetry: Dictionary containing full temporal traces (voltages, spikes)
        """
        T, B, _ = spike_inputs_temporal.shape

        # Propagate through hidden layer
        h_spikes, h_volts, h_ths = self.hidden_layer(spike_inputs_temporal)

        # Propagate through output layer
        o_spikes, o_volts, o_ths = self.output_layer(h_spikes)

        # Readout: compute firing rate across time window T
        # (T, B, out_features) -> mean over time dimension -> (B, out_features)
        out_rates = torch.mean(o_spikes, dim=0)

        telemetry = {
            "input_spikes": spike_inputs_temporal,
            "hidden_spikes": h_spikes,
            "hidden_voltages": h_volts,
            "hidden_thresholds": h_ths,
            "output_spikes": o_spikes,
            "output_voltages": o_volts,
            "out_rates": out_rates
        }
        return out_rates, telemetry

class SNNTrainingManager:
    """Manages online training, synthetic side-channel trace generation, and live telemetry buffering."""

    def __init__(self, in_features: int = 16, hidden_features: int = 48, out_features: int = 2,
                 num_timesteps: int = 25, lr: float = 0.01):
        self.in_features = in_features
        self.hidden_features = hidden_features
        self.out_features = out_features
        self.num_timesteps = num_timesteps
        
        self.model = NeuromorphicCryptoGuardSNN(
            in_features=in_features,
            hidden_features=hidden_features,
            out_features=out_features,
            num_timesteps=num_timesteps
        )
        self.optimizer = optim.Adam(self.model.parameters(), lr=lr)
        self.loss_fn = nn.CrossEntropyLoss()
        
        self.epoch_count = 0
        self.loss_history = []
        self.acc_history = []
        self.latest_telemetry = None

    def generate_synthetic_dataset(self, num_samples: int = 64) -> Tuple[torch.Tensor, torch.Tensor]:
        """
        Generates realistic cryptographic hardware power traces:
        Class 0: Benign Quantum Operation (smooth stationary Gaussian noise + 100MHz clock ripple).
        Class 1: Hostile Side-Channel Attack (DPA glitch, high-frequency power spikes & correlation bursts).
        """
        rng = np.random.default_rng(self.epoch_count + 42)
        half = num_samples // 2

        # Class 0: Benign
        benign_raw = rng.normal(loc=0.25, scale=0.08, size=(half, self.in_features))
        benign_labels = np.zeros(half, dtype=np.int64)

        # Class 1: Side-channel attack / DPA glitch
        attack_raw = rng.normal(loc=0.65, scale=0.15, size=(half, self.in_features))
        # Add intermittent sharp correlation peaks
        burst_idx = rng.choice(self.in_features, size=(half, 3))
        for i in range(half):
            attack_raw[i, burst_idx[i]] += 0.45
        attack_labels = np.ones(half, dtype=np.int64)

        raw_x = np.vstack([benign_raw, attack_raw])
        raw_y = np.concatenate([benign_labels, attack_labels])

        # Shuffle
        perm = rng.permutation(num_samples)
        raw_x = np.clip(raw_x[perm], 0.0, 1.0)
        raw_y = raw_y[perm]

        # Convert to Poisson spike trains: shape (T, Batch, in_features)
        spike_trains = SpikeEncoder.poisson_encode(raw_x, num_timesteps=self.num_timesteps, max_rate_hz=100.0)
        
        tensor_x = torch.from_numpy(spike_trains).float()
        tensor_y = torch.from_numpy(raw_y).long()
        return tensor_x, tensor_y

    def train_step(self) -> Dict[str, Any]:
        """Runs one full training epoch and returns rich telemetry for visualization."""
        self.model.train()
        self.optimizer.zero_grad()

        x_batch, y_batch = self.generate_synthetic_dataset(num_samples=32)
        out_rates, telemetry = self.model(x_batch)

        loss = self.loss_fn(out_rates, y_batch)
        loss.backward()
        self.optimizer.step()

        # Compute accuracy
        preds = torch.argmax(out_rates, dim=-1)
        acc = float((preds == y_batch).float().mean() * 100.0)

        self.epoch_count += 1
        loss_val = float(loss.item())
        self.loss_history.append(loss_val)
        self.acc_history.append(acc)

        # Extract sample 0 for oscilloscope & raster visualization
        sample_h_volts = telemetry["hidden_voltages"][:, 0, :].detach().cpu().numpy() # (T, hidden)
        sample_h_spikes = telemetry["hidden_spikes"][:, 0, :].detach().cpu().numpy()  # (T, hidden)
        sample_in_spikes = x_batch[:, 0, :].detach().cpu().numpy()                    # (T, in)
        sample_o_spikes = telemetry["output_spikes"][:, 0, :].detach().cpu().numpy()  # (T, out)
        
        w_hidden = self.model.hidden_layer.weight.detach().cpu().numpy() # (hidden, in)

        # Compute neuromorphic synaptic operations (SOPs)
        total_spikes = float(torch.sum(telemetry["hidden_spikes"]).item())
        # Energy: ~0.9 pJ per fixed-point SOP on 28nm Spartan-7 vs ~4.6 pJ for FP32 MAC
        est_energy_pj = total_spikes * self.hidden_features * 0.9

        result = {
            "epoch": self.epoch_count,
            "loss": round(loss_val, 4),
            "accuracy_percent": round(acc, 2),
            "est_energy_pj": round(est_energy_pj, 2),
            "hidden_weight_matrix": w_hidden.tolist(),
            "sample_raster": {
                "input_spikes": sample_in_spikes.tolist(),
                "hidden_spikes": sample_h_spikes.tolist(),
                "output_spikes": sample_o_spikes.tolist()
            },
            "sample_membrane_v": sample_h_volts[:, :4].tolist(), # First 4 hidden neurons
            "num_timesteps": self.num_timesteps
        }
        self.latest_telemetry = result
        return result
