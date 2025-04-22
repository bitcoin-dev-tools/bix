{
  description = "Bitcoin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11";
    nixpkgs-lief.url = "github:NixOS/nixpkgs?rev=50dc918cfe0dd0419403c957bcf395e881214416"; # Pinned commit for lief 0.13.2
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, nixpkgs-lief, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgs-lief = import nixpkgs-lief { inherit system; }; # Pinned Nixpkgs for lief
        isLinux = pkgs.stdenv.isLinux;
        binDirs = [ "./build/bin" "./build/bin/qt" ];

        # Common dependencies for both platforms
        commonNativeBuildInputs = with pkgs; [
          byacc
          ccache
          clang-tools_19
          clang_19
          cmake
          gnumake
          gnum4
          mold-wrapped
          ninja
          pkg-config
        ];

        # Linux-specific dependencies
        linuxNativeBuildInputs = with pkgs; [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
        ];

        # Combine dependencies based on platform
        nativeBuildInputs = commonNativeBuildInputs ++ (if isLinux then linuxNativeBuildInputs else []);

        # Override python311Packages.lief to use the pinned version
        pythonWithLief = pkgs.python311.override {
          packageOverrides = self: super: {
            lief = pkgs-lief.python311Packages.lief;
          };
        };

        # Common runtime dependencies
        buildInputs = with pkgs; [
          boost
          capnproto
          codespell
          db4
          gdb
          hexdump
          libevent
          python311Packages.flake8
          python311Packages.mypy
          python311Packages.pyzmq
          python311Packages.vulture
          pythonWithLief
          qrencode
          qt6.qtbase
          qt6.qttools
          sqlite
          uv
          zeromq
        ];

        # Platform-specific shell hook
        shellHook = ''
          # Use clang as default
          export CC=clang
          export CXX=clang++

          # Use Ninja generator 🥷
          export CMAKE_GENERATOR="Ninja"

          # Use mold linker 🦠
          export LDFLAGS="-fuse-ld=mold"

          # Add build dirs to PATH
          export PATH=$PATH:${builtins.concatStringsSep ":" binDirs}

          ${if isLinux then ''
            # Linux-specific settings
            BCC_EGG=${pkgs.linuxPackages.bcc}/${pkgs.python3.sitePackages}/bcc-${pkgs.linuxPackages.bcc.version}-py3.${pkgs.python3.sourceVersion.minor}.egg
            if [ -f $BCC_EGG ]; then
              export PYTHONPATH="$PYTHONPATH:$BCC_EGG"
            else
              echo "Warning: The bcc egg $BCC_EGG does not exist. Skipping bcc PYTHONPATH setup."
            fi
          '' else ''
          ''}
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          inherit nativeBuildInputs buildInputs shellHook;
        };
      }
    );
}
