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

def video []: string -> string {
  (
    ffprobe 
    -v error 
    -show_entries format=filename,duration,size 
    -of default=noprint_wrappers=1 
    # format duration using hh:mm:ss
    -sexagesimal 
    $in
  )
  | split row -r '\n' 
  | parse '{key}={value}' 
  | each {||
      match $in.key {
        size => ($in.value | into filesize | format filesize MB)
        filename => ($in.value | path basename)
        _ => $in.value
      }
  } 
  | str join "\n"
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
def main [f: string, w, h, x = 0, y = 0]: nothing -> any {
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
    video => ($f | video)
    image => (
      chafa 
      -f sixel
      -s $"($w)x($h)" 
      --animate off
      --polite on
      $"($f)"
    )
    _ => (bat --color=always --style=plain --pager=never $"($f)")
  }
}
