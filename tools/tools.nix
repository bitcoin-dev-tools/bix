{
  pkgs,
  lib,
  llvmPackages,
  pythonEnv,
}:
{
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
    text = builtins.replaceStrings [ "@interp@" ] [ pkgs.stdenv.cc.bintools.dynamicLinker ] (
      builtins.readFile ../scripts/patchelf-releases.sh
    );
  };
}
