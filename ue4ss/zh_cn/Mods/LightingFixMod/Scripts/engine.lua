local UEHelpers = require("UEHelpers")

local Engine = {}

function Engine.new(config)
    local ctx = {
        config = config,
        fixGeneration = 0,
        autoFixGeneration = 0,
        helperWidget = nil,
    }

    function ctx.log(msg)
        print(config.LOG_PREFIX .. msg)
    end

    function ctx.isValid(obj)
        return obj ~= nil and obj.IsValid and obj:IsValid()
    end

    function ctx.clearHelperWidget()
        ctx.helperWidget = nil
    end

    function ctx.getSceneDelay()
        return config.SCENES.in_game.delay_ms
    end

    local function trySettingsObject(obj)
        if obj == nil then return nil end
        local ok, quality = pcall(function()
            return obj:GetVisualEffectQuality()
        end)
        if ok and quality ~= nil then return obj end
        return nil
    end

    function ctx.getGameUserSettings()
        local ok, settings = pcall(function()
            return UEHelpers.GetGameplayStatics():GetGameUserSettings()
        end)
        local s = trySettingsObject(ok and settings or nil)
        if s then return s end

        ok, settings = pcall(FindFirstOf, "GameUserSettings")
        s = trySettingsObject(ok and settings or nil)
        if s then return s end

        local all = FindAllOf("GameUserSettings")
        if all then
            for _, obj in ipairs(all) do
                s = trySettingsObject(obj)
                if s then return s end
            end
        end

        ok, settings = pcall(function()
            local engine = UEHelpers.GetEngine()
            if engine and engine.GameUserSettings then
                return engine.GameUserSettings
            end
            return nil
        end)
        return trySettingsObject(ok and settings or nil)
    end

    function ctx.canRunLightingFix()
        if not ctx.getGameUserSettings() then
            return false
        end
        return ctx.isValid(UEHelpers.GetPlayerController())
    end

    local function findLiveOptionsWidget()
        local all = FindAllOf("options7_C")
        if not all then return nil end
        for _, widget in ipairs(all) do
            if ctx.isValid(widget) then
                return widget
            end
        end
        return nil
    end

    local function createHelperOptionsWidget()
        local pc = UEHelpers.GetPlayerController()
        if not ctx.isValid(pc) then
            return nil
        end

        local class = StaticFindObject(config.OPTIONS_CLASS_PATH)
        if not class then
            ctx.log("options7 class not found")
            return nil
        end

        local widget = nil
        local wbp = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        if wbp then
            local ok, created = pcall(function()
                return wbp:Create(class, pc)
            end)
            if ok then widget = created end
        end

        if not ctx.isValid(widget) then
            local ok, created = pcall(function()
                return StaticConstructObject(class, pc)
            end)
            if ok then widget = created end
        end

        if not ctx.isValid(widget) then
            ctx.log("Failed to create helper options7 widget")
            return nil
        end

        ctx.log("Created helper options7 widget")
        return widget
    end

    function ctx.getOptionsWidget(forceHelper)
        if not forceHelper then
            local live = findLiveOptionsWidget()
            if live then
                return live, "live"
            end
        end

        if ctx.isValid(ctx.helperWidget) then
            return ctx.helperWidget, "helper"
        end

        ctx.helperWidget = createHelperOptionsWidget()
        if ctx.helperWidget then
            return ctx.helperWidget, "helper"
        end

        return nil, nil
    end

    local function ensureVolumeDelegates(options, source)
        if source ~= "live" then
            return true
        end

        local ok, err = pcall(function()
            options[config.FN_VIDEO](options)
        end)
        if ok then
            ctx.log("Bound volume dispa delegates (live)")
            return true
        end

        ctx.log("Delegate bind failed: " .. tostring(err))
        return false
    end

    local function getVolumeGame()
        local gi = UEHelpers.GetGameInstance()
        if not ctx.isValid(gi) then return nil end

        local ok, volume = pcall(function()
            return gi[config.PROP_VOLUME_GAME]
        end)
        if ok and volume ~= nil then
            return volume
        end
        return nil
    end

    local function getPostSettingsPreset(gi)
        local ok, soven = pcall(function()
            return gi[config.PROP_SOVEN]
        end)
        if ok and soven then
            return gi.NewVar_3
        end
        return gi.NewVar_2
    end

    local function broadcastVolumeDispa(options)
        local volumeGame = getVolumeGame()
        if volumeGame == nil then
            ctx.log("volume game not found on GameInstance")
            return false
        end

        local delegate = options[config.DELEGATE_VOLUME_DISPA]
        if delegate ~= nil then
            local ok, err = pcall(function()
                delegate:Broadcast(volumeGame)
            end)
            if ok then
                ctx.log("volume dispa broadcast ok")
                return true
            end
            ctx.log("volume dispa Broadcast failed: " .. tostring(err))
        end

        local gi = UEHelpers.GetGameInstance()
        if ctx.isValid(gi) then
            local ok, err = pcall(function()
                local post = gi.post
                local settings = getPostSettingsPreset(gi)
                if ctx.isValid(post) and settings ~= nil then
                    post.Settings = settings
                end
            end)
            if ok then
                ctx.log("post.Settings fallback ok")
                return true
            end
            ctx.log("post.Settings fallback failed: " .. tostring(err))
        end

        return false
    end

    function ctx.applyPostSettingsFallbackOnly()
        local gi = UEHelpers.GetGameInstance()
        if not ctx.isValid(gi) then return false end

        local ok, err = pcall(function()
            local post = gi.post
            local settings = getPostSettingsPreset(gi)
            if ctx.isValid(post) and settings ~= nil then
                post.Settings = settings
            end
        end)
        if ok then
            ctx.log("post.Settings fallback ok (main menu)")
            return true
        end
        ctx.log("post.Settings fallback failed: " .. tostring(err))
        return false
    end

    local function finishLightingFix(options, source)
        if source == "live" then
            broadcastVolumeDispa(options)
        else
            ctx.log("Skipping volume dispa on helper widget")
        end

        local pc = UEHelpers.GetPlayerController()
        if ctx.isValid(pc) then
            pcall(function()
                pc:SetFocusToGameViewport()
            end)
        end
    end

    local function applyViaOptionsBlueprint(options, level)
        local textLib = UEHelpers.GetKismetTextLibrary()
        if not ctx.isValid(textLib) then
            return false
        end

        local inText = textLib:Conv_StringToText(config.VISUAL_EFFECTS_LABEL)
        local outText = {}
        local ok, err = pcall(function()
            options[config.FN_APPLY_SETTINGS](options, inText, level, outText)
        end)

        if ok then
            ctx.log("options7.primenyaem level=" .. tostring(level))
            return true
        end

        ctx.log("options7.primenyaem failed: " .. tostring(err))
        return false
    end

    local function applyVisualEffectQuality(settings, options, level, reason)
        local usedMenuPath = applyViaOptionsBlueprint(options, level)

        if not usedMenuPath then
            pcall(function()
                settings:SetVisualEffectQuality(level)
                settings:ApplySettings(true)
                settings:SaveSettings()
            end)
            ctx.log(string.format("VisualEffectQuality=%d (%s)", level, reason))
        end
    end

    local function cycleVisualEffectQualitySettingsOnly(reason)
        ExecuteInGameThread(function()
            local settings = ctx.getGameUserSettings()
            if not settings then
                ctx.log("GameUserSettings not found (" .. reason .. ")")
                return
            end

            ctx.fixGeneration = ctx.fixGeneration + 1
            local generation = ctx.fixGeneration

            local ok, original = pcall(function()
                return settings:GetVisualEffectQuality()
            end)
            if not ok or original == nil then
                ctx.log("GetVisualEffectQuality failed (" .. reason .. ")")
                return
            end

            local temporary
            if original == 0 then
                temporary = 1
            else
                temporary = original - 1
            end
            ctx.log(string.format("Visual effects cycle %d -> %d -> %d (%s, settings-only)", original, temporary, original, reason))

            pcall(function()
                settings:SetVisualEffectQuality(temporary)
                settings:ApplySettings(true)
            end)

            ExecuteWithDelay(config.RESTORE_DELAY_MS, function()
                if generation ~= ctx.fixGeneration then return end
                ExecuteInGameThread(function()
                    local s = ctx.getGameUserSettings()
                    if not s then return end
                    pcall(function()
                        s:SetVisualEffectQuality(original)
                        s:ApplySettings(true)
                    end)
                    ctx.applyPostSettingsFallbackOnly()
                    local pc = UEHelpers.GetPlayerController()
                    if ctx.isValid(pc) then
                        pcall(function()
                            pc:SetFocusToGameViewport()
                        end)
                    end
                end)
            end)
        end)
    end

    local function cycleVisualEffectQuality(reason)
        ExecuteInGameThread(function()
            local settings = ctx.getGameUserSettings()
            if not settings then
                ctx.log("GameUserSettings not found (" .. reason .. ")")
                return
            end

            local options, source = ctx.getOptionsWidget(false)
            if not options then
                ctx.log("options7 widget unavailable (" .. reason .. ")")
                return
            end

            if not ensureVolumeDelegates(options, source) then
                ctx.log("Continuing without delegate bind")
            end

            ctx.fixGeneration = ctx.fixGeneration + 1
            local generation = ctx.fixGeneration
            local widgetSource = source

            local ok, original = pcall(function()
                return settings:GetVisualEffectQuality()
            end)
            if not ok or original == nil then
                ctx.log("GetVisualEffectQuality failed (" .. reason .. ")")
                return
            end

            local temporary
            if original == 0 then
                temporary = 1
            else
                temporary = original - 1
            end
            ctx.log(string.format("Visual effects cycle %d -> %d -> %d (%s)", original, temporary, original, reason))

            applyVisualEffectQuality(settings, options, temporary, reason .. (original == 0 and " raise" or " lower"))

            ExecuteWithDelay(config.RESTORE_DELAY_MS, function()
                if generation ~= ctx.fixGeneration then return end
                ExecuteInGameThread(function()
                    local s = ctx.getGameUserSettings()
                    local opts = options
                    local restoreSource = widgetSource
                    if not ctx.isValid(opts) then
                        opts, restoreSource = ctx.getOptionsWidget(true)
                    end
                    if not s or not opts then return end

                    applyVisualEffectQuality(s, opts, original, reason .. " restore")
                    finishLightingFix(opts, restoreSource)
                end)
            end)
        end)
    end

    local function runFixWithRetry(reason, attemptsLeft)
        attemptsLeft = attemptsLeft or config.AUTO_RETRY_MAX
        ExecuteInGameThread(function()
            if not ctx.canRunLightingFix() then
                if attemptsLeft > 0 then
                    ctx.log("Waiting for PC/settings (" .. reason .. "), retries=" .. tostring(attemptsLeft))
                    ExecuteWithDelay(config.AUTO_RETRY_INTERVAL_MS, function()
                        runFixWithRetry(reason, attemptsLeft - 1)
                    end)
                else
                    ctx.log("Auto fix aborted (" .. reason .. "): PC/settings unavailable")
                end
                return
            end
            cycleVisualEffectQuality(reason)
        end)
    end

    function ctx.requestAutoFix(reason)
        ctx.autoFixGeneration = ctx.autoFixGeneration + 1
        local generation = ctx.autoFixGeneration
        local delayMs = ctx.getSceneDelay()
        ctx.log("Auto fix scheduled (in_game/full) (" .. reason .. "), delay " .. tostring(delayMs) .. "ms")

        ExecuteWithDelay(delayMs, function()
            if generation ~= ctx.autoFixGeneration then return end
            ctx.clearHelperWidget()
            runFixWithRetry(reason)
        end)
    end

    function ctx.manualFix()
        runFixWithRetry("hotkey")
    end

    return ctx
end

return Engine
