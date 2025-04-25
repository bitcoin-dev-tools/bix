let
  pkgs = import <nixpkgs> { system = "x86_64-linux"; };
  inherit (pkgs) lib;

  # Pinned for lief @ v0.13.2
  liefPkgs = import (builtins.fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    ref = "refs/heads/nixos-24.11";
    rev = "05bbf675397d5366259409139039af8077d695ce";
    shallow = true;
  }) { system = "x86_64-linux"; };

  binDirs = [ "./build/bin" "./build/bin/qt" ];
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    # build tools
    binutils
    ccache
    clang-tools_19
    clang_19
    cmake
    curlMinimal
    gcc14
    gnum4
    gnumake
    lld_19
    mold-wrapped
    ninja
    pkg-config
    which
    ];

    buildInputs = with pkgs; [
    # build dependencies
    boost
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

    doxygen

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

  CC = "clang";
  CMAKE_GENERATOR="Ninja";
  CXX = "clang++";
  LDFLAGS = "-fuse-ld=lld";
  LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc pkgs.capnproto ];
  LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";

  shellHook = ''
    BCC_EGG=${pkgs.linuxPackages.bcc}/${pkgs.python3.sitePackages}/bcc-${pkgs.linuxPackages.bcc.version}-py3.${pkgs.python3.sourceVersion.minor}.egg
    if [ -f $BCC_EGG ]; then
      export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
    else
      echo "The bcc egg $BCC_EGG does not exist. Maybe the python or bcc version is different?"
    fi

    # Add output build dir to $PATH
    export PATH=${builtins.concatStringsSep ":" binDirs}:$PATH
  '';
}
