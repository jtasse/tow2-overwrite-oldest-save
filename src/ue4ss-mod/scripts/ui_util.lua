local Log = require("log")

local UiUtil = {}

function UiUtil.is_valid(obj)
    if not obj then
        return false
    end
    local ok, valid = pcall(function()
        return obj:IsValid()
    end)
    return ok and valid
end

function UiUtil.safe_name(obj)
    if not UiUtil.is_valid(obj) then
        return ""
    end
    local ok, name = pcall(function()
        return obj:GetName()
    end)
    return ok and name or ""
end

function UiUtil.safe_full_name(obj)
    if not UiUtil.is_valid(obj) then
        return ""
    end
    local ok, name = pcall(function()
        return obj:GetFullName()
    end)
    return ok and name or ""
end

function UiUtil.matches_any(haystack, patterns)
    if not haystack or haystack == "" or not patterns then
        return false
    end
    for _, pat in ipairs(patterns) do
        if string.find(haystack, pat, 1, true) or string.find(haystack, pat) then
            return true
        end
    end
    return false
end

function UiUtil.is_excluded_name(haystack, patterns)
    return UiUtil.matches_any(haystack, patterns)
end

function UiUtil.is_widget_visible(widget)
    if not UiUtil.is_valid(widget) then
        return false
    end
    local ok, vis = pcall(function()
        return widget:GetVisibility()
    end)
    if not ok then
        return true
    end
    return vis == 0 or vis == 3 or vis == 4
end

function UiUtil.is_game_paused()
    local pc = FindFirstOf("PlayerController")
    if not UiUtil.is_valid(pc) then
        return false
    end
    local ok, paused = pcall(function()
        return pc:IsPaused()
    end)
    return ok and paused == true
end

function UiUtil.iter_widgets(class_names, fn)
    local count = 0
    for _, class_name in ipairs(class_names) do
        local objs = FindAllOf(class_name)
        if objs then
            for _, obj in ipairs(objs) do
                if UiUtil.is_valid(obj) then
                    fn(obj)
                    count = count + 1
                end
            end
        end
    end
    return count
end

--- Any live SaveLoadMenu widget (TOW2 lists mostly WidgetTree children, not the root).
function UiUtil.is_save_tab_blocked()
    local blocked = false
    UiUtil.iter_widgets({ "UserWidget" }, function(widget)
        local full = UiUtil.safe_full_name(widget)
        if string.find(full, "SaveGameBlocker", 1, true) and UiUtil.is_widget_visible(widget) then
            blocked = true
        end
    end)
    return blocked
end

function UiUtil.is_save_load_menu_open(cfg)
    cfg = cfg or {}
    local marker = cfg.SAVE_LOAD_MENU_MARKER or "SaveLoadMenu_BP"
    local open = false
    UiUtil.iter_widgets({ "UserWidget", "Button", "CommonButtonBase" }, function(widget)
        local full = UiUtil.safe_full_name(widget)
        if string.find(full, marker, 1, true) and UiUtil.is_widget_visible(widget) then
            open = true
        end
    end)
    return open
end

function UiUtil.walk_to_save_menu_root(from_widget)
    local w = from_widget
    for _ = 1, 24 do
        if not UiUtil.is_valid(w) then
            return nil
        end
        local name = UiUtil.safe_name(w)
        local full = UiUtil.safe_full_name(w)
        if name == "SaveLoadMenu_BP_C" and not string.find(full, "WidgetTree.", 1, true) then
            return w
        end
        if string.find(full, "SaveLoadMenu_BP.SaveLoadMenu_BP_C", 1, true)
            and not string.find(full, "WidgetTree.", 1, true)
        then
            return w
        end
        local next_w = nil
        pcall(function()
            next_w = w:GetOuter()
        end)
        if not UiUtil.is_valid(next_w) then
            next_w = UiUtil.get_parent_widget(w)
        end
        w = next_w
    end
    return nil
end

function UiUtil.find_save_load_menu_root(cfg)
    cfg = cfg or {}
    local marker = cfg.SAVE_LOAD_MENU_MARKER or "SaveLoadMenu_BP"

    local root = nil
    UiUtil.iter_widgets({ "UserWidget" }, function(widget)
        if root then
            return
        end
        local name = UiUtil.safe_name(widget)
        local full = UiUtil.safe_full_name(widget)
        if name == "SaveLoadMenu_BP_C" and not string.find(full, "WidgetTree.", 1, true) then
            root = widget
        end
    end)
    if root then
        return root
    end

    UiUtil.iter_widgets({ "UserWidget" }, function(widget)
        if root then
            return
        end
        local full = UiUtil.safe_full_name(widget)
        if string.find(full, marker .. ".SaveLoadMenu_BP_C:WidgetTree.", 1, true) then
            root = UiUtil.walk_to_save_menu_root(widget)
        end
    end)
    return root
end

function UiUtil.call_function(obj, function_path, ...)
    if not UiUtil.is_valid(obj) then
        return false, "invalid object"
    end
    local ufunc = StaticFindObject(function_path)
    if not UiUtil.is_valid(ufunc) then
        return false, "function not found: " .. function_path
    end
    local args = { ... }
    local ok, err = pcall(function()
        if #args == 0 then
            obj:CallFunction(ufunc)
        else
            obj:CallFunction(ufunc, table.unpack(args))
        end
    end)
    return ok, err
end

function UiUtil.get_parent_widget(widget)
    if not UiUtil.is_valid(widget) then
        return nil
    end
    local ok, parent = pcall(function()
        return widget:GetParent()
    end)
    if ok and UiUtil.is_valid(parent) then
        return parent
    end
    ok, parent = pcall(function()
        return widget:GetOuter()
    end)
    if ok and UiUtil.is_valid(parent) then
        return parent
    end
    return nil
end

function UiUtil.find_widget_by_name(root, child_name)
    if not UiUtil.is_valid(root) or not child_name then
        return nil
    end
    local ok, child = pcall(function()
        return root:GetWidgetFromName(child_name)
    end)
    if ok and UiUtil.is_valid(child) then
        return child
    end
    return nil
end

function UiUtil.find_injection_panel(menu_root, anchor, panel_names)
    if menu_root then
        for _, panel_name in ipairs(panel_names) do
            local panel = UiUtil.find_widget_by_name(menu_root, panel_name)
            if UiUtil.is_valid(panel) then
                return panel
            end
        end
    end
    if UiUtil.is_valid(anchor) then
        return UiUtil.get_parent_widget(anchor)
    end
    return nil
end

function UiUtil.find_input_widget_class(cfg)
    for _, path in ipairs(cfg.INPUT_WIDGET_CLASS_PATHS or {}) do
        local class = StaticFindObject(path)
        if UiUtil.is_valid(class) then
            return class
        end
    end
    return nil
end

function UiUtil.set_text_on_widget(widget, text)
    if not UiUtil.is_valid(widget) then
        return false
    end

    local text_paths = {
        "/Script/UMG.TextBlock:SetText",
        "/Script/CommonUI.CommonTextBlock:SetText",
        "/Script/UMG.RichTextBlock:SetText",
    }
    for _, path in ipairs(text_paths) do
        if UiUtil.call_function(widget, path, text) then
            return true
        end
    end

    local ok_ftext, ftext = pcall(function()
        return FText(text)
    end)
    if ok_ftext and ftext then
        for _, path in ipairs(text_paths) do
            if UiUtil.call_function(widget, path, ftext) then
                return true
            end
        end
    end

    return false
end

function UiUtil.set_label_on_button(button, text)
    if not UiUtil.is_valid(button) then
        return false
    end

    if UiUtil.set_text_on_widget(button, text) then
        return true
    end

    local child_names = {
        "Text",
        "TextBlock",
        "Label",
        "ButtonText",
        "PrimaryText",
        "InputLabel",
        "PrimaryInputLabel",
        "SecondaryInputLabel",
        "InputLabel_BP",
    }
    for _, name in ipairs(child_names) do
        local child = UiUtil.find_widget_by_name(button, name)
        if child and UiUtil.set_text_on_widget(child, text) then
            return true
        end
    end

    UiUtil.iter_widget_tree(button, function(w)
        local n = UiUtil.safe_name(w)
        if string.find(n, "Label", 1, true) or string.find(n, "Text", 1, true) then
            if UiUtil.set_text_on_widget(w, text) then
                return true
            end
        end
    end)

    return false
end

function UiUtil.iter_widget_tree(root, fn, depth)
    if not UiUtil.is_valid(root) or (depth or 0) > 8 then
        return false
    end
    if fn(root) == true then
        return true
    end
    local get_children = StaticFindObject("/Script/UMG.PanelWidget:GetAllChildren")
    if UiUtil.is_valid(get_children) then
        pcall(function()
            local children = root:CallFunction(get_children)
            if type(children) == "table" then
                for _, child in ipairs(children) do
                    if UiUtil.iter_widget_tree(child, fn, (depth or 0) + 1) then
                        return
                    end
                end
            end
        end)
    end
    return false
end

function UiUtil.set_visibility(widget, visible)
    if not UiUtil.is_valid(widget) then
        return
    end
    UiUtil.call_function(widget, "/Script/UMG.Widget:SetVisibility", visible and 0 or 1)
end

function UiUtil.add_child_to_panel(panel, child)
    if not UiUtil.is_valid(panel) or not UiUtil.is_valid(child) then
        return false
    end
    if UiUtil.call_function(panel, "/Script/UMG.PanelWidget:AddChild", child) then
        return true
    end
    if UiUtil.call_function(panel, "/Script/UMG.VerticalBox:AddChildToVerticalBox", child) then
        return true
    end
    if UiUtil.call_function(panel, "/Script/UMG.Overlay:AddChildToOverlay", child) then
        return true
    end
    return false
end

function UiUtil.find_save_load_injection_anchor(cfg)
    local menu_root = UiUtil.find_save_load_menu_root(cfg)

    if menu_root then
        for _, widget_name in ipairs(cfg.INJECTION_WIDGET_NAMES) do
            local anchor = UiUtil.find_widget_by_name(menu_root, widget_name)
            if UiUtil.is_valid(anchor) then
                return anchor, menu_root
            end
        end
    end

    local best = nil
    local best_score = -1

    UiUtil.iter_widgets(cfg.WIDGET_CLASSES, function(widget)
        local full = UiUtil.safe_full_name(widget)
        local short = UiUtil.safe_name(widget)
        local blob = full .. " " .. short

        if not string.find(full, cfg.SAVE_LOAD_MENU_MARKER, 1, true) then
            return
        end
        if UiUtil.is_excluded_name(blob, cfg.ANCHOR_EXCLUDE_PATTERNS) then
            return
        end

        local score = 0
        if string.find(full, "InputWidget_BP", 1, true) then
            score = score + 5
        end
        if string.find(short, "OOW_", 1, true) then
            return
        end

        if score > best_score then
            best_score = score
            best = widget
        end
    end)

    if best and not menu_root then
        menu_root = UiUtil.walk_to_save_menu_root(best)
    end

    return best, menu_root
end

function UiUtil.is_our_injected_widget(widget, button_name, injected_row)
    local w = widget
    while UiUtil.is_valid(w) do
        if w == injected_row then
            return true
        end
        if UiUtil.safe_name(w) == button_name then
            return true
        end
        if string.find(UiUtil.safe_full_name(w), button_name, 1, true) then
            return true
        end
        w = UiUtil.get_parent_widget(w)
    end
    return false
end

function UiUtil.log_save_load_menu_widgets(limit)
    limit = limit or 30
    local lines = {}
    UiUtil.iter_widgets({ "UserWidget", "Button", "CommonButtonBase" }, function(widget)
        if #lines >= limit then
            return
        end
        local full = UiUtil.safe_full_name(widget)
        if string.find(full, "SaveLoadMenu_BP", 1, true) then
            lines[#lines + 1] = full
        end
    end)
    table.sort(lines)
    return lines
end

function UiUtil.log_visible_menu_widgets(limit)
    limit = limit or 40
    local lines = {}
    UiUtil.iter_widgets({ "UserWidget", "CommonButtonBase", "Button" }, function(widget)
        if #lines >= limit then
            return
        end
        local full = UiUtil.safe_full_name(widget)
        if UiUtil.matches_any(full, { "Pause", "Menu", "Save", "Load", "WBP_" }) then
            lines[#lines + 1] = full
        end
    end)
    table.sort(lines)
    return lines
end

return UiUtil
