{
  description = "Bitcoin development environment with tools for building, testing, and debugging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-qt6.url = "github:NixOS/nixpkgs/0c0e48b0ec1af2d7f7de70f839de1569927fe4c8";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-qt6,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # Overlay depends-matching version of qt6:
        # https://github.com/bitcoin/bitcoin/blob/master/depends/packages/qt_details.mk#L1
        qtPkgs = import nixpkgs-qt6 { inherit system; };
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              qt6 = qtPkgs.qt6;
            })
          ];
        };
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
            vulture
          ]
          ++ lib.optionals isLinux [
            bcc
          ]
        );

        # Will only exist in the build environment
        nativeBuildInputs =
          with pkgs;
          [
            bison
            ccache
            clang-tools
            cmakeCurses
            curlMinimal
            ninja
            pkg-config
            xz
          ]
          ++ lib.optionals isLinux [
            libsystemtap
            linuxPackages.bcc
            linuxPackages.bpftrace
          ];

        qtBuildInputs = with pkgs; [
          qt6.qtbase # https://nixos.org/manual/nixpkgs/stable/#sec-language-qt
          qt6.qttools
        ];

        # Will exist in the runtime environment
        buildInputs = with pkgs; [
          boost
          capnproto
          libevent
          qrencode
          sqlite.dev
          zeromq
        ];

        mkDevShell =
          nativeInputs: buildInputs:
          (pkgs.mkShell.override { stdenv = stdEnv; }) {
            inherit nativeBuildInputs buildInputs;
            packages = [
              pkgs.include-what-you-use
              pythonEnv
              pkgs.codespell
              pkgs.hexdump
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
