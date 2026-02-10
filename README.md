# Aurum (AUR)

Aurum is a Bitcoin-derived Proof-of-Work Layer-1 blockchain focused on **simplicity, auditability, and fair launch**.

## Principles
- **Fair launch** (no premine, no founder allocation, no hidden minting)
- Conservative consensus rules (Bitcoin-style engineering)
- Designed for long-term verification and operational clarity

## Network parameters (mainnet)
- Ticker: **AUR**
- Consensus: **Proof-of-Work**
- Target block time: **150 seconds** (2.5 minutes)
- Halving interval: **840,000 blocks** (~4 years at 2.5-minute blocks)
- Supply schedule: **Bitcoin-style halvings** (implemented in `src/validation.cpp` → `GetBlockSubsidy()`)

> Note: We do **not** hardcode a marketing “max supply” number in docs unless it is computed directly from consensus code.
> The authoritative source of truth is the consensus implementation.

## Genesis (mainnet, consensus-locked)
Changing any genesis parameter creates a different network.

- Height: **0**
- Hash: **fe4ef79e105f5f722c0a6991b3e113190eaea9d7217e6437b05b10b33d626440**
- Merkle root: **3496b8efe1e8b3aaa03f89ce802a239131b76a27a3c6e2335f84bdd558b7e590**
- nTime: **1770336000** (2026-02-06 00:00:00 UTC)
- nBits: **207fffff**
- nNonce: **1663842**
- Version: **1**

## Build
See `docs/BUILD.md`.

## Status
- Mainnet: bootstrapping/private nodes
- Public testnet: pending
