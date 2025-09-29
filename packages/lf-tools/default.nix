{ pkgs }:
{
  # TODO:
  # - PDF
  # - SVG
  preview = pkgs.nuenv.writeShellApplication {
    name = "preview";
    runtimeInputs = with pkgs; [
      mimeo
      bat
      exiftool
      ouch
      chafa
      ffmpegthumbnailer
    ];
    text = builtins.readFile ./src/preview.nu;
    meta = {
      mainProgram = "preview";
      description = "File previewer for LF";
    };
  };
  # Archive opener for interactive extraction.
}
