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
  let r = (http get -e -f (get-url $SEARCH $params) --headers $HEADERS)
  if ($r.status != 200) {
    error make {msg: $r.body.detail}
  } else {
    $r.body | get images
  }
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

def e [c] {
  $"(ansi red)($c)(ansi reset)"
}

def s [c] {
  $"(ansi green)($c)(ansi reset)"
}

# Right pad a given string to fill entire length of terminal.
def rpad [s] {
  let l = ((tput cols | into int) - ($s | str length) - 1)
  let f = 0..$l | each {' '} | str join
  $"($s)($f)"
}

# Prints on top of previous value.
def printo [s] {
  print -n $"\r(rpad $s)"
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
📄 (_ g)o              go to a page
")
}

# Picture download and view.
def main [] {
  # Get query parameters.
  mut query = {
    "is_nsfw": false,
    "gif": false,
    "orientation": "portrait",
    "included_tags": ["waifu"],
  }

  # re-render on next iteration
  mut render = true

  # fetch and save image on next iteration
  mut fetch = false

  # saved images
  mut cache = (
    ls ...(glob $"($env.XDG_PICTURES_DIR)/waifu/**/*.*")
    | where type == file
    | sort-by modified
    | get name
  )

  # index of image to show (usually the last saved image).
  mut p = ($cache | length) - 1
  
  if (($cache | length) == 0) {
    $fetch = true
  }

  loop {
    if ($fetch) {
      printo (i 'Loading...')
      $render = false
      try {
        let fp = (get-search $query | first | download)
        $cache = ($cache | append $fp)
        $p = $p + 1
        $render = true
      } catch {|e|
        printo (e $e.msg)
      }
      $fetch = false
    }

    if ($render) {
      clear
      chafa ($cache | get $p) --align mid,mid
      display-options $query
      printo (i $"  #($p + 1)")
    }

    match (input listen --types [key]).code {
      n => {
        $query = $query
        | update is_nsfw { 
          if ($in) { false } else { true } 
        }
        $fetch = true
      }
      o => {
        $query = $query
        | update orientation { 
          if ($in == "landscape") { "portrait" } else { "landscape" } 
        }
        $fetch = true
      }
      t => {
        $query = $query
        | update included_tags (tags-select | get name)
        $fetch = true
      }
      c => {
        $cache | get $p | wl-copy
        printo (s $"💕 ctrl-c! ($cache | get $p)")
        $render = false
      }
      w => {
        setbg ($cache | get $p) | ignore
        printo (s "💕 wallpaper set")
        $render = false
      }
      g => {
        let total = $cache | length
        printo $"[($p + 1)/($total)]: "
        $render = false
        try {
          let page = (input | into int) - 1
          if ($page > $total) or ($page <= 0) {
            printo (e "Not a valid page")
          } else {
            $p = $page
            $render = true
          }
        } catch {|e|
          printo (e $"($e.msg)")
        }
      }
      q|esc => (clear; break)
      b => {
        if ($p != 0) {
          $p = $p - 1
        }
        $render = true
      }
      f => {
        if ($p < (($cache | length) - 1)) {
          $p = $p + 1
        } else {
          $fetch = true
        }
      }
    }
  }
}
