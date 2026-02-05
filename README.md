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


AurumCoin launched with a fixed genesis premine of 420,000 AUR.
Full exchange-facing disclosure:
docs/PREMINE_EXCHANGE_DISCLOSURE.md

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

---

## Build

### Release build (recommended)

Note: Some environments require disabling multiprocess IPC if Cap’n Proto is not installed.

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_IPC=OFF
cmake --build build -j"$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 8)"


---

## Build

### Release build (recommended)

Note: Some environments require disabling multiprocess IPC if Cap’n Proto is not installed.

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_IPC=OFF
cmake --build build -j"$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 8)"
```


---

## Run (Quickstart)

This starts a local regtest node, creates a wallet, mines 1 block, and shows the genesis premine output.

```bash
A="$HOME/Documents/AurumCoin"
DATA="$A/aurum-regtest"
D="$A/build/bin/aurumd"
CLI="$A/build/bin/aurum-cli"

"$CLI" -datadir="$DATA" -regtest stop 2>/dev/null || true
pkill -9 aurumd 2>/dev/null || true

rm -rf "$DATA/regtest"
mkdir -p "$DATA"

"$D" -datadir="$DATA" -regtest -daemon

for i in {1..60}; do
  "$CLI" -datadir="$DATA" -regtest -rpcclienttimeout=1 getblockchaininfo >/dev/null 2>&1 && break
  sleep 1
done

"$CLI" -datadir="$DATA" -regtest createwallet "miner" >/dev/null 2>&1 || true
"$CLI" -datadir="$DATA" -regtest loadwallet "miner"   >/dev/null 2>&1 || true
ADDR=$("$CLI" -datadir="$DATA" -regtest -rpcwallet=miner getnewaddress)
"$CLI" -datadir="$DATA" -regtest -rpcwallet=miner generatetoaddress 1 "$ADDR" >/dev/null

echo "GENESIS_HASH=$("$CLI" -datadir="$DATA" -regtest getblockhash 0)"
```

## Verify premine (on-chain)

The premine is a dedicated genesis output (vout index 1) worth 420,000 AUR.

```bash
A="$HOME/Documents/AurumCoin"
DATA="$A/aurum-regtest"
CLI="$A/build/bin/aurum-cli"

GEN=$("$CLI" -datadir="$DATA" -regtest getblockhash 0)
"$CLI" -datadir="$DATA" -regtest getblock "$GEN" 2 | sed -n "/\"vout\"[[:space:]]*:/,/^ *],/p"

# quick check (should print one line)
"$CLI" -datadir="$DATA" -regtest getblock "$GEN" 2 | grep -n "\"value\": 420000.00000000" || true
```
