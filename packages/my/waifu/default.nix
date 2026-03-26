{ pkgs }:
pkgs.nuenv.writeShellApplication rec {
  name = "waifu";
  text = builtins.readFile ./src/waifu.nu;

  runtimeInputs = with pkgs; [
    chafa
    jq
  ];

  meta = {
    mainProgram = name;
    description = "Waifu downloader";
  };
}
