import pytest
from synapse7.crypto.qkd_bb84 import BB84QKDProtocol

def test_bb84_clean_channel():
    qkd = BB84QKDProtocol(num_photons=1024, channel_noise=0.005, seed=123)
    res = qkd.run_exchange(eavesdropper_present=False)
    
    assert res["is_secure"] is True
    assert res["qber"] < 0.11
    assert res["final_quantum_key_hex"] is not None
    assert len(res["final_quantum_key_hex"]) == 64  # 256 bits in hex

def test_bb84_eavesdropper_detected():
    qkd = BB84QKDProtocol(num_photons=1024, channel_noise=0.01, seed=456)
    res = qkd.run_exchange(eavesdropper_present=True, eve_intercept_ratio=1.0)
    
    # Intercept-resend attack introduces ~25% error rate, well exceeding 11% threshold
    assert res["is_secure"] is False
    assert res["qber"] > 0.15
    assert res["eavesdropper_detected"] is True
    assert res["final_quantum_key_hex"] is None
