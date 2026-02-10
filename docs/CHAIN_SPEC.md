# Aurum Chain Specification

This document is the exchange / integrator-facing specification for Aurum.
If documentation conflicts with code, code is authoritative.

## Identity
- Name: Aurum
- Ticker: AUR
- Type: Aurum-derived Proof-of-Work Layer-1
- Launch policy: Fair launch (no premine, no founder allocation, no hidden minting)

## Consensus
- Proof-of-Work
- Target block time: 150 seconds (2.5 minutes)
- Difficulty retarget timespan: 302,400 seconds (3.5 days)
- Halving interval: 840,000 blocks (~4 years)

## Monetary Policy (Consensus-Enforced)
- Initial block subsidy: 56 AUR
- Halves every 840,000 blocks
- Subsidy becomes zero after 64 halvings
- No inflation
- No rebasing
- No admin minting

## Networks
- mainnet
- testnet
- regtest

## Default Ports (Mainnet)
- P2P: 19444
- RPC: 19443

## Genesis Block (Mainnet)
- Height: 0
- Hash: fe4ef79e105f5f722c0a6991b3e113190eaea9d7217e6437b05b10b33d626440
- Merkle root: 3496b8efe1e8b3aaa03f89ce802a239131b76a27a3c6e2335f84bdd558b7e590
- Version: 1
- nTime: 1770336000
- nBits: 207fffff
- nNonce: 1663842
