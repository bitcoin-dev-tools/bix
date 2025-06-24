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

      # Alias gcc/g++ to clang/clang++
      clangShim = pkgs.stdenv.mkDerivation {
        name = "clang-shim";
        buildInputs = [llvmTools.clang];
        phases = ["installPhase"];
        installPhase = ''
          mkdir -p $out/bin
          ln -s ${llvmTools.clang}/bin/clang $out/bin/gcc
          ln -s ${llvmTools.clang}/bin/clang++ $out/bin/g++
          ln -s ${llvmTools.clang}/bin/clang $out/bin/clang
          ln -s ${llvmTools.clang}/bin/clang++ $out/bin/clang++
        '';
      };

      # Will only exist in the build environment and includes everything needed
      # for a depends build
      dependsNativeBuildInputs = with pkgs;
        [
          bison
          ccache
          cmake
          curlMinimal
          llvmTools.bintools
          llvmTools.clang-tools
          clangShim
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
        depends = pkgs.mkShellNoCC {
          nativeBuildInputs = dependsNativeBuildInputs;
          buildInputs = usdtPkgs;
          shellHook = ''
            # having SOURCE_DATE_EPOCH set can interfere with the guix
            # build system, so we unset this in the depends devshell
            unset SOURCE_DATE_EPOCH

            echo "gcc/g++ are shimmed to llvm tools"
          '';
          inherit (env) CMAKE_GENERATOR LOCALE_ARCHIVE;
        };
      };

      formatter = pkgs.alejandra;
    });
}
