local Log = require("log")
local UiUtil = require("ui_util")

local SaveManager = {}

local cached = nil

local CONSOLE_COMMANDS = {
    "Quicksave",
    "SaveGame",
}

local CALL_FUNCTION_PATHS = {
    "/Script/Arkansas.SaveGameManager:Quicksave",
    "/Script/Arkansas.SaveGameManager:SaveGame",
}

local function is_valid(obj)
    if not obj then
        return false
    end
    local ok, valid = pcall(function()
        return obj:IsValid()
    end)
    return ok and valid
end

function SaveManager.get()
    if cached and is_valid(cached) then
        return cached
    end

    local found = FindAllOf("SaveGameManager")
    if found then
        for _, obj in ipairs(found) do
            if is_valid(obj) then
                cached = obj
                return cached
            end
        end
    end

    return nil
end

local function object_label(obj)
    if not is_valid(obj) then
        return "invalid"
    end
    local ok, name = pcall(function()
        return obj:GetFullName()
    end)
    if ok and name then
        return name
    end
    return "object"
end

local function exec_on_mgr(cmd)
    local mgr = SaveManager.get()
    if not mgr then
        Log.warn("SaveGameManager not found")
        return false
    end
    local ok, ret = pcall(function()
        return mgr:ProcessConsoleExec(cmd, nil, mgr)
    end)
    if not ok then
        Log.warn(string.format("ProcessConsoleExec '%s' error: %s", cmd, tostring(ret)))
        return false
    end
    Log.info(string.format("ProcessConsoleExec '%s' on %s -> %s", cmd, object_label(mgr), tostring(ret)))
    return ret == true
end

local function call_mgr_function(function_path)
    local mgr = SaveManager.get()
    if not mgr then
        return false, "no manager"
    end
    local ok, err = UiUtil.call_function(mgr, function_path)
    if ok then
        Log.info("CallFunction OK: " .. function_path)
        return true, function_path
    end
    Log.warn("CallFunction failed: " .. function_path .. " — " .. tostring(err))
    return false, err
end

function SaveManager.delete_slot(slot_id)
    local id = tostring(slot_id)
    if exec_on_mgr("DeleteGame " .. id) then
        Log.info("DeleteGame OK for " .. id)
        return true
    end
    Log.warn("DeleteGame failed for " .. id)
    return false
end

function SaveManager.quicksave()
    for _, cmd in ipairs(CONSOLE_COMMANDS) do
        if exec_on_mgr(cmd) then
            return true, cmd
        end
    end

    for _, path in ipairs(CALL_FUNCTION_PATHS) do
        local ok, detail = call_mgr_function(path)
        if ok then
            return true, detail
        end
    end

    return false, nil
end

function SaveManager.save_manual()
    return SaveManager.quicksave()
end

function SaveManager.install_param_logger()
end

return SaveManager
