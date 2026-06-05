# Agent handoff

TOW2 **quick save** mod (repo name: overwrite-oldest-save).

## Validated state (2026-06-05, LEELOO2)

| Item | Detail |
|------|--------|
| Game | Xbox PC / Game Pass **1.256.9237** |
| Branch | **`develop`** @ 8509bce — not `main` |
| Working flow | Ctrl+Shift+O / `oow.save` → below cap: `Quicksave`; at cap: `DeleteGame` oldest + `Quicksave` |
| Proof | Log + marker: `QUICK SAVE OK`, `DeleteGame OK`, `SUCCESS: Quick save done` |
| UE4SS | experimental-latest, **only** `OverwriteOldestSave : 1` |
| OW2 ini | **6852** B settings + **18293** B VTableLayout (`zCustomGameConfigs.zip`) |
| `override.txt` | **Must be absent** |
| Gamepad poll | **Off** by default (`GAMEPAD_ENABLED = false`) — WinGDK freeze |
| Input hooks | **Deferred** until `SaveGameManager` ready (`start_after_load`) |
| Menu inject | **Off** (`AUTO_INJECT = false`) |

Full fingerprint: **[WORKING-STATE.md](./WORKING-STATE.md)**

## Setup entry points

```powershell
.\scripts\setup.ps1          # first time / full
.\scripts\enable-mod.ps1     # redeploy
.\scripts\align-with-working.ps1   # post-repair
.\scripts\mod-status.ps1     # verify (remote OK)
```

## Do not reintroduce without testing

- `io.popen` / in-game PowerShell (freezes pause menu)
- Filesystem delete of save folders from Lua (registry desync)
- `RegisterHook` on `SaveGameManager` delete/save (crashes)
- On-screen `PrintString` right after delete (crashed)
- **Copying game exe** between Game Pass PCs (launcher integrity failure)
- **`override.txt`** in WinGDK
- **main-branch** `UE4SS-settings.ini` (6658 B — wrong for OW2)
- Early keyboard/gamepad hooks at mod **load** time (startup crash/hang)

## Key files

- `scripts/setup.ps1` — one-shot setup
- `scripts/install-ue4ss-config.ps1` — OW2 ini from experimental zip
- `scripts/quick_save.lua` — main logic
- `scripts/input_bindings.lua` — deferred Ctrl+Shift+O; optional gamepad
- `scripts/save_manager.lua` — `DeleteGame`, `Quicksave`
- `scripts/saves_fs.lua` — cache JSON
- `scripts/refresh-save-cache.ps1` — host scan + orphan quarantine

## User-facing docs

- [README.md](../README.md) — setup, controls, troubleshooting
- [WORKING-STATE.md](./WORKING-STATE.md) — reference install
- [DISCOVERY.md](./DISCOVERY.md) — APIs, discovery commands

## Open improvements

- Re-enable gamepad poll safely on all WinGDK builds
- Configurable overwrite-at-cap on/off, binding remapping in-game
- Stable pause-menu row calling same `QuickSave.run()`
