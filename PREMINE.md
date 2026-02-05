# AurumCoin Premine Transparency Record

## Summary
AurumCoin launched with a fixed premine created in the genesis block.
This document exists to permanently and publicly record the premine,
its address, handling, and current security status.

This repository is the **official public record** of the AurumCoin premine.

---

## Premine Details

- **Premine Amount:** 420,000 AUR
- **Genesis Block Height:** 0
- **Genesis Block Hash:**  
  `0ee5e347b57cd33fc6955be1ce59dbe33636b0db635c560f5b74f540a4cbf232`
- **Premine Percentage:** 2% of max supply (21,000,000 AUR)

- **Premine Address (Bech32):**  
  `au1q2rre2s6e6pksfhfvefe8ju596unz2rlk5vl4cd`

- **ScriptPubKey:**  
  `001450c7954359d06d04dd2cca72797285d726250ff6`

---

## Wallet & Key Handling

- The premine address is controlled by an **encrypted wallet**
- Wallet backups are stored **offline on removable media**
- No private keys are stored online
- Wallet is kept **locked by default**
- Premine UTXO is **not used for mining or operational spending**

---

## Operational Funds Separation

- Mining and operational rewards were consolidated into a **separate wallet output**
- Premine funds remain **fully isolated**
- Operational transactions never spend from the premine output
- Mining rewards were consolidated into a single operational UTXO for clarity and auditability.
---

## Current Status

- Premine UTXO exists on-chain
- Funds are unspent
- Wallet is locked
- Backup checksum verified
- USB storage safely removed after verification

---

## Commitment

The AurumCoin project commits to:
- Never secretly move the premine
- Publicly document any future premine movement **before** it occurs
- Maintain transparent, auditable records on GitHub

---

## Verification

Anyone can independently verify the premine by:
- Inspecting the genesis block contents
- Confirming the premine output and address on-chain
- Observing that the premine UTXO remains unspent

No trust assumptions are required.

This file serves as a permanent public attestation.
