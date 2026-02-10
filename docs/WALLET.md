# Aurum Wallet Guide

## Create a Wallet
```bash
./build/bin/aurum-cli createwallet "main"
```

## Get an Address
```bash
./build/bin/aurum-cli getnewaddress
```

## Check Balance
```bash
./build/bin/aurum-cli getbalance
```

## Backup
```bash
./build/bin/aurum-cli backupwallet ~/aurum-wallet-backup.dat
```

## Safety
- Never commit wallets/logs/data dirs
- Store backups offline
