local api, fn, uv = vim.api, vim.fn, vim.uv
local state = {}

local config = {
	statusline = {
		enabled = true,
		format = function(metadata)
			return string.format("%s: %s", metadata.artist, metadata.title)
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
	title = "musicfox xesam:title%s+(.+)",
	artUrl = "musicfox mpris:artUrl%s+(.+)",
	trackid = "musicfox mpris:trackid%s+(.+)",
	length = "musicfox mpris:length%s+(.+)",
}

local lyrics = [[
[00:01.00]作曲 : 野田洋次郎
[00:31.40]まだこの世界は [看来这世界]
[00:34.40]僕を飼いならしていたいみたいな [似乎还想要驯服我]
[00:39.40]望み通リいいだろう?美しくもがくよ [那就如你所愿吧 我会美丽地挣扎到底]
[00:47.40]互いの砂時計 [看着彼此的沙漏]
[00:51.40]眺めながらキスをしようよ [温柔地轻吻吧]
[00:55.40]さよならから一番遠い [分别后最遥远的地方]
[00:59.40]場所で待ち合わせよ [让我们彼此相约吧]
]]

local function convert_timestamp_to_seconds(timestamp)
	-- Split the timestamp into minutes and the remaining part
	local minutes_str, rest = timestamp:match("^(%d+):(.+)$")
	if not minutes_str then
		return nil -- invalid format
	end

	-- Split the remaining part into seconds and fractions
	local seconds_str, fractions_str = rest:match("^(%d+)%.?(%d*)$")
	if not seconds_str then
		return nil -- invalid format
	end

	-- Convert parts to numbers
	local minutes = tonumber(minutes_str)
	local seconds = tonumber(seconds_str)
	local fractions = tonumber(fractions_str) or 0
	local fraction_length = #fractions_str

	-- Calculate total seconds with floating point precision
	local total_seconds = minutes * 60 + seconds + fractions / (10 ^ fraction_length)

	return total_seconds / 10
end

local lyric_pattern = "%[(%d%d:%d%d%.%d%d)%](.+)"

local function parse_lyrics(str)
	local time2lyric = {}
	for line in vim.gsplit(str, "\n") do
		local timestamp, lyric = line:match(lyric_pattern)
		if timestamp then
			local pos = convert_timestamp_to_seconds(timestamp)
			assert(pos)
			time2lyric[pos] = lyric
		end
	end
	return time2lyric
end

---@class musicfox.metadata
---@field artist string
---@field album string
---@field title string
---@field artUrl string
---@field trackid string

---@param str string
---@return musicfox.metadata
local function parse_metadata(str)
	local res = {}
	for line in vim.gsplit(str, "\n") do
		for k, pattern in pairs(name2pattern) do
			local cap = line:match(pattern)
			if cap then
				if k == "length" then
					cap = tonumber(cap)
				end
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

local function get_metadata()
	local metadata = vim.system({ "playerctl", "-p", state.player_name, "metadata" }):wait()
	return metadata.stdout
end

---@return string?
local function update_lyric()
	state.player_name = state.player_name or get_playername()
	local obj = vim.system({ "playerctl", "-p", state.player_name, "position" }):wait()

	if obj then
		-- BUG:
		local pos = tonumber(obj.stdout)
		local t2l = parse_lyrics(get_metadata())

		local ts = vim.tbl_keys(t2l)
		-- vim.print(pos, ts)

		for i, t in ipairs(ts) do
			if pos <= t then
				return t2l[ts[i - 1]]
			end
		end
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
					vim.g.musicfox_lyric = update_lyric()
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
