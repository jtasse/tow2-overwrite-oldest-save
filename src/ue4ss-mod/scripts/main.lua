local Config = require("config")
local Log = require("log")
local Feedback = require("feedback")
local Discovery = require("discovery")
local Overwrite = require("overwrite")
local SaveManager = require("save_manager")
local SavesFs = require("saves_fs")
local Menu = require("menu")

Log.info("loaded v" .. Config.MOD_VERSION)

SaveManager.install_param_logger()
Menu.install_hooks()

-- Warm save-folder cache after load (not during console commands).
local hook_pre, hook_post
hook_pre, hook_post = RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    ExecuteInGameThread(function()
        if SaveManager.get() then
            Log.info("SaveGameManager ready after ClientRestart")
        end
        ExecuteWithDelay(3000, function()
            ExecuteInGameThread(function()
                SavesFs.refresh_cache()
            end)
        end)
    end)
end)

local function register_oow_command(name, run_fn, needs_game_thread)
    RegisterConsoleCommandGlobalHandler(name, function(_, __, Ar)
        if needs_game_thread then
            Feedback.say_in_console(Ar, "Running " .. name .. "...")
            ExecuteInGameThread(function()
                local ok, msg = run_fn()
                Log.info(msg or (ok and "Done" or "Failed"))
            end)
        else
            local ok, msg = run_fn()
            Feedback.say_in_console(Ar, msg or (ok and "OK" or "Failed"))
        end
        return true
    end)
end

register_oow_command("oow.discover_save", function()
    SavesFs.refresh_cache()
    Discovery.run_all()
    return true, "Discovery done — see UE4SS.log"
end, false)

register_oow_command("oow.overwrite_oldest", function()
    return Overwrite.request_confirm()
end, false)

register_oow_command("oow.overwrite_confirm", function()
    return Overwrite.execute_confirmed()
end, true)

Log.info("Commands: oow.discover_save | oow.overwrite_oldest | oow.overwrite_confirm")
Log.info("Wait ~3s after load before overwrite (save cache warms automatically)")
