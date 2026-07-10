local UEHelpers = require("UEHelpers")

local Engine = {}

function Engine.new(config)
    local ctx = {
        config = config,
        nudgeGeneration = 0,
        helperWidget = nil,
        fixStarted = false,
        periodicActive = false,
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

    function ctx.slotSaveExists()
        local gs = UEHelpers.GetGameplayStatics()
        if not gs then
            return false
        end

        local exists = false
        pcall(function()
            exists = gs:DoesSaveGameExist(config.SAVE_SLOT, config.SAVE_USER_INDEX)
        end)
        return exists
    end

    function ctx.settingsSaveExists()
        if ctx.slotSaveExists() then
            return true
        end

        local localAppData = os.getenv("LOCALAPPDATA")
        if not localAppData or localAppData == "" then
            return false
        end

        local path = localAppData .. "\\" .. config.SETTINGS_SAVE_RELATIVE
        local ok, file = pcall(io.open, path, "rb")
        if ok and file then
            file:close()
            return true
        end
        return false
    end

    local function readGiField(gi, field, default)
        local ok, val = pcall(function()
            return gi[field]
        end)
        if ok and val ~= nil then
            return val
        end
        return default
    end

    local function findLiveOptionsWidget()
        local all = FindAllOf("options7_C")
        if not all then
            return nil
        end
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

    local function prepareAudioPanel(options)
        pcall(function()
            if options[config.FN_CREATE] then
                options[config.FN_CREATE](options)
            end
        end)
        pcall(function()
            if options[config.FN_AUDIO] then
                options[config.FN_AUDIO](options)
            end
        end)
    end

    local function ensureVolumeDelegates(options, source)
        if source ~= "live" then
            return
        end
        pcall(function()
            options[config.FN_VIDEO](options)
        end)
    end

    local function getVolumeGame()
        local gi = UEHelpers.GetGameInstance()
        if not ctx.isValid(gi) then
            return nil
        end
        return readGiField(gi, config.PROP_VOLUME_GAME, nil)
    end

    local function broadcastVolumeDispa(options)
        local volumeGame = getVolumeGame()
        if volumeGame == nil then
            return false
        end

        local delegate = options[config.DELEGATE_VOLUME_DISPA]
        if delegate == nil then
            return false
        end

        local ok, err = pcall(function()
            delegate:Broadcast(volumeGame)
        end)
        if ok then
            ctx.log("volume dispa broadcast ok")
            return true
        end
        ctx.log("volume dispa failed: " .. tostring(err))
        return false
    end

    function ctx.directSaveAudioSettings()
        local gs = UEHelpers.GetGameplayStatics()
        local gi = UEHelpers.GetGameInstance()
        if not gs or not ctx.isValid(gi) then
            ctx.log("Direct save failed: GS/GI unavailable")
            return false
        end

        local volGame = readGiField(gi, "volume game", 0.5)
        local volVoice = readGiField(gi, "volume game voice", 0.5)
        local volEffect = readGiField(gi, "volume game effeckt", 0.5)
        local mouseSens = readGiField(gi, config.PROP_MOUSE_SENS, 0.5)

        local saveClass = StaticFindObject(config.MYSAVEGAME_CLASS)
        if not saveClass then
            ctx.log("Direct save failed: mysavegame class not found")
            return false
        end

        local save = nil
        local ok, created = pcall(function()
            return gs:CreateSaveGameObject(saveClass)
        end)
        if ok then
            save = created
        end
        if not ctx.isValid(save) then
            ctx.log("Direct save failed: CreateSaveGameObject")
            return false
        end

        local saveFn = save[config.FN_SAVE_AUDIO]
        if saveFn then
            ok = pcall(function()
                saveFn(save, volGame, volVoice, volEffect, save, config.SAVE_SLOT, mouseSens)
            end)
            if ok then
                ctx.log("сохранения звука(настроки) called")
                if ctx.slotSaveExists() then
                    ctx.log("Direct save ok (blueprint save fn)")
                    return true
                end
            else
                ctx.log("сохранения звука(настроки) failed")
            end
        else
            ctx.log("Save fn not found on mysavegame")
        end

        pcall(function()
            save["volume game"] = volGame
            save["volume game voice"] = volVoice
            save["volume game effeckt"] = volEffect
        end)

        ok = pcall(function()
            return gs:SaveGameToSlot(save, config.SAVE_SLOT, config.SAVE_USER_INDEX)
        end)
        if ok and ctx.slotSaveExists() then
            ctx.log("Direct save ok (SaveGameToSlot fallback)")
            return true
        end

        ctx.log("Direct save failed")
        return false
    end

    local function temporaryVolume(current)
        local step = config.VOLUME_NUDGE_STEP
        local temporary = current - step
        if temporary < 0 then
            temporary = current + step
        end
        if temporary == current then
            temporary = current + step
        end
        return temporary
    end

    local channel = config.VOLUME_CHANNEL

    local function getMusicVolume(options)
        local gi = UEHelpers.GetGameInstance()
        if ctx.isValid(gi) then
            local vol = readGiField(gi, channel.giProp, nil)
            if vol ~= nil then
                return vol
            end
        end

        local slider = options[channel.slider]
        if ctx.isValid(slider) then
            local ok, value = pcall(function()
                return slider:GetValue()
            end)
            if ok and value ~= nil then
                return value
            end
        end

        return nil
    end

    local function applyMusicVolume(options, volume)
        local handler = options[channel.handler]
        if handler then
            local ok, err = pcall(function()
                handler(options, volume)
            end)
            if ok then
                return true
            end
            ctx.log(channel.label .. " handler failed: " .. tostring(err))
        end

        local slider = options[channel.slider]
        if ctx.isValid(slider) then
            local ok, err = pcall(function()
                slider:SetValue(volume)
            end)
            if ok then
                return true
            end
        end

        return false
    end

    function ctx.stopPeriodic(reason)
        if not ctx.periodicActive then
            return
        end
        ctx.periodicActive = false
        ctx.nudgeGeneration = ctx.nudgeGeneration + 1
        ctx.clearHelperWidget()
        ctx.log("Periodic fix stopped (" .. reason .. ")")
    end

    function ctx.pollSaveSlot(attemptsLeft, reason, onGiveUp)
        if not ctx.periodicActive then
            return
        end

        if ctx.slotSaveExists() then
            ctx.stopPeriodic(reason)
            return
        end

        if attemptsLeft > 0 then
            ExecuteWithDelay(config.SAVE_DETECT_POLL_MS, function()
                ctx.pollSaveSlot(attemptsLeft - 1, reason, onGiveUp)
            end)
            return
        end

        ctx.log("Save slot not ready (" .. reason .. ")")
        if onGiveUp then
            onGiveUp()
        end
    end

    function ctx.scheduleNextPeriodic()
        if not ctx.periodicActive then
            return
        end
        ExecuteWithDelay(config.PERIODIC_INTERVAL_MS, function()
            ctx.runPeriodicTick()
        end)
    end

    function ctx.runAudioFixCycle(reason, onComplete)
        ExecuteInGameThread(function()
            local options, source = ctx.getOptionsWidget(false)
            if not options then
                ctx.log("Fix skipped: options7 unavailable (" .. reason .. ")")
                if onComplete then onComplete(false) end
                return
            end

            ensureVolumeDelegates(options, source)
            prepareAudioPanel(options)

            local original = getMusicVolume(options)
            if original == nil then
                ctx.log("Music volume unknown (" .. reason .. ")")
                if onComplete then onComplete(false) end
                return
            end

            local temporary = temporaryVolume(original)
            ctx.log(string.format(
                "%s nudge %.3f -> %.3f -> %.3f (%s)",
                channel.label, original, temporary, original, reason
            ))

            if not applyMusicVolume(options, temporary) then
                ctx.log("Volume nudge failed (" .. reason .. ")")
                if onComplete then onComplete(false) end
                return
            end

            ctx.nudgeGeneration = ctx.nudgeGeneration + 1
            local generation = ctx.nudgeGeneration

            ExecuteWithDelay(config.RESTORE_DELAY_MS, function()
                if generation ~= ctx.nudgeGeneration then
                    if onComplete then onComplete(false) end
                    return
                end
                ExecuteInGameThread(function()
                    local opts = options
                    if not ctx.isValid(opts) then
                        opts = ctx.getOptionsWidget(true)
                        if opts then
                            prepareAudioPanel(opts)
                        end
                    end
                    if not opts then
                        if onComplete then onComplete(false) end
                        return
                    end

                    if applyMusicVolume(opts, original) then
                        ctx.log("Music volume restored + mix applied (" .. reason .. ")")
                    else
                        ctx.log("Music restore/mix failed (" .. reason .. ")")
                    end

                    ctx.directSaveAudioSettings()
                    broadcastVolumeDispa(opts)

                    local pc = UEHelpers.GetPlayerController()
                    if ctx.isValid(pc) then
                        pcall(function()
                            pc:SetFocusToGameViewport()
                        end)
                    end

                    if onComplete then onComplete(true) end
                end)
            end)
        end)
    end

    function ctx.runFixWithRetry(reason, attemptsLeft, onComplete)
        attemptsLeft = attemptsLeft or config.RETRY_MAX
        ExecuteInGameThread(function()
            if not ctx.isValid(UEHelpers.GetPlayerController()) then
                if attemptsLeft > 0 then
                    ExecuteWithDelay(config.RETRY_INTERVAL_MS, function()
                        ctx.runFixWithRetry(reason, attemptsLeft - 1, onComplete)
                    end)
                else
                    ctx.log("Fix aborted (" .. reason .. "): PC unavailable")
                    if onComplete then onComplete(false) end
                end
                return
            end
            ctx.runAudioFixCycle(reason, onComplete)
        end)
    end

    function ctx.runPeriodicTick()
        if not ctx.periodicActive then
            return
        end

        if ctx.slotSaveExists() then
            ctx.stopPeriodic("save slot exists")
            return
        end

        ctx.clearHelperWidget()
        ctx.runFixWithRetry("periodic", config.RETRY_MAX, function()
            if not ctx.periodicActive then
                return
            end
            ctx.pollSaveSlot(config.SAVE_DETECT_MAX, "after-direct-save", function()
                if ctx.periodicActive and not ctx.slotSaveExists() then
                    ctx.scheduleNextPeriodic()
                end
            end)
        end)
    end

    function ctx.startAudioFix()
        if ctx.fixStarted then
            return
        end
        ctx.fixStarted = true

        if ctx.settingsSaveExists() then
            ctx.log("setting.sav exists — skip")
            return
        end

        ctx.periodicActive = true
        ctx.log("No setting.sav — nudge + direct mysavegame save")
        ExecuteWithDelay(config.START_DELAY_MS, function()
            ctx.runPeriodicTick()
        end)
    end

    return ctx
end

return Engine
