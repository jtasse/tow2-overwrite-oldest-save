# Working state snapshot

Validated **2026-06-05** on **LEELOO2** (Game Pass, remote desktop). Use this as the reference profile when debugging other PCs.

## Result

| Check | Status |
|-------|--------|
| Vanilla game (UE4SS off) | OK after Xbox **Verify and repair** |
| UE4SS only (`OverwriteOldestSave : 0`) | OK |
| UE4SS + mod | OK — `QUICK SAVE OK` at 100/100 cap |
| Quick save flow | `DeleteGame` oldest → `Quicksave` confirmed in log |

## Machine profile (LEELOO2)

```
Computer:     LEELOO2
Game version: 1.256.9237.0 (winget / MSIX)
WinGDK:       C:\XboxGames\The Outer Worlds 2\Content\Arkansas\Binaries\WinGDK
Branch:       develop @ 8509bce
Mod:          0.6.2-dev
```

| File | Size / hash | Notes |
|------|-------------|--------|
| `dwmapi.dll` | 61952 B, SHA256 prefix `312B76CE6BFC042A` | UE4SS injector |
| `UE4SS.dll` | 16377856 B, prefix `12592A086DBE5BCF` | experimental-latest |
| `UE4SS-settings.ini` | **6852** bytes | From `zCustomGameConfigs.zip` (not main-branch 6658) |
| `VTableLayout.ini` | **18293** bytes | Same zip |
| `override.txt` | **missing** | Do not create |
| `TheOuterWorlds2-WinGDK-Shipping.exe` | 171236864 B | **Official** after repair — do not hand-copy from another PC |

### UE4SS-settings (required)

```
bUseUObjectArrayCache = false
MajorVersion = 5
MinorVersion = 4
HookProcessLocalScriptFunction = 1
ConsoleEnabled = 0
GuiConsoleEnabled = 0
```

### mods.txt

Only `OverwriteOldestSave : 1`. All stock UE4SS mods `0`. No `enabled.txt` in the mod folder.

## Mod config on this PC

| Setting | Value | Why |
|---------|-------|-----|
| `GAMEPAD_ENABLED` | `false` | Gamepad poll froze WinGDK on startup; keyboard works |
| Input bindings | Deferred until `SaveGameManager` ready | Early `EngineTick` / poll crashed at launch |
| `AUTO_INJECT` | `false` | Pause-menu inject unstable |

**Controls that work:** **Ctrl+Shift+O**, console **`oow.save`** (needs Console Enabler `.pak` for `~`).

## Local mod files (host)

| Path | Purpose |
|------|---------|
| `%LOCALAPPDATA%\OverwriteOldestSave-save-cache.json` | 107 saves at validation |
| `%LOCALAPPDATA%\OverwriteOldestSave-mod-active.txt` | Last: `QUICK SAVE OK` |
| `%LOCALAPPDATA%\OverwriteOldestSave-mod-log.txt` | Event history |

## Scripts used to reach this state

```powershell
# After Xbox repair (exe tamper recovery):
.\scripts\tow2-ue4ss.ps1 -Action disable-ue4ss   # vanilla test
.\scripts\align-with-working.ps1                 # config + deploy + enable

# Ongoing:
.\scripts\enable-mod.ps1        # redeploy / refresh
.\scripts\mod-status.ps1      # verify without seeing the game
.\scripts\diagnose-ue4ss.ps1    # UE4SS + log tail
.\scripts\export-machine-profile.ps1   # diff two PCs
```

## What failed (do not repeat)

1. **Copying `TheOuterWorlds2-WinGDK-Shipping.exe`** from another PC → Xbox error *"Something went wrong launching your game"*. Fix: **Verify and repair** in Xbox app only.
2. **`main` branch / 6658-byte `UE4SS-settings.ini`** → mod or UE4SS never loaded correctly.
3. **`override.txt`** pointing at `UE4SS.dll` → remove it (working PCs omit it).
4. **Early keyboard/gamepad hooks at mod load** → crash or black-screen hang; fixed by deferring to in-game activation.

## Compare another PC

On each machine:

```powershell
.\scripts\export-machine-profile.ps1
```

Diff the two `tow2-machine-profile.txt` files. Match: WinGDK path, DLL hashes, ini **byte sizes**, `mods.txt`, no `override.txt`, mod version `0.6.2-dev`.

## Log lines that mean success

```
[OverwriteOldestSave] loaded v0.6.2-dev
[OverwriteOldestSave] SaveGameManager ready
[OverwriteOldestSave] STARTUP: Mod ACTIVE
[OverwriteOldestSave] DeleteGame OK for <GUID>    # at 100/100
[OverwriteOldestSave] SUCCESS: Quick save done (Quicksave).
```

Marker file headline: **`QUICK SAVE OK`** or **`MOD LOADED OK`**.
