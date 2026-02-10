# Aurum Network Guide

This document describes basic networking parameters and how to run a node.

## Ports
- P2P (mainnet): **19444**
- RPC (mainnet): **19443**

## Run a node (mainnet)
```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
mkdir -p "$DATADIR"

./build/bin/aurumd -datadir="$DATADIR" -daemon

./build/bin/aurum-cli -datadir="$DATADIR" getblockchaininfo
./build/bin/aurum-cli -datadir="$DATADIR" getnetworkinfo
```

## Run a node (regtest)
```bash
DATADIR="$HOME/Documents/AurumCoin/regtest-data"
mkdir -p "$DATADIR"

./build/bin/aurumd -regtest -datadir="$DATADIR" -daemon
./build/bin/aurum-cli -regtest -datadir="$DATADIR" getblockchaininfo
```

## Bootstrapping (no DNS seeds yet)
Mainnet DNS seeds are intentionally disabled until seed infrastructure exists.

To connect manually, use one or more `-addnode` entries:

```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -datadir="$DATADIR" -daemon 

# Example (replace with real peer IPs/hosts once available)
./build/bin/aurum-cli -datadir="$DATADIR" addnode "1.2.3.4:19444" onetry
./build/bin/aurum-cli -datadir="$DATADIR" getpeerinfo
```

