local M = require("musicfox")

local new_set, expect = MiniTest.new_set, MiniTest.expect

local eq = expect.equality

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

T = new_set()

T["timestamp2seconds"] = function()
	local ts = "00:55.40"
	eq(M.timestamp2seconds(ts), 55)
end

return T
