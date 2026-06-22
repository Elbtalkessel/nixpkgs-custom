{
  fetchFromGitHub,
  lib,
  pkgs,
}:
let
  version = "0.2.3";
  pname = "dmodman";
  owner = "dandels";
in
pkgs.rustPlatform.buildRustPackage {
  inherit version pname;

  src = fetchFromGitHub {
    inherit owner;
    rev = "v${version}";
    repo = pname;
    sha256 = "sha256-pzLl8rXZzpLHbekp5V3zUg8WzSba8ADxRwjIjJFZOmc=";
  };

  cargoHash = "sha256-uALoqREwUYseLreeU8KxQgP0qdFJmrzk6xjg/cIcFCA=";

  nativeBuildInputs = with pkgs; [
    pkg-config
    rustPlatform.bindgenHook
    llvmPackages_latest.libclang
  ];

  buildInputs = with pkgs; [
    (lib.getDev libarchive)
    openssl
  ];

  runtimeInputs = with pkgs; [
    xdg-utils
  ];

  BINDGEN_EXTRA_CLANG_ARGS = [
    "-I${lib.getDev pkgs.libarchive}/include"
  ]
  ++ lib.optionals pkgs.stdenv.cc.isClang [
    "-isystem"
    "${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${lib.getVersion pkgs.llvmPackages_latest.clang}/include"
  ]
  ++ map (x: "-isystem${x}") [
    "${pkgs.glibc.dev}/include"
  ];

  # https://github.com/dandels/dmodman/blob/main/src/config/mod.rs#L161C1-L166C2
  # Tests rely on envvar and / or xdg $XDG_CONFIG_HOME/user-dirs.dirs
  preCheck =
    # bash
    ''
      export HOME="$out/home"
      mkdir -p "$HOME/Downloads"
      export XDG_DOWNLOAD_DIR="$HOME/Downloads"
    '';

  postInstall = ''
    mkdir -p $out/share/applications
    install -Dm444 $src/*.desktop -t $out/share/applications
  '';

  meta = {
    description = "TUI downloader & update checker for Nexusmods.com ";
    homepage = "https://github.com/${owner}/${pname}";
    license = lib.licenses.mit;
  };
}
