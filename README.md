# Aurum (AUR)

Aurum is a Aurum-derived Proof-of-Work Layer-1 focused on simplicity, auditability, and a fair launch.

- No premine
- No founder allocation
- No hidden minting
- No staking

## Chain Summary (Mainnet)
- Ticker: **AUR**
- Proof-of-Work
- Target block time: **150 seconds (2.5 minutes)**
- Difficulty retarget timespan: **302,400 seconds (3.5 days)**
- Halving interval: **840,000 blocks** (~4 years at 2.5-minute blocks)

## Monetary Policy (Consensus-Enforced)
Defined in `src/validation.cpp → GetBlockSubsidy()`:
- Initial block subsidy: **56 AUR**
- Halves every **840,000** blocks
- Subsidy becomes **0 after 64 halvings**
- No inflation, no rebasing, no admin minting

## Genesis (Mainnet — Consensus Locked)
Changing any genesis parameter creates a different network.

- Height: **0**
- Hash: **fe4ef79e105f5f722c0a6991b3e113190eaea9d7217e6437b05b10b33d626440**
- Merkle root: **3496b8efe1e8b3aaa03f89ce802a239131b76a27a3c6e2335f84bdd558b7e590**
- Version: **1**
- nTime: **1770336000** (2026-02-06 00:00:00 UTC)
- nBits: **207fffff**
- nNonce: **1663842**

## Ports (Default Mainnet)
- P2P: **19444**
- RPC: **19443**

## Docs
- `docs/CHAIN_SPEC.md` (exchange / integrator spec)
- `docs/BUILD.md` (build instructions)
- `docs/OVERVIEW.md` (project overview)
- `docs/RELEASE_CHECKLIST.md` (release checklist)

## Quick Verify (from a running node)
```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblockhash 0
./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblock "$(./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblockhash 0)" 2
```

## Disclaimer
Aurum is experimental software. No guarantees are made regarding value, adoption, or future development. Use at your own risk.

## License
See `COPYING`.

## Development status

Automated CI checks are temporarily disabled while the project is in early development.
All checks will be re-enabled prior to public release.
