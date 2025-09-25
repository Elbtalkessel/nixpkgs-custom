{ pkgs, ... }:
pkgs.nuenv.writeShellApplication {
  name = "waifu";
  runtimeInputs = with pkgs; [
    nushell
    imv
  ];
  text = builtins.readFile ./waifu.nu;
  meta = {
    mainProgram = "waifu";
    description = "Waifu downloader";
  };
}
