# TOW2 — Overwrite Oldest Save (Quick Save Mod)

UE4SS mod for **The Outer Worlds 2** (Xbox PC / Game Pass) that adds a **quick save** — like F5 quicksave, but when you are at the **100 manual save cap** it **deletes the oldest manual slot first**, then saves.

**Target game version:** `1.256.9237`  
**Mod version:** `0.6.2-dev`

## What it does

| Situation | Behavior |
|-----------|----------|
| **Below 100/100** manual saves | Runs `Quicksave` (no delete) |
| **At 100/100** | `DeleteGame` on oldest slot (from external cache), then `Quicksave` |

Works **anywhere in gameplay** — you do **not** need the pause **Save Game** menu open.

The pause-menu row injector exists in code but is **off by default** (`AUTO_INJECT = false`) because it caused instability on this build.

## Controls

| Input | Action |
|--------|--------|
| **Ctrl+Shift+O** | Quick save |
| **Hold LB + RB, tap A** (Xbox) | Quick save |
| Console: **`oow.save`** | Same (aliases: `oow.overwrite`, `oow.quicksave`) |

There is **no** two-step confirm anymore — one press/command runs the full flow.

Customize bindings in `src/ue4ss-mod/scripts/config.lua` → `Config.INPUT`.

## Requirements

1. **The Outer Worlds 2** (tested on Xbox PC / Microsoft Store).
2. **[Console Enabler](https://www.nexusmods.com/theouterworlds2/mods/1)** (optional but useful) — opens the `~` developer console for `oow.*` commands.
3. **[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases)** — Lua mod loader via `dwmapi.dll`.
4. **PowerShell** — deploy scripts and save-cache refresh (run **outside** the game).

Use **only** `OverwriteOldestSave : 1` in `mods.txt`. Enabling the full stock UE4SS mod stack has caused crashes on this game.

---

## Where files live (Game Pass)

```
C:\Program Files\WindowsApps\Microsoft.OE-Arkansas_1.256.9237.0_x64__8wekyb3d8bbwe\Arkansas\
```

| What | Path |
|------|------|
| UE4SS root | `...\Arkansas\Binaries\WinGDK\ue4ss\` |
| Mod list | `...\ue4ss\Mods\mods.txt` |
| UE4SS log | `...\ue4ss\UE4SS.log` |
| This mod | `...\ue4ss\Mods\OverwriteOldestSave\` |
| Manual saves | `%USERPROFILE%\Saved Games\TheOuterWorlds2\` (GUID folders) |
| Save cache (mod reads) | `%LOCALAPPDATA%\OverwriteOldestSave-save-cache.json` |
| Status / last command | `%LOCALAPPDATA%\OverwriteOldestSave-mod-active.txt` |

`C:\XboxGames\The Outer Worlds 2\` is Game Pass **content**; UE4SS must live under **`WindowsApps\...\Binaries\WinGDK\ue4ss`**.

---

## Setup

### 1. Console Enabler (optional)

Install from Nexus, enable in Vortex, deploy. Confirm `...\Arkansas\Content\Paks\~mods\` exists. Press **`~`** in-game to open the console.

### 2. UE4SS

1. [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases): `UE4SS_v3.0.1.zip` + `zCustomGameConfigs.zip` (OW2).
2. Extract to `...\Binaries\WinGDK\` (`dwmapi.dll`, `ue4ss\`, etc.).
3. Copy OW2 `UE4SS-settings.ini` into `ue4ss\`; set `bUseUObjectArrayCache = false`.

### 3. Install and enable this mod

From the repo root:

```powershell
.\scripts\enable-mod.ps1
```

That refreshes the save cache, deploys the mod, enables UE4SS, and sets `OverwriteOldestSave : 1`.

Or step by step:

```powershell
.\scripts\refresh-save-cache.ps1
.\scripts\deploy.ps1
.\scripts\tow2-ue4ss.ps1 -Action recommended
```

**Do not** add `enabled.txt` inside the mod folder — use `mods.txt` only.

### 4. First launch

1. Start the game and load a save; wait **~5 seconds** (mod activates after `ClientRestart`).
2. Check `UE4SS.log` for `loaded v0.6.2-dev` and `SaveGameManager ready`.
3. Try **Ctrl+Shift+O** or **`oow.save`** in the console.

Restart the game after every `deploy.ps1` — Lua mods load at launch only.

---

## Daily use

### In-game

1. Play normally.
2. **Ctrl+Shift+O**, **LB+RB+A**, or **`oow.save`** when you want to save.
3. At 100/100, the mod removes the oldest cached slot via `DeleteGame`, then calls **`Quicksave`** (~3 seconds total).

### After playing (on the host PC)

```powershell
.\scripts\refresh-save-cache.ps1
```

This updates the JSON cache the mod reads and **moves engine-deleted orphan folders** to `%LOCALAPPDATA%\OverwriteOldestSave-backup\` if the mod marked them during play.

If you saved in-game during a session without refreshing on the host, run **`oow.reload_cache`** in the console before the next quick save (or refresh on the host first).

### Check result without the in-game console

```powershell
.\scripts\mod-status.ps1
```

Reads `%LOCALAPPDATA%\OverwriteOldestSave-mod-active.txt` and the event log. Use **`-Balloon`** for a tray popup.

---

## Console commands

| Command | Purpose |
|---------|---------|
| **`oow.save`** | Quick save (primary) |
| `oow.overwrite` / `oow.quicksave` | Same as `oow.save` |
| `oow.reload_cache` | Re-read cache JSON after `refresh-save-cache.ps1` |
| `oow.save_health` | Cache count + hints |
| `oow.status` | Recent mod messages |
| `oow.discover_gamepad` | Log which controller buttons the game sees (tune `Config.INPUT`) |
| `oow.discover_save` | Log `SaveGameManager` + cache state |
| `oow.discover_ui` | Log pause-menu widget names (for future menu inject) |
| `oow.help` | Short command list |

Feedback is written to **`UE4SS.log`**, **`OverwriteOldestSave-mod-active.txt`**, and **`OverwriteOldestSave-last-console.txt`**. On-screen text is disabled by default (caused crashes after delete on this build).

---

## Helper scripts

| Script | Purpose |
|--------|---------|
| `.\scripts\enable-mod.ps1` | Refresh cache + deploy + enable UE4SS + mod |
| `.\scripts\refresh-save-cache.ps1` | Scan save folders → JSON cache; clean pending orphans |
| `.\scripts\deploy.ps1` | Copy mod to `ue4ss\Mods\OverwriteOldestSave\` |
| `.\scripts\tow2-ue4ss.ps1 -Action recommended` | Only `OverwriteOldestSave : 1` |
| `.\scripts\tow2-ue4ss.ps1 -Action status` | Mod flags + log tail |
| `.\scripts\tow2-ue4ss.ps1 -Action disable-ue4ss` | Turn UE4SS off for next launch |
| `.\scripts\mod-status.ps1` | Read mod marker / last console output |
| `.\scripts\scan-saves.ps1` | List manual save folders (outside game) |
| `.\scripts\reconcile-saves.ps1` | Disk vs cache summary |
| `.\scripts\fix-save-state.ps1 -Apply` | Recovery: disable mod, move orphan folders (game **quit**) |

Edit `$WinGDK` in scripts if your `WindowsApps` package version folder differs.

---

## Save list UI quirks

Quick save uses the engine **`Quicksave`** API, not the pause-menu **Save Game** button. The **Save Game** list can look out of sync for a moment; it usually catches up after a normal pause-menu visit or after `refresh-save-cache.ps1` on the host.

Do **not** delete GUID folders under `Saved Games\TheOuterWorlds2` by hand unless `fix-save-state.ps1` tells you to — that desyncs the engine registry.

---

## Troubleshooting

### `oow.save` says "Not at 100/100 (cache=N)" but you have 100 saves

The **cache file is stale**. On the host:

```powershell
.\scripts\refresh-save-cache.ps1
```

Then in-game: **`oow.reload_cache`**, or restart the game.

### Quick save runs but nothing new at top of Save Game list

Expected with some builds — `Quicksave` ≠ pause-menu manual save UI. Check `%LOCALAPPDATA%\OverwriteOldestSave-mod-active.txt` for `QUICK SAVE OK`. Newest folder on disk: `.\scripts\scan-saves.ps1`.

### Game crashed on overwrite (older builds)

Fixed in **v0.5.2+**: no on-screen `PrintString` after delete; delayed `Quicksave`. Update mod and restart.

### Desync / stuck at 99 or 100 (orphan folders)

Quit the game, then:

```powershell
.\scripts\fix-save-state.ps1 -Apply
```

Reload, save once from pause if needed, then `.\scripts\refresh-save-cache.ps1`.

### Controller combo does not work

1. Load a save (in gameplay).
2. Run **`oow.discover_gamepad`** while pressing buttons.
3. Update `Config.INPUT.GAMEPAD` in `config.lua` with names from the log.
4. Redeploy and restart.

### `Command not recognized: oow.*`

Mod not loaded — check `UE4SS.log`, run `.\scripts\enable-mod.ps1`, restart game.

### UE4SS crashes on startup

`.\scripts\tow2-ue4ss.ps1 -Action recommended`. If still unstable: `-Action disable-ue4ss`.

---

## Architecture notes (for developers)

- **No** `io.popen` / PowerShell inside the game (freezes pause menu).
- **No** filesystem delete from Lua (desyncs registry); orphans cleaned by `refresh-save-cache.ps1`.
- **No** `RegisterHook` on `SaveGameManager` delete/save (crashed on this build).
- Oldest slot comes from **`refresh-save-cache.ps1`** (sorted by folder mtime).
- At cap: `ProcessConsoleExec DeleteGame <GUID>` then `Quicksave`.

See `docs/DISCOVERY.md` for FModel / future pause-menu work.

---

## Skip shader warmup (optional)

See `.\scripts\skip-shader-warmup.ps1 -Action status` and `.\scripts\tow2-ue4ss.ps1 -Action skip-shaders-fast-boot` — unrelated to saves but useful for faster restarts.

---

## More docs

- `docs/INSTALL-DEV.md` — short dev reference
- `docs/DISCOVERY.md` — `SaveGameManager` / UI discovery
- `docs/HANDOFF.md` — context for agents

## License

See repository license if present; game assets and trademarks belong to their owners.
