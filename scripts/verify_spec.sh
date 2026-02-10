#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DATADIR="${DATADIR:-$HOME/Documents/AurumCoin/main-data-main}"

echo "== GENESIS (node truth, if node is running) =="
if ./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblockhash 0 >/tmp/aurum_genhash 2>/dev/null; then
  GENHASH="$(cat /tmp/aurum_genhash)"
  echo "GENESIS_HASH=$GENHASH"
  ./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblock "$GENHASH" 2 | rg -n '"hash"|"version"|"merkleroot"|"time"|"nonce"|"bits"' || true
else
  echo "NOTE: aurumd not running (or DATADIR wrong). Skipping node-truth block query."
fi
echo

echo "== CONSENSUS (code truth) =="
rg -n "nPowTargetSpacing|nPowTargetTimespan|nSubsidyHalvingInterval|powLimit" src/kernel/chainparams.cpp | sed -n '1,120p' || true
echo
rg -n "CAmount GetBlockSubsidy|halvings|COIN" src/validation.cpp | sed -n '1835,1860p' || true
echo

echo "== PORTS (code truth) =="
echo "-- P2P:"
rg -n "nDefaultPort\s*=\s*[0-9]+" src/kernel/chainparams.cpp || true
echo "-- RPC:"
rg -n "CBaseChainParams\(\"aurum\",\s*[0-9]+\)" src/chainparamsbase.cpp || true
echo

echo "== MAX_MONEY (code truth) =="
rg -n "MAX_MONEY\s*=" src/consensus/amount.h || true
echo

echo "== DOCS (must match) =="
for f in README.md docs/CHAIN_SPEC.md; do
  echo "-- $f"
  rg -n "Target block time|Difficulty retarget|Halving interval|Initial block subsidy|Hash:|Merkle root:|P2P:|RPC:" "$f" || true
  echo
done
