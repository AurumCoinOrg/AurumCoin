# Mining Aurum

## Proof-of-Work
- Algorithm: **Scrypt**
- Target spacing: **150s**
- Retarget: **302,400s (3.5 days)**

## Solo mining (regtest)
```bash
DATADIR="$HOME/Documents/AurumCoin/regtest-data"
./build/bin/aurumd -regtest -datadir="$DATADIR" -daemon
./build/bin/aurum-cli -regtest -datadir="$DATADIR" createwallet "miner"
ADDR="$(./build/bin/aurum-cli -regtest -datadir="$DATADIR" getnewaddress)"
./build/bin/aurum-cli -regtest -datadir="$DATADIR" generatetoaddress 101 "$ADDR"
./build/bin/aurum-cli -regtest -datadir="$DATADIR" getbalance
```

## Mainnet / testnet mining
Recommended approach:
- Run a full node
- Use a pool/stratum compatible with Scrypt
- Monitor hashrate, shares, and orphan rate

