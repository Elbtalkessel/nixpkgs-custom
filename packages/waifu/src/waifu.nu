#!/usr/bin/env nu

let DL_ROOT = [$env.XDG_PICTURES_DIR, waifu] | path join
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
def get-filename [item: record]: nothing -> string {
  (
    ["waifu", (if $item.is_nsfw { "nsfw" } else { "sfw" })]
    | append ($item.tags | each {|| $in.name})
    | append [$"($item.width)x($item.height)", $item.signature]
    | str join "."
  ) + $item.extension
}


def download []: record -> string {
  let p = ([$DL_ROOT, (get-filename $in)] | path join)
  http get $in.url
  | tee { save $p }
  | tee {|| notify-send "Saved" $p}
  $p
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
  mut saved = [];
  get-search { "included_tags": $tags }
  | first
  | download
  | open
  | imv -
}

# Downloads an image and returns its path.
def main [
  --nsfw (-n) = false,
  --landscape (-l) = false,
  --imv (-i): number = 0,
  ...tags: string,
]: nothing -> string {
  get-search { 
    "is_nsfw": $nsfw,
    "gif": false,
    "orientation": (if ($landscape) { "landscape" } else { null }),
    "included_tags": $tags,
  } 
  | first 
  | download
  | tee { 
    if ($imv != 0) {
      imv-msg $imv open $in
      imv-msg $imv next
    }
  }
}
