# TOW2 — Overwrite Oldest Save

When manual save slots are full (100), adds **Overwrite oldest save** on the pause menu under **Save Game**, with a confirmation screen.

- **Target game version:** 1.256.9237
- **Status:** v0.1 dev — filesystem oldest-save detection, `SaveGameManager` hooks, console/dev confirm flow; pause menu UI pending FModel discovery

See `docs/INSTALL-DEV.md` for setup and `docs/DISCOVERY.md` for in-game / FModel next steps.

### Quick test (with UE4SS + Console Enabler)

1. Deploy mod (`scripts/deploy.ps1`).
2. Load a save at 100/100 manual slots.
3. Console: `oow.discover_save` then `oow.overwrite_oldest` → `oow.overwrite_confirm` (or `Ctrl+Shift+O` twice).
4. Perform one normal manual save and note hook args in the UE4SS log for tuning `DeleteGame` / `SaveGame` parameters.
