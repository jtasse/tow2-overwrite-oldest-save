local Config = require("config")
local Log = require("log")
local Feedback = require("feedback")
local QuickSave = require("quick_save")
local InputBindings = require("input_bindings")
local SavesFs = require("saves_fs")
local UiUtil = require("ui_util")

local Menu = {}

local injected = {
    row = nil,
    anchor = nil,
    panel = nil,
    menu_root = nil,
}

local refresh_token = 0

local function clear_injected()
    injected.row = nil
    injected.anchor = nil
    injected.panel = nil
    injected.menu_root = nil
end

local function row_label()
    return Config.MENU.ROW_LABEL
end

local function should_show_row()
    SavesFs.ensure_cache()
    return SavesFs.manual_save_count() >= Config.MAX_MANUAL_SAVES
end

local function update_row_label()
    if not UiUtil.is_valid(injected.row) then
        return
    end
    pcall(function()
        UiUtil.set_label_on_button(injected.row, row_label())
    end)
end

local function hide_row()
    if UiUtil.is_valid(injected.row) then
        pcall(function()
            UiUtil.set_visibility(injected.row, false)
        end)
    end
end

local function may_inject_ui()
    if not Config.MENU.AUTO_INJECT then
        return false
    end
    if not should_show_row() then
        return false
    end
    if not UiUtil.is_save_tab_blocked() then
        return false
    end
    return true
end

local function construct_row(anchor, menu_root, panel)
    local class = UiUtil.find_input_widget_class(Config.MENU)
    if not class and UiUtil.is_valid(anchor) then
        class = anchor:GetClass()
    end
    if not UiUtil.is_valid(class) then
        return nil, "no InputWidget class"
    end

    local outer = panel or menu_root or UiUtil.get_parent_widget(anchor)
    if not UiUtil.is_valid(outer) then
        return nil, "no outer for row"
    end

    local fname = nil
    pcall(function()
        fname = FName(Config.MENU.BUTTON_NAME)
    end)

    local row = nil
    local ok, err = pcall(function()
        if UiUtil.is_valid(anchor) then
            row = StaticConstructObject(class, outer, fname, 0, 0, false, false, anchor)
        else
            row = StaticConstructObject(class, outer, fname)
        end
    end)
    if not ok or not UiUtil.is_valid(row) then
        return nil, "StaticConstructObject failed: " .. tostring(err)
    end

    return row
end

function Menu.try_inject(verbose)
    local ok, err = pcall(function()
        if not UiUtil.is_save_tab_blocked() then
            if verbose then
                Log.info("inject: not on save-blocked screen (use Save Game, not Load Game)")
            end
            hide_row()
            error("not save tab")
        end

        if not should_show_row() then
            if verbose then
                Log.info("inject: not at save cap")
            end
            hide_row()
            error("not at cap")
        end

        if UiUtil.is_valid(injected.row) then
            UiUtil.set_visibility(injected.row, true)
            update_row_label()
            if verbose then
                Log.info("inject: row already present")
            end
            return
        end

        local anchor, menu_root = UiUtil.find_save_load_injection_anchor(Config.MENU)
        if not anchor then
            error("no anchor")
        end

        local panel = UiUtil.find_injection_panel(menu_root, anchor, Config.MENU.INJECTION_PANEL_NAMES)
        if not panel then
            error("no panel")
        end

        local row, construct_err = construct_row(anchor, menu_root, panel)
        if not row then
            error(construct_err or "construct failed")
        end

        if not UiUtil.add_child_to_panel(panel, row) then
            error("AddChild failed")
        end

        injected.row = row
        injected.anchor = anchor
        injected.panel = panel
        injected.menu_root = menu_root

        UiUtil.set_label_on_button(row, row_label())
        UiUtil.set_visibility(row, true)
        Log.info("Injected quick save row")
    end)

    if ok then
        return true, "injected"
    end
    return false, tostring(err)
end

function Menu.schedule_refresh()
    if not may_inject_ui() then
        return
    end
    refresh_token = refresh_token + 1
    local token = refresh_token

    for _, delay in ipairs(Config.MENU.POLL_DELAYS_MS) do
        ExecuteWithDelay(delay, function()
            if token ~= refresh_token or not may_inject_ui() then
                return
            end
            ExecuteInGameThread(function()
                Menu.try_inject(false)
            end)
        end)
    end
end

function Menu.on_keybind()
    InputBindings.trigger_quick_save()
end

function Menu.on_row_activated()
    Menu.on_keybind()
end

function Menu.install_hooks()
    if Config.MENU.AUTO_INJECT then
        pcall(function()
            NotifyOnNewObject(Config.MENU.SAVE_LOAD_MENU_CLASS, function(obj)
                ExecuteWithDelay(800, function()
                    ExecuteInGameThread(function()
                        if may_inject_ui() then
                            Menu.schedule_refresh()
                        end
                    end)
                end)
            end)
        end)
    else
        Log.info("UI auto-inject OFF — use oow.save in console")
    end
end

function Menu.install_keybind()
    -- Keyboard + gamepad installed from input_bindings.lua via main.lua
end

return Menu
