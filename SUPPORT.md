# Support

## Getting Help
- Read `docs/README.md` first
- Run the spec checker: `bash scripts/verify_spec.sh`

## Common Commands
```bash
# Build (example)
cmake -S . -B build
cmake --build build -j

# Run node (mainnet example)
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurumd -chain=main -datadir="$DATADIR" -daemon
./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getnetworkinfo
```

## Security
- Do not post private keys, wallet files, seed phrases, or `wallet.dat`
- For vulnerabilities, follow `SECURITY.md`
