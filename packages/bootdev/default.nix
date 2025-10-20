{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  version = "1.20.5";
in
buildGoModule {
  pname = "bootdev";
  inherit version;

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    sha256 = "sha256-iVL2nRQb4A7UfhiQSBBbaxM1Yqc2pESvRfQ3xSjGq10=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  meta = {
    description = "Boot.dev cli tool";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
  };
}
