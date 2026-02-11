# Aurum Network Guide

## Ports
- P2P: 19444
- RPC: 19443

## Seed Status
- No DNS seeds are currently enabled
- Nodes must be bootstrapped manually

## Bootstrap Example

```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -datadir="$DATADIR" -daemon -addnode=<IP>:19444
```
