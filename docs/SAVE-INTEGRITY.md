# Save integrity

The mod **never deletes a manual save slot unless the game engine reports you are at the 100/100 cap**.

## Rules

1. **Below 100/100 (in-game)** — `SaveGame` (new manual slot). No `DeleteGame`. The mod verifies the pause-menu count increased.
2. **At 100/100 (in-game)** — `DeleteGame` on the **oldest cached folder**, then `Quicksave` (fills the freed slot).
3. **If in-game count is unknown** — run **`oow.set_cap`** (or `scripts\set-cap-marker.ps1`) when the pause menu shows **100/100**. Then `oow.save` uses **DeleteGame + Quicksave** (the validated cap path). Run **`oow.clear_cap`** after you delete a save in the pause menu. The mod will **not** delete based on disk folder count alone.

**Why not Quicksave below cap?** `Quicksave` updates the quicksave slot only — the pause menu manual count stays the same (e.g. 99/100 after you delete one). Below cap the mod calls `SaveGame(false)` via `GetFunctionByName` + `CallFunction` (console `SaveGame` / `SaveGame 0` does not pass `bIgnoreSuperNova` on TOW2). Success is verified by a new GUID folder on disk when the engine count is unreadable.

## Why disk count can differ from the pause menu

- Deleted slots sometimes leave **orphan GUID folders** on disk until `refresh-save-cache.ps1` quarantines them.
- The pause menu shows the **engine** count; the mod used to use disk count and could delete too early. That is fixed.

## After playing

```powershell
.\scripts\refresh-save-cache.ps1
```

Syncs the host cache and moves engine-deleted orphans to `%LOCALAPPDATA%\OverwriteOldestSave-backup\` (recoverable).

## Verify anytime

In-game: **`oow.save_health`** — shows in-game count vs disk cache.

Host: **`.\scripts\mod-status.ps1`**
