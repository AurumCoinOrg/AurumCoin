# AurumCoin Exchange Disclosure

This document is provided for exchanges, explorers, and third-party reviewers.

## Premine Disclosure

AurumCoin includes a fixed premine created in the genesis block.

- **Premine Amount:** 420,000 AUR
- **Genesis Block Height:** 0
- **Premine Address:**  
  au1q2rre2s6e6pksfhfvefe8ju596unz2rlk5vl4cd

The premine was created transparently at launch and is publicly verifiable on-chain.

## Handling & Custody

- Premine funds are held in an **encrypted wallet**
- Private keys are stored **offline**
- Wallet is **locked by default**
- Premine UTXO is **not used** for mining, rewards, or operational spending

## Separation of Funds

Operational and mining rewards are held in **separate outputs** and wallets.  
No operational transactions spend from the premine output.

## Transparency Commitment

Any future movement of premine funds will be:
- Publicly announced in advance
- Documented on GitHub
- Fully traceable on-chain

This repository serves as the canonical public record.
