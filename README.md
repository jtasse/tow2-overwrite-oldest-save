# TOW2 — Overwrite Oldest Save

UE4SS mod for **The Outer Worlds 2** (Xbox PC / Game Pass) when manual saves hit the **100-slot cap** and the game stops letting you save.

**Target game version:** `1.256.9237`  
**Mod version:** `0.2.2-dev`

## What works today

| Feature | Status |
|---------|--------|
| Detect 100 manual save folders | Working |
| Console: overwrite oldest slot | Working |
| Pause menu → **Overwrite oldest save** | Not implemented yet |
| Pause menu confirm dialog (in-game UI) | Not implemented yet |

**Validated workflow:** with a full save list, run two console commands, then save from the pause menu without “Save unsuccessful.”

## Requirements

1. **The Outer Worlds 2** (this project was tested on Xbox PC / Microsoft Store).
2. **[Console Enabler](https://www.nexusmods.com/theouterworlds2/mods/1)** (Vortex or manual `.pak` in `Paks\~mods\`) — opens the `~` developer console.
3. **[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases)** — Lua mod loader injected via `dwmapi.dll`.
4. **PowerShell** (for helper scripts; edits protected `WindowsApps` folders for you).

You do **not** need the full default UE4SS mod stack (`BPModLoaderMod`, `ConsoleEnablerMod`, etc.) for this mod. Using only **OverwriteOldestSave** avoids crashes seen with all stock UE4SS mods enabled.

---

## Where files live (Game Pass)

The game you launch from the Store runs here (package name includes your build version):

```
C:\Program Files\WindowsApps\Microsoft.OE-Arkansas_1.256.9237.0_x64__8wekyb3d8bbwe\Arkansas\
```

Important paths:

| What | Path |
|------|------|
| Game binary | `...\Arkansas\Binaries\WinGDK\TheOuterWorlds2-WinGDK-Shipping.exe` |
| UE4SS root | `...\Arkansas\Binaries\WinGDK\ue4ss\` |
| UE4SS mod list | `...\ue4ss\Mods\mods.txt` |
| UE4SS log | `...\ue4ss\UE4SS.log` |
| This mod | `...\ue4ss\Mods\OverwriteOldestSave\` |
| Saves | `%USERPROFILE%\Saved Games\TheOuterWorlds2\` |

`C:\XboxGames\The Outer Worlds 2\` is the Game Pass **content** install; UE4SS and this mod must be under **`WindowsApps\...\Binaries\WinGDK\ue4ss`**, not `WinGDK\Mods\` at the top level.

---

## Setup (step by step)

### 1. Console Enabler (Vortex)

1. Install the [TOW2 Vortex extension](https://www.nexusmods.com/site/mods/1498) if needed.
2. Install **Console Enabler and BP ModLoader** from Nexus (mod id 1).
3. Enable and **Deploy** in Vortex.
4. Confirm a folder exists under:
   ```
   ...\Arkansas\Content\Paks\~mods\
   ```

### 2. UE4SS

1. Download from [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases):
   - `UE4SS_v3.0.1.zip` (or newer if you accept the risk)
   - `zCustomGameConfigs.zip` (OW2-specific settings)
2. Extract UE4SS so you have:
   ```
   ...\Binaries\WinGDK\dwmapi.dll
   ...\Binaries\WinGDK\ue4ss\UE4SS.dll
   ...\Binaries\WinGDK\ue4ss\UE4SS-settings.ini
   ...\Binaries\WinGDK\ue4ss\Mods\mods.txt
   ```
3. From `zCustomGameConfigs.zip`, copy the **The Outer Worlds 2** `UE4SS-settings.ini` (and `VTableLayout.ini` if included) into `...\ue4ss\`, replacing the default.
4. In `ue4ss\UE4SS-settings.ini`, confirm:
   ```ini
   bUseUObjectArrayCache = false
   ```

### 3. Install this mod

Clone or copy this repo, then from the repo root in PowerShell:

```powershell
.\scripts\deploy.ps1
```

That copies `src\ue4ss-mod\` to `...\ue4ss\Mods\OverwriteOldestSave\`.

### 4. Recommended `mods.txt` profile

Do **not** enable every stock UE4SS mod. From the repo:

```powershell
.\scripts\tow2-ue4ss.ps1 -Action recommended
```

That sets **only** `OverwriteOldestSave : 1` and turns the rest off, and ensures `dwmapi.dll` is present.

Enable/disable manually by editing:

```
...\ue4ss\Mods\mods.txt
```

You must have a line:

```
OverwriteOldestSave : 1
```

**Important:** Do **not** put an `enabled.txt` file inside `OverwriteOldestSave\`. UE4SS will load the mod even when `mods.txt` says `0`.

### 5. First launch check

1. Start the game and load a save.
2. Press **`~`** — the console should open (Console Enabler).
3. Open the log without browsing `WindowsApps`:
   ```powershell
   .\scripts\tow2-ue4ss.ps1 -Action open-log
   ```
4. Look for:
   ```text
   [OverwriteOldestSave] loaded v0.2.2-dev
   ```

If the game crashes on startup, see [Troubleshooting](#troubleshooting).

---

## Using the mod (console workflow)

Use this when you have **100 manual saves** and the game will not save.

1. Load your save.
2. Wait **~5 seconds** after spawning (save-folder cache warms automatically).
3. Press **`~`** and run:
   ```
   oow.overwrite_oldest
   ```
   You should see a message naming the oldest slot and asking you to confirm.
4. Within 30 seconds:
   ```
   oow.overwrite_confirm
   ```
5. Open the pause menu and use **Save Game** as usual.

Optional:

| Command | Purpose |
|---------|---------|
| `oow.discover_save` | Refresh save count / oldest slot in `UE4SS.log` |

Messages appear in the **game console** and in **`UE4SS.log`**.

---

## Helper scripts (run from repo root)

All scripts target the Game Pass `WindowsApps` path baked in for build `1.256.9237.0`. Edit `$GameRoot` / `$WinGDK` in the script if your package folder name differs.

| Script | Purpose |
|--------|---------|
| `.\scripts\deploy.ps1` | Copy mod into `ue4ss\Mods\OverwriteOldestSave\` |
| `.\scripts\tow2-ue4ss.ps1 -Action recommended` | Safe `mods.txt` + enable UE4SS |
| `.\scripts\tow2-ue4ss.ps1 -Action status` | Show mod flags and log tail |
| `.\scripts\tow2-ue4ss.ps1 -Action disable-ue4ss` | Rename `dwmapi.dll` off (vanilla game) |
| `.\scripts\tow2-ue4ss.ps1 -Action enable-ue4ss` | Restore UE4SS |
| `.\scripts\tow2-ue4ss.ps1 -Action open-log` | Open `UE4SS.log` in Notepad |
| `.\scripts\scan-saves.ps1` | List manual save folders (outside the game) |

---

## Optional: skip shader warmup when testing

To avoid PSO/shader warmup on every boot (after shaders are built once):

Create or edit:

```
%LOCALAPPDATA%\Arkansas\Saved\Config\WinGDK\Engine.ini
```

Add:

```ini
[SystemSettings]
r.PSOWarmup.WarmupMaterials=0
```

Let the game compile shaders normally once after each **game patch** or **GPU driver** update, then re-apply this for fast restarts.

---

## Gaming PC / transfer

1. Copy this repo (or run `deploy.ps1` on the other PC with the same game build).
2. Repeat UE4SS + Console Enabler setup on that machine.
3. Run `.\scripts\tow2-ue4ss.ps1 -Action recommended`.
4. Same console workflow in-game.

Vortex on the gaming PC is fine for Console Enabler; UE4SS remains a manual extract into `WinGDK\ue4ss`.

---

## Troubleshooting

### `Command not recognized: oow.*`

- Mod did not load. Check `UE4SS.log` for `loaded v0.2.2-dev` or `Failed to execute main script`.
- Fix Lua errors, redeploy with `.\scripts\deploy.ps1`, restart the game.

### Game crashes with UE4SS on

1. `.\scripts\tow2-ue4ss.ps1 -Action recommended` (minimal mods).
2. Still crashes? `.\scripts\tow2-ue4ss.ps1 -Action disable-ue4ss` and test vanilla.
3. If vanilla is stable, re-enable UE4SS and keep **only** `OverwriteOldestSave : 1`.

### `OverwriteOldestSave : 0` but mod still runs

Remove `...\Mods\OverwriteOldestSave\enabled.txt` if it exists.

### `oow.overwrite_oldest` crashed the game (older builds)

Fixed in `0.2.2` — do not run PowerShell file scans inside the console command; update the mod and wait ~5s after load.

### Cannot open `WindowsApps` in Explorer

Use the PowerShell scripts above; they edit files without manual access.

### Save still fails after confirm

Check `UE4SS.log` after `oow.overwrite_confirm` for `Overwrite complete` or errors. Run `oow.discover_save` and confirm `manual_folders=100`.

---

## Roadmap

- Pause menu entry under **Save Game** (only when at 100/100)
- In-game confirmation dialog
- Nexus release packaging

See `docs/DISCOVERY.md` for FModel / UI hook notes.

---

## More docs

- `docs/INSTALL-DEV.md` — short dev reference
- `docs/DISCOVERY.md` — UI and `SaveGameManager` discovery
- `docs/HANDOFF.md` — agent/context summary

## License

See repository license if present; game assets and trademarks belong to their owners.
