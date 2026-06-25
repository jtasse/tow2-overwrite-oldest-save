-- Read XInput state from host bridge file (scripts/start-gamepad-bridge.ps1).
local Config = require("config")
local Log = require("log")

local GamepadBridge = {}

local poll_active = false
local paused_until = 0
local prev_both_sticks = false
local on_trigger = nil
local bridge_retry_count = 0
local MAX_BRIDGE_RETRIES = 72

local BRIDGE_FILE = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-gamepad.json"

-- XInput: LEFT_THUMB = L3, RIGHT_THUMB = R3
local BUTTON_LEFT_THUMB = 0x0040
local BUTTON_RIGHT_THUMB = 0x0080

local function band(a, b)
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
        if (a % 2 == 1) and (b % 2 == 1) then
            result = result + bitval
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitval = bitval * 2
    end
    return result
end

local function parse_json_number(text, key)
    local pattern = '"' .. key .. '"%s*:%s*(%-?%d+)'
    local val = text:match(pattern)
    if val then
        return tonumber(val)
    end
    return nil
end

local function parse_json_bool(text, key)
    if text:find('"' .. key .. '"%s*:%s*true') then
        return true
    end
    if text:find('"' .. key .. '"%s*:%s*false') then
        return false
    end
    return nil
end

local function read_state()
    local file = io.open(BRIDGE_FILE, "r")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    if not text or text == "" then
        return nil
    end

    local connected = parse_json_bool(text, "connected")
    if connected == false then
        return nil
    end

    return {
        buttons = parse_json_number(text, "buttons") or 0,
        lt = parse_json_number(text, "lt") or 0,
    }
end

function GamepadBridge.pause(duration_ms)
    paused_until = os.clock() * 1000 + (duration_ms or Config.INPUT.CONSOLE_PAUSE_MS or 45000)
end

local function chord_label()
    return "LT+L3+R3"
end

local function check_chord(state, cfg)
    local threshold = cfg.trigger_threshold or 30
    local lt = state.lt >= threshold
    local l3 = band(state.buttons, BUTTON_LEFT_THUMB) ~= 0
    local r3 = band(state.buttons, BUTTON_RIGHT_THUMB) ~= 0
    local both = l3 and r3
    if lt and both and not prev_both_sticks then
        return true
    end
    return false
end

local function poll_once()
    local state = read_state()
    if not state then
        prev_both_sticks = false
        return
    end

    local cfg = Config.INPUT.XINPUT or {}
    local l3 = band(state.buttons, BUTTON_LEFT_THUMB) ~= 0
    local r3 = band(state.buttons, BUTTON_RIGHT_THUMB) ~= 0
    local both = l3 and r3

    if check_chord(state, cfg) and on_trigger then
        Log.info("Gamepad bridge: " .. chord_label())
        on_trigger()
    end

    prev_both_sticks = both
end

local function poll_loop()
    if not poll_active then
        return
    end
    if os.clock() * 1000 >= paused_until then
        pcall(poll_once)
    end
    local poll_ms = (Config.INPUT.BRIDGE and Config.INPUT.BRIDGE.poll_ms) or 50
    ExecuteWithDelay(poll_ms, poll_loop)
end

local function schedule_bridge_retry(trigger_fn)
    if bridge_retry_count >= MAX_BRIDGE_RETRIES then
        return
    end
    bridge_retry_count = bridge_retry_count + 1
    ExecuteWithDelay(5000, function()
        if not poll_active then
            GamepadBridge.start(trigger_fn)
        end
    end)
end

function GamepadBridge.start(trigger_fn)
    if poll_active then
        return true
    end

    on_trigger = trigger_fn
    if not read_state() then
        if bridge_retry_count == 0 then
            Log.warn("Gamepad bridge file missing — enable-mod installs autostart; or run scripts\\start-gamepad-bridge.ps1 (retries every 5s)")
        end
        schedule_bridge_retry(trigger_fn)
        return false
    end

    bridge_retry_count = 0
    poll_active = true
    prev_both_sticks = false
    Log.info("Gamepad bridge: hold LT + click L3 and R3 = quick save")
    poll_loop()
    return true
end

function GamepadBridge.stop()
    poll_active = false
end

return GamepadBridge
