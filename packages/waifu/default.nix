{
  imv,
  nuenv,
  libnotify,
}:
nuenv.writeShellApplication rec {
  name = "waifu";
  text = builtins.readFile ./src/waifu.nu;

  runtimeInputs = [
    imv
    libnotify
  ];

  meta = {
    mainProgram = name;
    description = "Waifu downloader";
  };
}
