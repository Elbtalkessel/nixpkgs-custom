{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  version = "1.22.0";
in
buildGoModule {
  pname = "bootdev";
  inherit version;

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    sha256 = "sha256-Fk82JKD8zHRPBoliwnvQKqZNii7TiX13cKENXw5011E=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  meta = {
    description = "Boot.dev cli tool";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = lib.licenses.mit;
  };
}
