{
  description = "Bitcoin development environment with tools for building, testing, and debugging";

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
      isLinux = pkgs.stdenv.isLinux;
      lib = pkgs.lib;
    in {
      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        CMAKE_GENERATOR = "Ninja";
        LDFLAGS = "-fuse-ld=mold";
        LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.gcc14.cc pkgs.capnproto];
        LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
        QT_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";

        nativeBuildInputs = with pkgs;
          [
            autoconf
            automake
            byacc
            ccache
            cmake
            gcc14
            gnum4
            gnumake
            include-what-you-use
            libtool
            llvmPackages_20.clang
            llvmPackages_20.clang-tools
            llvmPackages_20.stdenv
            mold-wrapped
            ninja
            pkg-config
            qt6.wrapQtAppsHook
          ]
          ++ lib.optionals isLinux [
            libsystemtap
            linuxPackages.bcc
            linuxPackages.bpftrace
          ];

        buildInputs = with pkgs;
          [
            boost
            capnproto
            codespell
            db4
            gdb
            hexdump
            libevent
            python312Packages.flake8
            python312Packages.lief
            python312Packages.mypy
            python312Packages.pyzmq
            python312Packages.vulture
            qrencode
            qt6.qtbase
            qt6.qttools
            sqlite
            uv
            valgrind
            zeromq
          ]
          ++ lib.optionals isLinux [
            libsystemtap
            linuxPackages.bcc
            linuxPackages.bpftrace
            python312Packages.bcc
          ]
          ++ lib.optionals (system == "aarch64-darwin") [
            pkgs.darwin.apple_sdk.frameworks.CoreServices
          ];

        shellHook = ''
          export CC=clang
          export CXX=clang++
          export PATH=$PATH:${pkgs.ccache}/bin
        '';
      };
    });
}
