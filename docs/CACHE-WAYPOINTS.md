# Cache, guardian and fallen-ally waypoints

Cache and guardian waypoints add independent guidance HUDs and minimap markers using the official coordinates supplied in the owner's updated addon documentation on 2026-10-15 and the subsequent `AZS_RUN` world-position/facing update. Cache guidance requires `AZS_CHESTS` and `AZS_CHESTS_UPDATED`; guardian guidance requires `AZS_LAIRS` and `AZS_LAIRS_UPDATED`. Both require the native active run phase. Received `AZS_RUN.px`/`py` and `pf` supply direct world guidance on supported builds, including instances; zone/map identity is additionally required for map projection and the older map-based fallback. Install them as part of SurvivorsDragonUi; no companion process or client modification is required.

## Player behavior

**Fallen ally guidance** reuses this same HUD, arrow and minimap pin system with
the selected **02 Winged Soul** artwork. A 32-unit blue/white spirit icon accompanies
the exact native member name and distance; each eligible fallen ally also has a
20-unit minimap pin, clamped to the edge when distant. The guide chooses a nearby
member and keeps that selection until it becomes unavailable, then chooses again.
Its default bottom sits eight units above the jewelry's upper edge, using the
action bar's shared static artwork bounds. Move, scale or hide **Fallen ally
waypoint** in the shared Layout editor. Existing saved positions remain in use;
move the guide there if an older saved position overlaps the jewelry.

The default-on `partyGuidance` and default-off `mirrorPartyWaypoint` choices live
in the existing display table. Both support preview, Confirm-only saving,
Cancel/world/logout/reload discard, profiles and both full resets. Turning this
guide off clears its live roster and skips party reads; enabling waits for a
fresh native sample. No member positions or death state are saved.

The existing ten-Hz/deferred controller prefers the proposed
`AZS_GetDownedPartyMembers()` when that function exists. It copies at most four
members by opaque native ID and validates the complete snapshot before accepting
positions. World X/Y/Z can be zero; map, run and coordinate-space identity must
match the current validated `AZS_GetPlayerPosition()` reading. Matching absent
run IDs are accepted where the player-position contract permits them. This path
needs no map UVs and can guide inside instances and to a released hero's
native revive location. It never uses a moving ghost's position.

An empty native snapshot removes guidance. A failed/unavailable snapshot or an
unavailable location hides it; neither falls back to old map coordinates while
the new getter is present. The current read replaces the last position. Revival,
disconnect, map/run changes and world cleanup retire the guide. Native API
availability and actual instance behavior remain unverified.

When the getter is absent, the original `party1`–`party4` map path remains:
connected, dead, non-ghost units with a rechecked native name and readable UVs on
the confirmed current-zone sheet. Unsupported instance maps, `(0, 0)` map UVs
and missing calibration still hide the map arrow/pins or show **On map**. No
last-alive or historical location is substituted.

### World icons (native API)

**Waypoints** also has three independent world-icon switches. **Icons above
caches** and **Icons above fallen allies** default on; **Icons above guardians
and bosses** defaults off and includes final bosses. These switches retain live
preview, Confirm/Cancel, profiles and both resets. They are independent of the
HUD/minimap guidance switches.

**Only show affordable caches** defaults off. Enable it to show a world cache
icon only when the latest received native gold covers the next cache cost.
Equality and a free cache count as affordable. Missing or invalid gold/cost data
hides cache icons while this filter is on. The option dims when **Icons above
caches** is off and retains its choice. It shares preview, Confirm/Cancel,
profiles and both resets; HUD/minimap guidance and other world icons keep their
existing behavior.

Icons require the five documented general world-anchor endpoints and version-one
capabilities in [the released API](AzerothSurvivors-Addon-API.md#world-anchors-version-1).
Discovery uses opaque handles; guardians/bosses follow the actual living entity,
not the fixed lair. Encounters use the native `overhead` point with six UI units
of screen padding. Cache and fallen-ally icons use `position` with the same
documented world offset `{ z = 5 }`: their centers sit five yards above the
cache or revive spot, without extra screen padding. Both have 22.4-unit sides,
30% smaller than their former 32-unit icons. These two kinds require advertised
world-offset support; encounter icons remain usable without it.
Only kinds with their required advertised attachment are requested. No
nameplate matching or old screen point is substituted.

Discovery finishes every page in one bounded controller pass; cursors never
cross frames. Complete catalogs replace the queried kinds atomically. Valid
handles continue projecting each native post-camera frame while periodic
discovery checks for new entities and delayed guardian classifications. A
`CATALOG_CHANGED`, first-read `NOT_READY` or malformed refresh keeps the last
valid handles; their native projection still decides whether they can be drawn.
These failures do not release the callback or publish a partial list. Explicit
world/context/stream changes retire the old handles. `STREAM_CHANGED` clears
old icons immediately; expired and unknown handles stop receiving projections.

Only marker kinds that can currently be shown are requested. The affordability
filter skips cache discovery and projection while gold is insufficient or
unknown; disabled encounter kinds do not start the native enemy scan. Known
empty parties skip ally requests. Hidden UI and disabled features do no marker
API reads. Existing handles, artwork bindings and pooled frames are reused.
Options update through the existing settings listener, and repeated failures
back off instead of flooding the provider. Visible recovery reads fresh data.

Only current post-camera projections place icons. Offscreen/behind-camera,
expired and unavailable anchors hide. Native world projection makes cache and ally
height follow distance and camera perspective. Occlusion is unsupported, so markers
can show through walls. Collected caches and revived/departed allies are removed
by the next complete native catalog or native handle retirement. The released
reference defines the accepted schema; installed-game delivery and appearance
remain unverified.

The native party-position contract is documented by
[benilla worldmap.rs at 0259668](https://github.com/samwhosung/benilla/blob/0259668162cd2674730e078f5bf3def4cf4dfb35/crates/benilla-ui/src/script/worldmap.rs#L953)
and its [party map tests](https://github.com/samwhosung/benilla/blob/0259668162cd2674730e078f5bf3def4cf4dfb35/crates/benilla-app/src/ui_script/world_map_tests.rs#L245).
The same snapshot's [unit bindings](https://github.com/samwhosung/benilla/blob/0259668162cd2674730e078f5bf3def4cf4dfb35/crates/benilla-ui/src/script/unit/bindings.rs#L318)
read native dead/ghost object flags; a released ghost is no longer `UnitIsDead`.
`AZS_GetRevive` supplies only the local interaction; `AZS_GetPartyMeter` supplies
ranked totals. Neither is a remote corpse-position feed. Installed-game delivery,
map support and rendering have not been verified through execution.

- Cache and guardian guides reconsider the nearest available destination every five seconds. A new nearer spawn or player movement can change the selected destination at the next check; an exactly equal distance keeps the current choice. Initial selection, removal of the current destination and showing a hidden guide can choose immediately. Direction, distance and minimap updates keep their existing responsive cadence. While position data is unavailable, the current valid destination or first available entry keeps the overlay visible with "On map", and nearest selection retries on the same five-second schedule. Disabled or Layout-hidden HUDs defer this selection work until shown. The two selections remain independent; there is no full world-map overlay or click-to-track control.
- Each waypoint has its own horizontal floating-label guide, 190 by 46 at its default size. An upright 32-by-32 icon sits beside two left-aligned text lines: the full Cache or Guardian title in DEFAULT 13 above distance in DEFAULT 15. The guardian HUD uses the gold-dragon/skull medallion `GuardianFloating.tga`, and the cache HUD uses the supplied `Chest.blp`. The icon and text have transparent backgrounds, with no bottom stripe, rectangular fill or enclosing border.
- Cache defaults to the left of that action-bar/XP stack and **Guardian** to the right, vertically centered on its combined artwork span with an eight-unit horizontal gap beyond the artwork edges. Registration waits for the bar/XP appearance metadata, after which shared layout handling converts these defaults to independent UIParent positions. Confirmed custom positions remain in use, and unrelated layout stays untouched.
- The selected **05 Quest spear** direction arrow rotates in place to the right of the text by default. `HudArrow.tga` retains Blizzard's original 32-by-32 quest-arrow canvas, whose visible glyph is 21 by 23 pixels. The full canvas draws at `24 * 32 / 23` square (about 33.39 units), matching the selected preview's 24-unit glyph height and about 21.91-unit width. Cache, Guardian and fallen-ally guidance share only this replacement arrow; their existing icons, labels, positions, mirroring, native directions and both Performance Mode lifecycles stay unchanged. Both cache and guardian guides show straight-line horizontal distance in yards from native world coordinates when available, otherwise when native map geometry establishes the scale.
- **Mirror cache waypoint** and **Mirror guardian waypoint** in `/sdui` → **HUD** independently move each arrow to the left and its icon to the right, with right-aligned text between them. Leave a mirror option off for an arrow on the right. Both default off and preview immediately, including while guidance is hidden. Confirm saves the choice; Cancel, world leave/logout/reload discard drafts, and both full resets turn mirroring off. Either combination is supported, including both arrows on the same side. Mirroring preserves the guide's position, scale, shape, distance and direction.
- Guardian coordinates describe the fixed lair, not the guardian's moving combat position. The visible label is **Guardian**; its distance and direction still refer to the lair, including while its guardian is fighting elsewhere.
- **Guide to next respawn** under `/sdui` → **Map & navigation** defaults off. When enabled and every guardian is defeated, Guardian guidance points to the lair with the shortest known native respawn timer. A timer of zero takes priority; equal timers keep the current lair. Unknown timers or missing coordinates cannot supply a destination. Any received living guardian takes priority again. This works with defeated minimap icons and minimap timers turned off. The option retains its value but dims and disables while Guardian guidance is off.
- Move and uniformly resize each guide independently through `/sdui`, then click Confirm to save geometry. Uniform resizing preserves the 190:46 shape. Their existing layout keys remain `cacheWaypoint` and `guardianWaypoint`. Each guide hides with its own unavailable waypoint; the two containers remain separate. Unconfirmed geometry uses the existing discard behavior. `/sdui reset` and Addon defaults restore both default anchors and sizes. The two visibility choices share the existing display preference store; no separate SavedVariables are added.
- **Cache guidance: on/off** and **Guardian guidance: on/off** in `/sdui` independently control each guide's HUD and minimap markers, both defaulting on. Guardian guidance also controls the guardian minimap markers and hides the native flag as described below. Changes preview immediately. Confirm alone saves `cacheGuidance` and `guardianGuidance` in `SurvivorsDragonUiDisplay`; missing or invalid older choices default on. Turning a guide off keeps its valid destination, accepted snapshots, calibration and geometry, and its layout handles remain available. Turning it back on restores the current valid selection. World leave/logout/reload discard unconfirmed visibility drafts. Both full resets restore both guides on together with their default geometry.
- Selection, positions and map calibration are session-only. No cache, guardian or other gameplay state is added to SavedVariables.

`guardianRespawnGuidance` is a normalized default-false boolean in the existing
display table. It previews from the accepted lair snapshot immediately, saves
only with Confirm and follows shared Cancel/world/logout/reload discard,
profiles and both full resets. Changing the option reselects from cached native
data without another lair publication or native timer read. Only the preference
is saved.

**Keep defeated guardian icons** in `/sdui` → **Minimap** defaults off, preserving living-only minimap markers on new installations and upgrades. When enabled, minimap markers also include accepted empty lairs with native `id == 0` and finite coordinates. These markers use the killed-boss appearance: an 80%-size medallion at 70% opacity with the same green native checkmark. A received living guardian restores the full-size, opaque medallion without a checkmark. The guidance HUD's next-respawn fallback is independent of this minimap choice. Guardian guidance continues to control all guardian markers.

The normalized `keepDefeatedGuardianIcons` boolean belongs to the existing display table and profiles. It previews immediately, saves only with Confirm, rolls back through Cancel/world/logout/reload and resets to off through either full reset. A separate copied minimap list is built during normal snapshot acceptance, keyed by lair index plus the supplied id, without keeping dead spawn identities or inventing occupants. Empty snapshots, retired runs and unavailable geometry use the existing marker cleanup. No gameplay data is saved.

## Data and geometry

Each guide defaults to `HUD_WIDTH = 190` and `HUD_HEIGHT = 46`. Default appearance metadata supplies the anchors: action artwork top is `55 + native action-button height + 14`; XP border bottom is `49 - (6 + 12) / 2 = 40`. Cache and guardian guides use that combined artwork span's vertical midpoint. Their left/right horizontal center offsets from the default bar center are `bar width / 2 + side inset 6 + gap 8 + HUD_WIDTH / 2`. The ally guide sits above the action bar, with its bottom eight units above the greater of `topInset` and the shared `jewelryTopInset` (`buttonWidth * 40 / 36`). Registration waits for this static metadata and lets shared layout convert the defaults to independent UIParent positions. Moving or resizing live action-bar or XP groups does not change the guides' dimensions or default anchor calculations; confirmed custom waypoint geometry and unrelated layout remain in use.

The renderer copies each cache's official run-local `id`, world `x`/`y` and map `mx`/`my` without mutating or sorting the native lists. It reads phase before retained tables and hides guidance while ready/between runs or dead. A numeric `AZS_CHESTS_UPDATED` identifies a received snapshot; an initially empty placeholder is not treated as confirmed data. On initial loading after `/reload`, the stream's own stamped data can restore guidance before zone data arrives. A received empty list removes all cache pins. Cache and zone last-change timestamps are independent: no ordering across packet prefixes is used to accept or reject a snapshot. Paused and unchanged data remains valid indefinitely, without a stale-feed timeout.

An observed active-to-inactive transition or world leave clears guidance and blocks the old raw table reference until a replacement table or matching `AZSCHESTS` packet confirms new receipt. Once zone context is established, a later `AZSZONE` or zone-identity change retires the last accepted reference unless that stream's matching prefix has been received since acceptance. This preserves a fresh destination snapshot arriving in the same event batch as its zone update. Initial zone-data arrival does not create a new requirement to wait for another destination snapshot.

These are best-effort protections around observed boundaries. The native API has no run id, so the addon cannot prove full run identity or reliably detect a boundary it never observed. It does not persist private snapshots to conceal that limitation.

Guardian guidance follows the same snapshot and lifecycle rules independently through `AZS_LAIRS`/`AZS_LAIRS_UPDATED` and `AZSLAIRS` packets. It accepts only `asleep` or `awake` lairs with a positive guardian `id`; both states represent a living guardian. Each copied record uses `index` plus guardian spawn `id` for identity and the lair's official coordinates for geometry. A replacement guardian in the same lair receives a new identity. Empty/refilling lairs are omitted from living guidance. The optional minimap list can include their accepted coordinates; a received empty list removes every marker. The addon never estimates a living guardian's current position from its lair or changes its selection through gameplay actions.

Read-only `GetWorldLocMapPosition(mapId, x, y)` and current-sheet coordinates remain navigation inputs for HUD distance and scale calibration. The addon never changes an open world-map selection. Missing or unrelated-sheet coordinates fall back to received world positions; no layer, cache/guardian pin, map tooltip or click handler is added to the full world map.

Navigation reads the received `AZS_RUN` snapshot, gated by an active native phase and numeric `AZS_RUN_UPDATED`. Finite numeric `px` and `py` share the caches' and lairs' world coordinate system in yards: X points north and Y points west. The destination offset is therefore east = `py - target.y`, north = `target.x - px`; horizontal distance is the square root of the sum of their squares. Zero coordinates are valid. The published `pz` is height, but these guides retain horizontal distance and do not use it for vertical navigation. Finite numeric `pf` supplies native facing in radians, zero north and increasing counterclockwise, including zero itself. The existing arrow rotation combines this heading with the destination bearing.

Direct world distance, nearest-destination selection and facing do not need `GetPlayerMapPosition`, a selected map sheet, map-scale calibration, a minimap model or zone metadata. They remain available while browsing another map and on instance maps, including Scarlet Monastery, Blackrock Mountain, Naxxramas and Ahn'Qiraj, when the game publishes the new fields and destination snapshots. Navigation reads the native values without predicting movement or persisting player position. Paused or unchanged received data remains valid without a timeout.

## Mirrored HUD layout

The existing `SurvivorsDragonUiDisplay` table stores only two additional normalized
booleans, `mirrorCacheWaypoint` and `mirrorGuardianWaypoint`; missing or invalid
values default false. Shared display editing owns preview, saving, rollback and
resets. No additional SavedVariable or layout record is introduced.

One `LayoutHUD` helper reflects the existing children within the same 190-by-46
frame only when its effective mirror choice changes. The arrow pivot moves from
x=163 to x=27; icon and text anchors reflect across the frame, retaining their
sizes and vertical offsets. The two text lines change justification; glyphs
and icon artwork stay upright. Native bearing/facing and arrow
UV rotation stay unchanged. The per-frame direction updater rotates the arrow
without overwriting its selected side. Accepted snapshots, selections, map and
minimap pins, calibration and interpolation state remain independent of mirroring.

## Smooth HUD updates

### Native version 1 live positions

When `AZS_GetMeterCapabilities()` advertises `liveInstancePosition`, navigation
uses `AZS_GetPlayerPosition()` for the current native rendered-frame world
position and facing, including instance maps. Cache/lair copies retain their
`runId`, `mapId` and `spaceId`; all three must match before their world offsets
are used for selection, floating guides or minimap pins. One synchronous
navigation sample shares the validated position across consumers. Successful
reads stay fresh each frame; typed failures defer for the native retry delay
without retaining an old position. Zero coordinates are valid.

Native offsets carry no sampled-presentation timestamp, so movement is direct
in both Performance Mode states. No cosmetic pin tween or movement prediction
is added. Advertised-API errors, missing getters and mismatched coordinate tags
hide/defer affected guidance instead of substituting older run packets. Accepted
snapshots remain available for readiness recovery. Legacy clients retain the
map/run-snapshot paths described below; map-only fallen-ally coordinates still
use the existing confirmed-sheet path. See the
[API contract](DAMAGE-METER-AND-INSTANCE-PLAYER-POSITION-API.md#35-azs_getplayerposition).

The HUD's `OnUpdate` already runs every rendered frame, but repeating a received `AZS_RUN` position does not make that packet's coordinates live. The earlier world-coordinate change preferred those sampled values even where a native per-frame position was available, making the rounded yard label and arrow step at the packet cadence.

Visible guides now first try the native current-sheet player map position with confirmed physical map geometry, and the native minimap model's per-frame facing. These live readings update the displayed distance and direction every frame. Browsing another sheet, missing scale or unavailable instance map coordinates retains the official world-coordinate path; missing native facing retains `pf`. The addon never changes an open world map to obtain a live reading.

For sampled values only, each guide blends its display distance, bearing and heading toward the latest received values on every frame. The transition uses the interval between that stream's run snapshots, capped at 0.5 seconds; angular changes take the shortest turn across north. Each transition stops at its received endpoint without extrapolating speed or predicting movement. Rounded whole-yard labels and their localized units remain unchanged. Native snapshot and map values remain the inputs to automatic selection and pins; interpolation affects only presentation.

First readings, source switches, changed destination identity/coordinates, non-playing phases, frame gaps over 0.5 seconds, new sample gaps over one second and offset changes over 32 yards snap to current data. Missing values clear their affected interpolation channels; hidden or removed guides and world/run cleanup clear all guide paint state. Pause/choosing/victory never continues a movement tween. Unchanged or paused snapshots remain valid; these animation reset limits do not expire destinations or hide valid data. All interpolation state stays in memory with no new controls, assets or SavedVariables. Snapshot-only instances still depend on the game's publication cadence for fresh measurements; display blending does not increase that cadence.

Older builds or missing/invalid fields retain the existing fallbacks independently: player map coordinates plus native geometry for offsets/distance, and the native minimap player-arrow model for heading. Geometry calibration consumes only copies accepted by the renderer's snapshot/lifecycle rules; navigation never independently reads the raw cache or lair lists. Native world-to-map projection probes can determine the zone's physical axis spans from one accepted cache or lair point. When those probes cannot establish scale, distinct accepted official world/map coordinate pairs can establish it. Observed boundaries clear calibration along with rejected destination data. Unknown fallback scale hides direction arrows and never produces a fabricated yard distance. Both guides keep their central marker and destination/distance text visible. Minimap markers below reuse the accepted destinations independently of the selected floating guides.

## Guardian and cache minimap markers

Guardian guidance shows one upright gold-dragon/skull medallion for every living guardian in the accepted lair snapshot, independently of the native flag, floating guide selection and world-map selection. Both `asleep` and `awake` lairs qualify when their guardian spawn id is positive. Each marker uses lair index plus spawn id, so death, an empty lair or a replacement removes the old marker. By default no marker is drawn for empty/refilling lairs. **Keep defeated guardian icons** extends only this minimap list to accepted empty lairs with native id zero. The snapshot reader never independently calls the raw native list getter or infers guardians from proximity.

Minimap markers reuse their tracker's HUD artwork and crop: `GuardianFloating.tga` at 20 by 20 local units for guardians, and `Chest.blp` with full texture coordinates at 16 by 16 for caches (20% smaller). Retained empty-lair medallions shrink to 16 by 16 while preserving the 20-by-20 marker bounds and edge clamping. `core/widgets.lua` shares the defeated-icon size, alpha and checkmark styling with timer bosses; the checkmark stays fully opaque above the faded artwork. The accepted empty-lair copy retains its native `state`, and appearance writes run only when that state changes or a pooled marker is reused. Recycling hides the checkmark and invalidates its cached appearance. They are mouse-transparent children of `Minimap`, inheriting its confirmed position and scale. Each guardian marker uses accepted lair coordinates and native player offsets in yards, stays upright and clamps independently inside the square map edge when distant. These are fixed-lair markers; they cannot follow a guardian moving during combat. Cache guidance shows every accepted available cache within range using its run-local id. Off-map caches hide; opened or retired caches disappear. Both kinds share drawing and cleanup helpers with separate reusable frame pools. The optional empty-lair choice uses the existing display table; it adds no asset or separate SavedVariable.

The reference [Survivor UI release](https://github.com/morderous/survivor-ui/releases/tag/v3.0.11) demonstrates custom texture overlays in its [pinned MapPins implementation](https://github.com/morderous/survivor-ui/blob/5a63e4fe75d86d4be8b020a9499860aa466709f1/SurvivorUI/MapPins.lua). No code or artwork is imported. Geometry comes from the [native renderer's zoom constants](https://github.com/samwhosung/benilla/blob/a6dbffd8e7591b3d400ac1c9a2b0d5e0d7f50b59/crates/benilla-ui/src/widget/kinds/mod.rs#L941-L958): outdoor diameters are chunk counts 14, 12, 10, 8, 6 and 4 times one 33.3333-yard chunk; indoor diameters are 300, 240, 180, 120, 80 and 50 yards.

The client has no Lua indoor-mode getter. Distinct `minimapZoom` and `minimapInsideZoom` settings let `Minimap:GetZoom()` identify the active mode. When equal, a guarded runtime measurement steps the active zoom once, reads which setting changed and restores the original zoom before rendering. It verifies restoration and caches the result until a world, zone or minimap mode/zoom event. Missing geometry or an unsuccessful measurement hides custom markers. It does not change the user's world-map selection or measure on every frame.

The 0.102.0 HUD API allows hiding the native flag through `AZS_SetHudShown("flag", false)`. While in world with Guardian guidance enabled, the addon captures its prior visibility and keeps it hidden, including when every lair is empty or dead, snapshots are unavailable or marker geometry cannot be resolved. Flag ownership is separate from marker cleanup, so snapshot refreshes cannot briefly restore it. `AZS_GetFlaggedLair()` and each row's `flag` field are no longer needed for marker selection. The prior native preference is restored when Guardian guidance is turned off, on world leave/logout and before reload preference serialization. Visibility drafts retain accepted snapshots and guide selections. This needs the official HUD visibility APIs; live rendering remains unverified because local checks and addon/game execution were intentionally not run.

## Artwork and limits

Guardians use `GuardianFloating.blp`, the gold-dragon/skull medallion shared by their HUD, minimap and tracker header, with the existing `0..65/128` crop on each axis. The supplied `Chest.blp` serves the cache HUD, minimap markers and bottom cache-cost counter with full `0..1` texture coordinates, and `HudArrow.blp` supplies the rotating direction arrow. The retired full world-map overlay and diamond runtime asset are removed. See [CacheWaypoints-ARTWORK.md](../third_party/CacheWaypoints-ARTWORK.md) for source artwork and preparation details.

This implements minimap markers and HUD guidance. It does not project icons above caches or guardians in the 3D world; no such camera/projection API is documented. It also does not calculate walkable routes, account for walls or provide vertical navigation. Guardian guidance does not track a moving guardian beyond the fixed lair coordinates exposed by the API.

Missing native snapshots, player position or heading hide the affected guidance rather than inventing it; map geometry is needed only for navigation sampling and fallback guidance. `AZSCHESTS` sends the full remaining-cache list whenever it changes, including cache spawns and openings. `AZSLAIRS` updates occupied, fighting and empty/refilling lair state; occupied living guardians supply normal destinations, with the earliest known empty-lair respawn used only when all guardians are defeated. After `/reload`, the game must reinstall/replay the relevant official API state, including when paused or unchanged. Received run and destination snapshots can restore direct guidance before zone geometry replays, but a missing cache or lair snapshot must wait for another native update. There is no documented addon-side resync request, and cache/guardian gameplay data is not persisted across reloads.

The world-map removal received manual source/diff review and pinned formatting.
No local tests, standalone syntax/validation checks, addon execution or game
startups were run. Runtime behavior remains unverified in the packaged game.
