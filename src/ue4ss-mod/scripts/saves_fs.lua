local Config = require("config")
local Log = require("log")

local SavesFs = {}

local cache = {
    list = nil,
    scanned_at = 0,
}

local CACHE_MAX_AGE_SEC = 120

local function is_guid_folder_name(name)
    return name and #name == 32 and string.match(name, "^[%x%x]+$") ~= nil
end

local function run_hidden_ps(script)
    if not io or not io.popen then
        return nil
    end
    local cmd = 'powershell -NoProfile -WindowStyle Hidden -Command "' .. script:gsub('"', '\\"') .. '"'
    local ok, pipe = pcall(io.popen, cmd, "r")
    if not ok or not pipe then
        return nil
    end
    local out = pipe:read("*a")
    pipe:close()
    return out
end

function SavesFs.refresh_cache()
    local root = Config.SAVE_ROOT:gsub("\\", "\\\\")
    local script = string.format(
        "$r='%s'; Get-ChildItem -LiteralPath $r -Directory | Where-Object { $_.Name -match '^[0-9A-F]{32}$' } | Sort-Object LastWriteTimeUtc | ForEach-Object { $_.Name }",
        root
    )
    local out = run_hidden_ps(script)
    local entries = {}
    if out and out ~= "" then
        for line in string.gmatch(out, "[^\r\n]+") do
            local name = line:match("^%s*(%S+)%s*$")
            if is_guid_folder_name(name) then
                entries[#entries + 1] = {
                    path = Config.SAVE_ROOT .. "\\" .. name,
                    name = name,
                }
            end
        end
    end
    cache.list = entries
    cache.scanned_at = os.time()
    Log.info(string.format("Save cache refreshed: %d manual folders", #entries))
    return #entries
end

function SavesFs.cache_ready()
    return cache.list ~= nil and #cache.list > 0
end

function SavesFs.ensure_cache()
    if cache.list and (os.time() - cache.scanned_at) < CACHE_MAX_AGE_SEC then
        return true
    end
    SavesFs.refresh_cache()
    return SavesFs.cache_ready()
end

function SavesFs.list_manual_saves()
    if not cache.list then
        return {}
    end
    return cache.list
end

function SavesFs.manual_save_count()
    return #SavesFs.list_manual_saves()
end

function SavesFs.is_at_cap()
    return SavesFs.manual_save_count() >= Config.MAX_MANUAL_SAVES
end

function SavesFs.oldest_manual_save()
    local list = SavesFs.list_manual_saves()
    if #list == 0 then
        return nil
    end
    return list[1]
end

function SavesFs.delete_folder(path)
    if not path or path == "" then
        return false
    end
    local escaped = path:gsub("\\", "\\\\"):gsub("'", "''")
    local script = string.format(
        "Remove-Item -LiteralPath '%s' -Recurse -Force -ErrorAction Stop",
        escaped
    )
    run_hidden_ps(script)
    Log.info("Filesystem delete attempted for: " .. path)
    return true
end

function SavesFs.describe_state()
    SavesFs.ensure_cache()
    local list = SavesFs.list_manual_saves()
    local oldest = list[1]
    local newest = list[#list]
    Log.info(string.format(
        "Saves: manual_folders=%d cap=%d oldest=%s newest=%s",
        #list,
        Config.MAX_MANUAL_SAVES,
        oldest and oldest.name or "(none)",
        newest and newest.name or "(none)"
    ))
end

return SavesFs
