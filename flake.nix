{
  description = "Bitcoin development environment with tools for building, testing, and debugging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      nixpkgs,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      systemOutputs = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (import ./overlays/compiler-rt-no-libc-aarch64-linux.nix)
              (import ./overlays/capnproto-1.5.0.nix)
            ];
          };
          inherit (pkgs) lib;
          inherit (pkgs.stdenv) isLinux isDarwin;

          python = pkgs.python313;
          llvmPackages = pkgs.llvmPackages_latest;

          stdEnv =
            let
              llvmStdenv =
                if isLinux then
                  llvmPackages.libcxxStdenv.override {
                    cc = llvmPackages.libcxxStdenv.cc.override {
                      bintools = llvmPackages.bintools;
                    };
                  }
                else
                  llvmPackages.libcxxStdenv;
            in
            let
              moldStdenv = if isLinux then pkgs.stdenvAdapters.useMoldLinker llvmStdenv else llvmStdenv;
            in
            pkgs.ccacheStdenv.override { stdenv = moldStdenv; };

          pythonEnv = python.withPackages (
            ps:
            with ps;
            [
              flake8
              lief
              matplotlib
              mypy
              pyzmq
              pycapnp
              requests
            ]
            ++ lib.optionals isLinux [
              bcc
            ]
          );

          tools = import ./tools/tools.nix {
            inherit
              lib
              llvmPackages
              pkgs
              pythonEnv
              ;
          };

          # programs/hooks executed on the build machine
          nativeBuildInputs = [
            pkgs.bison
            pkgs.ccache
            llvmPackages.clang-tools
            pkgs.cmakeCurses
            pkgs.curlMinimal
            pkgs.ninja
            pkgs.pkg-config
            pkgs.qt6.wrapQtAppsHook
            pkgs.xz
          ]
          ++ lib.optionals isLinux [
            pkgs.linuxPackages.bcc
            pkgs.linuxPackages.bpftrace
          ];

          # headers and libraries compiled or linked for the target machine
          buildInputs = [
            pkgs.boost
            pkgs.capnproto
            pkgs.qrencode
            pkgs.qt6.qtbase
            pkgs.qt6.qttools
            pkgs.sqlite.dev
            pkgs.zeromq
          ]
          ++ lib.optionals isLinux [
            pkgs.libsystemtap
          ];

          mkDevShell =
            nativeInputs: buildInputs:
            (pkgs.mkShell.override { stdenv = stdEnv; }) {
              nativeBuildInputs = nativeInputs;
              inherit buildInputs;
              hardeningDisable = lib.optionals isDarwin [ "stackclashprotection" ];
              packages = [
                tools.clang-tidy-diff
                pkgs.codespell
                pkgs.doxygen
                pkgs.graphviz
                pkgs.hexdump
                pkgs.include-what-you-use
                pkgs.ruff
                pkgs.ty
                pythonEnv
              ]
              ++ lib.optionals isLinux [
                tools.patchelf-releases
                pkgs.gdb
                pkgs.valgrind
              ]
              ++ lib.optionals isDarwin [ llvmPackages.lldb ];

              CMAKE_GENERATOR = "Ninja";
              CMAKE_EXPORT_COMPILE_COMMANDS = 1;
              LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.capnproto ];
              LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
              QT_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";
              # Force depends capnp to also use clang, otherwise it fails when
              # looking for the default (gcc/g++)
              build_CC = "clang";
              build_CXX = "clang++";
            };
        in
        {
          devShells.default = mkDevShell nativeBuildInputs buildInputs;
          devShells.depends = mkDevShell nativeBuildInputs [ ];
          formatter = pkgs.nixfmt-tree;
        }
      );
    in
    {
      devShells = nixpkgs.lib.mapAttrs (_: output: output.devShells) systemOutputs;
      formatter = nixpkgs.lib.mapAttrs (_: output: output.formatter) systemOutputs;
    };
}
