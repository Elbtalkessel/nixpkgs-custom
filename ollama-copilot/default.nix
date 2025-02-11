{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  version = "0.2.0";
  pname = "ollama-copilot";
in
buildGoModule {
  inherit version pname;

  src = fetchFromGitHub {
    owner = "bernardo-bruning";
    rev = "v${version}";
    repo = pname;
    sha256 = "sha256-0qNTQHT0aAPd4F6eAAcw1/HWA9BkpmVNIbvzVbehqsc=";
  };

  vendorHash = "sha256-g27MqS3qk67sve/jexd07zZVLR+aZOslXrXKjk9BWtk=";

  meta = {
    description = "Proxy that allows you to use ollama as a copilot like Github copilot";
    homepage = "https://github.com/bernardo-bruning/ollama-copilot";
    license = lib.licenses.mit;
  };
}
