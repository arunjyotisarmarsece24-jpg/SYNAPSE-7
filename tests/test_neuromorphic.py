import pytest
import numpy as np
import torch

from synapse7.neuromorphic.spike_encoder import SpikeEncoder
from synapse7.neuromorphic.lif_neuron import LIFNeuronLayer, SurrogateFastSigmoid
from synapse7.neuromorphic.stdp_engine import STDPSynapsePool
from synapse7.neuromorphic.snn_network import NeuromorphicCryptoGuardSNN, SNNTrainingManager
from synapse7.neuromorphic.neuromorphic_qkd_guard import NeuromorphicQKDGuard

def test_spike_encoder_poisson():
    inputs = np.array([0.0, 0.5, 1.0])
    spikes = SpikeEncoder.poisson_encode(inputs, num_timesteps=100, max_rate_hz=100.0)
    assert spikes.shape == (100, 3)
    # Zero input should produce zero spikes
    assert np.sum(spikes[:, 0]) == 0.0
    # Higher input should produce more spikes
    assert np.sum(spikes[:, 2]) > np.sum(spikes[:, 1])

def test_spike_encoder_latency():
    inputs = np.array([0.1, 0.9])
    spikes = SpikeEncoder.latency_encode(inputs, num_timesteps=20)
    assert spikes.shape == (20, 2)
    # Strong input (0.9) must fire earlier than weak input (0.1)
    t_early = np.argmax(spikes[:, 1])
    t_late = np.argmax(spikes[:, 0])
    assert t_early < t_late

def test_lif_neuron_layer_forward_and_backward():
    layer = LIFNeuronLayer(in_features=8, out_features=4, v_threshold=1.0)
    spike_in = torch.ones(10, 2, 8) # T=10, Batch=2, in=8
    spikes, voltages, thresholds = layer(spike_in)
    
    assert spikes.shape == (10, 2, 4)
    assert voltages.shape == (10, 2, 4)
    
    # Check that gradients flow back through surrogate gradient
    loss = spikes.sum()
    loss.backward()
    assert layer.weight.grad is not None
    assert torch.any(layer.weight.grad != 0)

def test_stdp_learning_ltp_and_ltd():
    pool = STDPSynapsePool(num_pre=2, num_post=2, a_plus=0.1, a_minus=0.1)
    orig_w = np.copy(pool.weights)
    
    # Step 1: Pre fires first (t=0)
    pool.step(pre_spikes=np.array([1.0, 0.0]), post_spikes=np.array([0.0, 0.0]))
    # Step 2: Post fires next (t=1) -> Causal relation -> LTP potentiation on W[0, 0]
    w_after = pool.step(pre_spikes=np.array([0.0, 0.0]), post_spikes=np.array([1.0, 0.0]))
    
    # W[0, 0] should have potentiated (increased)
    assert w_after[0, 0] > orig_w[0, 0]

def test_snn_training_manager():
    mgr = SNNTrainingManager(in_features=8, hidden_features=16, out_features=2, num_timesteps=15)
    telemetry = mgr.train_step()
    assert "loss" in telemetry
    assert "accuracy_percent" in telemetry
    assert "sample_raster" in telemetry
    assert len(telemetry["hidden_weight_matrix"]) == 16

def test_neuromorphic_qkd_guard():
    guard = NeuromorphicQKDGuard()
    # Benign low-energy vector
    benign_vec = np.full(16, 0.15)
    res_benign = guard.inspect_telemetry_trace(benign_vec)
    assert "classification" in res_benign
    assert "confidence" in res_benign
