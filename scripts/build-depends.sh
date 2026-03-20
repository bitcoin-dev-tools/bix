#!/usr/bin/env bash
set -euo pipefail

cd bitcoin

# Nix sets CC/CXX to bare names (e.g. 'clang'), relying on PATH. The depends
# Makefile substitutes these into toolchain.cmake, but cmake's find_program
# searches system dirs before PATH, so a bare 'clang' resolves to the system
# compiler instead of the Nix one. This causes glibc version mismatches:
# objects compiled against Nix's newer glibc headers reference fortified
# symbols (e.g. __inet_pton_chk) absent from the runner's older glibc.
NIX_CC=$(command -v "$CC")
NIX_CXX=$(command -v "$CXX")

HOST_TRIPLET=$(./depends/config.guess)

make -C depends "-j$(nproc)" NO_QT=1 \
    CC="$NIX_CC" CXX="$NIX_CXX" \
    build_CC="$NIX_CC" build_CXX="$NIX_CXX"

cmake -B build --toolchain "depends/$HOST_TRIPLET/toolchain.cmake"
cmake --build build "-j$(nproc)"
ccache --show-stats
