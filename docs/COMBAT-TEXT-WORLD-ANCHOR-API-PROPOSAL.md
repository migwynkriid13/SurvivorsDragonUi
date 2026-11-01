# World-anchored combat text: API and addon integration

The owner-supplied `addon_docs.md` from 2026-11-01 is preserved verbatim in
[Azeroth Survivors: Addon API](AzerothSurvivors-Addon-API.md).
Its [World-anchored combat text section](AzerothSurvivors-Addon-API.md#world-anchored-combat-text-version-1)
is the authoritative provider contract. It supersedes the original proposal's
assumptions about event fields and callback timing. This file describes the
requested result and SDUI's consumer; it does not define another payload schema.

## Required result

**After an enemy dies, its SCT must stay over that enemy's death location in the
world even when the player moves or rotates the camera.** The game retains the
enemy's overhead world position at death, independently of its nameplate and
corpse. Every visible frame reprojects that location through the current camera
while the label finishes its original animation and fade. Turning away hides
it; looking back can reveal only its remaining lifetime.

SDUI requests `follow` anchors: follow the exact living enemy, then retain where
it died. The provider's separate `impact` mode retains the original hit location.
An enemy disappearing without a confirmed death retains its last world position
with `targetState = "unavailable"`. Neither mode uses stale nameplate pixels.

The default-off **Scale damage by distance** checkbox lets players choose this
presentation. Off keeps the selected SCT size at every distance while retaining
world/death-location tracking. The existing display table's `sctDistanceScaling`
boolean shares preview/Confirm/Cancel, profiles and both full resets; missing or
invalid values reset to off while explicit saved choices survive. MSBT dims the
control and retains the choice. Both Performance Mode states share this path.

When enabled, farther numbers appear smaller while remaining readable. SDUI multiplies
the selected SCT size by `min(1, max(0.55, 20 / cameraDepth))`: full size through
20 yards of camera depth, shrinking farther away with a 55% floor. Camera turns,
player movement and zoom update this factor without restarting the label.

## Calls and frame timing

The complete integration uses these documented calls:

```lua
local capabilities, err = AZS_GetCombatTextCapabilities()
local batch, err = AZS_GetCombatTextEvents(cursor, limit)
local projection, err = AZS_ProjectCombatTextAnchors(anchorIds, "follow")
AZS_RegisterCombatTextFrameHandler(handler)
AZS_UnregisterCombatTextFrameHandler(handler)
```

Require all five functions, version 1 capabilities and `frameHandler = true`.
Register one stable addon-owned handler while custom Over enemies or Diablo IV
is active. Consume native events, resolve pending groups, project active anchors
and update their holders **inside that handler**, after the camera has moved.
Require `projection.frameCurrent == true` and one coherent camera sample across
all batches. Ordinary `OnUpdate` runs too early for native SCT positioning.

`OnUpdate` retains native-setting observation, plate styling and shared metadata
preparation. It updates legacy/MSBT text only while the native transport is not
selected. It also retries pending registration/release failures at most once
per half-second. No gameplay controller, frame, region or separate SavedVariable
is added, and the native path never animates a label in both frame phases.

Release only this addon's handler on Off, MSBT, world leave, logout and reload.
A failed release leaves its callback inert while the existing controller retries.
A failed registration keeps the legacy path active and releases any partially
installed handler before retrying. Performance Mode changes keep the same handler
and preserve the existing animation/grouping exception.

## Documented hit fields

Use received `sourceId`, `sourceKind`, `targetId` and `spellId` for native
identity. Preserve target incarnations, caster ownership, school, critical,
periodic/reflected status and resolved icons. Normal mode retains the inclusive
75 ms exact-amount window; Performance Mode retains its inclusive 300 ms sums,
using native presentation timestamps and leaving original amounts unchanged.

The shipped contract has no required `basicAttack` or `abilityKey`. Map the
received `melee`/`ranged` categories to Auto attacks and `spell` to Direct damage;
periodic/reflected booleans retain their dedicated filters. Group known spells
by `spellId`, even without a name/icon. Plain native melee/ranged attacks can
use their received category; otherwise missing native attack identity keeps
hits separate. Names or matching artwork never establish an unknown identity.

Miss `result.text` is already the game's localized word. Render it unchanged
with the existing game font. If the language supplies no word, accept the event
and advance the cursor without drawing that miss. Other valid hits in the same
batch continue normally; do not invent a word or reject/re-prime the batch.

## Reads, visibility and cleanup

The handler primes a cursor at the current tail and reads at most 256 events per
frame. It projects only active labels, in batches of at most 256; empty active
lists make no projection call. Keep the existing bounded 4096-ID duplicate window
and copy only accepted fields/handles, never raw native snapshot tables.

Offscreen, behind-camera, clipped, unavailable and expired projections hide the
label while its original lifetime continues. Invalid/noncurrent projections
retire presentation and retry native intake without duplicating chat hits.
Stale events older than 650 ms and hits without authoritative anchors are skipped.
Native stream/world fences and mode/style/world/reload cleanup retire old IDs.
The provider counts dropped history; the addon does not reconstruct missing hits.

Missing/incomplete API support keeps the existing nameplate path. MSBT remains
an independent chat-driven Layout stream. Hidden/off/retired native consumers
read no combat data. Both Performance Mode states share projection, offscreen
hiding, distance sizing and changed-only writes. Native text preferences and
incoming/self text retain their existing ownership rules.

## Evidence and limits

CI-only production-controller fixtures model `OnUpdate` and the later native
frame phase separately, with the supplied capabilities/events/projections and
no proposed-only payload fields. They cover death/camera movement, missing miss
captions, spell/category grouping, frame ownership, partial failures, cleanup,
false/missing `frameCurrent`, hidden work, old-build fallback and both modes.
No local tests, standalone validation or addon/game execution were run. Mocks do
not establish actual engine scheduling, live API delivery, appearance or FPS.

The original implementation leads remain useful: Wenilla's public
[world-position snapshot](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_text/mod.rs#L89-L101),
[per-frame projection and geometric rejection](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_text/mod.rs#L254-L272)
and [native hit/target association](https://github.com/Arnesen/wenilla/blob/ea514d8bb724c0571fc74183f23de7b1bbb303cf/crates/benilla-app/src/combat_log/text.rs#L23-L57).
These reference-client sources do not establish the packaged game's exact build.
See [Diablo SCT](DIABLO-SCT.md#native-world-anchors),
[Performance](PERFORMANCE.md#native-world-combat-text--2026-11-01) and
[PR checks](PR-CHECKS.md#ui-work-and-cleanup-tests) for the consumer lifecycle.
