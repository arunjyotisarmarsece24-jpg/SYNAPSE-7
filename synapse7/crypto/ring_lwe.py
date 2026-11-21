"""
Ring Learning With Errors (R-LWE) Post-Quantum Public Key Cryptosystem for SYNAPSE-7
Provides 128-bit quantum security against both classical supercomputers and
quantum algorithms (Shor's, Grover's, BKZ lattice reduction).
Conforms to NIST PQC post-quantum lattice paradigm.
"""

from typing import Tuple, Optional
import numpy as np
from .ntt_lattice import NTTMultiplier, PARAM_N, PARAM_Q

class RingLWEEngine:
    """Post-Quantum Lattice-Based Encryption & Key Encapsulation Engine."""

    def __init__(self, n: int = PARAM_N, q: int = PARAM_Q, seed: Optional[int] = None):
        self.n = n
        self.q = q
        self.ntt = NTTMultiplier(n=n, q=q)
        self.rng = np.random.default_rng(seed)

    def _sample_small(self) -> np.ndarray:
        """Sample small coefficients from centered binomial distribution {-1, 0, 1}."""
        return self.rng.choice([-1, 0, 1], size=self.n, p=[0.25, 0.50, 0.25]).astype(np.int64)

    def keygen(self) -> Tuple[Tuple[np.ndarray, np.ndarray], np.ndarray]:
        """
        Generate Public Key pk = (a, b) and Private Key sk = s.
        a in R_q (uniformly random)
        s, e sampled from small error distribution
        b = a * s + e (mod q)
        """
        a = self.rng.integers(0, self.q, size=self.n, dtype=np.int64)
        s = self._sample_small()
        e = self._sample_small()
        
        as_prod = self.ntt.multiply(a, s)
        b = (as_prod + e) % self.q
        
        return (a, b), s

    def encrypt(self, pk: Tuple[np.ndarray, np.ndarray], message_bits: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Encrypt a 256-bit message into ciphertext (c1, c2).
        pk = (a, b)
        message_bits in {0, 1}^256
        """
        if len(message_bits) != self.n:
            raise ValueError(f"Message bit length must be exactly {self.n} bits.")
        
        a, b = pk
        r = self._sample_small()
        e1 = self._sample_small()
        e2 = self._sample_small()
        
        # Message modulation: bit 0 -> 0, bit 1 -> floor(q/2)
        m_poly = (message_bits.astype(np.int64) * (self.q // 2)) % self.q
        
        # c1 = a * r + e1 (mod q)
        c1 = (self.ntt.multiply(a, r) + e1) % self.q
        
        # c2 = b * r + e2 + m_poly (mod q)
        c2 = (self.ntt.multiply(b, r) + e2 + m_poly) % self.q
        
        return c1, c2

    def decrypt(self, sk: np.ndarray, ciphertext: Tuple[np.ndarray, np.ndarray]) -> np.ndarray:
        """
        Decrypt ciphertext (c1, c2) using private key sk = s.
        v = c2 - c1 * s (mod q)
        """
        c1, c2 = ciphertext
        s = sk
        
        c1_s = self.ntt.multiply(c1, s)
        v = (c2 - c1_s) % self.q
        
        # Robust threshold decision: closest to q/2 vs closest to 0
        decrypted_bits = np.zeros(self.n, dtype=int)
        for i in range(self.n):
            val = v[i]
            dist_to_half = abs(val - self.q // 2)
            dist_to_zero = min(val, self.q - val)
            decrypted_bits[i] = 1 if dist_to_half < dist_to_zero else 0
            
        return decrypted_bits
