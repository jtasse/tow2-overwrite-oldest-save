local Config = require("config")
local Log = require("log")
local Overwrite = require("overwrite")

local Menu = {}

--- Pause menu row + confirmation widget — requires BP paths from FModel.
--- Fill Config.MENU_HOOKS after discovery, then register here.
function Menu.install_hooks()
    for _, path in ipairs(Config.MENU_HOOKS) do
        if path and path ~= "" then
            local ok, err = pcall(function()
                RegisterHook(path, function(self)
                    Log.info("Menu hook fired: " .. path)
                    ExecuteInGameThread(function()
                        Overwrite.run_with_confirm()
                    end)
                end)
            end)
            if ok then
                Log.info("Registered menu hook: " .. path)
            else
                Log.warn("Failed menu hook " .. path .. ": " .. tostring(err))
            end
        end
    end

    if #Config.MENU_HOOKS == 0 then
        Log.info("No pause menu hooks configured yet (see docs/DISCOVERY.md)")
    end
end

return Menu
