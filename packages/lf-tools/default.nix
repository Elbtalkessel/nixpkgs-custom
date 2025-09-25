{
  bat,
  id3v2,
  flac,
  ffmpeg,
  file,
  ouch,
  exiftool,
  nuenv,
}:
{
  preview = nuenv.writeShellApplication {
    name = "preview";
    runtimeInputs = [
      # text files
      bat
      # mp3
      id3v2
      # flac
      flac
      # any supported video files
      ffmpeg
      # getting a file mime
      file
      # list an archive
      ouch
      # image metadata
      exiftool
    ];
    text = builtins.readFile ./src/preview.nu;
    meta = {
      mainProgram = "preview";
      description = "File previewer for LF";
    };
  };
}
