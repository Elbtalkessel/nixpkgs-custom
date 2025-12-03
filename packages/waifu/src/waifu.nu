#!/usr/bin/env nu

let BASE_URL = "api.waifu.im"
let TAGS = "/tags"
let TAGS_CACHE_PATH = "/tmp/waifu.nu.tags.json"
let SEARCH = "/search"

let HEADERS = {
  "Content-Type": "application/json",
  "Accept-Version": "v6"
}

# Builds url including GET params.
# Params with value null are discarded.
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

# Gets list of tags that can be used for fetching
# images.
# Caches results because they don't change often.
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

# Displays tags with their description.
def tag-display []: list -> list {
  $in | enumerate | flatten | each {|| 
    $"#($in.index): ($in.description) [($in.name)(if ($in.is_nsfw) { ', nsfw' } else { ', sfw' })]"
  }
}

# Select tag UI.
# Returns IDs of selected tags.
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

# Builds absolute filepath to save image to or display from.
# Checks if an image with matching signature present, and
# returns its file path if does.
def get-filepath [item: record]: nothing -> string {
  # check if image present by searching by signature
  let base = [
    $env.XDG_PICTURES_DIR, 
    "waifu", 
    (if $item.is_nsfw { "nsfw" } else { "sfw" })
  ]
  let fpath = (ls ($base | path join) | where name =~ $item.signature)
  if (($fpath | length) > 0) {
    $fpath | get name | first
  } else {
    $base
    | append ((
       $item.tags 
       | each {|| $in.name}
       | append $"($item.width)x($item.height).($item.signature)"
       | str join "."
      ) + $item.extension)
    | path join
  }
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

# Invalidates and populates the tag cache returning the result.
# More: https://docs.waifu.im/reference/api-reference/tags
def "main retags" []: nothing -> list {
  try { rm $TAGS_CACHE_PATH }
  get-tags
}

def --wrapped select [label: string = "", ...args]: list<any> -> list<any> {
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

def display-options [options: record] {
  $options 
  | items {|k v| $"- ($k): $($v | into string)"} 
  | str join "\n" 
  | gum format
}

def display-image [options: record] {
  clear
  let fp = (get-search $options | first | download)
  display-options $options
  print $fp
  chafa $fp
}


def change-option [options: record] {
  let opt = ($options | items {|k v| $k} | append "apply" | select | first)
  let ans = match $opt {
    "is_nsfw" => {
      { key: $opt, value: ([true, false] | select | first) }
    }
    "gif" => {
      { key: $opt, value: ([false, true] | select | first) }
    }
    "orientation" => {
      { key: $opt, value: ([null, landscape, portrait] | select | first) }
    }
    "included_tags" => {
      { key: $opt, value: (get-tags | get name | select "Tags" --no-limit) }
    }
    "apply" => {
      { key: apply, value: true }
    }
  }
  $ans
}

def change-options [options: record] {
  mut opts = {...$options}
  loop { 
    clear; 
    display-options $opts; 
    let new = (change-option $opts)
    if ($new.key == "apply") {
      break
    }
    $opts = $opts | update $new.key $new.value
  }
  $opts
}

# Downloads an image and returns its path.
def main [] {
  mut options = {
    "is_nsfw": true,
    "gif": false,
    "orientation": "portrait",
    "included_tags": [],
  }

  display-options $options
  let next = (["Show" "Options"] | select "Terminal Waifu" | first)

  if ($next == "Show") {
    display-image $options
  }
  if ($next == "Options") {
    $options = (change-options $options)
  }

  loop {
    print "(N)ext / (O)ptions / (Q)uit"
    match (input listen --types [key]).code {
      n|N => (display-image $options)
      q|Q|esc => (clear; break)
      o|O => ($options = (change-options $options))
    }
  }
}
