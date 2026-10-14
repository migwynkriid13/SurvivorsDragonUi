# SurvivorsDragonUi

A fixed HUD for **Azeroth Survivors 0.87.0+**, using its official addon API. Install the addon alone; no companion process, client patch or special launcher is required.

## Install

1. Download `SurvivorsDragonUi.zip` from this repository's **Releases**.
2. On Windows or Linux, extract the ZIP. In the game, open **Options → AddOns** and click **Open AddOns Folder**, then place the extracted `SurvivorsDragonUi` folder inside it. You can also place that folder manually in `benilla-config/AddOns/` beside the game's executable.
3. The installed file should be at `benilla-config/AddOns/SurvivorsDragonUi/SurvivorsDragonUi.toc`.
4. In the browser version, use **Options → AddOns → install a .zip** instead.
5. Enable SurvivorsDragonUi and enter the world.

This targets Azeroth Survivors and its WoW 1.12.1 addon interface (`11200`). It is not a retail WoW addon. The native run HUD needs the game's 0.87.0+ API; unsupported clients retain their native run displays.

## HUD

- One action bar with seven buttons: native ability slots 1–6, followed by the permanent ability in native slot 12. No paging or gryphons.
- An XP bar below the abilities, matching the action bar's artwork width, without numbers or hover text.
- A gold bar directly below XP with three equal sections: kills, current gold and the next cache's gold cost. Each has a game icon and centered number.
- A blue run-progress pill using the native pause-aware clock, actual zone length and scheduled boss markers.
- Separate red health pills for every live boss and engaged guardian, keyed by spawn id.
- Player and target frames with one uninterrupted health bar and no resource bar.
- DEFAULT font, square minimap, one backpack, and Character/Talents/Main Menu buttons.
- Built-in nameplate scrolling combat text with damage icons and independent animations that continue after kills.
- A fixed chat window at the bottom left with fully transparent backgrounds, fading messages, slide animation, mouse-wheel history reveal, a passive scroll indicator and a matching native input. Hovering or opening, closing or focusing the input does not reveal history or pause fading. New messages display normally, and fading pauses while wheel-scrolled back for reading until you return to the bottom. Chat tabs, the Combat Log tab and the Copy button are hidden. Level, stat-gain, self-loot and class talent-progress notices use compact source-style formatting; learned abilities and skill increases show `+Name`; NPC yells show a red name and colon followed by the message; other messages keep their original text. `/copy` opens raw session diagnostics, including hidden announcements and combat/addon events. The archive runs continuously and resets on reload; see [chat port notes](docs/CLEANERCHAT-PORT.md) for native-history limits.

Appearance and placement are fixed. There are no addon settings, profiles, saved variables or frame movers.

Type `/copy` to open the Copy window, then press **Ctrl+C** to copy the selected diagnostics. Chat clicks and hyperlinks keep their native behavior.

## Combat-text commands

| Command | Behavior |
| --- | --- |
| `/sct on` | Custom icon-and-damage SCT; native outgoing damage text disabled. |
| `/sct off` | Both custom and native outgoing damage text disabled. |
| `/sct default` | Native outgoing damage text only. |

The normal **V** binding controls nameplates and custom SCT visibility. Mode changes clear custom text immediately. The selected mode lasts for the current UI session; reloading starts in custom mode. Combat logs and the damage meter are unaffected.

## Client limitations

- `/reload` rebuilds the client's Lua state. The addon reconnects its clock, counters and encounters independently as native data arrives, and uses the official `AZS_RUN.fin` duration when once-per-run zone data is absent. Full recovery while paused, including unchanged encounters and schedule markers, requires the client to replay its API snapshots. The addon cannot request that through the documented API.
- Nameplate collision stacking is controlled by the client. This build exposes no overlap switch to addons.
- The original 1.12 combat log identifies enemies by name rather than destination GUID. Same-name hits can have ambiguous positions; the addon shows those hits at a shared or fallback position.

The official API reference is included in [docs/AzerothSurvivors-Addon-API.md](docs/AzerothSurvivors-Addon-API.md).

## Automated releases

Each new commit pushed to `main` builds `SurvivorsDragonUi.zip` and gets a GitHub release tagged with its commit SHA, including when several commits are pushed together. The ZIP contains the installable `SurvivorsDragonUi/` folder. Re-running a release replaces its ZIP without creating another release for the same commit.

Packaging and publishing do not run the addon, launch the game, or perform addon validation. A published release is a packaged snapshot, not proof of in-game validation.

To package locally with Python 3:

```sh
python3 scripts/package.py dist/SurvivorsDragonUi.zip
```

## License

License terms are included in [LICENSE](LICENSE), with attribution and artwork notices in [third_party](third_party). Code permission and custom-texture restrictions are separate; this repository does not relicense third-party artwork.
