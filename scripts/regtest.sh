#!/usr/bin/env bash
set -euo pipefail

DATADIR="${DATADIR:-/tmp/aurum-regtest}"
CONF="$DATADIR/bitcoin.conf"
RPCUSER="${RPCUSER:-aurumrpc}"
RPCPASS="${RPCPASS:-aurumrpcpass}"
WALLET="${WALLET:-aurum}"

AURUMD="./build/bin/aurumd"
CLI="./build/bin/aurum-cli"

stop() {
  $CLI -regtest -datadir="$DATADIR" -rpcuser="$RPCUSER" -rpcpassword="$RPCPASS" stop 2>/dev/null || true
  pkill -f "aurumd.*$(basename "$DATADIR")" 2>/dev/null || true
  pkill -f "aurumd" 2>/dev/null || true
}

reset() {
  stop
  sudo rm -rf "$DATADIR"
  mkdir -p "$DATADIR"
  chmod 700 "$DATADIR"

  cat > "$CONF" <<CONF
server=1
daemon=1

[regtest]
rpcuser=$RPCUSER
rpcpassword=$RPCPASS
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
fallbackfee=0.0001
txindex=1
CONF
}

start() {
  $AURUMD -regtest -datadir="$DATADIR"
}

cli() {
  $CLI -regtest -datadir="$DATADIR" -rpcuser="$RPCUSER" -rpcpassword="$RPCPASS" "$@"
}

ensure_wallet() {
  cli listwallets | grep -q "\"$WALLET\"" && return 0
  cli createwallet "$WALLET" >/dev/null
}

mine101() {
  ensure_wallet
  local addr
  addr="$(cli -rpcwallet="$WALLET" getnewaddress)"
  cli generatetoaddress 101 "$addr" >/dev/null
  cli -rpcwallet="$WALLET" getbalance
}

case "${1:-}" in
  reset) reset ;;
  start) start ;;
  stop)  stop ;;
  status) cli getblockchaininfo | egrep '"chain"|"blocks"|bestblockhash' ;;
  mine101) mine101 ;;
  *) echo "usage: $0 {reset|start|stop|status|mine101}" ; exit 1 ;;
esac
