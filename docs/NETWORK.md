# Aurum Network Guide

## Networks
- mainnet
- testnet
- regtest

## Default Ports (Mainnet)
- P2P: **19444**
- RPC: **19443**

## Data Directory
- Default chain dir: `aurum/`
- Example: `-datadir=$HOME/Documents/AurumCoin/main-data-main`

## Start a Node (Mainnet)
```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -chain=main -datadir="$DATADIR" -daemon
./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblockchaininfo
```

## Firewall
- Allow inbound TCP **19444** for a reachable node
- Keep RPC (**19443**) bound to localhost unless you know exactly what you are doing
