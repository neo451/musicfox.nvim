# musicfox.nvim

Neovim plugin for go-musicfox, a TUI netease client.

## Requirements

- [go-musicfox](https://github.com/go-musicfox/go-musicfox)
- [playerctl](https://github.com/altdesktop/playerctl)

## Installation

**lazy.nvim:**

```lua
return { "neo451/musicfox.nvim", opts = {} }
```

## Mappings

Provides following plug mappings:

- `MusicfoxOpen`: Open TUI in a floating window
- `MusicfoxPlayPause`: Toggle between play and pause
- `MusicfoxNext`: Next Song
- `MusicfoxPrevious`: Previous Song

Map like:

```lua
vim.keymap.set("n", "<leader>mf", "<Plug>MusicfoxOpen")
```

## Statusline

If using lualine:

```lua
require("lualine").setup({
   sections = {
      lualine_x = {
         "g:musicfox_lyric",
         "g:musicfox",
      },
   },
})
```

By default it formats current playing song as `{{artist}}: {{song}}`, to change it:

```lua
---@class musicfox.metadata
---@field artist string
---@field album string
---@field title string
---@field artUrl string
---@field trackid string

require("musicfox").setup({
   statusline = {
      format = function(metadata)
         return string.format("%s [%s]: %s", metadata.artist, metadata.album, metadata.title)
      end,
   },
})
```

## Tmux

If you want a persistent instance of musicfox while being able to see the tui in neovim, use tmux, this plugin will use the existing tmux session named `musicfox`. Launch one like:

```bash
tmux new -s musicfox
musicfox
```

## TODO

- user command
- float window lyrics
- notifier lyrics
  - mini.notify
  - nvim-notify
  - snakcs.notifier
- more advanced action beyond `playerctl`
  - heart
  - download
  - play mode
  - ...
