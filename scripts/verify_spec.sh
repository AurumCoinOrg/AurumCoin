#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DATADIR="${DATADIR:-$HOME/Documents/AurumCoin/main-data-main}"

# ===== Expected canonical values (mainnet) =====
EXPECTED_GENESIS_HASH="fe4ef79e105f5f722c0a6991b3e113190eaea9d7217e6437b05b10b33d626440"
EXPECTED_MERKLE="3496b8efe1e8b3aaa03f89ce802a239131b76a27a3c6e2335f84bdd558b7e590"
EXPECTED_SPACING="150"
EXPECTED_TIMESPAN="302400"
EXPECTED_HALVING="840000"
EXPECTED_SUBSIDY="56"
EXPECTED_P2P="19444"
EXPECTED_RPC="19443"
EXPECTED_MAX_MONEY="94080000"

fail() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "NOTE: $*" >&2; }

echo "== GENESIS (node truth, if node is running) =="
if ./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblockhash 0 >/tmp/aurum_genhash 2>/dev/null; then
  GENHASH="$(cat /tmp/aurum_genhash)"
  echo "GENESIS_HASH=$GENHASH"
  [[ "$GENHASH" == "$EXPECTED_GENESIS_HASH" ]] || fail "Genesis hash mismatch: got $GENHASH expected $EXPECTED_GENESIS_HASH"

  # Verify merkle from node
  MERKLE="$(./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblock "$GENHASH" 2 | rg -n '"merkleroot"' | head -n 1 | sed -E 's/.*"merkleroot": "([^"]+)".*/\1/')"
  [[ "$MERKLE" == "$EXPECTED_MERKLE" ]] || fail "Genesis merkleroot mismatch: got $MERKLE expected $EXPECTED_MERKLE"

  ./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblock "$GENHASH" 2 | rg -n '"hash"|"version"|"merkleroot"|"time"|"nonce"|"bits"' || true
else
  note "aurumd not running (or DATADIR wrong). Skipping node-truth block query."
fi
echo

echo "== CONSENSUS (code truth) =="
# Mainnet values must be present in chainparams
rg -n "nPowTargetSpacing|nPowTargetTimespan|nSubsidyHalvingInterval|powLimit" src/kernel/chainparams.cpp | sed -n '1,140p' || true
echo
rg -n "CAmount GetBlockSubsidy|halvings|COIN" src/validation.cpp | sed -n '1835,1860p' || true
echo

# Hard assertions for mainnet params
rg -q "consensus\.nPowTargetSpacing\s*=\s*${EXPECTED_SPACING}\b" src/kernel/chainparams.cpp || fail "Missing/changed mainnet nPowTargetSpacing=${EXPECTED_SPACING}"
rg -q "consensus\.nPowTargetTimespan\s*=\s*${EXPECTED_TIMESPAN}\b" src/kernel/chainparams.cpp || fail "Missing/changed mainnet nPowTargetTimespan=${EXPECTED_TIMESPAN}"
rg -q "consensus\.nSubsidyHalvingInterval\s*=\s*${EXPECTED_HALVING}\b" src/kernel/chainparams.cpp || fail "Missing/changed mainnet nSubsidyHalvingInterval=${EXPECTED_HALVING}"
rg -q "CAmount\s+nSubsidy\s*=\s*${EXPECTED_SUBSIDY}\s*\*\s*COIN" src/validation.cpp || fail "Missing/changed starting subsidy ${EXPECTED_SUBSIDY} * COIN"

echo "== PORTS (code truth) =="
echo "-- P2P:"
rg -n "nDefaultPort\s*=\s*[0-9]+" src/kernel/chainparams.cpp || true
rg -q "nDefaultPort\s*=\s*${EXPECTED_P2P}\s*;" src/kernel/chainparams.cpp || fail "Missing/changed mainnet P2P port ${EXPECTED_P2P}"

echo "-- RPC:"
# Match either direct CBaseChainParams(...) or make_unique<CBaseChainParams>(...)
rg -n "CBaseChainParams\(\"aurum\",\s*[0-9]+\)" src/chainparamsbase.cpp || true
rg -n "make_unique<\s*CBaseChainParams\s*>\(\s*\"aurum\",\s*[0-9]+\s*\)" src/chainparamsbase.cpp || true
rg -q "(CBaseChainParams\(\"aurum\",\s*${EXPECTED_RPC}\)|make_unique<\s*CBaseChainParams\s*>\(\s*\"aurum\",\s*${EXPECTED_RPC}\s*\))" src/chainparamsbase.cpp || fail "Missing/changed RPC port ${EXPECTED_RPC} in src/chainparamsbase.cpp"
echo

echo "== MAX_MONEY (code truth) =="
rg -n "MAX_MONEY\s*=" src/consensus/amount.h || true
rg -q "MAX_MONEY\s*=\s*${EXPECTED_MAX_MONEY}\s*\*\s*COIN" src/consensus/amount.h || fail "Missing/changed MAX_MONEY=${EXPECTED_MAX_MONEY} * COIN"
echo

echo "== DOCS (must match) =="
for f in README.md docs/CHAIN_SPEC.md; do
  echo "-- $f"
  rg -n "Target block time|Difficulty retarget|Halving interval|Initial block subsidy|Hash:|Merkle root:|P2P:|RPC:" "$f" || true
  echo
done

# Docs must contain the canonical values
rg -q "${EXPECTED_GENESIS_HASH}" README.md docs/CHAIN_SPEC.md || fail "Docs missing genesis hash"
rg -q "${EXPECTED_MERKLE}" README.md docs/CHAIN_SPEC.md || fail "Docs missing merkle root"
rg -q "\b${EXPECTED_P2P}\b" README.md docs/CHAIN_SPEC.md || fail "Docs missing P2P port ${EXPECTED_P2P}"
rg -q "\b${EXPECTED_RPC}\b" README.md docs/CHAIN_SPEC.md || fail "Docs missing RPC port ${EXPECTED_RPC}"
# Docs can format numbers with commas (e.g., 302,400)
DOC_TIMESPAN="${EXPECTED_TIMESPAN}"
DOC_TIMESPAN_COMMA="$(printf "%s" "$DOC_TIMESPAN" | sed -E 's/([0-9])([0-9]{3})$/\1,\2/')"
rg -q "(${DOC_TIMESPAN}|${DOC_TIMESPAN_COMMA})" README.md docs/CHAIN_SPEC.md || fail "Docs missing timespan ${EXPECTED_TIMESPAN} (or comma-formatted)"
rg -q "\b${EXPECTED_SPACING}\b" README.md docs/CHAIN_SPEC.md || fail "Docs missing spacing ${EXPECTED_SPACING}"
# Docs can format numbers with commas (e.g., 840,000)
DOC_HALVING="${EXPECTED_HALVING}"
DOC_HALVING_COMMA="$(printf "%s" "$DOC_HALVING" | sed -E 's/([0-9])([0-9]{3})$/\1,\2/')"
rg -q "(${DOC_HALVING}|${DOC_HALVING_COMMA})" README.md docs/CHAIN_SPEC.md || fail "Docs missing halving ${EXPECTED_HALVING} (or comma-formatted)"
rg -q "\b${EXPECTED_SUBSIDY}\b" README.md docs/CHAIN_SPEC.md || fail "Docs missing subsidy ${EXPECTED_SUBSIDY}"

echo "OK: spec matches code (and node, if running)"
