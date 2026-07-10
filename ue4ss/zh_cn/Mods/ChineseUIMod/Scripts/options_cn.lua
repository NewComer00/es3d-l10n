-- Options menu text translation to Chinese
-- Overrides displayed text only; does not touch internal values

local SIG = "\u{200B}"

local translations = {
    -- TextBlock labels
    ["Visual Quality"] = "画质",
    ["Апскейл (upscale DLSS FSR)"] = "超分辨率 (DLSS/FSR)",
    ["Вертикальная синхронизация"] = "垂直同步",
    ["Визульные эффекты"] = "视觉特效",
    ["Глобальное освещение"] = "全局光照",
    ["Громкость"] = "音量",
    ["Качество шейдера"] = "着色器质量",
    ["Количество растительности"] = "植被密度",
    ["Назад"] = "返回",
    ["Ограничение FPS"] = "帧率限制",
    ["Ограничение ФПС"] = "帧率限制",
    ["Полный экран"] = "全屏",
    ["Постобработка"] = "后期处理",
    ["Прорисовка обьектов"] = "物体渲染距离",
    ["Прорисовка травы"] = "草地渲染距离",
    ["Размытие"] = "模糊",
    ["Разрешение экрана"] = "屏幕分辨率",
    ["Сглаживание"] = "抗锯齿",
    ["Текстуры"] = "纹理",
    ["Тени"] = "阴影",
    ["Тип сглаживания"] = "抗锯齿类型",
    ["Управление"] = "控制",
    ["вык"] = "关",
    -- Cycling values
    ["Высокие"] = "高",
    ["Средние"] = "中",
    ["Низкие"] = "低",
    ["Ультра"] = "超高",
    ["Cинематик"] = "电影级",
    ["Полноэкраный"] = "全屏",
    ["В окне без рамки"] = "无边框窗口",
    ["В окне"] = "窗口",
}

-- invisible signature
for k, v in pairs(translations) do translations[k] = v .. SIG end

local translationsLower = {}
for k, v in pairs(translations) do
    translationsLower[k:lower()] = v
end

local function translate(str)
    if type(str) ~= "string" then return nil end
    return translations[str] or translationsLower[str:lower()]
end

local function translateAllTextBlocks()
    local objects = FindAllOf("TextBlock")
    if not objects then return end
    for _, obj in ipairs(objects) do
        if obj:IsValid() then
            pcall(function()
                local translated = translate(obj:GetText():ToString())
                if translated then
                    obj:SetText(FText(translated))
                end
            end)
        end
    end
end

local function translateDeferred()
    ExecuteWithDelay(0, translateAllTextBlocks)
end

local hooksRegistered = false

local function tryRegisterHooks()
    if hooksRegistered then return end

    local ok7 = pcall(RegisterHook, "/Game/main/hud/options7.options7_C:Construct", function()
        translateDeferred()
    end)
    if not ok7 then return end

    pcall(RegisterHook, "/Game/main/hud/options7.options7_C:создать", function()
        translateDeferred()
    end)

    pcall(RegisterHook, "/Game/main/hud/options7.options7_C:применяем", function()
        translateDeferred()
    end)

    pcall(RegisterHook, "/Game/main/hud/options7.options7_C:проверяемфокус", function()
        translateDeferred()
    end)

    local ok8 = pcall(RegisterHook, "/Game/main/hud/options8.options8_C:Construct", function()
        translateDeferred()
    end)
    if not ok8 then return end

    local tickCounts8 = {}
    pcall(RegisterHook, "/Game/main/hud/options8.options8_C:Tick", function(self)
        local key = tostring(self:get():GetFullName())
        tickCounts8[key] = (tickCounts8[key] or 0) + 1
        if tickCounts8[key] <= 5 then
            translateAllTextBlocks()
        end
    end)

    pcall(RegisterHook, "/Script/UMG.ComboBoxString:SetSelectedOption", function(self, option)
        local str = option:get():ToString()
        local translated = translate(str)
        if translated then
            option:set(translated)
        end
    end)

    hooksRegistered = true
end

local pollCount = 0
local function poll()
    pollCount = pollCount + 1
    tryRegisterHooks()
    if not hooksRegistered and pollCount < 600 then
        ExecuteWithDelay(100, poll)
    end
end

ExecuteWithDelay(1000, poll)
