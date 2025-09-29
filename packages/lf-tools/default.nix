{
  bat,
  id3v2,
  flac,
  file,
  ouch,
  chafa,
  nuenv,
  ffmpegthumbnailer,
}:
{
  # TODO: replace `file` with `mimeo`,
  #   `id3v2` and `flac` with `exiftool`,
  #   remove `ffmpeg`,
  #   add pdf file preview.
  preview = nuenv.writeShellApplication {
    name = "preview";
    runtimeInputs = [
      # Getting a file info.
      file
      # Text file preview.
      bat
      # mp3 tags preview.
      id3v2
      # flac tags preview.
      flac
      # archive support.
      ouch
      # previewing images in terminal.
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
