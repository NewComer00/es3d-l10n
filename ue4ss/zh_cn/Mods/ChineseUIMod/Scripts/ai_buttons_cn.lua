-- AI interaction button + outfit text translation to Chinese
-- Shows Chinese normally; switches to Russian on hover so click logic works

local SafeTB = require("safe_textblock")

local SIG = "\u{200B}\u{200B}"

local translations = {
    -- Interaction buttons
    ["Знакомство"]        = "搭话",
    ["Модификатор"]       = "换装",
    ["Пошли вместе "]     = "同行",
    ["Пошли вместе"]      = "同行",
    ["Пока"]              = "再见",
    ["Досвидания"]        = "告辞",
    ["Осмотреть"]         = "检查",
    ["Вернуться"]         = "返回",
    ["Нет, ничего"]       = "不，没事儿",
    ["Подожди здесь"]     = "待在这儿",
    -- Outfit / dressing
    ["Пионерская форма"]  = "少先队服",
    ["Платье"]            = "连衣裙",
    ["Купальник"]         = "泳装",
    ["Спортивная одежда"] = "运动服",
    ["Выбор одежды"]      = "服装选择",
    ["Настройка костюмов"]= "服装设置",
    ["Настройка юбки"]    = "裙子设置",
    ["Короткая юбка"]     = "短裙",
    ["Длинная юбка"]      = "长裙",
    ["Переодеться"]       = "换衣服",
    ["В плавках"]         = "穿泳裤",
    ["Добавлена новая одежда"] = "已添加新服装",
    -- Dream
    ["Я знаю какой ненастоящий"] = "我知道哪节车厢是假的了",
    ["Повтори еще раз"] = "请再解释一遍",
    ["Мику, это я, Семен"] = "未来，是我，谢苗",
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

-- Check TextBlock + immediate parent for hover (parent = per-button Border, not shared container)
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
    SafeTB.forEach(function(obj)
        local rus, chn = identifyText(obj)
        if rus then
            local text = isParentHovered(obj) and rus or chn
            pcall(function() obj:SetText(FText(text)) end)
        end
    end)
end

local function periodicScan()
    doScan()
    ExecuteWithDelay(250, periodicScan)
end

local function registerHooks()
    local function forceRussianThenChinese()
        SafeTB.forEach(function(obj)
            local rus, _ = identifyText(obj)
            if rus then
                pcall(function() obj:SetText(FText(rus)) end)
            end
        end)
        ExecuteWithDelay(0, doScan)
    end

    pcall(RegisterHook,
        "/Game/InteractionWidgets/Blueprints/Widgets/BP_MasterInteractionWidget.BP_MasterInteractionWidget_C:Interact",
        forceRussianThenChinese
    )
    pcall(RegisterHook,
        "/Game/InteractionWidgets/Blueprints/InteractAddOns/BP_BasicInteractWidgetAddOn.BP_BasicInteractWidgetAddOn_C:Interact",
        forceRussianThenChinese
    )
end

-- Start
ExecuteWithDelay(500, registerHooks)
ExecuteWithDelay(1000, periodicScan)
