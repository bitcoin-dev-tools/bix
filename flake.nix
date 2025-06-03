{
  description = "Bitcoin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      lib = pkgs.lib;
      llvmVersion = "20";
      llvmPackages = pkgs."llvmPackages_${llvmVersion}";
      isLinux = pkgs.stdenv.isLinux;
      isDarwin = pkgs.stdenv.isDarwin;

      llvmTools = {
        inherit (llvmPackages) bintools clang clang-tools;
        lldb = pkgs."lldb_${llvmVersion}";
      };

      commonPkgs = with pkgs; {
        nativeBuildInputs = [
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
        ];
        buildInputs = [
          boost
          capnproto
          db4
          libevent
          qrencode
          sqlite.dev
          zeromq
        ];
        devTools = [
          codespell
          hexdump
          python312
          python312Packages.flake8
          python312Packages.lief
          python312Packages.mypy
          python312Packages.pyzmq
          python312Packages.vulture
        ];
      };

      linuxPkgs = with pkgs; {
        nativeBuildInputs = [
          libsystemtap
        ];
        buildInputs = [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
          python312Packages.bcc
        ];
        devTools = [gdb];
      };

      darwinPkgs = {
        devTools = [llvmTools.lldb];
      };

      mergePkgs = key:
        lib.flatten [
          commonPkgs.${key}
          (lib.optionals isLinux linuxPkgs.${key})
          (lib.optionals isDarwin darwinPkgs.${key})
        ];

      finalPkgs = {
        nativeBuildInputs = mergePkgs "nativeBuildInputs";
        buildInputs = mergePkgs "buildInputs";
        packages = mergePkgs "devTools";
      };

      env = {
        CMAKE_GENERATOR = "Ninja";
        LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.capnproto];
        LDFLAGS = "-fuse-ld=lld";
        LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
      };
    in {
      devShells.default = pkgs.mkShellNoCC {
        inherit (finalPkgs) nativeBuildInputs buildInputs packages;
        inherit (env) CMAKE_GENERATOR LD_LIBRARY_PATH LDFLAGS LOCALE_ARCHIVE;
        shellHook = "unset SOURCE_DATE_EPOCH";
      };

      formatter = pkgs.alejandra;
    });
}
