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
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-darwin"] (
      system: let
        pkgs = import nixpkgs {inherit system;};
        isLinux = pkgs.stdenv.isLinux;
        lib = pkgs.lib;
      in {
        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShell {
          CMAKE_GENERATOR = "Ninja";
          LDFLAGS = "-fuse-ld=mold";
          LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.gcc14.cc pkgs.capnproto];
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          QT_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";

          nativeBuildInputs = with pkgs;
            [
              byacc
              ccache
              cmake
              gcc14
              gnum4
              gnumake
              include-what-you-use
              llvmPackages_20.clang
              llvmPackages_20.clang-tools
              llvmPackages_20.stdenv
              mold-wrapped
              ninja
              pkg-config
              qt6.wrapQtAppsHook
            ]
            ++ (
              if isLinux
              then [
                libsystemtap
                linuxPackages.bcc
                linuxPackages.bpftrace
              ]
              else []
            );

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
            ++ (
              if isLinux
              then [
                libsystemtap
                linuxPackages.bcc
                linuxPackages.bpftrace
                python312Packages.bcc
              ]
              else []
            );

          shellHook = ''
            # Opinionated defaults
            export CC=clang
            export CXX=clang++
          '';
        };
      }
    );
}
