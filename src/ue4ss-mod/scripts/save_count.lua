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

local function scrape_widget_tree(root, seen, best_holder, depth)
    if not UiUtil.is_valid(root) or (depth or 0) > 10 then
        return
    end
    if UiUtil.is_widget_visible(root) then
        local text = UiUtil.get_widget_text(root)
        if text then
            consider_text(text, seen, best_holder)
        end
    end
    UiUtil.iter_widget_tree(root, function(widget)
        if UiUtil.is_widget_visible(widget) then
            local text = UiUtil.get_widget_text(widget)
            if text then
                consider_text(text, seen, best_holder)
            end
        end
    end, depth or 0)
end

function SaveCount.scrape_save_menu_count()
    local menu_root = UiUtil.find_save_load_menu_root(Config.MENU)
    if not UiUtil.is_valid(menu_root) then
        return nil
    end

    local seen = {}
    local best_holder = { value = nil }
    scrape_widget_tree(menu_root, seen, best_holder, 0)
    return best_holder.value
end

function SaveCount.try_sync_from_pause_ui(force)
    if not Config.GAMEPLAY_QUICK_SAVE_ENABLED then
        return nil
    end
    if not force and os.time() - last_scraped_at < SCRAPE_COOLDOWN_SEC then
        return nil
    end
    if not UiUtil.is_game_paused() or not UiUtil.is_save_load_menu_open(Config.MENU) then
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

return SaveCount
