{
  bat,
  id3v2,
  flac,
  ffmpeg,
  file,
  ouch,
  chafa,
  nuenv,
}:
{
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
      # a video file metadata.
      ffmpeg
      # archive support.
      ouch
      # previewing images in terminal.
      chafa
    ];
    text = builtins.readFile ./src/preview.nu;
    meta = {
      mainProgram = "preview";
      description = "File previewer for LF";
    };
  };
}
