local Config = require("config")
local Log = require("log")
local UiUtil = require("ui_util")
local SavesFs = require("saves_fs")

local SaveCount = {}

local last_scraped_at = 0
local SCRAPE_COOLDOWN_SEC = 1

local function cap_max()
    return Config.MAX_MANUAL_SAVES or 100
end

function SaveCount.parse_count_from_text(text)
    if not text or text == "" then
        return nil
    end
    local normalized = string.lower(text)
    local max = cap_max()
    local patterns = {
        "(%d+)%s*/%s*" .. max,
        "(%d+)%s+of%s+" .. max,
        "(%d+)%s+out%s+of%s+" .. max,
        "manual%s+saves?%s*:%s*(%d+)",
        "saves?%s*:%s*(%d+)%s*/%s*" .. max,
        "(%d+)%s*/%s*" .. max .. "%s*manual",
    }
    for _, pattern in ipairs(patterns) do
        local n = tonumber(string.match(normalized, pattern))
        if n and n >= 0 and n <= max then
            return n
        end
    end
    return nil
end

local function consider_text(text, seen, best_holder)
    local n = SaveCount.parse_count_from_text(text)
    if not n or seen[n] then
        return
    end
    seen[n] = true
    if not best_holder.value or n > best_holder.value then
        best_holder.value = n
    end
end

local function scrape_menu_root_only(menu_root, seen, best_holder)
    if not UiUtil.is_valid(menu_root) then
        return
    end
    local function visit(widget, depth)
        if not UiUtil.is_valid(widget) or (depth or 0) > 8 then
            return
        end
        if UiUtil.is_widget_visible(widget) then
            local text = UiUtil.get_widget_text(widget)
            if text then
                consider_text(text, seen, best_holder)
            end
        end
        UiUtil.iter_widget_tree(widget, function(child)
            visit(child, (depth or 0) + 1)
        end, depth or 0)
    end
    visit(menu_root, 0)
end

function SaveCount.scrape_save_menu_count()
    local menu_root = UiUtil.find_save_load_menu_root(Config.MENU)
    if not UiUtil.is_valid(menu_root) then
        return nil
    end

    local seen = {}
    local best_holder = { value = nil }
    scrape_menu_root_only(menu_root, seen, best_holder)
    return best_holder.value
end

function SaveCount.debug_scrape()
    local menu_root = UiUtil.find_save_load_menu_root(Config.MENU)
    local lines = {
        string.format("menu_root=%s", menu_root and UiUtil.safe_name(menu_root) or "nil"),
    }

    local samples = {}
    if UiUtil.is_valid(menu_root) then
        local function sample(widget, depth)
            if #samples >= 12 or not UiUtil.is_valid(widget) or (depth or 0) > 8 then
                return
            end
            if UiUtil.is_widget_visible(widget) then
                local text = UiUtil.get_widget_text(widget)
                if text and text ~= "" and string.find(text, "%d") then
                    samples[#samples + 1] = string.format("%s -> %q", UiUtil.safe_name(widget), text)
                end
            end
            UiUtil.iter_widget_tree(widget, function(child)
                sample(child, (depth or 0) + 1)
            end, depth or 0)
        end
        sample(menu_root, 0)
    end

    if #samples == 0 then
        lines[#lines + 1] = "no numeric text under SaveLoadMenu root"
    else
        for _, line in ipairs(samples) do
            lines[#lines + 1] = line
        end
    end

    local count = SaveCount.scrape_save_menu_count()
    lines[#lines + 1] = "parsed count: " .. tostring(count)
    local msg = table.concat(lines, " | ")
    Log.info("debug_sync: " .. msg)
    return true, msg
end

function SaveCount.try_sync_from_pause_ui(force)
    if Config.PAUSE_UI_SYNC_ENABLED == false then
        return nil
    end
    if not force and os.time() - last_scraped_at < SCRAPE_COOLDOWN_SEC then
        return nil
    end

    local menu_root = UiUtil.find_save_load_menu_root(Config.MENU)
    if not UiUtil.is_valid(menu_root) then
        if force then
            Log.warn("sync skipped: SaveLoadMenu root not found — open pause Save Game tab first")
        end
        return nil
    end

    last_scraped_at = os.time()
    local count = SaveCount.scrape_save_menu_count()
    if not count then
        return nil
    end

    local prev = SavesFs.read_persisted_save_count()
    if prev == count then
        return count
    end

    SavesFs.write_persisted_save_count(count, "pause_ui")
    Log.info(string.format("Save count synced from pause UI: %d/%d", count, cap_max()))
    return count
end

function SaveCount.note_successful_cap_save()
    SavesFs.write_persisted_save_count(cap_max(), "mod_save")
end

function SaveCount.note_successful_below_cap_save()
    local prev = SavesFs.read_persisted_save_count()
    if not prev or prev >= cap_max() then
        return
    end
    SavesFs.write_persisted_save_count(prev + 1, "mod_save")
end

function SaveCount.sync_now()
    local count = SaveCount.try_sync_from_pause_ui(true)
    if not count then
        return false,
            "Sync failed — open pause Save Game tab, then oow.sync_count or oow.debug_sync. "
            .. "Or: oow.set_count N / .\\scripts\\set-save-count.ps1 -Count N"
    end
    return true, string.format("Synced from pause UI: %d/%d", count, cap_max())
end

return SaveCount
