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
        binDirs = [ "./build/bin" "./build/bin/qt" ];
        isLinux = pkgs.stdenv.isLinux;
        lib = pkgs.lib;
        pkgs = import nixpkgs { inherit system; };
        pkgs-lief = import nixpkgs-lief { inherit system; };

        # Common dependencies
        commonNativeBuildInputs = with pkgs; [
          byacc
          ccache
          clang-tools_19
          clang_19
          cmake
          gcc14 # Match this to LD_LIBRARY_PATH for the devShell
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

        pythonWithLief = pkgs.python311.override {
          packageOverrides = self: super: {
            lief = pkgs-lief.python311Packages.lief;
          };
        };

        # Runtime dependencies
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

        shellHook = ''
          # Add build dirs to PATH
          export PATH=$PATH:${builtins.concatStringsSep ":" binDirs}

          export CC=clang
          export CXX=clang++
          export CMAKE_GENERATOR=Ninja
          export LDFLAGS="-fuse-ld=mold"

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
          LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.gcc14.cc pkgs.capnproto ];
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          inherit nativeBuildInputs buildInputs shellHook;
        };
      }
    );
}
