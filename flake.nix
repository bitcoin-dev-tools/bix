{
  description = "Bitcoin development environment with tools for building, testing, and debugging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      isLinux = pkgs.stdenv.isLinux;
      isDarwin = pkgs.stdenv.isDarwin;
      lib = pkgs.lib;

      # Configure LLVM and python version for the environment
      llvmVersion = "20";
      pythonVersion = "13";

      llvmPackages = pkgs."llvmPackages_${llvmVersion}";
      llvmTools = {
        inherit (llvmPackages) bintools clang clang-tools;
        lldb = pkgs."lldb_${llvmVersion}";
      };

      # Helper for platform-specific packages
      platformPkgs = cond: pkgs:
        if cond
        then pkgs
        else [];

      # Use a single pythonEnv throughout and specifically in the devShell to make sure bcc is available.
      pythonEnv = pkgs."python3${pythonVersion}".withPackages (ps:
        with ps;
          [
            flake8
            lief
            mypy
            pyzmq
            vulture
          ]
          ++ platformPkgs isLinux [
            bcc
          ]);

      # USDT is only supported on linux
      usdtPkgs = with pkgs;
        platformPkgs isLinux [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
        ];

      # Will only exist in the build environment and includes everything needed
      # for a depends build
      dependsNativeBuildInputs = with pkgs;
        [
          bison
          ccache
          cmake
          curlMinimal
          llvmTools.bintools
          llvmTools.clang
          llvmTools.clang-tools
          ninja
          pkg-config
          xz
        ]
        ++ usdtPkgs;
      nativeBuildInputs = with pkgs;
        dependsNativeBuildInputs
        ++ [
          qt6.wrapQtAppsHook # https://nixos.org/manual/nixpkgs/stable/#sec-language-qt
        ];

      # Will exist in the runtime environment - not needed for a depends build
      buildInputs = with pkgs;
        [
          boost
          capnproto
          libevent
          qrencode
          qt6.qtbase # https://nixos.org/manual/nixpkgs/stable/#sec-language-qt
          qt6.qttools
          sqlite.dev
          zeromq
        ]
        ++ usdtPkgs;

      env = {
        CMAKE_GENERATOR = "Ninja";
        LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.capnproto];
        LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
      };
    in {
      # We use mkShelNoCC to avoid having Nix set up a gcc-based build environment
      devShells = {
        default = pkgs.mkShellNoCC {
          inherit nativeBuildInputs buildInputs;
          packages =
            [
              pythonEnv
              pkgs.codespell
              pkgs.hexdump
            ]
            ++ platformPkgs isLinux [pkgs.gdb]
            ++ platformPkgs isDarwin [llvmTools.lldb];

          inherit (env) CMAKE_GENERATOR LD_LIBRARY_PATH LOCALE_ARCHIVE;
        };
        # TODO: this could be ported to a gcc shell in the future to bring this closer in line
        # with our guix depends build. This would allow us to remove the shellHook hack that shims
        # in clang to masquerade as gcc
        depends = pkgs.mkShellNoCC {
          nativeBuildInputs = dependsNativeBuildInputs;
          buildInputs = usdtPkgs;
          shellHook = ''
            # having SOURCE_DATE_EPOCH set can interfere with the guix
            # build system, so we unset this in the depends devshell
            unset SOURCE_DATE_EPOCH

            # its not super easy to override compiler defaults in
            # depends, so as a hack we just shim in clang and pretend
            # its gcc. this is done in a tmp dir to avoid polluting the
            # users shell and is cleaned up when the shell is exited.
            TMP_GCC_SHIM=$(mktemp -d "$TMPDIR/clang-shim.XXXXXX")

            ln -sf $(command -v clang++) "$TMP_GCC_SHIM/g++"
            ln -sf $(command -v clang) "$TMP_GCC_SHIM/gcc"

            export PATH="$TMP_GCC_SHIM:$PATH"
            echo "Using fake gcc/g++ -> clang in: $TMP_GCC_SHIM"

            trap "rm -rf $TMP_GCC_SHIM" EXIT
          '';
          inherit (env) CMAKE_GENERATOR LOCALE_ARCHIVE;
        };
      };

      formatter = pkgs.alejandra;
    });
}
