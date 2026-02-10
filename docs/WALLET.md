# Aurum Wallet Guide

This guide explains how to create, backup, and restore an Aurum wallet.

## Create a Wallet (Mainnet)
```bash
./build/bin/aurum-cli createwallet "main"
```

## Get a New Address
```bash
./build/bin/aurum-cli getnewaddress
```

## Check Balance
```bash
./build/bin/aurum-cli getbalance
```

## Backup Wallet
```bash
./build/bin/aurum-cli backupwallet "$HOME/aurum-wallet-backup.dat"
```

## Restore Wallet
```bash
./build/bin/aurumd -daemon -wallet=restored
./build/bin/aurum-cli restorewallet "restored" "$HOME/aurum-wallet-backup.dat"
```

## Notes
- Always encrypt backups
- Never store backups online
- Wallet files are compatible with Bitcoin Core tooling
