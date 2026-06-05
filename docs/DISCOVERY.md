# Discovery (FModel + in-game)

## Current product goal (v0.6.x)

**Quick save** from gameplay:

- **Below 100/100:** `SaveGameManager.Quicksave` via `ProcessConsoleExec`
- **At 100/100:** `DeleteGame <oldest GUID>` then `Quicksave`
- Oldest GUID from `%LOCALAPPDATA%\OverwriteOldestSave-save-cache.json` (built by `scripts/refresh-save-cache.ps1`)

Pause-menu **Save Game** row injection is **disabled** (`Config.MENU.AUTO_INJECT = false`) on stock UE4SS 3.0.1 for this game.

## 1. Install UE4SS

See [INSTALL-DEV.md](./INSTALL-DEV.md). Use the [OW2 `UE4SS-settings.ini`](https://github.com/UE4SS-RE/RE-UE4SS/tree/main/assets/CustomGameConfigs/The%20Outer%20Worlds%202) from `zCustomGameConfigs.zip`.

- `bUseUObjectArrayCache = false`
- `ProcessLocalScriptFunction` is **not** available on TOW2 3.0.1 — Blueprint `/Game/` `RegisterHook` paths do not run.

```
OverwriteOldestSave : 1
```

## 2. In-game commands

| Command | Purpose |
|---------|---------|
| `oow.save` | Quick save (delete oldest if cache ≥ 100, then Quicksave) |
| `oow.reload_cache` | Re-read cache JSON after host `refresh-save-cache.ps1` |
| `oow.save_health` | Cache count + cap hints |
| `oow.discover_save` | Log `SaveGameManager` + cache (no PowerShell in-game) |
| `oow.discover_gamepad` | Log active `Gamepad_*` key names while pressing buttons |
| `oow.discover_ui` | Log pause/save widget names (future menu inject) |

**Outside game only:**

```powershell
.\scripts\scan-saves.ps1
.\scripts\refresh-save-cache.ps1
```

Never run filesystem scans from inside UE4SS Lua.

### `oow.discover_save` — what to paste

Copy the block in `UE4SS.log` between:

```
=== OverwriteOldestSave discovery (in-game only) ===
...
=== end discovery ===
```

Useful lines: `SaveGameManager: ...`, property names, `manual_folders=100`, `oldest=...`.

### `oow.discover_gamepad` — tuning LB+RB+A

Default combo (see `config.lua` → `Config.INPUT.GAMEPAD`):

- Hold **LB** (`Gamepad_LeftShoulder`)
- Hold **RB** (`Gamepad_RightShoulder`)
- Tap **A** (`Gamepad_FaceButton_Bottom`)

If buttons do not fire, run discovery while pressing each button and update `left` / `right` / `action` name lists in config.

## 3. SaveGameManager APIs (confirmed via console gist / logs)

| Function | Use in mod |
|----------|------------|
| `DeleteGame <GUID>` | Remove oldest slot at cap (`ProcessConsoleExec`) |
| `Quicksave` | Primary save after delete (or alone below cap) |
| `SaveGame` | **Not used** — tended to create autosaves, not manual list entries |
| `Autosave` | Not used |

Reference: [TOW2 console command gist](https://gist.github.com/Micrologist/9c62b8f050bf25efbcf207382b1e7574) (`SaveGameManager::Quicksave`, etc.).

## 4. FModel searches (1.256.9237)

Pak: `Arkansas\Content\Paks\`

| Search | Why |
|--------|-----|
| `SaveGameManager` | Slot list, save/delete APIs |
| `Quicksave` | Native quick-save path |
| `SaveLoadMenu` | Pause save UI (`SaveLoadMenu_BP`) |
| `Manual` + `Save` | Cap / slot UI |

Future v2: hook pause **Save Game** to call the same quick-save path as `oow.save`.

## 5. Pause menu row (optional, off by default)

To experiment with menu inject:

1. Set `Config.MENU.AUTO_INJECT = true` in `config.lua` (may crash on Load Game — test carefully).
2. Open pause → **Save Game**, run `oow.discover_ui`.
3. Tune `Config.MENU.INJECTION_WIDGET_NAMES` / `ANCHOR_EXCLUDE_PATTERNS` from logs.

## 6. Success criteria

- [x] Quick save at &lt; 100 without blocking
- [x] At 100, delete oldest (engine) + Quicksave
- [x] Keyboard: Ctrl+Shift+O
- [x] Gamepad: LB + RB hold, tap A
- [x] External cache + orphan cleanup via `refresh-save-cache.ps1`
- [ ] Pause-menu row stable on stock UE4SS 3.0.1 (deferred)
- [ ] New manual save always appears at top of Save Game list (UI may lag; Quicksave vs manual save distinction)
