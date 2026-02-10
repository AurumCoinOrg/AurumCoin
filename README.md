# AurumCoin (AUR)

AurumCoin is a Bitcoin-derived digital currency focused on **scarcity, simplicity, and transparency**.

The project intentionally avoids experimental monetary mechanics, staking systems, or mutable supply logic.  
Its design philosophy mirrors early Bitcoin: fixed supply, predictable issuance, and consensus-locked rules.

---

## Key Properties

- **Ticker:** AUR
- **Consensus:** Proof-of-Work (Bitcoin-derived)
- **Maximum Supply:** 21,000,000 AUR
- **Network Types:** Mainnet, Testnet, Regtest

---





**Full exchange-facing disclosure:**  

---

## Genesis Block

The genesis block is **consensus-locked** and verified at node startup.

- **Genesis Block Height:** 0
- **Genesis Hash:**  
  `53f9cbb6a18320544b3b32b8133bfcb3ba204c7c1545281db9659324b9d45327`

- **Genesis Merkle Root:**  
  `fe0a200022f86c2903373e02693ec18b96b65058ad7b21a0e2035df3fbb644e6`

Changing any genesis parameter results in a **different network**.

---

## Monetary Policy

- Fixed maximum supply of **21,000,000 AUR**
- Block subsidy follows a deterministic schedule defined by consensus
- No inflation, rebasing, or admin-controlled minting
- No staking or yield mechanics

All monetary rules are enforced by consensus and are not upgradable.

---

## Design Philosophy

AurumCoin prioritizes:

- Predictable monetary policy
- Minimal consensus complexity
- Long-term auditability
- Human-readable rules
- Conservative, Bitcoin-style design decisions

No claims are made regarding price performance, adoption, or investment value.

---

## Disclaimer

AurumCoin is **experimental software**.

This project makes **no guarantees** regarding financial value, market adoption, or future development.  
Use at your own risk.

---

## Build

### Release build (recommended)

Note: Some environments require disabling multiprocess IPC if Cap’n Proto is not installed.

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_IPC=OFF
cmake --build build -j"$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 8)"
