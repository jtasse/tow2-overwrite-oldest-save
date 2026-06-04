local Log = require("log")

local SaveManager = {}

local cached = nil

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

local function get_ufunction(name)
    local path = "/Script/Arkansas.SaveGameManager:" .. name
    local fn = StaticFindObject(path)
    if is_valid(fn) then
        return fn
    end
    return nil
end

local function try_call_function(mgr, ufunc, arg1)
    if not is_valid(mgr) or not is_valid(ufunc) then
        return false, "invalid mgr/ufunc"
    end
    local ok, err = pcall(function()
        if arg1 == nil then
            mgr:CallFunction(ufunc)
        else
            mgr:CallFunction(ufunc, arg1)
        end
    end)
    return ok, err
end

local function try_console_exec(mgr, cmd)
    if not is_valid(mgr) then
        return false, "invalid mgr"
    end
    local ok, err = pcall(function()
        mgr:ProcessConsoleExec(cmd, nil, mgr)
    end)
    return ok, err
end

function SaveManager.delete_slot(slot_id)
    local mgr = SaveManager.get()
    if not mgr then
        return false, "SaveGameManager not found"
    end

    local ufunc = get_ufunction("DeleteGame")
    if ufunc then
        local attempts = {
            function() return try_call_function(mgr, ufunc, slot_id) end,
            function() return try_call_function(mgr, ufunc) end,
            function() return try_console_exec(mgr, "DeleteGame " .. slot_id) end,
        }
        for i, attempt in ipairs(attempts) do
            local ok, err = attempt()
            if ok then
                Log.info("DeleteGame succeeded (attempt " .. i .. ")")
                return true
            end
            Log.warn("DeleteGame attempt " .. i .. " failed: " .. tostring(err))
        end
    end

    return false, "DeleteGame failed"
end

function SaveManager.save_current()
    local mgr = SaveManager.get()
    if not mgr then
        return false, "SaveGameManager not found"
    end

    local ufunc = get_ufunction("SaveGame")
    if ufunc then
        local attempts = {
            function() return try_call_function(mgr, ufunc) end,
            function() return try_call_function(mgr, ufunc, true) end, -- bool overwrite flag guess
            function() return try_console_exec(mgr, "SaveGame") end,
        }
        for i, attempt in ipairs(attempts) do
            local ok, err = attempt()
            if ok then
                Log.info("SaveGame succeeded (attempt " .. i .. ")")
                return true
            end
            Log.warn("SaveGame attempt " .. i .. " failed: " .. tostring(err))
        end
    end

    return false, "SaveGame failed"
end

local function safe_tostring(v)
    local ok, s = pcall(function()
        if type(v) == "userdata" and v.ToString then
            return v:ToString()
        end
        return tostring(v)
    end)
    return ok and s or "<unprintable>"
end

function SaveManager.install_param_logger()
    local function log_hook(self, ...)
        Log.info("SaveGameManager hook on " .. self:GetFullName())
        local n = select("#", ...)
        for i = 1, n do
            Log.info("  arg[" .. i .. "] = " .. safe_tostring(select(i, ...)))
        end
    end

    pcall(function()
        RegisterHook("/Script/Arkansas.SaveGameManager:SaveGame", log_hook)
    end)
    pcall(function()
        RegisterHook("/Script/Arkansas.SaveGameManager:DeleteGame", log_hook)
    end)
end

return SaveManager
