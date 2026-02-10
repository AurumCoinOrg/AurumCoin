# Aurum Wallet Guide

## Wallet Types
- Descriptor wallets (default)
- Legacy wallets (not recommended)

## Create a Wallet
```bash
./build/bin/aurum-cli createwallet "main"
```

## Generate an Address
```bash
./build/bin/aurum-cli getnewaddress
```

## Check Balance
```bash
./build/bin/aurum-cli getbalance
```

## Backup
Always back up your wallet:

```bash
./build/bin/aurum-cli backupwallet ~/aurum-wallet-backup.dat
```

Store backups **offline**.

## Notes
- Wallet files must never be committed to git
- Loss of wallet backups means loss of funds
