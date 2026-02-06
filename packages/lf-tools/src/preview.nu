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
  | last
  | str trim
  | parse "{major}/{minor}"
  | each {|mtype|
    # replacing major (likely generic "application" keyword) with "x-archive".
    if ($mtype.minor in $ARCHIVE_MTYPE) {
      $mtype | merge {major: "x-archive"}
    } else {
      $mtype
    }
   }
  | last
}


# <- image bytes 
# -> sixel string
def to-sixel [w: number, h: number]: binary -> string {
  $in 
  | chafa -f sixel -s $"($w)x($h)" --animate off --polite on
}


# -> image bytes
def to-thumbnail [f: string]: nothing -> binary {
  ffmpegthumbnailer -i $f -s 0 -q 5 -c jpg -o -
}


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


# Appends to a string input its tags (if any).
# Separates both by newline.
# f a file path
# w window width
def with-tags [f: string, w: number]: string -> string {
  let r = do -i { tmsu tags -1 $f } | complete
  mut tags = ""
  if ($r.exit_code == 0) {
   $tags = "\n" + (
     $r.stdout
      | lines --skip-empty
      # If several files passed, tmsu will print in format:
      #   <filename>:
      #   tag
      #   ...
      # Normally it shouldn't happen here.
      | where {|it| not ($it | str ends-with ":")}
      | uniq
      # Decorate each tag with a background.
      | each {|it| $"(ansi pr) ($it) (ansi rst)"}
      # Reduce to a single string.
      | reduce --fold {o: "", c: 0} {|it, acc|
        let cl = $it | ansi strip | str length
        if ($acc.o == "") {
          # First iteration.
          { o: $it, c: 0 }
        } else if (($acc.c + $cl) >= $w) {
          # String overflows max width, render it on next line.
          { o: $"($acc.o)\n($it)", c: 0 }
        } else {
          { o: $"($acc.o) ($it)", c: ($acc.c + $cl) }
        }
      }
      | get o
   )
  }
  $in + $tags
}


def "main mime" [f: string, field: string = ""] {
  let mtype = to-mime $f
  if ($field != "") {
    $mtype | get $field
  } else {
    $mtype
  }
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
  to-mime $f
  | match $in.major {
    x-archive => (ouch l $f)
    audio => (get-exif-info $f $AUDIO_EXIF)
    video => (to-thumbnail $f | to-sixel $w $h)
    image => (open $f | to-sixel $w ($h - 5) | with-tags $f $w)
    _ => (bat --color=always --style=plain --pager=never $f)
  }
}
