## GIMD - I don't know how to name

$XDG_CONFIG_HOME/gimd/gimdrc.yaml:

```yaml
---
name: Wallpaper Dowloader Runtime Configuration

global:
  savedir:
    # Replative to XDG_PICTURES_DIR
    base: "GIMD"
    # group - providers[].groups
    # tag - a tag in a choosen group.
    path: "{group}/{tag}"

# Default application state.
state:
  group: "sfw"
  tag: "neko"
  tags: []
  # except waifu provider, doesn't work.
  orientation: "portrait"
  provider: "neko"

providers:
  # https://docs.waifu.im/docs/getting-started
  waifu:
    base_url: api.waifu.im
    base_path: /images
    headers:
      - Accept-Version: v6
    query_map:
      # Will map selected tags to this query param
      # https://docs.waifu.im/docs/tags#example
      tags: IncludedTags
    selectors:
      # jq queries
      image: ".items[0].url"
      tag: ".items[0].tags[0].slug"
      error: ".detail"
    groups:
      # Group name is up to you, tags are here
      # https://docs.waifu.im/docs/tags#listing-available-tags
      sfw:
        - waifu
        - genshin-impact
    request:
      server: generic

  # https://docs.night-api.com/
  night:
    base_url: api.night-api.com
    base_path: /images/{group}/{tag}/
    headers:
      - Authorization: <your-night-api-token>
    query_map: {}
    selectors:
      image: ".content.url"
      tag: ".content.type"
      error: ".content"
    groups:
      sfw:
        # https://docs.night-api.com/images/sfw/type
        - coffee
        - food
        - holo
        - kanna
    request:
      server: generic

  # https://waifu.pics/docs
  waifupics:
    base_url: api.waifu.pics
    base_path: /{group}/{tag}
    headers: {}
    query_map: {}
    selectors:
      image: ".url"
      error: ".message"
    groups:
      sfw:
        - waifu
        - neko
        - shinobu
        - megumin
        - bully
        - cuddle
        - cry
        - hug
        - awoo
        - kiss
        - lick
        - pat
        - smug
        - bonk
        - yeet
        - blush
        - smile
        - wave
        - highfive
        - handhold
        - nom
        - bite
        - glomp
        - slap
        - kill
        - kick
        - happy
        - wink
        - poke
        - dance
        - cringe
    request:
      server: generic

  # https://docs.nekos.best/getting-started/api-endpoints.html
  neko:
    base_url: nekos.best/api/v2
    base_path: /{tag}
    headers: {}
    query_map: {}
    selectors:
      image: ".results.[0].url"
    groups:
      sfw:
        - neko
        - waifu
        - husbando
        - kitsune
    request:
      server: generic
```
