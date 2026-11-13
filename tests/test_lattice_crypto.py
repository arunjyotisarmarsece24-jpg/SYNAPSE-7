import pytest
import numpy as np
from synapse7.crypto.ntt_lattice import NTTMultiplier
from synapse7.crypto.ring_lwe import RingLWEEngine

def test_ntt_roundtrip():
    ntt = NTTMultiplier()
    poly = np.random.randint(0, ntt.q, size=ntt.n)
    
    transformed = ntt.forward_ntt(poly)
    recovered = ntt.inverse_ntt(transformed)
    
    assert np.array_equal(poly, recovered)

def test_polynomial_multiplication_negacyclic():
    ntt = NTTMultiplier()
    # (2 + x) * (3 + 4x) = 6 + 11x + 4x^2
    p1 = np.zeros(ntt.n, dtype=int)
    p1[0] = 2
    p1[1] = 1
    
    p2 = np.zeros(ntt.n, dtype=int)
    p2[0] = 3
    p2[1] = 4
    
    prod = ntt.multiply(p1, p2)
    assert prod[0] == 6
    assert prod[1] == 11
    assert prod[2] == 4
    assert np.all(prod[3:] == 0)

def test_ring_lwe_encryption_decryption_100pct():
    engine = RingLWEEngine(seed=42)
    pk, sk = engine.keygen()
    
    # 256-bit arbitrary message
    msg = np.random.randint(0, 2, size=256)
    
    ciphertext = engine.encrypt(pk, msg)
    decrypted = engine.decrypt(sk, ciphertext)
    
    assert np.array_equal(msg, decrypted)
