local Config = {}

Config.MOD_VERSION = "0.2.2-dev"
Config.LOG_PREFIX = "[OverwriteOldestSave] "

-- Manual save cap (Steam / Xbox PC reports 100 manual slots).
Config.MAX_MANUAL_SAVES = 100

-- Saved Games root; profile subfolders are scanned automatically.
Config.SAVE_ROOT = os.getenv("USERPROFILE") .. "\\Saved Games\\TheOuterWorlds2"

-- Filenames containing these (case-insensitive) are not counted as manual saves.
Config.NON_MANUAL_MARKERS = {
    "autosave",
    "quicksave",
    "quick save",
    "checkpoint",
    "autosaverecovery",
    "recovery",
}

-- Properties to probe on SaveGameManager during oow.discover_save (add names from logs).
Config.SAVE_MANAGER_PROPERTY_CANDIDATES = {
    "ManualSaveCount",
    "NumManualSaves",
    "MaxManualSaves",
    "ManualSaveSlots",
    "SaveSlots",
    "Saves",
    "SaveGames",
    "CurrentSaveSlot",
}

-- Candidate SaveGameManager method names (filled in after in-game discovery).
Config.SAVE_METHOD_CANDIDATES = {
    "SaveGame",
    "SaveManualGame",
    "SaveUserGame",
}

Config.DELETE_METHOD_CANDIDATES = {
    "DeleteGame",
    "DeleteSave",
    "DeleteManualSave",
}

-- Pause menu / confirm UI — set after FModel + Dump Lua Bindings (see docs/DISCOVERY.md).
Config.MENU_HOOKS = {
    -- Example: "/Game/UI/Pause/WBP_PauseMenu.WBP_PauseMenu_C:OnSaveGameClicked",
}

-- Dev bindings until pause menu row exists.
Config.DEV_KEY = Key.O
Config.DEV_MODIFIERS = { ModifierKey.CONTROL, ModifierKey.SHIFT }

return Config
