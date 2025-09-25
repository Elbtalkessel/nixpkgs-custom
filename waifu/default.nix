{
  imv,
  nuenv,
}:
nuenv.writeShellApplication rec {
  name = "waifu";
  text = builtins.readFile ./src/waifu.nu;

  runtimeInputs = [
    imv
  ];

  meta = {
    mainProgram = name;
    description = "Waifu downloader";
  };
}
