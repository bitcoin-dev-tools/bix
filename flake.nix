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

      # Will only exist in the build environment
      nativeBuildInputs = with pkgs;
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
        ++ platformPkgs isLinux [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
        ];

      # Will exist in the runtime environment
      buildInputs = with pkgs;
        [
          boost
          capnproto
          libevent
          qrencode
          sqlite.dev
          zeromq
        ]
        ++ platformPkgs isLinux [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
        ];

      env = {
        CMAKE_GENERATOR = "Ninja";
        LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.capnproto];
        LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
      };
    in {
      # We use mkShelNoCC to avoid having Nix set up a gcc-based build environment
      devShells.default = pkgs.mkShellNoCC {
        inherit nativeBuildInputs buildInputs;
        packages =
          [
            pythonEnv
            pkgs.codespell
            pkgs.hexdump
          ]
          ++ platformPkgs isLinux [pkgs.gdb]
          ++ platformPkgs isDarwin [llvmTools.lldb];

        shellHook = ''
          # This can likely be removed if https://github.com/bitcoin/bitcoin/pull/32678 is merged
          unset SOURCE_DATE_EPOCH
        '';
        inherit (env) CMAKE_GENERATOR LD_LIBRARY_PATH LOCALE_ARCHIVE;
      };

      formatter = pkgs.alejandra;
    });
}
