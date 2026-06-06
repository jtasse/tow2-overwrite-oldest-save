# Dev setup (short reference)

Full instructions: **[../README.md](../README.md)**  
Validated profile: **[WORKING-STATE.md](./WORKING-STATE.md)**

## Quick commands

```powershell
.\scripts\setup.ps1               # first time / full (UE4SS + mod)
.\scripts\enable-mod.ps1          # redeploy + enable
.\scripts\align-with-working.ps1  # after Xbox repair or config drift
.\scripts\mod-status.ps1          # did mod load? (remote-friendly)
.\scripts\diagnose-ue4ss.ps1      # UE4SS + log tail
.\scripts\refresh-save-cache.ps1  # after playing / before 100/100 test
.\scripts\export-machine-profile.ps1
```

## Paths (Game Pass, build 1.256.9237.0)

WinGDK is usually `C:\XboxGames\The Outer Worlds 2\Content\Arkansas\Binaries\WinGDK`. Override in `scripts\lib\game-path.ps1` if needed.

| Item | Path |
|------|------|
| Mod source | `src\ue4ss-mod\` |
| Mod deployed | `...\Mods\OverwriteOldestSave\` |
| mods.txt | `...\Mods\mods.txt` |
| Saves | `%USERPROFILE%\Saved Games\TheOuterWorlds2\` |
| Cache | `%LOCALAPPDATA%\OverwriteOldestSave-save-cache.json` |

## Stable profile

- Branch **`develop`**, mod **0.6.2-dev**
- Only **`OverwriteOldestSave : 1`** in `mods.txt`
- **`UE4SS-settings.ini` = 6852 bytes** (experimental OW2 config)
- **No** `override.txt`, **no** `enabled.txt` in mod folder
- **No** stock UE4SS mods enabled

## Isolation tests

```powershell
.\scripts\tow2-ue4ss.ps1 -Action disable-ue4ss        # vanilla
.\scripts\tow2-ue4ss.ps1 -Action disable-overwrite     # UE4SS only
.\scripts\tow2-ue4ss.ps1 -Action enable-overwrite      # full stack
```

## In-game test

1. Restart game after deploy.
2. Wait ~30s in-game; run `.\scripts\mod-status.ps1` on host.
3. **Ctrl+Shift+O**, **LT+LB+X**, or **`oow.save`**.
4. At 100/100: log should show `DeleteGame OK` then `Quicksave`.
5. Host: `.\scripts\refresh-save-cache.ps1`.

Bindings: `src/ue4ss-mod/scripts/config.lua` → `Config.INPUT` (gamepad: LT+LB+X).
