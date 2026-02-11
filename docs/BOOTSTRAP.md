# Aurum Bootstrap Guide

This document explains how to connect to the Aurum network while DNS seed infrastructure is not yet deployed.

## Current Status
- No default DNS seeds are compiled into the client
- This is intentional for early-stage network safety

## Required Information
- P2P port: **19444**
- RPC port: **19443**

## Bootstrap Methods

### Method 1: addnode (recommended)
Allows normal peer discovery after connecting to a known node.

```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -datadir="$DATADIR" -daemon -addnode=<IP>:19444
```

### Method 2: connect (strict)
Connects only to the specified peer (no discovery).

```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -datadir="$DATADIR" -daemon -connect=<IP>:19444
```

## Example
```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -datadir="$DATADIR" -daemon -addnode=203.0.113.10:19444
```

## Notes
- Replace <IP> with a trusted Aurum node
- DNS seeds will be added in a future release once infrastructure is live
