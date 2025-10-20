#!/usr/bin/env nu

let BASE_URL = "api.waifu.im"
let TAGS = "/tags"
let TAGS_CACHE_PATH = "/tmp/waifu.nu.tags.json"
let SEARCH = "/search"

let HEADERS = {
  "Content-Type": "application/json",
  "Accept-Version": "v6"
}


def get-url [path: string, params = {}]: nothing -> string {
  {
    "scheme": "https",
    "host": $BASE_URL,
    "path": $path,
    "params": (
      $params 
      | transpose k v 
      | where $it.v != null 
      | reduce -f {} {|i,a| $a | insert $i.k $i.v}
    )
  } | url join
}

def get-tags []: nothing -> list {
  if ($TAGS_CACHE_PATH | path exists) {
    let cached = ($TAGS_CACHE_PATH | open)
    if ($cached != null) {
      return $cached
    }
    rm $TAGS_CACHE_PATH
  }

  http get (get-url $TAGS {"full": true}) --headers $HEADERS
  | values 
  | flatten
  | tee { to json | save $TAGS_CACHE_PATH }
}


# Search for an image(s)
# https://docs.waifu.im/reference/api-reference/search#search-images.
# Input: query params, Output: a list of image records.
def get-search [params = {}]: nothing -> list {
  http get (get-url $SEARCH $params) --headers $HEADERS 
  | get "images"
}


def tag-display []: list -> list {
  $in | enumerate | flatten | each {|| 
    $"#($in.index): ($in.description) [($in.name)(if ($in.is_nsfw) { ', nsfw' } else { ', sfw' })]"
  }
}


def tags-select []: nothing -> list {
  let tags = (get-tags)
  $tags 
    | tag-display
    | str join "\n"
    | fzf -m --header "Select a tag(s)" --footer "Tab to toggle, enter to select"
    | lines
    | each {|s| 
      $tags 
      | get (
        $s | parse "#{index}: {description} [{tags}]"
        | get index 
        | first
        | into int
      )
    }
}


# creates a filename from the search response item.
def get-filepath [item: record]: nothing -> string {
  [$env.XDG_PICTURES_DIR, "waifu", (if $item.is_nsfw { "nsfw" } else { "sfw" })]
  | append ((
     $item.tags 
     | each {|| $in.name}
     | append $"($item.width)x($item.height).($item.signature)"
     | str join "."
    ) + $item.extension)
  | path join
}


def download []: [record -> string, record -> nothing] {
  let filepath = (get-filepath $in)
  if ($filepath | path exists) {
    return $filepath
  }
  let url = $in.url
  try {
    let bytes = (http get $url)
    $bytes | save $filepath
    notify-send "Saved" $filepath
    return $filepath
  } catch {|err| 
    notify-send -u CRITICAL "Error" $err.msg
    print --stderr $err.msg 
    return null
  }
}

# filepath + sixel output = bytes out
# filepath + imv output = nothing out
def display [output: string]: [string -> binary, string -> nothing] {
  let filepath = $in
  match $output {
    imv => {
      let pid = (ps | where name =~ "imv" | get pid)
      if (($pid | length) == 0) {
        error make { msg: "imv is not running" }
      }
      imv-msg ($pid | first) open $filepath
      imv-msg ($pid | first) next
      return null
    }
    sixel => {
      chafa $filepath
    }
  }
}


# Invalidates and populates the tag cache returning the result.
# More: https://docs.waifu.im/reference/api-reference/tags
def "main retags" []: nothing -> list {
  try { rm $TAGS_CACHE_PATH }
  get-tags
}

# Image search with interactive tag select.
# More: https://docs.waifu.im/reference/api-reference/search
def "main search" [] {
  let tags = (tags-select | get name)
  let filepath = (
    get-search { "included_tags": $tags }
    | first
    | download
  )
  if ($filepath == null) {
   return
  }
  $filepath | open | imv -
}

def "main inf" [] {
  let query = build-query
  let output = ([imv, sixel] | select "Output" | first)

  let fp = (get-search $query | first | download)
  $fp | display $output
  print $fp

  loop {
    print "(N)ext / (Q)uit"
    match (input listen --types [key]).code {
      n|N => {
        clear
        let fp = (get-search $query | first | download)
        $fp | display $output
        print $fp
      }
      q|Q|esc => (clear; break)
    }
  }
}

def --wrapped select [label: string, ...args]: list<any> -> list<any> {
  gum style --align center --foreground 212 --width 50 $label
  $in 
  | each {|o| 
    if (($o | describe) != 'string') {
      $o | to json
    } else {
      $o
    }} 
  | str join "\n"
  | gum choose ...$args
  | split row "\n"
  | each {|o| $o | from json}
}

def build-query []: nothing -> record {
  { 
    "is_nsfw": ([true, false] | select "NSFW?" | first),
    "gif": ([false, true] | select "GIF?" | first),
    "orientation": ([null, landscape, portrait] | select "Orientation?" | first),
    "included_tags": (get-tags | get name | select "Tags" --no-limit),
  }
}

# Downloads an image and returns its path.
def main []: [nothing -> string, nothing -> nothing] {
  let filepath = (get-search (build-query) | first | download)
  if ($filepath == null) {
   return
  }
  $filepath | display ([imv, sixel] | select "Output" | first)
}
