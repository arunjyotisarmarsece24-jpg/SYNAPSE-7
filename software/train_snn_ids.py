#!/usr/bin/env python3
"""
===============================================================================
SYNAPSE-7: PyTorch SNN Training & Weight Quantization Pipeline
Project: SYNAPSE-7 (Neuromorphic-Quantum Hardware Security on Spartan-7)
===============================================================================
Trains an 8-input, 8-output Leaky Integrate-and-Fire (LIF) network using
surrogate gradient descent to detect microarchitectural side channels and
malicious packet floods. Exports 8-bit quantized weights directly to
Verilog hex memory format (`snn_weights.mem`).
"""

import os
import torch
import torch.nn as nn
import numpy as np

# Surrogate gradient function for non-differentiable Dirac spike step
class SurrogateSpike(torch.autograd.Function):
    @staticmethod
    def forward(ctx, input_val):
        ctx.save_for_backward(input_val)
        return (input_val > 0.0).float()

    @staticmethod
    def backward(ctx, grad_output):
        (input_val,) = ctx.saved_tensors
        # Fast sigmoid surrogate gradient
        alpha = 10.0
        grad_input = grad_output / (alpha * torch.abs(input_val) + 1.0) ** 2
        return grad_input

spike_fn = SurrogateSpike.apply

class HardwareLIFLayer(nn.Module):
    def __init__(self, in_features=8, out_features=8, decay=0.875, threshold=1.0):
        super().__init__()
        self.in_features = in_features
        self.out_features = out_features
        self.decay = decay
        self.threshold = threshold
        # Synaptic weight matrix
        self.weight = nn.Parameter(torch.randn(out_features, in_features) * 0.3)

    def forward(self, spike_trains):
        # spike_trains: [batch_size, time_steps, in_features]
        batch_size, time_steps, _ = spike_trains.shape
        v_mem = torch.zeros(batch_size, self.out_features, device=spike_trains.device)
        output_spikes = []

        for t in range(time_steps):
            syn_input = torch.matmul(spike_trains[:, t, :], self.weight.t())
            # Leaky integration: V[t] = V[t-1] * decay + I[t]
            v_mem = v_mem * self.decay + syn_input
            # Spike firing
            spikes = spike_fn(v_mem - self.threshold)
            # Reset by subtraction / clamp
            v_mem = v_mem * (1.0 - spikes)
            output_spikes.append(spikes)

        return torch.stack(output_spikes, dim=1) # [batch_size, time_steps, out_features]

def generate_synthetic_security_dataset(num_samples=1000, time_steps=32):
    # Class 0: Normal background traffic (sparse spikes, rate ~ 0.05)
    # Class 1: Attack / Side-Channel Glitch (dense bursts across specific channels, rate ~ 0.6)
    x = []
    y = []
    for _ in range(num_samples // 2):
        # Normal
        spikes = (torch.rand(time_steps, 8) < 0.05).float()
        x.append(spikes)
        y.append(0)

    for _ in range(num_samples // 2):
        # Attack
        spikes = torch.zeros(time_steps, 8)
        burst_channels = [0, 1, 4, 7]
        for c in burst_channels:
            spikes[:, c] = (torch.rand(time_steps) < 0.65).float()
        x.append(spikes)
        y.append(1)

    return torch.stack(x), torch.tensor(y, dtype=torch.long)

def train_and_export():
    print("=" * 70)
    print("  SYNAPSE-7: Training Neuromorphic SNN Intrusion Detection Weights")
    print("=" * 70)

    torch.manual_seed(42)
    x_train, y_train = generate_synthetic_security_dataset(num_samples=1200, time_steps=24)

    model = HardwareLIFLayer(in_features=8, out_features=8, decay=0.875, threshold=1.0)
    optimizer = torch.optim.Adam(model.parameters(), lr=0.02)
    criterion = nn.CrossEntropyLoss()

    # Training loop
    epochs = 30
    for epoch in range(epochs):
        optimizer.zero_grad()
        out_spikes = model(x_train) # [batch, time, 8]
        # Spike rate classification
        spike_counts = out_spikes.sum(dim=1) # [batch, 8]
        # Output neuron 0 = Normal, Neuron 1 = Attack
        logits = spike_counts[:, 0:2]
        
        loss = criterion(logits, y_train)
        loss.backward()
        optimizer.step()

        if (epoch + 1) % 10 == 0:
            preds = logits.argmax(dim=1)
            acc = (preds == y_train).float().mean() * 100
            print(f"Epoch {epoch+1:02d}/{epochs:02d} | Loss: {loss.item():.4f} | Accuracy: {acc:.2f}%")

    # Quantize weights to signed 8-bit integers [-128, 127]
    with torch.no_grad():
        w_float = model.weight.data.numpy() # [8, 8]
        max_abs = np.max(np.abs(w_float))
        w_quant = np.clip(np.round(w_float / max_abs * 120), -128, 127).astype(np.int8)

    print("\n[SYNAPSE-7] Quantized Synaptic Weight Matrix (8x8 INT8):")
    print(w_quant)

    # Export to Verilog Memory Format
    mem_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "snn_weights.mem")
    with open(mem_path, "w") as f:
        f.write("// SYNAPSE-7 Quantized Synaptic Weights for Spartan-7 BRAM\n")
        f.write("// Format: 8x8 signed 8-bit hex values\n")
        for row in range(8):
            for col in range(8):
                val = int(w_quant[row, col]) & 0xFF
                f.write(f"{val:02X} ")
            f.write("\n")

    print(f"\n[SUCCESS] Exported synaptic memory to: {mem_path}\n")

if __name__ == "__main__":
    train_and_export()
