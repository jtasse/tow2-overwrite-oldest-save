# Dev setup

**Game Pass install path (this PC):**

```
C:\XboxGames\The Outer Worlds 2\Content\Arkansas\
```

## Dependencies (install separately)

1. [Console Enabler and BP ModLoader](https://www.nexusmods.com/theouterworlds2/mods/1) → `Arkansas\Content\Paks\~mods\`
2. [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases) → extract so you have `Arkansas\Binaries\WinGDK\ue4ss\` (with `UE4SS.dll`, `UE4SS-settings.ini`, and `ue4ss\Mods\`). The injector `dwmapi.dll` sits next to `TheOuterWorlds2-WinGDK-Shipping.exe` in `WinGDK\`.

In `ue4ss\UE4SS-settings.ini`: `bUseUObjectArrayCache = false` (OW2 custom config from `zCustomGameConfigs.zip`).

In `ue4ss\Mods\mods.txt`: `BPModLoaderMod : 1` and `OverwriteOldestSave : 1`

## Deploy this mod

From the repo (PowerShell):

```powershell
.\scripts\deploy.ps1
```

Or copy `src\ue4ss-mod\` to:

```
...\Binaries\WinGDK\ue4ss\Mods\OverwriteOldestSave\
```

Use **only** `ue4ss\Mods\mods.txt` to enable/disable mods (`OverwriteOldestSave : 1` or `: 0`). Do **not** leave an `enabled.txt` inside the mod folder — UE4SS will start the mod even when `mods.txt` says `0`.

**Note:** `mods.txt` is **not** in `WinGDK\Mods\` — it is inside the `ue4ss` subfolder.

## Vortex

Use the [TOW2 Vortex extension](https://www.nexusmods.com/site/mods/1498) on your gaming PC; manual copy is fine for development.
