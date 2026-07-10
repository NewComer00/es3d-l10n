-- LightingFixMod entry point
-- Save-load auto fix + F8 manual

local Config = require("config")
local Engine = require("engine")
local Triggers = require("triggers")

local ctx = Engine.new(Config)

Triggers.start(ctx)

RegisterKeyBind(Key.F8, function()
    ctx.manualFix()
end)

ctx.log("Loaded — save-load auto fix; F8 manual")
