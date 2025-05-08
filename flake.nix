{
  description = "Bitcoin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11";
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
          clang-tools_19
          clang_19
          cmake
          gcc14
          gnum4
          gnumake
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
          python312Packages.bcc
        ];

        buildInputs = commonBuildInputs ++ (if isLinux then linuxBuildInputs else []);

        shellHook = ''
          # Opinionated defaults
          export CC=clang
          export CXX=clang++
          export CMAKE_GENERATOR=Ninja
          export LDFLAGS="-fuse-ld=mold"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.gcc14.cc pkgs.capnproto ];
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          QT_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";
          inherit nativeBuildInputs buildInputs shellHook;
        };
      }
    );
}
