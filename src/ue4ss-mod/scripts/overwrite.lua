-- Legacy name: overwrite is now quick save.
local QuickSave = require("quick_save")

local Overwrite = {}

function Overwrite.is_pending_confirm()
    return false
end

function Overwrite.snapshot()
    local SavesFs = require("saves_fs")
    return SavesFs.snapshot(true)
end

function Overwrite.check_manual_save(since_snapshot)
    local SavesFs = require("saves_fs")
    if not since_snapshot then
        return false, "No baseline snapshot."
    end
    return SavesFs.verify_overwrite_success(since_snapshot)
end

function Overwrite.request_confirm()
    return QuickSave.run()
end

function Overwrite.run_now(on_complete)
    return QuickSave.run(on_complete)
end

function Overwrite.delete_oldest_only()
    return QuickSave.run()
end

function Overwrite.execute_confirmed(on_complete)
    return QuickSave.run(on_complete)
end

function Overwrite.get_last_post_overwrite_snapshot()
    return nil
end

function Overwrite.run_with_confirm()
    return QuickSave.run()
end

return Overwrite
