local Log = require("log")
local SavesFs = require("saves_fs")
local Config = require("config")

local SaveHealth = {}

function SaveHealth.report()
    SavesFs.ensure_cache(true)
    local disk = SavesFs.manual_save_count()
    local game = SavesFs.get_game_manual_count()
    local host_cap = SavesFs.read_host_cap_count()
    local at_cap, cap_snap = SavesFs.resolve_cap_state()
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

    if host_cap then
        lines[#lines + 1] = string.format("Cap marker: %d/100 (oow.set_cap)", host_cap)
    else
        lines[#lines + 1] = "Cap marker: none (run oow.set_cap when pause menu shows 100/100)"
    end

    if oldest then
        lines[#lines + 1] = "Oldest folder: " .. oldest.name
    end
    if newest then
        lines[#lines + 1] = "Newest folder: " .. newest.name
    end

    if at_cap then
        lines[#lines + 1] = string.format(
            "At cap (%s): oow.save will DeleteGame oldest + Quicksave.",
            cap_snap.cap_source or "unknown"
        )
    elseif game then
        lines[#lines + 1] = string.format(
            "Below cap (engine %d/%d): oow.save will NOT delete.",
            game,
            Config.MAX_MANUAL_SAVES
        )
    else
        lines[#lines + 1] = "Cap unknown: run oow.set_cap if pause menu shows 100/100."
    end
    if disk >= Config.MAX_MANUAL_SAVES and (not game or game < Config.MAX_MANUAL_SAVES) then
        lines[#lines + 1] = string.format(
            "Note: disk has %d folders — orphans do not trigger delete. Run refresh-save-cache.ps1.",
            disk
        )
    end

    lines[#lines + 1] = "Run scripts\\refresh-save-cache.ps1 after any save (outside game)."

    local msg = table.concat(lines, " | ")
    Log.info("save_health: " .. msg)
    return true, msg
end

return SaveHealth
