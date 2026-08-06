# Temporary overlay until nixpkgs merges:
# https://github.com/NixOS/nixpkgs/pull/541600
final: prev: {
  capnproto = prev.capnproto.overrideAttrs (oldAttrs: rec {
    version = "1.5.0";
    src = prev.fetchFromGitHub {
      owner = "capnproto";
      repo = "capnproto";
      rev = "v${version}";
      hash = "sha256-2J3FYwPAtbahHI1y1KMqU8Gn2YlKyIW8kZIJz2Ja31w=";
    };
  });
}
