{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  version = "1.19.2";
in
buildGoModule {
  pname = "bootdev";
  inherit version;

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    sha256 = "sha256-jTI91t/gcEdOc3mwP0dFqL5sYeaC6nD96+RpuQfAf4s=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  meta = {
    description = "Boot.dev cli tool";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
  };
}
