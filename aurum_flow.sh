#!/usr/bin/env bash
set -eu

# -------------------------
# Config (edit if your paths differ)
# -------------------------
DATA_DIR="${DATA_DIR:-/Users/ericciciotti/Documents/AurumCoin/aurum-regtest-data}"
CLI="${CLI:-/Users/ericciciotti/Documents/AurumCoin/build/bin/bitcoin-cli}"
BITCOIND="${BITCOIND:-/Users/ericciciotti/Documents/AurumCoin/build/bin/bitcoind}"
RPCWAIT="${RPCWAIT:-60}"

W1="${W1:-aurum}"
W2="${W2:-aurum2}"
MINER_WALLET="${MINER_WALLET:-$W1}"

LAST_TX_FILE="${LAST_TX_FILE:-$DATA_DIR/last_txid.txt}"
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
  python3 -m json.tool
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
# -------------------------
# Commands
# -------------------------
cmd_help() {
  cat <<'EOH'
Usage: ./aurum_flow.sh {help|start|stop|last|best|new|mature|tail|status|mine|pay|pay-many|confirm|confirm-all|mempool|reorg-test|self-test|explore|tx|block|addr}

help
start                    (start bitcoind + load wallets)
stop                     (stop bitcoind)
last                     (prints last txid; falls back to best)
best                     (prints best txid; writes last_txid.txt)
new [AMOUNT] [--mature] [BLOCKS] (send AMOUNT W1->W2, mine (default 1; --mature=101), confirm)
mature [BLOCKS]            (mine BLOCKS, default 101, to mature coinbase)
tail [N]                 (prints last N wallet txs, one-line)
status
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
reorg-test [DEPTH] [MINE_AFTER]
self-test
EOH
}

cmd_start() {
  say "---- start ----"

  # Start bitcoind (regtest) with regtest-friendly defaults
  "$BITCOIND" -regtest \
    -datadir="$DATA_DIR" \
    -server=1 \
    -fallbackfee=0.00001 \
    -daemon >/dev/null 2>&1 || true

  # Wait for RPC to answer
  local tries=120
  while (( tries > 0 )); do
    if bcli getblockcount >/dev/null 2>&1; then
      break
    fi
    sleep 0.25
    ((tries--))
  done

  # Verify
  local h=""
  h="$(bcli getblockcount 2>/dev/null || true)"
  [[ -n "${h:-}" ]] || die "start: RPC not ready (check debug.log in $DATA_DIR/regtest/)"

  say "bitcoind up. height=$h"

  # Load wallets (ignore errors if already loaded)
  bcli loadwallet "$W1" >/dev/null 2>&1 || true
  bcli loadwallet "$W2" >/dev/null 2>&1 || true
  say "wallets loaded (or already loaded): $W1, $W2"
  say
}

cmd_stop() {
  say "---- stop ----"

  # Try graceful stop first
  if bcli stop >/dev/null 2>&1; then
    say "bitcoind stopped."
    say
    return 0
  fi

  # If RPC isn't reachable, kill the process for this datadir
  local pid=""
  if [[ -f "$DATA_DIR/regtest/bitcoind.pid" ]]; then
    pid="$(cat "$DATA_DIR/regtest/bitcoind.pid" 2>/dev/null || true)"
  fi

  if [[ -n "${pid:-}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    sleep 0.3
    kill -9 "$pid" >/dev/null 2>&1 || true
    say "bitcoind killed (pid=$pid)."
  else
    pkill -f "$BITCOIND.*-regtest.*-datadir=$DATA_DIR" >/dev/null 2>&1 || true
    say "bitcoind stopped (best-effort)."
  fi

  say
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
  write_last_txid "$txid"
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
  local miner="${1:-$MINER_WALLET}"
  local blocks="${2:-$DEFAULT_MINE_BLOCKS}"
  mine_blocks "$miner" "$blocks"
  local h
  h="$(bcli getblockcount)"
  say "Mined $blocks block(s). height=$h"
}

cmd_mature() {
  local blocks="${1:-101}"
  [[ "$blocks" =~ ^[0-9]+$ ]] || die "mature: Usage mature [BLOCKS]"
  cmd_mine "$MINER_WALLET" "$blocks"
}

cmd_mempool() {
  say "---- mempool ----"
  bcli getmempoolinfo 2>/dev/null | print_json || true
  say
  say "txids:"
  bcli getrawmempool 2>/dev/null | print_json || true
  say "-----------------"
}

cmd_confirm() {
  local txid="${1:-}"

  if [[ "$txid" == "best" ]]; then
    txid="$(pick_best_txid || true)"
    [[ -n "$txid" ]] || die "No txid found (no suitable send/receive tx)."
    # keep last_txid.txt in sync with "best"
    write_last_txid "$txid"
  fi

  if [[ "$txid" == "last" || -z "$txid" ]]; then
    txid="$(read_last_txid)"
    if [[ -z "$txid" ]]; then
      txid="$(pick_best_txid || true)"
      [[ -n "$txid" ]] || die "No txid. Use: confirm TXID  OR confirm last  OR confirm best"
      write_last_txid "$txid"
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
  # Flags can appear in any order.

  local quiet=0
  local no_mine=0
  local amount=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quiet)   quiet=1; shift ;;
      --no-mine) no_mine=1; shift ;;
      --help|-h) die "pay: Usage pay AMOUNT [--no-mine] [--quiet]" ;;
      -*)
        die "pay: unknown flag: $1"
        ;;
      *)
        if [[ -z "${amount:-}" ]]; then
          amount="$1"; shift
        else
          die "pay: too many args (got extra: $1)"
        fi
        ;;
    esac
  done

  [[ -n "${amount:-}" ]] || die "pay: Usage pay AMOUNT [--no-mine] [--quiet]"

  local addr txid
  addr="$(wcli "$W2" getnewaddress)"
  txid="$(wcli "$W1" sendtoaddress "$addr" "$amount")"
  write_last_txid "$txid"

  if [[ "$quiet" -eq 0 ]]; then
    say "TXID=$txid"
  fi

  if [[ "$no_mine" -eq 1 ]]; then
    if [[ "$quiet" -eq 0 ]]; then
      say "Not mining (tx left in mempool)"
    fi
  else
    mine_blocks "$MINER_WALLET" "$DEFAULT_MINE_BLOCKS"
    cmd_confirm "$txid"
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

  # 1) Send WITHOUT mining so the tx definitely exists in mempool first
  cmd_pay "${amt}" --no-mine --quiet

  # 2) Capture the newest suitable txid (prefers mempool, else confirmed)
  local txid
  txid="$(pick_best_txid || true)"
  [[ -n "${txid:-}" ]] || die "new: could not find txid after send"
  write_last_txid "$txid"

  # 3) Mine blocks (101 if --mature)
  cmd_mine "${W1}" "${blocks}"

  # 4) Confirm that txid explicitly (never pass placeholder strings)
  cmd_confirm "$txid"
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
  < "$tmp")"

  local txid
  # sendmany "fromaccount" amounts minconf comment subtractfeefrom replaceable conf_target
  txid="$(wcli "$W1" sendmany "" "$map_json" 0 "" '[]' true 1)"
  write_last_txid "$txid"

  say "TXID=$txid"
  if [[ "$no_mine" -eq 1 ]]; then
    say "Not mining (tx left in mempool)"
  else
    mine_blocks "$MINER_WALLET" "$DEFAULT_MINE_BLOCKS"
    cmd_confirm "$txid"
  fi
}

cmd_reorg_test() {
  local depth="${1:-2}"
  local mine_after="${2:-2}"
  [[ "$depth" =~ ^[0-9]+$ ]] || die "reorg-test: DEPTH must be a number"
  [[ "$mine_after" =~ ^[0-9]+$ ]] || die "reorg-test: MINE_AFTER must be a number"
  [[ "$depth" -ge 1 ]] || die "reorg-test: DEPTH must be >= 1"

  say "---- reorg-test ----"
  # Make a tx and confirm it so it can be reorg'd out
  cmd_pay_many 2 3 1 >/dev/null
  local txid
  txid="$(read_last_txid)"
  say "last tx: $txid"

  local tip h target_h target_hash
  h="$(bcli getblockcount)"
  tip="$(bcli getbestblockhash)"
  say "tip: $tip"

  target_h=$((h - depth + 1))
  if [[ "$target_h" -lt 1 ]]; then
    die "reorg-test: chain too short (height=$h) for depth=$depth"
  fi
  target_hash="$(bcli getblockhash "$target_h")"
  say "invalidate height=$target_h hash=$target_hash"
  bcli invalidateblock "$target_hash" >/dev/null || true

  say "---- last-tx after invalidate ----"
  cmd_confirm "$txid" || true

  # re-mine
  mine_blocks "$MINER_WALLET" "$mine_after"
  say "---- last-tx after re-mine ----"
  cmd_confirm "$txid" || true

  say "final height: $(bcli getblockcount)"
  say "final tip:    $(bcli getbestblockhash)"
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
  bcli getblock "$hash" 1 | python3 - <<'P2'
import sys, json
b=json.load(sys.stdin)
tx=b.get("tx",[])
print(f"count={len(tx)}")
for t in tx[:25]:
    print(t)
if len(tx)>25:
    print("... (truncated)")
P2
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

  # Extract hex robustly (no env vars)
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



case "$cmd" in
  start)       cmd_start ;;
  stop)        cmd_stop ;;
  help)        cmd_help ;;
  last)        cmd_last ;;
  best)        cmd_best ;;
  new)         cmd_new "${1:-1}" "${2:-$DEFAULT_MINE_BLOCKS}" ;;
  mature)      cmd_mature "${1:-101}" ;;
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
  reorg-test)  cmd_reorg_test "${1:-2}" "${2:-2}" ;;
  self-test)   cmd_self_test ;;
  explore)     cmd_explore ;;
  tx)          cmd_tx2 "$@" ;;
  block)       cmd_block2 "$@" ;;
  addr)        cmd_addr "$@" ;;
  *) die "Usage: ./aurum_flow.sh {help|start|stop|last|best|new|mature|tail|status|mine|pay|pay-many|confirm|confirm-all|mempool|reorg-test|self-test|explore|tx|block|addr}" ;;
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
  HEX_J1="$j1" HEX_J2="$j2" hex="$(python3 - <<'P'
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
  BH_J1="$j1" BH_J2="$j2" bh="$(python3 - <<'P'
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
