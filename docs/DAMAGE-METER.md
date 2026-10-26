# DPS meter

The meter uses the original Details! **The War Within** header, progress-bar and
background artwork in a native SurvivorsDragonUi window. Details and its skin
addon do not need to be installed.

Click its heading to cycle through Damage Done, Healing Done and Boss Damage;
right-click goes backwards. Only views with a native getter are offered. Scroll
over the window for more sources. Each row shows the native source name, total,
rate and share. Hover for its full name and numbers. Move, scale or hide **DPS
meter** through `/sdui` → **Layout**, then Confirm. Geometry and hiding also work
with named profiles, Cancel, `/sdui lock` and both full resets.

## Native data

The owner-supplied [2026-10-22 API reference](AzerothSurvivors-Addon-API-2026-10-22.txt)
defines `AZS_GetMeter()`, `AZS_GetHealing()` and `AZS_GetBossMeter()`. Each returns
`lines, total, rate`; rows supply `name`, `dmg`, `dps`, `share` and `proc`.

Damage and healing cover the whole run. Their rates are the game's averages over
its pause-aware run clock. Boss Damage covers the native current/last boss fight.
The renderer does not divide damage by UI time, estimate hits from combat text,
implement rolling DPS, subtract local reset baselines or fabricate fight segments.
The native meter window's Reset does not reset these API totals.

The phase is read before any retained meter data. `ready` clears the view;
`playing`, `choosing`, `paused`, `dead` and `victory` can display valid data.
Each selected snapshot must have finite nonnegative totals, rates, row amounts
and shares, with shares at most one. Source order and names remain native.
Rows are copied for display; native tables are never modified.

Initially a nonempty valid getter result can recover a view whose packet arrived
before addon initialization. Empty lists require their `AZSMETER`, `AZSHEAL` or
`AZSBOSSDMG` publication. A new zone, world leave or ready phase retires the
previous data and requires new publications before accepting that view again.
Packet handlers record receipt only: getters are read after parsing in OnUpdate,
at most five times a second. Paused data has no artificial expiry. Missing native
replay after reload can leave an empty view waiting; no resync API is invented.

The displayed sources belong to the local player's native meter. This is not a
party leaderboard or a port of Details' combat parser. Proc rows keep the native
blue distinction; other rows use the shared player-class palette. Icons use SCT's
existing exact-name metadata resolver independently of SCT's display mode or
filters. Ambiguous/missing icons are omitted. The existing square quality rim
surrounds source icons; the skin's retail class/spec portraits would misidentify
per-source rows and are not imported.

## Ownership and lifecycle

The common HUD owner captures `meter` / `hudMeter` only after the renderer,
layout registration and a selected snapshot are usable. Invalid or missing data,
render failures, world leave, logout and the wrapped ReloadUI release suppression
and restore the captured/latest external preference, including an originally
hidden meter. Its native minimap button belongs to that same HUD preference.
The custom heading remains available with a waiting/unavailable message when
another view has no snapshot. Hiding the Layout group intentionally hides the
replacement while its valid native takeover remains active.

Six fixed pooled rows show a scrollable source list. Header mode and scroll offset
are session-only; resets select Damage Done and the first page. One controller
coalesces data reads at five Hz. Bar values, colors, successful icon bindings and
label text skip unchanged writes. A missing SCT icon resolver affects only icons.
Shared layout storage contains only confirmed geometry and visibility; no meter
data or new SavedVariable is saved. All captions have source/runtime entries in
the fourteen supported languages.

## Artwork and verification

Pinned source, license, exact pixel preparation and runtime membership are in
[DetailsTWW-ARTWORK.md](../third_party/DetailsTWW-ARTWORK.md). Only the three
prepared BLPs and the original MIT notice enter the runtime payload; TGA
preparation inputs remain outside it. No Details, Ace3, retail mixin, external
font or new addon dependency is loaded.

Local work is limited to source inspection, artwork preparation and pinned
formatting under the repository workflow. No local tests, standalone syntax or
validation checks, addon execution or game execution were run. Existing GitHub
Actions supplies static checks; live appearance, scrolling, native replay and
preference restoration remain unverified in the packaged client.
