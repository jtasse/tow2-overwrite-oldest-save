local Config = require("config")
local Log = require("log")
local SavesFs = require("saves_fs")
local SaveManager = require("save_manager")

local Overwrite = {}

local pending_confirm = false
local pending_started_at = 0
local CONFIRM_WINDOW_SEC = 30

local function clear_pending()
    pending_confirm = false
    pending_started_at = 0
end

function Overwrite.is_pending_confirm()
    if not pending_confirm then
        return false
    end
    if os.time() - pending_started_at > CONFIRM_WINDOW_SEC then
        clear_pending()
        return false
    end
    return true
end

function Overwrite.request_confirm()
    if not SavesFs.ensure_cache() then
        return false, "Save list not ready. Wait 3s after load, or run oow.discover_save."
    end

    if not SavesFs.is_at_cap() then
        local count = SavesFs.manual_save_count()
        return false, string.format(
            "Not at cap (%d / %d). Overwrite only when full.",
            count,
            Config.MAX_MANUAL_SAVES
        )
    end

    local oldest = SavesFs.oldest_manual_save()
    if not oldest then
        return false, "Could not find oldest save folder."
    end

    pending_confirm = true
    pending_started_at = os.time()
    return true, string.format(
        "Overwrite oldest slot %s? Run: oow.overwrite_confirm (30s)",
        oldest.name
    )
end

function Overwrite.execute_confirmed()
    clear_pending()

    if not SavesFs.is_at_cap() then
        return false, "Not at save cap — cancelled."
    end

    local oldest = SavesFs.oldest_manual_save()
    if not oldest then
        return false, "No oldest save folder found."
    end

    Log.info("Overwrite oldest: " .. oldest.name)

    local deleted, del_err = SaveManager.delete_slot(oldest.name)
    if not deleted then
        Log.warn("DeleteGame API failed: " .. tostring(del_err) .. " — deleting folder on disk")
        SavesFs.delete_folder(oldest.path)
    end

    local saved, save_err = SaveManager.save_current()
    if saved then
        SavesFs.describe_state()
        return true, "Overwrite complete (SaveGame called). Check your save list."
    end

    return true,
        "Oldest slot removed on disk. Use pause menu → Save Game now (should succeed)."
end

function Overwrite.run_with_confirm()
    if Overwrite.is_pending_confirm() then
        return Overwrite.execute_confirmed()
    end
    return Overwrite.request_confirm()
end

return Overwrite
