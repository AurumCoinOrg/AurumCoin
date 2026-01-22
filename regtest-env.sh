#!/usr/bin/env bash
set -euo pipefail

export CLI=./build/bin/aurum-cli
export DATADIR=/tmp/aurum-regtest
export RPC=(-regtest -datadir="$DATADIR" -rpcuser=aurumrpc -rpcpassword=aurumrpcpass)

# wallets
export AURUM=(-rpcwallet=aurum)
export BOB=(-rpcwallet=bob)

# zsh users: allow # comments in pasted commands
# (safe even in bash, it’ll just ignore if not zsh)
if [ -n "${ZSH_VERSION-}" ]; then
  setopt interactivecomments
fi

echo "Loaded: CLI=$CLI DATADIR=$DATADIR"
