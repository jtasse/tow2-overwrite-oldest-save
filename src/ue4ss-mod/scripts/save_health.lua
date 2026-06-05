local Log = require("log")
local SavesFs = require("saves_fs")
local Config = require("config")

local SaveHealth = {}

function SaveHealth.report()
    SavesFs.ensure_cache(true)
    local disk = SavesFs.manual_save_count()
    local game = SavesFs.get_game_manual_count()
    local oldest = SavesFs.oldest_manual_save()
    local newest = SavesFs.list_manual_saves()
    newest = newest[#newest]

    local lines = {
        string.format("Disk folders (cache): %d / %d", disk, Config.MAX_MANUAL_SAVES),
    }

    if game then
        lines[#lines + 1] = string.format("Engine save count: %d", game)
    else
        lines[#lines + 1] = "Engine save count: (unknown - run oow.discover_save)"
    end

    if oldest then
        lines[#lines + 1] = "Oldest folder: " .. oldest.name
    end
    if newest then
        lines[#lines + 1] = "Newest folder: " .. newest.name
    end

    if disk >= Config.MAX_MANUAL_SAVES then
        lines[#lines + 1] = "At cap: oow.save deletes oldest then Quicksave."
    elseif disk == Config.MAX_MANUAL_SAVES - 1 then
        lines[#lines + 1] = "Room for one more: oow.save will quicksave without deleting."
    else
        lines[#lines + 1] = string.format("%d saves — oow.save works normally.", disk)
    end

    lines[#lines + 1] = "Run scripts\\refresh-save-cache.ps1 after any save (outside game)."

    local msg = table.concat(lines, " | ")
    Log.info("save_health: " .. msg)
    return true, msg
end

return SaveHealth
