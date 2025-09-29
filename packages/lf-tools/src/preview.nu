#!/usr/bin/env nu

let AUDIO_EXIF = [
  "File Size",
  "Audio Bitrate",
  "Title",
  "Artist",
  "Album",
  "Date",
  "Track",
  "Band",
  "Duration",
  "Genre",
];

def is-archive [subtype: string]: nothing -> bool {
  [x-tar x-bzip2 gzip x-7z-compressed x-gtar zip] 
  | any {|| $in | str contains $subtype}
}

# extracts mime
def to-mime []: string -> record {
   mimeo -m $in
   | parse "{name}: {major}/{minor}"
   | into record
   | each {||
      # replacing major (likely generic "application" keyword) with "x-archive".
      if (is-archive $in.subtype) {
        $in | merge {major: "x-archive"}
      }
    }
}

# <- image bytes 
# -> bytes in sixel format
def to-sixel [w: number, h: number]: binary -> binary {
  $in 
  | chafa -f sixel -s $"($w)x($h)" --animate off --polite on
}

# <- a video file path
# -> image bytes
def to-thumbnail []: string -> binary {
  ffmpegthumbnailer -i $"($in)" -s 0 -q 5 -c jpg -o -
}


# <- a file path
# -> table formatted file's metadata
def get-exif-info [fields: list<string>]: string -> string {
  exiftool $in
  | lines 
  | where {|line| 
    $fields
    | any {|key| 
      $key in $line
    }
  } 
  | str join "\n"
}

# Usually returns a string describing a file, but for
# images returns byte stream.
# TODO: run it in sandbox environment.
def main [
    f: string, 
    w: number, 
    h: number, 
    x: number = 0, 
    y: number = 0,
  ]: nothing -> any {
  $f 
  | to-mime
  | match $in.major {
    archive => (ouch l $"($f)")
    audio => ($f | get-exif-info $AUDIO_EXIF)
    video => ($f | to-thumbnail | to-sixel $w $h)
    image => ($f | open | to-sixel $w $h)
    _ => (bat --color=always --style=plain --pager=never $"($f)")
  }
}
