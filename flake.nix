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
      pkgs = import nixpkgs { inherit system; };
      isLinux = pkgs.stdenv.isLinux;
      isDarwin = pkgs.stdenv.isDarwin;
      lib = pkgs.lib;
      llvmPackages = pkgs.llvmPackages_20;

      # make a custom toolchain using llvm20
      llvmStdenv = llvmPackages.stdenv.override {
        cc = llvmPackages.clangUseLLVM;
      };
      toolchain =
        if isLinux
        then pkgs.useMoldLinker llvmStdenv
        else llvmStdenv;

      # Override pkgs to use LLVM stdenv
      pkgsWithLLVM = import nixpkgs {
        inherit system;
        stdenv = toolchain;
      };

      # Dependencies
      nativeBuildInputs = with pkgsWithLLVM;
        [
          autoconf
          automake
          byacc
          ccache
          cmake
          gnum4
          gnumake
          libtool
          llvmPackages_20.clang
          llvmPackages_20.clang-tools
          ninja
          pkg-config
          qt6.wrapQtAppsHook
        ]
        ++ lib.optionals isLinux [
          mold-wrapped
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
        ];

      buildInputs = with pkgsWithLLVM;
        [
          boost
          capnproto
          codespell
          db4
          libevent
          qrencode
          qt6.qtbase
          qt6.qttools
          sqlite.dev
          zeromq
        ]
        ++ lib.optionals isLinux [
          libsystemtap
          linuxPackages.bcc
          linuxPackages.bpftrace
          python312Packages.bcc
        ]
        ++ lib.optionals isDarwin [
          darwin.apple_sdk.frameworks.CoreServices
        ];

      env = {
        CMAKE_GENERATOR = "Ninja";
        LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgsWithLLVM.capnproto ];
        LOCALE_ARCHIVE = lib.optionalString isLinux "${pkgsWithLLVM.glibcLocales}/lib/locale/locale-archive";
        QT_PLUGIN_PATH = "${pkgsWithLLVM.qt6.qtbase}/${pkgsWithLLVM.qt6.qtbase.qtPluginPrefix}";
      };
    in {
      formatter = pkgsWithLLVM.alejandra;

      devShells.default = (pkgsWithLLVM.mkShell.override { stdenv = toolchain; }) {
        nativeBuildInputs = nativeBuildInputs;
        buildInputs = buildInputs;
        packages = with pkgsWithLLVM; [
          codespell
          gdb
          hexdump
          python312Packages.flake8
          python312Packages.lief
          python312Packages.mypy
          python312Packages.pyzmq
          python312Packages.vulture
          uv
        ];

        inherit (env) CMAKE_GENERATOR LD_LIBRARY_PATH LOCALE_ARCHIVE QT_PLUGIN_PATH;
      };
    });
}
