#!/usr/bin/env nu

let HEADERS = { "Content-Type": "application/json" }
let SETTINGS = $"($env.XDG_CONFIG_HOME)/wpdl/wpdlrc.yaml"

# Utilities

# Builds url including GET params.
# Params with value null are discarded.
def build-url [base: string, path: string, query = {}]: nothing -> string {
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

# UI for selecting item(s).
def select []: list -> list {
  $in
  | str join "\n"
  | fzf -m --header "Select an option" --footer "Tab to toggle, enter to select"
  | lines
}

# Purple underline text.
def _ [c] {
  $"(ansi pu)($c)(ansi reset)"
}

# Italic text.
def i [c] {
  $"(ansi pi)($c)(ansi reset)"
}

# Error text.
def e [c] {
  $"(ansi red)($c)(ansi reset)"
}

# Success text.
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

# ---

# Requests
# Download a file from given URL.
def download-image-url [url: string state: record]: nothing -> string {
  mut dirname_ = [
    $env.XDG_PICTURES_DIR,
    $state.provider,
    $state.group,
  ]
  if (($state.tags | length) > 0) {
    $dirname_ = ($dirname_ | append ($state.tags | first))
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
def query-image-url [settings: record, state: record]: nothing -> string {
  let path = ($state | format pattern $settings.base_path)
  let search = $settings.query_map
  | transpose k v 
  | reduce -f {} {|it, acc| 
    $acc 
    | insert $it.v ($state | get $it.k)
  }
  let headers = ($HEADERS | merge ($settings.headers | into record))
  
  let url = (build-url $settings.base_url $path $search)
  let r = (http get -e -f $url --headers $headers --raw)
  if ($r.status != 200) {
    error make {msg: ($r.body | jq -r $settings.selectors.error)}
  } else {
    $r.body | jq -r $settings.selectors.image
  }
}

# ----

# State / settings management
# Load settings file and retrive provider from it.
def get-settings [provider: string]: nothing -> record {
  let s = (open $SETTINGS)
  try {
    $s | get providers | get $provider
  } catch {
    error make { msg: $"Unknow provider ($provider), options are ($s | columns | str join ', ')." }
  }
}

# Load a saved state, or default form the settings file.
def load-state [provider: string]: nothing -> record {
  let p = ([$env.XDG_STATE_HOME, "wpdl", $"($provider).json"] | path join)
  if ($p | path exists) {
    open $p
  } else {
    (open $SETTINGS).state | update provider $provider
  }
}

# Save state into a file.
def save-state [provider: string, state: record] {
  let statedir = ([$env.XDG_STATE_HOME, "wpdl"] | path join)
  mkdir $statedir
  let p = ([$statedir, $"($provider).json"] | path join)
  $state | save -f $p
}

# ---

# Menu UI
def display-options [state: record] {
  print ($"
🌟 Provider        (i $state.provider)
🌟 Main tag        (i $state.tag)

💦 (_ G)roup           (i $state.group)
🙃 (_ O)rientation     (i $state.orientation)
🏷️ (_ T)ags            (i ($state.tags | str join ', '))

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
  # immutable and mutable states
  let settings = (get-settings $provider)
  mut state = (load-state $provider)

  # saved images
  let savedir = $"($env.XDG_PICTURES_DIR)/($state.provider)"
  mut cache = (
    ls ...(glob $"($savedir)/**/*.*")
    | where type == file
    | sort-by modified
    | get name
  )

  # index of an image in cache to show (usually the last saved image).
  mut p = ($cache | length) - 1
  # re-render on next iteration
  mut render = true
  # fetch and save image on next iteration
  mut fetch = (($cache | length) == 0)

  # main loop
  loop {
    if ($fetch) {
      printo (i 'Loading...')
      $render = false
      let url = (query-image-url $settings $state)
      let fp = (download-image-url $url $state)
      $cache = ($cache | append $fp)
      $p = $p + 1
      $render = true
      $fetch = false
    }

    if ($render) {
      clear

      let out = try {
        chafa ($cache | get $p) --align mid,mid --animate off
        { ok: true, msg: (i $"  #($p + 1)") }
      } catch {|err|
        { ok: false, msg: (e $err.msg) }
      }

      display-options $state
      printo $out.msg

      if not $out.ok {
        try { rm ($cache | get $p) }
        $cache = $cache | slice 0..-2
        if ($p > 0) {
          $p = $p - 1
        }
        $fetch = true;
        continue
      }
    }

    match (input listen --types [key]).code {
      g => {
        let g = ($settings.groups | columns | select | first)
        let t = ($settings.groups | get $g | first)
        $state = $state
        | merge {
          group: $g,
          tags: [$t],
          tag: $t
        }
        $fetch = true
      }
      o => {
        $state = $state
        | update orientation { 
          if ($in == "landscape") { "portrait" } else { "landscape" } 
        }
        $fetch = true
      }
      t => {
        let tags = ($settings.groups | get $state.group | select)
        $state = $state | merge {tags: $tags, tag: ($tags | first)}
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
      q|esc => (save-state $provider $state; clear; break)
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
