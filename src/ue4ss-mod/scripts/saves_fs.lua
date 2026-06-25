local Config = require("config")
local Log = require("log")

local SavesFs = {}

local cache = {
    list = nil,
    scanned_at = 0,
    source = nil,
}

local CACHE_MAX_AGE_SEC = 120

local function cache_file_path()
    local base = os.getenv("LOCALAPPDATA") or ""
    if base == "" then
        return nil
    end
    return base .. "\\OverwriteOldestSave-save-cache.json"
end

local function is_guid_folder_name(name)
    return name and #name == 32 and string.match(name, "^[%x%x]+$") ~= nil
end

local function invalidate_cache()
    cache.list = nil
    cache.scanned_at = 0
    cache.source = nil
end

local function parse_cache_json(text)
    if not text or text == "" then
        return nil, "empty cache file"
    end

    local count = tonumber(text:match('"count"%s*:%s*(%d+)'))
    local entries = {}
    for name in string.gmatch(text, '"name"%s*:%s*"([0-9A-Fa-f]+)"') do
        if is_guid_folder_name(name) then
            entries[#entries + 1] = {
                name = name:upper(),
                path = Config.SAVE_ROOT .. "\\" .. name:upper(),
            }
        end
    end

    if #entries == 0 and count and count > 0 then
        return nil, "cache parse failed"
    end

    return entries, nil
end

local function load_cache_file()
    local path = cache_file_path()
    if not path then
        return false, "LOCALAPPDATA unavailable"
    end

    local file = io.open(path, "r")
    if not file then
        return false, "no cache file — run scripts\\refresh-save-cache.ps1 outside the game"
    end

    local text = file:read("*a")
    file:close()

    local entries, err = parse_cache_json(text)
    if not entries then
        return false, err or "cache unreadable"
    end

    cache.list = entries
    cache.scanned_at = os.time()
    cache.source = path
    Log.info(string.format("Save cache loaded from file: %d manual folders", #entries))
    return true, nil
end

function SavesFs.refresh_cache()
    local ok, err = load_cache_file()
    if not ok then
        Log.warn("Save cache refresh failed: " .. tostring(err))
        cache.list = cache.list or {}
        cache.scanned_at = os.time()
    end
    return #SavesFs.list_manual_saves()
end

function SavesFs.cache_ready()
    return cache.list ~= nil and #cache.list > 0
end

function SavesFs.ensure_cache(force)
    if not force and cache.list and (os.time() - cache.scanned_at) < CACHE_MAX_AGE_SEC then
        return true
    end
    SavesFs.refresh_cache()
    return cache.list ~= nil
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

function SavesFs.build_name_set(list)
    local names = {}
    for _, entry in ipairs(list or {}) do
        names[entry.name] = true
    end
    return names
end

function SavesFs.name_in_cache(name)
    if not name or not cache.list then
        return false
    end
    local upper = string.upper(name)
    for _, entry in ipairs(cache.list) do
        if entry.name == upper then
            return true
        end
    end
    return false
end

local function cap_marker_path()
    return Config.CAP_MARKER_FILE
end

local function save_count_path()
    return Config.SAVE_COUNT_FILE
end

local function parse_save_count_json(text)
    if not text or text == "" then
        return nil
    end
    local count = tonumber(text:match('"count"%s*:%s*(%d+)'))
    if not count or count < 0 then
        return nil
    end
    local source = text:match('"source"%s*:%s*"([^"]+)"')
    local updated_at = text:match('"updatedAt"%s*:%s*"([^"]+)"')
    return {
        count = count,
        source = source,
        updatedAt = updated_at,
    }
end

function SavesFs.read_persisted_save_state()
    local path = save_count_path()
    if path and path ~= "" then
        local file = io.open(path, "r")
        if file then
            local text = file:read("*a")
            file:close()
            local state = parse_save_count_json(text)
            if state then
                return state
            end
        end
    end

    return nil
end

function SavesFs.read_persisted_save_count()
    local state = SavesFs.read_persisted_save_state()
    return state and state.count or nil
end

function SavesFs.write_persisted_save_count(count, source)
    local path = save_count_path()
    if not path or path == "" then
        return false, "LOCALAPPDATA unavailable"
    end
    local n = tonumber(count)
    if not n or n < 0 then
        return false, "invalid count"
    end
    if n > Config.MAX_MANUAL_SAVES then
        n = Config.MAX_MANUAL_SAVES
    end

    local payload = string.format(
        '{"count":%d,"source":"%s","updatedAt":"%s"}',
        n,
        tostring(source or "unknown"),
        os.date("%Y-%m-%dT%H:%M:%SZ")
    )
    local file = io.open(path, "w")
    if not file then
        return false, "could not write save count"
    end
    file:write(payload)
    file:close()

    local cap_path = cap_marker_path()
    if n >= Config.MAX_MANUAL_SAVES then
        if cap_path and cap_path ~= "" then
            local cap_payload = string.format(
                '{"atCap":true,"count":%d,"setAt":"%s","source":"in-game"}',
                n,
                os.date("%Y-%m-%dT%H:%M:%SZ")
            )
            local cap_file = io.open(cap_path, "w")
            if cap_file then
                cap_file:write(cap_payload)
                cap_file:close()
            end
        end
    elseif cap_path and cap_path ~= "" then
        os.remove(cap_path)
    end

    Log.info(string.format("Save count persisted: %d/%d (%s)", n, Config.MAX_MANUAL_SAVES, tostring(source)))
    return true, string.format("Save count %d/%d (%s).", n, Config.MAX_MANUAL_SAVES, tostring(source))
end

function SavesFs.read_host_cap_count()
    local path = cap_marker_path()
    if not path or path == "" then
        return nil
    end
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    if not text or text == "" then
        return nil
    end
    local count = tonumber(text:match('"count"%s*:%s*(%d+)'))
        or tonumber(text:match('"atCap"%s*:%s*true') and tostring(Config.MAX_MANUAL_SAVES))
    if count and count >= Config.MAX_MANUAL_SAVES then
        return count
    end
    return nil
end

function SavesFs.write_host_cap_marker(count)
    local n = tonumber(count) or Config.MAX_MANUAL_SAVES
    local ok, msg = SavesFs.write_persisted_save_count(n, "set_cap")
    if not ok then
        return false, msg
    end
    return true, string.format("Cap marker set (%d/100). Open Save Game tab to resync after deleting saves.", n)
end

function SavesFs.clear_host_cap_marker()
    local path = cap_marker_path()
    if not path or path == "" then
        return false, "LOCALAPPDATA unavailable"
    end
    os.remove(path)
    Log.info("Cap marker cleared")
    return true, "Cap marker cleared — open pause Save Game tab to resync x/100, or run oow.sync_count there."
end

local function read_bool_property(obj, prop_name)
    local ok, val = pcall(function()
        return obj:GetPropertyValue(prop_name)
    end)
    if ok and type(val) == "boolean" then
        return val
    end
    ok, val = pcall(function()
        return obj[prop_name]
    end)
    if ok and type(val) == "boolean" then
        return val
    end
    return nil
end

local function read_number_property(obj, prop_name)
    local ok, val = pcall(function()
        return obj:GetPropertyValue(prop_name)
    end)
    if ok and type(val) == "number" then
        return val
    end
    ok, val = pcall(function()
        return obj[prop_name]
    end)
    if ok and type(val) == "number" then
        return val
    end
    return nil
end

local function read_array_length(obj, prop_name)
    local val = nil
    local ok = pcall(function()
        val = obj:GetPropertyValue(prop_name)
    end)
    if not ok or val == nil then
        ok = pcall(function()
            val = obj[prop_name]
        end)
    end
    if not ok or val == nil then
        return nil
    end

    local ok_num, num = pcall(function()
        return val:GetArrayNum()
    end)
    if ok_num and type(num) == "number" and num >= 0 then
        return num
    end

    ok_num, num = pcall(function()
        return #val
    end)
    if ok_num and type(num) == "number" and num >= 0 then
        return num
    end

    return nil
end

function SavesFs.get_game_manual_count()
    local SaveManager = require("save_manager")
    local mgr = SaveManager.get()
    if not mgr then
        return nil
    end

    for _, prop_name in ipairs(Config.SAVE_MANAGER_CAP_BOOL_CANDIDATES or {}) do
        if read_bool_property(mgr, prop_name) == true then
            return Config.MAX_MANUAL_SAVES
        end
    end

    for _, prop_name in ipairs({ "ManualSaveCount", "NumManualSaves", "NumSaveGames", "SaveGameCount" }) do
        local val = read_number_property(mgr, prop_name)
        if val then
            return val
        end
    end

    for _, prop_name in ipairs({ "SaveGames", "ManualSaveSlots", "SaveSlots", "Saves" }) do
        local len = read_array_length(mgr, prop_name)
        if len then
            return len
        end
    end

    for _, prop_name in ipairs(Config.SAVE_MANAGER_PROPERTY_CANDIDATES) do
        if prop_name == "MaxManualSaves" then
            -- Cap constant, not current occupancy.
        elseif string.find(prop_name, "Count", 1, true) or string.find(prop_name, "Num", 1, true) then
            local val = read_number_property(mgr, prop_name)
            if val then
                return val
            end
        else
            local len = read_array_length(mgr, prop_name)
            if len then
                return len
            end
        end
    end

    return nil
end

function SavesFs.resolve_cap_state()
    local game = SavesFs.get_game_manual_count()
    local disk = SavesFs.manual_save_count()
    local persisted = SavesFs.read_persisted_save_state()
    local host_cap = SavesFs.read_host_cap_count()

    local at_cap = false
    local source = nil
    local count = game

    if game and game >= Config.MAX_MANUAL_SAVES then
        at_cap = true
        source = "engine"
    elseif game then
        at_cap = false
        source = "engine"
    elseif persisted and persisted.count then
        count = persisted.count
        at_cap = count >= Config.MAX_MANUAL_SAVES
        source = persisted.source or "persisted"
    elseif Config.AT_CAP_OVERRIDE then
        at_cap = true
        source = "config"
        count = Config.MAX_MANUAL_SAVES
    elseif host_cap and host_cap >= Config.MAX_MANUAL_SAVES then
        at_cap = true
        source = "host_marker"
        count = host_cap
    end

    local label
    if count and source then
        label = string.format("%d/%d (%s)", count, Config.MAX_MANUAL_SAVES, source)
    elseif at_cap and source then
        label = string.format("100/100 (%s)", source)
    else
        label = string.format(
            "count unknown — open pause Save Game tab or oow.set_cap if menu shows 100/100 (disk cache %d)",
            disk
        )
    end

    return at_cap, {
        game = count,
        disk = disk,
        label = label,
        verified = source ~= nil,
        cap_source = source,
        persisted = persisted,
    }
end

function SavesFs.cap_status()
    SavesFs.ensure_cache()
    local folders = SavesFs.manual_save_count()
    local game_count = SavesFs.get_game_manual_count()
    return {
        folders = folders,
        game_count = game_count,
        cap = Config.MAX_MANUAL_SAVES,
        cache_source = cache.source,
    }
end

function SavesFs.is_at_cap()
    SavesFs.ensure_cache()
    local disk = SavesFs.manual_save_count()
    if disk >= Config.MAX_MANUAL_SAVES then
        return true
    end
    local game = SavesFs.get_game_manual_count()
    if game and game >= Config.MAX_MANUAL_SAVES then
        return true
    end
    return false
end

function SavesFs.is_stuck_below_cap()
    SavesFs.ensure_cache()
    local disk = SavesFs.manual_save_count()
    if disk >= Config.MAX_MANUAL_SAVES then
        return false
    end
    local game = SavesFs.get_game_manual_count()
    if game and game >= Config.MAX_MANUAL_SAVES then
        return true, disk, game
    end
    return false
end

function SavesFs.remove_entry(name)
    if not cache.list or not name then
        return
    end
    local upper = string.upper(name)
    local kept = {}
    for _, entry in ipairs(cache.list) do
        if entry.name ~= upper then
            kept[#kept + 1] = entry
        end
    end
    cache.list = kept
    Log.info(string.format("Cache entry removed: %s (now %d saves in cache)", upper, #kept))
end

function SavesFs.oldest_manual_save()
    local list = SavesFs.list_manual_saves()
    if #list == 0 then
        return nil
    end
    return list[1]
end

-- Lightweight disk scan for post-save verification (gameplay only; avoid pause menu).
function SavesFs.scan_disk_guid_names()
    local root = Config.SAVE_ROOT
    if not root or root == "" then
        return nil
    end
    local cmd = string.format('cmd /c dir /b /ad "%s" 2>nul', root)
    local handle = io.popen(cmd, "r")
    if not handle then
        return nil
    end
    local names = {}
    for line in handle:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if is_guid_folder_name(trimmed) then
            names[#names + 1] = trimmed:upper()
        end
    end
    pcall(function()
        handle:close()
    end)
    if #names == 0 then
        return nil
    end
    return names
end

function SavesFs.find_new_disk_folder(before_names)
    local names = SavesFs.scan_disk_guid_names()
    if not names then
        return nil, "disk scan unavailable"
    end
    for _, name in ipairs(names) do
        if not before_names or not before_names[name] then
            return name, nil
        end
    end
    return nil, "no new save folder on disk"
end

function SavesFs.snapshot(force_refresh)
    if force_refresh then
        SavesFs.refresh_cache()
    else
        SavesFs.ensure_cache()
    end
    local list = SavesFs.list_manual_saves()
    local oldest = list[1]
    local newest = list[#list]
    return {
        count = #list,
        names = SavesFs.build_name_set(list),
        oldest = oldest and oldest.name or nil,
        oldest_path = oldest and oldest.path or nil,
        newest = newest and newest.name or nil,
        newest_path = newest and newest.path or nil,
        at = os.time(),
    }
end

function SavesFs.verify_overwrite_success(before)
    SavesFs.refresh_cache()
    local list = SavesFs.list_manual_saves()
    local count = #list

    if count < Config.MAX_MANUAL_SAVES then
        return false, string.format("only %d/100 folders after save", count)
    end

    local new_slots = {}
    for _, entry in ipairs(list) do
        if before.names and not before.names[entry.name] then
            new_slots[#new_slots + 1] = entry.name
        end
    end

    if #new_slots > 0 then
        return true, "new save slot " .. new_slots[1]
    end

    if before.oldest then
        local oldest_now = list[1]
        if oldest_now and oldest_now.name ~= before.oldest then
            return true, "oldest rotated (" .. before.oldest .. " -> " .. oldest_now.name .. ")"
        end
    end

    return false, "no new manual save folder — engine manual-save API not hooked yet"
end

function SavesFs.describe_snapshot(tag, snap)
    if not snap then
        return tag .. ": (no data)"
    end
    return string.format(
        "%s: folders=%d oldest=%s newest=%s",
        tag,
        snap.count or 0,
        snap.oldest or "(none)",
        snap.newest or "(none)"
    )
end

function SavesFs.folder_exists(path)
    if not path or path == "" then
        return false
    end
    SavesFs.ensure_cache()
    local name = path:match("[^\\]+$")
    return SavesFs.name_in_cache(name)
end

function SavesFs.delete_folder(_path)
    Log.warn("Filesystem delete disabled — run refresh-save-cache.ps1 after any manual disk changes.")
    return false
end

function SavesFs.describe_state()
    SavesFs.ensure_cache()
    local list = SavesFs.list_manual_saves()
    local oldest = list[1]
    local newest = list[#list]
    Log.info(string.format(
        "Saves: manual_folders=%d cap=%d oldest=%s newest=%s source=%s",
        #list,
        Config.MAX_MANUAL_SAVES,
        oldest and oldest.name or "(none)",
        newest and newest.name or "(none)",
        cache.source or "(none)"
    ))
end

return SavesFs
