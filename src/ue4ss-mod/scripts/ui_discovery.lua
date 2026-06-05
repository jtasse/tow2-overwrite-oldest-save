local Config = require("config")
local Log = require("log")
local UiUtil = require("ui_util")

local UiDiscovery = {}

function UiDiscovery.run()
    Log.info("=== OverwriteOldestSave UI discovery ===")
    Log.info("Open pause menu → Save Game, then run oow.discover_ui")

    Log.info("PlayerController IsPaused: " .. tostring(UiUtil.is_game_paused()))
    Log.info("SaveLoadMenu open: " .. tostring(UiUtil.is_save_load_menu_open(Config.MENU)))
    Log.info("Save tab blocked (SaveGameBlocker): " .. tostring(UiUtil.is_save_tab_blocked()))

    local root = UiUtil.find_save_load_menu_root()
    if root then
        Log.info("SaveLoadMenu root: " .. UiUtil.safe_full_name(root))
    else
        Log.warn("SaveLoadMenu root not found — open Save Game screen first")
    end

    local anchor = UiUtil.find_save_load_injection_anchor(Config.MENU)
    if anchor then
        Log.info("Injection anchor candidate: " .. UiUtil.safe_full_name(anchor))
        local parent = UiUtil.get_parent_widget(anchor)
        if parent then
            Log.info("  parent: " .. UiUtil.safe_full_name(parent))
        end
    else
        Log.warn("No injection anchor found")
    end

    Log.info("--- SaveLoadMenu widgets ---")
    local save_lines = UiUtil.log_save_load_menu_widgets(40)
    if #save_lines == 0 then
        Log.warn("No SaveLoadMenu widgets listed")
    else
        for _, line in ipairs(save_lines) do
            Log.info("  " .. line)
        end
    end

    Log.info("=== end UI discovery ===")
end

return UiDiscovery
