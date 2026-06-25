-- Read Xbox controller via Windows XInput (outside UE PlayerController).
-- UE IsInputKeyDown polling crashes WinGDK; XInput + QuickSave.run() does not.
local Config = require("config")
local Log = require("log")

local XInputGamepad = {}

local poll_active = false
local paused_until = 0
local prev_buttons = 0
local back_down_at = nil
local back_fired = false
local on_trigger = nil
local xinput = nil
local XInputGetState = nil

local BUTTON = {
    BACK = 0x0020,
    LEFT_THUMB = 0x0040,
    RIGHT_THUMB = 0x0080,
}

local prev_both_sticks = false

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

local function has_flag(buttons, flag)
    return band(buttons, flag) ~= 0
end

local function load_xinput()
    local ok_ffi, ffi = pcall(require, "ffi")
    if not ok_ffi or not ffi then
        return false, "ffi unavailable"
    end

    ffi.cdef[[
        typedef struct {
            unsigned short wButtons;
            unsigned char bLeftTrigger;
            unsigned char bRightTrigger;
            short sThumbLX;
            short sThumbLY;
            short sThumbRX;
            short sThumbRY;
        } XINPUT_GAMEPAD;
        typedef struct {
            unsigned int dwPacketNumber;
            XINPUT_GAMEPAD Gamepad;
        } XINPUT_STATE;
        unsigned int XInputGetState(unsigned int dwUserIndex, XINPUT_STATE* pState);
    ]]

    for _, name in ipairs({ "xinput1_4", "xinput1_3", "xinput9_1_0" }) do
        local ok, lib = pcall(ffi.load, name)
        if ok and lib then
            xinput = lib
            XInputGetState = lib.XInputGetState
            return true, name
        end
    end
    return false, "xinput DLL not found"
end

function XInputGamepad.pause(duration_ms)
    paused_until = os.clock() * 1000 + (duration_ms or Config.INPUT.CONSOLE_PAUSE_MS or 45000)
end

local function read_state()
    if not XInputGetState then
        return nil
    end
    local ffi = require("ffi")
    local state = ffi.new("XINPUT_STATE[1]")
    local idx = (Config.INPUT.XINPUT and Config.INPUT.XINPUT.user_index) or 0
    if XInputGetState(idx, state) ~= 0 then
        return nil
    end
    return state[0].Gamepad
end

local function check_chord(gp, cfg)
    local threshold = cfg.trigger_threshold or 40
    local lt = gp.bLeftTrigger >= threshold
    local l3 = has_flag(gp.wButtons, BUTTON.LEFT_THUMB)
    local r3 = has_flag(gp.wButtons, BUTTON.RIGHT_THUMB)
    local both = l3 and r3
    if lt and both and not prev_both_sticks then
        return true, "LT+L3+R3"
    end
    return false, nil
end

local function check_hold_back(gp, cfg)
    local hold_ms = cfg.hold_back_ms or 700
    local back_down = has_flag(gp.wButtons, BUTTON.BACK)
    if not back_down then
        back_down_at = nil
        back_fired = false
        return false, nil
    end
    if not back_down_at then
        back_down_at = os.clock() * 1000
        back_fired = false
        return false, nil
    end
    if back_fired then
        return false, nil
    end
    if (os.clock() * 1000 - back_down_at) >= hold_ms then
        back_fired = true
        return true, "hold Back"
    end
    return false, nil
end

local function poll_once()
    local gp = read_state()
    if not gp then
        prev_buttons = 0
        prev_both_sticks = false
        return
    end

    local cfg = Config.INPUT.XINPUT or {}
    local mode = cfg.mode or "chord"
    local fired, via

    if mode == "hold_back" or mode == "both" then
        fired, via = check_hold_back(gp, cfg)
    end
    if not fired and (mode == "chord" or mode == "both") then
        fired, via = check_chord(gp, cfg)
    end

    local l3 = has_flag(gp.wButtons, BUTTON.LEFT_THUMB)
    local r3 = has_flag(gp.wButtons, BUTTON.RIGHT_THUMB)
    prev_both_sticks = l3 and r3
    prev_buttons = gp.wButtons

    if fired and on_trigger then
        Log.info("XInput gamepad: " .. via)
        on_trigger()
    end
end

local function poll_loop()
    if not poll_active then
        return
    end
    if os.clock() * 1000 >= paused_until then
        pcall(poll_once)
    end
    local poll_ms = (Config.INPUT.XINPUT and Config.INPUT.XINPUT.poll_ms) or 50
    ExecuteWithDelay(poll_ms, poll_loop)
end

function XInputGamepad.start(trigger_fn)
    if poll_active then
        return true
    end
    if not XInputGetState then
        local ok, detail = load_xinput()
        if not ok then
            Log.warn("XInput gamepad unavailable: " .. tostring(detail))
            return false
        end
        Log.info("XInput loaded: " .. detail)
    end

    on_trigger = trigger_fn
    poll_active = true
    prev_buttons = 0
    prev_both_sticks = false
    back_down_at = nil
    back_fired = false

    local cfg = Config.INPUT.XINPUT or {}
    local mode = cfg.mode or "chord"
    if mode == "chord" or mode == "both" then
        Log.info("Gamepad (XInput): hold LT + click L3 and R3 = quick save")
    end
    if mode == "hold_back" or mode == "both" then
        Log.info(string.format("Gamepad (XInput): hold Back %dms = quick save", cfg.hold_back_ms or 700))
    end

    poll_loop()
    return true
end

function XInputGamepad.stop()
    poll_active = false
end

return XInputGamepad
