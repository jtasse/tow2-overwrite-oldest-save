local Config = require("config")
local Log = require("log")
local QuickSave = require("quick_save")

local InputBindings = {}

local last_trigger_at = 0
local DEBOUNCE_MS = 800

local GAMEPAD_KEY_CANDIDATES = {
    left = {
        "Gamepad_LeftShoulder",
        "Gamepad_LeftShoulder_Button",
        "LeftShoulder",
    },
    right = {
        "Gamepad_RightShoulder",
        "Gamepad_RightShoulder_Button",
        "RightShoulder",
    },
    action = {
        "Gamepad_FaceButton_Bottom",
        "Gamepad_FaceButton_A",
        "FaceButton_Bottom",
    },
}

local resolved_keys = {
    left = nil,
    right = nil,
    action = nil,
}

local function get_player_controller()
    local pc = FindFirstOf("PlayerController")
    if pc then
        local ok, valid = pcall(function()
            return pc:IsValid()
        end)
        if ok and valid then
            return pc
        end
    end
    return nil
end

local function make_key(name)
    if FName then
        local ok, key = pcall(function()
            return FName(name)
        end)
        if ok and key then
            return key
        end
    end
    return name
end

local function is_key_down(pc, key_name)
    local key = make_key(key_name)
    local ok, ret = pcall(function()
        return pc:IsInputKeyDown(key)
    end)
    if ok and ret then
        return true
    end
    ok, ret = pcall(function()
        return pc:IsInputKeyDown(key, false)
    end)
    return ok and ret == true
end

local function was_key_pressed(pc, key_name)
    local key = make_key(key_name)
    local ok, ret = pcall(function()
        return pc:WasInputKeyJustPressed(key)
    end)
    if ok and ret then
        return true
    end
    ok, ret = pcall(function()
        return pc:WasInputKeyJustPressed(key, false)
    end)
    return ok and ret == true
end

local function resolve_gamepad_keys(pc)
    if resolved_keys.left and resolved_keys.right and resolved_keys.action then
        return true
    end
    for _, name in ipairs(GAMEPAD_KEY_CANDIDATES.left) do
        if is_key_down(pc, name) or was_key_pressed(pc, name) then
            resolved_keys.left = name
            Log.info("Gamepad left key resolved: " .. name)
            break
        end
    end
    for _, name in ipairs(GAMEPAD_KEY_CANDIDATES.right) do
        if is_key_down(pc, name) or was_key_pressed(pc, name) then
            resolved_keys.right = name
            Log.info("Gamepad right key resolved: " .. name)
            break
        end
    end
    for _, name in ipairs(GAMEPAD_KEY_CANDIDATES.action) do
        if is_key_down(pc, name) or was_key_pressed(pc, name) then
            resolved_keys.action = name
            Log.info("Gamepad action key resolved: " .. name)
            break
        end
    end
    if not resolved_keys.left then
        resolved_keys.left = Config.INPUT.GAMEPAD.left[1]
    end
    if not resolved_keys.right then
        resolved_keys.right = Config.INPUT.GAMEPAD.right[1]
    end
    if not resolved_keys.action then
        resolved_keys.action = Config.INPUT.GAMEPAD.action[1]
    end
    return true
end

local function should_trigger()
    local now = os.clock() * 1000
    if now - last_trigger_at < DEBOUNCE_MS then
        return false
    end
    last_trigger_at = now
    return true
end

function InputBindings.trigger_quick_save()
    if not should_trigger() then
        return
    end
    ExecuteWithDelay(0, function()
        QuickSave.run()
    end)
end

local function check_gamepad_combo()
    if not Config.INPUT.GAMEPAD_ENABLED then
        return
    end

    local pc = get_player_controller()
    if not pc then
        return
    end

    resolve_gamepad_keys(pc)

    local left_name = resolved_keys.left
    local right_name = resolved_keys.right
    local action_name = resolved_keys.action
    if not left_name or not right_name or not action_name then
        return
    end

    if not (is_key_down(pc, left_name) and is_key_down(pc, right_name)) then
        return
    end

    if was_key_pressed(pc, action_name) then
        Log.info("Gamepad combo: " .. left_name .. " + " .. right_name .. " + tap " .. action_name)
        InputBindings.trigger_quick_save()
    end
end

local function poll_gamepad_loop()
    ExecuteInGameThread(function()
        check_gamepad_combo()
    end)
    ExecuteWithDelay(Config.INPUT.GAMEPAD_POLL_MS, poll_gamepad_loop)
end

function InputBindings.install_keyboard()
    local kb = Config.INPUT.KEYBOARD
    pcall(function()
        RegisterKeyBind(kb.key, kb.modifiers, function()
            Log.info("Keyboard: Ctrl+Shift+O")
            InputBindings.trigger_quick_save()
        end)
        Log.info("Keyboard: Ctrl+Shift+O = quick save")
    end)
end

function InputBindings.install_gamepad()
    if not Config.INPUT.GAMEPAD_ENABLED then
        return
    end
    local gp = Config.INPUT.GAMEPAD
    resolved_keys.left = gp.left[1]
    resolved_keys.right = gp.right[1]
    resolved_keys.action = gp.action[1]
    poll_gamepad_loop()
    Log.info(string.format(
        "Gamepad: hold %s + %s, tap %s (A) = quick save",
        resolved_keys.left,
        resolved_keys.right,
        resolved_keys.action
    ))
end

function InputBindings.install()
    InputBindings.install_keyboard()
    InputBindings.install_gamepad()
end

function InputBindings.discover_gamepad()
    local lines = { "=== Gamepad input discovery (press buttons now) ===" }
    local pc = get_player_controller()
    if not pc then
        return false, "No PlayerController — load a save first."
    end

    local probe = {}
    for _, group in pairs(GAMEPAD_KEY_CANDIDATES) do
        for _, name in ipairs(group) do
            probe[#probe + 1] = name
        end
    end
    table.insert(probe, "Gamepad_FaceButton_Bottom")
    table.insert(probe, "Gamepad_FaceButton_Right")
    table.insert(probe, "Gamepad_Special_Left")
    table.insert(probe, "Gamepad_Special_Right")
    table.insert(probe, "Gamepad_LeftTrigger")
    table.insert(probe, "Gamepad_RightTrigger")

    for _, name in ipairs(probe) do
        if is_key_down(pc, name) or was_key_pressed(pc, name) then
            local line = "ACTIVE: " .. name
            lines[#lines + 1] = line
            Log.info(line)
        end
    end

    lines[#lines + 1] = "=== end gamepad discovery ==="
    Log.info(lines[#lines])
    return true, table.concat(lines, " | ")
end

return InputBindings
