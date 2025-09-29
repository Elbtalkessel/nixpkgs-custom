{ pkgs }:
{
  # TODO: replace `file` with `mimeo`,
  #   `id3v2` and `flac` with `exiftool`,
  #   remove `ffmpeg`,
  #   add pdf file preview.
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
}
