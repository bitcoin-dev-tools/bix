{
  description = "Bitcoin development environment with tools for building, testing, and debugging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      inherit (pkgs) lib;
      inherit (pkgs.stdenv) isLinux isDarwin;

      python = pkgs.python313;
      llvmPackages = pkgs.llvmPackages_20;

      # On Darwin use clang-20 otherwise use a gcc15 (and mold)-based standard env.
      stdEnv =
        if isDarwin
        then llvmPackages.stdenv
        else pkgs.stdenvAdapters.useMoldLinker pkgs.gcc15Stdenv;

      pythonEnv = python.withPackages (ps:
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
          ]);

      # Will only exist in the build environment
      nativeBuildInputs = with pkgs;
        [
          bison
          ccache
          clang-tools
          cmake
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

      # Will exist in the runtime environment
      buildInputs = with pkgs; [
        boost
        capnproto
        libevent
        qrencode
        qt6.qtbase # https://nixos.org/manual/nixpkgs/stable/#sec-language-qt
        qt6.qttools
        sqlite.dev
        zeromq
      ];

      # Qt-only build inputs needed for depends shell
      qtBuildInputs = with pkgs; [
        qt6.qtbase # https://nixos.org/manual/nixpkgs/stable/#sec-language-qt
        qt6.qttools
      ];

      mkDevShell = nativeInputs: buildInputs:
        (pkgs.mkShell.override {stdenv = stdEnv;}) {
          inherit nativeBuildInputs buildInputs;
          packages =
            [
              pythonEnv
              pkgs.codespell
              pkgs.hexdump
            ]
            ++ lib.optionals isLinux [pkgs.gdb]
            ++ lib.optionals isDarwin [llvmPackages.lldb];

          CMAKE_GENERATOR = "Ninja";
          CMAKE_EXPORT_COMPILE_COMMANDS = 1;
          LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.capnproto];
          LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
        };
    in {
      devShells.default = mkDevShell (nativeBuildInputs ++ [pkgs.qt6.wrapQtAppsHook]) buildInputs;
      devShells.depends = mkDevShell nativeBuildInputs qtBuildInputs;

      formatter = pkgs.alejandra;
    });
}
