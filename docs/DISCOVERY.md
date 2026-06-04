# Discovery (FModel + in-game)

Goal: pause menu **Save Game** submenu → row **Overwrite oldest save** (only when 100/100 manual) → confirmation → call `SaveGameManager` to replace the oldest slot.

## 1. Install UE4SS on dev PC

See [INSTALL-DEV.md](./INSTALL-DEV.md). Use the [OW2 custom `UE4SS-settings.ini`](https://github.com/UE4SS-RE/RE-UE4SS/tree/main/assets/CustomGameConfigs/The%20Outer%20Worlds%202) from the UE4SS release zip (`zCustomGameConfigs.zip`).

- `bUseUObjectArrayCache = false`
- If BP hooks are required and startup warns about `ProcessLocalScriptFunction`, try `HookProcessLocalScriptFunction = 0` in the Hooks section (limits `/Game/` `RegisterHook`).

Deploy this mod, enable in `ue4ss/Mods/mods.txt`:

```
OverwriteOldestSave : 1
```

## 2. In-game probes (mod already ships these)

Open the UE console (`~` with Console Enabler) after loading a save:

| Command | Purpose |
|---------|---------|
| `oow.discover_save` | Safe in-game probe of `SaveGameManager` fields (no PowerShell). |
| `oow.overwrite_oldest` | Starts confirm flow (dev stand-in for pause menu). |
| `oow.overwrite_confirm` | Executes overwrite after confirm. |

**Filesystem save count (outside game):** `.\scripts\scan-saves.ps1` in PowerShell — never run file scans from inside UE4SS.

### What to paste back (be explicit)

After `oow.discover_save`, open the log (`.\scripts\tow2-ue4ss.ps1 open-log`) and copy **only the block between**:

```
=== OverwriteOldestSave discovery (in-game only) ===
...
=== end discovery ===
```

Example of what we need inside that block:

```
SaveGameManager: SaveGameManager_123
  ManualSaveCount = 100
  MaxManualSaves = 100
```

Any line with a property name and value helps. If you only see `SaveGameManager: ...` and nothing else, say that — we’ll add more property names.

**After one normal manual save**, also paste any lines containing `SaveGameManager hook` and `arg[1]`, `arg[2]`, etc.

## 3. FModel searches (1.256.9237)

Pak path: `Arkansas\Content\Paks\`

| Search | Why |
|--------|-----|
| `SaveGameManager` | C++ / BP save API, slot list, max manual count |
| `Pause` + `Menu` | Pause root widget |
| `Save` + `Game` | Save submenu / “Save Game” row |
| `Confirm` + `Save` | Existing confirmation dialogs to mirror |
| `Manual` + `Save` | Slot list UI, “full” detection |

Record full `UFunction` paths for:

- Opening pause → Save Game
- Manual save attempt when full (greyed out / error)
- Any `CanSave` / `IsSaveSlotsFull` style function

Add confirmed hook paths to `Config.MENU_HOOKS` in `scripts/config.lua` and implement `menu.lua` to show/hide the new row when `SavesFs.is_at_cap()` is true.

## 4. Dump Lua bindings (optional)

UE4SS GUI → Dumpers → **Dump Lua Bindings** → inspect `Mods/shared/types` for `SaveGameManager` fields (`ManualSaveSlots`, filenames, etc.). Do **not** `require` generated type files from the mod.

## 5. Success criteria for v1

- [ ] Row visible only at 100 manual saves
- [ ] Confirmation text matches game style
- [ ] After confirm, new manual save succeeds without “Save Unsuccessful”
- [ ] Oldest manual slot file timestamp updates (or slot content replaced in UI)
