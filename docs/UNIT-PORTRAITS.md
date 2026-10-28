# Unit frames

**Hide portraits** in `/sdui` → **Unit frames** switches the player,
target and target-of-target to closed health bars without their portrait
pictures or gold rings. Names, levels and health values keep their native
updates. The separately selected class resources remain available.

## Guardian and boss dragons

Guardian targets use the silver winged dragon. Bosses and the final boss use
the gold winged dragon. These are the already-bundled
`UI-TargetingFrame-RareElite.blp` and `UI-TargetingFrame-Boss.blp` sheets;
the portrait, health bar, width handles and native clicks keep their existing
geometry. **Hide portraits** hides the dragon with the rest of the portrait
border. The static artwork stays the same in Performance Mode.

Known guardians and bosses select their dragon immediately on target selection,
without waiting for the next `AZSTGT` health packet. The target-health owner's
separate `GetBorderKind()` lookup uses the current target's exact localized name
and native maximum health against the received `AZS_UNITS` encounter roster.
The complete roster is validated before copying cosmetic kind/maximum metadata;
it is bounded to forty entries and rejects duplicate IDs, malformed fields and
known guardian/boss/elite collisions. Only living published entries participate.
Sleeping guardians remain eligible even while they cannot be attacked.

Maximum matching reuses `T.IndexUnitMaximum`, shared with the nameplate filter:
original and exactly rounded float32 values, native ceiling/uint32-clamped
values and their float32 storage, plus the bounded upper-ceiling publication
preimage. There is no tolerance, percentage estimate or name-only match.
Unknown, absent or ambiguous signatures retain native classification artwork
until a valid target publication identifies them. A roster match is cosmetic
evidence, not a spawn-ID binding; an unlisted ordinary enemy with the same name
and native maximum cannot be distinguished by these APIs.

The existing target-health owner still copies authoritative `AZS_TARGET.kind`
only after accepting the phase, publication, name, spawn ID and health fields.
`GetKind()` retains that strict contract, and its result takes precedence over
the cosmetic roster lookup. Selection, invalid packets and hiding clear the
accepted target source without discarding the current-run roster, allowing
immediate retargeting. Cosmetic matching never supplies health, assigns spawn
identity, changes the damage-loss baseline or reuses a retired target packet.
The official `AZS_UnitKind` helper is not a shortcut here: its same-name target
path can still read the previous `AZS_TARGET` publication.

`AZSUNITS` and `AZSRUN` receipts use the existing controller's one deferred
callback. It settles parser readiness and checks phase/run rollback even when
hidden, then skips hidden roster/target reads. The first visible selection can
prepare already-received metadata synchronously. Table/stamp/receipt caches
prevent unchanged alias rebuilding; a copied roster remains stable while
ordinary packets are pending. Zone/world retirement, inactive phases, observed
run-clock rollback and language changes discard the roster and block its old
publication. New roster data refreshes the existing border listener even when
the target packet has not changed. No polling loop or separate controller is
added.

The classification cache still binds textures only when the selected sheet
changes or a native rebuild requires repair. It reuses the existing rim/health
border strips, alpha bounds and hidden lifecycle, with no new region, asset,
event, updater, setting or saved state. CI-only mocks cover immediate selection,
packet handoffs, exact aliases/collisions, hidden recovery, retirement and
accepted target precedence. Local source review and pinned formatting do not
establish native event order or in-game appearance.

## Target health and compact numbers

Enemy targets use the official `AZS_TARGET.hp` and `hpm` publication for their
health label, whole-number percentage, fill and damage-loss animation once it
arrives. Selecting a target first shows its validated current native
`UnitHealth` / `UnitHealthMax` immediately, so the bar and labels do not stay
empty while the packet is in transit. Those temporary numbers retain the
client's native limits. Accepting the full-precision publication replaces that
source and resets the loss baseline; the handoff never animates as damage. This
avoids the legacy `UnitHealth` / `UnitHealthMax` unsigned 32-bit ceiling of
4,294,967,295. The native StatusBar receives a 0–1 fraction and retains its own
texture UV handling, geometry and clicks. Later native capped writes are
translated through the same accepted health source.

`modules/unit/health.lua` owns one current publication. It checks the native
phase first, requires a published timestamp, validates finite current/maximum
health, the enemy kind and positive spawn ID, and matches the exact native target
name. `AZSTGT` requests a single deferred read after the native parser. Target
changes, zone/world retirement and inactive phases clear the old source and loss
baseline; the retired table/stamp/receipt tuple cannot return. Switching between
identically named creatures still requires a fresh target publication instead
of treating a name match as a GUID; only the newly selected native unit supplies
temporary health. A late mismatched packet cannot replace that current unit's
health. Invalid native health/maxima remain empty, and an invalid packet after
an accepted AZS source clears it without reverting to capped values. World/zone
retirement and inactive phases do not enable the selection fallback.
Player/friendly targets retain native getters;
clients without the phase API retain native health. An accepted AZS enemy
publication stays authoritative when that creature becomes unattackable.

Hidden targets cancel pending reads and active loss, skip health presentation
and resume from the current publication with a new loss baseline. Changed
maximum health or spawn identity also resets the effect. Damage still uses the
original full counters and the existing half-second fade, never abbreviated
text or combat messages.

Unit-health labels and boss/guardian current/maximum labels share K, M, B and T
for thousands, millions, billions and trillions. Examples are `1.2K`, `15.1B`
and `70T`; values below 1,000 remain whole numbers. Formatting truncates to at
most one decimal and removes a trailing `.0`, so `999,999` stays `999.9K` until
the actual million boundary. T remains the largest suffix. Percentages and bar
fractions always use full health values.

Retail exposes a [configurable number formatter](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/StringUtilDocumentation.lua)
with [magnitude breakpoints](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AbbreviatedNumberFormatterAPIDocumentation.lua).
This legacy-compatible adaptation uses the requested fixed K/M/B/T tiers and
precision; it does not import retail APIs or locale-dependent suffix catalogs.
The installed client's embedded `AZSTGT` parser was inspected read-only and
still parses `AZS_TARGET` fields through `tonumber`, without a 32-bit conversion.
Its executable SHA-256 was
`522e1c831b3b4627875a28a1030368ef9d2e7f98c5606c34cb30448d3b7d776e`.
Only source review and pinned formatting were performed locally. CI-only mocks
are authored separately; actual client rendering and event order remain
unverified.

## Player absorbs

The player health bar shows active absorbs automatically as a pale-blue
segment. There is no separate setting, and **Class resources** can stay off.
The segment starts after current health when there is room. When health plus
the shield exceeds maximum health, it moves left inside the bar so the shield
is still visible at full health. Its width represents shield / maximum health,
capped at one full bar. Existing health labels continue to show health only.

The shared player-resource reader uses the official `AZS_RUN.sh`, `hp` and
`hpm` fields after checking `AZS_GetPhase()` and a published `AZS_RUN_UPDATED`.
It never derives absorbs from buffs, spell descriptions or combat text. Zero,
missing or invalid shield/health data clears the segment. Inactive phases,
new zones and world cleanup retire the previous run publication; the same
table/stamp/receipt tuple stays blocked until native data changes. Hidden
player frames clear the segment and defer presentation until visible again.
Run packets request a deferred read through the existing resource controller.

The segment inherits the actual health rectangle, including width handles,
portrait modes and the optional resource row's height. It lazily reuses the
prepared health-fill image below the gold border and health text, leaving
native StatusBar UVs, values and clicks unchanged. No setting, artwork,
SavedVariable, event subscription or updater is added. Appearance and live
shield changes remain unverified in-game.

## Names, levels and editor layout

**Show player name**, **Show player level**, **Show target name** and
**Show target level** independently control the four native captions. The
normalized `showPlayerName`, `showPlayerLevel`, `showTargetName` and
`showTargetLevel` booleans default true in the existing display table. They
reuse live preview, Confirm-only saving, Cancel/world/logout/reload discard
and both full resets to on, independently of portrait and resource choices.

One shared `BindUnitLabelVisibility` helper masks only each FontString's alpha.
Native text and Show/Hide decisions continue; later native alpha requests are
retained and become effective when the option is on. The helper never shows
an inactive target, clears its caption or changes the frame's geometry.

Unit frames has no scroll frame. Its ten controls occupy five rows in two
columns, starting with player name/level and then target name/level. Each row
is 60 units within the existing 396-unit page. Column width is measured against
all fourteen caption and hint catalogs; existing descriptions keep their two-line
space. The shared editor still fits the viewport, and other pages retain their
existing layouts and scrolling behavior.

## Settings and layout

The normalized `hidePortraits` boolean defaults to false in the existing
`SurvivorsDragonUiDisplay` table. It uses the shared live preview and Confirm-only
saving. Cancel, world leave, logout and reload discard the preview; both full
resets restore visible portraits. No SavedVariable or gameplay state is added.

Round player portrait and 3D Portrait retain their confirmed
choices while hidden. Their editor controls are dimmed until portraits return.
The model renderer treats hidden portraits as disabled, releases existing
copies and rejects late model callbacks. Still portraits remain transparent,
including when model creation is unsupported. Showing portraits restores the
chosen still or 3D model behavior through the existing readiness gates.

Unit roots retain native handlers and the existing saved/draft position and scale rules. Independent health widths use the same Layout records.
The large bars remove only the overlap beneath the absent portrait, preserving
their outer edge and original label area. The optional player resource row and
existing damage-loss fractions follow the health span. Health fills, values,
native target availability and target-of-target updates remain authoritative.

## Health width handles

Player, Target and Party frames have left/right side handles in Layout. Dragging changes the horizontal health span; it does not scale the portrait, gold end caps, bar height, fonts, aura icons or models. The existing corner handles still scale proportionally. Party's width applies to all four native rows together, including their edit outline while inactive. Its native row/pet anchor chains and unit clicks stay intact.

Player and target use compact edit regions around their visible border art and enabled name/level captions, rather than the native roots' transparent canvas. Width grips sit at the middle of that outline's left/right borders. The shared helper reads prepared nonzero-alpha bounds for the pointed, round, boss, elite and rare sheets as static metadata; classification and portrait-mode changes select the appropriate bounds. Hidden portraits use the existing closed-border frame plus the enabled caption height. The native root, input, saved position/scale and independent health-width value stay unchanged. Corner scaling and Shift alignment measure this same compact region. Target bounds also include its currently shown native aura buttons through the existing tooltip-owned aura registry, so the border does not cross visible icons. Aura measurements run only while editing. Auras and attached pets retain their native attachment and input.

The shared Layout root stores `width` beside its position/scale. Let `delta` be the chosen root width minus its original native width. Player and target content becomes `122 + delta`, with portrait overlap and one-unit render underlap added separately. The player retains its 15-unit round or two-unit pointed overlap. The target uses seven units: its right fill/background edge moves eight UI units left from the former 15-unit overlap, toward the inside edge of the gold ring. Its far-left edge, health text positions, portrait and border stay fixed. This reduces the hidden portion of the health fill without claiming to remove the circular ring's entire overlap. Source columns 0–33 keep the outer cap's native size while columns 33–152 extend the straight horizontal artwork. The portraits and their original rim crops retain their sizes. The target still follows its rim even when its native anchor was expressed from the root center or left side. The player's status pulse and resting animation stay with its fixed portrait area rather than shifting to the widened root center.

**Hide portraits** continues to remove only the existing overlap and display the shared closed border attached to the actual health rectangle. It does not reset the chosen width. Pointed and round player rims, native 2D/optional 3D portraits, health values/percentages, names, levels and damage-loss fractions keep their existing owners. A shown resource strip follows the health span at its original height. No target-of-target or pet-frame width control is added.

Party's 128-unit artwork is split at columns 44 and 112: the portrait portion and outer end retain their size, and the middle span takes `delta`. Its existing health-only artwork retains the exact divider-removal crops, splitting only the top/bottom horizontal spans at column 112. The native 35-unit portrait stays at its original position relative to that fixed portrait portion. Native health/resource values remain unchanged; optional resource strips follow the wider housing. Names gain the same horizontal room without changing their fonts.

Player/target limits leave at least 64 units of original health content; party limits leave at least 40 before its existing resource-off extension. Each group allows up to 800 units beyond its native root width. Defaults and both resets retain the original dimensions. Side dragging holds the opposite visible border edge fixed; shared Confirm, Cancel/world/logout/reload discard and profiles keep their established behavior. Width changes use existing Layout callbacks and unit events, without a new preference, SavedVariable, asset or updater. Hidden presentation defers until Show, with required edit geometry refreshed on editor entry; inactive party bounds still fit all four rows.

## Artwork

**3D Portrait** enables the existing independent player, target and
target-of-target models. Their native rectangular viewports are centered inside
the existing portrait circles. For portrait diameter `d`, each viewport is
`(d - 2) / sqrt(2)` units square, keeping all four corners inside the ring.
The 3D view is therefore smaller than the original full-width model viewport;
this is containment, not a circular model mask. Native cameras and animations
remain in charge, with no race offsets or additional copies.

Twenty-two passive native `WHITE8X8` strips form a round near-black background
at alpha `0.72`, beneath each 3D model and the existing gold artwork. The outer
edge of each strip fits inside the circle; no rectangular background protrudes
past it. The backing inherits model visibility, so disabling 3D, hiding portraits
or retiring a model removes it too. The existing model update checks changed
portrait dimensions and skips unchanged geometry; no updater is added.
Still portraits remain the fallback until the existing model callback provides
copy and viewport evidence. The legacy `playerPortrait3D` preference and all
preview, Confirm, Cancel, reset and world/reload cleanup paths are retained.

The shared `CreatePortraitlessBorder` helper closes both ends with mirrored
pieces of the existing `UI-TargetingFrameDF1.blp` straight metal edge. Source
columns 24–32 provide end caps; columns 32–136 provide horizontal spans. Rows
29–34 and 63–67 supply the top and bottom pieces. The sides stretch only the
clean 35–49 span, excluding the old resource-divider stub from both mirrored
ends. Corners keep their size while the straight spans follow each bar. This
applies to player, target and target-of-target, independently of Class resources;
the player's optional resource row and native values remain unchanged. No new
asset is shipped.

The ordinary portrait sheets are hidden while this border is active. The small
target-of-target hides only its sheet strips, retaining its foreground health
and dead text. Player portrait pulses and the resting icon remain hidden while
portraits are off. Native primary pet and summon frames are unaffected.

## Verification

The edited Lua and Markdown were formatted locally with the pinned repository
formatters. No local tests, standalone syntax checks, addon execution or game
launches were run. The supplied mockup and later screenshots guide the intended
appearance; exact rendering, containment and native callbacks remain unverified
in-game.
