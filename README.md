# Aurum

Aurum is an independent Layer-1 Proof-of-Work blockchain.

## Core Principles
- Fair launch (no pre-allocation)
- No team allocation
- No ICO
- No hidden allocations

Aurum is designed to be simple, auditable, and fair from genesis.

## Consensus
- Proof-of-Work (SHA256d)

## Status
- Genesis: locked
- Mainnet: live (bootstrap phase)
- Testnet: pending public release

## Build

### Requirements
- macOS / Linux
- CMake
- Clang or GCC
- Boost

### Build
```bash
cmake -S . -B build
cmake --build build -j$(sysctl -n hw.ncpu)
