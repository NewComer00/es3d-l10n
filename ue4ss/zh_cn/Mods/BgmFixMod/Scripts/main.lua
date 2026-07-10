-- BgmFixMod: first launch only — nudge volumes when setting.sav is missing

local Config = require("config")
local Engine = require("engine")

local ctx = Engine.new(Config)

ctx.startAudioFix()
ctx.log("Loaded — nudge mix + direct mysavegame save")
