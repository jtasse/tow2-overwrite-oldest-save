# TOW2 — Overwrite Oldest Save (Quick Save Mod)

UE4SS mod for **The Outer Worlds 2** (Xbox PC / Game Pass) that adds a **quick save** — like F5 quicksave, but when you are at the **100 manual save cap** it **deletes the oldest manual slot first**, then saves.

**Target game version:** `1.256.9237`  
**Mod version:** `0.6.2-dev` (use **`develop`** branch — `main` is outdated)

## What it does

| Situation | Behavior |
|-----------|----------|
| **Below 100/100** (pause menu count) | `SaveGame` — new manual slot, **never deletes** |
| **At 100/100** (engine-confirmed) | Replaces **oldest** slot, then `Quicksave` |

**Save integrity:** The mod does **not** delete based on disk folder count. Orphan folders on disk cannot trigger deletes. See [docs/SAVE-INTEGRITY.md](docs/SAVE-INTEGRITY.md).

Verify in-game: **`oow.save_health`** — shows engine count vs disk cache.

Works **anywhere in gameplay** — you do **not** need the pause **Save Game** menu open.

## Controls (Game Pass / WinGDK)

| Input | Action |
|--------|--------|
| Console: **`oow.s`** or **`oow.save`** | Quick save (always works) |
| **Ctrl+Shift+O** | Quick save — auto-arms ~10s after you load a save |
| **Hold LT + LB, tap X** | Quick save (requires [gamepad bridge](#gamepad-bridge) on host) |
| **`oow.s`** | Console quick save (always works) |

Keyboard uses **RegisterKeyBind**. Gamepad uses **LT+LB+X** (unchanged from the working LEELOO2 setup).

Optional external fallback: `.\scripts\start-hotkey-binder.ps1` (AutoHotkey) if in-mod binds fail.

One press/command runs the full flow (no confirm step).

---

## Setup (one command)

From the repo root, **outside the game**:

```powershell
.\scripts\setup.ps1
```

This installs UE4SS + OW2 config if missing, refreshes the save cache, deploys the mod, and enables it.

**Already have UE4SS?** Same thing in two steps:

```powershell
.\scripts\upgrade-ue4ss.ps1   # optional: refresh UE4SS core + OW2 ini
.\scripts\enable-mod.ps1      # cache + deploy + enable
```

### First launch

1. Start the game from the **Xbox app** and load a save.
2. Wait **~30 seconds** after spawning (black screen can last up to a minute with UE4SS).
3. Verify without the in-game UI:

```powershell
.\scripts\mod-status.ps1
```

Look for `MOD LOADED OK` or `QUICK SAVE OK` in `%LOCALAPPDATA%\OverwriteOldestSave-mod-active.txt`.

4. Wait **~10 seconds** in-game — **Ctrl+Shift+O** should work without opening the console.

Restart the game after every `deploy.ps1` / `enable-mod.ps1` — Lua mods load at launch only.

---

## Daily use

**In-game or pause menu:** **Ctrl+Shift+O**, **LT+LB+X**, or **`oow.s`** in console.

### Gamepad bridge

UE4SS on WinGDK cannot read the controller in-process (`ffi` unavailable; UE input APIs crash). A small **host script** (shipped with the mod) writes XInput state to a file; the mod reads it — **no reWASD**, same **LT+LB+X** chord.

**Once per gaming session** (before or while the game runs):

```powershell
.\scripts\start-gamepad-bridge.ps1
```

Then load a save and wait ~15s. Log should show `Gamepad bridge: hold LT + LB, tap X = quick save`.

**After playing (on the host PC):**

```powershell
.\scripts\refresh-save-cache.ps1
```

Updates the JSON cache and quarantines orphan folders the mod marked during play.

**Check status (works over remote desktop):**

```powershell
.\scripts\mod-status.ps1
.\scripts\diagnose-ue4ss.ps1
```

---

## Requirements

1. **The Outer Worlds 2** (Xbox PC / Game Pass `1.256.9237`).
2. **[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases)** — installed by `setup.ps1` / `upgrade-ue4ss.ps1` (experimental build + OW2 `zCustomGameConfigs`).
3. **[Console Enabler](https://www.nexusmods.com/theouterworlds2/mods/1)** (optional) — `~` console for `oow.*` commands.
4. **PowerShell** on the host for deploy/refresh scripts.

Use **only** `OverwriteOldestSave : 1` in `mods.txt`. Enabling the full stock UE4SS mod stack has caused crashes.

---

## Where files live

Scripts auto-detect WinGDK (usually `C:\XboxGames\The Outer Worlds 2\Content\Arkansas\Binaries\WinGDK`; `WindowsApps\...\WinGDK` is a junction to the same folder).

| What | Path |
|------|------|
| UE4SS root | `...\Binaries\WinGDK\ue4ss\` |
| Mod list | `...\ue4ss\Mods\mods.txt` |
| UE4SS log | `...\ue4ss\UE4SS.log` |
| This mod | `...\ue4ss\Mods\OverwriteOldestSave\` |
| Manual saves | `%USERPROFILE%\Saved Games\TheOuterWorlds2\` |
| Save cache | `%LOCALAPPDATA%\OverwriteOldestSave-save-cache.json` |
| Mod status | `%LOCALAPPDATA%\OverwriteOldestSave-mod-active.txt` |

---

## Helper scripts

| Script | Purpose |
|--------|---------|
| **`.\scripts\setup.ps1`** | **First-time / full setup** (UE4SS if needed + enable mod) |
| `.\scripts\enable-mod.ps1` | Refresh cache + deploy + enable (usual redeploy) |
| `.\scripts\align-with-working.ps1` | After repair / drift: OW2 config + deploy + enable |
| `.\scripts\upgrade-ue4ss.ps1` | UE4SS `dwmapi.dll` + `UE4SS.dll` + OW2 ini |
| `.\scripts\diagnose-ue4ss.ps1` | UE4SS health + log tail |
| `.\scripts\mod-status.ps1` | Read mod marker / events (remote-friendly) |
| `.\scripts\export-machine-profile.ps1` | Fingerprint install for diffing two PCs |
| `.\scripts\refresh-save-cache.ps1` | Scan saves → JSON cache |
| `.\scripts\tow2-ue4ss.ps1 -Action disable-ue4ss` | Vanilla game next launch |
| `.\scripts\tow2-ue4ss.ps1 -Action disable-overwrite` | UE4SS on, mod off (isolation test) |
| `.\scripts\fix-save-state.ps1 -Apply` | Recovery when saves desync (game **quit**) |

---

## Console commands

| Command | Purpose |
|---------|---------|
| **`oow.save`** | Quick save |
| `oow.reload_cache` | Re-read cache after `refresh-save-cache.ps1` |
| `oow.save_health` | Cache count + hints |
| `oow.status` | Recent mod messages |
| `oow.s` | Short alias for `oow.save` |
| `oow.discover_gamepad` | Log controller button names |
| `oow.help` | Short command list |

---

## Gamepad

Default combo: **(hold LT + LB together) + tap X** — both triggers held, then press X once (`Gamepad_LeftTrigger` + `Gamepad_LeftShoulder` + `Gamepad_FaceButton_Left`). Avoids RB (grenade) and A (jump).

Works while playing or on the **pause menu** — polling uses `PlayerController` input state in both cases.

To remap: edit `Config.INPUT.GAMEPAD` in `src/ue4ss-mod/scripts/config.lua`, redeploy, restart. Run **`oow.discover_gamepad`** in-game to see which key names TOW2 reports.

If gamepad polling causes startup issues on your PC, set `GAMEPAD_ENABLED = false` in `config.lua`.

---

## Troubleshooting

### Mod / UE4SS not loading

```powershell
.\scripts\diagnose-ue4ss.ps1
.\scripts\align-with-working.ps1
```

Check `UE4SS-settings.ini` is **6852** bytes (experimental OW2 config, not the smaller main-branch file). No `override.txt` in WinGDK.

### Game crashes with mod, vanilla works

Already fixed in current `develop` build: input hooks defer until in-game. Run `.\scripts\enable-mod.ps1` and restart.

**Isolate:**

```powershell
.\scripts\tow2-ue4ss.ps1 -Action disable-overwrite   # UE4SS only
.\scripts\tow2-ue4ss.ps1 -Action disable-ue4ss       # vanilla
```

### "Something went wrong launching your game"

Usually **tampered game exe** (e.g. copying `TheOuterWorlds2-WinGDK-Shipping.exe` from another PC). **Do not swap exes on Game Pass.** Fix: Xbox app → Manage → **Verify and repair**, then `.\scripts\align-with-working.ps1`.

### Black screen on launch

Can last **30–60 seconds** with UE4SS. Wait before force-quitting. Confirm with `.\scripts\mod-status.ps1`.

### Stale cache / wrong cap count

```powershell
.\scripts\refresh-save-cache.ps1
```

Then in-game: `oow.reload_cache` or restart.

### Compare two PCs

```powershell
.\scripts\export-machine-profile.ps1
```

See **[docs/WORKING-STATE.md](docs/WORKING-STATE.md)** for a validated reference profile.

---

## More docs

- **[docs/WORKING-STATE.md](docs/WORKING-STATE.md)** — validated install snapshot (LEELOO2, 2026-06-05)
- **[docs/INSTALL-DEV.md](docs/INSTALL-DEV.md)** — short dev reference
- **[docs/DISCOVERY.md](docs/DISCOVERY.md)** — API / discovery commands
- **[docs/HANDOFF.md](docs/HANDOFF.md)** — context for agents

## License

See repository license if present; game assets and trademarks belong to their owners.
