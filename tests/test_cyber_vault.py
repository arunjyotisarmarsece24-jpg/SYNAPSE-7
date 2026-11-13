import pytest
from synapse7.crypto.cyber_vault import CyberVault7, QuantumProofTransaction

def test_quantum_proof_transaction():
    vault = CyberVault7()
    vault.recharge_quantum_entropy()
    
    tx = QuantumProofTransaction(
        sender="0xAlice_MoneyHeistLeader",
        recipient="0xProfessor_IIT_BHU",
        amount_syn=1000000.0,
        nonce=1,
        payload_data="Vault key release auth"
    )
    
    signed_tx = vault.sign_transaction(tx)
    assert signed_tx.pqc_signature is not None
    assert signed_tx.tx_id is not None
    
    success = vault.verify_and_commit(signed_tx)
    assert success is True
    assert len(vault.ledger) == 1

def test_quantum_attack_comparison():
    vault = CyberVault7()
    res = vault.simulate_quantum_attack_comparison(50000000.0)
    
    assert "BREACHED" in res["classical_ecdsa"]["result"]
    assert "IMMUNE" in res["synapse7_quantum_defense"]["result"]
    assert res["synapse7_quantum_defense"]["status"] == "VAULT_SECURED"
