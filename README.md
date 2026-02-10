# Aurum (AUR)

Aurum is a Bitcoin-derived Proof-of-Work Layer-1 focused on **simplicity, auditability, and a fair launch**.

## Principles
- Fair launch (no premine, no pre-allocation)
- No founder or developer rewards
- No staking / no admin minting
- Consensus rules are locked at genesis

## Network parameters (from consensus code)
- Ticker: **AUR**
- Consensus: **Proof-of-Work**
- Target block time: **113:        consensus.nPowTargetSpacing = 150;     // 2.5 minutes seconds** (~2.5 minutes)
- Halving interval: **99:        consensus.nSubsidyHalvingInterval = 840000; // ~4 years @ 2.5m blocks blocks**
- Starting subsidy: **1849:    CAmount nSubsidy = 56 * COIN;   // Aurum: 56 AUR starting subsidy AUR**
- Estimated max supply (from code): ** AUR**
  (Calculated as starting_subsidy * halving_interval * 2)

## Genesis (mainnet, consensus-locked)
- Height: **0**
- Hash: **fe4ef79e105f5f722c0a6991b3e113190eaea9d7217e6437b05b10b33d626440**
- Merkle root: **3496b8efe1e8b3aaa03f89ce802a239131b76a27a3c6e2335f84bdd558b7e590**
- nTime: **"time": 1770336000**
- nBits: **207fffff**
- nNonce: **"nonce": 1663842**
- Version: **"version": 1**

## Build
See `docs/BUILD.md`.

## Status
- Mainnet: bootstrapping/private nodes
- Public testnet: pending
