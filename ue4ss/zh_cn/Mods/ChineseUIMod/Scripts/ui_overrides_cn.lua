-- General runtime overrides for UI strings that the CSV/UAssetGUI pipeline
-- cannot round-trip (Blueprint bytecode, legacy .uexp no-op, etc.).
-- Examples: the v0.6.0 autosave label is set by the slot widget via SetText
-- (EX_TextConst), and 3день/уборка5 is silently left unchanged by UAssetGUI.

local SafeTB = require("safe_textblock")

local translations = {
    ["Автосохранение"] = "自动保存",
    ["автосохранение"] = "自动保存",
    ["Вроде все убрал."] = "好像都收拾干净了。",
}

local function clean(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("\226\128\139", "")
    s = s:gsub("[\r\n\t]", " ")
    s = s:gsub("%s+", " ")
    return s:match("^%s*(.-)%s*$") or s
end

local function scan()
    SafeTB.forEach(function(t)
        local ok, raw = pcall(function() return t:GetText():ToString() end)
        if not ok or not raw then return end

        local cn = translations[clean(raw)]
        if cn then
            pcall(function() t:SetText(FText(cn)) end)
        end
    end)

    ExecuteWithDelay(500, scan)
end

ExecuteWithDelay(3000, scan)
