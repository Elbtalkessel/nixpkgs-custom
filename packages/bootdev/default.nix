{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  version = "1.20.6";
in
buildGoModule {
  pname = "bootdev";
  inherit version;

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    sha256 = "sha256-/53s+XYMhxo9i1ZeWuV3xiZnhcS5rBJUvM3acb8TiWM=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  meta = {
    description = "Boot.dev cli tool";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
  };
}
