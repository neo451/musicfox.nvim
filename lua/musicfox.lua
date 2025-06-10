local api, fn, uv = vim.api, vim.fn, vim.uv
local state = {}
local M = {}

-- TODO: save lyrics, download song
-- TODO: user command
-- TODO: lyrics in float win, notifiers, winbar
-- TODO: difference pos preset
-- TODO: close
-- TODO: winhighlight

---@class musicfox.config
---@field statusline { enabled: boolean, format: fun(musicfox.metadata): string }
local config = {
   statusline = {
      enabled = true,
      format = function(metadata)
         return string.format("%s: %s", metadata.artist, metadata.title)
      end,
   },
   dir = "~/.musicfox",
}

---@return vim.api.keyset.win_config
local function win_opts()
   local width = math.floor(vim.o.columns * 0.8)
   local height = math.floor(vim.o.lines * 0.8)
   local col = (vim.o.columns - width) / 2
   local row = (vim.o.lines - height) / 2
   return {
      relative = "editor",
      width = width,
      height = height,
      col = col,
      row = row,
      border = "solid",
   }
end

---@param buf integer
---@param enter boolean
---@return integer
local function open_win(buf, enter)
   local win = api.nvim_open_win(buf, enter, win_opts())
   vim.cmd("startinsert")
   state.group = api.nvim_create_augroup("musicfox", { clear = true })
   api.nvim_create_autocmd("VimResized", {
      group = state.group,
      callback = function()
         api.nvim_win_set_config(win, win_opts())
      end,
   })
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

local function tmux_has_session()
   if not vim.fn.executable("tmux") then
      return false
   end
   local output = vim.system({ "tmux", "list-sessions" }):wait().stdout
   if output and output:find("musicfox: ") then
      return true
   end
   return false
end

local function open()
   if not state.buf then
      local buf = api.nvim_create_buf(false, true)
      state.win = open_win(buf, true)
      local cmds = tmux_has_session() and { "tmux", "attach", "-t", "musicfox" } or { "musicfox" }
      fn.jobstart(cmds, { term = true })
      vim.bo[buf].filetype = "musicfox"
      vim.keymap.set("t", "q", function()
         api.nvim_del_augroup_by_id(state.group)
         state.group = nil
         vim.cmd("close")
      end, { buffer = buf })
      state.buf = buf
   else
      open_win(state.buf, true)
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

local function timestamp2seconds(timestamp)
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

   return total_seconds
end

local lyric_pattern = "%[(%d%d:%d%d%.%d%d)%](.+)"

---@return number[]
---@return string[]
local function parse_lyrics(str)
   local poses = {}
   local lyrics = {}
   for line in vim.gsplit(str, "\n") do
      local timestamp, lyric = line:match(lyric_pattern)
      if timestamp then
         local pos = timestamp2seconds(timestamp)
         assert(pos)
         poses[#poses + 1] = pos
         lyrics[#lyrics + 1] = lyric
      end
   end
   return poses, lyrics
end

---@class musicfox.metadata
---@field artist string
---@field album string
---@field title string
---@field artUrl string
---@field trackid string
---@field lyrics string[]

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

---@param cmd string
---@return function
local function playerctl(cmd)
   state.player_name = state.player_name or get_playername()
   return function()
      return vim.system({ "playerctl", "-p", state.player_name, cmd })
   end
end

---@return string
local function get_metadata()
   local obj = playerctl("metadata")():wait()
   assert(obj)
   return obj.stdout
end

---@return number
local function get_position()
   local obj = playerctl("position")():wait()
   assert(obj)
   return assert(tonumber(obj.stdout))
end

local function time_job(t, f)
   local timer = uv.new_timer()
   assert(timer)
   timer:start(0, t, vim.schedule_wrap(f))
end

---@return string?
local function update_lyric()
   local pos = get_position()
   local ts, ls = parse_lyrics(get_metadata())

   for i, t in ipairs(ts) do
      if pos <= t then
         return ls[i - 1]
      end
   end
end

local function float_lyrics()
   local buf = api.nvim_create_buf(false, true)
   state.lyrics = open_win(buf, false)
   api.nvim_win_set_config(state.lyrics, {
      height = 1,
      style = "minimal",
   })
   time_job(500, function()
      api.nvim_buf_set_lines(buf, 0, 1, false, { vim.g.musicfox_lyric })
   end)
end

---@return string?
local function update_metadata()
   local metadata = parse_metadata(get_metadata())
   return config.statusline.format(metadata)
end

M.setup = function(opts)
   if config.statusline.enabled then
      time_job(1000, function()
         vim.schedule(function()
            vim.g.musicfox = update_metadata()
            vim.g.musicfox_lyric = update_lyric()
         end)
      end)
   end
   config = vim.tbl_extend("force", config, opts)
   vim.keymap.set("n", "<Plug>MusicfoxOpen", open)
   vim.keymap.set("n", "<Plug>MusicfoxPlayPause", playerctl("play-pause"))
   vim.keymap.set("n", "<Plug>MusicfoxNext", playerctl("next"))
   vim.keymap.set("n", "<Plug>MusicfoxPrevious", playerctl("previous"))
   vim.keymap.set("n", "<Plug>MusicfoxLyrics", float_lyrics)
end

local function save_metadata()
   local metadata = parse_metadata(get_metadata())
   if vim.tbl_isempty(metadata) then
      return
   end
   local _, lyrics = parse_lyrics(get_metadata())
   metadata.lyrics = lyrics

   local dir = vim.fs.normalize(config.dir)

   vim.fn.mkdir(dir, "p")

   local basename = metadata.title .. ".json"

   local fp = vim.fs.joinpath(dir, basename)

   vim.fn.writefile({ vim.json.encode(metadata) }, fp)
end

M.timestamp2seconds = timestamp2seconds

return M
