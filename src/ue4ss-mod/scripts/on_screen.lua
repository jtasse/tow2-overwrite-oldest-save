local Log = require("log")

local OnScreen = {}

local function find_print_library()
    local paths = {
        "/Script/Engine.Default__KismetSystemLibrary",
        "/Script/Engine.KismetSystemLibrary",
    }
    for _, path in ipairs(paths) do
        local ok, obj = pcall(function()
            return StaticFindObject(path)
        end)
        if ok and obj then
            return obj
        end
    end
    return nil
end

function OnScreen.show(message, duration_sec)
    if not message or message == "" then
        return
    end
    local text = "[OOW] " .. tostring(message)
    local duration = duration_sec or 10.0

    ExecuteInGameThread(function()
        local lib = find_print_library()
        if not lib then
            Log.warn("on_screen: KismetSystemLibrary not found")
            return
        end

        local world = nil
        pcall(function()
            local pc = FindFirstOf("PlayerController")
            if pc and pc:IsValid() then
                world = pc:GetWorld()
            end
        end)

        pcall(function()
            if lib.PrintString then
                lib:PrintString(world, text, true, false, { R = 0.1, G = 1.0, B = 0.3, A = 1.0 }, duration)
            end
        end)
    end)
end

return OnScreen
