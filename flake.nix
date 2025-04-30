{
  description = "Bitcoin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
      let
        binDirs = [ "./build/bin" "./build/bin/qt" ];
        isLinux = pkgs.stdenv.isLinux;
        lib = pkgs.lib;
        pkgs = import nixpkgs { inherit system; };

        # Common dependencies
        commonNativeBuildInputs = with pkgs; [
          byacc
          ccache
          clang-tools_19
          clang_19
          cmake
          gcc14
          gnumake
          gnum4
          mold-wrapped
          ninja
          pkg-config
        ];

        linuxNativeBuildInputs = with pkgs; [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
        ];

        nativeBuildInputs = commonNativeBuildInputs ++ (if isLinux then linuxNativeBuildInputs else []);

        # Runtime dependencies
        buildInputs = with pkgs; [
          boost
          capnproto
          codespell
          db4
          gdb
          hexdump
          libevent
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
          python312Packages.bcc
          python312Packages.flake8
          python312Packages.lief
          python312Packages.mypy
          python312Packages.pyzmq
          python312Packages.vulture
          qrencode
          qt6.qtbase
          qt6.qttools
          sqlite
          uv
          valgrind
          zeromq
        ];

        shellHook = ''
          # Add build dirs to PATH
          export PATH=$PATH:${builtins.concatStringsSep ":" binDirs}

          # Opinionated default compiler, linker, and Generator options
          export CC=gcc
          export CXX=g++
          export LDFLAGS="-fuse-ld=mold"
          export CMAKE_GENERATOR=Ninja

          # Add bcc egg to PYTHONPATH
          BCC_EGG=${pkgs.linuxPackages.bcc}/${pkgs.python312.sitePackages}/bcc-${pkgs.linuxPackages.bcc.version}-py3.12.egg
          if [ -f $BCC_EGG ]; then
            export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
          else
            echo "Warning: The bcc egg $BCC_EGG does not exist. Skipping bcc PYTHONPATH setup."
          fi
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.gcc14.cc pkgs.capnproto ];
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          inherit nativeBuildInputs buildInputs shellHook;
        };
      }
    );
}
