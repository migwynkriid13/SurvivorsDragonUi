# Official addon API integration — 2026-10-14

## Heroic affixes and totems — 0.125.0, 2026-10-28

The [supplied 0.125.0 reference](AzerothSurvivors-Addon-API-0.125.0-2026-10-28.txt)
is preserved verbatim. Its evidence paths and reproduction commands refer to
the source reconstruction checkout described in that text. This addon change
uses the supplied contract; it does not repeat that investigation or its tests.

`AZSZONE` supplies `AZS_ZONE.heroic` and the new `AZS_ZONE.affixes`. Affixes are one
comma-separated string of English keys, such as `sanguine,explosive`, in native
order regardless of UI language. Empty means no affixes in the received
snapshot; nil means unavailable. Display labels can be localized separately;
unknown keys must remain acceptable. There is no affix getter or live mechanic
timer. This change documents the fields without adding an affix display.

`AZSTOTEMS` publishes `AZS_TOTEMS` and its `AZS_TOTEMS_UPDATED` receipt stamp.
`AZS_GetTotems([key])` returns fresh rows grouped by exact ability key, with
localized name, native icon, spell ID, count, cap, duration and the next expiry
as `remaining`. `AZS_GetTotemCount([key])` sums counts; table length counts
kinds. Keys currently include `searing_totem` and `magma_totem`, but SDUI accepts
any valid published key and does not hardcode their cap, icon or duration.

The [Pet frames group](PET-FRAMES.md#totems--01250) uses those rows alongside
the separate summon feed. Its optional countdown waits for a valid native
`AZS_GetRunTime()`, follows native pauses, and never decrements a published
count on local expiry. The deadline describes the next existing totem to
expire, not the next summon. No individual totem IDs, health, positions, pulse
times or combat ownership are supplied. Local work is source review and pinned
formatting; CI-only controller scenarios are authored but not run locally.

## Party meter — 2026-10-27

Static reading of the installed 146,088,960-byte client, SHA-256
`22f7938eb4f99f2857dc091b1c57c147bd848eaabfeaa81e444c0a3393ca8150`,
confirms `AZS_GetPartyMeter()` returns `AZS_MeterTotals(AZS_PARTY)`.
The embedded API describes one hero per row, most damage first:
`name`, class key `class`, `dmg`, `dps`, `share`, `top` and `topdps`.
`AZS_MeterTotals` sums the supplied damage and DPS fields without inventing a
clock. The `AZSPARTY` parser publishes exactly those seven fields and stamps
`AZS_PARTY_UPDATED`; the getter is documented as empty outside a party.

SDUI adds this as the fourth meter view after Boss Damage. Hero portraits use
the native `SetPortraitTexture` unit path after a unique current player/party
name match; the meter's party API itself supplies no portrait path or unit ID.
The native frame portrait image invalidates a cached binding when it changes.
Unmatched/ambiguous identities stay neutral. Existing official reference copies
are preserved verbatim; source inspection does not establish live co-op behavior.
See [DAMAGE-METER.md](DAMAGE-METER.md#party-data-and-portraits).

## Supplied summon API reference — 2026-10-22

The [latest supplied API reference](AzerothSurvivors-Addon-API-2026-10-22.txt)
is preserved verbatim alongside the earlier Markdown and 2026-10-15 copies.
The date records receipt; the supplied text does not identify a game version.
It documents `AZS_GetSummons`, `AZS_GetSummonCount`, `AZS_GetSummonGroups`,
`AZS_PETS` and the `AZSPETS` update prefix for every class and spec.

The [summon API assessment](SUMMONS-API.md) explains the new counts, native
icons and run-clock lifetimes, their limits, and the effect on our current pet
frame and SCT filter. The [pet-frame group](PET-FRAMES.md) uses this roster
for grouped names, counts, native icons and optional lifetimes. The API does not identify the
source of unattributed SELF combat messages, including the reported Imp
Fireball. No existing API removal is stated in the supplied reference.

## Endless boss countdown — 2026-10-21

After the native phase check, a received `AZS_RUN.endl == 1` switches the run
caption to elapsed time above the pill's left edge and **Boss in: M:SS** above
its right edge. Final-boss death (`won`) and passing the zone duration do not
activate this layout. Outside Endless, the existing centered caption returns.

The countdown reads only finite nonnegative `AZS_RUN.nb`, rounded up to the next
whole second. Minutes have no leading zero: `5:00`, `4:59`, through `0:00`.
Missing, invalid or negative data hides and clears only the boss caption. No
deadline is reconstructed from the zone schedule, final-boss kill time, repeat
boss deaths or a fixed 300-second interval. Pauses, repeat spawns and overlapping
bosses follow the native countdown snapshots; no gameplay clock is added.

Both captions reuse the pooled seconds renderer and the existing font, outline,
shadow and text-visibility controls. Each translated prefix resolves its own
DEFAULT fallback for non-ASCII text. Measured captions can extend equally past
the pill's edges when needed to retain an eight-unit gap at large font sizes;
the shared edit bounds include this overflow and the raised seconds. The pill
and confirmed geometry are unchanged. Clock release clears the boss caption and
restores the centered anchor. The caption is present in all fourteen source and
runtime UI catalogs. No setting, asset or SavedVariable was added.

The reported 0.108.0 startup error came from clearing the new boss FontString
before assigning any font. It now receives the resolved DEFAULT face immediately
after creation, before its first `SetText`, matching the existing pill caption.
The shared font preview still applies the selected face, size, outline and shadow.

The API fields are documented in [the supplied reference](AzerothSurvivors-Addon-API.md#azs_run-the-run-right-now).
The supplied static analysis of the installed 0.107.0 client places the first
Endless deadline five run-clock minutes after Continue Endless and resets it
after each actual spawn. That evidence explains why the addon uses the native
remaining time rather than the zone ending or a kill-based cadence. No local
tests, syntax/formatting checks or addon/game execution were run; GitHub Actions
provides the authorized static checks. Live rendering remains unverified.

## Native 0.108.0 UI compatibility — 2026-10-21

Read-only inspection of the installed executable's embedded Lua found the new
native bar using `ActionButton1`–`ActionButton6` and `ActionButton12`. Buttons
7–11 are retained under hidden `AZS_HiddenBar`. The addon already reparents
button 7 into its own visible bar, maps it to slot 12 and refreshes its native
action state. Its existing texture suppression covers `AZS_RacialRim` on
`MainMenuBarArtFrame`; its XP replacement hides `MainMenuExpBar`, which also owns
the new always-visible native XP text. No action-bar geometry or preferences
were changed for this update.

The same embedded API adds `AZS_RegisterBannerHandler` and
`AZS_UnregisterBannerHandler`, delivering banner tables with `id`, `kind`, `boss`,
`name`, `text` and receipt `time` even when native banners are hidden.
`AZS_BANNERS` retains the newest 20 entries. The later replacement in
[RUN-BANNERS.md](RUN-BANNERS.md) consumes future callbacks and also redirects the
separate legacy `RaidBossEmoteFrame` display path. Its independent **Banners**
Layout group leaves the timer bounds and original default boss position intact.

Source fingerprint: installed `AzerothSurvivors.exe`, SHA-256
`dc0040043fff7995a9137d96509c08debd1dbf8b0125a935273d718c66cb698b`.
The bar setup is embedded near file offset `0x71f90b6`, and banner registration
near `0x71ecee5`. This is source inspection only. No local checks or addon/game
execution were run; live 0.108.0 rendering remains unverified.

## Run-timer seconds alignment — 2026-10-20

The user reported the seconds appearing one pixel below the minutes and requested
a fixed upward correction for all seconds values. The live run label and its font
preview now share a segmented renderer: minutes and colons keep their existing
baseline, while both elapsed and duration seconds are raised by one physical
pixel. The correction is uniform for 00–59, without digit-specific rules or font
substitution. This does not establish the original renderer/font cause.

The full translated caption stays in a hidden native FontString for its original
centred bounds. A second hidden FontString measures prefixes, preserving kerning
at segment boundaries. Pooled visible parts use the same native font resolution,
size, outline, shadow and text visibility. Text/font/effective-scale changes
refresh their anchors, and shared resize handling updates the live label and edit
bounds. Unused duration parts clear and hide when the run reaches its limit. Run
values, `MM:SS` formatting, tooltip clocks, clock takeover, preferences and saved
geometry remain unchanged. No new setting, font, asset or SavedVariable is added.
No local checks or addon/game execution were run; packaged-game rendering remains
unverified.

## Pointed player health-bar seam — 2026-10-19

The user reported a slight gap beside the non-circular player portrait and requested a two-unit extension to the left. The shared overlap helper now uses a two-unit underlap for the pointed player frame: health width/inset become 124/102 instead of 122/104, keeping the far edge at 226. The health background, damage-loss segment and optional resource row/divider follow the same span. The existing label compensation keeps health/resource values and the name in place; name width excludes the overlap so its original text area remains unchanged.

The circular player's existing 15-unit overlap (137/89), circular divider cleanup and target geometry remain unchanged. This supersedes earlier notes that disabling Round player portrait restores the original 122/104 opening. No setting, asset or SavedVariable is added. No local checks or addon/game execution were run; the correction remains unverified in-game.

## Blue timer leading-edge foam — 2026-10-25

The user requested a stronger waterfall-like froth where the blue run-progress fill ends, softening its abrupt cutoff. The existing cosmetic fill controller pools a broad blue glow, a pale blue-white crest, two independently moving shoulders and twelve flecks using the native casting-bar spark texture. The main crest is eight units wide over a seventeen-unit glow; staggered flecks swell, fade and drift seven to fourteen-and-a-half units back into the water. Glow, crests and flecks use a 1.4 opacity multiplier, clamped to `0..1` so the client's byte-alpha conversion cannot wrap bright peaks. The cosmetic foam can feather up to six UI units beyond the native fill edge, with its quads and UVs still clipped to the pill's width and bar height beneath the metal border and boss markers. Native progress and the filled width are unchanged.

Animation shares the existing 30 Hz UI-time update and continues while paused without advancing the native run clock. The shared cleanup hides foam at zero progress and clock release, including world leave/logout. Switching to the red time-limit appearance hides it immediately; the existing red glow and stationary sparkles retain their behavior. A return to blue or a new run reacquires the edge from current native data. All pieces are created once, with no new OnUpdate, asset, setting or SavedVariable. No local checks, fixed-sample previews or addon/game execution were run; live appearance and performance remain unverified.

## Round portrait divider remnant — 2026-10-19

The user identified a short horizontal line inside the health fill just to the right of the circular portrait, above the intended gray lower border. The circular sheet still contains the original health/resource divider in source columns 152–153 at rows 52–54. The portrait crop includes those columns even though the shared bar interior omits the rest of the divider.

`CreateRoundPlayerRim` draws the same existing artwork in three horizontal pieces. Only the divider band trims those two columns, with half-texel filtering margins horizontally and vertically; the upper/lower artwork, circular rim and gray lower bar border remain. The rounded player's normal rim and combat/rest pulses share that crop, so animation cannot reintroduce the stub. The optional full resource divider remains available through its existing control. Original pointed artwork, health/resource geometry, values, model copies and saved layout are unchanged. Pieces are created once with no new OnUpdate or polling; no texture file, setting or SavedVariable is added. No local checks or addon/game execution were run; the correction remains unverified in-game.

## Two-column HUD options — 2026-10-19

The HUD tab places its existing eleven controls left to right in two columns and six 60-unit rows. Each description has two lines below its label. Dialog sizing measures translated labels across all supported languages and allows descriptions to wrap instead of reserving their full single-line width in both columns. The existing scroll frame and mouse-wheel handling remain available, with scrolling stepping by one paired row. The shared display controls, jewelry dependencies, live preview, Confirm, Cancel and reset paths remain unchanged. No new setting, SavedVariable or asset is added. No local checks or addon/game execution were run; packaged-game appearance remains unverified.

## Disable the talent-button reminder pulse — 2026-10-19

The user requested a steady Talents (N) micro-menu icon. The native [talent event handler](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/MainMenuBarMicroButtons.lua#L109-L119) starts its level-up reminder through `SetButtonPulse`. The native [pulse helpers](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/UIParent.lua#L1279-L1318) animate a locked highlight and provide `ButtonPulse_StopPulse` to remove an active reminder.

The micro-menu initializer stops any existing talent pulse when that helper is available and unlocks its highlight once. A wrapper on the real global `SetButtonPulse` rejects only the existing TalentMicroButton; calls for every other button retain the original function and arguments. Native talent events, availability, tooltip/binding updates, click handling, normal hover artwork and the game's talent window remain intact. No polling, setting, SavedVariable or new asset is added. This follows the 1.12 FrameXML path; packaged-game behavior remains unverified. No local checks or addon/game execution were run.

## Round player portrait fill overlap — 2026-10-19

The supplied screenshot shows world background between the new circular rim and the original player health opening. The pointed border formerly covered that area. The shared unit-border helper now exposes its existing 15-unit circular overlap: the target retains its current geometry, while the player opts in only with Round player portrait. Player fill width/inset become 137/89 instead of 122/104, leaving the far edge at 226. Its background follows the bar; the optional resource row and native divider use the same extended span. Name and centered health/resource values compensate for the extension so their visible positions stay fixed. Disabling the option restores the original internal geometry without changing confirmed PlayerFrame layout or native values.

Both native still portraits and gold sheets use the raised border layer above fill/loss. Anonymous model copies retain their current subjects and native viewport geometry; a reference to the existing model widget on its owner allows late player-border initialization to align the model's level without rebinding or readiness inference. Damage-loss segments retain normalized start/width fractions so bar-size changes reflow the same segment while preserving its fade time and alpha. No new health event, effect, asset, setting or SavedVariable is introduced. No local checks or addon/game execution were run; the correction remains unverified in-game.

## SCT pet damage filter — 2026-10-20

**Pet damage** in `/sdui` → **Combat text** controls only custom numeric damage explicitly identified as coming from a pet. Its normalized `sctPetDamage` boolean defaults on, including missing or invalid values, in the existing display table. It shares live preview, Confirm-only saving, Cancel/world/logout/reload discard and both resets. Identified pet damage must also pass its normal/critical and damage-category choices; miss/avoidance notices retain their independent choice. The checkbox fills the spare half of the existing final category row, and all fourteen languages have source/runtime captions. The two result captions are now **Normal damage** and **Critical damage**, retaining their saved keys.

The parser marks native PET melee, miss and spell events, and accepted shared periodic/reflected messages whose explicit source matches `UnitName("pet")` rather than the player. Duplicate identity includes this marker so a suppressed pet hit cannot absorb an otherwise identical allowed hit. Active labels retain the marker for preview removal and clear it when pooled. Every original event still matches, consumes health-loss evidence and samples its original color before filtering; no amounts, native messages or meter totals change.

The supplied capture confirms PET melee events for Succubus, Infernal and Voidwalker, but the reported Imp Fireball appears as `CHAT_MSG_SPELL_SELF_DAMAGE` with `Your Fireball...` wording and no pet source. Such unattributed spells remain visible when Pet damage is off. No spell-name, icon, class or meter-total inference fills that gap. The private capture is not shipped. No local checks, tests, syntax/formatting tools or addon/game execution were run; GitHub Actions supplies static checks and runtime behavior remains unverified.

## SCT normal/critical result filters — 2026-10-19

Normal damage and Critical damage are independent display booleans defaulting to true, `sctNormalHits` and `sctCriticalHits`, using the shared display normalization, live preview, Confirm, discard and reset paths. Numeric damage must pass its result choice and existing damage category; miss/avoidance notices keep their independent control. Normal includes stronger yellow non-critical hits. Native parsed critical status determines the choice even with class-colored damage enabled; no magnitude or color inference is used.

The first-hit info and active text retain native critical status, and the duplicate intake key includes it. Otherwise a normal first hit could absorb an equal-valued critical hit into its group and hide that critical when normal text is disabled, or vice versa. Same-type duplicates retain the original fixed 75 ms admission window and unchanged number. All original events still match in order, consume their own loss evidence and sample original colors before display filtering. Active rejected labels are returned to the pool; queued groups use current choices at display time. Compact two-column checkbox rows keep all controls inside the existing Combat text page. No local checks or game/addon execution were run; runtime behavior remains unverified.

## SCT size and shared checkbox row — 2026-10-19

The Combat text tab places Incoming/self text and Damage icons side by side, retaining both independent native/addon preference paths and allowing two lines for each description. SCT size uses the existing minus/plus editor buttons, with a 100% default and five-percentage-point steps clamped to 25–200%. The existing display table adds only a normalized numeric `sctScale` multiplier (0.25–2): missing, nonnumeric and nonfinite values use 1; finite out-of-range values clamp. This is the user-authorized numeric exception to that table's display booleans.

The renderer multiplies only each hit's inner visual scale at launch and throughout animation, so text, icons and existing critical/miss pop follow the setting. Holder coordinates, trajectory, lifetime, matching, raw amounts, grouping, colors and native combat text are unchanged. Already animating hits preview size without resetting their launch/lifetime. The shared display draft handles Confirm-only saving, Cancel/world cleanup/reload discard and both full resets to 100%, without changing SCT mode. No new SavedVariable, command or asset is added. No local checks or game/addon execution were run; packaged-game behavior remains unverified.

## Player/buff options, class damage colors and command retirement — 2026-10-19

The shared display table adds `roundPlayerPortrait`, `flipBuffs` and `sctClassColors`, all normalized booleans defaulting to false. They use the existing preview/Confirm/Cancel/world cleanup/reset lifecycle, with no new SavedVariable or gameplay state.

The round-player option reuses the existing target circular border sheet through the player's mirrored crop. The optional combat/rest pulse uses that circular rim instead of the original pointed status artwork. The later fill-overlap adjustment extends the health/resource background beneath that rim while keeping labels and the far bar edge fixed. It changes neither native still/model binding nor the renderer's existing rectangular model viewport/camera. Buff flipping changes only the existing native buttons’ horizontal order to left to right, keeping durations below, stack counts at bottom-right and row offsets unchanged, retaining the Buffs group's saved position/scale, native data and six-column wrapping. Users place that independent group above the player through Layout. The HUD page uses the same native scroll-frame template already used by Copy so every option fits inside the existing dialog.

Class-colored damage reads one shared class palette also used by player and party health. It repaints custom numeric damage, including active labels and critical/pet hits, while keeping misses unchanged. Original per-hit colors and non-critical history remain available when the toggle is turned off or class data is unavailable. Category filtering and matching still process every original hit before display suppression.

This addon no longer registers `/sct`: Custom/Off/Game settings, current-mode indication, incoming/self text, damage icons and Confirm-only persistence already exist in `/sdui`. Its command-only setter and feedback translations are removed without clearing another addon's globals or adding an alias. Older dated notes below describing the former slash implementation are historical. No local validation, formatting tools, tests, syntax checks, addon execution or game startup was run; packaged-game behavior remains unverified.

The owner announced native addon support in **Azeroth Survivors 0.87.0**, and the user supplied the official `addon_docs.md`. A verbatim copy is saved as `AzerothSurvivors-Addon-API.md` beside this note.

The owner's updated reference supplied on **2026-10-15** is preserved separately and verbatim in [AzerothSurvivors-Addon-API-2026-10-15.txt](AzerothSurvivors-Addon-API-2026-10-15.txt). It adds authoritative per-spawn boss/guardian debuffs through `AZS_GetDebuffs(id)`, superseding the former target-only limitation. The original Markdown reference remains unchanged.

This supplies everything needed for SurvivorsDragonUi's native run-progress and boss-health replacements, including control over the original HUD. Users install only the addon; the old external REA companion is unnecessary and excluded.

| Purpose                                                                    | Official interface                                                           |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Native smooth, pause-aware elapsed time                                    | `AZS_GetRunTime()`                                                           |
| Current run lifecycle                                                      | `AZS_GetPhase()`                                                             |
| Actual zone duration/final-boss time                                       | `AZS_GetRunLength()`, with native `AZS_RUN.fin` fallback                     |
| Complete boss-spawn schedule; boss-state skull, glow and checkmark display | `AZS_SCHEDULE`, each entry's `at` and `state`                                |
| Every live boss, with stable identity within a run                         | `AZS_GetBosses()`: `id`, `name`, `hp`, **`hpm`**                             |
| Guardian bars sharing the native boss-HUD group                            | `AZS_GetGuardians()`: `id`, `name`, `hp`, `hpm`                              |
| Debuffs on every displayed boss and awake guardian                         | `AZS_GetDebuffs(id)`: native icons, stacks, timing and permanence            |
| Kills, current gold and the next cache's gold cost                         | `AZS_RUN.kills`, `AZS_RUN.gold`, `AZS_RUN.chest`                             |
| Show/hide native HUD groups                                                | `AZS_SetHudShown(part, shown)` and `AZS_IsHudShown(part)`                    |
| Immediate state/list refreshes                                             | `CHAT_MSG_ADDON`: `AZSZONE`, `AZSRUN`, `AZSBOSSES`, `AZSUNITS`, `AZSDEBUFFS` |

`modules/ui/run.lua` consumes these APIs directly. There is no companion sequence/acknowledgement protocol, independent run clock or heartbeat timeout. The native getter owns interpolation and pauses. The local 0.1-second accumulator only throttles list refreshes. The user-authorized reload-only schedule handoff below preserves already-received facts without writing native API tables.

The official document corrects the earlier assumption that every zone lasts 16 minutes: duration and spawn times are zone-specific. Elwynn Forest remains 960 seconds with spawns at 3, 6, 9, 12 and 16 minutes. Other zones use their native duration and full schedule. The addon validates that full schedule and displays every scheduled skull. Native `due` entries keep the default full-size, opaque skull; `up` entries add a red/orange glow underneath the unchanged skull; `dead` entries use an 80%-size skull at 70% opacity with a green checkmark and no active glow. The checkmark means the boss was killed, based only on the official schedule state. Only the fill is clamped after the final-boss time, allowing elapsed time to continue in endless mode.

Hovering a visible timer skull shows its native schedule `name` unchanged. The normalized schedule retains that name through the existing reload-only handoff. Missing or empty names, including older handoffs without names, leave valid skulls visible without a tooltip or guessed boss identity. Pooled markers refresh an owned tooltip when their name changes and hide only their own tooltip on mouse leave, marker or parent hiding, retirement and clock release. The hit area remains the existing 18-by-18 marker; timing, appearance and layout geometry stay unchanged. Local checks and addon/game execution were intentionally not run; hover behavior remains unverified in-game.

Every live boss and engaged guardian has its own spawn-id key and health pill, with no addon-imposed four-row limit. Guardians are shown only when their documented `awake` flag is true (or native numeric 1); sleeping guardians are omitted. This keeps map-wide dormant lairs from bloating the HUD, while engaged enemies remain visible even at full health. Do not use `enraged` (a low-health state), selection or missing HP as an engagement test. The API's `hpm` maximum-health field replaces the private JSON's old `hpMax` field. All returned native lists remain read-only.

The addon hides `clock`, `bosses` and `tally` only after their replacements are ready; `bosses` includes guardians, so engaged guardians' health is also preserved in the replacement. The clock requires a valid phase, native elapsed time and native duration; its marker schedule is independent. It captures prior HUD visibility and restores it when a replacement's required native data is missing/invalid, on world leave and on logout. Saved game HUD settings are not treated as addon configuration.

The replacement tally is one gold bar whose default placement is directly beneath the XP bar, with its default total outer width matching the seven-button action bar artwork and XP bar. Each of those three groups can be moved and uniformly resized independently, so user resizing can make their displayed widths differ. Three equal sections show centered numeric values in DEFAULT text for kills, current gold and the next cache's gold cost. Kills and cache cost retain their native icons; current gold is number-only. These come directly from `AZS_RUN.kills`, `AZS_RUN.gold` and `AZS_RUN.chest`; `ck` counts opened caches and is not used as a price. All three required counters must be present and nonnegative; zero is valid. Missing fields release control of the native tally. Native `AZSRUN` messages and the existing 0.1-second poll refresh the values without inventing increments or timing out a paused run.

Phase must be read before using retained tables, which can contain previous-run data outside a run. A nil clock before the first update leaves the original HUD available. Paused/unchanged native state is valid without repeated packets.

After `/reload`, each HUD replacement reconnects independently when its required native data arrives. A missing zone-derived run length can fall back to the current run's official `AZS_RUN.fin`; no local clock or guessed schedule is used. Encounter lists must have `AZS_UNITS_UPDATED` before an empty list can suppress native boss bars. A complete schedule can cross a hooked reload through the narrow handoff below. The addon cannot request a full API replay: reliable recovery of unchanged lists and missing/rejected handoffs needs the game to republish its current state after rebuilding the Lua VM. See [RELOAD-API-NOTES.md](RELOAD-API-NOTES.md) for the static evidence, owner-side requirement and unverified live status.

The API also exposes damage-meter lines, damage taken, spells/cooldowns, buffs, other hero/run statistics, targets and unit kinds. Those extra capabilities are available for future work; the current replacements cover run/encounter bars, the tally and their native visibility.

The supplied release announcement establishes the **0.87.0+** requirement for the original run HUD APIs. Individual features also require their documented getters and snapshots from the matching game build. The implementation detects unavailable APIs and leaves the native HUD available. No tests, syntax checks, validation or game startups were run for this change, per the project instruction.

## Hide the native build — 2026-10-17

The user requested hiding the original weapon and jewelry rows again after the comparison period. The supplied reference identifies both native rows as the `build` HUD part, controlled by `AZS_SetHudShown` and the game's saved `hudBuild` preference. These rows are separate from Lua/FrameXML objects and are not discoverable through the addon's frame inspector.

The `Native build rows` initializer in `modules/ui/ui.lua` feature-detects the official getter/setter. The user-requested **Hide default jewelry / abilities** HUD toggle defaults on; it applies `AZS_SetHudShown("build", not hideNativeBuild)` on initialization, world entry, display changes and changes to `hudBuild` while in the world. Matching visibility causes no repeated write, and a guard prevents synchronous CVar callbacks from reentering. Confirm alone saves `hideNativeBuild` in the existing display table. Cancel, world leave/logout/reload restore the committed choice; display drafts are discarded before native reload or world-exit saving, independently of layout-event order. Both full resets restore hiding. It adds no per-frame polling, SavedVariable or prior-visibility snapshot and leaves the existing clock/boss/tally takeover and restoration paths intact. Packaged-game behavior remains unverified; no local checks or game/addon execution were run.

The user explicitly chose five ordinary equipped jewelry slots: neck, two rings and two trinkets. The selected design-4 thin-bezel attachment joins those sockets to the existing action bar, with the extra lower curved line omitted and the original bar texture retained. Jewelry shares the action bar's geometry and editing lifecycle while attached. The Attach jewelry to action bar HUD toggle defaults on and is available while equipped jewelry is enabled; off retains complete silver-gray circular outlines and uses independent `jewelryBar` layout geometry through a separate container. Only Confirm saves `attachJewelry` in the existing display table; discard and both full resets use the shared lifecycle. Its independent **Equipped jewelry** HUD toggle defaults on; off restores the original bar edge and stops equipment/cooldown work. Only Confirm saves `equippedJewelry` in the existing display table; shared discard and both full resets retain the usual lifecycle. Equipment data uses stock inventory APIs and native cooldowns. A private hidden inventory tooltip supplies only localized Equip/Use/Chance-on-hit rows for the effects-only card without owning or clearing the shared tooltip; missing descriptions show no popup. The common hover module separately styles native unit/ability tooltips and the jewelry card using the selected PentSec/DragonUI approach, without a Targeting line or hover health bar; see [TOOLTIPS.md](TOOLTIPS.md). It does not substitute equipped items for the native six-pickup build or invent an AZS jewelry feed. See [EQUIPPED-JEWELRY.md](EQUIPPED-JEWELRY.md) for sources, refresh/cleanup and layout behavior.

## Independent clock and marker recovery after reload — 2026-10-15

The user reported that `/reload` leaves the run progress bar without its vertical boss-spawn markers. A recovered native clock and `AZS_RUN.fin` can supply elapsed time and duration before `AZSBOSSES` has replayed the complete schedule. The first response made the entire clock wait for that schedule; the user then reported that the whole custom top bar disappeared after `/reload`. That schedule gate has been removed from clock display and takeover.

Marker rendering requires a complete valid `AZS_SCHEDULE`, checked against the native expected boss count from `AZS_RUN.bt` or `AZS_ZONE.bt`. Schedule entries need unique numeric indices, positive spawn times no later than the native run length, a recognized `due`, `up` or `dead` state, and a final-boss flag/time agreeing with that length. Completeness validation uses the full list, including every state; `AZS_GetUpcomingBosses()` cannot replace it because that getter excludes past bosses. The native state chooses each marker's default, active-glow or killed-checkmark appearance. Elapsed time and the absence of a live boss entry never establish activation or death. Native tables remain read-only.

The custom clock displays and takes control of the native `clock` HUD part as soon as the phase, native elapsed time and native duration are valid. Without a complete live schedule or eligible reload handoff, missing schedule data clears only its marker textures; it keeps the progress bar visible and respects the selected run-label visibility without a duplicate native clock. Markers rebuild from the complete official schedule when it arrives, restoring the default skulls for `due`, active glow for `up` and killed checkmarks for `dead`. Invalid phase, elapsed time or duration releases the custom clock and restores captured native visibility, including an originally hidden game preference. Tally and encounter bars continue reconnecting independently when their own native data is ready.

This corrected the full-bar regression while keeping incomplete marker data separate from valid clock data. At that stage, no schedule was persisted and complete marker restoration required the game to replay `AZSBOSSES`. The subsequently authorized handoff below supersedes that persistence restriction only for a hooked reload. Official getters remain polled every frame, list refreshes remain throttled to 0.1 seconds, and native addon messages trigger refreshes. There are no invented markers, independent clock or resync command. See [RELOAD-API-NOTES.md](RELOAD-API-NOTES.md). These edits have not been verified live.

## Reload-only boss-schedule handoff — 2026-10-15

The user requested that an already-received boss schedule survive `/reload`. The addon keeps a normalized copy of a complete native schedule and minimal continuity fields in memory. Immediately before a wrapped real `_G.ReloadUI` call, it writes that handoff to the separate `SurvivorsDragonUiBossSchedule` SavedVariable. The next initialization consumes and clears the saved value immediately; normal play does not maintain a persistent gameplay cache. A complete live schedule always takes priority.

The handoff can supply markers only after current native data again provides an active phase, valid elapsed time/duration and expected boss count. Duration and count must match; raw `AZS_RUN.t` must not regress; native `bs` and `bk` counters must match exactly. Changed boss counters discard the saved marker states and require a fresh complete schedule, without guessing which boss became active or died. The native clock remains the sole time source. Normal world leave/logout, ready/run reset and a new `AZSZONE` invalidate the in-memory handoff; a reload-triggered leave preserves it for the new Lua VM.

No documented run identifier exists, so these fields cannot prove run identity. This is best-effort continuity through the hooked native reload path, not a cross-session cache or a replacement for full client replay. An absent, incompatible or outdated handoff leaves markers hidden until a complete live schedule arrives, while a valid custom clock remains visible. Calls that bypass the hooked `_G.ReloadUI` path have no handoff guarantee. Layout remains geometry-only; chat capture, encounters and other native data stay unsaved. This narrow exception supersedes older blanket schedule-persistence prohibitions in these notes. No local validation, tests, syntax checks, addon execution or game startups were run; packaged-game reload behavior remains unverified.

## Independent layout geometry — 2026-10-15

The user replaced the modifier-key trigger with explicit layout edit mode. `/sdui` opens editing; repeated calls keep it open. Left-dragging a group's body moves it and left-dragging a corner icon resizes it while editing is active. Outlines and corner icons remain visible until editing ends, including for hidden HUD groups without showing inactive targets or encounters. A single centered Confirm button stays above the handles. The remaining groups include independent player/target frames, boss-health group, run timer, action bar, XP, kills/gold/cache tally, buffs, minimap and chat, plus the main menu and Copy window while open. Cast-bar and quest-watch displays are removed rather than registered for layout editing.

HUD groups resize by uniform scale, retaining their artwork proportions. Chat and Copy instead change actual width and height to update wrapping and the viewport, while fonts retain their normal size. The defaults remain defined in code, with XP beneath the action bar and tally beneath XP at matching artwork widths; moving or resizing one never changes another. Boss health rows remain together in their own group, independently of the timer.

Moving and resizing stage draft geometry without saving on drop. Confirm stores all pending locations, HUD scale and chat/Copy dimensions in the single `SurvivorsDragonUiLayout` SavedVariables table, then locks the layout and hides its editing controls. Unconfirmed edits are discarded on world leave, logout and reload; the last confirmed layout is restored. `/sdui reset` immediately clears saved geometry, discards the draft, exits editing and restores every registered group's default position and size, including groups that are currently hidden. It does not alter native run data or the separately saved SCT mode. Its authorized Hide default jewelry / abilities reset restores the default native-build hiding preference. `/copy` remains the chat-capture utility; raw capture is still session-only. Chat defaults to the bottom-left corner and keeps opacity 0. Entering edit mode, moving or resizing does not reveal faded history or change fading; mouse-wheel navigation remains available during editing and is still the only reveal action. Its existing SHIFT fast-scroll modifier remains unrelated to layout editing.

Layout persistence never stores phase, clock, schedules, encounters, counters or other native API snapshots. The separate reload-only schedule handoff above does not change layout storage. The HUD still requires current official native data and, where the handoff cannot apply, client replay. These layout edits were made without tests, syntax checks, validation, addon execution or game startups.

## Shared SDUI editor organization — 2026-10-16

The user requested a more cohesive `/sdui` layout using artwork from public Dragonflight-style projects. The editor is one initially centered, draggable dialog with three tabs. **HUD** groups Class resources, Boss debuffs, Cache guidance and Guardian guidance into checkbox rows with explanatory descriptions. **Combat text** presents direct Custom, Off and Game settings buttons for outgoing text, alongside separate Incoming/self text and Damage icons checkboxes; Game settings maps to the existing `default` SCT mode. **Run timer** provides a live label sample, native-font dropdown, size stepper, explicit None/Outline/Thick choices, Shadow and Run text checkboxes. The existing `showText` preference controls the Run text checkbox; no new font or display fields are introduced by this organization.

The dialog width is measured from its controls and labels. Left-dragging its background moves it. The selected tab and dialog position stay in session memory; they add no SavedVariable, layout entry, profile or command. The full reset recenters the dialog. `core/layout.lua` still owns the single Confirm action, now anchored at the center of the shared footer with Addon defaults beside it. The editor and both actions stay above editing handles. Every tab previews through the existing draft stores immediately, and changing tabs does not save or discard those drafts. Confirm, world leave/logout/reload discard, native-setting precedence and both full-reset paths retain their existing behavior.

`core/editor.lua` supplies shared panel, button, checkbox and divider styling through ordinary texture APIs. Five compact TGA textures under `media/tex/editor/` contain selected pixels from the pinned PentSec/DragonUI artwork, with the upstream Karl-HeinzSchneider/DragonflightUI family credited. Source commits, pixel coordinates, licensing and the four requested repositories researched are recorded in [SDUI-ARTWORK.md](../third_party/SDUI-ARTWORK.md). The new borrowed artwork comes from the recorded PentSec source; the research does not imply that all four repositories supplied shipped assets. The addon does not load those source addons, a retail atlas API or an external dependency. Required attribution and license text is retained in the shipped helper's comments.

This editor change does not alter the official native APIs or the supplied reference copies. No local checks, tests, syntax validation, addon execution or game startups were run. The editor's appearance, input behavior and integration remain unverified in the packaged game.

## SCT damage colors — 2026-10-15

Custom damage text uses gray for normal hits, yellow for stronger non-critical hits and orange for critical hits. A stronger hit is at least 1.2 times the average of the same attack's preceding non-critical hits: at most eight samples, no older than 30 seconds, with at least three samples before yellow can appear. The source, parsed damage type, school and spell name separate those baselines, including periodic ticks versus direct hits. Unnamed attacks other than autoattacks stay gray rather than combining unknown abilities. Critical status comes only from the existing native-message parser; crits and misses do not contribute samples. Existing miss labels retain yellow.

Colors are chosen once in native message order before matching delays, and remain fixed throughout each hit's animation. The sample tables are memory-only and clear with the existing mode/world reset; they are never SavedVariables. Combat parsing, original damage amounts, crit pop/size, position matching and nameplate masking are unchanged. No tests, syntax checks, validation, addon execution or game startups were run for this local change.

## SCT damage colors — 2026-10-15

Custom damage text uses gray for normal hits, yellow for stronger non-critical hits and orange for critical hits. A stronger hit is at least 1.2 times the average of the same attack's preceding non-critical hits: at most eight samples, no older than 30 seconds, with at least three samples before yellow can appear. The source, parsed damage type, school and spell name separate those baselines, including periodic ticks versus direct hits. Unnamed attacks other than autoattacks stay gray rather than combining unknown abilities. Critical status comes only from the existing native-message parser; crits and misses do not contribute samples. Existing miss labels retain yellow.

Colors are chosen once in native message order before matching delays, and remain fixed throughout each hit's animation. The sample tables are memory-only and clear with the existing mode/world reset; they are never SavedVariables. Combat parsing, original damage amounts, crit pop/size, position matching and nameplate masking are unchanged. No tests, syntax checks, validation, addon execution or game startups were run for this local change.

## SCT position stability — 2026-10-15

The user reported damage numbers shaking and briefly disappearing, mainly on newly spawned distant enemies approaching the player. Active hits already own independent WorldFrame holders and a full 1.45-second lifetime; plate hiding/reuse does not release or restart them. The source-level weakness was direct per-frame assignment of each hit's follow point from the native plate coordinate.

The inspected base client's [collision placement has no cross-frame history](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-app/src/smart_rect.rs), and [newly loaded unit models can change the overhead anchor](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-app/src/entities.rs). Those native position discontinuities are a plausible source of the report, not proof of the packaged game's exact cause.

Each hit now interpolates only its cosmetic follow coordinates with an elapsed-time exponential response of 0.08 seconds, starting at the resolved impact position. Raw plate positions and health/name evidence remain the matching inputs. Position samples require finite coordinates, positive finite scales and usable WorldFrame geometry; the native center must intersect the viewport with its half-width/half-height allowance, keeping partly visible edge plates eligible. Rejected samples preserve the previous usable position for existing animations. A last-valid coordinate older than the existing 0.65-second recent-plate window cannot continue supplying new matches merely because its frame remains shown.

Smoothing never resets a hit's start time, arc, critical pop, color, alpha or full lifetime. Retired incarnations keep their last valid target position; frame reuse cannot redirect their hits. Native V tracking, draw-layer/click masking and native collision placement remain unchanged. No private state is persisted. This is an addon-side mitigation; it does not claim to fix the separate first-allocation stock-plate flash or provide exact enemy identity. No local validation, tests, syntax checks, addon execution or game startups were run; the reported in-game behavior still needs confirmation.

## Nameplate appearance integration — 2026-10-15

The nameplate style adapts the [Kui Nameplates Vanilla port's beta0.16 release](https://github.com/laytya/Kui-Namaplates/releases/tag/beta0.16), using the `Kui-Namaplates_beta0.16b.zip` asset. Its fixed 100-by-10 outer bar has a one-pixel black border, a 98-by-8 health fill and a centered name above, with native raid markers retained. The cyan target glow and arrows were removed at the user's request on 2026-10-16. Health percentages and all level indicators, including the unknown-level skull, are omitted. The style retains the imported health-fill and frame-shadow artwork; target-focus textures are no longer referenced by its Lua renderer. Upstream authorship/media notices and the full GPL-3.0 license remain in the shipped style module and `third_party/Kui-Nameplates-NOTICE.txt`; imported material retains its upstream terms. Appearance defaults are fixed in code and use DEFAULT. No upstream settings, profiles, estimated auras, cast tracking, health estimates, unit caches, libraries or client extensions are imported.

Each skin is a mouse-disabled child of the native plate. It reads the original health bar's range, value and reaction color and the original name region without modifying them. Native plate geometry, alpha, shown state and mouse-enabled state remain controlled by the client. Native artwork and omitted label regions are made transparent; the native border texture identity remains available for plate discovery. None of the upstream name-based targeting scans, GUID caches or native targeting changes are included.

The same discovery loop refreshes appearance in all SCT modes. It builds each skin before applying the existing recursive draw-layer/hit-rectangle mask, so V-off custom SCT tracking also masks the new artwork. The style never enables draw layers or changes nameplate visibility. Native names, health-change evidence, live and retired coordinates, combat parsing and independent hit animations remain the inputs to SCT. Native collision displacement remains a client limitation.

V-off masking also hides the entire custom visual child explicitly, including its black background and shadow. Restoring presentation shows that child again. Native plate and health-bar frames remain shown with their original alpha, so invisible coordinate tracking and SCT animations continue. The complete-child masking from the black-rectangle fix is retained with the replacement style.

No tests, syntax checks, validation, addon execution or game startups were run; visual appearance and SCT coexistence remain unverified in the packaged game.

## MSBT-style combat text — 2026-10-27

`/sdui` → **Combat text** has **MSBT-style scrolling**, off by default. Missing
or invalid `sctMSBTStyle` values normalize to false in the existing display
table, preserving the current over-enemy style. Preview, Confirm-only saving,
Cancel/world/logout/reload discard, profiles and both full resets share the
existing display transaction. The checkbox dims and disables alongside the
other settings when the effective mode is Off or Game settings. The Custom
status description follows the selected style in all fourteen languages.

The optional style sends outgoing damage and avoidance notices down a curved
stream to the right of screen center. It reuses the current parser, exact
duplicate grouping, unchanged numeric amounts, filters, icons, colors, size,
crit/miss pop and 1.45-second lifetime. Pooled label offsets space simultaneous
lines and ease older lines downward as new ones arrive; no extra hit cap,
amount merging or replacement history is added. Incoming/self text retains
its existing independent native control. This is an independently implemented
outgoing style, not a port of another addon or its full notification system.

The stream uses the `sctMSBT` Layout owner, defaulting to the same position right
of WorldFrame center. With Custom and MSBT-style scrolling enabled, its outline
is available in `/sdui` and `/sdui lock` before the first combat hit. Dragging,
corner scaling, Shift alignment, numeric position/scale and Hide frame reuse the
shared Layout controls. Only Confirm saves its geometry in
`SurvivorsDragonUiLayout`; Cancel, world/logout/reload discard, profiles and both
resets use the existing lifecycle. Disabling the style or Custom mode retires
the owner request and its handle while retaining confirmed geometry.

Pooled hit holders inherit the scrolling owner's position, scale and visibility.
Over-enemy hits return to their original parent and WorldFrame anchors when
reused, so the scrolling layout cannot affect them. Layout hiding clears active
and queued scrolling hits and skips intake, icon lookup, animation and text
measurement until new visible hits arrive. Unhiding never replays old hits.

The movable stream still skips enemy-origin
matching, health-loss sampling and combat-event plate discovery. It does not
force native hostile plates on: with V off, the captured native HideNameplates
restores normal overhead-name eligibility. Native name preferences still
apply. With V on, nameplate styling, Names only and the bosses/guardians filter
retain their current behavior. The default over-enemy style keeps its original
tracking, matching and animation equations.

Changing styles clears active/queued text and transient matching/color samples,
then applies the current V request without writing `NAMEPLATES_ON` or native
settings. A discarded preview does the same in reverse. World/logout cleanup
and Lua 5.0 remembered queue sizes remain shared. No runtime test export, asset,
new SavedVariable, event or updater is introduced. See
[PERFORMANCE.md](PERFORMANCE.md#msbt-style-combat-text--2026-10-27) for costs
and CI-only mocked coverage in [PR-CHECKS.md](PR-CHECKS.md).

## Names-only nameplates — 2026-10-27

`/sdui` → **Nameplates** has **Names only**, off by default. The normalized
`nameplatesNamesOnly` boolean lives in the existing display table and shares
live preview, Confirm-only saving, Cancel/world/logout/reload discard, profiles
and both full resets. It works in every SCT mode. V still shows or hides enemy
names, Shift-V retains friendly visibility and **Only bosses and guardians**
continues to exclude ordinary enemy plates.

**Font size** in the same category changes the custom name label in both
regular and names-only plates. `nameplateFontSize` defaults to the original 9,
rounds/clamps finite values to 6–32 and shares the same display transaction,
profiles and resets. The label keeps DEFAULT/OUTLINE, its original bottom
anchor and proportional text-box dimensions. Native plate/bar/click geometry,
SCT positions and world-rendered overhead names are unchanged. Masked plates
defer the font update; unchanged successful assignments skip writes and failed
font assignments remain retryable, including when a preview is discarded.

Names only reuses each plate's current name label and native reaction color.
It hides the custom health bar, black background, shadow and raid icon. The
label's overlay anchors directly to the visual root's original one-unit inset,
so its name has no dependency on a hidden cosmetic bar. Starting with Names only
allocates no cosmetic StatusBar, shadow, background or raid texture; the first
eligible regular-bar refresh creates those once. Later names-only transitions
hide them and keep the pool for reuse. Turning the option off restores the original artwork,
white name and current native health/raid state. Hidden or filtered plates
defer all of this presentation until visible through the existing reader.

The native plate and native health bar keep their original geometry, alpha,
shown state, mouse behavior, values and names. SCT still reads the same
positions and health-loss evidence; the V-off tracking mask and its empty
click rectangle are unchanged. These are names on native nameplates, with
their existing range and collision stacking, rather than the world-rendered
overhead text. No client config key or native preference is changed.

Both captions are present in all fourteen source/runtime UI catalogs. The
existing settings page adds one standard checkbox; no per-plate frame/drawing
region, asset, event, updater or SavedVariable is added. Verification
was source/diff review and pinned formatting only; local tests, standalone
validation and addon/game execution were not run. See the source-level drawing
costs in [PERFORMANCE.md](PERFORMANCE.md#names-only-nameplates--2026-10-27).

## Boss and guardian nameplate filter — 2026-10-27

`/sdui` → **Nameplates** has **Only bosses and guardians**, off by default.
The normalized `nameplatesBossGuardiansOnly` boolean uses the existing display
table, live preview, Confirm-only saving, Cancel/world/logout/reload discard,
profiles and both full resets. It works in every SCT mode and independently of
boss bars and guardian guidance. V still controls requested enemy-plate visibility;
friendly plates keep their native Shift-V behavior.

The existing SCT controller reads phase first and accepts only received
`AZS_UNITS` publications. It keeps an unsaved index of exact native names and
maximum health for `final`, `boss` and `guardian` entries, including sleeping
guardians. Each accepted maximum indexes its original value and exact float32
representation, plus its native ceil/uint32-clamped value and that value's
float32 representation. Float conversion rounds halfway ties to even.
The retained Rust formatter also uses
[half-to-even precision rounding](https://doc.rust-lang.org/std/fmt/index.html#precision).

Waking guardians rescale their actor health before publishing native unit
fields. The unit maximum uses `ceilf`, while the encounter-list formatter emits
whole numbers. For example, actor maximum `1234.25` can arrive as `hpm = 1234`
but produce a native bar maximum of `1235`. The former exact-equality filter
rejected that signature. The index now also includes the upper unit ceiling
when a float32 value above the published integer can round to that integer:
below 2^22, or at an even half-tie below 2^23. At and above 2^23 no fractional
float32 maximum exists, so no extra integer is accepted. This is a bounded
serialization preimage, not a general plus/minus-one or epsilon match. An
explicit fractional publication also indexes its direct ceiling. All aliases
are prepared only when the accepted publication changes, in both sleeping and
awake states; no previous plate identity is carried across a mismatch.

Static inspection of the installed executable on 2026-10-27, SHA-256
`22f7938eb4f99f2857dc091b1c57c147bd848eaabfeaa81e444c0a3393ca8150`,
locates the guardian health/max block at VA `0x145c21c7c` (file `0x5c2107c`). It
loads actor fields `+0x160/+0x164`, calls import `ceilf` through
`0x145febc63`, and publishes descriptor fields 28/22 with uint32 saturation.
This rechecks the conversion lead in AzerothSurvivorsRE's
`docs/analysis/guardian-target-health-2026-10-23.md` against the installed file.
Its retained `gameplay/client/addon_lists.rs` and historical native
`0.109.0/addon-bridge` producer evidence supply the zero-decimal encounter-format
lead; this inspection does not execute either game or establish the reported
live guardian's actual values.

There is no inferred health or conversion of a percentage bar to absolute HP.
This handles native plate storage that cannot retain the full published maximum,
including the Names only/filter combination and waking conversion. Published
ordinary `elite` entries colliding with any of those native representations
make that signature ambiguous and hide it. The complete list is validated
before replacing the index; failed or unavailable data hides hostile plates until
usable data arrives or the option is turned off. Zone/world boundaries, terminal
phases and observed native-clock rollback retire prior publications; receipts are
read only on the existing deferred OnUpdate, at five Hz. Unchanged publications
reuse the index, and disabling skips these phase/table reads and clears it.

This is a display filter with an identity limit. Anonymous plates expose their
name and raw health range, but no supported spawn-ID binding; the reference
[native plate implementation](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/nameplate.rs)
keeps its key inside the engine. An ordinary enemy absent from the published
special-enemy list can still match a boss/guardian with the identical name and
native-representable maximum health. Known ambiguous signatures are hidden, which
can also hide a guardian. Percentage-only or otherwise unmatched bars stay hidden. No fuzzy
names, guessed unit tokens, health estimates or persistent identity registry are
used; source compatibility does not prove the packaged client's rendering.

The public engine's [plate state](https://github.com/samwhosung/benilla/blob/7c7a7f3e7ce168f819f676e6c2a423c6088731ca/crates/benilla-ui/src/script/nameplate.rs#L66-L75)
describes raw unit-field health stored as float32. This is a compatibility lead,
not a claim that the installed executable matches that upstream revision.
CI-only mocks run the production SCT/filter and style together over capped,
rounded, sleeping-to-awake ceiling and ambiguous native ranges, both mode
switches, V masking, retirement and lazy artwork allocation. They reject
out-of-preimage integers and percentage guesses. No local tests or live appearance/FPS measurement
were performed.

Excluded hostile plates reuse the existing recursive draw-layer/hit-rectangle
mask and hide the complete custom visual child. Native plate shown state, alpha,
mouse-enabled flag, data and coordinates remain native. Custom SCT still samples
ordinary enemies and retains every hit's original matching and animation.
Unmasking restores captured draw layers and click bounds. No asset, event,
updater, SavedVariable or client change is added. Verification was source/diff
review and pinned formatting only; local tests, standalone validation and
addon/game execution were not run.

## First-allocation nameplate flash — 2026-10-15

The user reported a brief stock-nameplate flash on spawning mobs, both before the custom nameplate style and with V off. The current public client source has a matching first-allocation timing gap: [Lua ticking runs in UiInput and painting follows VPlateSet](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-app/src/ui_script/mod.rs#L373-L392), while [native plate generation runs after UiInput](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-app/src/vplates.rs#L650-L658). A brand-new plate can therefore be drawn before the addon's next OnUpdate discovers, skins and masks it. This source ordering matches the report; it does not establish the exact packaged client's runtime behavior.

The native constructor [allocates frames internally](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-ui/src/script/nameplate.rs#L416-L419), bypassing Lua CreateFrame, and [writes health directly](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-ui/src/script/nameplate.rs#L656-L663), bypassing Lua SetValue. Wrapping those globals or adding another earlier OnUpdate cannot reliably intercept first allocation. No supported pre-draw creation callback was found in this source or the supplied addon API.

Known pooled plates already receive synchronous OnShow and OnValueChanged handling through the existing SCT hooks. Their masks remain installed across retirement. The first-frame gap concerns a newly allocated slot that has not yet been discovered and has no addon handlers. V off still needs the native coordinate feed for SCT; disabling that feed or hiding/changing native frame alpha would undo the existing tracking integration. Complete first-allocation suppression remains a client requirement, such as a creation notification or addon update stage after plate synchronization and before painting. No client patch, unsupported event, polling workaround or SCT behavior change was introduced. This was a source investigation only, without local checks, tests, syntax checks or game execution.

## Invisible nameplate tracking for custom SCT — 2026-10-15

The user reported that custom hits fell back to the center when native nameplates were hidden. The default over-enemy SCT style separates V's requested visible state from the native tracking state: while that style is active, it uses the original `ShowNameplates` to keep hostile plates live and their coordinates updating even when the user has chosen to hide the plates. `NAMEPLATES_ON` and the user's saved V preference remain unchanged. Selecting MSBT-style scrolling, Off or Game settings in `/sdui` releases that tracking control and restore the originally requested native visibility. World leave and logout release it too; the selected SCT mode is saved separately and restored subject to current game settings on the next UI initialization.

With V off, the addon disables draw layers on hostile plate frames and their descendants, including health-bar layers. It makes their hit rectangles empty through insets so invisible plates cannot receive clicks. It leaves the native mouse-enabled flag unchanged, preserving the client's freelook transitions. It does not hide the plate frames or change their alpha, so their native shown-state lifecycle and coordinate updates continue. Turning visible plates back on, changing out of custom mode, leaving the world or logging out restores the captured draw-layer and hit-rectangle state.

The base source supplies the mechanism: [native nameplate show/hide functions](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/nameplate.rs), [frame draw-layer and hit-rectangle controls](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/object/frame_state.rs), [native plate placement and collision handling](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/vplates.rs), and [native overhead-name behavior](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/nameplates.rs). These primary sources establish the intended integration mechanism, not the exact packaged game's behavior; the implementation has not been verified in-game.

Custom SCT uses live visible or invisible plates and recently retired positions with name/health-change evidence. Unmatched or ambiguous messages still appear at the shared fallback; no destination GUID or exact enemy projection is exposed by this integration. The tracked coordinates retain native collision displacement, so this does not disable native plate stacking. Native overhead enemy names can remain suppressed while the internal native tracker is active, even though the plate layers are invisible. Each hit keeps its independent animation through plate hiding, deaths and frame reuse, and mode changes clear active and queued hits immediately.

This is addon-only integration, with no settings window, companion process or client patch. No tests, syntax checks, validation, addon execution or game startups were run for this change.

## Custom SCT combat-burst work — 2026-10-16

Players reported a severe frame-rate drop with `/sct on` compared with native outgoing numbers. The custom event handler refreshed every known plate before parsing each combat message, including messages it later rejected. Each refresh repeated skin updates, projection/health reads and V-off descendant traversal, on top of the per-frame scan and native health hooks. This is a source-level bottleneck; its contribution to the reported frame-rate loss has not been measured in-game.

Combat messages now parse first. The first accepted hit in an event batch checks for new WorldFrame children; subsequent hits share that discovery until OnUpdate rearms it. Full per-frame sampling and forced scans always run independently. Discovery still takes an initial plate sample, and existing plates retain synchronous show/health hooks. The [base client synchronization](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-ui/src/script/nameplate.rs#L226-L241) dispatches visibility and health callbacks. The event-only discovery flag resets on mode/world cleanup and after each frame scan: native allocation happens after OnUpdate, and the next combat feed can still observe that update's clock value. Do not use one shared GetTime stamp to skip both paths; see the [UI stage ordering](https://github.com/samwhosung/benilla/blob/129b3bb852b2f328de529f3c698595c14baf5fa5/crates/benilla-app/src/ui_script/mod.rs#L342-L381) and [direct combat-event delivery](https://github.com/samwhosung/benilla/blob/129b3bb852b2f328de529f3c698595c14baf5fa5/crates/benilla-app/src/ui_chat/frames.rs#L21-L37).

The native [GetNumChildren implementation](https://github.com/samwhosung/benilla/blob/129b3bb852b2f328de529f3c698595c14baf5fa5/crates/benilla-ui/src/script/object/frame_state.rs#L208-L226) uses the same [child-list clone/walk](https://github.com/samwhosung/benilla/blob/129b3bb852b2f328de529f3c698595c14baf5fa5/crates/benilla-ui/src/script/object/frame_state.rs#L776-L783) as enumeration. Every pooled hit previously added a direct WorldFrame child, making even count queries grow with peak hit concurrency. Pooled holders now live beneath one empty, mouse-disabled container, retaining their explicit WorldFrame anchors, effective scale and frame level. No hit cap or early eviction is added.

Pending and active hits compact stably in place, avoiding repeated array shifts. Matching uses counts and coordinate sums instead of three temporary candidate arrays on each retry; uniqueness priorities, health-loss consumption and fallback averaging stay unchanged. Animation updates replace their existing CENTER anchor without tearing it down, and only write scale/alpha when those values change. The client [replaces a matching anchor in SetPoint](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-ui/src/script/object/layout_methods.rs#L281-L302), while [SetAlpha propagates through descendants](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-ui/src/widget/propagation.rs#L249-L258). Matching delays, recent retired origins, animation curves and every hit's full lifetime remain unchanged.

The user subsequently reported SCT numbers remaining on screen, with a runtime error in `UpdatePending` while indexing a nil `entry`. The client implements [Lua 5.0 remembered table sizes](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-ui/src/script/lua50/table_size.rs#L1-L7): `table.insert` records a size and `table.getn` returns it even after direct assignments clear array slots. Compaction now calls `table.setn` with the retained count for both pending and active hits; full cleanup resets the remembered active count to zero. This keeps subsequent insertion, iteration and reset consistent without reverting the batching, shared hit container, scale/alpha write guards or animation path. The original failure aborted the frame update before animation and expiration, leaving already displayed text frozen.

V-off masking walks descendants on presentation changes and forced discovery/reuse rather than every refresh. Hidden custom skins skip repainting while native position and health sampling continue; their next visible refresh copies current data. New plate skins still exist before their first mask, and pooled plates force a descendant revisit on show. V, mode changes, world leave and logout retain restoration of captured draw layers and hit rectangles.

The client still [projects and collision-places native plates while tracking is enabled](https://github.com/samwhosung/benilla/blob/129b3bb852b2f328de529f3c698595c14baf5fa5/crates/benilla-app/src/vplates.rs#L318-L473), even when the addon masks their draw layers. This is a separate cost retained to supply hit positions with V off; it is not eliminated by these addon changes. First-allocation flash also remains a client limitation. The original performance change used source review and GitHub Actions static checks only. For the retained-text follow-up, the user explicitly authorized live SCT diagnosis: frozen labels were observed in the running client, and the supplied traceback identified the nil pending entry. The corrected post-reload behavior remains unverified. No local formatter or separate validation/syntax-check tool was run. Neither the source review nor that narrow live diagnosis establishes frame-rate recovery; that still requires an in-game comparison.

## Run HUD text and icons — 2026-10-15

The run label is centered above the progress pill as `RUN elapsed / duration`, using native `Fonts\\SKURRI.TTF` at size 14 with normal `OUTLINE` and shadow. DEFAULT is initialized first so an unavailable native face leaves readable text. The default timer anchor moves from 38 to 30 pixels below the screen top, and its edit bounds include both the label and pill. Other UI keeps DEFAULT. The [base game's font source](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/ui_text/engine/faces.rs#L4-L11) lists Skurri among the client fonts; no custom font file is bundled, and loading in the packaged game has not been verified.

Scheduled boss-spawn markers use `Interface\\TargetingFrame\\UI-TargetingFrame-Skull`. The kills tally uses the native enemy-hover sword cursor `Interface\\Cursor\\Attack.blp`; the cache-cost tally uses the native loot-pouch cursor `Interface\\Cursor\\LootAll.blp`, retaining its full artwork, including the cursor triangle. Both cursor paths follow the [base game's cursor source](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/cursor.rs). Current gold is number-only, centered within its existing field; its tooltip anchors above the number and its affordability effects remain. Kills and cache-cost icons retain their existing 18-by-18 size and geometry, and the numbers still come from `AZS_RUN.kills`, `AZS_RUN.gold` and `AZS_RUN.chest`. Native schedule completeness and clock/marker readiness gates stay unchanged. No chat image assets remain. No tests, syntax checks, validation, addon execution or game startups were run for these edits.

## Mark official boss state — 2026-10-15

The user superseded elapsed-time completion with the official schedule's boss state. After validating the complete native schedule, the addon keeps every marker at its native `at` position and uses `state` for appearance: `due` displays the default 18-by-18 skull at full opacity without a checkmark or glow; `up` displays the same skull over a red outline following its native silhouette without tinting the skull; `dead` displays an 80%-size skull at 0.70 alpha with a green native checkmark and no active glow. The outline uses eight native skull copies at the unchanged 18-by-18 size, tinted with the original outline RGB `(1, 0.25, 0)`. Over a smooth 2.4-second cycle, each copy has additive alpha from 0.25 to 0.50 and its directional offset moves from 0.90 to 4.55 pixels. The minimum reach is 20% farther outward than the previous 0.75-pixel minimum; the maximum reach remains unchanged. Normalized diagonal offsets keep expansion even. The increased per-copy opacity makes the original outline color stronger throughout the pulse; animated offsets provide inward/outward motion instead of only changing brightness. The rejected circular halo texture is removed from the source and runtime manifest; no additional artwork is required. Cosmetic phase comes from UI `GetTime()` so the glow continues breathing during pause/card selection; it never supplies run time, progress or schedule state. The foreground skull, marker anchor geometry and dead/due styles are unchanged. The checkmark indicates a killed boss. Passing a scheduled time and disappearing from `AZS_GetBosses()` never establish activation or death; no private clock advances boss state.

Schedule completeness checks include all recognized `due`, `up` and `dead` states; marker positions, the 0.1-second schedule/geometry refresh, native table ownership and independent clock/reload recovery stay unchanged. Without a complete live schedule or eligible reload handoff, missing schedule data clears the skull, glow and checkmark while keeping a valid clock visible. Unused pooled markers and clock release also hide all three visuals. Replayed schedules after `/reload` and fresh schedules for new runs restore appearance from their official states; the later handoff exception can also preserve those states through an eligible reload. No tests, syntax checks, validation, addon execution or game startups were run for this edit.

## Saved SCT mode and native settings — 2026-10-16

The selected Custom (`on`), Off (`off`) or Game settings (`default`) mode persists in the separate scalar `SurvivorsDragonUiSctMode` SavedVariable. Module initialization accepts only those three mode names and uses `default` for missing or invalid values, preserving native choices on new installations. The game's **Enable Floating Combat Text** checkbox writes the saved `SHOW_COMBAT_TEXT` global; **Show Target Damage** independently writes the `CombatDamage` CVar. The floating-text checkbox controls native incoming/self feedback, while `CombatDamage` gates native outgoing numbers and miss words. Custom outgoing SCT depends on effective `on` mode, either confirmed or previewed in the editor, and native outgoing text being disabled; it has no dependency on `SHOW_COMBAT_TEXT`.

The previous `/sct on` implementation wrote `SHOW_COMBAT_TEXT = "1"` and called the native floating-text updater, which explains why selecting custom outgoing text also enabled received-damage text. The base game's [options adapter](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/assets/ui/OptionsFrame.xml#L36-L43) loads `Blizzard_CombatText` when that global is enabled and updates its displayed messages; its [combat settings rows](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/assets/ui/OptionsFrame.xml#L2231-L2241) explicitly keep outgoing `CombatDamage` separate. The [native outgoing renderer](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/combat_text/mod.rs#L436-L442) observes the outgoing damage CVars. These are base-source evidence, not verification of the packaged game's exact build.

The `/sdui` Custom choice selects custom outgoing SCT and suppresses `CombatDamage` once to avoid duplicate numbers. Off disables custom SCT, suppresses native outgoing damage once and clears custom hits. Game settings disables custom SCT and releases temporary outgoing-preview suppression, otherwise leaving native outgoing preferences in control. Confirm alone saves the chosen addon mode. None of these mode selections writes `SHOW_COMBAT_TEXT`, loads the native incoming-text addon or calls its updater. After `on` or `off`, players who want native outgoing numbers must enable **Show Target Damage** themselves; switching to `default` alone does not turn it back on.

Enabling native target damage selects and saves `default` mode, preventing duplicate outgoing displays. Turning incoming/self floating text off does not clear custom hits or release tracking, and turning it on does not switch saved `off` mode to `on`. Initialization, world entry, `CVAR_UPDATE` and the frame update loop observe native outgoing settings without writing them. Effective custom-state or mode changes clear active and queued hits before refreshing tracking.

The `/sdui` **Combat text** tab presents direct **Custom**, **Off** and **Game settings** outgoing choices and an **Incoming/self text** checkbox. Both preview immediately when clicked. The committed SCT mode remains separate from its effective draft; custom/off previews suppress native outgoing damage once and immediately refresh custom text and tracking. Game settings selects the existing `default` mode and releases the preview's temporary outgoing suppression so the previous native preference applies. The separate incoming/self control immediately writes native `SHOW_COMBAT_TEXT` and applies the shared `BenillaCombatText_UpdateOrLoad` or feature-detected native load/update fallback. Selecting outgoing SCT alone never changes incoming/self text. Confirm saves only the selected mode in the existing scalar SavedVariable and retains the current native choices without reapplying them. The incoming choice uses the game's own saved preference, with no addon SavedVariable.

World leave, logout, reload and both full-reset entry points discard these drafts and restore the confirmed effective mode. Session-only rollback records restore a native value only while it still matches the preview's last write, allowing later native menu changes to take precedence. No rollback record is persisted. Before calling the wrapped real `ReloadUI`, the addon explicitly discards SCT previews so the unconfirmed incoming/self global is restored before the normal reload save. `/sdui reset` and **Addon defaults** preserve the confirmed SCT mode and native incoming choice. The existing **Damage icons** control retains live preview and Confirm-only saving in `SurvivorsDragonUiDisplay`.

World leave and logout release internal nameplate tracking and clear hits. SCT persistence stores only the addon mode, with no native setting snapshot, chat capture, combat hits, plate state or gameplay/API data. No local checks, tests, syntax checks, addon execution or game startups were run for this edit; packaged-game behavior remains unverified.

## Run timer font and text editing — 2026-10-15

The user requested font changes for the top `RUN` label while `/sdui` is active. Its **Run timer** tab previews font face, size, outline and shadow, with the same Confirm/discard lifecycle as layout geometry. The **Run text** control also previews showing or hiding the entire `RUN elapsed / duration` label while keeping the progress pill and boss markers visible. Only Confirm saves the selected font and normalized boolean `showText` in `SurvivorsDragonUiRunFont`, a separate SavedVariable containing the font/text preference. Missing or invalid `showText` values default to shown so older font saves retain their label. `SurvivorsDragonUiLayout` remains geometry-only. World leave, logout and reload discard unconfirmed font/text edits and restore the confirmed choice. **Addon defaults** calls the shared layout reset used by `/sdui reset`: both immediately clear saved geometry and the timer font/text preference, discard all pending edits, restore every registered group's defaults including hidden groups, show the run label, and exit editing without requiring Confirm. Both leave the separately saved SCT mode unchanged. The shared editor can be moved by left-dragging its background while open; its width fits the controls and available labels. Its position is session-only and adds no SavedVariable or layout entry. The shared full reset also recenters the editor.

The available faces are `DEFAULT` and the four client fonts listed in the [base game's font loader](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/ui_text/engine/faces.rs): `Fonts\\FRIZQT__.TTF`, `Fonts\\ARIALN.TTF`, `Fonts\\MORPHEUS.TTF` and `Fonts\\SKURRI.TTF`. The addon run label defaults to shown in Skurri, size 14, normal `OUTLINE`, and a black shadow at `(1, -1)`. Existing confirmed font preferences remain in use until changed or reset. DEFAULT is initialized before attempting a native face, leaving a readable fallback when it is unavailable. No font assets or machine-specific paths are added. The edit bounds include the selected font's label only while shown; hiding it removes that extra text area. Font/text controls do not change native clock takeover, time, phase, schedule readiness, marker visibility, encounters or tally recovery.

No local validation, tests, syntax checks, addon execution or game startups were run. Native-font loading and editing behavior in the packaged game remain unverified.

## Native per-spawn debuffs and display controls — 2026-10-15

The owner's supplied [official reference](AzerothSurvivors-Addon-API-2026-10-15.txt) exposes `AZS_GetDebuffs(id)` for each boss or guardian spawn id. The addon reads that getter for every displayed live boss and awake guardian, including untargeted encounters. It feature-detects the getter and does not use `UnitDebuff`, target changes, names or combat messages to identify encounter auras. A missing getter or unavailable debuff list hides only the icons; valid encounter health bars remain independent.

The getter supplies `spell`, `name`, `icon`, `stacks`, optional `duration` and `remaining`, optional `dispelType`, and `permanent`. Its `remaining` value is worked out on every call from `AZS_GetRunTime()`, so the addon reads it during OnUpdate for smooth countdowns that pause with the native run clock. It never subtracts a private wall clock or invents a duration. Only `permanent == true` means no expiration; missing timing or a nil permanence value remains unknown. Permanent effects have no expiration countdown, and unknown timing does not gain one. `AZSDEBUFFS` announces list changes; an unchanged or paused list stays valid without a timeout. All returned native lists remain read-only.

Rectangular icon frames retain the straight metallic border strips from the health pill, stack counts, and tooltips built from the API's spell name, dispel type and timing. Debuffs sit beneath each pill, wrap within the bar width and expand the movable group's bounds without overlapping the next encounter. Removed effects, unavailable API/data, retired rows, world leave/logout and the off toggle clear icons and owned tooltips. No debuff snapshot or gameplay state is written to SavedVariables. Recovery after `/reload` still requires the client to reinstall its getter and replay the current native debuff snapshot; no request/resync API is documented.

The `/sdui` editor adds **Boss debuffs** (default on) and **Damage icons** (default off). Both preview live through the shared display preference store, including icons on already animating custom hits, without changing SCT mode, animation timing or native outgoing damage text. Confirm alone saves normalized boolean choices in `SurvivorsDragonUiDisplay`. World leave/logout/reload discard drafts; `/sdui reset` and **Addon defaults** clear the preferences and restore both defaults along with the existing full layout/font reset. These display preferences store no gameplay or native data.

This integration requires a matching game build that provides the documented getter. No local validation, tests, syntax checks, formatting tools or game/addon execution were run. Countdown behavior, multi-encounter display and tooltips remain unverified in the packaged game.

## Native talent window — 2026-10-15

The user confirmed that N and the bottom talent button open the correct Azeroth Survivors talent window when the addon is disabled. The addon had replaced the real global `ToggleTalentFrame` with a separate Classic three-tree display and wrapped `UpdateMicroButtons` for that replacement. Removing the replacement restores the game's own talent-opening function and native micro-button updates rather than requiring another client API.

`modules/ui/talents.lua` is removed from source, the TOC and the shared runtime manifest. Its three otherwise-unused header textures are removed with it. The micro-menu keeps its existing talent artwork, geometry and original TalentMicroButton click handler. The general UI skin no longer modifies TalentFrameCloseButton, preserving the game's talent-window close control. The native game owns the talent contents, point spending and window behavior; no hardcoded tree data or addon-specific talent command is introduced.

No local validation, tests, syntax checks, addon execution or game startups were run. The user's disabled-addon observation establishes the available native window; opening it with the updated addon remains unverified in-game.

## Micro-menu click geometry — 2026-10-15

The user reported that the micro-menu icons required clicking toward their bottom-right corner. The native 1.12 micro-button template has an 18-pixel top hit inset for its original 29-by-58 geometry; the compact module resized those buttons to 20 by 30 without clearing that inset. It also reused native state textures without replacing their original anchors. The [native template](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/MainMenuBarMicroButtons.xml#L3-L9) and [state-texture reuse behavior](https://github.com/samwhosung/benilla/blob/358731f95a7eab43861e250280856ecf5d90741d/crates/benilla-ui/src/script/button.rs) support the correction.

Each of the three native buttons now has local scale 1 and zero hit insets, with normal, pushed, highlight and disabled textures explicitly filling the button rectangle. The character disabled texture uses the bundled character atlas. Existing container dimensions/scale, confirmed layout geometry, native character/talent click handlers and native availability remain unchanged. Only source inspection was performed; no local validation, tests, syntax checks, addon execution or game startups were run. Updated in-game click alignment remains unverified.

## Original Main Menu artwork — 2026-10-15

The third micro-menu button uses the gold WoW emblem from the exact original UI foundation, [dbtdsilva's source repository, commit 5c6a63fda03fe9b8fd8219e6c1f65c574679077a](https://api.github.com/repositories/1040377421/commits/5c6a63fda03fe9b8fd8219e6c1f65c574679077a). The three unmodified `media/tex/micromenu/color_micro/wow-*.tga` textures are restored directly from that snapshot. Its [original Main Menu mapping](https://api.github.com/repositories/1040377421/contents/modules/micro/micro.lua?ref=5c6a63fda03fe9b8fd8219e6c1f65c574679077a) uses `wow-regular.tga` for normal, `wow-faded.tga` for pushed and `wow-highlight.tga` for hover, all cropped with `SetTexCoord(36 / 128, 86 / 128, 29 / 128, 98 / 128)`. Disabled artwork reuses the faded icon in grayscale, matching the talent button's disabled treatment while preserving native availability. Original artwork attribution remains in the shipped module and the repository's license remains unchanged.

The reduced menu had assigned the separate LFG eye to Main Menu; those unused eye textures remain removed. Only the three original emblem textures are added to the shared runtime manifest. All button states fill the corrected click rectangle, and Main Menu retains its existing custom menu toggle and shared layout geometry. Source artwork inspection used temporary PNG representations because the image viewer cannot decode TGA; the shipped original textures were not edited. No local validation, tests, syntax checks or addon/game execution were run; final in-game appearance remains unverified.

## Independent waypoint display controls — 2026-10-16

The **HUD** tab in `/sdui` includes **Cache guidance** and **Guardian guidance** checkboxes, both default on. Each choice independently controls its guidance HUD and associated world-map pins. Visibility previews immediately, including on an open map, without clearing a valid selected destination, accepted native snapshots, calibration or confirmed geometry. The existing hidden-group edit handles remain available.

Only Confirm saves the normalized `cacheGuidance` and `guardianGuidance` booleans in `SurvivorsDragonUiDisplay`, alongside the three existing display choices. Missing or invalid values default on. World leave/logout/reload discard unconfirmed drafts, and both shared full-reset entry points restore both guides on. The change adds no SavedVariable, gameplay persistence or SCT mode changes.

Source review covers the independent visibility gates and shared layout lifecycle. The toggle behavior has not been exercised in a running addon; formatting, dead-code and version checks remain in GitHub Actions.

## Integrated player resources — 2026-10-16

The **HUD** tab's **Class resources** choice now defaults off. Enabling it displays the current native active resource inside the player frame: the existing 122-by-29 opening becomes a 19-pixel health fill above a 9-pixel power fill at `(104, -54)`, with the original divider artwork restored. Disabling it or losing valid current native player data restores the full-height health fill. Primary power reads use `UnitPowerType`, `UnitMana` and `UnitManaMax`; they do not require an AZS phase or replayed run snapshot. Native resource frames remain disabled.

The secondary display is attached to PlayerFrame at `(105, -68)`. It moves and scales with health and primary power, with no independent layout registration or saved resource geometry. The owner's 2026-10-20 game update adds `AZS_RUN.proc`, `pv` and `pm`: the addon now reads these received, phase-gated values independently of primary power. Seal Fate and Soul Fire retain the Rogue/Warlock socket artwork for whole-number capacities up to five; Bloodrage, Lightwell and other supported ranges use a compact current / maximum fill in the same row. Missing or invalid proc data hides the secondary display without guessing from active power. The former 20-unit encoding and its pinned executable evidence remain historical in [class resource notes](CLASS-RESOURCES.md#historical-native-game-code-verification--2026-10-16).

The choice previews live, saves only with Confirm in the existing display store, and discards on world leave/logout/reload. Both full resets restore off. No live values, point counts, native snapshots or new SavedVariables are introduced. No local validation, tests, syntax checks, addon execution or game startups were run for these changes.

## Shared SCT icon metadata — 2026-10-17

The supplied screenshots show valid native debuff icons while SCT uses question marks. The first expansion beyond the spellbook learned icons from standard native talents, received phase-gated `AZS_DEBUFFS` snapshots and target/mouseover debuffs. That still depended on observing the effect. The owner's raw combat log identifies `Deadly Poison` correctly on ordinary wolves and kobolds, but the accompanying active-spell list omits that passive and the excerpt provides no encounter-debuff icon snapshot. The game's custom talent screen also uses its own metadata instead of the standard `GetTalentInfo` list.

The final change uses one shared resolver for every class, with no ability or class conditionals. It adds the complete packaged custom talent icon catalog and unambiguous spell-database metadata behind valid live spellbook/aura data. This lets passive effects obtain their published icons without waiting for a target or boss encounter. Learned talent and actual-aura caches stay separate, and metadata scans remain dirty-event-driven and globally throttled to 0.35 seconds. A same-UI-time addon message no longer blocks all sources. Ambiguous names stay unresolved instead of selecting an arbitrary icon.

The shipped catalog contains native names and texture paths only, not binary assets, gameplay snapshots or a runtime dependency. It covers all 354 custom talent records across nine classes and the full supplied spell database; only English name slots were populated in these packaged inputs. Live native observations continue matching their own localized names. Extraction provenance, lookup priority, counts, ambiguity handling and regeneration steps are recorded in [SCT-ICONS.md](SCT-ICONS.md).

No spell-specific fallback is included. Damage parsing, amounts, school text, ownership checks, matching, colors, animation and SCT modes remain unchanged. No local validation, tests, syntax checks, addon execution or game startups were run. Metadata extraction and catalog generation read source data only; in-game resolution remains unverified.

## Duplicate SCT displays with a 75 ms tolerance — 2026-10-17

The user requested that matching SCT numbers appear once, without adding their amounts. After the initial exact-timestamp implementation still showed repeated labels in the supplied screenshot, the user authorized a tolerance and then set it to 75 ms. Three matching `100` damage hits therefore display one `100`, never `300` or an `x3` label. The same identified spell/ability/autoattack, resolved icon and original numeric amount must arrive from the first hit's raw local `GetTime()` through its fixed inclusive 75 ms deadline. This can span update batches. Joining hits never extend the deadline, so hits at 0, 60 and 120 ms form two groups, not one. Source, damage type and school remain part of attack identity. Different targets can share one display; different amounts remain separate. Original amounts stay numeric keys; raw timestamp comparisons use no rounding or epsilon.

Every original event still enters the flat pending queue, updates its damage-color history in native message order and independently resolves/consumes its original health-loss evidence. Groups affect presentation only. A group waits until its intake window has closed and all members finish the existing matching lifecycle, then one label uses the first original hit's unchanged value and style. It follows an enemy only when every member shares the same nonnil origin; otherwise it stays at the fixed centroid of the member positions. Miss labels, aura notices and unidentified unnamed attacks do not collapse or acquire the grouping hold. Intake entries expire strictly after their first-hit deadline even while matching remains pending; identity-guarded cleanup cannot remove a newer group using the same key, and empty buckets are removed. Group queues/maps clear with the existing mode/world reset; compacted arrays retain explicit Lua 5.0 `table.setn` sizes.

The original matching delays still serve matching; 75 ms limits group admission, not total display latency. Each displayed label retains its full animation lifetime. Raw capture, native combat messages and native damage-meter totals are unchanged; no setting, command, SavedVariable or persisted gameplay state is added. No local tests, static/syntax checks, addon execution or game startups were run. Source review and GitHub Actions static results do not establish in-game behavior.

## SCT icon ambiguity by damage school — 2026-10-17

The owner supplied another raw capture and a damage-meter screenshot identifying Thorns. The capture contains 90 named Thorns hits, all explicitly Nature damage, such as `Your Thorns hits Kobold Vermin for 21 Nature damage.` The native spell database has 24 exact-name Thorns rows across three schools and three icons; its old name-only entry is therefore `false`. All 14 Nature rows share the same native icon. Other named outgoing attacks in the supplied capture already have native spellbook or generated metadata candidates; the log alone does not label the rendered question marks.

The shared generator now emits `schools[locale][canonicalSchool][exactName]` only for names that are ambiguous across the full database. It groups every matching row by native School field 1, without spell/class exceptions or arbitrary row selection. The output has 1,460 name/school pairs: 504 resolve to one icon and 956 remain ambiguous. Existing name-only and custom talent mappings retain their meaning; all paths are deduplicated across tiers, producing 841 native paths and 668,345 bytes of generated Lua.

Runtime resolution consults this index only after all stronger native sources are absent and the locale database entry is ambiguous. It uses the actual parsed canonical school, retains ambiguity within that school and does not override conflicts from observed auras, custom game metadata or learned talents. The resolver remains shared across every class and ability. It adds no scans, settings, SavedVariables, assets or gameplay inference, and preserves the 75 ms duplicate window and fixed SCT launch positions.

Catalog generation authored display metadata from the pinned native data files only. No local tests, formatting/static/syntax checks, addon execution or game startups were run; the in-game icon result remains unverified.

## Thirteen-language addon text — 2026-10-18

Addon captions and the existing 69 jewelry-effect templates now use the thirteen native localization catalogs with reviewed compact overrides. `GetLocale()` is only a fallback: the game picker includes languages outside the base client's legacy table. Exact localized names/subtitles in phase-gated official `AZS_ZONE` select a unique catalog after deferred parsing; unknown or tied evidence retains the fallback. There is no assumed language CVar, new native API or client patch. Existing labels refresh without rebuilding controls or losing drafts. Native values, localized caps/proc limits, UTF-8 subjects, raw capture and native item/unit/ability names are preserved. Language adds no saved state. [LOCALIZATION.md](LOCALIZATION.md) records data preparation, text/font/layout behavior and remaining runtime/translation-review limits. No local validation or addon/game execution was performed.

## Empty equipped-jewelry sockets

Empty equipment texture reads show the selected original WoW necklace, ring and trinket inventory pictures over charcoal circles. Their complete source interiors are fitted inside the existing circular openings with padding, using the three existing BLP2 Raw3 runtime textures. The five native slot IDs, gold rims, attached/detached silver artwork, icon frame sizes, positions and existing display/layout controls are retained. Placeholders are separate from the native equipped texture field, so empty slots clear hover and cooldown state and do not read item effects or cooldowns. Actual item textures replace them through the existing five-Hz refresh. Failed reads, missing required APIs/player, disable and world cleanup retain the existing clear/hide behavior. There is no new setting, saved state or sample equipment. Preparation and ownership are documented in [Jewelry-ARTWORK.md](../third_party/Jewelry-ARTWORK.md). Only artwork was prepared and previewed; no local checks or addon/game execution were run.

## Native-window and unused-artwork cleanup

The general UI module no longer skins the quest log or spellbook, adjusts
their close buttons or repositions the quest timer. Their seven dedicated
textures are removed. The game owns its talent window and opening functions;
no addon talent window or header artwork ships. The unused cast-bar and bag artwork is also removed. Their small modules only disable native player/pet cast bars and backpack, bag-slot and keyring buttons.

The micro menu is removed, including its module, layout group, translated
editor caption and seven runtime textures plus their TGA preparation inputs.
The general UI module disables all eight native micro buttons, including later
Show attempts, without creating a replacement container or updater. Native
Character and Talents windows remain available through their key bindings;
Escape retains the existing main-menu behavior. The menu no longer writes
the removed button's pressed state. Existing player/talent pulse suppression
is retained independently of the removed skin. The dated micro-menu styling
notes above describe the earlier implementation and are superseded by this removal.

The unused dedicated pet background and border are removed; current summon
circles continue to reuse the jewelry rim. Unused chat-control artwork is also
removed. The passive scroll indicator keeps its centered status text. The gold
tally retains its original coin atlas, relocated unchanged to
`media/tex/tally/Coins.tga`, with the original gold crop, icon/number spacing,
tooltip above the icon and affordability halo offset.
The shared tally fitter reserves icon space only for fields that have an icon.

The native minimap mail indicator is disabled through the shared unused-frame
helper, including its events and later Show calls. Its bundled texture and
custom positioning are removed.

The arrowless minimap border still uses
`media/tex/minimap/map_dragonflight_square2.tga`. Four passive texture sections
retain the original border while replacing only the top-center arrow region
with a plain span sampled from the same source. There is no separate
arrowless image; the source texture, shadow and zone strip remain in use.

## Optional action-bar gryphons

**Show gryphons** in `/sdui` → **Action bar** starts off. The normalized
`showGryphons` boolean lives in the existing display table, so preview,
Confirm, Cancel, world/logout/reload discard, named profiles and both full
resets use the same lifecycle as the other display choices.

One cropped Dragonflight `Gryphon.tga` supplies both sides, with the right side mirrored.
The pair is created only on first enable and inherits the action bar's
movement, scale and hiding. It retains retail proportions, trims transparent
atlas padding and overlaps the side trim to close the gap beside the bar.
The native button frames remain in front of the decorative textures.
The action-bar bounds helper combines the visible ornament extents with
jewelry, XP and tally extents without changing the bar owner or saved
geometry. Jewelry reports its upper extent through the same helper so
changing its attachment cannot overwrite the ornament bounds.

The caption and hint have source/runtime entries in all fourteen languages.
No per-frame updater, extra layout key or SavedVariable is introduced.
Artwork provenance is in [XP-ARTWORK.md](../third_party/XP-ARTWORK.md).
