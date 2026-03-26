{ pkgs }:
pkgs.nuenv.writeShellApplication rec {
  name = "gimd";
  text = builtins.readFile ./src/gimd.nu;

  runtimeInputs = with pkgs; [
    chafa
    jq
    fzf
  ];

  meta = {
    mainProgram = name;
    description = "Generic Image Downloader";
  };
}
