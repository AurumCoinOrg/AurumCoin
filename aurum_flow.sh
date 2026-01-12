#!/usr/bin/env bash
set -euo pipefail

# =========================
# aurum_flow.sh v1.2.0
# =========================
VERSION="1.2.0"

# ----- Defaults (override via env) -----
CLI="${CLI:-/Users/ericciciotti/Documents/AurumCoin/build/bin/bitcoin-cli}"
DATA_DIR="${DATA_DIR:-/Users/ericciciotti/Documents/AurumCoin/aurum-regtest-data}"

W1="${W1:-aurum}"
W2="${W2:-aurum2}"
MINER_WALLET="${MINER_WALLET:-$W1}"

DEFAULT_MINE_BLOCKS="${DEFAULT_MINE_BLOCKS:-1}"

# Files
BATCH_FILE="${BATCH_FILE:-$DATA_DIR/batch_amounts.txt}"
LAST_TX_FILE="${LAST_TX_FILE:-$DATA_DIR/last_txid.txt}"

# -------------------------
# Helpers
# -------------------------
say() { printf "%s\n" "$*"; }
die() { printf "error: %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

bcli() {
  "$CLI" -regtest -datadir="$DATA_DIR" "$@"
}

wcli() {
  local wallet="$1"; shift
  "$CLI" -regtest -datadir="$DATA_DIR" -rpcwallet="$wallet" "$@"
}

print_json() {
  # Works with stdin OR with arguments
  if [[ $# -gt 0 ]]; then
    printf "%s" "$*" | python3 -c 'import sys,json; s=sys.stdin.read(); 
if not s.strip(): sys.exit(0)
try: print(json.dumps(json.loads(s), indent=2))
except Exception: print(s, end="")'
  else
    python3 -c 'import sys,json; s=sys.stdin.read(); 
if not s.strip(): sys.exit(0)
try: print(json.dumps(json.loads(s), indent=2))
except Exception: print(s, end="")'
  fi
}

write_last_txid() {
  local txid="$1"
  mkdir -p "$(dirname "$LAST_TX_FILE")"
  printf "%s\n" "$txid" > "$LAST_TX_FILE"
}

read_last_txid() {
  if [[ -f "$LAST_TX_FILE" ]]; then
    tr -d ' \t\r\n' < "$LAST_TX_FILE"
  else
    echo ""
  fi
}

ensure_batch_file() {
  mkdir -p "$(dirname "$BATCH_FILE")"
  touch "$BATCH_FILE"
}

mine_blocks() {
  local miner_wallet="${1:-$MINER_WALLET}"
  local blocks="${2:-$DEFAULT_MINE_BLOCKS}"
  [[ -z "${blocks}" ]] && blocks=1
  local addr
  addr="$(wcli "$miner_wallet" getnewaddress)"
  bcli generatetoaddress "$blocks" "$addr" >/dev/null
  local h
  h="$(bcli getblockcount)"
  say "Mined $blocks block(s). height=$h"
}

wallet_ready() {
  local w="$1"
  # listwallets returns JSON array
  bcli listwallets | python3 -c 'import sys,json; w=sys.argv[1]; arr=json.load(sys.stdin); print("yes" if w in arr else "no")' "" W="$w"
}

load_wallet_if_needed() {
  local w="$1"
  if [[ "$(wallet_ready "$w")" == "yes" ]]; then
    return 0
  fi
  # try load, else create then load
  if ! bcli loadwallet "$w" >/dev/null 2>&1; then
    bcli createwallet "$w" >/dev/null
  fi
}

# -------------------------
# Commands
# -------------------------
cmd_version() { say "$VERSION"; }

cmd_init() {
  # Load/create wallets idempotently (works even if wallet DB already exists)
  for w in "" ""; do
    # If already loaded, skip
    if bcli listwallets | python3 -c 'import sys,json; w=sys.argv[1]; arr=json.load(sys.stdin); print("yes" if w in arr else "no")' "" | grep -qx yes; then
      continue
    fi

    # If exists on disk, load it; otherwise create it
    if bcli listwalletdir | python3 -c 'import sys,json; w=sys.argv[1]; d=json.load(sys.stdin); names=[x.get("name","") for x in d.get("wallets",[])]; print("yes" if w in names else "no")' "" | grep -qx yes; then
      bcli loadwallet "" >/dev/null 2>&1 || die "Could not load wallet: "
    else
      bcli createwallet "" >/dev/null 2>&1 || die "Could not create wallet: "
    fi
  done

  say "OK: wallets ready (, )"
}

cmd_status() {
  say "---- status ----"
  local height mempool_size last
  height="$(bcli getblockcount 2>/dev/null || echo "?")"
  # robust: size comes from getmempoolinfo JSON
  mempool_size="$(bcli getmempoolinfo | python3 -c 'import sys,json; o=json.load(sys.stdin); print(o.get("size","?"))' 2>/dev/null || echo "?")"
  last="$(read_last_txid)"
  [[ -n "$last" ]] || last="(none yet)"
  say "chain height: $height"
  say "mempool size: $mempool_size"
  say "last txid: $last"
  echo
  cmd_balances
  echo "------------------"
}

cmd_balances() {
  say "---- balances ----"
  say "$W1:"
  wcli "$W1" getbalances 2>/dev/null | print_json || true
  echo
  say "$W2:"
  wcli "$W2" getbalances 2>/dev/null | print_json || true
  echo "------------------"
}

cmd_mempool() {
  say "---- mempool ----"
  bcli getmempoolinfo 2>/dev/null | print_json || true
  echo
  say "txids:"
  bcli getrawmempool 2>/dev/null | print_json || true
  say "-----------------"
}

cmd_mine() {
  local mw="${1:-$MINER_WALLET}"
  local blocks="${2:-$DEFAULT_MINE_BLOCKS}"
  mine_blocks "$mw" "$blocks"
}

cmd_pay() {
  local amount="${1:-}"
  [[ -n "$amount" ]] || die "Usage: pay AMOUNT [--no-mine]"
  shift || true

  local no_mine=0
  if [[ "${1:-}" == "--no-mine" ]]; then
    no_mine=1
  fi

  # recipient: new address from W2
  local addr
  addr="$(wcli "$W2" getnewaddress)"

  # sendtoaddress supports amount directly
  local txid
  txid="$(wcli "$W1" sendtoaddress "$addr" "$amount")"
  write_last_txid "$txid"
  say "TXID=$txid"

  if [[ "$no_mine" -eq 1 ]]; then
    say "Not mining (tx left in mempool)"
  else
    mine_blocks "$MINER_WALLET" "$DEFAULT_MINE_BLOCKS"
    cmd_confirm "$txid"
  fi
}

cmd_pay_many() {
  local no_mine=0
  if [[ "${1:-}" == "--no-mine" ]]; then
    no_mine=1
    shift || true
  fi
  [[ $# -ge 1 ]] || die "Usage: pay-many [--no-mine] AMT1 [AMT2 ...]"

  ensure_batch_file
  # build recipients file and JSON map safely
  local tmp
  tmp="$(mktemp)"
  trap '[[ -n "${tmp-}" ]] && rm -f "$tmp"' RETURN

  local a addr
  for a in "$@"; do
    [[ -n "$a" ]] || continue
    # normalize integer -> float string
    if [[ "$a" != *.* ]]; then a="${a}.0"; fi
    [[ "$a" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "Invalid amount: $a"
    addr="$(wcli "$W2" getnewaddress)"
    printf "%s %s\n" "$addr" "$a" >> "$tmp"
  done

  local map_json
  map_json="$(python3 -c 'import sys,json; d={}; 
for line in sys.stdin:
  line=line.strip()
  if not line: continue
  addr,amt=line.split()
  d[addr]=float(amt)
print(json.dumps(d, separators=(",",":")))' < "$tmp")"

  # Positional sendmany (works on your build; avoids -named JSON weirdness)
  # sendmany "" <amounts> minconf comment subtractfeefromamount replaceable conf_target
  local txid
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

cmd_confirm() {
  local txid="${1:-}"
  if [[ "$txid" == "last" || -z "$txid" ]]; then
    txid="$(read_last_txid)"
  fi
  [[ -n "$txid" ]] || die "No txid. Use: confirm TXID  OR confirm last"

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
  # if blocks == 0 => don't mine
  if [[ "$blocks" != "0" ]]; then
    mine_blocks "$MINER_WALLET" "$blocks"
  fi
  local last
  last="$(read_last_txid)"
  if [[ -n "$last" ]]; then
    cmd_confirm "$last"
  else
    say "No last txid recorded."
  fi
}

cmd_confirm_mempool() {
  local blocks="${1:-$DEFAULT_MINE_BLOCKS}"

  local txids
  txids="$(bcli getrawmempool 2>/dev/null || echo '[]')"

  say "TXIDs currently in mempool:"
  # print one-per-line; robust if empty
  echo "$txids" | python3 -c 'import sys,json; 
s=sys.stdin.read().strip()
if not s: sys.exit(0)
a=json.loads(s)
for t in a: print("  "+t)'

  echo
  if [[ "$blocks" != "0" ]]; then
    mine_blocks "$MINER_WALLET" "$blocks"
  fi

  echo
  say "---- confirmations after mining ----"
  echo

  echo "$txids" | python3 -c 'import sys,json; a=json.load(sys.stdin); 
print("\n".join(a))' | while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    cmd_confirm "$t"
  done
}

# -------------------------
# Batch mode
# -------------------------
cmd_batch_add() {
  local amount="${1:-}"
  [[ -n "$amount" ]] || die "Usage: batch-add AMOUNT"
  ensure_batch_file
  printf "%s\n" "$amount" >> "$BATCH_FILE"
  say "Added: $amount"
}

cmd_batch_show() {
  ensure_batch_file
  say "---- batch ----"
  if [[ -s "$BATCH_FILE" ]]; then
    nl -ba "$BATCH_FILE"
  else
    say "(empty)"
  fi
  say "--------------"
}

cmd_batch_status() {
  ensure_batch_file
  say "---- batch-status ----"
  local count total
  count="$(wc -l < "$BATCH_FILE" | tr -d ' ')"
  total="$(awk '{s+=$1} END {printf "%.8f", s+0}' "$BATCH_FILE" 2>/dev/null || echo "0.00000000")"
  say "count: $count"
  say "total: $total"
  say "file:  $BATCH_FILE"
  say "----------------------"
}

cmd_batch_clear() {
  ensure_batch_file
  : > "$BATCH_FILE"
  say "Batch cleared."
}

cmd_batch_send() {
  local no_mine=0
  if [[ "${1:-}" == "--no-mine" ]]; then
    no_mine=1
    shift || true
  fi

  ensure_batch_file
  [[ -s "$BATCH_FILE" ]] || die "No recipients (batch is empty). Use: batch-add AMOUNT"

  # Build recipients file + JSON map safely
  local tmp
  tmp="$(mktemp)"
  trap '[[ -n "${tmp-}" ]] && rm -f "$tmp"' RETURN

  local a addr
  while IFS= read -r a; do
    a="$(echo "$a" | tr -d ' \t\r\n')"
    [[ -z "$a" ]] && continue
    if [[ "$a" != *.* ]]; then a="${a}.0"; fi
    [[ "$a" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "Invalid amount in batch file: $a"
    addr="$(wcli "$W2" getnewaddress)"
    printf "%s %s\n" "$addr" "$a" >> "$tmp"
  done < "$BATCH_FILE"

  local map_json
  map_json="$(python3 -c 'import sys,json; d={}; 
for line in sys.stdin:
  line=line.strip()
  if not line: continue
  addr,amt=line.split()
  d[addr]=float(amt)
print(json.dumps(d, separators=(",",":")))' < "$tmp")"

  # Positional sendmany (works on your build)
  local txid
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

# -------------------------
# Usage / Main
# -------------------------
usage() {
  cat <<'EOU'
Usage: ./aurum_flow.sh <command> [args]

Commands:
  version
  init
  status
  balances
  mempool
  mine [MINER_WALLET] [BLOCKS]
  pay AMOUNT [--no-mine]
  pay-many [--no-mine] AMT1 [AMT2 ...]
  confirm TXID
  confirm last
  confirm-all [BLOCKS]        (mines BLOCKS unless 0)
  confirm-mempool [BLOCKS]    (mines BLOCKS unless 0)

Batch mode:
  batch-add AMOUNT
  batch-show
  batch-status
  batch-clear
  batch-send [--no-mine]

Env overrides:
  DATA_DIR, CLI, W1, W2, MINER_WALLET, DEFAULT_MINE_BLOCKS
EOU
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    version)         cmd_version ;;
    init)            cmd_init "$@" ;;
    status)          cmd_status "$@" ;;
    balances)        cmd_balances "$@" ;;
    mempool)         cmd_mempool "$@" ;;
    mine)            cmd_mine "$@" ;;
    pay)             cmd_pay "$@" ;;
    pay-many)        cmd_pay_many "$@" ;;
    confirm)         cmd_confirm "$@" ;;
    confirm-all)     cmd_confirm_all "$@" ;;
    confirm-mempool) cmd_confirm_mempool "$@" ;;
    batch-add)       cmd_batch_add "$@" ;;
    batch-show)      cmd_batch_show "$@" ;;
    batch-status)    cmd_batch_status "$@" ;;
    batch-clear)     cmd_batch_clear "$@" ;;
    batch-send)      cmd_batch_send "$@" ;;
    ""|help|-h|--help) usage ;;
    *) die "Unknown command: $cmd (try: $0 help)" ;;
  esac
}

main "$@"
