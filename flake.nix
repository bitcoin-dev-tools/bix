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
      llvmVersion = "20";
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

      # Dependencies
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
          python3
          xz
        ]
        ++ platformPkgs isLinux [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
        ];

      buildInputs = with pkgs;
        [
          boost
          capnproto
          db4
          libevent
          qrencode
          sqlite.dev
          zeromq
        ]
        ++ platformPkgs isLinux [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
          python312Packages.bcc
        ];

      env = {
        CMAKE_GENERATOR = "Ninja";
        LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.capnproto];
        LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
      };
    in {
      devShells.default = (pkgs.mkShellNoCC) {
        nativeBuildInputs = nativeBuildInputs;
        buildInputs = buildInputs;
        packages = with pkgs;
          [
            codespell
            hexdump
            python312
            python312Packages.flake8
            python312Packages.lief
            python312Packages.mypy
            python312Packages.pyzmq
            python312Packages.vulture
          ]
          ++ platformPkgs isLinux [gdb]
          ++ platformPkgs isDarwin [llvmTools.lldb];
        shellHook = ''
          unset SOURCE_DATE_EPOCH
        '';

        inherit (env) CMAKE_GENERATOR LD_LIBRARY_PATH LOCALE_ARCHIVE;
      };

      formatter = pkgs.alejandra;
    });
}
