#!/usr/bin/env bash
set -euo pipefail

CORES=${1:?usage: build-systemlibs.sh <cores> [cmake_flags...]}
shift
CMAKE_FLAGS=("$@")

cd bitcoin
cmake -B build \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    --preset dev-mode \
    -DBUILD_GUI=OFF \
    "${CMAKE_FLAGS[@]}"
cmake --build build "-j$CORES"
ccache --show-stats
