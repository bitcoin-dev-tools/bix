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
}
