local Log = require("log")

local Feedback = {}

-- Ar:Log only from the console handler thread (not from ExecuteInGameThread).
function Feedback.say_in_console(Ar, message)
    Log.info(message)
    if not Ar then
        return
    end
    pcall(function()
        if type(Ar) == "userdata" and Ar.Log then
            Ar:Log("[OverwriteOldestSave] " .. message)
        end
    end)
end

return Feedback
