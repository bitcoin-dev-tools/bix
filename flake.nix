{
  description = "Bitcoin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        isLinux = pkgs.stdenv.isLinux;
        lib = pkgs.lib;

        commonNativeBuildInputs = with pkgs; [
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
        ];

        linuxNativeBuildInputs = with pkgs; [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
          python312Packages.bcc
        ];

        nativeBuildInputs = commonNativeBuildInputs ++ (if isLinux then linuxNativeBuildInputs else []);

        pythonEnv = pkgs.python312.withPackages (ps: with ps; [
          flake8
          lief
          mypy
          pyzmq
          vulture
        ]);

        commonBuildInputs = with pkgs; [
          boost
          capnproto
          codespell
          db4
          gdb
          hexdump
          libevent
          qrencode
          qt6.qtbase
          qt6.qttools
          sqlite
          uv
          valgrind
          zeromq
          pythonEnv
        ];

        linuxBuildInputs = with pkgs; [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
          python312Packages.bcc
        ];

        buildInputs = commonBuildInputs ++ (if isLinux then linuxBuildInputs else []);

        shellHook = ''
          # Opinionated defaults
          export CC=clang
          export CXX=clang++
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          CMAKE_GENERATOR = "Ninja";
          LDFLAGS = "-fuse-ld=mold";
          LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.gcc14.cc pkgs.capnproto ];
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          QT_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";
          inherit nativeBuildInputs buildInputs shellHook;
        };
      }
    );
}
