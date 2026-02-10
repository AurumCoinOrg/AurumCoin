# Build (macOS / Linux)

## Requirements
- CMake
- Clang or GCC
- Boost
- (Optional) Qt if building GUI

## Configure + Build
cmake -S . -B build
cmake --build build -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"

## Binaries
build/bin/aurumd
build/bin/aurum-cli
