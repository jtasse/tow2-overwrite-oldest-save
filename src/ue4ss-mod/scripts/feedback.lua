local Config = require("config")
local Log = require("log")
local OnScreen = require("on_screen")

local Feedback = {}

Feedback._history = {}
Feedback._history_max = 12
Feedback._session_id = os.date("%Y-%m-%d %H:%M:%S")

local MARKER = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-mod-active.txt"
local EVENT_LOG = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-mod-log.txt"
local CONSOLE_OUT = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-last-console.txt"
local PENDING_ORPHAN = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-pending-orphan.txt"

local function push_history(message)
    Feedback._history[#Feedback._history + 1] = {
        t = os.time(),
        msg = message,
    }
    while #Feedback._history > Feedback._history_max do
        table.remove(Feedback._history, 1)
    end
end

local function append_event(kind, message)
    if not EVENT_LOG or EVENT_LOG == "\\OverwriteOldestSave-mod-log.txt" then
        return
    end
    local file = io.open(EVENT_LOG, "a")
    if not file then
        return
    end
    file:write(string.format("[%s] [%s] %s\n", os.date("%H:%M:%S"), kind, tostring(message)))
    file:close()
end

local function write_marker(headline, detail)
    if not MARKER or MARKER == "\\OverwriteOldestSave-mod-active.txt" then
        return
    end
    local file = io.open(MARKER, "w")
    if not file then
        return
    end
    file:write("session=", Feedback._session_id, "\n")
    file:write("version=", Config.MOD_VERSION, "\n")
    file:write("updated=", os.date("%Y-%m-%d %H:%M:%S"), "\n")
    file:write("headline=", tostring(headline), "\n")
    if detail and detail ~= "" then
        file:write("detail=", tostring(detail), "\n")
    end
    file:close()
end

local function write_console_out(message)
    if not CONSOLE_OUT then
        return
    end
    local file = io.open(CONSOLE_OUT, "w")
    if not file then
        return
    end
    file:write("time=", os.date("%Y-%m-%d %H:%M:%S"), "\n")
    file:write("message=", tostring(message), "\n")
    file:close()
end

function Feedback.get_history()
    return Feedback._history
end

function Feedback.get_session_id()
    return Feedback._session_id
end

function Feedback.format_history()
    if #Feedback._history == 0 then
        return "No status yet. Try: oow.help"
    end
    local lines = {}
    for i, entry in ipairs(Feedback._history) do
        lines[#lines + 1] = string.format("%d) %s", i, entry.msg)
    end
    return table.concat(lines, "\n")
end

function Feedback.emit_to_console(message)
    if message and message ~= "" then
        Log.info(message)
    end
end

function Feedback.say_in_console(Ar, message)
    if not message or message == "" then
        return
    end

    local line = "[OOW] " .. tostring(message)
    Log.info(line)
    push_history(message)
    append_event("console", message)
    write_console_out(message)
    write_marker("CONSOLE", message)
    if Config.USE_ON_SCREEN_FEEDBACK then
        OnScreen.show(message, 12.0)
    end

    if Ar then
        local logged = false
        pcall(function()
            if Ar.Log then
                Ar:Log(line)
                logged = true
            end
        end)
        if not logged then
            pcall(function()
                if Ar.Log then
                    Ar.Log(Ar, line)
                end
            end)
        end
    end
end

function Feedback.show_game_toast(message)
    if not message or message == "" then
        return
    end
    push_history(message)
    Log.info("[status] " .. message)
    append_event("status", message)
    write_marker(message, "See mod-log or oow.status")
    if Config.USE_ON_SCREEN_FEEDBACK then
        OnScreen.show(message, 8.0)
    end
end

function Feedback.show_toast(message)
    Feedback.show_game_toast(message)
end

function Feedback.show_startup_banner()
    local msg = string.format(
        "Mod ACTIVE v%s - Ctrl+Shift+O | LT+L3+R3 (gamepad bridge on host)",
        Config.MOD_VERSION
    )
    Log.info("========================================")
    Log.info("STARTUP session=" .. Feedback._session_id)
    Log.info("STARTUP: " .. msg)
    Log.info("========================================")
    push_history(msg)
    append_event("STARTUP", msg)
    write_marker("MOD LOADED OK", msg)
end

function Feedback.write_result(headline, detail)
    write_marker(headline, detail)
    push_history(detail)
    append_event("result", detail)
    write_console_out(detail)
end

function Feedback.mark_pending_orphan(guid)
    if not guid or guid == "" or not PENDING_ORPHAN then
        return
    end
    ExecuteWithDelay(0, function()
        local file = io.open(PENDING_ORPHAN, "w")
        if not file then
            return
        end
        file:write("guid=", string.upper(tostring(guid)), "\n")
        file:write("marked=", os.date("%Y-%m-%d %H:%M:%S"), "\n")
        file:write("action=Run scripts\\refresh-save-cache.ps1 after playing (outside game)\n")
        file:close()
        Log.info("Pending orphan marked: " .. guid)
    end)
end

return Feedback
