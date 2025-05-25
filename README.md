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

- `MusicfoxOpen`
- `MusicfoxPlayPause`
- `MusicfoxNext`
- `MusicfoxPrevious`

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
			"g:musicfox",
		},
	},
})
```

By default it formats current playing song as `{{artist}}: {{song}}`

**TODO:** Lyrics
