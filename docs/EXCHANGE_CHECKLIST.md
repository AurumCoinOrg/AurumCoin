# Exchange / Integrator Checklist

## Canonical Chain Spec
- See: `docs/CHAIN_SPEC.md`

## Required Verifications
1) Verify genesis
```bash
DATADIR="$HOME/Documents/AurumCoin/main-data-main"
./build/bin/aurum-cli -chain=main -datadir="$DATADIR" getblockhash 0
```

2) Verify consensus matches docs
```bash
bash scripts/verify_spec.sh
```

## Ports
- P2P: 19444
- RPC: 19443 (local only)

## Operational Notes
- Run behind a firewall
- Keep RPC restricted to localhost + auth
- Monitor disk usage, mempool, and peer count
