# Pet frames

The **Pet frames** group combines permanent and temporary summons with the same
native type key, in first-arrival order. One gold-rimmed circle shows the name
and an `xN` count when more than one member is present. An optional timer shows
the earliest temporary member's remaining time; permanent-only groups have no
status text. There are no health or power bars. All distinct groups are shown,
without an eight-frame cap; a missing type key leaves that summon separate.

`/sdui` → Pet frames retains one to six rows, spacing from 0 to 60 units, and
independent name, count and timer visibility. Defaults are six rows, four-unit
spacing, visible names/counts and hidden timers. Move, scale or hide the whole
group through the shared Layout controls. Confirm, Cancel, discard and both
full resets retain their existing behavior and saved fields. The default
anchor is eight units below the player portrait and ten units to its left,
falling back to the player frame or UIParent when needed. Confirmed and draft
geometry remains independent of these defaults.

## Totems — 0.125.0

Totems share this group and all its existing controls with Hunter pets,
Warlock demons and other summons. Each received totem kind uses the same
gold-rimmed native icon, localized name, `xN` count for more than one, optional
timer, row arrangement and Layout behavior. Summon groups retain their arrival
order, followed by totem kinds in their native order. The two feeds remain
separate even if their keys or names coincide.

`AZS_GetTotems()` supplies already grouped kinds through `AZSTOTEMS`,
`AZS_TOTEMS` and `AZS_TOTEMS_UPDATED`. SDUI copies each unique nonempty key,
name, native icon and positive integer count, requiring a valid published cap
at least as large as that count. It does not hardcode kinds, cap, spell IDs,
artwork or durations. The cap is metadata for validation; the existing count
badge keeps the pet display's `xN` form. The native feed supplies no individual
IDs, so no individual totem frames or identities are manufactured.

The optional timer shows the getter's earliest expiry for that kind, rounded
up like pet timers. It stays `--:--` until `AZS_GetRunTime()` is available and
finite, even if the getter computed a value against its pre-run zero fallback.
No UI clock is subtracted from a raw deadline. Reaching zero keeps the native
count until a new snapshot changes it. Duration can describe a different
captured instance than the earliest expiry; neither is used to infer other
totems' lifetimes or the next summon.

Each feed has its own receipt generation, accepted packet and retirement gate.
Missing, blocked or malformed totem data clears only totems, and the same is
true for pets. New zone, inactive phase, world leave, logout and reload retire
both streams. Packet events defer native reads to the existing tenth-second
controller. Unchanged hidden/static groups do no getter reads; visible enabled
timers sample only streams containing temporary entries. Changed accepted
totem names/icons also use the same shared source-icon metadata path as pets,
without changing combat attribution.

The [complete supplied reference](AzerothSurvivors-Addon-API-0.125.0-2026-10-28.txt)
also documents Heroic affixes. CI-only scenarios cover the production pet
controller with fake native boundaries, including mixed feeds, counts, timer
readiness, pauses, hidden work and retirement. No local tests, standalone
validation or addon/game execution were run for this integration.

## Shared artwork

The native summon icon occupies the round portrait opening, with the same
34-unit diameter, center, full-image crop and separate 39-unit gold rim. Wolf
and Raptor retain their native pet-family icons. The gold rim reuses
`media/tex/jewelry/Frame.blp`; the unused dedicated pet background and border
are removed. A separate crop at `(576, 56)` through `(648, 128)` keeps the gold
pixels from the original rim and removes its inner and outer drop shadow with
an antialiased annular alpha mask. Its complete circle stays inside the crop,
so no square shadow edge is cut off on the right. The five jewelry crops are
unchanged. `scripts/prepare_jewelry_art.py` prepares this crop in the existing
atlas; no additional texture file is needed. Fonts, sizes, grouping, row
arrangement and settings are unchanged.

## Round-icon rendering

Each pooled row has one named ARTWORK texture. The native global
`SetPortraitToTexture(texture:GetName(), icon)` supplies its circular mask,
below the unchanged OVERLAY gold rim. This is a still icon, without a unit
token, model, animation or camera binding. The setter runs only when that
row's icon changes; inherited layout scale needs no rebinding.

The installed game itself uses this API in its embedded
`BenillaScriptLogFrame_OnLoad`, passing a texture name and an icon path to mask
the icon into a portrait ring. This is current-client usage evidence rather
than an assumption that a retail mask API exists. No new asset or runtime
module is needed.

Previously, each icon used roughly one native Texture region per physical
pixel of its height. Those regions remained visible and participated in native
rendering every frame, even after Lua roster/text updates were cached. The
native path removes this persistent strip composition and uses one portrait
region per displayed group. Older clients that lack the global, raise an
error or fail to assign the requested texture path lazily use the existing
strip renderer instead. Failed native paths are not retried every refresh; a different
icon can use the native path again. Retirement hides and clears both paths and
resets the icon cache. Binding verification accepts the original path or the
extension-stripped form returned by the legacy `GetTexture()` API. Failed
attempts clear the hidden portrait before fallback, including partial writes.

The compatibility renderer caches each successfully bound strip. A failed strip
stays retryable through the existing tenth-second controller, even for static
groups with timers hidden; successful strips are not rebound while retrying.
An incomplete icon stays hidden until every required strip has loaded. A scale
change reuses successful bindings while changing only the clipping geometry.
Retirement clears both the successful bindings and the native-failure cache.

## Native data and lifecycle

`modules/unit/pets.lua` feature-detects `AZS_GetPhase` and each feed's getter.
It reads phase before inspecting roster tables and requires each feed's native
receipt stamp plus a roster table. A missing API or invalid snapshot removes
only that feed; an inactive phase retires both. The existing native primary-pet
health/power frame stays intact; the new roster does not map summon IDs to the
single `pet` unit token.

Missing names or invalid/duplicate summon IDs reject that feed until a usable
snapshot arrives. Native list entries are never mutated or retained. Display groups,
duplicate-ID tracking and the type-key lookup reuse session-only tables.
Retired groups release names, icons and timing references while their empty
tables and passive frames remain available for reuse. Missing icons leave an
empty portrait opening; no creature model or health data is invented.

The controller retains its phase-first check and detects roster changes through
packet identity, receipt stamp and each stream's receipt generation. Unchanged
static groups reuse their accepted display data instead of calling native
getters and rebuilding the view on each periodic check. Settings
previews reflow those cached groups; localization requests a deferred native
refresh. A changed effective scale only rebuilds clipping for the compatibility
strip renderer; the native portrait scales through its parent.

Only visible, enabled timers on temporary groups require periodic native
getter reads, at the existing tenth-second update interval. Hidden timers,
permanent-only groups and a hidden group do not perform these clock reads.
Countdown seconds still round up and use unpadded minutes. The getter owns
pause/card-choice timing; no receipt time, cast time or private gameplay clock
supplies remaining time. A still-listed creature at zero remains counted until
the native roster removes it. Unavailable temporary timing shows `--:--`.
For a mixed group, only temporary members contribute to the earliest timer;
one unavailable member leaves that timer unknown.

Names, counts and status labels call `SetText` only when the displayed string
changes. The root's Show/Hide calls occur only on visibility transitions. Hidden
groups still accept roster changes and update shared edit bounds, but skip row
creation, icon binding and label painting. Showing the group invalidates its
presentation through the existing controller, using the accepted roster and
native timer data.
The shared layout wrapper continues to own the Hide frame setting, so hiding
and unhiding the group preserves its active roster and editor behavior.

`AZSPETS`, `AZSTOTEMS`, `AZSRUN` and `AZSZONE` schedule reads for the next
OnUpdate, after native parsing. New-zone, inactive-phase, world-leave and logout
cleanup retire each current packet/stamp and receipt generation. The same
retained packet cannot reactivate that stream's rows until its identity/stamp
changes or a fresh corresponding receipt occurs. Paused and choosing phases
keep valid data without a timeout.
World leave/logout and the wrapped ReloadUI stop updates and clear accepted
roster caches, row identity, text and icon references. Full layout resets clear
the view; its next native refresh can repopulate current summons. Nothing is
saved or replayed. Empty groups expose only the normal layout editing handles,
without fictional pets. Existing translations and native names are unchanged.

The roster supplies no per-summon health, power, unit token, target or damage
identity. Pet-damage filtering and damage attribution remain independent. Changed accepted publications also pass each display group’s exact name/icon pair to the shared SCT/meter resolver; this supplies display metadata only, including the existing Hunter family icon choices.
There is no documented pets/summons HUD visibility part to take over.

The 2026-10-26 follow-up used source/history review and pinned local formatting.
No local tests, syntax checks or addon/game execution were run. GitHub Actions
supplies the repository's static checks; static artwork previews do not
establish live client rendering or native replay behavior.

The first update-only optimization did not recover FPS in the supplied native
journal capture. With native portraits enabled, the next manual capture's
settled median sample frame time returned to 16.67 ms (about 60 FPS), compared
with 20.03 ms (about 50 FPS) after the update-only change and 19.17 ms (about
52 FPS) originally. The median reported per-sample p95 fell from 38.35 to
18.59 ms, close to the pets-disabled capture's 18.68 ms. Matching the shared
entity-count range retains the 16.67 ms result. These are sample medians from
separate runs, not raw-frame percentiles or a controlled per-widget profile.
They strongly support persistent strip rendering as the sustained FPS cost.
The world-entry stall remains, and native GPU out-of-memory crashes have not
been established as fixed.

The 2026-10-27 source-icon follow-up reuses this reader after full roster validation. It learns only on changed accepted publications, not timer-only reads, and creates no new getter, scan, event, updater or drawing region. The shared resolver retains only unsaved name/path pairs until zone, language or world cleanup, allowing meter rows to keep known pet art after despawn. Source/diff inspection and pinned formatting were performed; the supplied Russian screenshots establish the original mismatch, while the correction remains unverified in-game.
