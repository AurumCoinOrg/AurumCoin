# AurumCoin (AUR)

AurumCoin is an independent, Bitcoin-derived Proof-of-Work blockchain designed for
simplicity, transparency, and long-term monetary certainty.

Aurum intentionally avoids experimental monetary mechanics, staking systems,
governance minting, or mutable supply logic.  
Its design philosophy mirrors early Bitcoin and Litecoin: conservative consensus,
predictable issuance, and rules locked by code.

---

## Core Principles

- Fair launch — **no premine**
- No founder or developer allocation
- No ICO or token sale
- Fixed maximum supply
- Consensus rules are immutable once released
- Engineering decisions favor auditability over novelty

---

## Network Overview

- **Ticker:** AUR  
- **Consensus:** Proof-of-Work (PoW)  
- **Hashing:** SHA-256 based  
- **Supply Cap:** **94,000,000 AUR**  
- **Network Types:** Mainnet, Testnet, Regtest  

Aurum operates as its **own Layer-1 blockchain**, not a token or smart-contract asset.

---

## Monetary Policy

- Fixed maximum supply of **94,000,000 AUR**
- Deterministic block subsidy schedule enforced by consensus
- No inflation beyond the defined issuance curve
- No staking, rebasing, or admin-controlled minting
- No governance or upgrade keys

All monetary rules are enforced at the consensus layer and cannot be altered without
creating a new, incompatible network.

---

## Genesis & Consensus

The genesis block and all consensus parameters are **locked in code** and verified
at node startup.

Canonical definitions live in:
- `src/kernel/chainparams.cpp`

Any change to genesis or consensus parameters results in a **different network**.

Genesis values are intentionally not duplicated in documentation to avoid drift.

---

## What Aurum Is Not

- Not a premined coin
- Not a DAO
- Not a staking network
- Not a smart-contract platform
- Not an experimental monetary system

Aurum is focused on **sound money mechanics and reliable base-layer transfers**.

---

## Development Status

- **Mainnet:** Live (bootstrap phase)
- **Testnet:** Available for public testing
- **Wallets:** CLI + RPC available
- **Mining:** Proof-of-Work enabled

---

## Build

See:
- `docs/BUILD.md`

---

## Documentation

- `docs/POSITIONING.md` — project direction
- `docs/LAUNCH_NOTES.md` — release requirements
- `docs/BUILD.md` — build instructions

---

## Disclaimer

AurumCoin is experimental software.

No guarantees are made regarding financial value, adoption, or future development.
Use at your own risk.
