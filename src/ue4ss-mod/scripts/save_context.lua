local Config = require("config")
local Log = require("log")
local UiUtil = require("ui_util")
local SaveCount = require("save_count")
local SavesFs = require("saves_fs")

local SaveContext = {}

--- Checked at action time only (no session flags).
function SaveContext.is_on_save_game_screen_now()
    if not UiUtil.is_game_paused() then
        return false
    end

    local menu_root = UiUtil.find_save_load_menu_root(Config.MENU)
    if not UiUtil.is_valid(menu_root) or not UiUtil.is_widget_visible(menu_root) then
        return false
    end

    if not UiUtil.is_save_tab_blocked() then
        return false
    end

    return true
end

function SaveContext.read_menu_save_count()
    if not SaveContext.is_on_save_game_screen_now() then
        return nil, "not on Save Game screen"
    end
    local count = SaveCount.scrape_save_menu_count()
    if not count then
        return nil, "could not read x/100 from Save Game screen"
    end
    return count, nil
end

function SaveContext.can_use_hotkey()
    if Config.GAMEPLAY_QUICK_SAVE_ENABLED then
        return true, nil
    end
    if not UiUtil.is_game_paused() then
        return false, "Blocked — not on Save Game screen."
    end
    if SaveContext.is_on_save_game_screen_now() then
        return true, nil
    end
    return false, "Blocked — open pause → Save Game tab."
end

function SaveContext.prepare()
    if SaveContext.is_on_save_game_screen_now() then
        local count, err = SaveContext.read_menu_save_count()
        if not count then
            return nil, err or "Could not read x/100 from Save Game screen."
        end
        return {
            count = count,
            at_cap = count >= Config.MAX_MANUAL_SAVES,
            source = "save_menu_ui",
            label = string.format("%d/%d (save_menu_ui)", count, Config.MAX_MANUAL_SAVES),
        }, nil
    end

    if not Config.GAMEPLAY_QUICK_SAVE_ENABLED then
        return nil, "Blocked — open pause → Save Game. Overwrite only runs on that screen."
    end

    local at_cap, snap = SavesFs.resolve_cap_state()
    local count = snap.game
    if not count and at_cap then
        count = Config.MAX_MANUAL_SAVES
    end
    if not count then
        return nil, "Gameplay overwrite: save count unknown."
    end

    return {
        count = count,
        at_cap = at_cap,
        source = snap.cap_source or "gameplay",
        label = snap.label or string.format("%d/%d (gameplay)", count, Config.MAX_MANUAL_SAVES),
        gameplay = true,
    }, nil
end

return SaveContext
