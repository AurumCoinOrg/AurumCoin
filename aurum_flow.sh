#!/usr/bin/env bash
# ---- GLOBAL FLAGS ----
CI_MODE="${CI_MODE:-0}"
JSON_MODE="${JSON_MODE:-0}"
QUIET="${QUIET:-0}"
VERBOSE="${VERBOSE:-0}"

# Parse global flags in any order before the command
while [[ "${1:-}" == --* ]]; do
  case "${1:-}" in
    --ci) CI_MODE=1; shift ;;
    --json) JSON_MODE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --) shift; break ;;
    *) break ;;  # unknown flag: stop parsing; will be handled by usage
  esac
done

# If verbose is set, force quiet off
if [[ "${VERBOSE:-0}" -eq 1 ]]; then
QUIET="${QUIET:-0}"
fi

export CI_MODE JSON_MODE QUIET VERBOSE

set -eu

# ---- QUIET MODE ----
QUIET="${QUIET:-0}"
# CI default quiet
# If CI_MODE=1, default to quiet logs unless user explicitly asks otherwise
if [[ ${CI_MODE:-0} -eq 1 && ${QUIET:-0} -eq 0 && ${VERBOSE:-0} -eq 0 ]]; then
  QUIET=1
fi

# If user explicitly asked for verbose, force quiet off
if [[ ${VERBOSE:-0} -eq 1 ]]; then
QUIET="${QUIET:-0}"
fi
# ---- VERBOSE MODE ----
VERBOSE="${VERBOSE:-0}"
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
  shift
fi
export VERBOSE

# AURUM_QUIET export
if [[ "${VERBOSE:-0}" -eq 1 ]]; then
  export AURUM_QUIET=0
elif [[ "${QUIET:-0}" -eq 1 ]]; then
  export AURUM_QUIET=1
else
  export AURUM_QUIET=0
fi
AURUM_QUIET="${QUIET:-0}"
export QUIET AURUM_QUIET

# -------------------------
# Config (edit if your paths differ)
# -------------------------
DATA_DIR="${DATA_DIR:-/Users/ericciciotti/Documents/AurumCoin/aurum-regtest-data}"
CLI="${CLI:-/Users/ericciciotti/Documents/AurumCoin/build/bin/bitcoin-cli}"
BITCOIND="${BITCOIND:-/Users/ericciciotti/Documents/AurumCoin/build/bin/bitcoind}"
RPCWAIT=180
RPCWAIT="${RPCWAIT:-60}"

W1="${W1:-aurum}"
W2="${W2:-aurum2}"
MINER_WALLET="${MINER_WALLET:-$W1}"

LAST_TX_FILE="${LAST_TX_FILE:-$DATA_DIR/last_txid.txt}"
LAST_TX_HEX_FILE="${LAST_TX_HEX_FILE:-$DATA_DIR/last_tx_hex.txt}"

DEFAULT_MINE_BLOCKS="${DEFAULT_MINE_BLOCKS:-1}"
DEFAULT_TXFEE="${DEFAULT_TXFEE:-0.00001}"

# -------------------------
# Helpers
# -------------------------
say(){ echo "$@"; }
die(){ echo "error: $*" >&2; exit 1; }

bcli() {
  # base cli (no wallet)
  "$CLI" -regtest -datadir="$DATA_DIR" -rpcwait -rpcwaittimeout="${RPCWAIT:-60}" "$@"
}
wcli() {
  local wallet="$1"; shift || true
  "$CLI" -regtest -datadir="$DATA_DIR" -rpcwait -rpcwaittimeout="${RPCWAIT:-60}" -rpcwallet="$wallet" "$@"
}
print_json() {
  # VERBOSE always wins (even in CI), so callers can force pretty JSON.
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    python3 -m json.tool
  elif [[ "${AURUM_QUIET:-0}" == "1" ]]; then
    cat
  else
    python3 -m json.tool
  fi
}

read_last_txid() {
  [[ -f "$LAST_TX_FILE" ]] || { echo ""; return 0; }
  tr -d ' \t\r\n' < "$LAST_TX_FILE" 2>/dev/null || true
}
write_last_txid() {
  local txid="${1:-}"
  [[ -n "$txid" ]] || return 0
  mkdir -p "$(dirname "$LAST_TX_FILE")" 2>/dev/null || true
  echo "$txid" > "$LAST_TX_FILE"

  # Best-effort: also store raw hex for later rebroadcast (works even without txindex)
  local hex=""
  hex="$(wcli "$W1" gettransaction "$txid" 2>/dev/null | python3 -c $'import sys, json\ntry:\n  j=json.load(sys.stdin)\n  print(j.get("hex","") or "")\nexcept Exception:\n  print("")\n' 2>/dev/null || true
)"
  if [[ -z "${hex:-}" ]]; then
    hex="$(wcli "$W2" gettransaction "$txid" 2>/dev/null | python3 -c $'import sys, json\ntry:\n  j=json.load(sys.stdin)\n  print(j.get("hex","") or "")\nexcept Exception:\n  print("")\n' 2>/dev/null || true
)"
  fi
  if [[ -n "${hex:-}" ]]; then
    echo "$hex" > "$LAST_TX_HEX_FILE"
  fi
}

save_last_tx_hex() {
  local txid="${1:-}"
  [[ -n "${txid:-}" ]] || return 0

  mkdir -p "$(dirname "$LAST_TX_HEX_FILE")" 2>/dev/null || true

  local hex=""
  local i=0

  while [[ $i -lt 20 ]]; do
    hex="$(wcli "$W1" gettransaction "$txid" true true 2>/dev/null | python3 -c 'import sys,json
try:
  j=json.load(sys.stdin)
  print(j.get("hex","") or "", end="")
except Exception:
  print("", end="")' 2>/dev/null || true)"

    if [[ -z "${hex:-}" ]]; then
      hex="$(wcli "$W2" gettransaction "$txid" true true 2>/dev/null | python3 -c 'import sys,json
try:
  j=json.load(sys.stdin)
  print(j.get("hex","") or "", end="")
except Exception:
  print("", end="")' 2>/dev/null || true)"
    fi

    [[ -n "${hex:-}" ]] && break
    i=$((i+1))
    sleep 0.1
  done

  if [[ -n "${hex:-}" ]]; then
    echo "$hex" > "$LAST_TX_HEX_FILE"
  else
    say "warn: couldn't save tx hex after retries txid=$txid"
  fi
}
mine_blocks() {
  local miner_wallet="${1:-$MINER_WALLET}"
  local blocks="${2:-$DEFAULT_MINE_BLOCKS}"

  [[ "$blocks" =~ ^[0-9]+$ ]] || die "mine: BLOCKS must be a number"
  [[ "$blocks" -ge 0 ]] || die "mine: BLOCKS must be >= 0"
  [[ "$blocks" -eq 0 ]] && return 0

  local addr
  addr="$(wcli "$miner_wallet" getnewaddress 2>/dev/null || true)"
  [[ -n "$addr" ]] || die "mine: couldn't get mining address from wallet=$miner_wallet"

  # Bitcoin Core regtest supports generatetoaddress
  bcli generatetoaddress "$blocks" "$addr" >/dev/null
}

pick_best_txid() {
  # Choose newest send/receive txid (don't trust list order).
  # Priority:
  #   1) newest mempool-present send/receive
  #   2) newest confirmed send/receive
  local mp out

  mp="$(bcli getrawmempool 2>/dev/null || echo '[]')"
  out="$(MEMPOOL="$mp" wcli "$W1" listtransactions "*" 500 0 true 2>/dev/null || echo '[]')"

  OUT="$out" MEMPOOL="$mp" python3 - <<'PY2'
import os, json

try:
  txs = json.loads(os.environ.get("OUT","[]") or "[]")
except Exception:
  txs = []

try:
  mempool = set(json.loads(os.environ.get("MEMPOOL","[]") or "[]"))
except Exception:
  mempool = set()

def ok_cat(t): return t.get("category") in ("send","receive")
def bad(t):
  return (t.get("abandoned") is True
          or t.get("generated") is True
          or t.get("category") in ("orphan","immature"))

def ttime(t):
  # prefer timereceived, then time, else 0
  return int(t.get("timereceived") or t.get("time") or 0)

mempool_cands = []
conf_cands = []

for t in txs:
  if not ok_cat(t) or bad(t):
    continue
  txid = t.get("txid","")
  if not txid:
    continue
  if txid in mempool:
    mempool_cands.append((ttime(t), txid))
  elif int(t.get("confirmations",0) or 0) > 0:
    conf_cands.append((ttime(t), txid))

if mempool_cands:
  mempool_cands.sort()
  print(mempool_cands[-1][1], end="")
elif conf_cands:
  conf_cands.sort()
  print(conf_cands[-1][1], end="")
else:
  print("", end="")
PY2
}

tx_in_mempool() {
  local txid="${1:-}"
  [[ -n "${txid:-}" ]] || return 1
  local mp
  mp="$(bcli getrawmempool 2>/dev/null || echo '[]')"
  python3 -c 'import json,sys; mp=json.loads(sys.argv[1]); tx=sys.argv[2]; sys.exit(0 if tx in mp else 1)' "$mp" "$txid" >/dev/null 2>&1
}

quiet_filter() {
  if [[ "${quiet:-0}" -eq 1 ]]; then
    sed -E '
      /^[[:space:]]*[0-9]+[[:space:]]*$/d;
      /^txid:/d;
      /^TXID=/d;
      /blockhash/d;
      /^starting height=/d;
      /^starting tip=/d;
      /^fork point/d;
      /^invalidating last/d;
      /^after invalidate/d;
      /^after mine/d;
      /^current height=/d;
      /^skipping reconsider/d;
      /^last tx already confirmed/d;
      /^last tx is in mempool/d;
/^---- .* ----$/d;
      /^[0-9]+\)/d;
      /^sending [0-9]+ from/d;
      /^wallets loaded/d;
    '
  else
    cat
  fi
}

# -------------------------
# Commands
# -------------------------
cmd_help() {
  cat <<'EOH'
Usage: ./aurum_flow.sh {help|start|stop|last|best|new|mature|tail|status|mine|pay|pay-many|confirm|confirm-all|mempool|reorg-test|reorg-sim|self-test|explore|tx|block|addr|rebroadcast|quiet-filter|reorg-ci|check|smoke}
help
start                    (start bitcoind + load wallets)
stop                     (stop bitcoind)
last                     (prints last txid; falls back to best)
best                     (prints best txid; writes last_txid.txt)
new [AMOUNT] [--mature] [BLOCKS] (send AMOUNT W1->W2, mine (default 1; --mature=101), confirm)
mature [BLOCKS]            (mine BLOCKS, default 101, to mature coinbase)
tail [N]                 (prints last N wallet txs, one-line)
status
check                    (sanity checks: chain/mempool/wallet UTXOs)
mine [MINER_WALLET] [BLOCKS]
pay AMOUNT [--no-mine]
pay-many [--no-mine] AMT1 [AMT2 ...]
confirm TXID|last|best
confirm-all [BLOCKS]
mempool
explore                 (quick dashboard: height/mempool/balances/last tx)
tx TXID                  (inspect tx: wallet view + decoded + block)
block HASH|HEIGHT        (inspect block header + tx list)
addr ADDRESS             (address info + UTXOs via scantxoutset)
rebroadcast TXID|last|best  (sendrawtransaction from wallet hex; useful after reorg)
reorg-test [DEPTH] [MINE_AFTER] [AUTO_CONFIRM=1|0] [RECONSIDER=1|0]
self-test
EOH
}



cmd_quiet_filter() {
  # Filter stdin using quiet_filter() helper
  quiet_filter
}


cmd_reorg_ci() {
  # CI-friendly wrapper:
  # reorg-ci [DEPTH] [MINE_AFTER] [AUTO_CONFIRM=1|0] [RECONSIDER=1|0] [AMOUNT]
  set -o pipefail
  ./aurum_flow.sh reorg-e2e "$@" | ./aurum_flow.sh quiet-filter
}
cmd_smoke() {
  # One command for CI/dev:
  # smoke [DEPTH] [MINE_AFTER] [AUTO_CONFIRM=1|0] [RECONSIDER=1|0] [AMOUNT]
  #
  # Runs:
  #   1) check (auto-start RPC if needed)
  #   2) reorg-ci (reorg-e2e piped through quiet-filter)
  # Produces one final PASS line.
  # Pre-check (print output only on failure; avoid set -e silent exit)
  local _chk_out _chk_ec
  # CI quiet default (smoke)
  local quiet=0
  if [[ ${CI_MODE:-0} -eq 1 && ${VERBOSE:-0} -eq 0 ]]; then
    quiet=1
  fi

  if declare -F cmd_check >/dev/null 2>&1; then
    _chk_out="$(cmd_check 2>&1)"; _chk_ec=$?
  else
    _chk_out="$("./aurum_flow.sh" check 2>&1)"; _chk_ec=$?
  fi
  if [[ $_chk_ec -ne 0 ]]; then
    say "SMOKE: pre-check failed (exit=$_chk_ec). Output:"
    printf "%s\n" "$_chk_out"
    return $_chk_ec
  fi
  ./aurum_flow.sh reorg-ci "$@"
  echo "PASS: smoke $*"
  # Summary (helpful one-liner)
  local h mp last conf
  h="$(bcli getblockcount 2>/dev/null || echo "?")"
  mp="$(bcli getmempoolinfo 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("size","?"))' 2>/dev/null || echo "?")"
  last="$(read_last_txid 2>/dev/null || true)"
  conf="?"
  if [[ -n "${last:-}" ]]; then
    conf="$(wcli "$W1" gettransaction "$last" 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("confirmations","?"))' 2>/dev/null || echo "?")"
  fi
  # One-line CI-friendly summary
  local h mp last w1c w2c bh
  h="$(bcli getblockcount 2>/dev/null || echo "?")"
  mp="$(bcli getmempoolinfo 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("size","?"))' 2>/dev/null || echo "?")"
  last="$(read_last_txid 2>/dev/null || true)"
  w1c="?"
  w2c="?"
  bh="?"
  if [[ -n "${last:-}" ]]; then
    w1c="$(wcli "$W1" gettransaction "$last" 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("confirmations","?"))' 2>/dev/null || echo "?")"
    w2c="$(wcli "$W2" gettransaction "$last" 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("confirmations","?"))' 2>/dev/null || echo "?")"
    bh="$(wcli "$W1" gettransaction "$last" 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("blockheight","?"))' 2>/dev/null || echo "?")"
  fi
  say "SMOKE_SUMMARY: height=$h mempool=$mp last_tx=${last:-none} W1conf=${w1c:-?} W2conf=${w2c:-?} blockheight=${bh:-?}"
}

cmd_check() {
  say "---- check ----"

  # 1) Ensure RPC is up. If not, try a hard start once.
  if ! bcli getblockcount >/dev/null 2>&1; then
    say "check: RPC not responding -> attempting: start --hard"
    ./aurum_flow.sh start --hard >/dev/null 2>&1 || true
    if ! bcli getblockcount >/dev/null 2>&1; then
      die "check: FAIL: RPC not responding (bitcoind down?)"
    fi
  fi

  # 2) Basic chain/mempool sanity
  local h mp
  # QUIET gate (check)
  local _q
  _q="$(printenv AURUM_QUIET 2>/dev/null || echo 0)"

  h="$(bcli getblockcount 2>/dev/null || echo "?")"
  if [[ ${_q:-0} == "1" ]]; then
    if [[ "${CI_MODE:-0}" -eq 1 && "${VERBOSE:-0}" -ne 1 ]]; then
      AURUM_QUIET=1 cmd_mempool
    else
      cmd_mempool
    fi
  else
    mp="$(bcli getmempoolinfo 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("size","?"))' 2>/dev/null || echo "?")"
  fi
  say "OK: RPC up (height=$h mempool=$mp)"

  # 3) Wallet sanity (balances)
  cmd_status >/dev/null 2>&1 || true
  say "OK: status ran"

  say "PASS: check"
}

cmd_start() {
  local mode="${1:-}"
  local hard=0
  local skip_wallets=0
  # Optional flags (order-insensitive):
  #   --no-mempool-persist
  #   --hard   (kill any running bitcoind and wait until RPC is down before starting)
  while [[ "${1:-}" == --* ]]; do
    case "${1:-}" in
      --skip-wallets) skip_wallets=1 ;;
      --no-mempool-persist) mode="--no-mempool-persist" ;;
      --hard) hard=1 ;;
      *) break ;;
    esac
    shift || true
  done
  say "---- start ----"


  # helper (local so it always exists)
  ensure_wallet () {
    local w="$1"
    if "$CLI" -regtest -datadir="$DATA_DIR" listwallets 2>/dev/null | grep -q "\"$w\""; then
      return 0
    fi
    if "$CLI" -regtest -datadir="$DATA_DIR" listwalletdir 2>/dev/null | grep -q "\"$w\""; then
      "$CLI" -regtest -datadir="$DATA_DIR" loadwallet "$w" >/dev/null 2>&1 || true
    else
      "$CLI" -regtest -datadir="$DATA_DIR" createwallet "$w" true true "" true >/dev/null 2>&1 || true
    fi
  }
  mkdir -p "$DATA_DIR/regtest"
  : > "$DATA_DIR/regtest/bitcoind_start.log"
  if [[ $hard -eq 1 ]]; then
    say "hard start: stopping any running bitcoind first..."
    "$CLI" -regtest -datadir="$DATA_DIR" stop >/dev/null 2>&1 || true
    pkill -f "$BITCOIND.*-regtest.*-datadir=$DATA_DIR" >/dev/null 2>&1 || true

    # Wait for process + lock to clear (stale .lock can happen after crashes)
    local gone=0
    for i in $(seq 1 60); do
      if ! pgrep -f "$BITCOIND.*-regtest.*-datadir=$DATA_DIR" >/dev/null 2>&1; then
        if [[ -e "$DATA_DIR/regtest/.lock" ]]; then
          # if no process is alive, lock is stale
          rm -f "$DATA_DIR/regtest/.lock" >/dev/null 2>&1 || true
        fi
        if [[ ! -e "$DATA_DIR/regtest/.lock" ]]; then
          gone=1
          break
        fi
      fi
      sleep 1
    done

    if [[ $gone -ne 1 ]]; then
      echo "error: bitcoind did not fully stop or .lock persisted after 60s" >&2
      echo "---- bitcoind processes ----" >&2
      pgrep -af bitcoind >&2 || true
      echo "---- ls -la .lock ----" >&2
      ls -la "$DATA_DIR/regtest/.lock" 2>/dev/null >&2 || true
      exit 1
    fi
  fi


  if [[ "$mode" == "--no-mempool-persist" ]]; then
    say "starting bitcoind (NO mempool persist + NO wallet rebroadcast)"
    rm -f "$DATA_DIR/regtest/mempool.dat" "$DATA_DIR/regtest/mempool.dat.new" 2>/dev/null || true
    "$BITCOIND" -regtest -datadir="$DATA_DIR" -persistmempool=0 -walletbroadcast=0 -daemon >>"$DATA_DIR/regtest/bitcoind_start.log" 2>&1
  else
    say "starting bitcoind (normal: mempool persisted)"
    "$BITCOIND" -regtest -datadir="$DATA_DIR" -daemon >>"$DATA_DIR/regtest/bitcoind_start.log" 2>&1
  fi
  # Wait for RPC (up to RPCWAIT seconds)
  local waited=0
  for i in $(seq 1 "${RPCWAIT}"); do
    if "$CLI" -regtest -datadir="$DATA_DIR" getblockcount >/dev/null 2>&1; then
      break
    fi
    sleep 1
    waited=$i
  done

  if ! "$CLI" -regtest -datadir="$DATA_DIR" getblockcount >/dev/null 2>&1; then
    echo "error: bitcoind RPC not responding (waited ${waited}s)" >&2
    echo "---- bitcoind processes ----" >&2
    pgrep -af bitcoind >&2 || true
    echo "---- tail debug.log ----" >&2
    tail -n 120 "$DATA_DIR/regtest/debug.log" 2>/dev/null >&2 || true
    echo "---- tail bitcoind_start.log ----" >&2
    tail -n 200 "$DATA_DIR/regtest/bitcoind_start.log" 2>/dev/null >&2 || true
    exit 1
  fi

  say "bitcoind up. height=$(bcli getblockcount)"
  if [[ $skip_wallets -eq 1 ]]; then
    say "wallet loading skipped (--skip-wallets)"
  else
    ensure_wallet "$W1"
    ensure_wallet "$W2"
    say "wallets loaded (or already loaded): $W1, $W2"
  fi
  if [[ $skip_wallets -eq 1 ]]; then
    : # skip wallet usability checks
  else
  "$CLI" -regtest -datadir="$DATA_DIR" -rpcwallet="$W2" getnewaddress >/dev/null 2>&1 \
    || die "wallet $W2 not usable (getnewaddress failed)"
  fi


}

cmd_stop() {
  say "---- stop ----"

  # Try clean RPC stop first
  "$CLI" -regtest -datadir="$DATA_DIR" stop >/dev/null 2>&1 || true

  # Wait a bit for clean exit
  for i in {1..40}; do
    if ! pgrep -f "$BITCOIND" >/dev/null 2>&1 && ! pgrep -f "bitcoind.*-regtest.*$DATA_DIR" >/dev/null 2>&1; then
      say "bitcoind stopped."
      return 0
    fi
    sleep 0.25
  done

  # Hard stop fallback (covers stuck/unknown RPC state)
  say "bitcoind still running -> forcing stop (pkill)"
  pkill -f "bitcoind.*-regtest.*$DATA_DIR" >/dev/null 2>&1 || true
  sleep 1
  pkill -9 -f "bitcoind.*-regtest.*$DATA_DIR" >/dev/null 2>&1 || true
  sleep 0.5

  if pgrep -f "bitcoind.*-regtest.*$DATA_DIR" >/dev/null 2>&1; then
    say "WARNING: bitcoind may still be running"
  else
    say "bitcoind stopped (forced)."
  fi
}

cmd_status() {
  say "---- status ----"

  local height mempool last
  height="$(bcli getblockcount 2>/dev/null || true)"

  mempool="$(bcli getmempoolinfo 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("size","?"))' 2>/dev/null || true)"

  last="$(read_last_txid 2>/dev/null || true)"
  if [[ -z "${last:-}" ]]; then
    last="$(pick_best_txid 2>/dev/null || true)"
  fi

  # Wallet balances (trusted + immature)
  local w1_tr w1_imm w2_tr w2_imm
  w1_tr="$(wcli "$W1" getbalances 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); m=d.get("mine",{}); print(m.get("trusted",0))' 2>/dev/null || true)"
  w1_imm="$(wcli "$W1" getbalances 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); m=d.get("mine",{}); print(m.get("immature",0))' 2>/dev/null || true)"
  w2_tr="$(wcli "$W2" getbalances 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); m=d.get("mine",{}); print(m.get("trusted",0))' 2>/dev/null || true)"
  w2_imm="$(wcli "$W2" getbalances 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); m=d.get("mine",{}); print(m.get("immature",0))' 2>/dev/null || true)"

  say "chain height: ${height:-?}"
  say "mempool size: ${mempool:-?}"
  say "last txid: ${last:-}"
  say "wallet $W1: trusted=${w1_tr:-?}  immature=${w1_imm:-?}"
  say "wallet $W2: trusted=${w2_tr:-?}  immature=${w2_imm:-?}"
  say
}



cmd_last() {
  local txid=""

  # 1) Try saved last_txid.txt
  if [[ -s "$LAST_TX_FILE" ]]; then
    txid="$(cat "$LAST_TX_FILE" 2>/dev/null || true)"
    if [[ -n "$txid" ]] && wcli "$W1" gettransaction "$txid" >/dev/null 2>&1; then
      echo "$txid"
      return 0
    fi
  fi

  # 2) Fallback to best
  txid="$(pick_best_txid || true)"
  if [[ -n "$txid" ]]; then
    echo "$txid"
    printf "%s" "$txid" >"$LAST_TX_FILE"
    return 0
  fi

  return 0
}

cmd_best() {
  local txid
  txid="$(pick_best_txid || true)"
  [[ -n "$txid" ]] || die "No txid found (no suitable send/receive tx)."
  write_last_txid ""
  save_last_tx_hex ""

  echo "$txid"
}


cmd_tail() {
  local n="${1:-10}"
  [[ "$n" =~ ^[0-9]+$ ]] || die "tail: Usage tail [N]"

  local out
  out="$(wcli "$W1" listtransactions "*" "$n" 0 true 2>&1 || true)"

  if [[ -z "$out" ]]; then
    say "tail: (no output from listtransactions)"
    return 0
  fi

  # Validate JSON safely
  OUT="$out" python3 - <<'PYJSON' >/dev/null 2>&1 || {
import os, json
json.loads(os.environ.get("OUT",""))
PYJSON
    say "tail: listtransactions returned non-JSON (showing raw):"
    printf "%s
" "$out"
    return 0
  }

  # Print one-line summary per tx
  OUT="$out" python3 - <<'PY2'
import os, json
txs = json.loads(os.environ.get("OUT","[]") or "[]")
if not txs:
  print("(no transactions)")
  raise SystemExit
for t in txs:
  cat=t.get("category","?")
  conf=t.get("confirmations",0)
  ab=t.get("abandoned",False)
  gen=t.get("generated",False)
  amt=t.get("amount",0)
  txid=t.get("txid","")
  print(f"{cat:8} conf={conf:<3} ab={str(ab):<5} gen={str(gen):<5} amt={amt:<12} {txid}")
PY2
}


cmd_mine() {
  # Usage:
  #   mine BLOCKS
  #   mine WALLET BLOCKS
  # If first arg is numeric, treat it as BLOCKS and use default MINER_WALLET.
  local a1="${1:-}"
  local a2="${2:-}"
  local wallet blocks
  if [[ "${a1:-}" =~ ^[0-9]+$ ]]; then
    wallet="${MINER_WALLET}"
    blocks="${a1}"
  else
    wallet="${a1:-$MINER_WALLET}"
    blocks="${a2:-1}"
  fi
  
[[ -n "${blocks:-}" ]] || die "mine: Usage: mine [WALLET] BLOCKS"
  # If blocks is 0, do nothing (used by cmd_new when user requests 0 blocks)
  [[ "${blocks:-0}" -gt 0 ]] || return 0

  say "---- mine ----"
  say "wallet=$wallet blocks=$blocks"
  mine_blocks "$wallet" "$blocks"
  say "Mined $blocks block(s). height=$(bcli getblockcount)"
}


cmd_mature() {
  local blocks="${1:-101}"
  [[ "$blocks" =~ ^[0-9]+$ ]] || die "mature: Usage mature [BLOCKS]"
  cmd_mine "$MINER_WALLET" "$blocks"
}

cmd_mempool() {
  local mi
  mi="$(bcli getmempoolinfo 2>/dev/null || true)"

  if [[ -z "${mi:-}" ]]; then
    # likely bitcoind not running / RPC not reachable
    if ! bcli getblockcount >/dev/null 2>&1; then
      die "mempool: RPC not reachable (is bitcoind running?). Try: ./aurum_flow.sh start"
    fi
    die "mempool: getmempoolinfo returned empty output"
  fi

  # Compact one-liner when quiet (CI sets AURUM_QUIET=1)
  if [[ "${AURUM_QUIET:-0}" == "1" ]]; then
    local size bytes unbroadcast
    size="$(printf '%s' "$mi" | python3 -c 'import sys,json; j=json.load(sys.stdin); print(j.get("size",0))' 2>/dev/null || echo 0)"
    bytes="$(printf '%s' "$mi" | python3 -c 'import sys,json; j=json.load(sys.stdin); print(j.get("bytes",0))' 2>/dev/null || echo 0)"
    unbroadcast="$(printf '%s' "$mi" | python3 -c 'import sys,json; j=json.load(sys.stdin); print(j.get("unbroadcastcount",0))' 2>/dev/null || echo 0)"
    echo "mempool size=$size bytes=$bytes unbroadcast=$unbroadcast"
    return 0
  fi

  say "---- mempool ----"
  echo "$mi" | print_json
}

cmd_confirm() {
  local txid="${1:-}"

  if [[ "$txid" == "best" ]]; then
    txid="$(pick_best_txid || true)"
    [[ -n "$txid" ]] || die "No txid found (no suitable send/receive tx)."
    # keep last_txid.txt in sync with "best"
    write_last_txid "$txid"
    save_last_tx_hex "$txid"
  fi

  if [[ "$txid" == "last" || -z "$txid" ]]; then
    txid="$(read_last_txid)"
    if [[ -z "$txid" ]]; then
      txid="$(pick_best_txid || true)"
      [[ -n "$txid" ]] || die "No txid. Use: confirm TXID  OR confirm last  OR confirm best"
      write_last_txid "$txid"
      save_last_tx_hex "$txid"
    fi
  fi

  [[ -n "$txid" ]] || die "No txid. Use: confirm TXID  OR confirm last  OR confirm best"

  say
  say "TXID=$txid"
  echo
  say "$W1 view:"
  wcli "$W1" gettransaction "$txid" 2>/dev/null | print_json || true
  echo
  say "$W2 view:"
  wcli "$W2" gettransaction "$txid" 2>/dev/null | print_json || true
  echo
}

cmd_confirm_all() {
  local blocks="${1:-$DEFAULT_MINE_BLOCKS}"
  if [[ "$blocks" != "0" ]]; then
    mine_blocks "$MINER_WALLET" "$blocks"
  fi
  cmd_confirm last
}

cmd_pay() {
  # Usage:
  #   pay AMOUNT [--no-mine] [--quiet]
  #   pay [--no-mine] [--quiet] AMOUNT
  #
  # Flags can appear in any order; first numeric token is the amount.
  local quiet=0
  local no_mine=0
  local amount=""


  # pay: auto-load wallets if they aren't loaded (helps after --skip-wallets starts)
  "$CLI" -regtest -datadir="$DATA_DIR" loadwallet "$W2" >/dev/null 2>&1 || true
  "$CLI" -regtest -datadir="$DATA_DIR" loadwallet "$W1" >/dev/null 2>&1 || true
  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --quiet)   quiet=1; shift ;;
      --no-mine) no_mine=1; shift ;;
      *)
        if [[ -z "${amount:-}" ]] && [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          amount="$1"; shift
        else
          die "pay: Usage: pay [--no-mine] [--quiet] AMOUNT"
        fi
        ;;
    esac
  done

  [[ -n "${amount:-}" ]] || die "pay: missing amount (usage: pay [--no-mine] [--quiet] AMOUNT)"

  # Destination address in W2
  local addr txid
  addr="$(wcli "$W2" getnewaddress 2>/dev/null)" || die "pay: couldn't get address from wallet=$W2"

  # Send from W1
  txid="$(wcli "$W1" sendtoaddress "$addr" "$amount" 2>/dev/null)" || die "pay: sendtoaddress failed"

  # Always update last-tx files
  write_last_txid "$txid"
  save_last_tx_hex "$txid"

  # If quiet, stdout MUST be ONLY the txid (for scripting/cmd_new capture)
  if [[ "${quiet:-0}" -eq 1 ]]; then
    echo "$txid"
    return 0
  fi

  say "---- pay ----"
  say "amount=$amount from $W1 -> $W2 (no_mine=$no_mine)"
  say "TXID=$txid"

  if [[ $no_mine -eq 0 ]]; then
    mine_blocks "$MINER_WALLET" "${DEFAULT_MINE_BLOCKS}" >/dev/null
    say "Mined ${DEFAULT_MINE_BLOCKS} block(s). height=$(bcli getblockcount)"
  fi
}

cmd_new() {
  say "---- new ----"
  local amt="" blocks="" mature=0

  # Parse args in any order:
  #   new [AMOUNT] [--mature] [BLOCKS]
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mature) mature=1; shift ;;
      *)
        if [[ -z "${amt:-}" ]] && [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
          amt="$1"; shift
        elif [[ -z "${blocks:-}" ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
          blocks="$1"; shift
        else
          die "new: Usage: new [AMOUNT] [--mature] [BLOCKS]"
        fi
        ;;
    esac
  done

  amt="${amt:-1}"
  if [[ -z "${blocks:-}" ]]; then
    if (( mature == 1 )); then blocks=101; else blocks=1; fi
  fi

  say "sending ${amt} from ${W1} -> ${W2}"

  # Send WITHOUT mining so tx is in mempool first.
  # cmd_pay must echo txid to stdout when --quiet is set.
  local txid
  txid="$(cmd_pay --no-mine --quiet "$amt")"
  [[ -n "${txid:-}" ]] || die "new: could not get txid from pay"

  # Ensure last_* files are set to *this* txid (even if cmd_pay also wrote them)
  write_last_txid "$txid"
  save_last_tx_hex "$txid"

  say "TXID=$txid"

  # Mine + confirm only if blocks > 0
  if [[ "${blocks:-0}" -gt 0 ]]; then
    cmd_mine "$blocks"
    cmd_confirm "$txid"
  fi
}
cmd_pay_many() {
  local no_mine=0
  if [[ "${1:-}" == "--no-mine" ]]; then
    no_mine=1
    shift || true
  fi
  [[ $# -ge 1 ]] || die "pay-many: Usage pay-many [--no-mine] AMT1 [AMT2 ...]"

  # build {"addr":amount,...}
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN

  local a addr
  for a in "$@"; do
    addr="$(wcli "$W2" getnewaddress)"
    printf "%s %s\n" "$addr" "$a" >> "$tmp"
  done

  local map_json
  map_json="$(python3 - <<'PY'
import sys,json
d={}
for line in sys.stdin:
  line=line.strip()
  if not line: continue
  addr,amt=line.split()
  d[addr]=float(amt)
print(json.dumps(d, separators=(",",":")))
PY
  cat "$tmp")"

  local txid
  # sendmany "fromaccount" amounts minconf comment subtractfeefrom replaceable conf_target
  txid="$(wcli "$W1" sendmany "" "$map_json" 0 "" '[]' true 1)"
  write_last_txid "$txid"
  save_last_tx_hex "$txid"

  say "TXID=$txid"
  if [[ "$no_mine" -eq 1 ]]; then
    say "Not mining (tx left in mempool)"
  else
    mine_blocks "$MINER_WALLET" "$DEFAULT_MINE_BLOCKS"
    cmd_confirm "$txid"
  fi
}
cmd_reorg_test() {
  # Flags:
  #   --quiet    : suppress most chatter; keep errors + key results
  #   --verbose  : always show chatter (default behavior)
  local quiet=0
  if [[ "${1:-}" == "--quiet" ]]; then
    quiet=1
    shift || true
  elif [[ "${1:-}" == "--verbose" ]]; then
    quiet=0
    shift || true
  fi

  # quiet-aware logger (overrides say locally)
  sayq() { if [[ "$quiet" -eq 0 ]]; then say "$@"; fi; }

  # quiet mode: suppress accidental bare-number prints (e.g. "0")
  quiet_echo() {
    if [[ "${quiet:-0}" -eq 1 ]]; then
      # drop lines that are only digits (common accidental prints)
      sed -E '/^[[:space:]]*[0-9]+[[:space:]]*$/d'
    else
      cat
    fi
  }


  local depth="${1:-2}"
  local mine_after="${2:-2}"
  local auto_confirm="${3:-1}"
  local reconsider="${4:-1}"

  sayq "---- reorg-test ----"

  local start_h start_tip fork_h fork_hash
  start_h="$(bcli getblockcount)"
  start_tip="$(bcli getbestblockhash)"
  fork_h=$(( start_h - depth ))
  fork_hash="$(bcli getblockhash "$fork_h")"

  sayq "starting height=$start_h"
  sayq "starting tip=$start_tip"
  sayq "fork point height=$fork_h"
  sayq "fork point hash=$fork_hash"

  sayq "invalidating last $depth block(s)..."
  bcli invalidateblock "$start_tip" >/dev/null

  local h1 tip1
  h1="$(bcli getblockcount)"
  tip1="$(bcli getbestblockhash)"
  sayq "after invalidate height=$h1 tip=$tip1"

  sayq "mining $mine_after block(s) on the new tip..."
  mine_blocks "$MINER_WALLET" "$mine_after" >/dev/null

  local h2 tip2
  h2="$(bcli getblockcount)"
  tip2="$(bcli getbestblockhash)"
  sayq "after mine height=$h2 tip=$tip2"

  if [[ "$reconsider" -eq 1 ]]; then
    say "reconsidering invalidated block(s)..." 
    bcli reconsiderblock "$start_tip" >/dev/null

    local h3 tip3
    h3="$(bcli getblockcount)"
    tip3="$(bcli getbestblockhash)"
    say "final height=$h3 tip=$tip3"
  else
    sayq "skipping reconsider (reconsider=0); leaving node on reorged tip"
    sayq "current height=$(bcli getblockcount) tip=$(bcli getbestblockhash)"
  fi
  sayq
  # last txid (best-effort)
  local t
  t="$(cmd_last 2>/dev/null || true)"
  if [[ -z "${t:-}" ]]; then
    sayq "last txid: (none)"
    return 0
  fi

  # If last tx is NOT in mempool (e.g. after start --no-mempool-persist),
  # automatically rebroadcast it from saved hex.
  if ! tx_in_mempool "$t"; then
    sayq "last tx not in mempool -> rebroadcasting..."
    if [[ "$quiet" -eq 1 ]]; then
      out="$(cmd_rebroadcast "$t" 2>&1 || true)"
      # quiet: keep only high-signal lines
      echo "$out" | grep -E '^(rebroadcast status:|error:)' || true
    else
      cmd_rebroadcast "$t" || true
    fi
  fi


  sayq "last txid: $t"
  sayq "aurum confirmations:"
  (   wcli "$W1" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0 ) | quiet_echo
  sayq "aurum2 confirmations:"
  (   wcli "$W2" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0 ) | quiet_echo
  sayq
  # compute cmax
  local c1 c2 cmax
  c1="$(wcli "$W1" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0)"
  c2="$(wcli "$W2" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0)"
  cmax="$c1"; [[ "$c2" -gt "$cmax" ]] && cmax="$c2"

  # mempool check
  local mp in_mempool=1
  mp="$(bcli getrawmempool 2>/dev/null || echo '[]')"
  if python3 -c 'import json,sys; mp=json.loads(sys.argv[1]); tx=sys.argv[2]; sys.exit(0 if tx in mp else 1)' "$mp" "$t" >/dev/null 2>&1; then
    in_mempool=0
  fi

  if [[ "$cmax" -eq 0 ]]; then
    if [[ "$in_mempool" -eq 0 ]]; then
  sayq "last tx is in mempool."
      if [[ "$auto_confirm" -eq 1 ]]; then
        sayq "mining 1 block to confirm..."
        mine_blocks "$MINER_WALLET" "$mine_after"
say "confirm after mine (compact):"
for w in "$W1" "$W2"; do
  conf="$(wcli "$w" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json
try:
  j=json.load(sys.stdin)
  print(int(j.get("confirmations",0) or 0), j.get("blockheight","?"))
except Exception:
  print("?", "?")
' 2>/dev/null)"
  say "  $w: confirmations,height = $conf"
done
      else
        say "(auto-confirm disabled; not mining)"
      fi
    else
      say "auto-rebroadcasting last tx (0-conf, not in mempool)..."
      # After restart with --skip-wallets we MUST have persisted raw hex
      if [[ ! -s "$LAST_TX_HEX_FILE" ]]; then
        die "reorg-test: missing raw tx hex file ($LAST_TX_HEX_FILE) (cannot rebroadcast)"
      fi
      

      # Guard: if tx is non-final due to nLockTime, rebroadcast will fail (-26 non-final)
      # If we are NOT mining and NOT auto-confirming, the tx must land in the mempool.
      # Otherwise smoke(DEPTH=1,MINE_AFTER=0,AUTO_CONFIRM=0,...) will correctly fail later.
      if [[ "${mine_after:-0}" -eq 0 && "${auto_confirm:-0}" -eq 0 ]]; then
        # After rebroadcast attempt, tx may be:
        #  - in mempool (unconfirmed)
        #  - already confirmed (-27 / already in UTXO set), so NOT in mempool
        #  - neither (real failure)
        if bcli getmempoolentry "$txid" >/dev/null 2>&1; then
          say "rebroadcast status: tx is now in mempool"
        else
          # If it's already confirmed, rebroadcast won't put it in mempool.
          if bcli getrawtransaction "$txid" >/dev/null 2>&1; then
            say "rebroadcast status: tx already confirmed (not in mempool)"
          else
            die "reorg-test: rebroadcast did not place tx in mempool and tx is not confirmed (txid=$txid)"
          fi
        fi
      fi
      
      cur_h="$(bcli getblockcount 2>/dev/null || echo 0)"
      locktime="$(bcli getrawtransaction "$t" true 2>/dev/null | python3 -c $'import sys, json\ntry:\n  j=json.load(sys.stdin)\n  print(int(j.get("locktime",0) or 0))\nexcept Exception:\n  print(0)\n' 2>/dev/null || echo 0
)" 
      if [[ "${locktime:-0}" -gt 0 && "${cur_h:-0}" -lt "${locktime:-0}" ]]; then
        say "rebroadcast skipped: tx is non-final until height >= locktime (height=$cur_h locktime=$locktime)"
      else
        if [[ "$quiet" -eq 1 ]]; then
          out="$(cmd_rebroadcast "$t" 2>&1 || true)"
          # quiet: keep only high-signal lines
          echo "$out" | grep -E '^(rebroadcast status:|error:)' || true
        else
          cmd_rebroadcast "$t" || true
        fi
      fi
      # re-check after rebroadcast (could have been -27 / already confirmed)
      c1="$(wcli "$W1" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0)"
      c2="$(wcli "$W2" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0)"
      cmax="$c1"; [[ "$c2" -gt "$cmax" ]] && cmax="$c2"

      if [[ "$cmax" -eq 0 ]]; then
        if [[ "$auto_confirm" -eq 1 ]]; then
          say "auto-confirm enabled -> mining ${mine_after} block(s) to confirm rebroadcast..."
          mine_blocks "$MINER_WALLET" "$mine_after"
        else
          say "(auto-confirm disabled; not mining)"
        fi
      else
        say "rebroadcast not needed; tx is now confirmed (confirmations=$cmax)"
      fi
    fi
  else
    say "last tx already confirmed on current chain (confirmations=$cmax)"
  fi
  sayq
  say "final last-tx status:"
  say "aurum:"
  wcli "$W1" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json
try:
  j=json.load(sys.stdin)
except Exception:
  print("confirmations: ?")
  raise SystemExit(0)
c=j.get("confirmations","?")
print("confirmations:", c)
try:
  ci=int(c)
except Exception:
  ci=0
if ci>0:
  print("blockheight:", j.get("blockheight","?"))
  print("blockhash:", j.get("blockhash",""))
else:
  print("status: unconfirmed (mempool/orphan)")

' 2>/dev/null || true

  say "aurum2:"
  wcli "$W2" gettransaction "$t" 2>/dev/null | python3 -c 'import sys,json
try:
  j=json.load(sys.stdin)
except Exception:
  print("confirmations: ?")
  raise SystemExit(0)
c=j.get("confirmations","?")
print("confirmations:", c)
try:
  ci=int(c)
except Exception:
  ci=0
if ci>0:
  print("blockheight:", j.get("blockheight","?"))
  print("blockhash:", j.get("blockhash",""))
else:
  print("status: unconfirmed (mempool/orphan)")

' 2>/dev/null || true

}



cmd_self_test() {
  say "==== AurumCoin self-test ===="
  say "[1] status"
  cmd_status >/dev/null

  say "[2] mine"
  cmd_mine "$MINER_WALLET" 1 >/dev/null

  say "[3] pay + confirm"
  cmd_pay 1 >/dev/null
  cmd_confirm last >/dev/null

  say "[4] pay-many"
  cmd_pay_many 1 2 3 >/dev/null
  cmd_confirm last >/dev/null

  say "[5] mempool"
  cmd_pay 1 --no-mine >/dev/null
  cmd_mempool >/dev/null
  cmd_mine "$MINER_WALLET" 1 >/dev/null
  cmd_confirm best >/dev/null

  say "[6] confirm-all"
  cmd_confirm_all 1 >/dev/null

  say "[7] reorg-test"
  cmd_reorg_test 2 2 >/dev/null || true

  say "==== SELF-TEST PASSED ===="
}

# -------------------------
# Main dispatcher
# -------------------------
cmd="${1:-}"
shift || true

cmd_tx() {
  local txid="${1:-}"
  [[ -n "${txid:-}" ]] || die "tx: Usage: tx TXID"

  say "---- tx ----"
  say "txid: $txid"
  say

  say "wallet view ($W1):"
  wcli "$W1" gettransaction "$txid" 2>/dev/null || echo "(not in $W1)"
  say
  say "wallet view ($W2):"
  wcli "$W2" gettransaction "$txid" 2>/dev/null || echo "(not in $W2)"
  say

  local raw=""
  raw="$(bcli getrawtransaction "$txid" 2>/dev/null || true)"
  [[ -n "${raw:-}" ]] || die "tx: could not fetch raw tx (not in mempool/chain?)"

  say "decoded:"
  bcli decoderawtransaction "$raw"
  say

  local bh=""
  bh="$(bcli getrawtransaction "$txid" true 2>/dev/null | python3 -c 'import sys,json; j=json.load(sys.stdin); print(j.get("blockhash",""))' 2>/dev/null || true)"
  if [[ -n "${bh:-}" ]]; then
    say "confirmed in block: $bh"
    bcli getblockheader "$bh"
  else
    say "status: unconfirmed (mempool)"
  fi
  say
}

cmd_block() {
  local arg="${1:-}"
  [[ -n "${arg:-}" ]] || die "block: Usage: block HASH|HEIGHT"

  say "---- block ----"

  local hash=""
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    hash="$(bcli getblockhash "$arg" 2>/dev/null || true)"
    [[ -n "${hash:-}" ]] || die "block: bad height: $arg"
  else
    hash="$arg"
  fi

  say "hash: $hash"
  say

  say "header:"
  bcli getblockheader "$hash"
  say

  say "txids:"
  bcli getblock "$hash" 1 | python3 -c $'import sys, json\nb=json.load(sys.stdin)\ntx=b.get("tx",[])\nprint(f"count={len(tx)}")\nfor t in tx[:25]:\n    print(t)\nif len(tx)>25:\n    print("... (truncated)")\n'
  say
}

cmd_addr() {
  local addr="${1:-}"
  [[ -n "${addr:-}" ]] || die "addr: Usage: addr ADDRESS"

  say "---- addr ----"
  say "address: $addr"
  say

  for w in "$W1" "$W2"; do
    local info=""
    info="$(wcli "$w" getaddressinfo "$addr" 2>/dev/null || true)"
    if [[ -n "${info:-}" ]]; then
      say "addressinfo ($w):"
      echo "$info"
      say
    fi
  done

  say "scantxoutset:"
  bcli scantxoutset start "[\"addr($addr)\"]"
  say
}

cmd_explore() {
  say "---- explore ----"

  local height mp
  height="$(bcli getblockcount 2>/dev/null || echo "?")"
  mp="$(bcli getmempoolinfo 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("size","?"))' 2>/dev/null || echo "?")"

  say "height: $height"
  say "mempool: $mp"
  say

  say "balances:"
  for w in "$W1" "$W2"; do
    local trusted immature
    trusted="$(wcli "$w" getbalances 2>/dev/null | python3 -c 'import sys,json; j=json.load(sys.stdin); print(j.get("mine",{}).get("trusted","?"))' 2>/dev/null || echo "?")"
    immature="$(wcli "$w" getbalances 2>/dev/null | python3 -c 'import sys,json; j=json.load(sys.stdin); print(j.get("mine",{}).get("immature","?"))' 2>/dev/null || echo "?")"
    say "  $w: trusted=$trusted immature=$immature"
  done
  say

  local last=""
  last="$(read_last_txid 2>/dev/null || true)"
  if [[ -z "${last:-}" ]]; then
    last="$(pick_best_txid 2>/dev/null || true)"
  fi
  say "last txid: ${last:-}"
  say

  say "recent wallet txs:"
  cmd_tail 8
}

# ---- V2 INSPECTORS (tx/block) ----
cmd_tx2() {
  local arg="${1:-}"
  [[ -n "${arg:-}" ]] || die "tx: Usage: tx TXID|last|best"

  local txid=""
  case "$arg" in
    last) txid="$(read_last_txid || true)" ;;
    best) txid="$(pick_best_txid || true)" ;;
    *)    txid="$arg" ;;
  esac
  [[ -n "${txid:-}" ]] || die "tx: could not determine txid"

  say "---- tx ----"
  say "txid: $txid"
  say

  local j1 j2
  j1="$(wcli "$W1" gettransaction "$txid" 2>/dev/null || true)"
  j2="$(wcli "$W2" gettransaction "$txid" 2>/dev/null || true)"

  say "wallet view ($W1):"
  [[ -n "${j1:-}" ]] && echo "$j1" || echo "(not in $W1)"
  say
  say "wallet view ($W2):"
  [[ -n "${j2:-}" ]] && echo "$j2" || echo "(not in $W2)"
  say

  # Extract hex robustly via stdin JSON
  local hex=""
  if [[ -n "${j1:-}" ]]; then
    hex="$(echo "$j1" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("hex",""))' 2>/dev/null || echo "")"
  fi
  if [[ -z "${hex:-}" && -n "${j2:-}" ]]; then
    hex="$(echo "$j2" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("hex",""))' 2>/dev/null || echo "")"
  fi

  [[ -n "${hex:-}" ]] || die "tx: no wallet hex found for this txid (not in wallets?)"

  say "decoded:"
  bcli decoderawtransaction "$hex"
  say

  # Show block header if confirmed
  local bh=""
  if [[ -n "${j1:-}" ]]; then
    bh="$(echo "$j1" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("blockhash",""))' 2>/dev/null || echo "")"
  fi
  if [[ -z "${bh:-}" && -n "${j2:-}" ]]; then
    bh="$(echo "$j2" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("blockhash",""))' 2>/dev/null || echo "")"
  fi

  if [[ -n "${bh:-}" ]]; then
    say "confirmed in block: $bh"
    bcli getblockheader "$bh"
    say
  else
    # Distinguish mempool vs not in mempool
    local mp=""
    mp="$(bcli getrawmempool 2>/dev/null || echo '[]')"
    local in_mp="0"
    export TXID="$txid" MEMPOOL="$mp"
 in_mp="$(python3 - <<'P'
import os, json
txid=os.environ.get("TXID","")
try:
    mp=set(json.loads(os.environ.get("MEMPOOL","[]") or "[]"))
except Exception:
    mp=set()
print("1" if txid in mp else "0")
P
)"
    if [[ "$in_mp" == "1" ]]; then
      say "status: unconfirmed (in mempool)"
    else
      say "status: unconfirmed (not in mempool / conflicted)"
    fi
    say
  fi
}

cmd_block2() {
  local arg="${1:-}"
  [[ -n "${arg:-}" ]] || die "block: Usage: block HASH|HEIGHT"

  say "---- block ----"

  local hash=""
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    hash="$(bcli getblockhash "$arg" 2>/dev/null)" || die "block: bad height: $arg"
  else
    hash="$arg"
  fi

  say "hash: $hash"
  say

  say "header:"
  bcli getblockheader "$hash"
  say

  local bj=""
  bj="$(bcli getblock "$hash" 1 2>/dev/null || true)"
  [[ -n "${bj:-}" ]] || die "block: could not fetch block JSON (RPC issue?)"

  say "txids:"
  BJ="$bj" python3 - <<'P2'
import os, json
b = json.loads(os.environ["BJ"])
tx = b.get("tx", [])
print(f"count={len(tx)}")
for t in tx[:50]:
    print(t)
if len(tx) > 50:
    print("... (truncated)")
P2
  say
}

### CMD_REBROADCAST ###
cmd_rebroadcast() {
  local txid="${1:-}"
  [[ -n "$txid" ]] || die "rebroadcast: need TXID"

  say "---- rebroadcast ----"
  say "txid: $txid"
  say

  # Try to obtain raw tx (prefer node, fallback to wallet hex)
  local rawhex=""
  rawhex="$(bcli getrawtransaction "$txid" 0 2>/dev/null || true)"

  if [[ -z "${rawhex:-}" ]]; then
    rawhex="$(wcli "$W1" gettransaction "$txid" 2>/dev/null | python3 -c $'import sys, json\ntry:\n  j=json.load(sys.stdin)\n  print(j.get("hex","") or "")\nexcept Exception:\n  print("")\n' 2>/dev/null || true
)"
  fi

  if [[ -z "${rawhex:-}" ]]; then
    rawhex="$(wcli "$W2" gettransaction "$txid" 2>/dev/null | python3 -c $'import sys, json\ntry:\n  j=json.load(sys.stdin)\n  print(j.get("hex","") or "")\nexcept Exception:\n  print("")\n' 2>/dev/null || true
)"
  fi

  # Fallback: use saved hex from LAST_TX_HEX_FILE (written at send time)

  if [[ -z "${rawhex:-}" && -f "$LAST_TX_HEX_FILE" ]]; then

    rawhex="$(tr -d ' \t\r\n' < "$LAST_TX_HEX_FILE" 2>/dev/null || true)"

  fi

  # Fallback: use saved hex from LAST_TX_HEX_FILE (written at send time)

  if [[ -z "${rawhex:-}" && -f "$LAST_TX_HEX_FILE" ]]; then

    rawhex="$(tr -d ' \t\r\n' < "$LAST_TX_HEX_FILE" 2>/dev/null || true)"

  fi

  [[ -n "${rawhex:-}" ]] || die "rebroadcast: couldn't fetch raw tx (no txindex; wallets lack hex; and no $LAST_TX_HEX_FILE)"

  # Decode locktime so we can explain/guard non-final cases
  local locktime cur_h mtp
  locktime="$(printf "%s" "$rawhex" | bcli decoderawtransaction - 2>/dev/null | python3 -c $'import sys, json\ntry:\n  j=json.load(sys.stdin)\n  print(int(j.get("locktime",0) or 0))\nexcept Exception:\n  print(0)\n' 2>/dev/null || echo 0
)"
  cur_h="$(bcli getblockcount 2>/dev/null || echo 0)"
  mtp="$(bcli getblockheader "$(bcli getbestblockhash)" 2>/dev/null | python3 -c $'import sys, json\ntry:\n  j=json.load(sys.stdin)\n  print(int(j.get("mediantime",0) or 0))\nexcept Exception:\n  print(0)\n' 2>/dev/null || echo 0
)"

  # Broadcast and capture errors
  local out rc
  out="$(bcli sendrawtransaction "$rawhex" 2>&1)"; rc=$?

  if [[ $rc -eq 0 ]]; then
    say "sendrawtransaction: $out"

  # Post-check: is it in the mempool now?
  if bcli getmempoolentry "$txid" >/dev/null 2>&1; then
    say "rebroadcast status: tx is now in mempool"
    # ASSERT: tx must be in mempool *right now*
    bcli getmempoolentry "$txid" >/dev/null 2>&1 \
      || die "ASSERT FAIL: mempoolentry missing right after rebroadcast"
    bcli getrawmempool | grep -q "$txid" \
      || die "ASSERT FAIL: txid not found in getrawmempool right after rebroadcast"
    say "ASSERT OK: txid present in mempool right after rebroadcast"
  else
    say "rebroadcast status: tx is NOT in mempool"
  fi

    return 0
  fi

  # Handle known benign errors:

  # -27: already in UTXO set (tx is already confirmed in active chain)
  if echo "$out" | grep -q "outputs already in UTXO set"; then
    say "note: node says outputs already in UTXO set (-27). Treating as success (tx already in active chain)."
    return 0
  fi

  # -26 non-final: locktime/sequence not yet satisfied
  if echo "$out" | grep -qi "non-final"; then
    # For height-based locktime, Core considers height of *next* block (tip+1) for finality checks
    local next_h=$((cur_h + 1))
    if [[ "${locktime:-0}" -ge 500000000 ]]; then
      say "note: rebroadcast rejected as non-final (-26)."
      say "      tx is time-locked until MTP >= locktime (mtp=$mtp locktime=$locktime)"
    else
      say "note: rebroadcast rejected as non-final (-26)."
      say "      tx is height-locked until height >= locktime (next_height=$next_h locktime=$locktime)"
    fi
    # Don't fail the whole script; this is a valid state.
    return 0
  fi

  # Unknown failure -> surface it
  die "rebroadcast: sendrawtransaction failed: $out"
}

cmd_reorg_sim() {
  # Same args as reorg-test for convenience
  # reorg-sim [--quiet|--verbose] [DEPTH] [MINE_AFTER] [AUTO_CONFIRM=1|0] [RECONSIDER=1|0]
  cmd_reorg_test "$@"
}

cmd_reorg_e2e() {
  # reorg-e2e [DEPTH] [MINE_AFTER] [AUTO_CONFIRM=1|0] [RECONSIDER=1|0] [AMOUNT=1]
  local depth="${1:-6}"
  local mine_after="${2:-2}"
  local auto_confirm="${3:-1}"
  local reconsider="${4:-0}"
  local amount="${5:-1}"
  [[ "${amount:-0}" != "0" ]] || amount=1

  say "---- reorg-e2e ----"
  say "1) create tx (amount=${amount}) left unmined"
  if [[ "${quiet:-0}" -eq 1 ]]; then
    out="$( cmd_new "$amount" 0 2>&1 || true )"
    # quiet: hide txid noise
    echo "$out" | sed -E '/^[[:space:]]*(TXID=|txid:)/d'
  else
    cmd_new "$amount" 0
  fi
  local txid
  txid="$(cat aurum-regtest-data/last_txid.txt 2>/dev/null || true)"
  [[ -n "${txid:-}" ]] || die "reorg-e2e: could not read last txid file"
  # Persist raw hex BEFORE restart so reorg-test can rebroadcast even with --skip-wallets
  save_last_tx_hex "$txid"
  if [[ ! -s "$LAST_TX_HEX_FILE" ]]; then
    die "reorg-e2e: missing last tx hex file ($LAST_TX_HEX_FILE); cannot rebroadcast after --skip-wallets"
  fi
  

  say
  say "2) clean restart (drop mempool + no wallet rebroadcast)"
  # NOTE: cmd_start already hard-stops any running bitcoind, so no need to stop twice.
  cmd_start --hard --no-mempool-persist --skip-wallets
  say "mempool after clean restart:"
  if [[ "${CI_MODE:-0}" -eq 1 && "${VERBOSE:-0}" -ne 1 ]]; then
    AURUM_QUIET=1 cmd_mempool
  else
    cmd_mempool
  fi

  # Explicitly load wallets after clean restart (do NOT rely on side-effects)
  "$CLI" -regtest -datadir="$DATA_DIR" loadwallet "$W1" >/dev/null 2>&1 || true
  "$CLI" -regtest -datadir="$DATA_DIR" loadwallet "$W2" >/dev/null 2>&1 || true


  # CI miner wallet (fresh) so we can mine without loading $W1/$W2 (which may resubmit old txs)
  local CI_MINER_WALLET="ci_miner"
  "$CLI" -regtest -datadir="$DATA_DIR" loadwallet "$CI_MINER_WALLET" >/dev/null 2>&1 || \
    "$CLI" -regtest -datadir="$DATA_DIR" createwallet "$CI_MINER_WALLET" true true "" true >/dev/null 2>&1 || true



  say
  say "3) assert tx missing from mempool"
  if tx_in_mempool "$txid"; then
    die "FAIL: tx still in mempool after start --no-mempool-persist (txid=$txid)"
  fi
  say "OK: missing"

  say
  say "4) run reorg-test (should auto-rebroadcast; optionally mine/confirm)"
  cmd_reorg_test --quiet "$depth" "$mine_after" "$auto_confirm" "$reconsider"
  say "mempool after reorg-test (rebroadcast stage):"
  if [[ "${CI_MODE:-0}" -eq 1 && "${VERBOSE:-0}" -ne 1 ]]; then
    AURUM_QUIET=1 cmd_mempool
  else
    cmd_mempool
  fi

  say
  say "5) assert tx is now known and confirmations reflect mining (if enabled)"
  local c1 c2 cmax
  c1="$(wcli "$W1" gettransaction "$txid" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0)"
  c2="$(wcli "$W2" gettransaction "$txid" 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin).get("confirmations",0) or 0))' 2>/dev/null || echo 0)"
  cmax="$c1"; [[ "$c2" -gt "$cmax" ]] && cmax="$c2"

  if [[ "$auto_confirm" -eq 1 ]]; then
    if [[ "$cmax" -lt 1 ]]; then
      die "FAIL: expected confirmed tx after auto_confirm=1 (confirmations=$cmax txid=$txid)"
    fi
    say "OK: confirmed (confirmations=$cmax)"
  else
    if [[ "$cmax" -ge 1 ]]; then
      say "OK: confirmed even though auto_confirm=0 (confirmations=$cmax)"
    elif tx_in_mempool "$txid"; then
      say "OK: unconfirmed but present (mempool)"
    else
      die "FAIL: tx missing from mempool and unconfirmed (txid=$txid)"
    fi
  fi

  # One-line summary for scripts/CI
  local h mp
  h="$(bcli getblockcount 2>/dev/null || echo "?")"
  mp="$(bcli getmempoolinfo 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("size","?"))' 2>/dev/null || echo "?")"
  say
  if [[ "${quiet:-0}" -eq 1 ]]; then
    say "PASS: reorg-e2e depth=$depth mine_after=$mine_after auto_confirm=$auto_confirm reconsider=$reconsider amount=$amount txid=<redacted> conf=$cmax height=$h mempool=$mp"
  else
    if [[ "${quiet:-0}" -eq 1 ]]; then
      say "PASS: reorg-e2e depth=$depth mine_after=$mine_after auto_confirm=$auto_confirm reconsider=$reconsider amount=$amount txid=<redacted> conf=$cmax height=$h mempool=$mp"
    else
      say "PASS: reorg-e2e depth=$depth mine_after=$mine_after auto_confirm=$auto_confirm reconsider=$reconsider amount=$amount txid=$txid conf=$cmax height=$h mempool=$mp"
    fi
  fi
}

# shellcheck disable=SC2218
case "$cmd" in
  start) cmd_start "$@" ;;
  stop)        cmd_stop ;;
  help)        cmd_help ;;
  last)        cmd_last ;;
  best)        cmd_best ;;
  new)         cmd_new "${1:-1}" "${2:-$DEFAULT_MINE_BLOCKS}" ;;
  mature)      cmd_mature "${1:-101}" ;;
  tail)        cmd_tail "${1:-}" ;;
  status)      cmd_status ;;
  mine)        cmd_mine "${1:-$MINER_WALLET}" "${2:-$DEFAULT_MINE_BLOCKS}" ;;
  pay)         cmd_pay "$@" ;;
  pay-many)    cmd_pay_many "$@" ;;
  confirm)     cmd_confirm "${1:-}" ;;
  confirm-all) cmd_confirm_all "${1:-$DEFAULT_MINE_BLOCKS}" ;;
  mempool)     cmd_mempool ;;
  reorg-test)
    cmd_reorg_test "$@"
    ;;
  self-test)   cmd_self_test ;;
  explore)     cmd_explore ;;
  tx)          cmd_tx2 "$@" ;;
  block)       cmd_block2 "$@" ;;
  addr)        cmd_addr "$@" ;;
  rebroadcast) cmd_rebroadcast "$@" ;;
  reorg-sim)  cmd_reorg_sim "$@" ;;
  reorg-e2e)  cmd_reorg_e2e "$@" ;;

  quiet-filter)  cmd_quiet_filter "$@" ;;
  reorg-ci)  cmd_reorg_ci "$@" ;;
  check)       cmd_check ;;
  smoke)       cmd_smoke "$@" ;;
  *) die "Usage: ./aurum_flow.sh {help|start|stop|last|best|new|mature|tail|status|mine|pay|pay-many|confirm|confirm-all|mempool|reorg-test|reorg-sim|self-test|explore|tx|block|addr|rebroadcast|quiet-filter|reorg-ci|check|smoke}" ;;

esac


cmd_tx2() {
  local txid="${1:-}"
  [[ -n "${txid:-}" ]] || die "tx: Usage: tx TXID"

  say "---- tx ----"
  say "txid: $txid"
  say

  local j1 j2
  j1="$(wcli "$W1" gettransaction "$txid" 2>/dev/null || true)"
  j2="$(wcli "$W2" gettransaction "$txid" 2>/dev/null || true)"

  say "wallet view ($W1):"
  [[ -n "${j1:-}" ]] && echo "$j1" || echo "(not in $W1)"
  say
  say "wallet view ($W2):"
  [[ -n "${j2:-}" ]] && echo "$j2" || echo "(not in $W2)"
  say

  # Pull raw tx hex from whichever wallet has it (no -txindex needed)
  local hex
  export HEX_J1="$j1" HEX_J2="$j2"
 hex="$(python3 - <<'P'
import os, json
for k in ("HEX_J1","HEX_J2"):
    raw = (os.environ.get(k,"") or "").strip()
    if not raw:
        continue
    try:
        j = json.loads(raw)
    except Exception:
        continue
    h = j.get("hex","")
    if h:
        print(h)
        raise SystemExit(0)
print("")
P
)"
  [[ -n "${hex:-}" ]] || die "tx: no wallet hex found for this txid (not in wallets)"

  say "decoded:"
  bcli decoderawtransaction "$hex"
  say

  # If confirmed, show block header too (wallet has blockhash)
  local bh
  export BH_J1="$j1" BH_J2="$j2"
 bh="$(python3 - <<'P'
import os, json
for k in ("BH_J1","BH_J2"):
    raw = (os.environ.get(k,"") or "").strip()
    if not raw:
        continue
    try:
        j=json.loads(raw)
    except Exception:
        continue
    bh=j.get("blockhash","")
    if bh:
        print(bh)
        raise SystemExit(0)
print("")
P
)"
  if [[ -n "${bh:-}" ]]; then
    say "confirmed in block: $bh"
    bcli getblockheader "$bh"
    say
  else
    say "status: unconfirmed (mempool)"
    say
  fi
}

cmd_block2() {
  local arg="${1:-}"
  [[ -n "${arg:-}" ]] || die "block: Usage: block HASH|HEIGHT"

  say "---- block ----"

  local hash=""
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    hash="$(bcli getblockhash "$arg" 2>/dev/null)" || die "block: bad height: $arg"
  else
    hash="$arg"
  fi

  say "hash: $hash"
  say

  say "header:"
  bcli getblockheader "$hash"
  say

  # Fetch block JSON robustly (NO empty pipe into python)
  local bj=""
  if ! bj="$(bcli getblock "$hash" 1 2>/dev/null)"; then
    die "block: could not fetch block JSON (RPC issue?)"
  fi
  [[ -n "${bj:-}" ]] || die "block: empty block JSON (RPC issue?)"

  say "txids:"
  BJ="$bj" python3 - <<'P2'
import os, json
b = json.loads(os.environ["BJ"])
tx = b.get("tx", [])
print(f"count={len(tx)}")
for t in tx[:50]:
    print(t)
if len(tx) > 50:
    print("... (truncated)")
P2
  say
}

# CI exit guard
[[ $CI_MODE -eq 1 ]] && exit 0
