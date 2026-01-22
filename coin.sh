#!/usr/bin/env bash
set -euo pipefail
source ./regtest-env.sh

cmd="${1-}"
shift || true

case "$cmd" in
  wallets)   $CLI "${RPC[@]}" listwallets ;;
  auruminfo) $CLI "${RPC[@]}" "${AURUM[@]}" getwalletinfo ;;
  bobinfo)   $CLI "${RPC[@]}" "${BOB[@]}" getwalletinfo ;;
  balances)
    echo "AURUM:"; $CLI "${RPC[@]}" "${AURUM[@]}" getbalances
    echo "BOB:";   $CLI "${RPC[@]}" "${BOB[@]}" getbalances
    ;;
  mine)
    n="${1-1}"
    addr="$($CLI "${RPC[@]}" "${AURUM[@]}" getnewaddress)"
    $CLI "${RPC[@]}" generatetoaddress "$n" "$addr"
    ;;
  tx)
    txid="${1:?txid required}"
    $CLI "${RPC[@]}" "${AURUM[@]}" gettransaction "$txid" || true
    $CLI "${RPC[@]}" "${BOB[@]}"   gettransaction "$txid" || true
    ;;
  mempool)
    txid="${1:?txid required}"
    $CLI "${RPC[@]}" getmempoolentry "$txid"
    ;;
  *)
    echo "Usage:"
    echo "  ./coin.sh wallets|auruminfo|bobinfo|balances|mine [n]|tx <txid>|mempool <txid>"
    exit 1
    ;;
esac
