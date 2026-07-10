-- Gameplay settings text translation to Chinese
-- Shows Chinese normally; switches to Russian on hover so click logic works

local SIG = "\u{200B}\u{200B}\u{200B}"

local translations = {
    ["Оригинальный"] = "原版",
    ["Включить"] = "开启",
    ["Выключить"] = "关闭",
    ["Старый"] = "旧版",
    ["Краткий"] = "简洁版",
}

for k, v in pairs(translations) do translations[k] = v .. SIG end

local translationsLower = {}
for k, v in pairs(translations) do
    translationsLower[k:lower()] = v
end

local reverseTranslations = {}
for k, v in pairs(translations) do
    reverseTranslations[v] = k
end

local function identifyText(obj)
    local ok, currentText = pcall(function()
        return obj:GetText():ToString()
    end)
    if not ok or not currentText then return nil, nil end

    if translations[currentText] or translationsLower[currentText:lower()] then
        local chn = translations[currentText] or translationsLower[currentText:lower()]
        return currentText, chn
    end
    local rus = reverseTranslations[currentText]
    if rus then
        return rus, currentText
    end
    return nil, nil
end

-- Check TextBlock + immediate parent for hover (parent = per-button Button, not shared container)
local function isParentHovered(obj)
    -- First check the TextBlock itself
    local ok, h = pcall(function() return obj:IsHovered() end)
    if ok and h then return true end
    -- Check immediate parent (Border for AI, Button for gameplay)
    local ok2, parent = pcall(function() return obj:GetParent() end)
    if ok2 and parent and parent:IsValid() then
        local h2 = false
        pcall(function() h2 = parent:IsHovered() end)
        return h2
    end
    return false
end

-- Single-pass: check hover on text + parents (Button/Border/SizeBox)
local function doScan()
    local objects = FindAllOf("TextBlock")
    if not objects then return end

    for _, obj in ipairs(objects) do
        if obj:IsValid() then
            local rus, chn = identifyText(obj)
            if rus then
                local text = isParentHovered(obj) and rus or chn
                pcall(function() obj:SetText(FText(text)) end)
            end
        end
    end
end

-- Periodic scan
local function periodicScan()
    doScan()
    ExecuteWithDelay(100, periodicScan)
end

ExecuteWithDelay(1000, periodicScan)
