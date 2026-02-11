# Seed Nodes (Bootstrap)

## Status
Aurum currently ships with **no default DNS seeds**.

Until seed infrastructure is deployed, bootstrap using one of:
- `-addnode=<ip>:19444` (recommended)
- `-connect=<ip>:19444` (strict, only that peer)

## Example
```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -datadir="$DATADIR" -daemon -addnode=203.0.113.10:19444
```
