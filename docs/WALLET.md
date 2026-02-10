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

## Restore Wallet (example)
```bash
./build/bin/aurumd -daemon -wallet=restored
./build/bin/aurum-cli restorewallet "restored" "$HOME/aurum-wallet-backup.dat"
```

## Safety
- Keep backups offline
- Don’t commit wallets or datadirs to git
