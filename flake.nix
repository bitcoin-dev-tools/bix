{
  description = "Bitcoin development environment with tools for building, testing, and debugging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachSystem
      [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ]
      (
        system:
        let
          compilerRtNoLibcAarch64LinuxOverlay =
            final: prev:
            let
              patchLlvmPackages =
                llvmPackages:
                llvmPackages.overrideScope (
                  llvmFinal: llvmPrev: {
                    compiler-rt-no-libc = llvmPrev.compiler-rt-no-libc.overrideAttrs (oldAttrs: {
                      postPatch =
                        (oldAttrs.postPatch or "")
                        +
                          final.lib.optionalString (prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64)
                            ''
                              # PR #409265 disables AArch64 FMV for no-libc compiler-rt
                              # builds, but LLVM 22 still includes sys/auxv.h for LSE atomics.
                              # https://github.com/NixOS/nixpkgs/pull/409265
                              # https://github.com/NixOS/nixpkgs/issues/393603
                              substituteInPlace lib/builtins/cpu_model/aarch64.c \
                                --replace-fail '#elif defined(__linux__)' \
                                               '#elif defined(__linux__) && __has_include(<sys/auxv.h>)'
                            '';
                    });
                  }
                );
            in
            {
              llvmPackages_22 = patchLlvmPackages prev.llvmPackages_22;
              llvmPackages_latest = final.llvmPackages_22;
            };

          # Temporary overlay until nixpkgs merges:
          # https://github.com/NixOS/nixpkgs/pull/541600
          capnproto150Overlay = final: prev: {
            capnproto = prev.capnproto.overrideAttrs (oldAttrs: rec {
              version = "1.5.0";
              src = prev.fetchFromGitHub {
                owner = "capnproto";
                repo = "capnproto";
                rev = "v${version}";
                hash = "sha256-2J3FYwPAtbahHI1y1KMqU8Gn2YlKyIW8kZIJz2Ja31w=";
              };
            });
          };

          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              compilerRtNoLibcAarch64LinuxOverlay
              capnproto150Overlay
            ];
          };
          inherit (pkgs) lib;
          inherit (pkgs.stdenv) isLinux isDarwin;

          python = pkgs.python313;
          llvmPackages = pkgs.llvmPackages_latest;

          clang-tidy-diff =
            pkgs.runCommand "clang-tidy-diff"
              {
                nativeBuildInputs = [ pkgs.makeWrapper ];
              }
              ''
                mkdir -p $out/bin
                cp ${llvmPackages.clang-unwrapped.src}/clang-tools-extra/clang-tidy/tool/clang-tidy-diff.py \
                  $out/bin/clang-tidy-diff
                chmod +x $out/bin/clang-tidy-diff
                wrapProgram $out/bin/clang-tidy-diff \
                  --prefix PATH : ${
                    lib.makeBinPath [
                      llvmPackages.clang-tools
                      pythonEnv
                    ]
                  }
              '';

          patchelf-releases = pkgs.writeShellApplication {
            name = "patchelf-releases";
            runtimeInputs = with pkgs; [
              patchelf
              file
              findutils
              gnugrep
            ];
            text = builtins.replaceStrings [ "@interp@" ] [ "${pkgs.glibc}/lib/ld-linux-x86-64.so.2" ] (
              builtins.readFile ./scripts/patchelf-releases.sh
            );
          };

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

          # Will only exist in the build environment
          nativeBuildInputs = [
            pkgs.bison
            pkgs.ccache
            llvmPackages.clang-tools
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

          # Will exist in the runtime environment
          buildInputs = [
            pkgs.boost
            pkgs.capnproto
            pkgs.libevent
            pkgs.sqlite.dev
            pkgs.zeromq
          ];

          mkDevShell =
            nativeInputs: buildInputs:
            (pkgs.mkShell.override { stdenv = stdEnv; }) {
              nativeBuildInputs = nativeInputs;
              inherit buildInputs;
              hardeningDisable = lib.optionals isDarwin [ "stackclashprotection" ];
              packages = [
                clang-tidy-diff
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
                patchelf-releases
                pkgs.gdb
                pkgs.valgrind
              ]
              ++ lib.optionals isDarwin [ llvmPackages.lldb ];

              CMAKE_GENERATOR = "Ninja";
              CMAKE_EXPORT_COMPILE_COMMANDS = 1;
              LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.capnproto ];
              LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
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
}
