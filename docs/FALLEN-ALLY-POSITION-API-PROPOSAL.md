# Proposal: party positions and general world anchors

Status: the released API reference supplied on 2026-11-02 supersedes this
historical proposal and the preliminary provider notes below. See the
[official world-anchor contract](AzerothSurvivors-Addon-API.md#world-anchors-version-1)
and [current SDUI integration](#sdui-integration-with-the-released-api).
The proposal remains as design history; it is not another accepted wire format.
Actual installed-game timing, placement and performance remain unverified.

## Purpose

Expose authoritative world positions for downed party members and a general
world-anchor projection API. This would support direction and distance guidance,
icons above living enemies, markers where enemies fell, and markers over caches,
guardians, bosses and guardian lairs in open-world zones, dungeons and raids.

`GetPlayerMapPosition(unit)` depends on map projection data and can return
`0, 0` inside instances. `AZS_GetPlayerPosition()` already provides the local
player's world position on those maps. The missing equivalent is a world-position
feed for downed party members. `AZS_GetRevive()` provides revive state and
progress, without remote positions.

## Downed-party position getter

```lua
local members, err = AZS_GetDownedPartyMembers()
```

Return a detached, complete snapshot of the other currently downed heroes in
the caller's party. An empty list means there are no matching members. Return
`nil, err` when the snapshot itself is unavailable, following the existing
native API error conventions.

Each entry would contain:

| Field                       | Type                  | Meaning                                                                                                                                                      |
| --------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`                        | string                | Opaque, stable native member identity; preferably reuse the existing hero/actor identity.                                                                    |
| `name`                      | string                | Native display name. Names are captions, not identity keys.                                                                                                  |
| `positionAvailable`         | boolean               | Whether an authoritative downed location is currently available.                                                                                             |
| `x`, `y`, `z`               | number                | World position in yards, using the same axes and units as `AZS_GetPlayerPosition()`. Present together when `positionAvailable` is true.                      |
| `mapId`, `runId`, `spaceId` | existing native types | Coordinate identity matching the existing player-position contract. Supplied with an available position; `runId` follows that contract's presence rules.     |
| `anchorId`, `anchorStatus`  | string                | General world-anchor handle when ready; otherwise an explicit unavailable status with no handle. Independent of whether raw world coordinates are available. |

A known downed member whose location is unavailable remains distinguishable
from a revived or departed member: return `positionAvailable = false` and omit
the position and coordinate-identity fields. Do not substitute a guessed
location or use zero as an unavailable sentinel; zero is a valid world coordinate.

### Required behavior

- Use the game's authoritative downed/revive location. It must describe where
  another player can revive that member, independently of corpse animation or
  a released ghost's movement.
- Work without zone-map coordinates, an open map, targeting or a visible
  nameplate. If the game retains the downed location when the member's object
  leaves rendering range, keep that authoritative location available.
- Match positions to the local player's native map, run and coordinate space
  before they are used together. Never present data from a previous run or map
  as current.
- Remove a member when revived, disconnected, removed from the party or no
  longer downed. Read current state after reload rather than replaying expired
  downed entries.
- Preserve valid downed locations while paused or choosing cards. Getter calls
  must have no gameplay, targeting, map-selection or HUD visibility side effects.
- Return bounded current-party data. Reading or modifying the returned tables
  must not modify native state or another caller's snapshot.

### Acceptance cases

- A living observer can obtain another member's downed location in both an
  open-world zone and an instance where `GetPlayerMapPosition()` returns `0, 0`.
- Moving or turning changes the observer's relative direction and distance
  while the authoritative downed location stays correct.
- Revival, disconnect, party changes, map/run transitions and reload retire or
  restore entries according to current native state.
- Unavailable positions, temporarily unavailable snapshots and an empty list
  remain distinct. Valid zero-valued world coordinates remain usable.

## General world-anchor API

### Supported entities

Provide anchors for the following independently identifiable native entities:

| Entity                     | Anchor behavior                                                                                                       |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Downed party member        | The actual downed/revive location; retired when revived or no longer eligible.                                        |
| Living enemy               | Follow that exact enemy's current rendered position, including ordinary enemies and elites.                           |
| Fallen enemy               | Retain the confirmed death location, even if the corpse animates, disappears or its nameplate is removed.             |
| Cache                      | Its authoritative world location until collected or removed.                                                          |
| Guardian                   | Follow the actual guardian while it moves; retain its confirmed death location under the fallen-enemy lifetime rules. |
| Boss, including final boss | Follow the actual boss while it moves; retain its confirmed death location under the same rules.                      |
| Guardian lair              | Its fixed location, separate from its occupant; an empty lair remains an eligible location while it exists.           |

These anchors must work without selecting the entity, showing a nameplate or
dealing damage to it. Discovery may expose only entities and locations the
native game actually knows; unknown positions must remain explicitly unavailable.
An enemy disappearing without a confirmed death must not become a fallen-enemy
marker.

### Discovery and identity

```lua
local capabilities, err = AZS_GetWorldAnchorCapabilities()
local page, err = AZS_GetWorldAnchors(query, cursor, limit)
```

The proposed query filters entity kinds and native lifecycle states, including
living and fallen enemies. Discovery must cover ordinary enemies as well as
special enemies; the existing special-enemy list alone is insufficient.

Capabilities advertise `apiVersion`, supported kinds and attachments, a
post-camera handler flag, `playerDistanceMetrics`, maximum entries and projections per call, and the
fallen-enemy retention time and capacity. A maximum of 256 entries/projections
per call would match the existing combat-text batching model; callers use the
advertised limits.

Each discovery page supplies a coherent catalog identity, world epoch,
coordinate context, entries, `nextCursor` and `hasMore`. Pagination must not
silently mix catalog revisions or omit entries while claiming completion.
An invalidated cursor produces an explicit error so callers can restart
discovery. Partial pages are not complete absence/removal evidence.

Each record provides:

- An opaque `anchorId`, entity kind, display name and native lifecycle state.
- An explicit reference to its existing native identity where available:
  party-member identity, enemy spawn/life identity, cache ID or lair index.
  Document the mapping to combat-text `targetId` if it is a different identity.
- World position and `mapId`, `runId`, `spaceId` when available, with the same
  units and identity rules as the downed-party getter.
- Available attachments and explicit position/anchor readiness.
- An expiry or retirement reason for retained fallen-enemy anchors.

An enemy life, a cache and a lair are distinct identities, even if their names
or numeric IDs match. Reused spawn IDs, a revived enemy, a new run or a new
occupant of the same lair must never redirect an old enemy handle. Callers do
not parse handles or match entities by names or icons.

Existing downed-party, cache, lair, guardian and boss getters may also expose
these same optional `anchorId` handles. Repeated discovery returns the same
valid handle for the same entity lifetime; reading must not allocate another
anchor or extend its retention.

### Batched projection

```lua
local projection, err = AZS_ProjectWorldAnchors(requests)
```

Each request contains an `anchorId` and an attachment:

- `"position"`: the authoritative entity, downed, death, cache or lair location.
- `"overhead"`: the game's native overhead-label point, based on the actual
  entity's size or bounds. This is the attachment for an icon above an enemy.

Attachments must be explicitly supported. If the provider cannot supply the
requested point, report it as unavailable rather than inventing a height.
Optional finite world-space offsets in yards may be supported separately from
an addon's own screen-space icon padding.

Project from current native poses through the current camera. The result
contains `apiVersion`, `worldId`, `cameraSampleId`, `clockSeconds`,
`frameCurrent` and one entry per request in the original order. All batches in
one frame share the same camera sample.

| Entry field                     | Meaning                                                                                                                                                                                        |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `anchorId`, `attachment`        | The requested identity and attachment.                                                                                                                                                         |
| `state`                         | `onScreen`, `offscreen`, `behindCamera`, `clipped`, `notReady`, `unavailable`, `expired`, `unknownAnchor` or `worldChanged`.                                                                   |
| `entityState`                   | The known native lifecycle state, including alive, downed or dead where applicable.                                                                                                            |
| `x`, `y`                        | `onScreen` only: offsets from `WorldFrame`'s bottom-left corner in UI units.                                                                                                                   |
| `cameraDistance`, `cameraDepth` | `onScreen` only: straight-line distance and forward depth from the camera in yards.                                                                                                            |
| `playerDistance`                | `onScreen` when known: straight-line world distance in yards from the local player's origin to the entity's resolved base position. Independent of camera position and overhead-label offsets. |
| `uiUnitsPerYard`                | `onScreen` only: scale at that depth for optional distance-based icon sizing.                                                                                                                  |
| `occlusion`                     | `visible`, `occluded` or `notTested`, when the optional occlusion capability is supported.                                                                                                     |
| `reason`                        | An explicit unavailable/retirement reason, such as collected, revived, removed, age, resource limit or unsupported attachment.                                                                 |

Coordinates must work with
`SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", x, y)` at the current viewport
size and UI scale. Other states contain no usable screen coordinates. Turning
away hides an icon; turning back can reveal the same still-valid anchor.

Projection tests the camera view. Terrain or wall occlusion is a separate,
optional request capability with an explicit result. Callers opt into any
additional occlusion work. If it is not tested, document that markers can
appear through walls; do not present camera frustum visibility as proof of an
unobstructed line of sight.

### Frame timing and callback ownership

```lua
AZS_RegisterWorldAnchorFrameHandler(handler)
AZS_UnregisterWorldAnchorFrameHandler(handler)
```

Run each registered handler once per world frame, after camera movement and
before drawing. Require `frameCurrent = true` for screen placement. Ordinary
`OnUpdate` runs before camera movement under the existing combat-text contract
and is insufficient for icons that must stay aligned while turning.

The implementation may share the existing combat-text post-camera machinery,
but registration and removal must preserve other callbacks and isolate handler
errors. Paused gameplay still projects through camera movement. Loading, world
leave and reload invalidate old-world projections and handles explicitly.

### Lifetime and resource limits

General anchors must be independent of combat-text events and their five-second
hit-anchor lifetime. A living enemy, cache or lair stays eligible while its
native lifecycle remains valid. Fallen-enemy positions have their own advertised
bounded retention; repeated reads do not refresh that deadline. Capacity
retirement reports `resourceLimit` instead of reassigning an old handle.

Retain a confirmed death position independently of the corpse object. For a
living entity whose current position becomes unknown, return `unavailable`
rather than drawing at an old position as though it were current. Cache
collection, party revival/departure, confirmed removal without death and
world/run changes retire the corresponding handles. Corpse removal does not
end a confirmed death marker's retention. Each new downed episode receives a
new anchor even when the member identity is unchanged. Lair lifetime remains
independent of occupant life.

Provider reads have no targeting, camera, gameplay or HUD-setting side effects.
Publish resource bounds and cursor/epoch recovery rules. Callers can filter
discovery, reuse handles and batch only the markers they currently need.

### Example: an icon above an enemy

Here `enemy.anchorId` comes from native discovery and `icon` is a caller-owned
UI frame. The names below remain proposed API names.

```lua
local requests = { { anchorId = enemy.anchorId, attachment = "overhead" } }

local function PlaceIcon()
    local projection = AZS_ProjectWorldAnchors(requests)
    local entry = projection and projection.entries[1]
    if projection and projection.frameCurrent and entry
        and entry.state == "onScreen" and entry.occlusion ~= "occluded" then
        icon:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", entry.x, entry.y + 6)
        icon:Show()
    else
        icon:Hide()
    end
end

AZS_RegisterWorldAnchorFrameHandler(PlaceIcon)
-- On cleanup: unregister this same function and hide/release the icon.
-- AZS_UnregisterWorldAnchorFrameHandler(PlaceIcon)
```

This draws a screen-space icon anchored above the entity in the world, following
camera movement. Its image and size remain the caller's choice. The same
projection contract supports death-location markers and cache, guardian, boss
and lair icons. It does not require inserting a new model into the 3D scene.

### Projection acceptance cases

- A marker above an unselected, unhit living enemy follows the correct entity
  while it moves, independently of nameplate visibility.
- Camera movement, turning, zoom, UI scale and viewport changes preserve
  alignment in both open-world and instance maps, including while paused.
- Camera-only changes leave `playerDistance` unchanged. Player or entity movement
  updates it from the current native positions, independently of attachments.
- A confirmed enemy death retains the correct location after corpse animation
  or removal. Reused identities and new lives cannot inherit that marker.
- A guardian marker follows the moving guardian while a separate lair marker
  stays at its fixed location. Bosses, final bosses and caches project correctly.
- Downed-party revival and cache collection retire their markers promptly.
  Offscreen/behind-camera/unknown positions provide no stale screen coordinates.
- Multiple callers share native handles without invalidating one another's
  tracking, and each unregisters only its own handler. Pagination changes,
  expired handles, resource limits, world changes and reload have explicit,
  bounded recovery behavior.

## Player-relative combat-text scaling

Distance-based size controls need player-to-enemy distance separately from
camera projection. Camera depth and camera distance change when zooming or
rotating even if the player and enemy remain in the same places.

Please also extend the existing combat-text API, without changing its signatures:

```lua
local capabilities = AZS_GetCombatTextCapabilities()
-- Proposed optional capability: capabilities.playerDistanceMetrics == true

local projection = AZS_ProjectCombatTextAnchors(anchorIds, "follow")
-- Proposed optional on-screen entry field: entry.playerDistance
```

The current documented `distanceMetrics` flag covers camera metrics; it must
not be reinterpreted to promise player-relative distance. Advertise the proposed
`playerDistanceMetrics` capability explicitly in both projection APIs.

For `follow` anchors, measure from the local viewing hero's current world origin
to the exact enemy's current world origin. After confirmed death, use its retained
death location. For `impact` anchors, measure to the retained impact location.
Use a straight-line 3D world distance in yards, excluding decorative overhead
height and screen offsets. The reference is the local hero even when a pet,
summon or totem caused the hit.

Use the same native frame sample throughout a batch. Camera rotation, zoom,
pitch, camera collision and UI scale must not change this scalar when the player
and destination are stationary. Player movement, enemy movement and movement
relative to a retained death location must update it. Zero is a valid distance.
If the player or destination position is unknown, omit the field explicitly
rather than supplying a camera distance or an old measurement.

For example, a consumer could preserve its chosen size within 20 yards and
shrink farther text to a readable 55% floor:

```lua
local factor = 1
if entry.playerDistance and entry.playerDistance > 20 then
    factor = math.max(0.55, 20 / entry.playerDistance)
end
```

Consumers must first validate a supplied distance as finite and nonnegative.
Without the new capability or a valid distance, retain the chosen text size.
World/death anchoring and camera-driven screen placement continue independently.
Neither `cameraDepth` nor `cameraDistance` is a substitute for player distance.

Expose this metric directly on the existing combat-text projection results;
adding it only to the new general-anchor API would leave current SCT consumers
without it. No per-hit enemy-name lookup or general-entity catalog scan is needed.

Acceptance cases include a stationary player/enemy with camera-only changes,
player-only movement, enemy-only movement, pet hits viewed from the hero,
movement relative to a retained death location, zero/unavailable distances and
older providers without the optional capability.

## Existing API compatibility

The current `AZS_ProjectCombatTextAnchors()` and combat-text frame handlers
already establish screen units, camera timing, batching and hit-anchor behavior.
Use those conventions for the proposed general API while keeping their existing
signatures, camera metrics, hit retention and subscribers unchanged. The
player-relative metric is an optional extension. The position getters and
general anchors above are proposed additions; the current combat-text API does
not by itself provide persistent entity discovery or all of these marker types.

## Provider behavior reported on 2026-11-02

These are historical notes from the provider developer's earlier message. The
released reference supplied later on the same day takes precedence, including
its advertised world-offset support and 60-second fallen-enemy retention:

- Occlusion and world-space offsets are optional and unsupported; capabilities
  report them false. Markers can show through walls.
- `overhead` works for units. Cache, lair and downed-party overhead requests
  return unavailable with `unsupportedAttachment`; callers must not invent a
  world height. SDUI therefore chooses `position` for caches/downed allies and
  adds only screen-space icon spacing. Encounter units retain `overhead`.
- All pages of one discovery pass must be read in the same frame. Frequent
  catalog revisions during enemy deaths invalidate older cursors with
  `CATALOG_CHANGED`. Existing handles remain valid independently of catalog
  revisions, so a failed discovery refresh must not discard them.
- Native guardian classification can lag by up to about 0.2 seconds because
  `AZSUNITS` arrives at most five times a second. The same handle can first be
  classified as an ordinary enemy; periodic discovery must pick up the later
  native classification without guessing it from names.
- The enemy scan starts lazily on the first enemy request. That first call can
  return `NOT_READY` for one frame. Retry through the existing reader rather
  than restarting the marker owner.
- Enemy corpses last about 1.2 seconds. A longer frame hitch can hide a death
  from discovery and produce no fallen-enemy marker, without producing a false
  one. SDUI does not request general fallen-enemy markers. This statement does
  not establish a lifetime limit for native downed-party positions or the
  separate combat-text anchors.

The released reference now confirms the endpoint and payload definitions.
It advertises `worldOffsets = true`, while occlusion remains false. SDUI does
request the shared five-yard upward offset for caches and fallen allies,
with no occlusion or general
fallen-enemy discovery.

## SDUI integration with the released API

The authoritative source is the user-supplied `addon_docs(2).md`, preserved
verbatim in [Azeroth Survivors: Addon API](AzerothSurvivors-Addon-API.md).
The runtime consumer and CI fixtures use that released contract, replacing the
previous provisional profile rather than probing alternate names.

### Capabilities and catalogs

World markers require all five documented functions, version 1,
`frameProjection = true` and `frameHandler = true`. Capability `kinds` and
`attachments` are dense string lists. SDUI copies only supported-kind booleans
and `maxEntriesPerCall` / `maxProjectionsPerCall` into its own metadata cache;
it retains no provider table. Cache and fallen-ally support require advertised
`worldOffsets = true`. Unsupported kinds/attachments stay hidden.

Queries contain only needed `cache`, `guardian`, `boss`, `finalBoss` and
`downedPartyMember` kinds. Their states are `present`, `alive` and `downed`.
Catalog entries supply opaque `anchorId` handles directly and list their
attachments. The catalog does not need the proposal's `anchorStatus` field;
the separate downed-position getter still documents its own readiness fields.

Every discovery pass completes all pages synchronously in one frame, bounded
to 256 entries and 256 pages. Pages must agree on catalog, stream, world,
clock and current map/run/space. Only a complete valid catalog replaces the
queried kinds. Cyclic/sparse/duplicate/malformed, overflowing and over-budget
responses never publish partial replacement or removal evidence.

Accepted refreshes run no more often than every 0.2 UI seconds through the
existing waypoint reader. `NOT_READY` / `CATALOG_CHANGED` first retry after
0.1 seconds; other first failures wait half a second. Consecutive failures back
off to eight seconds and a complete accepted read restores normal timing.
Valid handles continue projecting during a temporary discovery failure.
`STREAM_CHANGED` clears all accepted/staging handles and hides old icons,
then starts a fresh catalog on a later shared pass without rebinding the owner.
A changed world, stream, coordinate context or regressed native clock also
retires the old catalog.

### Projection and placement

Projection runs only inside the native post-camera callback. Every batch must
have `frameCurrent = true`, the accepted world and stream, one coherent camera
sample and clock, and exact request order. A changed stream/world response or
`STREAM_CHANGED` error clears the catalog immediately. Malformed/noncurrent
batches hide all icons atomically and retire the presentation for retry.

Encounters use the native unit `overhead` point with six screen units above it.
Caches and fallen allies use `position` with the same shared `{ z = 5 }`
offset, placing their centers five world yards above the cache or revive spot
without extra screen padding. Cache sides are 22.4 units; fallen-ally sides
are 29.12 units, 30% larger than their former 22.4. Every request slot explicitly
sets or clears its offset, so this
height never leaks to an encounter kind. Pooled frames update dimensions only when the required size
changes. Occlusion is unsupported, so markers can show through walls.

Offscreen, behind-camera, clipped, notReady and unsupported/unavailable entries
hide without inventing a point. `expired` and `unknownAnchor` handles retire
from the accepted list and recycle their views, so later frames stop projecting
them. A `worldChanged` result clears the whole catalog. Frames are children of
WorldFrame and reuse the existing artwork, static bindings and changed-only
placement/visibility. Cache and encounter icons use a 120 ms appearance/range
fade in normal mode and instant visibility in Performance Mode; invalid or
offscreen points and explicit retirement hide immediately.

### Demand, caching and cleanup

Display choices are cached through the existing settings listener. Copied
capability metadata can be reused for up to 30 seconds on later activation;
a changed getter or regressed UI clock invalidates it. There is no per-frame
capability, setting, phase or player-position read in the marker callback.
Visible eligible handles still need current-camera projection each frame.

The default-off **Only show affordable caches** filter reads published
`AZS_RUN.gold >= AZS_RUN.chest`, requiring finite nonnegative values and a valid
receipt. Equality, fractional values and free caches keep their native meaning.
Unaffordable caches skip discovery, projection and drawing. A changed eligible
kind mask requests a fresh complete catalog while retaining callback ownership.

Known solo state suppresses ally work. An already validated empty downed feed
also suppresses duplicate ally discovery within that same reader pass, without
caching gameplay presence across passes. Disabled/hidden roots do no marker API
reads. Temporarily unqueried but enabled kinds can keep dormant scalar handles
and prepared frames; accepted active plus dormant records remain bounded to 256. Fully disabled/world-retired owners release the callback through the
shared service. Failed release retries at most twice per second and preserves
the exact function needed for release; retired callbacks remain inert and
foreign callbacks stay untouched.

Downed-position guidance uses the released `AZS_GetDownedPartyMembers()` fields,
including exact map/run/space and valid zeros. A missing getter keeps the old
map path; an available but empty/unavailable/malformed feed never borrows map,
ghost or historical positions. Hidden HUD plus minimap, hidden UIParent,
disabled guidance and known solo state skip this getter. Empty or entirely
position-unavailable lists do no player-position read. Failed reads hide old
locations and back off from half a second to eight seconds; successful reads,
changed getters, known solo state and world reset release that delay.

SCT distance sizing already consumes the released `playerDistanceMetrics` /
`playerDistance` contract. Zero or absent/invalid distances keep the chosen
size; camera metrics never substitute. No extra getter or catalog scan is
added by the sizing controls.

The request-count, pooling, paging, failure and stream/terminal-handle cases
are CI-only mocks. They do not prove native scheduling, delivery, rendering
cost, instance revive locations, appearance or live FPS.

### Cache and encounter distance preferences

Their independent Always/Nearby only/Distant only selectors use the released
`playerDistance` field and advertised `playerDistanceMetrics`, with a 40-yard
default cutoff adjustable from 5 to 200. Near includes the cutoff; Far starts
beyond it. Missing metrics hide a filtered kind rather than guessing from the
camera. Always keeps working without that optional metric. These settings add
no native lookup; cached settings and existing native projections decide
visibility, with the same bounded pool/callback/discovery ownership. Affordability
still gates caches independently, and fallen-ally icons retain their existing
instant visibility. See [performance notes](PERFORMANCE.md#world-icon-distance-visibility-and-quick-fades)
for fade and settings-region costs and [CI scope](PR-CHECKS.md).
