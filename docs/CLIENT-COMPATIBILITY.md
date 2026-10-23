# Client update compatibility

The reported regression followed the Azeroth Survivors client update. The supplied changelog identifies 0.101.0 as the move to a newer client and Lua 5.0 behavior. The screenshots show `SetText(): Font not set` in the player and target modules, an incomplete layout entry at `core/layout.lua:730`, and the client's 48 MB script-memory popup. They do not establish the exact engine commit packaged by the game or the allocation responsible for the memory popup.

## Fonts and incomplete layout registration

The addon previously passed the literal filename `DEFAULT` to `SetFont` throughout its HUD, editor and chat. Current client code checks whether a font file loads, returns nil without changing the receiver when it does not, and rejects `SetText` on an uninitialized FontString. See the pinned [WeNilla font loader](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/font_block.rs) and [FontString text binding](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/region/text.rs). The same behavior remains in current BeNilla.

This explains the reported source path: player and target health labels are created without an inherited font and their failed font assignment was followed by `SetText`. Layout labels used the same sequence. Registration had already added an entry to the shared update list before constructing its handle; an error in its label therefore left `entry.handle` nil for the later update loop. A failed module also skipped the positioning and hooks that followed its failed caption.

`core/fonts.lua` now resolves the game default once at file load, before factories or modules construct captions. It retains `DEFAULT` on clients that accept it; otherwise it tries the native `GameFontNormal` face, the native standard-font filename, and the original client's bundled Friz Quadrata file. The probe checks the native assignment result and its font getter without writing text. Every addon default-font assignment uses this shared resolved face, including native font globals; the Run timer's existing selected-face fallback remains in place. No external font is installed or shipped.

Layout entries become visible to the update list and native visibility wrappers only after their anchors and complete handles have been constructed. A new handle starts hidden. This prevents a failed handle setup from creating the repeated nil-handle error.

The additional reported missing UI follows these same initialization dependencies:

| Reported symptom                        | Affected source path                                                                                                                                                                                                |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Missing player/target health text       | Their new value FontStrings use the rejected default-font assignment before their first health `SetText`.                                                                                                           |
| CleanerChat presentation absent         | Its first custom captions require a loaded default font; a failed caption stops `Chat` setup. Native chat can remain visible.                                                                                       |
| Jewelry textures absent                 | `Jewelry` registers its layout handle before attaching its hidden HUD to the action bar and enabling inventory texture refresh. A failed handle caption aborts those steps even when the texture files are present. |
| SCT text absent                         | Its pooled damage FontStrings use the same default-font assignment before the first damage label is written.                                                                                                        |
| Nameplate text absent                   | Both the copied-name FontStrings and native `NAMEPLATE_FONT` previously used the rejected alias.                                                                                                                    |
| Kills, gold and cache-cost tally absent | `RunTimers` registers its run-timer and boss-bar handles before creating the three tally fields. A failed handle caption prevents tally creation.                                                                   |

This maps the reports to source-level failure paths; visibility and texture rendering still require confirmation in the packaged game.

The first installed fix exposed another native-handle difference: `Fonts` stopped at `core/fonts.lua:36` with `stale or invalid widget handle` while scanning globals. A retained wrapper can expose `GetObjectType` but raise when called. Each native font candidate is now inspected and updated within its own protected call, so a retired widget cannot abort the rest of the pass.

## Native chat resize error

The supplied screenshot reports `FloatingChatFrame.lua:600: Frame ChatFrame1 is not resizable`. The addon marked each attached native chat frame non-resizable but hid only a control named `ResizeButton`. The pinned [original FloatingChatFrame XML](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML/FloatingChatFrame.xml) instead defines eight edge/corner resize buttons. Their mouse handlers call `FCF_Resize`, whose [native Lua implementation](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML/FloatingChatFrame.lua#L600) calls `StartSizing` on the parent. Those untouched buttons could therefore invoke sizing on a frame the addon had made non-resizable.

Chat setup now permanently hides all eight controls through the existing control-hiding helper, retaining `ResizeButton` support for other client layouts. It restores the native frame's XML-declared resizable capability. The separate `/sdui` container still owns chat position and dimensions; native events, history, hyperlinks, wheel scrolling and message formatting remain in place. No FrameXML globals are overridden and no error handler is suppressed. This is a source-reviewed correction; local checks and addon/game execution were intentionally not run, so live behavior remains unverified.

## Lua 5.0 closure limit

The subsequent supplied reload screenshot reports `modules/ui/run.lua:1761: too many upvalues (limit=32)`. This is a compiler rejection: the combined HUD update captured more locals than Lua 5.0 permits, so the whole `RunTimers` module was unavailable before any of its initialization ran. That independently explains the absent run clock, encounter bars and kills/gold/cache-cost tally. The earlier font errors also affected these paths where compilation succeeded.

The update now calls separate boundary and clock helpers. Each helper captures only its own dependencies, and the small coordinator still checks native phase before reading retained tables, updates run boundaries before the clock, and refreshes the tally/encounters last. Native timing, schedule continuity, takeover/release and reload handoff behavior are preserved. No captured state becomes global or saved, and no native compiler limit is bypassed.

## Screen-unit rounding

BeNilla [#1946](https://github.com/samwhosung/benilla/pull/1946) changed frame sizes, positions, screen extents and cursor coordinates to the original client's screen-unit conversions. [#1962](https://github.com/samwhosung/benilla/pull/1962) extended them to font sizes, shadows, insets and other lengths. Native getters can now differ slightly from the Lua values passed to setters: a width of 100 can read back as 99.99999850988391 at 4:3 or 100.00000136774479 at 16:9, as documented in the upstream [source cases](https://github.com/samwhosung/benilla/blob/adbfedc3660d/crates/benilla-ui/src/script/tests/screen_units.rs).

Layout and chat now compare these values with one finite-number tolerance instead of continually reapplying nominally identical anchors, dimensions, fonts and insets. The existing effective-scale conversions, confirmed normalized positions and independent group geometry remain authoritative. There is no resolution cutoff or replacement coordinate system. These changes address source-level causes of incomplete or repeatedly invalidated layout; they do not establish visual alignment on any particular monitor.

## Anchor-sized edit regions

The later action-bar and chat screenshots expose a separate size-contract mismatch, larger than float rounding. Native `GetWidth`/`GetHeight` return authored local dimensions when nonzero, but an automatically sized axis returns its resolved span without dividing by effective scale. Edge getters do divide that scale. This distinction exists in both the examined [WeNilla implementation](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/object/layout_methods.rs) and [BeNilla implementation](https://github.com/samwhosung/benilla/blob/adbfedc3660d/crates/benilla-ui/src/script/object/layout_methods.rs); it is not a claim that the later float-rounding changes introduced the distinction.

The edit regions are sized by opposite anchors. Treating their returned spans as local dimensions scaled them again: at UI scale 0.9, the chat edit region's actual 521-by-372 local bounds, including the 32-unit footer, read as 468.9 by 334.8. The outline therefore became 90% of the intended size. A source-calibrated regression reproduces the action region at 280.8 physical width with a 252.72-wide old handle.

The shared `GetLocalSize` helper now measures rendered local bounds from right-minus-left and top-minus-bottom, retaining raw getters only while edge geometry is unavailable. Handles, resize diagonals/opposite corners, numeric screen-center calculations and dialog width clipping use those extents. Explicitly authored sizes, native chat input ownership, artwork and fonts remain as before. Saved-position normalization retains its existing denominator; no confirmed coordinates are reinterpreted, cleared or migrated.

The committed [geometry regression](../tests/layout_geometry.lua) passes 73 assertions across four UI scales and four group scales. The prior layout implementation fails 41 of those assertions. It covers action/chat outlines, chat footer bounds, numeric centers, corner resizing and confirmed-position preservation. The earlier geometry adapter assumed uniformly local size getters and missed this native distinction; the new fixture explicitly models both getter paths.

## Defaults shifting after a new run

The owner reported that Addon defaults looked correct, but the run timer, chat, micro menu, minimap and waypoint HUDs shifted left/up after ending the run and entering again, without making further edits. The account save file contained the reset correctly: empty layout geometry and cleared display/timer-font choices. An empty layout is the intended saved representation of code-defined defaults.

The examined [native startup sequence](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-app/src/ui_script/lifecycle.rs) loads addons and emits `ADDON_LOADED` before applying the saved UI scale. The addon's Layout Ready initializer had already captured default positions at the earlier scale. The first layout update skipped viewport-change recovery because it had no previous viewport sample, then reapplied those stale positions. Pressing Addon defaults during a run recalculated them at the current scale, but a fresh UI session repeated the earlier capture.

The first valid layout update now recalculates authored default anchors just as a later viewport change does, before applying current geometry. Confirmed records still use their existing normalized coordinates; neither startup nor world transitions save, clear or reinterpret them. Addon defaults still applies immediately without Confirm, while later custom edits still require Confirm. This corrects default-position reconstruction rather than changing SavedVariables serialization. The expanded geometry fixture passes all 175 assertions. Before this startup fix, 18 assertions reproduce shifted defaults for the reported groups, both on first entry and after a fresh session following Addon defaults; confirmed geometry remains unchanged.

## SCT numbers ending in dots

The supplied screenshot shows orange critical values such as `1...` and `10...` alongside complete normal-hit numbers. The addon passes the full `tostring(value)` to `SetText`; it does not abbreviate damage amounts. Its FontString had only a center anchor and no explicit dimensions. The surrounding 240-by-60 visual frame does not give that FontString its text box.

The native [text extraction path](https://github.com/Arnesen/wenilla/blob/6934a85c5da7b304b42b9aae5f65410401b94653/crates/benilla-app/src/ui_script/extract/text.rs) ellipsizes a region's string when its wrapped lines exceed the region bounds. Natural-width measurement and the rendered shadow use different scale factors, so an exact automatic width can be too narrow during the critical pop. Rasterized natural width can also change with scale.

SCT now applies the visual scale before measuring each new label and refits when that scale changes, including critical/miss animation and live size preview. Each label receives `ceil(GetStringWidth()) + 4` local units of width and a 36-unit line box for the 18-unit font. The getter already returns local natural width, so it is not divided by effective scale again. Width writes are cached. If native metrics are temporarily unavailable, a 240-unit provisional width is used and measurement is retried during normal updates; pooled labels are fitted again even when their scale is unchanged.

Centering, adjacent icons, full original values, hit matching/grouping, launch positions, colors, lifetime and motion remain as before. No text is abbreviated or edited to remove dots after rendering. This change was reviewed from source; its local checks and addon/game execution were intentionally not run under the standing policy. GitHub Actions checks formatting, local dead code and TOC metadata; live rendering remains unverified.

## Lua globals and memory

BeNilla [#1792](https://github.com/samwhosung/benilla/pull/1792) removed the native `_G` global. The addon supplies `_G = getfenv(0)` inside its private module environment through `DFRL:GetEnv()`, but `modules/chat/prettify.lua` defines helpers directly at file load and had not entered that environment. Its reads of learned-ability, level-up and self-loot format globals therefore raised. The chat wrapper's protected call preserved the raw message, explaining the supplied screenshot's unformatted level announcements, stat gains and learned Gouge notice without a visible Lua error. The prettifier now enters the same private environment before defining its helpers. No native global alias or extra formatting category is added.

BeNilla [#1782](https://github.com/samwhosung/benilla/pull/1782) enabled the original client's `scriptMemory` enforcement. Its default 49,152 KB limit covers the whole Lua state, including the game interface and all addons. The client attempts collection, shows the supplied popup if usage remains over the limit, and may exit after 15 seconds. [#1788](https://github.com/samwhosung/benilla/pull/1788) subsequently aligned the accounting with 32-bit Lua 5.0 object sizes. WeNilla's [upstream merge](https://github.com/Arnesen/wenilla/commit/024ae5882e44) includes these Lua and memory changes.

The screenshot alone cannot attribute those allocations. This fix removes the font/layout error cascade and redundant native writes; it does not claim to prove or eliminate script-memory exhaustion. The requested complete session diagnostics remain uncapped and session-only. The addon does not change the game's memory limit, discard capture records or alter other addons.

## Target debuff placement

**Target debuffs on top** in `/sdui` → HUD defaults off. When enabled, the target's native debuff rows grow above its frame, while buffs stay below. The setting uses the existing display preview, Confirm, Cancel and reset behavior.

The integration follows the original [1.12.1 target-frame code](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML/TargetFrame.lua): `TargetDebuffButton_Update()` manages both aura types and only rewrites selected row anchors. The addon changes those same TOPLEFT points, preserving native icon sizes and horizontal chains. Calling the native updater restores every changed point when the option is disabled. Buffs use the native friendly-target anchor so they do not follow the moved debuff rows. No additional per-frame aura scan is added.

The hook is feature-detected. The packaged game's FrameXML was not extracted, and live placement remains unverified; this contract comes from the pinned original source. No local checks or game execution were run.

## Party target health

The target module formerly forced every health-color write to red, including
selected party heroes. It now uses one shared live-alias helper to distinguish
the player and `party1` through `party4`. Both units must exist and native
`UnitIsUnit` must return true or 1; names and class are not identity evidence.
These aliases receive green health through native color writes and the
existing target refresh path. Other Survivors targets retain enemy red.
Target and world changes, health/faction updates and party membership changes
refresh the choice without an idle updater or saved subject.

Target-of-target uses the same party-alias helper before its existing reaction
color choice. Its tapped-NPC gray, non-party reaction colors and dead/absent
cleanup remain in place. Unit existence, native health values, target selection,
clicks, portraits, visibility and geometry are unchanged. Native co-op color
transitions still require in-game verification; local addon execution was not
performed.

## Evidence limits

The initial investigation and fixes used the supplied screenshots/changelog and read-only source inspection. The user subsequently authorized a full local validation pass on 2026-10-19. That pass compiled all tracked Lua with stock Lua 5.0.3, checked the package and formatting, and exercised actual modules through focused native-API adapters. It found and fixed an additional UTF-8 literal-matching defect; see the [validation report](VALIDATION-2026-10-19.md).

No game was started. The existing GitHub Actions workflow still performs formatting, local dead-code and TOC metadata checks only. Stock Lua and adapter results do not establish packaged-game startup, memory use, native rendering or appearance on particular monitors; these still require game-side confirmation.
