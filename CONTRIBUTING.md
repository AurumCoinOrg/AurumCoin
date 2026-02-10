# Contributing to Aurum

Thanks for your interest in contributing.

## Ground rules
- Consensus parameters listed in docs/SPEC_LOCK.md are frozen and must not be changed without a hard-fork proposal.
- No local data directories, wallets, logs, or backups in commits.
- No consensus changes without an explicit proposal and review.
- If docs conflict with code, code wins.

## Development workflow
1. Fork and create a branch.
2. Build + run tests.
3. Run the spec verifier:
   - `bash scripts/verify_spec.sh`
4. Open a PR with a clear description and rationale.

## Style
- Keep changes minimal and focused.
- Prefer existing project conventions.

## Before you open a PR
- Run: `bash scripts/verify_spec.sh`
- Read: `docs/README.md`
- For security issues: see `SECURITY.md`
- For help: see `SUPPORT.md`
