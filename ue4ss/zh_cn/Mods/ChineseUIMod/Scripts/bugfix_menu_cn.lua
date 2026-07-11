-- Bug-fix menu (tellmenuu) ComboBox translation
-- Russian options kept internally; TextBlocks show Chinese, Russian on hover

local SafeTB = require("safe_textblock")

local SIG = "\u{200B}\u{200B}\u{200B}\u{200B}\u{200B}"

local translations = {
    ["Не могу подбирать физические предметы."] = "无法拾取物理对象。",
    ["Не могу взаимодействовать с предметами."] = "无法与物品互动。",
    ["Не могу ходить."] = "无法移动。",
    ["Я застрял или упал под карту (вернуть в лагерь)."] = "卡在地图里或掉到地图外了（送回营地）。",
    ["Не могу нормально повернуться."] = "无法正常转动视角。",
    ["Застрял в анимации."] = "卡在动画里。",
    ["Не запустилась сцена в автобусе (игра начнется заново)."] = "巴士场景未启动（游戏将重新开始）。",
    ["Бесконечный тёмный экран."] = "无限黑屏。",
    ["Курсор (вызвать)"] = "光标（唤出）",
}

for k, v in pairs(translations) do translations[k] = v .. SIG end

local reverseTranslations = {}
for k, v in pairs(translations) do
    reverseTranslations[v] = k
end

local function stripSig(s)
    return s:gsub("\u{200B}", "")
end

local function identifyText(text)
    if not text or text == "" then return nil, nil end
    if translations[text] then
        return text, translations[text]
    end
    local rus = reverseTranslations[text] or reverseTranslations[stripSig(text)]
    if rus then
        return rus, translations[rus]
    end
    return nil, nil
end

local function isTellmenuuCombo(combo)
    if not combo or not combo:IsValid() then return false end
    local outer = combo
    for _ = 1, 10 do
        if not outer or not outer:IsValid() then return false end
        local ok, name = pcall(function() return outer:GetClass():GetFullName() end)
        if ok and name and name:find("tellmenuu_C") then return true end
        local nextOuter = nil
        pcall(function() nextOuter = outer:GetOuter() end)
        outer = nextOuter
    end
    return false
end

local function isHoveredChain(obj)
    local current = obj
    for _ = 1, 8 do
        if not current or not current:IsValid() then return false end
        local ok, h = pcall(function() return current:IsHovered() end)
        if ok and h then return true end
        local parent = nil
        pcall(function() parent = current:GetParent() end)
        current = parent
    end
    return false
end

local function applyTranslation(obj, current)
    local rus, chn = identifyText(current)
    if not rus then return end
    local text = isHoveredChain(obj) and rus or chn
    obj:SetText(FText(text))
end

local function scanTextBlocks()
    if SafeTB.inventoryOpen() then
        return
    end
    SafeTB.forEach(function(obj)
        pcall(function()
            applyTranslation(obj, obj:GetText():ToString())
        end)
    end)
    local rtbs = nil
    pcall(function() rtbs = FindAllOf("RichTextBlock") end)
    if not rtbs then
        return
    end
    for _, obj in pairs(rtbs) do
        if obj and obj:IsValid() and not SafeTB.shouldSkip(obj) then
            pcall(function()
                applyTranslation(obj, obj:GetText():ToString())
            end)
        end
    end
end

local function burstScanDropdown()
    scanTextBlocks()
    for i = 1, 12 do
        ExecuteWithDelay(i * 25, scanTextBlocks)
    end
end

local scanActive = false

local function startScan()
    scanActive = true
    scanTextBlocks()
end

local function stopScan()
    scanActive = false
end

local function scanLoop()
    if scanActive then
        scanTextBlocks()
    end
    ExecuteWithDelay(250, scanLoop)
end

local hooksRegistered = false

local function tryRegisterHooks()
    if hooksRegistered then return end

    local ok = pcall(RegisterHook,
        "/Game/main/hud/tellmenuu.tellmenuu_C:Construct",
        function()
            ExecuteWithDelay(0, startScan)
        end
    )
    if not ok then return end

    pcall(RegisterHook,
        "/Game/main/hud/tellmenuu.tellmenuu_C:Destruct",
        function() stopScan() end
    )

    -- When dropdown opens, burst-scan newly created row TextBlocks
    pcall(RegisterHook,
        "/Script/UMG.ComboBoxString:HandleOpening",
        function() end,
        function(self)
            local combo = self:get()
            if combo and combo:IsValid() and isTellmenuuCombo(combo) then
                burstScanDropdown()
            end
        end
    )

    hooksRegistered = true
end

local pollCount = 0
local function poll()
    pollCount = pollCount + 1
    tryRegisterHooks()
    if pollCount < 600 then
        ExecuteWithDelay(100, poll)
    end
end

ExecuteWithDelay(500, poll)
ExecuteWithDelay(1000, scanLoop)
