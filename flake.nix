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

          mkStdenv =
            stdenv:
            pkgs.ccacheStdenv.override {
              stdenv = if isLinux then pkgs.stdenvAdapters.useMoldLinker stdenv else stdenv;
            };

          gccStdenv = mkStdenv pkgs.stdenv;

          clangStdenv =
            let
              stdenv =
                if isLinux then
                  llvmPackages.libcxxStdenv.override {
                    cc = llvmPackages.libcxxStdenv.cc.override {
                      bintools = llvmPackages.bintools;
                    };
                  }
                else
                  llvmPackages.libcxxStdenv;
            in
            mkStdenv stdenv;

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

          # Programs and hooks shared by all shells, executed on the build machine.
          commonNativeBuildInputs = [
            pkgs.bison
            pkgs.ccache
            pkgs.cmakeCurses
            pkgs.curlMinimal
            pkgs.ninja
            pkgs.pkg-config
            pkgs.xz
          ]
          ++ lib.optionals isLinux [
            pkgs.linuxPackages.bcc
            pkgs.linuxPackages.bpftrace
          ];

          # Headers and libraries shared by shells using nixpkgs dependencies.
          commonBuildInputs = [
            pkgs.boost
            pkgs.capnproto
            pkgs.sqlite.dev
            pkgs.zeromq
          ]
          ++ lib.optionals isLinux [
            pkgs.libsystemtap
          ];

          qtEnv = pkgs.qt6.env "bix-qt-${pkgs.qt6.qtbase.version}" [
            pkgs.qt6.qtbase
            pkgs.qt6.qttools
          ];

          qtBuildInputs = [
            qtEnv
            # wrapQtAppsHook inspects qtbase directly to discover qtPluginPrefix.
            pkgs.qt6.qtbase
            pkgs.qrencode
          ];

          qtEnvironment = {
            QT_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins";
            QT_QPA_PLATFORM_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins/platforms";
          }
          // lib.optionalAttrs isLinux {
            QT_QPA_PLATFORM = "wayland";
          };

          mkDevShell =
            {
              stdenv ? gccStdenv,
              buildInputs ? commonBuildInputs,
              extraNativeBuildInputs ? [ ],
              extraBuildInputs ? [ ],
              extraEnvironment ? { },
              extraPackages ? [ ],
            }:
            (pkgs.mkShell.override { inherit stdenv; }) {
              nativeBuildInputs = commonNativeBuildInputs ++ extraNativeBuildInputs;
              buildInputs = buildInputs ++ extraBuildInputs;
              hardeningDisable = lib.optionals isDarwin [ "stackclashprotection" ];
              packages = [
                pkgs.codespell
                pkgs.doxygen
                pkgs.graphviz
                pkgs.hexdump
                pkgs.ruff
                pkgs.ty
                pythonEnv
              ]
              ++ lib.optionals isLinux [
                tools.patchelf-releases
                pkgs.gdb
                pkgs.valgrind
              ]
              ++ lib.optionals isDarwin [ llvmPackages.lldb ]
              ++ extraPackages;

              CMAKE_GENERATOR = "Ninja";
              CMAKE_EXPORT_COMPILE_COMMANDS = 1;
              LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.capnproto ];
              LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
            }
            // extraEnvironment;
        in
        {
          devShells = rec {
            gcc = mkDevShell {
              extraNativeBuildInputs = [ pkgs.qt6.wrapQtAppsHook ];
              extraBuildInputs = qtBuildInputs;
              extraEnvironment = qtEnvironment;
            };
            default = gcc;
            clang = mkDevShell {
              stdenv = clangStdenv;
              extraNativeBuildInputs = [
                pkgs.qt6.wrapQtAppsHook
                llvmPackages.clang-tools
              ];
              extraBuildInputs = qtBuildInputs;
              extraPackages = [
                tools.clang-tidy-diff
                pkgs.include-what-you-use
              ];
              extraEnvironment = {
                # Keep depends' native build tools on the Clang toolchain.
                build_CC = "clang";
                build_CXX = "clang++";
              }
              // qtEnvironment;
            };
            depends = mkDevShell {
              buildInputs = [ ];
            };
          };
          formatter = pkgs.nixfmt-tree;
        }
      );
    in
    {
      devShells = nixpkgs.lib.mapAttrs (_: output: output.devShells) systemOutputs;
      formatter = nixpkgs.lib.mapAttrs (_: output: output.formatter) systemOutputs;
    };
}
