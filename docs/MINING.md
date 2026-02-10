# Mining Aurum

## Proof-of-Work
- Algorithm: **Scrypt**
- Target block time: **150 seconds**
- Difficulty retarget: **302,400 seconds (3.5 days)**

## Block Rewards
- Initial subsidy: **56 AUR**
- Halving interval: **840,000 blocks**
- Maximum supply: **94,080,000 AUR**

## Solo Mining (Regtest)

This is intended for **development and testing only**.

```bash
DATADIR="$HOME/Documents/AurumCoin/regtest-data"

./build/bin/aurumd -regtest -datadir="$DATADIR" -daemon

./build/bin/aurum-cli -regtest -datadir="$DATADIR" createwallet "miner"

ADDR="$(./build/bin/aurum-cli -regtest -datadir="$DATADIR" getnewaddress)"

./build/bin/aurum-cli -regtest -datadir="$DATADIR" generatetoaddress 101 "$ADDR"

./build/bin/aurum-cli -regtest -datadir="$DATADIR" getbalance
```

## Notes
- Mainnet mining parameters are enforced by consensus
- GPU/ASIC mining requires external Scrypt miners (cgminer-compatible)
