-- ChineseUIMod — loads translation sub-modules

do
    local ok, mod = pcall(require, "safe_textblock")
    if not ok then
        local chunk = loadfile("ue4ss/Mods/ChineseUIMod/Scripts/safe_textblock.lua")
        if chunk then
            ok, mod = pcall(chunk)
        end
    end
    if ok and type(mod) == "table" then
        package.loaded["safe_textblock"] = mod
    else
        package.loaded["safe_textblock"] = {
            inventoryOpen = function() return true end,
            shouldSkip = function() return true end,
            forEach = function() end,
        }
    end
end

pcall(dofile, "ue4ss/Mods/ChineseUIMod/Scripts/options_cn.lua")
pcall(dofile, "ue4ss/Mods/ChineseUIMod/Scripts/ai_buttons_cn.lua")
pcall(dofile, "ue4ss/Mods/ChineseUIMod/Scripts/gameplay_settings_cn.lua")
pcall(dofile, "ue4ss/Mods/ChineseUIMod/Scripts/choice_text_cn.lua")
pcall(dofile, "ue4ss/Mods/ChineseUIMod/Scripts/bugfix_menu_cn.lua")
