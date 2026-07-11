-- Shared safe TextBlock iteration for ChineseUIMod.
-- Closing FullscreenInventory destroys many TextBlocks while scanners run;
-- skip inventory widgets and wrap all UObject access in pcall.

local M = {}

local SKIP_MARKERS = {
    "UI_FullscreenInventory",
    "FullscreenInventory",
}

local function isValidObj(obj)
    if obj == nil then
        return false
    end
    local ok, valid = pcall(function()
        return obj:IsValid()
    end)
    return ok and valid == true
end

function M.shouldSkip(obj)
    if not isValidObj(obj) then
        return true
    end
    local ok, name = pcall(function()
        return obj:GetFullName()
    end)
    if not ok or type(name) ~= "string" then
        return true
    end
    for _, marker in ipairs(SKIP_MARKERS) do
        if name:find(marker, 1, true) then
            return true
        end
    end
    return false
end

function M.inventoryOpen()
    local ok, inv = pcall(FindFirstOf, "UI_FullscreenInventory_C")
    if not ok then
        return false
    end
    return isValidObj(inv)
end

function M.forEach(callback)
    if type(callback) ~= "function" then
        return
    end
    if M.inventoryOpen() then
        return
    end
    local objects = nil
    local okFind = pcall(function()
        objects = FindAllOf("TextBlock")
    end)
    if not okFind or not objects then
        return
    end
    for _, obj in pairs(objects) do
        if isValidObj(obj) and not M.shouldSkip(obj) then
            pcall(callback, obj)
        end
    end
end

return M
