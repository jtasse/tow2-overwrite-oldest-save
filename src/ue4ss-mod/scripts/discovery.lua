local Config = require("config")
local Log = require("log")
local SaveManager = require("save_manager")

local Discovery = {}

local function format_value(val)
    local t = type(val)
    if t == "number" or t == "boolean" or t == "string" then
        return tostring(val)
    end
    if t ~= "userdata" then
        return t
    end

    local ok_num, num = pcall(function()
        return val:GetArrayNum()
    end)
    if ok_num and type(num) == "number" then
        return "TArray len=" .. num
    end

    local ok_str, s = pcall(function()
        return val:ToString()
    end)
    if ok_str and s and s ~= "" then
        return s
    end

    local ok_name, fn = pcall(function()
        return val:GetFullName()
    end)
    if ok_name and fn then
        return fn
    end

    return "(userdata)"
end

local function read_property(obj, prop_name)
    local ok, val = pcall(function()
        return obj:GetPropertyValue(prop_name)
    end)
    if ok and val ~= nil then
        return val
    end
    ok, val = pcall(function()
        return obj[prop_name]
    end)
    if ok then
        return val
    end
    return nil
end

local function dump_save_related_properties(mgr)
    local class = mgr:GetClass()
    if not class or not class:IsValid() then
        Log.warn("SaveGameManager class invalid")
        return
    end

    local ok, props = pcall(function()
        return class:ForEachProperty()
    end)
    if not ok or not props then
        Log.warn("ForEachProperty failed — do one manual save and paste SaveGameManager hook lines")
        return
    end

    local shown = 0
    for _, prop in ipairs(props) do
        local name_ok, prop_name = pcall(function()
            return prop:GetFName():ToString()
        end)
        if name_ok and prop_name then
            local lower = string.lower(prop_name)
            if string.find(lower, "save", 1, true)
                or string.find(lower, "manual", 1, true)
                or string.find(lower, "slot", 1, true)
                or string.find(lower, "count", 1, true)
                or string.find(lower, "max", 1, true)
            then
                local val = read_property(mgr, prop_name)
                if val ~= nil then
                    Log.info("  " .. prop_name .. " = " .. format_value(val))
                    shown = shown + 1
                end
            end
        end
        if shown >= 25 then
            Log.info("  (truncated after 25 save-related properties)")
            break
        end
    end

    if shown == 0 then
        Log.warn("No save-related properties matched — use manual save + hook log")
    end
end

function Discovery.run_all()
    Log.info("=== OverwriteOldestSave discovery (in-game only) ===")

    local mgr = SaveManager.get()
    if not mgr then
        Log.warn("SaveGameManager not found — load a save first, then run oow.discover_save again")
        Log.info("=== end discovery ===")
        return
    end

    Log.info("SaveGameManager: " .. mgr:GetFullName())

    local SavesFs = require("saves_fs")
    SavesFs.describe_state()

    dump_save_related_properties(mgr)

    Log.info("=== end discovery ===")
    Log.info("At 100/100 saves the game will NOT call SaveGame — hook lines will not appear.")
    Log.info("Try: oow.overwrite_oldest then oow.overwrite_confirm (uses oldest folder name).")
end

return Discovery
