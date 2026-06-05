local Config = require("config")
local Log = require("log")
local Feedback = require("feedback")
local Discovery = require("discovery")
local QuickSave = require("quick_save")
local SaveManager = require("save_manager")
local SavesFs = require("saves_fs")
local Menu = require("menu")
local UiDiscovery = require("ui_discovery")
local SaveHealth = require("save_health")
local InputBindings = require("input_bindings")

Log.info("loaded v" .. Config.MOD_VERSION)

SaveManager.install_param_logger()
Menu.install_hooks()

local game_ready = false
local activation_scheduled = false

local function try_activate_after_load()
    if game_ready then
        return true
    end

    local mgr = SaveManager.get()
    if not mgr then
        return false
    end

    game_ready = true
    Log.info("SaveGameManager ready")
    InputBindings.start_after_load()
    Feedback.show_startup_banner()
    return true
end

local hook_pre, hook_post
hook_pre, hook_post = RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    if game_ready or activation_scheduled then
        return
    end
    activation_scheduled = true
    ExecuteWithDelay(5000, function()
        ExecuteInGameThread(function()
            try_activate_after_load()
        end)
    end)
end)

local function reply(Ar, ok, msg)
    local text = msg or (ok and "OK" or "Failed")
    Feedback.say_in_console(Ar, text)
    return true
end

local function run_command(FullCommand, Parameters, Ar, run_fn)
    try_activate_after_load()
    local ok, msg = run_fn(FullCommand, Parameters, Ar)
    return reply(Ar, ok, msg)
end

local function register_oow_command(name, run_fn)
    RegisterConsoleCommandGlobalHandler(name, function(FullCommand, Parameters, Ar)
        return run_command(FullCommand, Parameters, Ar, run_fn)
    end)
end

register_oow_command("oow.save", function()
    return QuickSave.run()
end)

register_oow_command("oow.overwrite", function()
    return QuickSave.run()
end)

register_oow_command("oow.quicksave", function()
    return QuickSave.run()
end)

register_oow_command("oow.reload_cache", function()
    SavesFs.ensure_cache(true)
    local n = SavesFs.manual_save_count()
    return true, string.format("Cache: %d saves (delete+save when >= %d)", n, Config.MAX_MANUAL_SAVES)
end)

register_oow_command("oow.help", function()
    return true, table.concat({
        "Ctrl+Shift+O or hold LB+RB and tap A = quick save",
        "oow.save - same as above",
        "oow.discover_gamepad - log which buttons the game sees",
        "oow.reload_cache - after refresh-save-cache.ps1 on host",
    }, " | ")
end)

register_oow_command("oow.discover_gamepad", function()
    return InputBindings.discover_gamepad()
end)

register_oow_command("oow.save_health", function()
    return SaveHealth.report()
end)

register_oow_command("oow.delete_oldest", function()
    return QuickSave.run()
end)

register_oow_command("oow.discover_save", function()
    SavesFs.refresh_cache()
    Discovery.run_all()
    return true, "Discovery done - see UE4SS.log"
end)

register_oow_command("oow.overwrite_oldest", function()
    return QuickSave.run()
end)

register_oow_command("oow.overwrite_confirm", function()
    return QuickSave.run()
end)

register_oow_command("oow.check_save", function()
    SavesFs.ensure_cache(true)
    local list = SavesFs.list_manual_saves()
    local newest = list[#list]
    return true, "Newest in cache: " .. (newest and newest.name or "(none)")
end)

register_oow_command("oow.status", function()
    return true, Feedback.format_history()
end)

register_oow_command("oow.discover_ui", function()
    UiDiscovery.run()
    return true, "UI discovery done - see UE4SS.log"
end)

register_oow_command("oow.inject_menu", function()
    SavesFs.refresh_cache()
    return Menu.try_inject(true)
end)

Log.info("Commands: oow.save | Ctrl+Shift+O | LB+RB+A | oow.discover_gamepad")
