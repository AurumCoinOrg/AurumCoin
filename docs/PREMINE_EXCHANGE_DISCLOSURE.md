# AurumCoin (AUR) — Premine & Exchange Disclosure

This document is intended for exchanges, explorers, listing services, and auditors.

It describes AurumCoin’s genesis allocation and confirms that no ongoing premine or hidden subsidy
logic exists in mining or validation.

---

## Summary

- **Project:** AurumCoin
- **Ticker:** AUR
- **Maximum Supply:** 21,000,000 AUR
- **Consensus:** Proof-of-Work (Bitcoin-derived)

### Genesis Premine

AurumCoin includes a **fixed premine of 420,000 AUR**, equal to **2% of the maximum supply**.

- The premine exists **only in the genesis block (height 0)**
- The premine is paid as a **dedicated genesis coinbase output** (genesis transaction `vout[1]`)
- There is **no premine logic** in mining, subsidy calculation, or validation rules
- Any change to premine parameters would change the **genesis hash** and result in a different network

---

## Genesis Identifiers

These values are consensus-locked and verified at startup:

- **Genesis block hash:**  
  `53f9cbb6a18320544b3b32b8133bfcb3ba204c7c1545281db9659324b9d45327`

- **Genesis merkle root:**  
  `fe0a200022f86c2903373e02693ec18b96b65058ad7b21a0e2035df3fbb644e6`

---

## Verification (Node / RPC)

### Important note about genesis coinbase

Bitcoin-derived nodes do **not** treat the genesis coinbase as an “ordinary transaction”.
As a result, RPC methods such as `getrawtransaction` may refuse to return it.

Use `getblock <genesis> 2` to view the full genesis transaction and outputs.

### Verify the premine output exists (value = 420,000 AUR)

```bash
A="$HOME/Documents/AurumCoin"
DATA="$A/aurum-regtest"
CLI="$A/build/bin/aurum-cli"

GEN=$("$CLI" -datadir="$DATA" -regtest getblockhash 0)

# Show the genesis transaction JSON (includes vout array)
"$CLI" -datadir="$DATA" -regtest getblock "$GEN" 2 | sed -n '/"tx"[[:space:]]*:/,/^ *],/p'

# Quick check for the premine amount
"$CLI" -datadir="$DATA" -regtest getblock "$GEN" 2 | grep -n '"value":[[:space:]]*420000\.00000000' || true
