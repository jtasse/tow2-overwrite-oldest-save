local Config = {}

Config.MOD_VERSION = "0.7.6-dev"

-- Below cap: UFunction SaveGame (manual slot). Fallback: UFunction Quicksave (quicksave slot only).
Config.USE_MANUAL_SAVE_ONLY = true
Config.CAP_SAVE_USE_QUICKSAVE = true
Config.ALLOW_QUICKSAVE_FALLBACK = true

Config.PREFER_UFUNCTION_CALLS = true
-- Console SaveGame returns true but does not save on TOW2; keep off for save paths (delete still has fallback).
Config.ALLOW_MGR_CONSOLE_EXEC = false
Config.ALLOW_PLAYER_CONTROLLER_CONSOLE = true

-- PrintString on-screen feedback crashed TOW2 right after DeleteGame; use log + marker files.
Config.USE_ON_SCREEN_FEEDBACK = false

-- Delay (ms) after DeleteGame before SaveGame at cap.
Config.POST_DELETE_DELAY_MS = 400

-- Keyboard + gamepad quick save bindings (Key.* resolved at install, not here).
Config.INPUT = {
    KEYBOARD = {
        key_name = "O",
        modifier_names = { "CONTROL", "SHIFT" },
    },
    HOTKEYS_ENABLED = true,
    KEYBOARD_ENABLED = true,
    -- Auto-arm Ctrl+Shift+O ~8s after loading a save (ClientRestart + pawn check).
    AUTO_ARM_BINDINGS = true,
    CLIENT_RESTART_DELAY_MS = 8000,
    ARM_DELAY_MS = 1500,
    -- Also arm after oow.s if auto-arm has not run yet.
    AUTO_ARM_ON_SAVE = true,
    ARM_DELAY_AFTER_SAVE_MS = 2500,
    GAMEPAD_ENABLED = true,
    -- XInput reads the controller outside UE (safe on WinGDK). UE "poll" crashes.
    AUTO_ARM_GAMEPAD_ON_LOAD = true,
    AUTO_ARM_GAMEPAD_ON_SAVE = false,
    CONSOLE_PAUSE_MS = 45000,
    GAMEPAD_ARM_DELAY_MS = 2000,
    -- bridge = host PowerShell XInput file (WinGDK) | xinput = needs LuaJIT ffi (unavailable)
    GAMEPAD_METHOD = "bridge",
    BRIDGE = {
        poll_ms = 50,
    },
    XINPUT = {
        mode = "chord",
        trigger_threshold = 30,
        user_index = 0,
        poll_ms = 50,
    },
    GAMEPAD_POLL_MS = 300,
    GAMEPAD_POLL_DELAY_MS = 1000,
    GAMEPAD = {
        hold1 = { "Gamepad_LeftTrigger" },
        hold2 = { "Gamepad_LeftThumbstick", "Gamepad_LeftThumb", "LeftThumb" },
        action = { "Gamepad_RightThumbstick", "Gamepad_RightThumb", "RightThumb" },
    },
}

-- In-game subprocess I/O freezes TOW2 pause menu (cmd/powershell/wscript). Use external cache file only.
Config.SAVE_CACHE_FILE = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-save-cache.json"
Config.LOG_PREFIX = "[OverwriteOldestSave] "

-- Manual save cap (Steam / Xbox PC reports 100 manual slots).
Config.MAX_MANUAL_SAVES = 100

-- When engine save count is unreadable, set true if pause menu shows 100/100 (see oow.set_cap).
Config.AT_CAP_OVERRIDE = false

-- Host marker written by oow.set_cap or scripts\set-cap-marker.ps1
Config.CAP_MARKER_FILE = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-at-cap.json"

-- Tracked x/100 when engine count is unreadable (pause UI scrape + successful mod saves).
Config.SAVE_COUNT_FILE = (os.getenv("LOCALAPPDATA") or "") .. "\\OverwriteOldestSave-save-count.json"

-- Manual only (oow.sync_count). Auto poll/NotifyOnNewObject freezes TOW2 Save Game menu.
Config.PAUSE_UI_SYNC_ENABLED = true
Config.PAUSE_UI_SYNC_AUTO = false
Config.PAUSE_UI_SYNC_INTERVAL_MS = 2000

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
    "NumSaveGames",
    "SaveGameCount",
    "CurrentManualSaveCount",
    "MaxManualSaves",
    "ManualSaveSlots",
    "SaveSlots",
    "Saves",
    "SaveGames",
    "CurrentSaveSlot",
}

-- Bool properties: if true, treat as at cap (100/100).
Config.SAVE_MANAGER_CAP_BOOL_CANDIDATES = {
    "bAtManualSaveCap",
    "bIsAtSaveCap",
    "bSaveListFull",
    "bManualSaveCapReached",
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
