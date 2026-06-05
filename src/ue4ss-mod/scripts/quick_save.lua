local Config = require("config")
local Log = require("log")
local Feedback = require("feedback")
local SavesFs = require("saves_fs")
local SaveManager = require("save_manager")

local QuickSave = {}

local run_in_progress = false

local function ensure_ready()
    if run_in_progress then
        return false, "Save already in progress — wait ~3s."
    end
    SavesFs.ensure_cache(true)
    if not SavesFs.cache_ready() then
        return false, "Save cache missing. Run scripts\\refresh-save-cache.ps1 on host, then oow.save again."
    end
    return true, nil
end

local function needs_delete_first()
    return SavesFs.manual_save_count() >= Config.MAX_MANUAL_SAVES
end

local function finish(ok, msg)
    run_in_progress = false
    Log.info(msg)
    Feedback.show_game_toast(msg)
    Feedback.write_result(ok and "QUICK SAVE OK" or "QUICK SAVE FAILED", msg)
    return ok, msg
end

function QuickSave.run(on_complete)
    local ready, err = ensure_ready()
    if not ready then
        return false, err
    end

    local oldest = nil
    if needs_delete_first() then
        oldest = SavesFs.oldest_manual_save()
        if not oldest then
            return false, "At 100/100 but no oldest save in cache — run refresh-save-cache.ps1 on host."
        end
    end

    run_in_progress = true
    local start_msg
    if oldest then
        start_msg = "Quick save: removing oldest " .. oldest.name .. " then saving..."
    else
        start_msg = "Quick save: saving..."
    end
    Log.info(start_msg)
    Feedback.show_game_toast(start_msg)

    ExecuteInGameThread(function()
        if oldest then
            local deleted = SaveManager.delete_slot(oldest.name)
            if not deleted then
                local fail_msg = "FAILED: could not remove oldest save " .. oldest.name
                local ok, msg = finish(false, fail_msg)
                if on_complete then
                    on_complete(ok, msg)
                end
                return
            end
            SavesFs.remove_entry(oldest.name)
            Feedback.mark_pending_orphan(oldest.name)
            Log.info("Oldest removed, calling Quicksave...")
        end

        ExecuteWithDelay(Config.POST_DELETE_DELAY_MS, function()
            local saved, method = SaveManager.quicksave()
            local result_msg
            if saved then
                result_msg = "SUCCESS: Quick save done (" .. tostring(method) .. ")."
            else
                result_msg = "FAILED: Quicksave/SaveGame did not run — try pause menu Save Game."
            end
            local ok, msg = finish(saved, result_msg)
            if on_complete then
                on_complete(ok, msg)
            end
        end)
    end)

    return true, "Quick save started (~3s). See mod-active.txt on host."
end

return QuickSave
