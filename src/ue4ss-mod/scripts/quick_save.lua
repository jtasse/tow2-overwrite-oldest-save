local Config = require("config")
local Log = require("log")
local Feedback = require("feedback")
local SavesFs = require("saves_fs")
local SaveManager = require("save_manager")

local QuickSave = {}

local run_in_progress = false

local function ensure_ready()
    if run_in_progress then
        return false, "Save already in progress — wait ~2s."
    end
    SavesFs.ensure_cache(false)
    if not SavesFs.cache_ready() then
        return false, "Save cache missing. Run scripts\\refresh-save-cache.ps1 on host, then oow.save again."
    end
    return true, nil
end

local function is_quicksave_method(method)
    return method == "Quicksave"
        or (method and string.find(method, "Quicksave", 1, true))
end

local function verify_save_result(oldest, method)
    if is_quicksave_method(method) and not Config.ALLOW_QUICKSAVE_FALLBACK then
        return false, "Got Quicksave but manual SaveGame is required — check UE4SS.log"
    end
    if oldest then
        if is_quicksave_method(method) then
            return true, "replaced oldest (Quicksave)"
        end
        return true, "replaced oldest (SaveGame)"
    end
    if is_quicksave_method(method) then
        return false, "Below cap got Quicksave — manual SaveGame required"
    end
    return true, "SaveGame OK"
end

local function finish(ok, msg)
    run_in_progress = false
    Log.info(msg)
    Feedback.write_result(ok and "QUICK SAVE OK" or "QUICK SAVE FAILED", msg)
    if ok then
        local ok_ib, InputBindings = pcall(require, "input_bindings")
        if ok_ib and InputBindings.schedule_arm_after_save then
            InputBindings.schedule_arm_after_save()
        end
    end
    return ok, msg
end

function QuickSave.run(on_complete)
    local ready, err = ensure_ready()
    if not ready then
        return false, err
    end

    local at_cap, snap = SavesFs.resolve_cap_state()
    local oldest = nil
    if at_cap then
        oldest = SavesFs.oldest_manual_save()
        if not oldest then
            return false, "At cap but oldest slot missing in cache — run refresh-save-cache.ps1 on host."
        end
    end

    run_in_progress = true
    if oldest then
        Log.info(string.format(
            "At cap %s — removing oldest %s, then save.",
            snap.label,
            oldest.name
        ))
    else
        Log.info(string.format("Below cap (%s) — SaveGame.", snap.label))
    end

    ExecuteWithDelay(100, function()
        ExecuteInGameThread(function()
            local ok_run, err_run = pcall(function()
                if oldest then
                    Log.info("DeleteGame starting for " .. oldest.name)
                    local deleted = SaveManager.delete_slot(oldest.name)
                    if not deleted then
                        local ok_done, msg = finish(false, "FAILED: could not remove oldest save " .. oldest.name)
                        if on_complete then on_complete(ok_done, msg) end
                        return
                    end
                    SavesFs.remove_entry(oldest.name)
                    Feedback.mark_pending_orphan(oldest.name)
                end

                local save_delay = oldest and Config.POST_DELETE_DELAY_MS or 0
                ExecuteWithDelay(save_delay, function()
                    ExecuteInGameThread(function()
                        local saved, method
                        if oldest then
                            saved, method = SaveManager.save_after_cap_delete()
                        else
                            saved, method = SaveManager.save_below_cap()
                        end

                        if not saved then
                            local result_msg
                            if oldest then
                                result_msg = "FAILED: SaveGame did not run after delete — try pause menu Save Game."
                            elseif not at_cap and not snap.verified then
                                result_msg = "FAILED: Save blocked. If pause menu shows 100/100, run oow.set_cap then try again."
                            else
                                result_msg = "FAILED: SaveGame did not run — try pause menu Save Game."
                            end
                            local ok_done, msg = finish(false, result_msg)
                            if on_complete then on_complete(ok_done, msg) end
                            return
                        end

                        Log.info(string.format("Save command OK: %s", tostring(method)))
                        local verified, verify_detail = verify_save_result(oldest, method)
                        local result_msg
                        if verified then
                            if oldest then
                                result_msg = string.format(
                                    "SUCCESS: Saved at cap — replaced oldest %s (%s).",
                                    oldest.name,
                                    verify_detail
                                )
                            else
                                result_msg = string.format("SUCCESS: %s", verify_detail)
                            end
                        else
                            result_msg = "FAILED: " .. verify_detail
                        end
                        local ok_done, msg = finish(verified, result_msg)
                        if on_complete then on_complete(ok_done, msg) end
                    end)
                end)
            end)

            if not ok_run then
                local ok_done, msg = finish(false, "FAILED: quick save error — " .. tostring(err_run))
                if on_complete then on_complete(ok_done, msg) end
            end
        end)
    end)

    return true, "Save started. See mod-active.txt on host."
end

return QuickSave
