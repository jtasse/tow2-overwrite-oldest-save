local Config = require("config")
local Log = require("log")
local QuickSave = require("quick_save")
local XInputGamepad = nil
local GamepadBridge = nil

local function get_xinput()
    if not XInputGamepad then
        XInputGamepad = require("xinput_gamepad")
    end
    return XInputGamepad
end

local function get_bridge()
    if not GamepadBridge then
        GamepadBridge = require("gamepad_bridge")
    end
    return GamepadBridge
end

local InputBindings = {}

local last_trigger_at = 0
local DEBOUNCE_MS = 800
local bindings_started = false
local arm_scheduled = false
local gamepad_poll_active = false
local gamepad_poll_paused_until = 0

local GAMEPAD_KEY_CANDIDATES = {
    hold1 = { "Gamepad_LeftTrigger", "LeftTrigger" },
    hold2 = { "Gamepad_LeftThumbstick", "Gamepad_LeftThumb", "LeftThumb" },
    action = { "Gamepad_RightThumbstick", "Gamepad_RightThumb", "RightThumb" },
}

local resolved_keys = { hold1 = nil, hold2 = nil, action = nil }

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

local function resolve_ue_key(name)
    if Key and Key[name] then
        return Key[name]
    end
    return make_key(name)
end

local function resolve_keyboard_binding()
    local kb = Config.INPUT.KEYBOARD
    if kb.key and kb.modifiers then
        return kb.key, kb.modifiers
    end
    if not Key or not ModifierKey then
        return nil, nil
    end
    local key = Key[kb.key_name or "O"]
    local mods = {}
    for _, mod_name in ipairs(kb.modifier_names or {}) do
        if ModifierKey[mod_name] then
            mods[#mods + 1] = ModifierKey[mod_name]
        end
    end
    if not key or #mods == 0 then
        return nil, nil
    end
    return key, mods
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

function InputBindings.pause_gamepad_poll(duration_ms)
    gamepad_poll_paused_until = os.clock() * 1000 + (duration_ms or Config.INPUT.CONSOLE_PAUSE_MS or 45000)
    if XInputGamepad and XInputGamepad.pause then
        XInputGamepad.pause(duration_ms)
    end
    if GamepadBridge and GamepadBridge.pause then
        GamepadBridge.pause(duration_ms)
    end
end

local function install_gamepad_bridge()
    if not Config.INPUT.GAMEPAD_ENABLED or Config.INPUT.GAMEPAD_METHOD ~= "bridge" then
        return false
    end
    local ok, mod_or_err = pcall(get_bridge)
    if not ok then
        Log.warn("Gamepad bridge module failed: " .. tostring(mod_or_err))
        return false
    end
    return mod_or_err.start(function()
        InputBindings.trigger_quick_save()
    end)
end

local function install_gamepad_xinput()
    if not Config.INPUT.GAMEPAD_ENABLED or Config.INPUT.GAMEPAD_METHOD ~= "xinput" then
        return false
    end
    local ok, mod_or_err = pcall(get_xinput)
    if not ok then
        Log.warn("XInput module failed: " .. tostring(mod_or_err))
        return false
    end
    return mod_or_err.start(function()
        InputBindings.trigger_quick_save()
    end)
end

local function install_console_pause_binds()
    if not Key then
        return
    end
    for _, name in ipairs({ "Tilde", "Backslash", "Quote" }) do
        local key = Key[name]
        if key then
            pcall(function()
                RegisterKeyBind(key, {}, function()
                    InputBindings.pause_gamepad_poll()
                    Log.info("Gamepad poll paused (~ console)")
                end)
            end)
        end
    end
end

local function install_keyboard_register()
    if not Config.INPUT.KEYBOARD_ENABLED then
        return false
    end
    local key, mods = resolve_keyboard_binding()
    if not key then
        Log.warn("Keyboard bind skipped (Key API unavailable) — use oow.s")
        return false
    end
    local ok, err = pcall(function()
        RegisterKeyBind(key, mods, function()
            Log.info("Keyboard: Ctrl+Shift+O")
            InputBindings.trigger_quick_save()
        end)
    end)
    if ok then
        Log.info("Keyboard: Ctrl+Shift+O = quick save (RegisterKeyBind)")
        install_console_pause_binds()
        return true
    end
    Log.warn("RegisterKeyBind keyboard failed: " .. tostring(err))
    return false
end

local function install_gamepad_register()
    if not Config.INPUT.GAMEPAD_ENABLED then
        return false
    end
    if Config.INPUT.GAMEPAD_METHOD ~= "register" then
        return false
    end

    local candidates = {}
    if Config.INPUT.GAMEPAD_REGISTER_KEY then
        candidates[#candidates + 1] = Config.INPUT.GAMEPAD_REGISTER_KEY
    end
    for _, name in ipairs(Config.INPUT.GAMEPAD_REGISTER_FALLBACK_KEYS or {}) do
        candidates[#candidates + 1] = name
    end

    for _, name in ipairs(candidates) do
        local key = resolve_ue_key(name)
        if key then
            local bound = false
            local ok, err = pcall(function()
                RegisterKeyBind(key, {}, function()
                    Log.info("Gamepad: " .. name)
                    InputBindings.trigger_quick_save()
                end)
                bound = true
            end)
            if ok and bound then
                Log.info("Gamepad: " .. name .. " = quick save (RegisterKeyBind)")
                return true
            end
            Log.warn("RegisterKeyBind gamepad " .. name .. " failed: " .. tostring(err))
        end
    end
    return false
end

local function resolve_gamepad_keys(pc)
    if resolved_keys.hold1 and resolved_keys.hold2 and resolved_keys.action then
        return true
    end
    for _, name in ipairs(GAMEPAD_KEY_CANDIDATES.hold1) do
        if is_key_down(pc, name) or was_key_pressed(pc, name) then
            resolved_keys.hold1 = name
            break
        end
    end
    for _, name in ipairs(GAMEPAD_KEY_CANDIDATES.hold2) do
        if is_key_down(pc, name) or was_key_pressed(pc, name) then
            resolved_keys.hold2 = name
            break
        end
    end
    for _, name in ipairs(GAMEPAD_KEY_CANDIDATES.action) do
        if is_key_down(pc, name) or was_key_pressed(pc, name) then
            resolved_keys.action = name
            break
        end
    end
    local gp = Config.INPUT.GAMEPAD
    if not resolved_keys.hold1 then
        resolved_keys.hold1 = gp.hold1[1]
    end
    if not resolved_keys.hold2 then
        resolved_keys.hold2 = gp.hold2[1]
    end
    if not resolved_keys.action then
        resolved_keys.action = gp.action[1]
    end
    return true
end

local function check_gamepad_combo()
    local pc = get_player_controller()
    if not pc then
        return
    end
    resolve_gamepad_keys(pc)
    local h1, h2, act = resolved_keys.hold1, resolved_keys.hold2, resolved_keys.action
    if not (h1 and h2 and act) then
        return
    end
    if not is_key_down(pc, h1) then
        return
    end
    if is_key_down(pc, h2) and is_key_down(pc, act) then
        if not InputBindings._prev_stick_chord then
            Log.info("Gamepad combo: LT + L3 + R3")
            InputBindings.trigger_quick_save()
        end
        InputBindings._prev_stick_chord = true
        return
    end
    InputBindings._prev_stick_chord = false
end

local function poll_gamepad_loop()
    if not gamepad_poll_active then
        return
    end
    if os.clock() * 1000 < gamepad_poll_paused_until then
        ExecuteWithDelay(250, poll_gamepad_loop)
        return
    end
    ExecuteInGameThread(function()
        pcall(check_gamepad_combo)
    end)
    ExecuteWithDelay(Config.INPUT.GAMEPAD_POLL_MS, poll_gamepad_loop)
end

local function install_gamepad_poll()
    if not Config.INPUT.GAMEPAD_ENABLED or Config.INPUT.GAMEPAD_METHOD ~= "poll" then
        return false
    end
    local gp = Config.INPUT.GAMEPAD
    resolved_keys.hold1 = gp.hold1[1]
    resolved_keys.hold2 = gp.hold2[1]
    resolved_keys.action = gp.action[1]
    gamepad_poll_active = true
    ExecuteWithDelay(Config.INPUT.GAMEPAD_POLL_DELAY_MS or 3000, function()
        poll_gamepad_loop()
        Log.info(string.format(
            "Gamepad poll: hold %s + click %s + %s (LT+L3+R3)",
            resolved_keys.hold1, resolved_keys.hold2, resolved_keys.action
        ))
    end)
    return true
end

function InputBindings.start_keyboard()
    if InputBindings._keyboard_started then
        return false
    end
    InputBindings._keyboard_started = install_keyboard_register()
    return InputBindings._keyboard_started
end

function InputBindings.start_gamepad()
    if InputBindings._gamepad_started then
        return false
    end
    if Config.INPUT.GAMEPAD_METHOD == "bridge" then
        InputBindings._gamepad_started = install_gamepad_bridge()
        if not InputBindings._gamepad_started then
            InputBindings._gamepad_started = install_gamepad_xinput()
        end
        return InputBindings._gamepad_started
    end
    if Config.INPUT.GAMEPAD_METHOD == "xinput" then
        InputBindings._gamepad_started = install_gamepad_xinput()
        return InputBindings._gamepad_started
    end
    if Config.INPUT.GAMEPAD_METHOD == "external" then
        Log.info("Gamepad: use external remap LT+L3+R3 -> Ctrl+Shift+O (in-mod poll crashes WinGDK)")
        InputBindings._gamepad_started = true
        return true
    end
    if Config.INPUT.GAMEPAD_METHOD == "poll" then
        InputBindings._gamepad_started = install_gamepad_poll()
        return InputBindings._gamepad_started
    end
    InputBindings._gamepad_started = install_gamepad_register()
    return InputBindings._gamepad_started
end

function InputBindings.start_after_load(opts)
    opts = opts or {}
    local want_keyboard = opts.keyboard ~= false
    local want_gamepad = opts.gamepad == true

    if want_keyboard then
        InputBindings.start_keyboard()
    end
    if want_gamepad and Config.INPUT.GAMEPAD_ENABLED then
        local delay_ms = opts.gamepad_delay_ms or Config.INPUT.GAMEPAD_ARM_DELAY_MS or 3000
        ExecuteWithDelay(delay_ms, function()
            if Config.INPUT.GAMEPAD_METHOD == "bridge" or Config.INPUT.GAMEPAD_METHOD == "xinput" then
                pcall(function()
                    InputBindings.start_gamepad()
                end)
            else
                ExecuteInGameThread(function()
                    pcall(function()
                        InputBindings.start_gamepad()
                    end)
                end)
            end
        end)
    end

    if want_keyboard or want_gamepad then
        bindings_started = true
    end
end

function InputBindings.schedule_arm(opts)
    if bindings_started then
        return true, "Hotkeys already active."
    end
    if arm_scheduled then
        return true, "Hotkeys already scheduled."
    end
    if not Config.INPUT.HOTKEYS_ENABLED then
        return false, "Hotkeys disabled in config."
    end

    arm_scheduled = true
    local via = (opts and opts.via) or "scheduled"
    local delay_ms = (opts and opts.delay_ms) or Config.INPUT.ARM_DELAY_MS or 2500
    Log.info(string.format("Hotkeys scheduled in %.1fs (%s) — close console", delay_ms / 1000, via))

    ExecuteWithDelay(delay_ms, function()
        ExecuteInGameThread(function()
            local ok, err = pcall(function()
                local arm_opts = opts.arm or { keyboard = true, gamepad = false }
                InputBindings.start_after_load(arm_opts)
            end)
            if ok then
                Log.info("Hotkeys active (" .. via .. ")")
            else
                arm_scheduled = false
                bindings_started = false
                Log.warn("Hotkey install failed: " .. tostring(err))
            end
        end)
    end)

    return true, string.format("Hotkeys in ~%.0fs. Close console first.", delay_ms / 1000)
end

function InputBindings.schedule_arm_after_save()
    if not Config.INPUT.AUTO_ARM_ON_SAVE or bindings_started then
        return
    end
    InputBindings.schedule_arm({
        via = "after_save",
        delay_ms = Config.INPUT.ARM_DELAY_AFTER_SAVE_MS,
        arm = { keyboard = true, gamepad = false },
    })
end

function InputBindings.arm_gamepad_after_console()
    if InputBindings._gamepad_started then
        return true, "Gamepad already armed (XInput)."
    end
    InputBindings.pause_gamepad_poll(2000)
    ExecuteWithDelay(2000, function()
        pcall(function()
            InputBindings.start_after_load({ keyboard = false, gamepad = true })
        end)
    end)
    return true, "Close console. Gamepad (LT+L3+R3 / hold Back) in ~2s."
end

function InputBindings.discover_gamepad()
    local cfg = Config.INPUT.XINPUT or {}
    local lines = {
        "Gamepad via XInput (same quick save as Ctrl+Shift+O)",
        "mode=" .. tostring(cfg.mode or "chord"),
        "LT+L3+R3 chord; hold Back " .. tostring(cfg.hold_back_ms or 700) .. "ms",
    }
    for _, line in ipairs(lines) do
        Log.info(line)
    end
    return true, table.concat(lines, " | ")
end

return InputBindings
