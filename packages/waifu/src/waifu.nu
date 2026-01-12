#!/usr/bin/env nu

let HEADERS = {
  "Content-Type": "application/json",
}

# Builds url including GET params.
# Params with value null are discarded.
def get-url [base: string, path: string, query = {}]: nothing -> string {
  {
    "scheme": "https",
    "host": $base,
    "path": $path,
    "params": (
      $query
      | transpose k v 
      | where $it.v != null 
      | reduce -f {} {|i,a| $a | insert $i.k $i.v}
    )
  } | url join
}

def select []: list -> list {
  $in
  | str join "\n"
  | fzf -m --header "Select an option" --footer "Tab to toggle, enter to select"
  | lines
}

def download-image-url [url: string query: record]: nothing -> string {
  mut dirname_ = [
    $env.XDG_PICTURES_DIR,
    $query.provider,
    $query.group,
  ]
  if (($query.tags | length) > 0) {
    $dirname_ = ($dirname_ | append ($query.tags | first))
  }
  let dirname = ($dirname_ | path join)
  mkdir $dirname

  let filename = ($url | path basename)
  let filepath = ([$dirname, $filename] | path join)

  if ($filepath | path exists) {
    return $filepath
  }

  let bytes = (http get $url)
  $bytes | save $filepath
  return $filepath
}

# Searches for an image for download.
def query-image-url [settings: record, query: record]: nothing -> string {
  let path = ($query | format pattern $settings.list)
  let search = $settings.query 
  | transpose k v 
  | reduce -f {} {|it, acc| 
    $acc 
    | insert $it.v ($query | get $it.k)
  }
  let headers = ($HEADERS | merge ($settings.headers | into record))
  
  let url = (get-url $settings.base $path $search)
  let r = (http get -e -f $url --headers $headers --raw)
  if ($r.status != 200) {
    error make {msg: ($r.body | jq -r $settings.error_selector)}
  } else {
    $r.body | jq -r $settings.image_selector
  }
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

def get-settings [provider: string]: nothing -> record {
  let s = (open $"($env.XDG_CONFIG_HOME)/wpdl/wpdlrc.yaml")
  try {
    $s | get providers | get $provider
  } catch {
    error make { msg: $"Unknow provider ($provider), options are ($s | columns | str join ', ')." }
  }
}

def try-last-used [provider: string, query: record]: nothing -> record {
  let p = ([$env.XDG_STATE_HOME, "wpdl", $"($provider).json"] | path join)
  if ($p | path exists) {
    open $p
  } else {
    $query
  }
}

def save-state [provider: string, query: record] {
  let statedir = ([$env.XDG_STATE_HOME, "wpdl"] | path join)
  mkdir $statedir
  let p = ([$statedir, $"($provider).json"] | path join)
  $query | save -f $p
}

def display-options [query: record] {
  print ($"
💦 (_ G)roup           (i ($query.group))
🙃 (_ O)rientation     (i ($query.orientation))
🏷️ (_ T)ags            (i ($query.tags | str join ', '))

👈 (_ b)ack            show previous image
👉 (_ f)orward         navigate to the next image or fetch new one
🫵 (_ c)opy            copy image path to the clipboard
🫰 (_ w)allpaper       set as wallpaper
🤌 (_ q)uit            exit program
📄 (_ j)ump            jump to a page
")
}

# Picture download and view.
def main [provider: string = "waifu"] {
  # global provider settings
  let settings = get-settings $provider

  # Get query parameters.
  mut query = (try-last-used $provider {
    "group": ($settings.groups | columns | first),
    "tag": "",
    # Just [<tag>], workaround.
    "tags": [],
    "orientation": "portrait",
    "provider": $provider,
  })

  # re-render on next iteration
  mut render = true

  # fetch and save image on next iteration
  mut fetch = false

  let basedir = $"($env.XDG_PICTURES_DIR)/($query.provider)"

  # saved images
  mut cache = (
    ls ...(glob $"($basedir)/**/*.*")
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
      let url = (query-image-url $settings $query)
      let fp = (download-image-url $url $query)
      $cache = ($cache | append $fp)
      $p = $p + 1
      $render = true
      $fetch = false
    }

    if ($render) {
      clear
      chafa ($cache | get $p) --align mid,mid --animate off
      display-options $query
      printo (i $"  #($p + 1)")
    }

    match (input listen --types [key]).code {
      g => {
        $query = $query
        | update group ($settings.groups | columns | select | first)
        | update tags []
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
        let tag = ($settings.groups | get $query.group | select)
        $query = $query | merge {tags: [$tag], tag: $tag}
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
      j => {
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
      q|esc => (save-state $provider $query; clear; break)
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
