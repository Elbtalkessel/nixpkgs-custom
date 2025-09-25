{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  version = "1.2";
  pname = "tlm";
in
buildGoModule {
  inherit version pname;

  src = fetchFromGitHub {
    owner = "yusufcanb";
    rev = version;
    repo = pname;
    sha256 = "sha256-G6cpFzN7PuTve1RTZGp6VPnE93xVITEFVMCzrix6hXg=";
  };

  vendorHash = "sha256-JgmGPtPDMfRosa1I441pzAP0wBM36EaQarhhOOQ4+zw=";

  # Skip check phase, it calls the app, but the app requires .tlm in home folder.
  # During build nix assignes HOME to a read-only /homeless-shelter, thus uselsess.
  doCheck = false;

  meta = {
    description = "Local CLI Copilot, powered by Ollama";
    homepage = "https://github.com/yusufcanb/tlm";
    license = lib.licenses.asl20;
  };
}
