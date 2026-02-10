# Build (macOS / Linux)

## Requirements
- CMake
- Clang or GCC
- Boost

## Build
```bash
cmake -S . -B build
cmake --build build -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
