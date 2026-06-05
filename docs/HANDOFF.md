# Agent handoff

TOW2 **quick save** mod (repo name: overwrite-oldest-save).

## Current state (v0.6.2-dev)

| Item | Detail |
|------|--------|
| Game | Xbox PC / Game Pass **1.256.9237** |
| Saves | 100 manual GUID folders under `%USERPROFILE%\Saved Games\TheOuterWorlds2\` |
| Working flow | `oow.save` / Ctrl+Shift+O / hold LB+RB tap A → below cap: `Quicksave`; at cap: `DeleteGame` oldest + `Quicksave` |
| Cache | `refresh-save-cache.ps1` on host; mod reads JSON only (no in-game disk scan) |
| UE4SS | 3.0.1, **only** `OverwriteOldestSave : 1` |
| Menu inject | **Off** (`AUTO_INJECT = false`) |

## Do not reintroduce without testing

- `io.popen` / in-game PowerShell (freezes pause menu)
- Filesystem delete of save folders from Lua (registry desync)
- `RegisterHook` on `SaveGameManager` delete/save (crashes)
- On-screen `PrintString` right after delete (crashed)
- Console `SaveGame` as primary save (autosaves, wrong UI)
- Two-step overwrite / “must use pause Save Game” as required step (removed in v0.6)

## Key files

- `scripts/quick_save.lua` — main logic
- `scripts/input_bindings.lua` — Ctrl+Shift+O, LB+RB+A
- `scripts/save_manager.lua` — `DeleteGame`, `Quicksave`
- `scripts/saves_fs.lua` — cache JSON
- `scripts/refresh-save-cache.ps1` — host scan + orphan quarantine

## User-facing docs

- [README.md](../README.md) — setup, controls, troubleshooting
- [DISCOVERY.md](./DISCOVERY.md) — APIs, discovery commands

## Open improvements

- Configurable: overwrite-at-cap on/off, binding remapping in-game
- Stable pause-menu row calling same `QuickSave.run()`
- Reliable “newest at top” in Save Game list (may need true manual-save API)
