# AurumCoin

AurumCoin is an experimental Bitcoin Core-derived project for learning, testing, and iterating on consensus + wallet tooling.

## Build

    cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
    cmake --build build -j 8

## Run (regtest)

    rm -rf /tmp/aurum-regtest && mkdir -p /tmp/aurum-regtest

    cat > /tmp/aurum-regtest/bitcoin.conf <<'CONF'
    server=1
    daemon=1

    [regtest]
    rpcuser=aurumrpc
    rpcpassword=aurumrpcpass
    rpcbind=127.0.0.1
    rpcallowip=127.0.0.1
    fallbackfee=0.0001
    txindex=1
    CONF

    ./build/bin/bitcoind -regtest -datadir=/tmp/aurum-regtest
    ./build/bin/bitcoin-cli -regtest -datadir=/tmp/aurum-regtest -rpcuser=aurumrpc -rpcpassword=aurumrpcpass getblockchaininfo

## Docs
## Premine Transparency (Mainnet)

AurumCoin mainnet includes a genesis premine. Full details, address, and on-chain proof are documented here:

👉 [PREMINE.md](./PREMINE.md)

- docs/PHILOSOPHY.md
- docs/SECURITY.md
- docs/RELEASES.md
