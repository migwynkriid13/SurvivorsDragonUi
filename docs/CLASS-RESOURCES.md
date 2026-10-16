# Class resources

The **Class resources** checkbox in the `/sdui` **HUD** tab defaults off. The player frame normally has one uninterrupted health bar. Enabling the option integrates the current native active resource below health inside the original frame opening, with attached secondary point artwork where supported. Target and target-of-target frames remain health-only.

Warlock soul shards and Rogue points retain five sockets with one filled socket per complete 20 native active-power units, capped at five. For example, 19 units lights no slots, 20 lights one, 59 lights two and 100 lights five. Partial units do not light another slot. This conversion matches the native power publication in the inspected Survivors v0.94.2 Windows build; it is not ordinary WoW mana, energy or inventory soul shards. The exact evidence is preserved below.

## Current native values

The module reads the current native `UnitClass("player")`, `UnitPowerType("player")`, `UnitMana("player")` and `UnitManaMax("player")` independently of AZS phase and retained run snapshots. It requires an existing player, finite nonnegative current power and power type, and a finite positive native maximum. The primary bar uses that maximum directly, without inventing a pool or maximum for a class. Turning the option off, unavailable current data and world leave/logout hide power and secondary points and restore full-height health.

In the [base client's native bindings](https://github.com/samwhosung/benilla/blob/129b3bb852b2f328de529f3c698595c14baf5fa5/crates/benilla-ui/src/script/unit/bindings.rs), `UnitMana` and `UnitManaMax` read the current power type, including energy. The supplied Survivors build publishes Warlock shards through mana type `0` and Rogue points through energy type `3`; the point visualization clamps active power to its native maximum and 100, divides by 20 and rounds down rather than normalizing by maximum power. Five empty sockets remain visible at zero when the matching point display is available.

The base client's target-dependent `GetComboPoints()` reads a separate native combo state. Additional class point displays can use a valid native reading where available, without treating a full generic active-resource bar as proof of extra points. The supplied official Survivors API has no general independent third-resource getter; the active-power display and attached artwork do not claim separate simultaneous mana/shard or energy/point pools. Typed retail `UnitPower` APIs, invented counters and class-specific maxima are not used.

Player power, maximum-power, display-power and target/combo events trigger current reads. An independent controller polls every 0.1 seconds even while the display is hidden, covering delayed native player initialization. There is no independent resource timer, spell-name matching, native-state mutation or gameplay persistence.

## Native game-code verification — 2026-10-16

The supplied Windows executable reports **v0.94.2 (cb46a4f8)**. Its SHA-256 is `69caa6d39e1db92477227d461dc72cffbb90fd3fa2c679b906e0c2310d22d841`. Static inspection of that executable's native machine code confirms the conversion independently of the earlier reported mechanic. No executable, game assets or disassembly are included in this addon.

The native resource-publication path reads the rogue combo counter and multiplies it by 20 at relative virtual address `0x05457B7B`, selecting update field `0x1A` (`UNIT_FIELD_POWER4`, energy). The corresponding warlock path reads the shard counter and multiplies it by 20 at `0x05457BCB`, selecting field `0x17` (`UNIT_FIELD_POWER1`, mana). Each multiplication is a shift left by two followed by multiplication by five. Both paths publish the resulting value through the same native field-update path. The counter handlers cap accumulation at five and reset the counters when their respective finisher triggers.

The native class records select energy type `3` for rogue and mana type `0` for warlock. The player initializer sets the corresponding maximum-power fields to 100. Consequently, the addon's inverse conversion, `floor(min(currentPower, maximumPower, 100) / 20)`, matches this build's published values: 0, 20, 40, 60, 80 and 100 represent zero through five points or shards. `UnitMana` is the 1.12 name for the active power getter; rogue energy is read through that function too. No attack counting, resource timer or maximum-power percentage is needed.

This establishes the native encoding in the identified executable. It does not establish startup event ordering, that every transient five-point value remains visible before consumption, or resource rendering and reload behavior in a running addon. Other game builds need their own evidence if the native encoding changes.

## Display preference

The **Class resources** checkbox appears in the `/sdui` **HUD** tab alongside boss debuffs and independent Cache/Guardian guidance. It defaults **off**. Turning it off hides power and attached point artwork and restores full-height health without changing the player's confirmed geometry or the selected SCT mode. Changes preview live; **Confirm** alone saves the choice. World leave, logout and `/reload` discard unconfirmed changes and restore the last confirmed value.

The choice remains one of five normalized booleans in `SurvivorsDragonUiDisplay`: `classResources`, `bossDebuffs`, `damageIcons`, `cacheGuidance` and `guardianGuidance`. Missing or invalid `classResources` values use `false`; confirmed existing boolean choices remain in use. Both `/sdui reset` and **Addon defaults** use the shared full reset to restore class resources off, boss debuffs on, damage icons off and both guides on, together with layout and timer defaults. The confirmed SCT mode and native incoming/self text choice remain unchanged after their editing drafts are discarded.

## Layout

Health, primary power and secondary points belong to the player frame and follow its confirmed position and uniform scale. The existing 122-by-29 bar opening becomes a 19-pixel health fill above a 9-pixel resource fill at `(104, -54)` when enabled with valid native data; the original divider artwork separates the fills. Off or unavailable data restores the 29-pixel health fill. The primary bar shows current power against the native maximum range.

Secondary artwork is parented to PlayerFrame at `(105, -68)` and retains the original purple shard and red combo-point pixels. It has no independent layout group, edit handles or saved geometry. Confirm/discard/reset apply through the existing player layout and shared display preference flow. No extra commands, profiles, resource SavedVariables or gameplay persistence are introduced.

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

The native conversion was verified by static inspection of the supplied executable. The game was opened only to its character-selection menu to identify the version; no run was started and no addon interaction was exercised. No local addon tests, syntax checks or formatting tools were run. The existing PR workflow runs its authorized formatting, local dead-code and TOC metadata checks in GitHub Actions. Those checks do not establish packaged-game rendering, native event ordering, resource transitions, reload recovery or layout interaction. Those runtime behaviors remain unverified.
