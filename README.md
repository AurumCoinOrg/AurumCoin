# AurumCoin (AUR)

AurumCoin is a Bitcoin-derived digital currency focused on scarcity, simplicity, and transparency.

The project intentionally avoids experimental monetary mechanics and complex token behavior.
Its design philosophy mirrors early Bitcoin: fixed supply, predictable issuance, and consensus-locked rules.

---

## Key Properties

- **Ticker:** AUR
- **Consensus:** Proof-of-Work (Bitcoin-derived)
- **Maximum Supply:** 21,000,000 AUR
- **Block Subsidy:** Fixed schedule defined by consensus rules
- **Network Types:** Mainnet, Testnet, Regtest

---

## Premine Disclosure

AurumCoin includes a fixed premine of **420,000 AUR**, representing **2% of the maximum supply**.

- The premine exists **only in the genesis block**
- No premine logic exists in mining, subsidy, or validation code
- The premine output is permanently embedded in the genesis transaction
- Changing the premine would change the genesis hash and create a different chain

This design ensures full transparency and prevents hidden or mutable allocations.

---

## Genesis Block

The genesis block is consensus-locked and verified at startup.

- **Genesis Hash:**  
  `53f9cbb6a18320544b3b32b8133bfcb3ba204c7c1545281db9659324b9d45327`

- **Genesis Merkle Root:**  
  `fe0a200022f86c2903373e02693ec18b96b65058ad7b21a0e2035df3fbb644e6`

Any modification to the genesis block parameters will result in a different network.

---

## Design Philosophy

AurumCoin prioritizes:

- Predictable monetary policy
- Minimal consensus complexity
- Long-term auditability
- Human-readable rules

No claims are made about guaranteed value, price performance, or adoption.

---

## Disclaimer

AurumCoin is experimental software.

This project makes no promises regarding financial value or future development.
Use at your own risk.
