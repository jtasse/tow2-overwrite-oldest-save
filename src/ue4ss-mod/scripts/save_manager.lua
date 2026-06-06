local Config = require("config")
local Log = require("log")
local UiUtil = require("ui_util")


local SaveManager = {}



local cached = nil



local MANUAL_SAVE_FUNCTION = "/Script/Arkansas.SaveGameManager:SaveGame"

local DELETE_FUNCTION_PATHS = {
    "/Script/Arkansas.SaveGameManager:DeleteGame",
    "/Script/Arkansas.SaveGameManager:DeleteSave",
}

local DELETE_METHOD_NAMES = { "DeleteGame", "DeleteSave", "DeleteManualSave" }



local MANUAL_SAVE_MGR_COMMANDS = {
    "SaveGame bIgnoreSuperNova=false",
    "SaveGame bIgnoreSuperNova=0",
    "SaveGame false",
    "SaveGame 0",
}

local MANUAL_SAVE_CONSOLE_COMMANDS = {
    "SaveGame bIgnoreSuperNova=false",
    "SaveGame bIgnoreSuperNova=0",
}



local CAP_SAVE_COMMANDS = {

    "Quicksave",

}



local CAP_SAVE_PATHS = {

    "/Script/Arkansas.SaveGameManager:Quicksave",

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



local function exec_on_obj(obj, cmd)

    if not is_valid(obj) then

        return false

    end

    local ok, ret = pcall(function()

        return obj:ProcessConsoleExec(cmd, nil, obj)

    end)

    if not ok then

        Log.warn(string.format("ProcessConsoleExec '%s' error: %s", cmd, tostring(ret)))

        return false

    end

    Log.info(string.format("ProcessConsoleExec '%s' on %s -> %s", cmd, object_label(obj), tostring(ret)))

    return ret == true

end



local function exec_on_mgr(cmd)

    local mgr = SaveManager.get()

    if not mgr then

        Log.warn("SaveGameManager not found")

        return false

    end

    return exec_on_obj(mgr, cmd)

end



local function resolve_ufunc(obj, name, static_path)

    local ufunc = nil

    local ok = pcall(function()

        ufunc = obj:GetFunctionByName(name)

    end)

    if ok and is_valid(ufunc) then

        return ufunc

    end



    if static_path then

        ufunc = StaticFindObject(static_path)

        if is_valid(ufunc) then

            return ufunc

        end

    end



    return nil

end



local SAVE_GAME_PARAM_SETS = {
    { false, false, false, false },
    { false, true, false, false },
    { false, false, false },
    { false },
}

local function invoke_save_game_ufunc(mgr)
    local ufunc = resolve_ufunc(mgr, "SaveGame", MANUAL_SAVE_FUNCTION)
    if not ufunc then
        return false, nil
    end

    for i, params in ipairs(SAVE_GAME_PARAM_SETS) do
        local label = string.format("UFunction(SaveGame) params=%d", i)
        local ok, err = pcall(function()
            ufunc(mgr, table.unpack(params))
        end)
        if ok then
            Log.info(label .. " OK")
            return true, label
        end
        Log.warn(label .. " failed: " .. tostring(err))
    end

    return false, nil
end



local function try_console_save_via_player()
    if Config.ALLOW_PLAYER_CONTROLLER_CONSOLE == false then
        return false, nil
    end

    local pc = FindFirstOf("PlayerController")
    if not is_valid(pc) then
        return false, nil
    end

    for _, cmd in ipairs(MANUAL_SAVE_CONSOLE_COMMANDS) do
        if exec_on_obj(pc, cmd) then
            return true, cmd .. " (PlayerController)"
        end
    end

    return false, nil
end

local function make_fstring(text)
    if not FString then
        return nil
    end
    local ok, fstr = pcall(function()
        return FString(text)
    end)
    if ok then
        return fstr
    end
    return nil
end

local function invoke_delete_game(mgr, slot_id)
    local id = tostring(slot_id)
    local upper = string.upper(id)
    local fstr = make_fstring(id) or make_fstring(upper)

    local ufunc_candidates = {}
    local seen = {}

    local function add_ufunc(ufunc)
        if is_valid(ufunc) and not seen[ufunc] then
            seen[ufunc] = true
            ufunc_candidates[#ufunc_candidates + 1] = ufunc
        end
    end

    for _, name in ipairs(DELETE_METHOD_NAMES) do
        add_ufunc(resolve_ufunc(mgr, name, nil))
    end
    for _, path in ipairs(DELETE_FUNCTION_PATHS) do
        add_ufunc(StaticFindObject(path))
    end

    for _, ufunc in ipairs(ufunc_candidates) do
        for _, slot_id in ipairs({ id, upper }) do
            local label = "UFunction(Delete," .. slot_id .. ")"
            local ok, err = pcall(function()
                ufunc(mgr, slot_id)
            end)
            if ok then
                Log.info(label .. " OK")
                return true, label
            end
            Log.warn(label .. " failed: " .. tostring(err))
        end
        if fstr then
            local ok, err = pcall(function()
                ufunc(mgr, fstr)
            end)
            if ok then
                Log.info("UFunction(Delete,FString) OK")
                return true, "UFunction(Delete,FString)"
            end
        end
    end

    return false, nil
end



local function call_mgr_function(function_path, ...)

    local mgr = SaveManager.get()

    if not mgr then

        return false, "no manager"

    end

    local ok, err = UiUtil.call_function(mgr, function_path, ...)

    if ok then

        Log.info("CallFunction OK: " .. function_path)

        return true, function_path

    end

    Log.warn("CallFunction failed: " .. function_path .. " — " .. tostring(err))

    return false, err

end



function SaveManager.delete_slot(slot_id)
    local id = tostring(slot_id)
    local mgr = SaveManager.get()
    if not mgr then
        Log.warn("SaveGameManager not found")
        return false
    end

    if Config.PREFER_UFUNCTION_CALLS ~= false then
        local ok, detail = invoke_delete_game(mgr, id)
        if ok then
            Log.info("DeleteGame OK for " .. id .. " via " .. tostring(detail))
            return true
        end
    end

    if Config.ALLOW_MGR_CONSOLE_EXEC then
        if exec_on_mgr("DeleteGame " .. id) then
            Log.info("DeleteGame OK for " .. id .. " (ProcessConsoleExec)")
            return true
        end
    end

    Log.warn("DeleteGame failed for " .. id .. " — set ALLOW_MGR_CONSOLE_EXEC=true to allow console fallback")
    return false
end



local function try_commands(commands, paths)

    for _, cmd in ipairs(commands) do

        if exec_on_mgr(cmd) then

            return true, cmd

        end

    end



    for _, path in ipairs(paths) do

        local ok, detail = call_mgr_function(path)

        if ok then

            return true, detail

        end

    end



    return false, nil

end



local function try_mgr_console_save()
    for _, cmd in ipairs(MANUAL_SAVE_MGR_COMMANDS) do
        if exec_on_mgr(cmd) then
            return true, cmd
        end
    end
    return false, nil
end

-- Manual SaveGame only — new slot below cap, new slot after delete at cap (same as pause menu Save Game).
function SaveManager.save_manual_slot()
    local mgr = SaveManager.get()
    if not mgr then
        return false, nil
    end

    if Config.PREFER_UFUNCTION_CALLS ~= false then
        local ok, detail = invoke_save_game_ufunc(mgr)
        if ok then
            return true, detail
        end
    end

    if Config.ALLOW_MGR_CONSOLE_EXEC then
        local ok, detail = try_mgr_console_save()
        if ok then
            return true, detail
        end
    end

    local ok, detail = try_console_save_via_player()
    if ok then
        return true, detail
    end

    return false, nil
end

function SaveManager.save_after_cap_delete()
    -- After DeleteGame at cap, Quicksave fills the freed *manual* slot (WORKING-STATE validated).
    -- ProcessConsoleExec SaveGame returns true but does not actually save on TOW2 WinGDK.
    if Config.CAP_SAVE_USE_QUICKSAVE ~= false then
        local ok, detail = try_commands(CAP_SAVE_COMMANDS, CAP_SAVE_PATHS)
        if ok then
            return true, detail
        end
        Log.warn("Cap Quicksave failed — trying SaveGame fallback")
    end
    return SaveManager.save_manual_slot()
end

function SaveManager.save_below_cap()
    local ok, detail = SaveManager.save_manual_slot()
    if ok then
        return true, detail
    end
    if Config.ALLOW_QUICKSAVE_FALLBACK then
        Log.warn("SaveGame failed — falling back to Quicksave (limited slot pool).")
        return try_commands(CAP_SAVE_COMMANDS, CAP_SAVE_PATHS)
    end
    return false, nil
end



function SaveManager.quicksave()

    return SaveManager.save_after_cap_delete()

end



function SaveManager.save_manual()

    return SaveManager.save_below_cap()

end



function SaveManager.install_param_logger()

end



return SaveManager

