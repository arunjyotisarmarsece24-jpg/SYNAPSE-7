"""
Spike Encoding Module for SYNAPSE-7 Neuromorphic Subsystem
Implements Poisson Rate Coding, Time-to-First-Spike (TTFS) Latency Coding,
and Event-Based Temporal Delta Modulation (DVS / Cochlear paradigm).
"""

from typing import Tuple, Optional
import numpy as np
import torch

class SpikeEncoder:
    """Transforms continuous analog telemetry and crypto side-channel traces into discrete spike trains."""

    @staticmethod
    def poisson_encode(inputs: np.ndarray, num_timesteps: int, max_rate_hz: float = 100.0, dt_ms: float = 1.0, rng: Optional[np.random.Generator] = None) -> np.ndarray:
        """
        Generates inhomogeneous Poisson spike trains S[t, i] in {0, 1}.
        Probability of spike per timestep dt: P(spike) = rate * dt.
        Inputs: normalized array in [0, 1].
        Output: shape (num_timesteps, *inputs.shape) binary array.
        """
        if rng is None:
            rng = np.random.default_rng()
        
        # Scale inputs to instantaneous firing probabilities
        prob = np.clip(inputs * (max_rate_hz * (dt_ms / 1000.0)), 0.0, 1.0)
        
        # Draw uniform random samples across all timesteps
        shape = (num_timesteps,) + inputs.shape
        rand_vals = rng.random(shape)
        
        # Broadcast prob across timesteps
        spikes = (rand_vals < prob).astype(np.float32)
        return spikes

    @staticmethod
    def latency_encode(inputs: np.ndarray, num_timesteps: int, tau: float = 5.0) -> np.ndarray:
        """
        Time-to-First-Spike (TTFS) temporal latency coding.
        Stronger inputs fire earlier according to logarithmic or linear decay:
        t_spike = round((num_timesteps - 1) * (1 - input))
        """
        inputs_clamped = np.clip(inputs, 1e-4, 1.0)
        # Latency index in [0, num_timesteps - 1]
        spike_times = np.round((num_timesteps - 1) * (1.0 - inputs_clamped)).astype(int)
        
        shape = (num_timesteps,) + inputs.shape
        spikes = np.zeros(shape, dtype=np.float32)
        
        # Vectorized assignment
        for idx in np.ndindex(inputs.shape):
            t = spike_times[idx]
            if 0 <= t < num_timesteps:
                spikes[(t,) + idx] = 1.0
                
        return spikes

    @staticmethod
    def delta_modulation(signal: np.ndarray, threshold: float = 0.05) -> Tuple[np.ndarray, np.ndarray]:
        """
        Event-based temporal derivative encoder (ON/OFF events).
        Fires ON spike when delta_V > +threshold.
        Fires OFF spike when delta_V < -threshold.
        """
        T = len(signal)
        on_spikes = np.zeros(T, dtype=np.float32)
        off_spikes = np.zeros(T, dtype=np.float32)
        
        last_val = signal[0]
        for t in range(1, T):
            diff = signal[t] - last_val
            if diff >= threshold:
                on_spikes[t] = 1.0
                last_val = signal[t]
            elif diff <= -threshold:
                off_spikes[t] = 1.0
                last_val = signal[t]
                
        return on_spikes, off_spikes
