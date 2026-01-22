{
  description = "Bitcoin development environment with tools for building, testing, and debugging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        unstablePkgs = import nixpkgs-unstable { inherit system; };
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;
        inherit (pkgs.stdenv) isLinux isDarwin;

        python = pkgs.python313;
        llvmPackages = pkgs.llvmPackages_latest;

        # Use a full llvm toolchain including bintools
        stdEnv =
          let
            llvmStdenv = llvmPackages.stdenv.override {
              cc = llvmPackages.stdenv.cc.override {
                bintools = llvmPackages.bintools;
              };
            };
          in
          if isLinux then
            # Mold linker is much faster on Linux
            pkgs.stdenvAdapters.useMoldLinker (pkgs.ccacheStdenv.override { stdenv = llvmStdenv; })
          else
            pkgs.ccacheStdenv.override { stdenv = llvmStdenv; };

        pythonEnv = python.withPackages (
          ps:
          with ps;
          [
            flake8
            lief
            mypy
            pyzmq
            pycapnp
            requests
            vulture
          ]
          ++ lib.optionals isLinux [
            bcc
          ]
        );

        # Will only exist in the build environment
        nativeBuildInputs = [
          pkgs.bison
          pkgs.ccache
          pkgs.clang-tools
          pkgs.cmakeCurses
          pkgs.curlMinimal
          pkgs.ninja
          pkgs.pkg-config
          pkgs.xz
        ]
        ++ lib.optionals isLinux [
          pkgs.libsystemtap
          pkgs.linuxPackages.bcc
          pkgs.linuxPackages.bpftrace
        ];

        qtBuildInputs = [
          pkgs.qt6.qtbase # https://nixos.org/manual/nixpkgs/stable/#sec-language-qt
          pkgs.qt6.qttools
        ];

        # Will exist in the runtime environment
        buildInputs = [
          pkgs.boost
          pkgs.capnproto
          pkgs.libevent
          pkgs.qrencode
          pkgs.sqlite.dev
          pkgs.zeromq
        ];

        mkDevShell =
          nativeInputs: buildInputs:
          (pkgs.mkShell.override { stdenv = stdEnv; }) {
            inherit nativeBuildInputs buildInputs;
            packages = [
              pkgs.codespell
              pkgs.hexdump
              pkgs.include-what-you-use
              pkgs.ruff
              unstablePkgs.ty
              pythonEnv
            ]
            ++ lib.optionals isLinux [ pkgs.gdb ]
            ++ lib.optionals isDarwin [ llvmPackages.lldb ];

            CMAKE_GENERATOR = "Ninja";
            CMAKE_EXPORT_COMPILE_COMMANDS = 1;
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.capnproto ];
            LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
          };
      in
      {
        devShells.default = mkDevShell (nativeBuildInputs ++ [ pkgs.qt6.wrapQtAppsHook ]) (
          buildInputs ++ qtBuildInputs
        );
        devShells.depends = (mkDevShell nativeBuildInputs qtBuildInputs).overrideAttrs (oldAttrs: {
          # Set these to force depends capnp to also use clang, otherwise it
          # fails when looking for the default (gcc/g++)
          build_CC = "clang";
          build_CXX = "clang++";
        });
        formatter = pkgs.nixfmt-tree;
      }
    );
}
