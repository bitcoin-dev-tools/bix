# Bix - Bitcoin Development Environment

## Overview

This flake is designed primarily as `devShell`s rather than for building a specific derivation. It provides:

- `gcc` (the default shell): GCC, Qt, and nixpkgs dependencies
- `clang`: Clang with non-Qt nixpkgs dependencies
- `depends`: build tools only; dependencies are built by Bitcoin Core's depends system
- Cross-platform support (Linux and MacOS)

## Features

### Build System

The GCC shell uses a slightly opinionated build system:

- CMake + Ninja - Fast, parallel builds
- GCC and mold on Linux
- ccache

### Dependencies

The nixpkgs-backed shells provide Bitcoin Core dependencies such as:
- Boost
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
# or explicitly:
nix develop .#gcc
nix develop .#clang
nix develop .#depends
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
| MacOS    | aarch64      | ✅    | ❌      |

## Environment Variables

The shell automatically sets:
- `CMAKE_GENERATOR=Ninja` - Use Ninja build system
- `LD_LIBRARY_PATH` - Includes Cap'n Proto libraries
- `LOCALE_ARCHIVE` - Proper locale support (Linux)
- `QT_PLUGIN_PATH` - Qt plugin location in the GCC shell

## Requirements

- Nix with flakes enabled

## Contributing

This flake uses nixpkgs stable (25.05) for reproducible builds. Format code with:
```bash
nix fmt .
```
