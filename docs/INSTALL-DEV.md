# Dev setup (short reference)

Full instructions: **[../README.md](../README.md)**

## Quick commands

```powershell
.\scripts\enable-mod.ps1          # cache + deploy + enable (usual)
.\scripts\refresh-save-cache.ps1 # after playing / before testing at 100/100
.\scripts\deploy.ps1
.\scripts\tow2-ue4ss.ps1 -Action recommended
.\scripts\tow2-ue4ss.ps1 -Action open-log
.\scripts\mod-status.ps1
```

## Paths (Game Pass, build 1.256.9237.0)

```
C:\Program Files\WindowsApps\Microsoft.OE-Arkansas_1.256.9237.0_x64__8wekyb3d8bbwe\Arkansas\Binaries\WinGDK\ue4ss\
```

| Item | Path |
|------|------|
| Mod | `...\Mods\OverwriteOldestSave\` |
| mods.txt | `...\Mods\mods.txt` |
| Saves | `%USERPROFILE%\Saved Games\TheOuterWorlds2\` |
| Cache | `%LOCALAPPDATA%\OverwriteOldestSave-save-cache.json` |

## Stable profile

- Only **`OverwriteOldestSave : 1`** in `mods.txt`
- Vortex **Console Enabler** for `~` (optional)
- **No** `enabled.txt` in the mod folder
- **No** stock UE4SS mods enabled (crash correlation)

## In-game test

1. Restart game after deploy.
2. **Ctrl+Shift+O** or **`oow.save`**.
3. At 100/100: confirm log shows `DeleteGame OK` then `Quicksave`.
4. Host: `.\scripts\refresh-save-cache.ps1`.

Bindings: `src/ue4ss-mod/scripts/config.lua` → `Config.INPUT`.
