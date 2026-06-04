# Agent handoff (paste into a chat opened **with this folder** as the workspace)

Continue the TOW2 **Overwrite oldest save** mod.

- **Repo:** `C:\dev\github\tow2-overwrite-oldest-save`
- **Game:** Xbox PC / Game Pass, version **1.256.9237**
- **Saves:** at cap (100), backup done
- **v1:** Pause menu → **Overwrite oldest save** under **Save Game**, only when full → confirmation → overwrite oldest slot
- **Later:** same action as a row on the save list
- **Not in scope:** long-press, more save slots mod
- **Game path:** `C:\XboxGames\The Outer Worlds 2\Content\Arkansas\Binaries\WinGDK\`
- **Test transfer:** Google Drive to gaming PC; Nexus later

**Done in repo (v0.1):** modular UE4SS Lua mod, `oow.*` console commands, Ctrl+Shift+O dev confirm, `SaveGame`/`DeleteGame` param logging, filesystem oldest-manual detection under `%USERPROFILE%\Saved Games\TheOuterWorlds2`.

**Next:** Install UE4SS on dev PC → run `oow.discover_save` → FModel pause/SaveGame UI → fill `Config.MENU_HOOKS` → wire confirmation widget → tune `DeleteGame`/`SaveGame` args from hook log. See `docs/DISCOVERY.md`.
