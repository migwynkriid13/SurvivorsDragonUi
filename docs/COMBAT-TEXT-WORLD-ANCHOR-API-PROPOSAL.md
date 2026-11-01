# Proposal: world anchors for addon combat text

Status: proposed game API, reviewed against the sources below on 2026-11-01.
The function names, fields and guarantees in this document require game-side
implementation. SDUI includes a capability-detected consumer described below;
the packaged game's delivery of the native provider remains unverified.

## Problem and requested result

Custom scrolling combat text (SCT) currently uses native nameplates to find
screen coordinates. It follows a matched plate while those coordinates remain
usable. When an enemy dies, its plate disappears, or the camera turns away,
the numbers can finish around the last usable screen position. They then appear
to move with the camera instead of remaining at the enemy's location in the world.
Unmatched hits and ambiguous same-name enemies can also use a shared fallback.

Please expose an exact native hit-to-target association and a retained world
anchor that addons can project through the current camera. Capture the anchor
before death or despawn removes the target, including a one-shot kill before
any nameplate was created. Turning 180 degrees should hide numbers whose world
anchors leave the view, rather than leave them floating over empty screen space.

**Required result: after an enemy dies, its SCT must stay over that enemy's death
location in the world even when the player moves or rotates the camera.** The
API must retain the enemy's overhead world position at death and recalculate
its screen position through the current camera every frame. Moving the player,
turning the camera or zooming must move the numbers across the screen so they
remain over that same death location for the rest of their normal animation
and fade. If that location leaves the view, hide the numbers while it is out of
view. The nameplate and enemy entity may already be gone.

This requested death-location behavior uses `follow` mode below.

Two anchor behaviors are useful:

| Mode     | Required behavior                                                                                                                                                                         |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `impact` | Keep the hit's original world position and reproject it as the camera moves. A surviving enemy can walk away from old numbers.                                                            |
| `follow` | Follow that exact living enemy's native overhead world anchor. At death, retain its overhead world position at the death location and continue reprojecting it through the moving camera. |

The retained position must be a **world position**, not the last nameplate pixel
position. Addons should retain their own fonts, icons, colors, grouping,
animations and expiry. Distance information should also permit optional
distance-based sizing without guessing distance from a nameplate's size.

## What the inspected native source already does

The public Wenilla renderer stores a world-position snapshot in each
[`WorldText`](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_text/mod.rs#L89-L101).
It then [reprojects that position through the camera every frame and culls rejected projections](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_text/mod.rs#L254-L268).
This establishes a native implementation lead for `impact` mode; it is not a
Lua API that the addon can call today.

That source explicitly keeps [text size constant with distance](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_text/mod.rs#L270-L272).
Distance-based addon sizing is therefore an additional requested capability,
not a claim about the default renderer's behavior.

## Proposed Lua calls

```lua
local capabilities, err = AZS_GetCombatTextCapabilities()
local batch, err = AZS_GetCombatTextEvents(cursor, limit)
local projection, err = AZS_ProjectCombatTextAnchors(anchorIds, mode)
```

All three calls are read-only. They return a detached table and `nil` on success,
or `nil` and an error table with `code` and `message` on failure. Returned tables
must not expose mutable native state. IDs and cursors are opaque strings so Lua
number precision cannot merge native 64-bit identities. Addons compare IDs for
equality only and never persist them between sessions.

The API covers outgoing damage and miss results from the local player and their
owned pets, summons and totems. It does not request incoming/self text, healing,
a complete unit-discovery API or a replacement damage meter.

### 1. Discover support

```lua
local capabilities, err = AZS_GetCombatTextCapabilities()
```

| Field                                | Proposed version 1 value or meaning                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `apiVersion`                         | Integer `1`.                                                                                            |
| `impactAnchors`, `followAnchors`     | Both `true`; the two modes above are supported.                                                         |
| `frameProjection`, `distanceMetrics` | Both `true`; current-camera projection and the metrics below are supported.                             |
| `maxEventsPerRead`                   | Integer `256`.                                                                                          |
| `maxAnchorsPerRead`                  | Integer `256`.                                                                                          |
| `eventCapacity`                      | At least `4096` retained events.                                                                        |
| `anchorCapacity`                     | At least `4096` retained anchor records.                                                                |
| `eventRetentionSeconds`              | At least `5` UI-clock seconds, subject to the advertised event capacity.                                |
| `anchorRetentionSeconds`             | At least `5` UI-clock seconds from event publication, subject to an explicitly reported resource limit. |

Capabilities work outside a run. Advertise version 1 only when all three calls
and their required behavior are available. No native setting or visibility
write is needed to discover support.

### 2. Read exact native events and their anchor handles

```lua
-- First call subscribes at the current tail; it returns no historical hits.
local start, err = AZS_GetCombatTextEvents(nil, 256)
local cursor = start and start.cursor

-- Later calls return events strictly after this reader's cursor.
local batch, err = AZS_GetCombatTextEvents(cursor, 256)
```

`limit` is an integer from `1` to `maxEventsPerRead`; omitting it selects the
advertised maximum. A successful batch contains:

| Field          | Meaning                                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `apiVersion`   | Integer `1`.                                                                                                            |
| `streamId`     | Identifies this event stream. Changes on reload, world/instance retirement or a new run.                                |
| `worldId`      | Identifies the actual coordinate space and its epoch; separate instances never share it.                                |
| `clockSeconds` | Current native UI presentation time, using the same monotonic clock and epoch as `GetTime()`, not the paused run clock. |
| `cursor`       | Resume token immediately after the last returned event, or the current position for an empty batch.                     |
| `events`       | Dense array in original native presentation order. Equal hits remain separate events.                                   |
| `hasMore`      | Whether additional retained events were available after this batch.                                                     |
| `droppedCount` | Exact number of events lost between the requested cursor and the first available event; normally zero.                  |

Reads do not consume a shared queue: multiple addons keep independent cursors.
An empty batch is a valid success. A cursor from a retired stream returns
`STREAM_CHANGED`; the addon clears its old labels and starts at the new tail.
A lagging cursor in the same stream returns the available events and a positive
`droppedCount`, without inventing the missing events or silently restarting.
The addon advances to the returned `cursor` after accepting the batch. When
`hasMore` is true, it can read another bounded batch through the same controller;
the cursor must advance even when `events` is empty after retention loss.

Each event contains:

| Field                                          | Meaning                                                                                                                                                                                                                                              |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `eventId`                                      | Unique native presentation-event identity within `streamId`; never a name/amount/timestamp guess.                                                                                                                                                    |
| `presentedAt`                                  | Native UI-clock time when this hit becomes eligible for presentation.                                                                                                                                                                                |
| `targetId`                                     | Exact target incarnation, when the native target is known; independent of nameplates and names.                                                                                                                                                      |
| `targetName`                                   | Received localized target name when available; display metadata only.                                                                                                                                                                                |
| `sourceId`, `sourceKind`                       | Exact native caster identity when known, and `player`, `pet`, `summon`, `totem` or `ownedUnknown`. Retain the recorded owner relationship.                                                                                                           |
| `kind`                                         | `damage` or `miss`.                                                                                                                                                                                                                                  |
| `amount`                                       | For `damage`, the native nonnegative finite damage number before abbreviation or addon grouping. Absent for `miss`.                                                                                                                                  |
| `result`                                       | For `miss`, `{ key = "dodge", text = "Dodge" }`, for example. Keys are `miss`, `dodge`, `parry`, `block`, `resist`, `immune`, `evade`, `absorb`, `reflect`, `deflect` or `unknown`; retain the actual native localized caption. Absent for `damage`. |
| `critical`, `periodic`, `reflected`            | Actual native booleans.                                                                                                                                                                                                                              |
| `damageType`                                   | `melee`, `ranged` or `spell` when natively known; periodic/reflected status remains in the independent booleans. Omit when unavailable.                                                                                                              |
| `schoolMask`                                   | Native schools expressed as a bitmask: Physical `1`, Holy `2`, Fire `4`, Nature `8`, Frost `16`, Shadow `32`, Arcane `64`. Preserve combined schools; omit when unavailable rather than infer one.                                                   |
| `abilityKey`, `abilityName`, `icon`, `spellId` | Native source identity, localized name, texture path and spell ID where actually available. Optional metadata; never fabricate a spell identity for an unnamed attack or item effect.                                                                |
| `anchorId`                                     | Retained native anchor handle, or absent when no authoritative world anchor can be captured.                                                                                                                                                         |
| `anchorStatus`                                 | `ready` or `unavailable`. A missing anchor never means coordinates `0,0`.                                                                                                                                                                            |

Each event also requires `basicAttack`, an actual boolean distinguishing an
ordinary melee/ranged autoattack from an ability. Attack range, school or a
localized name cannot establish that distinction. This lets the consumer
preserve the existing Auto attacks and Direct damage filters without guessing.

Preserve native event amounts, ordering, critical status, schools, reflected
damage and caster identities. Do not collapse equal hits, sum packets, infer
ownership from a translated name, or join an event to an arbitrary same-name
enemy. The same event must not be exposed twice through separate melee/spell
paths. This presentation feed must not be used as the authority for meter totals.

Capture anchors at the native hit/presentation boundary while the target's
overhead world position is still available. Melee impact, projectile arrival,
periodic damage and lethal-hit cleanup must retain their actual native ordering.
If an entity retires before a delayed presentation, use a world anchor retained
by that native event; return `unavailable` if none exists. Never guess a location.

The feed must remain available with `CombatDamage` off, native pet-text CVars
off, nameplates hidden, or the native renderer at its per-unit text limit.
Capture before those presentation gates and caps. Otherwise an addon could not
hide native numbers while consuming their replacement data. Do not change any
native CVar as a side effect of reading the feed.

### 3. Project retained anchors through the current camera

```lua
local projection, err = AZS_ProjectCombatTextAnchors(
    { firstEvent.anchorId, secondEvent.anchorId },
    "impact" -- Or "follow"; one mode applies to the entire batch.
)
```

`anchorIds` is a dense array of at most `maxAnchorsPerRead` handles. An empty
array succeeds with no entries. Invalid arguments return `INVALID_ARGUMENT`.
Each successful result contains `apiVersion`, `worldId`, `cameraSampleId`,
`streamId`, `clockSeconds` and a dense `entries` array with exactly one entry per requested
handle, in the same order. All entries use one camera/viewport sample.
The addon rejects a projection whose stream/world no longer matches its events
and clears that retired session before accepting new hits.

| Entry field      | Meaning                                                                                                                                                                                |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `anchorId`       | The requested handle.                                                                                                                                                                  |
| `state`          | `onScreen`, `offscreen`, `behindCamera`, `clipped`, `notReady`, `expired`, `unknownAnchor` or `worldChanged`. `clipped` covers native near/far-plane rejection in front of the camera. |
| `targetState`    | `alive`, `dead` or `unavailable`, based on native state, not whether a plate is shown. Absent when the handle itself is invalid.                                                       |
| `x`, `y`         | Present only for `onScreen`: offsets from `WorldFrame`'s bottom-left in that frame's local UI units, X right and Y up.                                                                 |
| `cameraDistance` | For `onScreen`, finite nonnegative Euclidean camera-to-anchor distance in yards; not player distance.                                                                                  |
| `cameraDepth`    | For `onScreen`, finite positive forward camera depth in yards.                                                                                                                         |
| `uiUnitsPerYard` | For `onScreen`, finite positive projected length of one yard along camera-up at this anchor's depth, in `WorldFrame` local UI units. Enables optional perspective sizing.              |
| `reason`         | For `expired`, `age` or `resourceLimit`, so early resource eviction is visible.                                                                                                        |

In `ready` events, `targetId` and `anchorId` are both required and identify the
same native target incarnation. An unknown or expired handle never becomes
`onScreen` through a name lookup. The coordinates must work directly with:

```lua
holder:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", point.x, point.y)
```

Account for UI scale, root effective scale, viewport resizing, widescreen or
letterboxed rendering and high-DPI windows inside the native conversion.
Return the overhead anchor before nameplate collision/stacking displacement.
Do not ask Lua to reconstruct a camera matrix or calibrate screen pixels.

In `follow` mode, camera turns or a living target going offscreen must not
freeze its world tracking. At death, capture the native overhead world position
at the death location before corpse animation, despawn or entity cleanup can
remove or move it. Every still-active `follow` anchor for that incarnation must
then use this retained death position. Continue projecting it through each
frame's current camera until the label expires, including while the player
moves, rotates the camera or zooms. This keeps the numbers over the death
location with their own animation offsets; their projected screen position
must continue changing with the camera.

If an entity disappears without a confirmed death position, retain its last
valid world anchor with `targetState = "unavailable"`; do not claim that sample
is a confirmed death location. Handle identity must include the target's
incarnation, so a recycled plate, entity slot or respawn cannot move old text.
In `impact` mode, the initial world anchor stays fixed regardless of subsequent
target movement or death. Reads in either mode never extend anchor retention.

An offscreen or behind-camera result has no usable `x/y`; never return the last
screen coordinates as a successful projection or clamp it to the screen edge.
Clipped points likewise have no usable screen coordinates.
This is a geometric visibility result, not a terrain/wall line-of-sight test.
An addon can temporarily hide a label while its original lifetime continues,
or retire it immediately. Looking back must not restart or replay an expired hit.

The sample must reflect the camera and native entity transforms used to render
that frame, including camera input and zoom. Publish it before the consuming
addon update and before UI extraction; move the native sampling/update stage if
necessary. A getter backed by the previous frame's camera or periodic run
packets does not satisfy this contract. Repeated reads in one frame share
`cameraSampleId`; a later frame has a new sample even when the camera is still.
If the current camera is unavailable, return `notReady` entries without stale
coordinates. Outside a world, return `nil, { code = "NOT_IN_WORLD", ... }`.

## Lifetime, bounded cost and cleanup

Keep a bounded event ring and bounded anchor storage; advertise the actual
capacities. The proposed five-second retention covers SDUI's current 1.1/1.45
second labels plus matching/grouping delays. If resource pressure evicts an
anchor early, report `expired` with `reason = "resourceLimit"`; never silently
retarget it. Report event loss through `droppedCount` independently of anchor
expiry. Addons must also respect each event's age when deciding whether to show
it, so a delayed batch cannot replay several seconds of stale damage.

Death, despawn, V, native text visibility and nameplate reuse do not invalidate
an already captured world anchor. World/instance changes, coordinate-epoch
changes, new runs and reload invalidate the stream and all its anchors.
Expired handles must never identify a new event. No save file, network message,
companion process, raw game-memory access or extra gameplay state is requested.

Share the native camera sample across one batch and project only requested
anchors. Addons should use their existing SCT controller, poll new events only
while their custom SCT is enabled, and project only active labels. With no
active labels, skip projection. Chunk larger active sets to the advertised
batch limit; all chunks in one frame must share the same camera sample.

General errors are `INVALID_ARGUMENT`, `NOT_IN_WORLD`, `NOT_READY` and
`STREAM_CHANGED`, as applicable to the call. Capabilities remain readable
without a world. A single expired or unknown handle is an entry result, not a
failure of the whole projection batch.

## Example addon consumption

These are integration sketches, not shipped code or locally executed tests.
`point`, `holder`, `animationX` and `animationY` below belong to the addon's
existing active-label loop. Grouping still preserves every original native hit;
a mixed-target group must not acquire one arbitrary member's anchor.

```lua
if type(AZS_GetCombatTextCapabilities) == "function"
    and type(AZS_GetCombatTextEvents) == "function"
    and type(AZS_ProjectCombatTextAnchors) == "function" then
    local caps = AZS_GetCombatTextCapabilities()
    if caps and caps.apiVersion == 1 and caps.frameProjection then
        -- Prime a cursor when custom SCT is enabled, then consume new batches
        -- through the existing controller. Do not also render those chat hits.
    end
end
```

```lua
if point.state == "onScreen" then
    holder:SetPoint(
        "CENTER", WorldFrame, "BOTTOMLEFT",
        point.x + animationX, point.y + animationY
    )
    holder:Show()
else
    holder:Hide()
    -- Preserve original born/expiry times; never freeze or restart the label.
end
```

Distance sizing is optional addon presentation. `cameraDepth` and
`uiUnitsPerYard` let the addon choose a bounded scale; constant text size can
remain available. Camera projection and visibility must work with either size
choice. SDUI's Performance Mode retains its existing SCT animation and grouping
exception; neither state should fall back to stale screen anchors on this API.
MSBT's fixed Layout stream can remain independent of world projection.

On old builds, retain the existing nameplate path. Once the native feed is
selected, do not render both native-feed and parsed-chat copies of a hit or
silently switch transports halfway through a failed batch. Retire that session
and explicitly re-prime the chosen transport. Existing native outgoing-text
ownership and incoming/self-text preferences remain independent.

## Current SDUI consumer

`core/combat_text_api.lua` protects and validates all three calls. Over enemies
and Diablo IV select this feed only after a complete valid version 1 capability
response. Builds without that support retain the nameplate path. The consumer
always requests `follow`: existing text remains over the enemy's retained death
location as the camera moves, provided the game fulfills the contract above.
MSBT keeps its independent chat-driven Layout stream.

The existing SCT controller primes a cursor at the current tail, reads at most
256 events per frame and projects only active labels in batches of at most 256.
Native source/target/ability identities keep separate casters and same-name
enemies distinct. Normal and Performance Mode grouping windows remain 75/300
ms, based on native presentation times; original amounts remain unchanged.
Native icon metadata is preferred without bypassing existing icon visibility,
font, color, damage-category or pet filters.

Native camera depth supplies automatic bounded distance sizing: text retains
the selected SCT size at depths up to 20 yards, shrinks as depth increases and
stops shrinking at 55% of that size. Camera movement and zoom update this factor
without restarting the animation. Both Performance Mode states share it; no
new setting, SavedVariable, frame, region or updater is added.

Offscreen, clipped, unavailable and expired projections hide the label while its
original expiry continues. Invalid native batches or projections retire the
current custom labels and re-prime native intake after a half-second retry
delay; they never duplicate the hit through a mid-session chat fallback.
Already-stale events older than 650 ms and hits with no authoritative anchor
are skipped. Missing event history is not reconstructed. Mode/style/world/reload
cleanup clears retained handles and duplicate IDs; no raw native table is held.

CI-only fixtures exercise this consumer against explicit fake native endpoints.
They were authored without local execution and do not establish native API
availability, real death-position capture, camera-update ordering or appearance.

## Acceptance criteria for the game implementation

- A one-shot kill supplies the correct event and world anchor even if no plate
  was ever created. The anchor remains projectable after target cleanup.
- Kill an enemy, then move the player, rotate the camera and zoom while its
  death location remains in view: all remaining `follow` SCT stays over that
  same world location as its screen coordinates change with the camera. The
  native nameplate and enemy entity may already be gone. Corpse animation and
  cleanup must not move the retained death anchor or restart the text lifetime.
- Turn the camera while a living enemy moves: `follow` tracks that incarnation;
  `impact` stays at the hit's original world location.
- Turn 180 degrees immediately after a lethal or nonlethal hit: the projection
  becomes offscreen/behind-camera and the custom label hides. No number remains
  pinned to its last screen location.
- Turn back before expiry: an addon that chose temporary hiding can show only
  the remaining lifetime. After expiry, nothing replays.
- Two identically named enemies, overlapping plates, same-amount simultaneous
  hits and recycled native entity/plate slots never exchange anchors.
- Melee, ranged, direct, periodic, reflected, pet, summon and totem events retain
  native amounts and attribution. Native miss results keep their correct target.
- `CombatDamage = 0`, native pet-text toggles, V off and native text caps do not
  suppress the replacement feed or prevent anchor capture.
- Camera rotation, zoom, resolution, UI scale, high DPI, letterboxing and instance
  maps retain correct alignment with no previous-frame camera lag.
- Front/behind-camera, viewport edges, missing camera, unavailable anchors,
  expiry and overflow return explicit states without fabricated coordinates.
- Two independent readers do not consume each other's events. Cursor gaps,
  empty batches, invalid inputs and stream/world/reload changes behave as above.
- Memory stays bounded under sustained high hit volume. Dead targets are not
  kept alive solely for text; retain only the required identities and positions.

These are requested provider tests and live acceptance cases. Source review
alone does not establish packaged-game behavior, rendering, FPS or API delivery.
No local tests, standalone validation or addon/game execution accompanied this
proposal and its addon consumer.

## References and implementation leads

References are pinned to inspected revisions so the proposal remains reviewable.
The public native client is implementation evidence, not proof of the packaged
Azeroth Survivors build or its private AZS bindings.

1. [Current SDUI position sampling](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/4ff27c85ad421564044f57c2260b5fc14970455b/modules/nameplates/sct.lua#L601-L638): rejects unusable screen coordinates and retains the previous usable point.
2. [Current SDUI plate retirement](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/4ff27c85ad421564044f57c2260b5fc14970455b/modules/nameplates/sct.lua#L667-L679) and [active-label origin reads](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/4ff27c85ad421564044f57c2260b5fc14970455b/modules/nameplates/sct.lua#L2239-L2253): explain the retained screen position after plate loss.
3. [Current SDUI target matching and fallback](https://github.com/migwynkriid13/SurvivorsDragonUi/blob/4ff27c85ad421564044f57c2260b5fc14970455b/modules/nameplates/sct.lua#L952-L1023): name/health evidence cannot provide an exact destination identity for every hit.
4. [Wenilla native anchor capture](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_text/mod.rs#L174-L230): obtains the native overhead world point and stores it in `WorldText`. Its existing late capture can skip a previously despawned entity; the proposed lethal-hit guarantee requires capturing earlier when necessary.
5. [Wenilla per-frame world-text projection](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_text/mod.rs#L254-L272) and [native projector](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/ui_pass.rs#L368-L391): existing camera projection and geometric rejection to expose through a supported binding.
6. [Wenilla native combat-log target and owner association](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_log/text.rs#L23-L57) and [spell-text emission](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_log/text.rs#L66-L109): native IDs exist before localized chat parsing; presentation CVars already gate the final text path, so the new feed must branch before that gate.
7. [Wenilla native nameplate projection](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/vplates.rs#L535-L550): behind-camera or out-of-viewport targets do not retain a native plate. Death is not the only cause of plate loss.
8. [Supplied AZS addon API reference](AzerothSurvivors-Addon-API.md), [existing player-position API request](DAMAGE-METER-AND-INSTANCE-PLAYER-POSITION-API.md#35-azs_getplayerposition) and [current SCT lifecycle](DIABLO-SCT.md#native-nameplate-layout-and-retirement): player/map coordinates alone do not supply an exact hit target, a retained enemy anchor or current-camera screen projection.
