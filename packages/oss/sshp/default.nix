{
  stdenv,
  fetchFromGitHub,
  lib,
}:
stdenv.mkDerivation rec {
  pname = "sshp";
  version = "1.1.3";
  src = fetchFromGitHub {
    owner = "bahamas10";
    rev = "v${version}";
    repo = pname;
    sha256 = "sha256-E7nt+t1CS51YG16371LEPtQxHTJ54Ak+r0LP0erC9Mk=";
  };
  makeFlags = [ "PREFIX=$(out)" ];
  # In master but not in version 1.1.3
  preInstall = # bash
    ''
      mkdir -p $out/bin
      mkdir -p $out/man/man1
    '';
  meta = {
    description = "Parallel SSH Executor";
    homepage = "https://github.com/bahamas10/sshp";
    license = lib.licenses.mit;
  };
}
