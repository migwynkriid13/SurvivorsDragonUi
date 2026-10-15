# SurvivorsDragonUi

A custom HUD for **Azeroth Survivors 0.87.0+**, using its official addon API. Install the addon alone; no companion process, client patch or special launcher is required.

See [Commands](#commands) for every addon command, including layout editing, reset, chat copying and combat-text modes.

## Install

1. Download `SurvivorsDragonUi.zip` from this repository's **Releases**.
2. On Windows or Linux, extract the ZIP. In the game, open **Options → AddOns** and click **Open AddOns Folder**, then place the extracted `SurvivorsDragonUi` folder inside it. You can also place that folder manually in `benilla-config/AddOns/` beside the game's executable.
3. The installed file should be at `benilla-config/AddOns/SurvivorsDragonUi/SurvivorsDragonUi.toc`.
4. In the browser version, use **Options → AddOns → install a .zip** instead.
5. Enable SurvivorsDragonUi and enter the world.

This targets Azeroth Survivors and its WoW 1.12.1 addon interface (`11200`). It is not a retail WoW addon. The native run HUD needs the game's 0.87.0+ API; unsupported clients retain their native run displays.

## HUD

- One action bar with seven buttons: native ability slots 1–6, followed by the permanent ability in native slot 12. No paging or gryphons.
- An XP bar whose default placement is below the abilities, matching the action bar's default artwork width, without numbers or hover text.
- A gold bar whose default placement is directly below XP with three equal sections: kills, current gold and the next cache's gold cost. Kills use the enemy-hover sword cursor icon, current gold uses custom gold-coin artwork, and the cache cost uses the native loot-pouch cursor icon. Each section has a centered number.
- A blue run-progress pill with `RUN 05:42 / 16:00` centered above it using the client's Morpheus font when available. The timer group defaults eight pixels higher on the screen. It reads the native pause-aware clock and actual zone length, with skull icons marking upcoming boss spawns. Each skull disappears when the native clock reaches its scheduled spawn time.
- Separate red health pills for every live boss and engaged guardian, keyed by spawn id.
- Player and target frames with one uninterrupted health bar and no resource bar.
- DEFAULT font throughout the UI except the run timer, square minimap, one backpack, and Character/Talents/Main Menu buttons.
- Cast-bar and quest-watch displays are removed.
- Built-in scrolling combat text with damage icons and independent animations that continue after kills, including with nameplates hidden.
- Chat defaults to the bottom left with fully transparent backgrounds, fading messages, slide animation, mouse-wheel history reveal, a passive scroll indicator and a matching native input. Hovering or opening, closing or focusing the input does not reveal history or pause fading. New messages display normally, and fading pauses while wheel-scrolled back for reading until you return to the bottom. Chat tabs, the Combat Log tab and the Copy button are hidden. Level, stat-gain, self-loot and class talent-progress notices use compact source-style formatting; learned abilities and skill increases show `+Name`; NPC yells show a red name and colon followed by the message; other messages keep their original text. `/copy` opens raw session diagnostics, including hidden announcements and combat/addon events. The archive runs continuously and resets on reload; see [chat port notes](docs/CLEANERCHAT-PORT.md) for native-history limits.

Type **`/sdui`** to edit the layout, then **left-drag a frame's body** to move the player frame, target frame, boss/guardian health-bar group, run timer, action bar, XP bar, kills/gold/cache bar, micro menu, player buffs, minimap or chat. **Left-drag a corner icon** to resize that group. Each group moves and resizes independently: changing the action bar does not change XP or the tally. Editing shows outlines and corner icons, including for currently hidden HUD groups, without showing inactive targets or encounters. The main menu and Copy window support the same controls while open. Click the single **Confirm** button in the center of the screen to save all pending changes and lock the frames again. Using `/sdui` again while editing keeps it open. Moving or resizing chat does not uncover faded messages; only the mouse wheel does that, and it still works during layout editing.

HUD groups resize by uniform scale, keeping their artwork proportions. Chat and Copy resize their actual width and height so text wraps and the viewport adjusts; their fonts keep their normal size. The action bar, XP and tally match at their default sizes, but can differ when resized independently.

While `/sdui` is open, the **Run timer font** controls preview the top `RUN` label's font, size, outline and shadow. Choose the game's `DEFAULT` face or its native Friz Quadrata, Arial Narrow, Morpheus and Skurri faces; no font download is needed. **Addon defaults** restores the addon's initial timer settings: Morpheus, size 14, outline and black shadow at offset `(1, -1)`, with DEFAULT as the fallback when a native font is unavailable. Other UI keeps DEFAULT.

Only **Confirm** saves pending geometry and timer font changes; releasing a drag or changing a font control does not save. Confirmed locations, HUD scale and chat/Copy dimensions persist across `/reload` and game sessions in `SurvivorsDragonUiLayout`; the confirmed timer font is stored separately in `SurvivorsDragonUiRunFont`. Unconfirmed edits are discarded on world leave, logout or `/reload`, preserving the last confirmed layout and timer font. `/sdui reset` clears saved geometry and timer font choices, exits editing and restores every registered frame's default position and size, including hidden frames, plus the initial timer font. Defaults stay defined in code; font controls appear only during layout editing, without profiles or a separate settings window. The selected SCT mode is saved separately in `SurvivorsDragonUiSctMode`; `/sdui reset` leaves it unchanged. Chat diagnostics remain session-only, and gameplay/native API state is never stored with the layout.

## Commands

All addon commands are listed below. Layout editing does not require holding SHIFT.

| Command        | Behavior                                                                                                                                                        |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/sdui`        | Edit frame positions, sizes and the run timer font. Click the centered **Confirm** button to save all changes and lock the frames. |
| `/sdui reset`  | Exit editing, clear saved geometry and timer font choices, and restore defaults, including hidden frames. |
| `/copy`        | Open a snapshot of raw chat messages and events, including hidden messages; press **Ctrl+C** to copy the selected text.                                         |
| `/sct`         | Show the available combat-text modes and the currently selected mode.                                                                                           |
| `/sct on`      | Custom icon-and-damage SCT; native outgoing damage text disabled.                                                                                               |
| `/sct off`     | Both custom and native outgoing damage text disabled.                                                                                                           |
| `/sct default` | Native outgoing damage text only.                                                                                                                               |

The normal **V** binding controls whether native nameplates are visible; `/sct` controls custom combat text independently. In `/sct on` mode, invisible native plates continue tracking enemies when V is off, so matched hits can follow them. Your V preference stays unchanged. Visible, invisible or recently retired plate positions are matched using names and health changes; unmatched or ambiguous hits appear at a shared fallback position. Mode changes clear active and queued custom hits immediately. The selected `on`, `off` or `default` mode is saved across runs, `/reload` and game sessions. New installations and missing or invalid saved values start in custom `on` mode. Combat logs and the damage meter are unaffected. Chat clicks and hyperlinks keep their native behavior.

## Client limitations

- `/reload` rebuilds the client's Lua state. The addon reconnects its clock, counters and encounters independently as native data arrives, and uses the official `AZS_RUN.fin` duration when once-per-run zone data is absent. Full recovery while paused, including unchanged encounters and schedule markers, requires the client to replay its API snapshots. The addon cannot request that through the documented API.
- Nameplate collision stacking is controlled by the client. This build exposes no overlap switch to addons.
- Custom SCT uses native plate coordinates, including the client's collision displacement. With custom SCT on and V off, keeping invisible tracking active can also leave native overhead enemy names suppressed. The tracking integration has not been verified in the packaged game; see [API notes](docs/API-NOTES.md).
- The original 1.12 combat log identifies enemies by name rather than destination GUID. Same-name hits can have ambiguous positions; the addon shows those hits at a shared or fallback position.

The official API reference is included in [docs/AzerothSurvivors-Addon-API.md](docs/AzerothSurvivors-Addon-API.md).

## Automated releases

Each push to `main` that changes the installable payload builds one `SurvivorsDragonUi.zip` from that push's final commit. The payload is listed in `packaging/runtime-files.json`: the TOC, its loaded Lua files and the textures used at runtime. The ZIP contains only those files inside the installable `SurvivorsDragonUi/` folder. Repository documentation, tooling, workflows, unused source/artwork and standalone license/attribution files stay on GitHub. Required third-party license text remains in the packaged Lua source comments.

Release eligibility uses the same manifest as packaging, including removed files and changes to payload membership. PRs that change the shipped ZIP payload must increase the TOC version. Documentation/tooling-only PRs leave the version unchanged and do not publish a release. Files outside the payload and manifest formatting alone do not trigger packaging; publication is skipped when no packaged content changed.

Releases use the final commit's SHA as their tag. Re-running the same build replaces its ZIP without creating another release. Publication is serialized, and an older rerun cannot replace a newer Latest release. The stable [latest ZIP download](https://github.com/migwynkriid13/SurvivorsDragonUi/releases/latest/download/SurvivorsDragonUi.zip) points to the newest published build. A manual workflow run on `main` can also package the current commit.

Packaging and publishing do not run the addon, launch the game, or perform addon validation. A published release is a packaged snapshot, not proof of in-game validation.

To package locally with Python 3:

```sh
python3 scripts/package.py dist/SurvivorsDragonUi.zip
```

## Pull request checks

PRs that change the shipped ZIP payload must set `## Version` in `SurvivorsDragonUi.toc` strictly higher than the latest target `main` version, keeping the `major.minor.patch-survivors` format and `-survivors` suffix. Default to one patch increment, for example `3.2.2-survivors` to `3.2.3-survivors`. Bump once per qualifying PR, not on every commit or push. If another merge brings `main` to the same or a higher version, update the PR version before merging. Documentation/tooling-only PRs leave the version unchanged. PR-introduced payload impact uses the shared release comparison of the PR merge-base and PR-head `packaging/runtime-files.json` manifests, including removals and membership changes.

An automated metadata guard uses that shared payload comparison and requires a version increase when shipped content changes, comparing the pinned PR head with the target branch's current version when CI runs. The protected `main` branch requires the GitHub Actions check **Formatting and local dead code** to pass and the PR branch to be up to date before merging, including for administrators. Preserve this protection unless the user explicitly authorizes changing it. CI never bumps or commits the version automatically.

Every push to a pull request runs all source-quality checks across the complete tracked codebase. Prettier checks owned Markdown, JSON and YAML; StyLua checks all Lua formatting; Luacheck reports unused local variables and assignments, unreachable code and single-iteration loops. These checks never load the addon or start the game.

The version guard and all three source-quality checks finish before CI enforces the result. One combined job summary and downloadable artifact contain the version result, every tool's findings and suggested formatting patches; CI does not commit changes automatically. The supplied API reference and upstream WidgetStatusBar attribution stay verbatim. Lua formatting uses the nearest supported grammar, Lua 5.1; it does not establish 1.12 runtime compatibility. Dead-code analysis excludes dynamic WoW/DFRL globals and unused callback arguments, and cannot prove that globally registered callbacks or assets are unused.

## License

License terms are included in [LICENSE](LICENSE), with attribution and artwork notices in [third_party](third_party). Code permission and custom-texture restrictions are separate; this repository does not relicense third-party artwork.
