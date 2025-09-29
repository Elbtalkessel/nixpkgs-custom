#!/usr/bin/env nu

def file-mime-type []: string -> record {
   file --mime-type $in
   | parse "{name}: {type}/{subtype}"
   | into record
}

def is-archive [subtype: string]: nothing -> bool {
  [x-tar x-bzip2 gzip x-7z-compressed x-gtar zip] 
  | any {|| $in | str contains $subtype}
}

def merge-mime-supertype []: record -> record {
  $in
  | each {||
    # workaround because a lot of archive formats have different mime
    if (is-archive $in.subtype) {
      $in | merge {supertype: "archive"}
    } else {
      $in | merge {supertype: $in.type}
    }
  }
}

# Coverts stdin bytes into sixel formatted string to show images in terminal.
def to-sixel [w: number, h: number]: binary -> binary {
  $in 
  | chafa -f sixel -s $"($w)x($h)" --animate off --polite on
}

# Converts a path from stdin to a byte string.
def video-thumbnail-stream []: string -> binary {
  ffmpegthumbnailer -i $"($in)" -s 0 -q 5 -c jpg -o -
}


# Parses the VORBIS_COMMENT block extracting comments and
# clearing it leaving only comments itself.
def get-flac-meta [f: string]: nothing -> string {
  # Input:
  # METADATA block #2
  #   type: 4 (VORBIS_COMMENT)
  #   is last: false
  #   length: 214
  #   vendor string: reference libFLAC 1.2.1 20070917
  #   comments: <N>
  #     comment[N]: <KEY>=<Value>
  metaflac --block-type=VORBIS_COMMENT --list $f 
  | lines
  | where $it =~ "comment" 
  | slice 1.. 
  | str replace -r '^.*comment\[\d+\]: ' '' 
  | str replace "=" ": " 
  | str join "\n"
}

def "main mime" [f: string]: nothing -> record {
  $f | file-mime-type | merge-mime-supertype
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
  | file-mime-type
  | merge-mime-supertype
  | match $in.supertype {
    archive => (ouch l $"($f)")
    audio => {
      match $in.subtype {
        flac => (get-flac-meta $f)
        _ => (id3v2 --list $"($f)")
      }
    }
    video => ($f | video-thumbnail-stream | to-sixel $w $h)
    image => ($f | open | to-sixel $w $h)
    _ => (bat --color=always --style=plain --pager=never $"($f)")
  }
}
