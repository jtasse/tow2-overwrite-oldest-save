local Config = require("config")

local Log = {}

function Log.info(msg)
    print(Config.LOG_PREFIX .. msg .. "\n")
end

function Log.warn(msg)
    print(Config.LOG_PREFIX .. "WARN: " .. msg .. "\n")
end

function Log.error(msg)
    print(Config.LOG_PREFIX .. "ERROR: " .. msg .. "\n")
end

return Log
