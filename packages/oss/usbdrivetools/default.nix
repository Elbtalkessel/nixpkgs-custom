{
  stdenv,
  fetchFromGitHub,
  lib,
  bash,
  rsync,
}:
stdenv.mkDerivation rec {
  pname = "usbdrivetools";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "satk0";
    repo = "usbdrivetools";
    rev = "main";
    sha256 = "sha256-0YSXL+ziwbe1pueMZ6Y7NS1ml+IKivb8ryRTFyPyxak=";
  };

  runtimeInput = [
    bash
    rsync
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp -r scripts/* $out/bin/
    chmod +x $out/bin/*
  '';

  meta = {
    description = "Simple bash tools that aim to help transfer files to USB Drive and monitor their syncing progress. Provides usbcp, usbdd, usbeject, usbmv and usbumount.";
    homepage = "https://github.com/satk0/usbdrivetools";
    license = lib.licenses.gpl3;
  };
}
