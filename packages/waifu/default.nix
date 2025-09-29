{ pkgs }:
pkgs.nuenv.writeShellApplication rec {
  name = "waifu";
  text = builtins.readFile ./src/waifu.nu;

  runtimeInputs = with pkgs; [
    imv
    libnotify
    chafa
  ];

  meta = {
    mainProgram = name;
    description = "Waifu downloader";
  };
}
