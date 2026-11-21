"""
Leaky Integrate-and-Fire (LIF) & Adaptive LIF (ALIF) Neuromorphic Dynamics
Includes:
1. Exact Euler discretized membrane potential evolution with hard/soft reset.
2. Refractory period dynamics and spike-frequency adaptation (SFA).
3. PyTorch Surrogate Gradient Autograd function (Fast-Sigmoid) for STBP learning.
"""

from typing import Tuple, Optional
import numpy as np
import torch
import torch.nn as nn

class SurrogateFastSigmoid(torch.autograd.Function):
    """
    Surrogate Gradient operator for non-differentiable Heaviside step spike generation.
    Forward: S = Theta(V - V_th)
    Backward: dS/dV = 1 / (1 + alpha * |V - V_th|)^2
    """
    alpha = 4.0

    @staticmethod
    def forward(ctx, v_membrane: torch.Tensor, v_threshold: torch.Tensor) -> torch.Tensor:
        ctx.save_for_backward(v_membrane, v_threshold)
        return (v_membrane >= v_threshold).to(v_membrane.dtype)

    @staticmethod
    def backward(ctx, grad_output: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        v_membrane, v_threshold = ctx.saved_tensors
        diff = v_membrane - v_threshold
        # Fast sigmoid surrogate derivative
        surrogate_grad = 1.0 / (1.0 + SurrogateFastSigmoid.alpha * torch.abs(diff)) ** 2
        grad_v = grad_output * surrogate_grad
        grad_th = -grad_output * surrogate_grad if v_threshold.requires_grad else None
        return grad_v, grad_th

class LIFNeuronLayer(nn.Module):
    """
    Fully-connected PyTorch Layer of Leaky Integrate-and-Fire Neurons with
    Spatio-Temporal Backpropagation (STBP) and adaptive threshold dynamics.
    """
    def __init__(self, in_features: int, out_features: int,
                 tau_m_ms: float = 20.0,
                 tau_adapt_ms: float = 100.0,
                 v_threshold: float = 1.0,
                 v_reset: float = 0.0,
                 v_rest: float = 0.0,
                 dt_ms: float = 1.0,
                 adaptive_threshold: bool = True,
                 soft_reset: bool = False):
        super().__init__()
        self.in_features = in_features
        self.out_features = out_features
        self.v_threshold_init = v_threshold
        self.v_reset = v_reset
        self.v_rest = v_rest
        self.dt = dt_ms
        self.soft_reset = soft_reset
        self.adaptive_threshold = adaptive_threshold
        
        # Decay coefficients
        self.beta = float(np.exp(-dt_ms / tau_m_ms))       # Membrane leak
        self.rho = float(np.exp(-dt_ms / tau_adapt_ms))    # Adaptation leak
        self.gamma = 0.2                                  # Threshold spike jump
        
        # Synaptic weight matrix
        self.weight = nn.Parameter(torch.empty(out_features, in_features))
        # Kaiming uniform initialization adapted for spiking dynamics
        nn.init.kaiming_uniform_(self.weight, a=np.sqrt(5))

        if self.adaptive_threshold:
            self.register_buffer("v_th_base", torch.full((out_features,), v_threshold))
        else:
            self.register_buffer("v_th_base", torch.tensor(v_threshold))

    def forward(self, spike_inputs_temporal: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """
        Forward simulation across time.
        Input: spike_inputs_temporal of shape (T, Batch, in_features)
        Returns:
            spikes: (T, Batch, out_features)
            voltages: (T, Batch, out_features) - recorded membrane potentials
            thresholds: (T, Batch, out_features) - recorded adaptive thresholds
        """
        T, B, _ = spike_inputs_temporal.shape
        device = spike_inputs_temporal.device

        v_m = torch.full((B, self.out_features), self.v_rest, device=device)
        v_th = torch.full((B, self.out_features), self.v_threshold_init, device=device)
        
        spikes_list = []
        voltages_list = []
        thresholds_list = []

        for t in range(T):
            x_t = spike_inputs_temporal[t] # (B, in_features)
            # Synaptic current integration: I_syn = X_t @ W.T
            i_syn = torch.matmul(x_t, self.weight.t())

            # Membrane voltage update: V[t] = beta * (V[t-1] - V_rest) + V_rest + I_syn
            v_m = self.beta * (v_m - self.v_rest) + self.v_rest + i_syn

            # Fire spike if V_m >= V_th
            spike = SurrogateFastSigmoid.apply(v_m, v_th)

            # Membrane reset
            if self.soft_reset:
                v_m = v_m - spike * v_th
            else:
                v_m = torch.where(spike > 0.5, torch.full_like(v_m, self.v_reset), v_m)

            # Adaptive threshold update
            if self.adaptive_threshold:
                v_th = self.rho * (v_th - self.v_th_base) + self.v_th_base + self.gamma * spike

            spikes_list.append(spike)
            voltages_list.append(v_m)
            thresholds_list.append(v_th)

        spikes = torch.stack(spikes_list, dim=0)       # (T, B, out_features)
        voltages = torch.stack(voltages_list, dim=0)   # (T, B, out_features)
        thresholds = torch.stack(thresholds_list, dim=0)
        return spikes, voltages, thresholds
