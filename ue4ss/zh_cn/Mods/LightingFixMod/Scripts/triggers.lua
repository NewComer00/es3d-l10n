local UEHelpers = require("UEHelpers")

local Triggers = {}

function Triggers.start(ctx)
    local config = ctx.config
    local prevLoadFromSlot = false
    local hookReady = {}

    local function textLooksLikeLoadComplete(textParam)
        if textParam == nil then return false end

        local ok, str = pcall(function()
            local text = textParam.get and textParam:get() or textParam
            if text == nil then return nil end
            if text.ToString then return text:ToString() end
            if text.GetValue then return text:GetValue() end
            return tostring(text)
        end)
        if not ok or str == nil then return false end

        local lower = string.lower(str)
        for _, marker in ipairs(config.LOAD_COMPLETE_MARKERS) do
            if string.find(lower, marker, 1, true) then
                return true
            end
        end
        return false
    end

    local function getMyGameInstance()
        local gi = UEHelpers.GetGameInstance()
        if ctx.isValid(gi) then
            local ok, name = pcall(function()
                return gi:GetClass():GetName()
            end)
            if ok and name and string.find(name, "mygameinstans", 1, true) then
                return gi
            end
        end

        local all = FindAllOf(config.MYGAMEINSTANS_CLASS)
        if all then
            for _, obj in ipairs(all) do
                if ctx.isValid(obj) then
                    return obj
                end
            end
        end
        return nil
    end

    local function registerSaveLoadHooks()
        if not hookReady.streamed then
            local ok = pcall(RegisterHook, config.HOOK_LOAD_STREAMED, function()
                ctx.requestAutoFix("LoadStreamedLevelsFromSlot")
            end)
            if ok then hookReady.streamed = true end
        end

        if not hookReady.hud then
            local ok = pcall(RegisterHook, config.HOOK_DISPLAY_HUD_TEXT, function(_self, inText)
                if not textLooksLikeLoadComplete(inText) then return end
                ctx.requestAutoFix("DisplayHUDText")
            end)
            if ok then hookReady.hud = true end
        end

        if hookReady.streamed and hookReady.hud and not hookReady.saveLoadLogged then
            hookReady.saveLoadLogged = true
            ctx.log("Save-load hooks registered (DisplayHUDText, LoadStreamedLevelsFromSlot)")
        end
    end

    local function pollLoadFromSlot()
        ExecuteInGameThread(function()
            local gi = getMyGameInstance()
            if not ctx.isValid(gi) then return end

            local ok, loadFromSlot = pcall(function()
                return gi[config.PROP_LOAD_FROM_SLOT]
            end)
            if not ok or loadFromSlot == nil then return end

            if prevLoadFromSlot and not loadFromSlot then
                ctx.requestAutoFix("LoadFromSlot")
            end
            prevLoadFromSlot = loadFromSlot
        end)
        ExecuteWithDelay(config.LOAD_FROM_SLOT_POLL_MS, pollLoadFromSlot)
    end

    local function pollHooks()
        registerSaveLoadHooks()
        ExecuteWithDelay(config.HOOK_POLL_MS, pollHooks)
    end

    pollLoadFromSlot()
    ExecuteWithDelay(config.HOOK_POLL_MS, pollHooks)
end

return Triggers
