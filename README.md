# SurvivorsDragonUi

A Dragonflight-style interface for Azeroth Survivors, with a movable HUD, combat text and cache and guardian guides.

## Install

1. Download [SurvivorsDragonUi.zip](https://github.com/migwynkriid13/SurvivorsDragonUi/releases/latest/download/SurvivorsDragonUi.zip).
2. In the game, go to **Options → AddOns → Open AddOns Folder**.
3. Extract the ZIP and put the `SurvivorsDragonUi` folder there. You can also place it manually in `benilla-config/AddOns/` beside the game.
4. Enable the addon and enter a run.

The file should be at `benilla-config/AddOns/SurvivorsDragonUi/SurvivorsDragonUi.toc`.

**Browser version:** open **Options → AddOns → install a .zip** and choose the downloaded ZIP.

## Set up your UI

Type `/sdui` to open the editor.

Action buttons start locked. Under **Action bar**, turn off **Lock action buttons** and click **Confirm** to allow rearranging. Shift-click two occupied buttons to swap their spells; spells cannot be dragged off the bar.

XP starts attached beneath the action bar. Turn off **Attach XP to action bar** to move and resize it separately, then click **Confirm** to save.

- Drag a frame to move it. Hold **Shift** while dragging to align its edges or center with nearby frames, screen guides or the finer grid. Gold lines show the alignment. Drag its corners to resize it. **Tooltip** controls the native hover card; click its handle and use **Hide frame** under **Layout** to hide it.
- Use `/sdui lock` for move and resize handles with only the **Confirm** button. Use `/sdui` to return to the full editor.
- Use **Layout** for positions and sizes, **Profiles** to save and load named setups, **HUD** for display options, **Combat text** for damage numbers, and **Run timer** for its text and font.
- Click **Confirm** to save, or **Cancel** to undo your changes. Leaving the run or reloading also discards unsaved changes.

**Addon defaults** or `/sdui reset` immediately resets your layout, display options, and timer font and text. Your combat-text mode stays unchanged.

In **Profiles**, enter a name and click **Save new profile** to keep your current setup. Select a saved profile to load, overwrite or delete it. Click **Confirm** to keep profile changes, or **Cancel** to undo them. Resetting the addon keeps your saved profiles.

To use the game's damage numbers, choose **Game settings** under **Combat text**, then enable **Show Target Damage** in the game options.

## Features

- Player and target frames, a seven-button action bar, equipped jewelry, XP, kills, gold and cache cost.
- A run timer with boss markers, movable event banners and boss health bars. Move, resize or hide **Banners** through `/sdui` → **Layout**. Enable **Guardians in boss bar** in `/sdui` → **HUD** to include fighting guardians; it defaults off. **Revive** shows progress for reviving a friend or being revived. Move it through **Layout** if the game's original bar covers it.
- A guardian tracker with health bars during combat. Plus shows only living guardians; minus shows all lairs and respawn timers. Move, resize or hide it through `/sdui` → **Layout**.
- Pet frames for up to eight active summons, with native names, icons and duration. Extra pets appear as a count. Move, resize or hide the whole **Pet frames** group through `/sdui` → **Layout**.
- A movable **Level Up!** button for stored levels. Select it in `/sdui` → **Layout** to move or resize it, then **Confirm** to save.
- Compact nameplates and custom damage numbers with size, color and damage filters.
- Retail-style loot popups for new drops, using WoW’s original font. Already-collected drops are hidden from both chat and popups. Move, resize or hide loot notifications through **Layout**.
- Transparent chat with shorter game messages and mouse-wheel history.
- Cache and guardian guides with distance, direction and world-map pins. Mirror each guide in `/sdui` → **HUD** to put its arrow on either side.
- Minimap loot-pouch icons for nearby caches and gold skull medallions for all living guardians. Empty or dead lairs show no icon, and Guardian guidance hides the red flag. Guardian icons mark their lairs, including while they are fighting elsewhere.

Player, target and target-of-target portraits use the original 2D images by default. **Experimental 3D portraits** in `/sdui` → **Unit frames** switches all three to 3D. **Hide portraits** shows all three as bars without portrait pictures or rings; turn it off to restore your portrait choices.

Supports all 14 game languages, including Czech.

## Other commands

- `/copy` opens chat messages and diagnostic text you can copy when reporting a problem.
- `/fstack` inspects the UI under your mouse. Run it again to close it.

## Help

[Report a problem](https://github.com/migwynkriid13/SurvivorsDragonUi/issues) with your game version, addon version and a screenshot or error message.

Some features need a recent game build. The latest compatibility and minimap changes still need in-game testing. See [compatibility notes](docs/CLIENT-COMPATIBILITY.md) or the [technical docs](docs/) for details.

## License and credits

See [LICENSE](LICENSE) and [third-party credits](third_party/). Game artwork has separate terms from addon code.
