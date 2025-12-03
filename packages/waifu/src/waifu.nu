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
    return $filepath
  } catch {|err| 
    notify-send -u CRITICAL "Waifu" $"Error ($err.msg)"
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

def _ [c] {
  $"(ansi pu)($c)(ansi reset)"
}

def i [c] {
  $"(ansi pi)($c)(ansi reset)"
}

def display-options [options: record] {
  print ($"
💦 (_ N)SFW            (i (if ($options.is_nsfw) { "Yes" } else { "No" }))
🙃 (_ O)rientation     (i ($options.orientation))
🏷️ (_ T)ags            (i ($options.included_tags | str join ', '))

👈 (_ b)ack            show previous image
👉 (_ f)orward         navigate to the next image or fetch new one
🫵 (_ c)opy            copy image path to the clipboard
🫰 (_ w)allpaper       set as wallpaper
🤌 (_ q)uit            exit program
")
}

def main [] {
  mut o = {
    "is_nsfw": false,
    "gif": false,
    "orientation": "portrait",
    "included_tags": ["maid"],
  }
  # index of current image
  # image cache
  mut c = (
    ls ...(glob $"($env.XDG_PICTURES_DIR)/waifu/**/*.*")
    | where type == file
    | sort-by modified
    | get name
  )
  mut p = ($c | length) - 1
  mut render = true
  if (($c | length) == 0) {
    $c = ($c | append (get-search $o | first | download))
    $p = 0
  }
  loop {
    if ($render) {
      clear
      chafa ($c | get $p) --fit-width
      display-options $o
    }
    match (input listen --types [key]).code {
      n => {
        $o = $o
        | update is_nsfw { 
          if ($in) { false } else { true } 
        }
        $render = true
      }
      o => {
        $o = $o
        | update orientation { 
          if ($in == "landscape") { "portrait" } else { "landscape" } 
        }
        $render = true
      }
      t => {
        $o = $o
        | update included_tags (tags-select | get name)
        $render = true
      }
      c => {
        $c | get $p | wl-copy
        notify-send -u low -t 900 "💕 Waifu" "Path in clipboard"
        $render = false
      }
      w => {
        setbg ($c | get $p) | ignore
        notify-send -u low -t 900 "💕 Waifu" "Wallpaper set"
        $render = false
      }
      q|esc => (clear; break)
      b => {
        if ($p != 0) {
          $p = $p - 1
        }
        $render = true
      }
      f => {
        if ($p < (($c | length) - 1)) {
          $p = $p + 1
        } else {
          try {
            $c = ($c | append (get-search $o | first | download))
            $p = $p + 1
            $render = true
          } catch {|e|
            notify-send -u critical "💔 Waifu" $"($e.msg)"
          }
        }
      }
    }
  }
}
