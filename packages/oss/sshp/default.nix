{
  stdenv,
  fetchFromGitHub,
  lib,
}:
stdenv.mkDerivation rec {
  pname = "sshp";
  version = "1.1.4";
  src = fetchFromGitHub {
    owner = "bahamas10";
    rev = "v${version}";
    repo = pname;
    sha256 = "sha256-4DrNGQQ1ETKuLiB3N+3KnRxx4BEhrCOgskpowbF/KWc=";
  };
  makeFlags = [ "PREFIX=$(out)" ];
  meta = {
    description = "Parallel SSH Executor";
    homepage = "https://github.com/bahamas10/sshp";
    license = lib.licenses.mit;
  };
}
