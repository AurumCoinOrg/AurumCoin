# Aurum Wallet Guide

This guide explains how to create, use, back up, and restore an Aurum wallet.

## Wallet Types
- Descriptor wallets (default, recommended)
- Legacy wallets (not recommended)

## Create a Wallet (mainnet)
```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"

./build/bin/aurum-cli -datadir="$DATADIR" createwallet "main"
./build/bin/aurum-cli -datadir="$DATADIR" getwalletinfo
```

## Get a Receiving Address
```bash
./build/bin/aurum-cli -datadir="$DATADIR" getnewaddress
```

## Check Balance
```bash
./build/bin/aurum-cli -datadir="$DATADIR" getbalance
```

## Backup Wallet
```bash
./build/bin/aurum-cli -datadir="$DATADIR" backupwallet "$DATADIR/wallet-backup.dat"
```

## Restore Wallet (from backup)
```bash
# Stop the node first
./build/bin/aurum-cli -datadir="$DATADIR" stop

# Replace wallet.dat with your backup, then restart the node
./build/bin/aurumd -datadir="$DATADIR" -daemon
```

## Regtest Wallet (development only)
```bash
DATADIR="$HOME/Documents/AurumCoin/regtest-data"

./build/bin/aurum-cli -regtest -datadir="$DATADIR" createwallet "test"
./build/bin/aurum-cli -regtest -datadir="$DATADIR" getbalance
```
