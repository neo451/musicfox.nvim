local api, fn, uv = vim.api, vim.fn, vim.uv
local state = {}

local config = {
	statusline = {
		enabled = true,
		format = function(metadata)
			return string.format("%s: %s", metadata.artist, metadata.album)
		end,
	},
}

---@param buf integer
---@return integer
local function open_win(buf)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local col = (vim.o.columns - width) / 2
	local row = (vim.o.lines - height) / 2
	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
	})
	vim.cmd("startinsert")
	return win
end

---@return string?
local function get_playername()
	if not vim.fn.executable("playerctl") then
		error("no playerctl found")
	end
	local obj = vim.system({ "playerctl", "-l" }):wait()

	for line in vim.gsplit(obj.stdout, "\n") do
		if line:find("musicfox") then
			return line
		end
	end
end

local function open()
	if not state.buf then
		local buf = api.nvim_create_buf(false, true)
		state.win = open_win(buf)
		fn.jobstart({ "musicfox" }, { term = true })
		vim.bo[buf].filetype = "musicfox"
		vim.keymap.set("t", "q", "<cmd>close<cr>", { buffer = buf })
		state.buf = buf
	else
		open_win(state.buf)
	end
end

local name2pattern = {
	artist = "musicfox xesam:artist%s+(.+)",
	album = "musicfox xesam:album%s+(.+)",
}

---@class musicfox.metadata
---@field artist string
---@field album string

---@param str string
---@return musicfox.metadata
local function parse_metadata(str)
	local res = {}
	for line in vim.gsplit(str, "\n") do
		for k, pattern in pairs(name2pattern) do
			local cap = line:match(pattern)
			if cap then
				res[k] = cap
			end
		end
	end
	return res
end

---@return string?
local function update_statusline()
	state.player_name = state.player_name or get_playername()
	local obj = vim.system({ "playerctl", "-p", state.player_name, "metadata" }):wait()

	if obj then
		local metadata = parse_metadata(obj.stdout)
		return config.statusline.format(metadata)
	else
		error()
	end
end

---@param cmd string
---@return function
local function playerctl(cmd)
	state.player_name = state.player_name or get_playername()
	return function()
		vim.system({ "playerctl", "-p", state.player_name, cmd })
	end
end

return {
	setup = function(opts)
		if config.statusline.enabled then
			local timer = uv.new_timer()
			assert(timer)

			timer:start(0, 1000, function()
				vim.schedule(function()
					vim.g.musicfox = update_statusline()
				end)
			end)
		end
		config = vim.tbl_extend("force", config, opts)
		vim.keymap.set("n", "<Plug>MusicfoxOpen", open)
		vim.keymap.set("n", "<Plug>MusicfoxPlayPause", playerctl("play-pause"))
		vim.keymap.set("n", "<Plug>MusicfoxNext", playerctl("next"))
		vim.keymap.set("n", "<Plug>MusicfoxPrevious", playerctl("previous"))
	end,
}
