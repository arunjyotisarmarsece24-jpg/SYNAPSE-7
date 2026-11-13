"""
Quantum Key Distribution (QKD) BB84 Protocol Simulator for SYNAPSE-7
Simulates photon polarization / phase basis preparation, quantum channel transmission,
hostile intercept-resend eavesdropping, basis sifting, QBER calculation, and privacy amplification.
"""

from typing import List, Tuple, Dict, Any, Optional
import numpy as np
import hashlib

class BB84QKDProtocol:
    """End-to-End Quantum Key Distribution Protocol with Eavesdropping Defense."""

    def __init__(self, num_photons: int = 1024, channel_noise: float = 0.01, seed: Optional[int] = None):
        self.num_photons = num_photons
        self.channel_noise = channel_noise
        self.rng = np.random.default_rng(seed)

    def run_exchange(self, eavesdropper_present: bool = False, eve_intercept_ratio: float = 1.0) -> Dict[str, Any]:
        """
        Execute full QKD exchange between Alice and Bob across quantum channel.
        Basis notation: 0 = Z (rectilinear: |0>, |1>), 1 = X (diagonal: |+>, |->)
        """
        # 1. Alice prepares random bits and random bases
        alice_bits = self.rng.integers(0, 2, size=self.num_photons)
        alice_bases = self.rng.integers(0, 2, size=self.num_photons)

        # 2. Photons travel over quantum channel (with optional Eve intercept)
        qubit_states = []
        for bit, basis in zip(alice_bits, alice_bases):
            # Encode polarization / state:
            # (bit, basis) -> 0,Z: |0>; 1,Z: |1>; 0,X: |+>; 1,X: |->
            qubit_states.append((bit, basis))

        # Eavesdropper (Eve) Intercept-Resend Attack
        eve_eavesdropped = 0
        if eavesdropper_present:
            eaved_states = []
            for bit, basis in qubit_states:
                if self.rng.random() < eve_intercept_ratio:
                    eve_eavesdropped += 1
                    eve_basis = self.rng.integers(0, 2)
                    # If Eve guessed basis right, outcome is bit. If wrong, 50% chance bit flips.
                    measured_bit = bit if eve_basis == basis else self.rng.integers(0, 2)
                    # Eve re-transmits in her measurement basis
                    eaved_states.append((measured_bit, eve_basis))
                else:
                    eaved_states.append((bit, basis))
            qubit_states = eaved_states

        # 3. Bob measures photons in independently chosen random bases
        bob_bases = self.rng.integers(0, 2, size=self.num_photons)
        bob_bits = np.zeros(self.num_photons, dtype=int)

        for i in range(self.num_photons):
            incoming_bit, incoming_basis = qubit_states[i]
            # Channel noise
            if self.rng.random() < self.channel_noise:
                incoming_bit = 1 - incoming_bit

            if bob_bases[i] == incoming_basis:
                bob_bits[i] = incoming_bit
            else:
                # Incompatible basis measurement yields 50/50 collapse
                bob_bits[i] = self.rng.integers(0, 2)

        # 4. Sifting Phase: Alice & Bob disclose bases over classical channel
        matching_indices = np.where(alice_bases == bob_bases)[0]
        alice_sifted = alice_bits[matching_indices]
        bob_sifted = bob_bits[matching_indices]

        # 5. QBER Estimation: Compare a test sample of 25% of sifted bits
        sifted_len = len(matching_indices)
        if sifted_len < 32:
            raise RuntimeError("Insufficient sifted key length for statistical significance.")

        sample_size = max(16, sifted_len // 4)
        sample_indices = self.rng.choice(sifted_len, size=sample_size, replace=False)
        
        errors = np.sum(alice_sifted[sample_indices] != bob_sifted[sample_indices])
        qber = float(errors) / float(sample_size)

        # Remaining bits form the raw key candidate
        keep_mask = np.ones(sifted_len, dtype=bool)
        keep_mask[sample_indices] = False
        alice_raw_key = alice_sifted[keep_mask]
        bob_raw_key = bob_sifted[keep_mask]

        # 6. Security Threshold Check: Theoretical Shor-Preskill limit is ~11%
        ABORT_THRESHOLD = 0.11
        is_secure = qber < ABORT_THRESHOLD

        final_key = None
        key_hex = None

        if is_secure:
            # Privacy Amplification via Universal Toeplitz / Cryptographic Hashing
            raw_key_bytes = np.packbits(alice_raw_key).tobytes()
            final_key = hashlib.sha256(raw_key_bytes).digest()
            key_hex = final_key.hex()

        return {
            "num_photons_sent": self.num_photons,
            "sifted_key_length": sifted_len,
            "qber": qber,
            "qber_percent": round(qber * 100.0, 2),
            "is_secure": is_secure,
            "eavesdropper_detected": not is_secure,
            "eve_intercepted_photons": eve_eavesdropped,
            "final_quantum_key_hex": key_hex,
            "status": "KEY_ESTABLISHED" if is_secure else "CONNECTION_ABORTED_EVE_DETECTED"
        }
