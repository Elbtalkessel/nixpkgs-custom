{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  version = "1.20.1";
in
buildGoModule {
  pname = "bootdev";
  inherit version;

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    sha256 = "sha256-fjXMaK6Mz38FJNrR+lVDi0EMxMoCTnC1q0wDQS1Mab8=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  meta = {
    description = "Boot.dev cli tool";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
  };
}
