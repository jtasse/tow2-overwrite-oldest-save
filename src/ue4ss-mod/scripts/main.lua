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
local SaveCount = require("save_count")

Log.info("loaded v" .. Config.MOD_VERSION)

SaveManager.install_param_logger()
Menu.install_hooks()

local game_ready = false
local auto_arm_pending = false

local function is_valid(obj)
    if not obj then
        return false
    end
    local ok, valid = pcall(function()
        return obj:IsValid()
    end)
    return ok and valid
end

local function pawn_full_name(pawn)
    local ok, name = pcall(function()
        return pawn:GetFullName()
    end)
    return ok and name or ""
end

-- Reject menu/default pawns; FindAllOf("Pawn") was activating on the black screen.
local function is_playable_pawn(pawn)
    if not is_valid(pawn) then
        return false
    end
    local name = string.lower(pawn_full_name(pawn))
    if name:find("default__", 1, true) then
        return false
    end
    if name:find("mainmenu", 1, true) or name:find("titlemenu", 1, true) then
        return false
    end
    return true
end

local function pawn_from_pc(pc)
    for _, accessor in ipairs({ "GetPawn", "Pawn", "GetCharacter", "Character" }) do
        local ok, val = pcall(function()
            local member = pc[accessor]
            if type(member) == "function" then
                return member(pc)
            end
            return member
        end)
        if ok and is_playable_pawn(val) then
            return val
        end
    end
    local ok, ack = pcall(function()
        return pc.AcknowledgedPawn
    end)
    if ok and is_playable_pawn(ack) then
        return ack
    end
    return nil
end

local function has_playable_character()
    local pc = FindFirstOf("PlayerController")
    if not is_valid(pc) then
        return false
    end
    return pawn_from_pc(pc) ~= nil
end

local function try_schedule_hotkeys(opts)
    if game_ready or auto_arm_pending then
        return true, "Hotkeys already active or scheduled."
    end
    if not SaveManager.get() then
        return false, "SaveGameManager not ready — load a save first."
    end
    local via = (opts and opts.via) or "manual"
    auto_arm_pending = true
    game_ready = true
    local delay_ms = (opts and opts.delay_ms) or Config.INPUT.ARM_DELAY_MS or 1500
    local ok, msg = InputBindings.schedule_arm({
        via = via,
        delay_ms = delay_ms,
        arm = opts and opts.arm,
    })
    if ok then
        ExecuteWithDelay(delay_ms + 500, function()
            auto_arm_pending = false
            Feedback.show_startup_banner()
        end)
    else
        auto_arm_pending = false
        game_ready = false
    end
    return ok, msg
end

local function try_auto_arm_hotkeys(via)
    if not Config.INPUT.AUTO_ARM_BINDINGS then
        return
    end
    if game_ready or auto_arm_pending then
        return
    end
    if not SaveManager.get() then
        Log.info("Hotkeys waiting — SaveGameManager not ready")
        return
    end
    if not has_playable_character() then
        Log.info("Hotkeys waiting — character not ready")
        return
    end
    Log.info("In-game — scheduling hotkeys (" .. via .. ")")
    local arm_gamepad = Config.INPUT.AUTO_ARM_GAMEPAD_ON_LOAD
        and Config.INPUT.GAMEPAD_ENABLED
        and (Config.INPUT.GAMEPAD_METHOD == "bridge" or Config.INPUT.GAMEPAD_METHOD == "xinput")
    try_schedule_hotkeys({
        via = via,
        delay_ms = Config.INPUT.ARM_DELAY_MS,
        arm = { keyboard = true, gamepad = arm_gamepad },
    })
end

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    if game_ready or auto_arm_pending then
        return
    end
    local delay_ms = Config.INPUT.CLIENT_RESTART_DELAY_MS or 8000
    ExecuteWithDelay(delay_ms, function()
        ExecuteInGameThread(function()
            try_auto_arm_hotkeys("ClientRestart")
        end)
    end)
end)

local function reply(Ar, ok, msg)
    local text = msg or (ok and "OK" or "Failed")
    Feedback.say_in_console(Ar, text)
    return true
end

local function run_command(FullCommand, Parameters, Ar, run_fn, name)
    InputBindings.pause_gamepad_poll()
    local ok, msg = run_fn(FullCommand, Parameters, Ar)
    return reply(Ar, ok, msg)
end

local function register_oow_command(name, run_fn)
    RegisterConsoleCommandGlobalHandler(name, function(FullCommand, Parameters, Ar)
        return run_command(FullCommand, Parameters, Ar, run_fn, name)
    end)
end

local function cmd_quicksave()
    return QuickSave.run()
end

register_oow_command("oow.save", cmd_quicksave)
register_oow_command("oow.s", cmd_quicksave)

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

register_oow_command("oow.arm_bindings", function()
    local ok, msg = try_schedule_hotkeys({ via = "oow.arm_bindings", delay_ms = 3000 })
    return ok, msg or "Hotkeys scheduled."
end)

register_oow_command("oow.arm_gamepad", function()
    return InputBindings.arm_gamepad_after_console()
end)

register_oow_command("oow.set_cap", function()
    return SavesFs.write_host_cap_marker(Config.MAX_MANUAL_SAVES)
end)

register_oow_command("oow.clear_cap", function()
    return SavesFs.clear_host_cap_marker()
end)

register_oow_command("oow.sync_count", function()
    return SaveCount.sync_now()
end)

register_oow_command("oow.debug_sync", function()
    return SaveCount.debug_scrape()
end)

register_oow_command("oow.set_count", function(FullCommand, Parameters)
    local n = tonumber(Parameters and Parameters[1])
    if not n then
        return false, "Usage: oow.set_count 96 (match pause menu x/100)"
    end
    return SavesFs.write_persisted_save_count(n, "manual")
end)

register_oow_command("oow.help", function()
    return true, table.concat({
        "Ctrl+Shift+O ~10s after load | LT+L3+R3 (gamepad bridge autostarts at logon)",
        "oow.s = quick save | oow.set_count N if sync fails | oow.set_cap at 100/100",
        "oow.save_health = integrity check | oow.reload_cache after refresh-save-cache.ps1",
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

if Config.PAUSE_UI_SYNC_AUTO then
    Log.warn("PAUSE_UI_SYNC_AUTO is on — may freeze Save Game menu; use oow.sync_count instead")
else
    Log.info("Pause UI sync: manual only (oow.sync_count) — auto disabled to avoid menu freeze")
end

Log.info("Ctrl+Shift+O auto-arms after load | oow.s | oow.help")
