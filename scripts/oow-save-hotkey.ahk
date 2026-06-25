#Requires AutoHotkey v2.0
; External hotkey for TOW2 WinGDK — in-mod keyboard/gamepad hooks crash the game.
; Ctrl+Shift+O opens the UE console, runs oow.s, closes console.
; Run: .\scripts\start-hotkey-binder.ps1  (or double-click this file if AHK v2 is installed)

#SingleInstance Force
SendMode "Input"

GAME_EXE := "TheOuterWorlds2-WinGDK-Shipping.exe"
CONSOLE_KEY := "``"   ; backtick / tilde key (Console Enabler default)
COMMAND := "oow.s"
DEBOUNCE_MS := 1200

lastFire := 0

RunOowSave(*) {
    global lastFire, DEBOUNCE_MS, CONSOLE_KEY, COMMAND
    if (A_TickCount - lastFire < DEBOUNCE_MS) {
        return
    }
    lastFire := A_TickCount

    Send CONSOLE_KEY
    Sleep 200
    SendText COMMAND
    Sleep 50
    Send "{Enter}"
    Sleep 250
    Send CONSOLE_KEY
}

#HotIf WinActive("ahk_exe " GAME_EXE)
^+o:: RunOowSave()
#HotIf

TraySetToolTip "TOW2 oow.s — Ctrl+Shift+O (game window only)"
