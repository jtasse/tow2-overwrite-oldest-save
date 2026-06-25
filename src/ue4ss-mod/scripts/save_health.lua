local Log = require("log")
local SavesFs = require("saves_fs")
local Config = require("config")

local SaveHealth = {}

function SaveHealth.report()
    SavesFs.ensure_cache(true)
    local disk = SavesFs.manual_save_count()
    local game = SavesFs.get_game_manual_count()
    local host_cap = SavesFs.read_host_cap_count()
    local persisted = SavesFs.read_persisted_save_state()
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

    if persisted and persisted.count then
        lines[#lines + 1] = string.format(
            "Tracked save count: %d/100 (%s)",
            persisted.count,
            persisted.source or "unknown"
        )
    else
        lines[#lines + 1] = "Tracked save count: none (open pause Save Game tab to sync)"
    end

    if host_cap then
        lines[#lines + 1] = string.format("Cap marker file: %d/100", host_cap)
    else
        lines[#lines + 1] = "Cap marker file: none"
    end

    if host_cap and host_cap >= Config.MAX_MANUAL_SAVES and persisted and persisted.count and persisted.count < Config.MAX_MANUAL_SAVES then
        lines[#lines + 1] = string.format(
            "Stale cap marker (%d tracked): open Save Game tab or oow.sync_count — saves were replacing oldest at %d/100.",
            persisted.count,
            persisted.count
        )
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
        lines[#lines + 1] = "Cap unknown: open pause Save Game tab, or oow.set_cap if menu shows 100/100."
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
