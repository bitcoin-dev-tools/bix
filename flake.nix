{
  description = "Bitcoin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      binDirs = [ "./build/bin" "./build/bin/qt" ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # Build-time tools
        nativeBuildInputs = with pkgs; [
          byacc
          ccache
          clang-tools_19
          clang_19
          cmake
          gcc14
          gdb
          hexdump
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
          llvmPackages.bintools
          ninja
          pkg-config
          python312
          python312Packages.autopep8
          python312Packages.flake8
          python312Packages.mypy
          python312Packages.pyzmq
          python312Packages.requests
        ];

        # Runtime dependencies
        buildInputs = with pkgs; [
          boost
          libevent
          sqlite
          capnproto
          db4
          qrencode
          zeromq
          qt6.qtbase
          qt6.qttools
        ];

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

          # Misc bitcoin options
          export LSAN_OPTIONS="suppressions=$(pwd)/test/sanitizer_suppressions/lsan"
          export TSAN_OPTIONS="suppressions=$(pwd)/test/sanitizer_suppressions/tsan:halt_on_error=1:second_deadlock_stack=1"
          export UBSAN_OPTIONS="suppressions=$(pwd)/test/sanitizer_suppressions/ubsan:print_stacktrace=1:halt_on_error=1:report_error_type=1"

          # Add output build dir to $PATH
          export PATH=$PATH:${builtins.concatStringsSep ":" binDirs}
        '';
      };
    };
}
