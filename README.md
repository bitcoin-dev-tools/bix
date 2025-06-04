# Bix - Bitcoin Development Environment

## Overview

This flake is designed primarily as a `devShell` rather than for building a specific derivation. It provides:

- All dependencies from nixpkgs needed to build all Bitcoin Core modules
- Modern LLVM toolchain
- Cross-platform support (Linux and MacOS x64 + aarch64)

## Features

### Build System

We use a slightly opinionated Clang/LLVM-based build system:

- CMake + Ninja - Fast, parallel builds
- LLVM/Clang 20 toolchain
- ccache

### Dependencies

All Bitcoin Core dependencies from nixpkgs:
- Boost
- libevent
- SQLite
- ZeroMQ
- Cap'n Proto
- QR code generation

### Development Tools

- Debugging: GDB (Linux) / LLDB (macOS)
- Tracing: SystemTap, BCC, bpftrace (Linux)
- Linting: flake8, mypy, vulture, codespell
- Misc: `clang-format`, `clang-tidy` and friends

### Build Capabilities

- All Bitcoin Core modules from nixpkgs dependencies (Linux)
  - On MacOS the USDT component is not possible to build
- All modules **excluding QT** using depends

## Usage

### Enter Development Shell

```bash
nix develop
```

### Build Bitcoin Core

Once in the development shell, you can build Bitcoin Core using either approach:

#### Using nixpkgs dependencies

```bash
cmake -B build
# On Linux build all modules with:
# cmake -B build --preset dev-mode
cmake --build build -j$(nproc)
```

#### Using depends system (excludes GUI)

```bash
TRIPLET=$(./depends/config.guess)
make -C depends -j$(nproc) NO_QT=1
cmake -B build --toolchain depends/"$TRIPLET"/toolchain.cmake
cmake --build build -j$(nproc)
```

## Quick Test with Docker

To quickly test the development environment using Docker:

```bash
docker run --pull=always -it nixos/nix
git clone --depth=1 https://github.com/bitcoin/bitcoin && cd bitcoin
nix develop github:bitcoin-dev-tools/bix --extra-experimental-features flakes --extra-experimental-features nix-command --no-write-lock-file
cmake -B build
cmake --build build -j$(nproc)
```

## Platform Support

| Platform | Architecture | Build | Tracing |
|----------|--------------|-------|---------|
| Linux    | x86_64       | ✅    | ✅      |
| Linux    | aarch64      | ✅    | ✅      |
| MacOS    | x86_64       | ✅    | ❌      |
| MacOS    | aarch64      | ✅    | ❌      |

## Environment Variables

The shell automatically sets:
- `CMAKE_GENERATOR=Ninja` - Use Ninja build system
- `LD_LIBRARY_PATH` - Includes Cap'n Proto libraries
- `LOCALE_ARCHIVE` - Proper locale support (Linux)

## Requirements

- Nix with flakes enabled

## Contributing

This flake uses nixpkgs stable (25.05) for reproducible builds. Format code with:
```bash
nix fmt .
```
