local Config = {}

Config.MOD_VERSION = "0.6.2-dev"

-- PrintString on-screen feedback crashed TOW2 right after DeleteGame; use log + marker files.
Config.USE_ON_SCREEN_FEEDBACK = false

-- Delay (ms) after DeleteGame before Quicksave.
Config.POST_DELETE_DELAY_MS = 1500

-- Keyboard + gamepad quick save bindings.
Config.INPUT = {
    KEYBOARD = {
        key = Key.O,
        modifiers = { ModifierKey.CONTROL, ModifierKey.SHIFT },
    },
    GAMEPAD_ENABLED = true,
    GAMEPAD_POLL_MS = 50,
    -- Xbox: hold LB + RB, tap A (face button bottom).
    GAMEPAD = {
        left = { "Gamepad_LeftShoulder" },
        right = { "Gamepad_RightShoulder" },
        action = {
            "Gamepad_FaceButton_Bottom",
            "Gamepad_FaceButton_A",
            "FaceButton_Bottom",
        },
    },
}

-- In-game subprocess I/O freezes TOW2 pause menu (cmd/powershell/wscript). Use external cache file only.
Config.SAVE_CACHE_FILE = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-save-cache.json"
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

-- Pause menu row — TOW2 uses SaveLoadMenu_BP (/Game/UI/Menus/SaveLoadMenu/...).
Config.MENU = {
    ROW_LABEL = "Quick save (overwrite oldest if full)",
    CONFIRM_LABEL = "Confirm overwrite oldest save?",
    BUTTON_NAME = "OOW_OverwriteOldestSaveBtn",

    -- Global UI hooks + auto-inject crashed Load Game on TOW2. Keep false; use oow.inject_menu.
    AUTO_INJECT = false,

    SAVE_LOAD_MENU_CLASS = "/Game/UI/Menus/SaveLoadMenu/SaveLoadMenu_BP.SaveLoadMenu_BP_C",
    SAVE_LOAD_MENU_MARKER = "SaveLoadMenu_BP",

    -- Clone one of these InputWidget rows inside SaveLoadMenu (discovered via oow.discover_ui).
    INJECTION_WIDGET_NAMES = {
        "InputWidget_BP_1",
        "InputWidget_BP",
    },

    INJECTION_PANEL_NAMES = {
        "Overlay_0",
        "VerticalBox_0",
        "ButtonBox",
        "MenuButtonBox",
    },

    INPUT_WIDGET_CLASS_PATHS = {
        "/Game/UI/Menus/SaveLoadMenu/InputWidget_BP.InputWidget_BP_C",
        "/Game/UI/Menus/InputWidget_BP.InputWidget_BP_C",
    },

    POLL_INTERVAL_MS = 400,
    POLL_MAX_TICKS = 60,

    WIDGET_CLASSES = {
        "CommonButtonBase",
        "Button",
        "UserWidget",
    },

    ANCHOR_EXCLUDE_PATTERNS = {
        "SaveGameManager",
        "Autosave",
        "Quicksave",
        "LoadGame",
        "Blocker",
        "SaveGameBlocker",
        "Background",
        "InputLabelGroup",
        "OOW_",
    },

    REFRESH_ON_VISIBILITY_PATTERNS = {
        "SaveLoadMenu_BP",
        "InputWidget_BP",
    },

    POLL_DELAYS_MS = { 50, 150, 350, 750, 1500 },
}

-- Optional BP hooks — only work if ProcessLocalScriptFunction is available (not on stock TOW2 UE4SS 3.0.1).
Config.MENU_HOOKS = {
    -- Example: "/Game/UI/Pause/WBP_PauseMenu.WBP_PauseMenu_C:OnSaveGameClicked",
}

return Config
