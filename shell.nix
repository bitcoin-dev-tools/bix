let
  pkgs = import <nixpkgs> { system = "x86_64-linux"; };

  # Pinned for lief @ v0.13.2
  liefPkgs = import (builtins.fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    ref = "refs/heads/nixos-24.11";
    rev = "05bbf675397d5366259409139039af8077d695ce";
    shallow = true;
  }) { system = "x86_64-linux"; };

  binDirs = [ "./build/bin" "./build/bin/qt" ];
  lib = pkgs.lib;
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    # build tools
    boost
    ccache
    clang-tools_19
    clang_19
    cmake
    gcc14
    gnumake
    gnum4
    mold
    ninja
    pkg-config

    # build dependencies
    capnproto
    db4
    libevent
    qrencode
    sqlite
    zeromq

    # Tests
    hexdump

    # Depends
    byacc

    # Functional tests & linting
    python311
    python311Packages.autopep8
    python311Packages.flake8
    python311Packages.mypy
    python311Packages.pyzmq
    python311Packages.requests
    liefPkgs.python311Packages.lief

    # Benchmarking
    python311Packages.pyperf

    # Debugging
    gdb

    # Tracing
    libsystemtap
    linuxPackages.bcc
    linuxPackages.bpftrace

    # Bitcoin-qt
    qt6.qtbase
    qt6.qttools
  ];

  # Set locale to the system locale
  LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";

  shellHook = ''
    BCC_EGG=${pkgs.linuxPackages.bcc}/${pkgs.python3.sitePackages}/bcc-${pkgs.linuxPackages.bcc.version}-py3.${pkgs.python3.sourceVersion.minor}.egg
    if [ -f $BCC_EGG ]; then
      export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
    else
      echo "The bcc egg $BCC_EGG does not exist. Maybe the python or bcc version is different?"
    fi

    # Use clang by default
    export CC=clang
    export CXX=clang++

    # Use Ninja generator 🥷
    export CMAKE_GENERATOR="Ninja"

    # Use mold linker 🦠
    export LDFLAGS="-fuse-ld=mold"

    # Misc bitcoin options
    export LSAN_OPTIONS="suppressions=$(pwd)/test/sanitizer_suppressions/lsan"
    export TSAN_OPTIONS="suppressions=$(pwd)/test/sanitizer_suppressions/tsan:halt_on_error=1:second_deadlock_stack=1"
    export UBSAN_OPTIONS="suppressions=$(pwd)/test/sanitizer_suppressions/ubsan:print_stacktrace=1:halt_on_error=1:report_error_type=1"

    # Add output build dir to $PATH
    export PATH=$PATH:${builtins.concatStringsSep ":" binDirs}
  '';
}
