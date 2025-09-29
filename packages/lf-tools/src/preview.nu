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

let ARCHIVE_MTYPE = [
  x-tar
  x-bzip2
  gzip
  x-7z-compressed
  x-gtar
  zip
  x-compressed-tar
]

# extracts mime
def to-mime [f: string]: nothing -> record {
  # <file/path>
  #   <mime/type>
  mimeo -m $f
  | lines
  | str trim
  | parse "{major}/{minor}"
  | last
  | each {|mtype|
    # replacing major (likely generic "application" keyword) with "x-archive".
    if ($mtype.minor in $ARCHIVE_MTYPE) {
      $mtype | merge {major: "x-archive"}
    } else {
      $mtype
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
def to-thumbnail [f: string]: nothing -> binary {
  ffmpegthumbnailer -i $"($f)" -s 0 -q 5 -c jpg -o -
}


# <- a file path
# -> table formatted file's metadata
def get-exif-info [f: string, fields: list<string>]: nothing -> string {
  exiftool $f
  | lines 
  | where {|line| 
    $fields
    | any {|key| 
      $key in $line
    }
  } 
  | str join "\n"
}

def "main mime" [f: string] {
  $f | to-mime
}

# Usually returns a string describing a file, but for
# images returns byte stream.
# TODO: run it in sandbox environment.
def main [
    f: string, 
    w: number = 100,
    h: number = 100, 
    x: number = 0, 
    y: number = 0,
  ]: nothing -> any {
  $f
  | to-mime
  | match $in.major {
    x-archive => (ouch l $"($f)")
    audio => (get-exif-info $"($f)" $AUDIO_EXIF)
    video => (to-thumbnail $"($f)" | to-sixel $w $h)
    image => (open $"($f)" | to-sixel $w $h)
    _ => (bat --color=always --style=plain --pager=never $"($f)")
  }
}
