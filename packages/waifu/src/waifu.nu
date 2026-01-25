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
  print $"\r(rpad $s)"
}

def log [s: string] {
  print $"(ansi dgrd)($s)(ansi reset)"
}

# ---

# Requests
# Download a file from given URL.
def download-image-url [url: string, state: record, settings: record]: nothing -> string {
  let dirname = [
    $env.XDG_PICTURES_DIR,
    $settings.global.savedir.base,
    ($state | format pattern $settings.global.savedir.path),
  ] | path join
  mkdir $dirname

  let filename = ($url | path basename)
  let filepath = ([$dirname, $filename] | path join)

  if ($filepath | path exists) {
    log $"EXISTS ($filepath)"
    return $filepath
  }
  
  log $"GET ($url)"
  let bytes = (http get $url)
  log $"SAVE ($filepath)"
  $bytes | save $filepath
  return $filepath
}

# Searches for an image for download.
def query-image-url [settings: record, state: record]: nothing -> string {
  let path = ($state | format pattern $settings.x.base_path)
  let search = $settings.x.query_map
  | transpose k v 
  | reduce -f {} {|it, acc| 
    $acc 
    | insert $it.v ($state | get $it.k)
  }
  let headers = ($HEADERS | merge ($settings.x.headers | into record))
  
  let url = (build-url $settings.x.base_url $path $search)
  log $"GET ($url)"
  mut r = null
  if ($settings.x.request.server == "stash") {
    let cq = { query: ($settings.x.request.count_query | str replace -rma '\s' '') }
    log ($cq | to json)
    let cr = (http post --content-type application/json -e -f $url --headers $headers --raw $cq)
    log $"GOT ($cr.body)"
    let page = (random int 0..($cr.body | jq -r $settings.x.selectors.count | into int)) | into string
    let iq = { query: ($settings.x.request.image_query | str replace '{page}' $page | str replace -rma '\s' '') }
    $r = http post --content-type application/json -e -f $url --headers $headers --raw $iq
  } else {
    $r = (http get -e -f $url --headers $headers --raw)
  }
  log $"GOT ($r.body)"
  if ($r.status != 200) {
    error make {msg: ($r.body | jq -r $settings.x.selectors.error)}
  } else {
    $r.body | jq -r $settings.x.selectors.image
  }
}

def request-image [settings: record, state: record]: nothing -> string {
  let url = (query-image-url $settings $state)
  download-image-url $url $state $settings
}

# ----

# State / settings management
# Load settings file and retrive provider from it.
def get-settings [provider: string]: nothing -> record {
  let s = (open $SETTINGS)
  try {
    $s | insert x ($s | get providers | get $provider)
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
    let settings = (open $SETTINGS)
    let groups = (
      $settings.providers 
      | get $provider 
      | get groups
    )
    let group = ($groups | columns | first)
    let tag = ($groups | get $group | first)
    $settings.state
    | merge {
      provider: $provider,
      group: $group,
      tag: $tag,
      tags: [$tag],
    }
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
  let appdir = [
    $env.XDG_PICTURES_DIR
    $settings.global.savedir.base
  ] | path join
  mut cache = (
    ls ...(glob $"($appdir)/**/*.*")
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
      let fp = request-image $settings $state
      $cache = ($cache | append $fp)
      $p = $p + 1
      $render = true
      $fetch = false
    }

    if ($render) {
      clear

      let out = try {
        let fp = ($cache | get $p)
        chafa $fp --align mid,mid --animate off
        { ok: true, msg: (i $"#($p + 1) ($fp)") }
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
        let g = (
          $settings.x.groups 
          | columns 
          | select 
          | first
        )
        if ($g == null) {
          continue
        }
        let t = ($settings.x.groups | get $g | first)
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
        let tag = (
          $settings.x.groups 
          | get $state.group 
          | select
          | first
        )
        if ($tag == null) {
          continue
        }
        $state = (
          $state 
          | merge { tags: [$tag], tag: $tag }
        )
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
