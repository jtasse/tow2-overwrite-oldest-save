# Dev setup (short reference)

Full instructions: **[../README.md](../README.md)**

## Quick commands

```powershell
.\scripts\deploy.ps1
.\scripts\tow2-ue4ss.ps1 -Action recommended
.\scripts\tow2-ue4ss.ps1 -Action open-log
```

## Paths (Game Pass, build 1.256.9237.0)

```
C:\Program Files\WindowsApps\Microsoft.OE-Arkansas_1.256.9237.0_x64__8wekyb3d8bbwe\Arkansas\Binaries\WinGDK\ue4ss\
```

Mod: `...\ue4ss\Mods\OverwriteOldestSave\`  
Config: `...\ue4ss\Mods\mods.txt` (not `WinGDK\Mods\`)

## Stable profile

Only `OverwriteOldestSave : 1`; Vortex **Console Enabler** for `~`; no `enabled.txt` in the mod folder.
