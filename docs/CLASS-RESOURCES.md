# Class resources

The **Class resources** checkbox in the `/sdui` **HUD** tab defaults off. The player frame normally has one uninterrupted health bar. Enabling the option integrates the current native active resource below health inside the original frame opening, with the game's class-proc meter attached below the frame when available. Target and target-of-target frames remain health-only.

Rogue points and Warlock soul shards use the existing socket artwork. Bloodrage and Lightwell use a compact red or gold fill with current / maximum text. All four use the official proc values; none are inferred from active power, spell casts or combat messages.

## Current native values

The primary bar reads `UnitPowerType("player")`, `UnitMana("player")` and `UnitManaMax("player")` independently of AZS phase and retained run snapshots. It requires an existing player, finite nonnegative current power and power type, and a finite positive native maximum. The primary bar uses that maximum directly, without inventing a pool or maximum for a class. Missing proc data does not hide valid primary power; missing primary power does not hide a valid proc meter.

The game update supplied by the owner on 2026-10-20 adds three `AZS_RUN` fields:

| Field  | Meaning                                                                         |
| ------ | ------------------------------------------------------------------------------- |
| `proc` | `bloodrage`, `seal_fate`, `soul_fire`, `lightwell`, or an empty string for none |
| `pv`   | Current meter value                                                             |
| `pm`   | Full meter value                                                                |

The proc reader checks the native phase before reading the received run table and requires a finite nonnegative `AZS_RUN_UPDATED`. It shares the existing active-phase definition: `playing`, `choosing`, `paused` and `victory`. The value must be finite and nonnegative, and the maximum finite and positive. A value above its maximum is clamped for display without changing the native table. Empty, unknown, missing or invalid proc data hides only the secondary display. Older builds without these fields retain their primary power bar but show no inferred proc meter.

For `seal_fate` and `soul_fire`, a whole-number native maximum up to five selects that many sockets; complete points light directly from `pv`. The supplied example `proc=seal_fate, pv=3, pm=5` shows three filled points and two empty sockets. Zero retains the available empty sockets. Larger or nonintegral ranges use the numeric fill meter, preserving the game's range instead of imposing a five-point maximum. Bloodrage and Lightwell always use that fill meter. No retail typed `UnitPower` calls, target-dependent combo getter or divide-by-20 conversion supplies a proc value.

Player power, maximum-power and display-power events trigger primary reads. The independent controller polls every 0.1 seconds even while the display is hidden, covering delayed native player initialization and snapshot recovery. `AZSRUN` schedules a read on the next frame, after native parsing. There is no independent resource timer, spell-name matching, native-state mutation or gameplay persistence.

Observed inactive phases and world leave/logout retire the current run-table reference; a later active phase needs a newly received table before the proc meter returns. Paused and choosing snapshots remain valid without a timeout. The API has no run id, so unobserved run boundaries remain a best-effort limitation. Turning the option off hides both displays, and world leave/logout also clears point textures and meter text. Primary power retains its separate native-unit lifecycle.

## Historical native game-code verification — 2026-10-16

The supplied Windows executable reports **v0.94.2 (cb46a4f8)**. Its SHA-256 is `69caa6d39e1db92477227d461dc72cffbb90fd3fa2c679b906e0c2310d22d841`. Static inspection of that executable's native machine code confirms the conversion independently of the earlier reported mechanic. No executable, game assets or disassembly are included in this addon.

The native resource-publication path reads the rogue combo counter and multiplies it by 20 at relative virtual address `0x05457B7B`, selecting update field `0x1A` (`UNIT_FIELD_POWER4`, energy). The corresponding warlock path reads the shard counter and multiplies it by 20 at `0x05457BCB`, selecting field `0x17` (`UNIT_FIELD_POWER1`, mana). Each multiplication is a shift left by two followed by multiplication by five. Both paths publish the resulting value through the same native field-update path. The counter handlers cap accumulation at five and reset the counters when their respective finisher triggers.

The native class records select energy type `3` for rogue and mana type `0` for warlock. The player initializer sets the corresponding maximum-power fields to 100. Consequently, the addon's former inverse conversion, `floor(min(currentPower, maximumPower, 100) / 20)`, matched this build's published values: 0, 20, 40, 60, 80 and 100 represented zero through five points or shards. `UnitMana` is the 1.12 name for the active power getter; rogue energy is read through that function too. This historical encoding is retained as evidence, but no longer drives the secondary display.

This establishes the native encoding in the identified executable. It does not establish startup event ordering, that every transient five-point value remains visible before consumption, or resource rendering and reload behavior in a running addon. Other game builds need their own evidence if the native encoding changes.

## Display preference

The **Class resources** checkbox appears in the `/sdui` **HUD** tab alongside boss debuffs and independent Cache/Guardian guidance. It defaults **off**. Turning it off hides player and party power bars, hides attached player point artwork and restores full-height health without changing confirmed geometry or the selected SCT mode. Changes preview live; **Confirm** alone saves the choice. World leave, logout and `/reload` discard unconfirmed changes and restore the last confirmed value.

The choice remains the normalized `classResources` boolean in `SurvivorsDragonUiDisplay`. Missing or invalid values use `false`; confirmed existing choices remain in use. Both `/sdui reset` and **Addon defaults** restore class resources off through the shared full reset. The confirmed SCT mode and native incoming/self text choice remain unchanged after their editing drafts are discarded.

## Layout

Health, primary power and secondary points belong to the player frame and follow its confirmed position and uniform scale. The existing 122-by-29 bar opening becomes a 19-pixel health fill above a 9-pixel resource fill at `(104, -54)` when enabled with valid native data; the original divider artwork separates the fills. Off or unavailable data restores the 29-pixel health fill. The primary bar shows current power against the native maximum range.

The secondary display is parented to PlayerFrame at `(105, -68)` in the existing 120-by-32 row. It retains the original purple shard and red combo-point pixels. The numeric meter is 120 by 12, centered within that same row, and reuses the bundled primary-power fill with a native black background and white DEFAULT 10 outlined text. It has no independent layout group, edit handles or saved geometry. Confirm/discard/reset apply through the existing player layout and shared display preference flow. No extra commands, artwork files, captions, resource SavedVariables or gameplay persistence are introduced.

The four native party frames follow the same display choice. Their native power
bars and optional power text use the shared alpha mask, preserving native
Show/Hide, latest alpha, values and updates while hidden. Off expands health
from 11 units at center Y 10 to 17.5 units at Y 6.75, retaining the top edge and
covering the former resource opening. Its fill extends 12 units beneath the
portrait's lower curve, retaining the original right edge and health-value
position. A passive border/portrait layer stays above the fill. A shared crop of the existing 128-by-64
pet-frame border removes only its internal divider, retaining the portrait
ring and outer border; target-of-target reuses that same crop. On restores the
original party split and complete artwork without forcing a native power bar
visible. Party unit buttons, portraits, names, tooltips, values, outer size,
placement and scale are unchanged. The existing hint describes both player and
party frames in all fourteen source/runtime catalogs. Pet-frame power remains
independent.

## Referenced addon research

All four requested repositories were inspected. These are the pinned snapshots consulted, rather than dependencies of the installed addon.

| Repository                                                                                                                                          | Snapshot                                   | Relevant result                                                                                                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| [NeticSoul/DragonUI](https://github.com/NeticSoul/DragonUI/tree/23b36a57acf4cbdf0a01fea600eef97ae9983109)                                           | `23b36a57acf4cbdf0a01fea600eef97ae9983109` | Large retail/Forever combo atlases and a later-client implementation. No dedicated shard atlas found.                                        |
| [Karl-HeinzSchneider/WoW-DragonflightUI](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/tree/b8b35451d4621a8097e887385f72ec03e17765f1)   | `b8b35451d4621a8097e887385f72ec03e17765f1` | Selected compact red-orb combo atlas and its documented UVs. Shards use a native later-client `ShardBarFrame` rather than bundled shard art. |
| [Stormhand-dev/DragonflightUI-Reforged](https://github.com/Stormhand-dev/DragonflightUI-Reforged/tree/2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8)     | `2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8` | No dedicated combo/shard art or corresponding module found. No material imported.                                                            |
| [DarckRovert/ProjectJaina_DragonflightUI](https://github.com/DarckRovert/ProjectJaina_DragonflightUI/tree/d11727768f15168478b524a376f30752940a924d) | `d11727768f15168478b524a376f30752940a924d` | Ordinary unit-frame/resource-bar art; no dedicated combo/shard display found. No material imported.                                          |

The selected combo atlas is converted from its original raw BGRA BLP2 to uncompressed 32-bit TGA without changing pixels. The original purple-shard atlas is obtained separately from the Blizzard texture archive because the referenced addons do not bundle it, and likewise converted losslessly from RGBA PNG to TGA. Both render through ordinary `SetTexture` and `SetTexCoord`. No Ace framework, modern class frame, mixin, animation group or `SetAtlas` API is imported. Source links, atlas rectangles and notices are in [the artwork notice](../third_party/ClassResources-NOTICE.md) and the shipped Lua comments.

## Verification boundary

The historical native conversion was verified by static inspection of the identified executable. During that earlier investigation the game was opened only to its character-selection menu to identify the version; no run was started and no addon interaction was exercised. The proc fields come from the owner's 2026-10-20 update notice, without a new executable inspection or live capture. No local addon tests, syntax checks, formatting tools, addon execution or game startup were run for the proc integration. The existing PR workflow runs its authorized formatting, local dead-code and TOC metadata checks in GitHub Actions. Those checks do not establish packaged-game rendering, native event ordering, resource transitions, reload recovery or layout interaction. Those runtime behaviors remain unverified.
