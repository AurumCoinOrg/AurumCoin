# Hard Fork Policy (Aurum)

Aurum mainnet consensus is **frozen** (see `docs/SPEC_LOCK.md`).

## What counts as a hard fork?
Any change that alters consensus validation rules, including (non-exhaustive):
- Genesis / chainparams that change the network identity
- Proof-of-work rules or difficulty adjustment behavior
- Block/tx validity rules
- Monetary policy (subsidy, halving interval, MAX_MONEY)
- Script or consensus flags affecting what is valid

## Process
1. Open an RFC issue: **[RFC] Hard fork: <title>**
2. Include:
   - Motivation + risks
   - Exact parameter changes
   - Activation method + timeline
   - Compatibility and replay protection strategy (if needed)
3. Implement behind a clearly named commit/branch.
4. Require review + explicit maintainer approval.
5. Tag a release and publish upgrade notes.

## Default stance
Hard forks are **rare** and require strong justification.
