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

- Drag a frame to move it. Drag its corners to resize it.
- Use **Layout** for positions and sizes, **HUD** for display options, **Combat text** for damage numbers, and **Run timer** for its text and font.
- Click **Confirm** to save, or **Cancel** to undo your changes. Leaving the run or reloading also discards unsaved changes.

**Addon defaults** or `/sdui reset` immediately resets your layout, display options, and timer font and text. Your combat-text mode stays unchanged.

To use the game's damage numbers, choose **Game settings** under **Combat text**, then enable **Show Target Damage** in the game options.

## Features

- Player and target frames, a seven-button action bar, equipped jewelry, XP, kills, gold and cache cost.
- A run timer with boss markers, plus boss and guardian health bars.
- Compact nameplates and custom damage numbers with size, color and hit filters.
- Transparent chat with shorter game messages and mouse-wheel history.
- Cache and guardian guides with distance, direction and world-map pins.
- Minimap loot-pouch icons for nearby caches and a gold skull medallion for the flagged guardian. Empty flagged lairs show no marker or flag. Guardian markers point to the lair, even while its guardian is fighting elsewhere.

The player portrait uses the original 2D image by default. You can try **Experimental 3D player portrait** in `/sdui` → **HUD**.

Supports all 14 game languages, including Czech.

## Other commands

- `/copy` opens chat messages and diagnostic text you can copy when reporting a problem.
- `/fstack` inspects the UI under your mouse. Run it again to close it.

## Help

[Report a problem](https://github.com/migwynkriid13/SurvivorsDragonUi/issues) with your game version, addon version and a screenshot or error message.

Some features need a recent game build. The latest compatibility and minimap changes still need in-game testing. See [compatibility notes](docs/CLIENT-COMPATIBILITY.md) or the [technical docs](docs/) for details.

## License and credits

See [LICENSE](LICENSE) and [third-party credits](third_party/). Game artwork has separate terms from addon code.
