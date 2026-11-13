"""
Spike-Timing-Dependent Plasticity (STDP) Online Synaptic Learning Engine
Implements biologically realistic, local, unsupervised Hebbian learning using
exponential synaptic traces (Song, Miller & Abbott, 2000).
Hardware-synthesizable for on-chip online learning on Spartan-7 FPGA.
"""

from typing import Tuple, Optional
import numpy as np

class STDPSynapsePool:
    """
    Synaptic crossbar array updated online via continuous pre- and post-synaptic traces.
    LTP: Pre fires before Post -> Potentiation (Hebbian reinforcement).
    LTD: Post fires before Pre -> Depression (Anti-Hebbian pruning).
    """

    def __init__(self, num_pre: int, num_post: int,
                 w_min: float = 0.0,
                 w_max: float = 1.0,
                 a_plus: float = 0.015,
                 a_minus: float = 0.012,
                 tau_plus_ms: float = 20.0,
                 tau_minus_ms: float = 20.0,
                 dt_ms: float = 1.0,
                 seed: Optional[int] = None):
        self.num_pre = num_pre
        self.num_post = num_post
        self.w_min = w_min
        self.w_max = w_max
        self.a_plus = a_plus
        self.a_minus = a_minus
        
        # Exponential trace decay factors
        self.decay_pre = float(np.exp(-dt_ms / tau_plus_ms))
        self.decay_post = float(np.exp(-dt_ms / tau_minus_ms))
        
        self.rng = np.random.default_rng(seed)
        # Initialize synaptic weights uniformly in [0.2, 0.6]
        self.weights = self.rng.uniform(0.2, 0.6, size=(num_post, num_pre)).astype(np.float32)
        
        # Online traces: pre-synaptic trace x_j, post-synaptic trace y_i
        self.pre_trace = np.zeros(num_pre, dtype=np.float32)
        self.post_trace = np.zeros(num_post, dtype=np.float32)
        
        # Learning telemetry history
        self.weight_history = []
        self.sops_count = 0  # Synaptic operations counter

    def reset_traces(self):
        self.pre_trace.fill(0.0)
        self.post_trace.fill(0.0)

    def step(self, pre_spikes: np.ndarray, post_spikes: np.ndarray) -> np.ndarray:
        """
        Executes one timestep dt of online trace-based STDP:
        dx_j/dt = -x_j/tau_+ + S_j_pre
        dy_i/dt = -y_i/tau_- + S_i_post
        dW_ij = A_+ * x_j * S_i_post - A_- * y_i * S_j_pre
        """
        pre_spikes = pre_spikes.astype(np.float32)
        post_spikes = post_spikes.astype(np.float32)

        # Decay previous traces and accumulate incoming spikes
        self.pre_trace = self.decay_pre * self.pre_trace + pre_spikes
        self.post_trace = self.decay_post * self.post_trace + post_spikes

        # Count Synaptic Operations (SOPs): active when pre_spikes == 1
        num_active_pre = np.sum(pre_spikes > 0.5)
        self.sops_count += int(num_active_pre * self.num_post)

        # 1. LTP: Post-synaptic spike triggers potentiation proportional to pre_trace
        # dW_ltp[i, j] = A_+ * post_spikes[i] * pre_trace[j]
        # Multiplicative weight dependence: (W_max - W)
        dw_ltp = self.a_plus * np.outer(post_spikes, self.pre_trace) * (self.w_max - self.weights)

        # 2. LTD: Pre-synaptic spike triggers depression proportional to post_trace
        # dW_ltd[i, j] = A_- * post_trace[i] * pre_spikes[j]
        # Multiplicative weight dependence: (W - W_min)
        dw_ltd = self.a_minus * np.outer(self.post_trace, pre_spikes) * (self.weights - self.w_min)

        # Total delta W
        delta_w = dw_ltp - dw_ltd
        self.weights = np.clip(self.weights + delta_w, self.w_min, self.w_max)

        return self.weights

    def get_sparsity(self, pre_spikes_temporal: np.ndarray) -> float:
        """Percentage of zeros in spike activations (biological energy sparsity)."""
        zeros = np.sum(pre_spikes_temporal == 0)
        total = pre_spikes_temporal.size
        return float(zeros / total * 100.0) if total > 0 else 100.0
