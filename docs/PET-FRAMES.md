# Pet frames

The **Pet frames** group shows the first eight native summons in arrival order,
in two columns of four. Equal names and kinds remain separate creatures, using
their native run-local IDs. A translated count below the group reports any
additional summons. Move, scale or hide the complete group in `/sdui` → Layout;
Confirm, Cancel, discard and both full resets use the shared layout lifecycle.
There is one `petFrames` geometry record in the existing layout table, without
another setting or SavedVariable.

The frame uses published pet artwork, rather than a newly drawn substitute.
The [artwork notes](../third_party/PetFrames-ARTWORK.md) pin the original files,
owning code, conversion and notices. The native summon icon occupies the round
portrait opening; fixed cropped texture strips preserve transparency using
legacy texture APIs. The name appears above the bar wells. The upper well
contains the remaining duration or translated **Permanent** label; the lower
well has a blue remaining-duration fill for timed summons. Neither represents
health or power. The owner reports that these summons are immortal.

## Native data and lifecycle

`modules/unit/pets.lua` feature-detects `AZS_GetPhase` and `AZS_GetSummons`.
It reads phase before inspecting roster tables and requires the native
`AZS_PETS_UPDATED` receipt stamp plus a roster table. A missing API, invalid
snapshot or inactive phase leaves this group unavailable without affecting
other frames. The existing native primary-pet health/power frame stays intact;
the new roster does not map summon IDs to the single `pet` unit token.

The module copies at most eight display rows, never mutates the native list,
and preserves native arrival order. Missing names or invalid/duplicate visible
IDs reject the view until a usable snapshot arrives. Icons come directly from
each native row; there is no icon catalog, guessed spell icon or creature model.
Missing icons leave an empty portrait opening. Overflow never allocates more
frames or stores hidden creatures.

At most ten times a second, the view reads the getter's current `remaining` and
`duration`. Only these values drive the blue lifetime fraction, clamped to its
well; countdown seconds round up and use unpadded minutes. The getter owns
pause/card-choice timing. No local receipt time, cast time or independent clock
supplies gameplay time. A still-listed creature at zero remaining remains
visible until the native roster removes it. Only `permanent == true` shows
**Permanent**; unavailable timing shows `--:--` and no fill.

`AZSPETS`, `AZSRUN` and `AZSZONE` schedule reads for the next OnUpdate, after
native parsing. New-zone, inactive-phase, world-leave and logout cleanup retire
the current packet/stamp and receipt generation. The same retained packet
cannot reactivate rows until its identity/stamp changes or a fresh `AZSPETS`
receipt occurs. Paused and choosing phases keep valid data without a timeout.
World leave/logout and the wrapped ReloadUI stop updates and clear all row
identity, text and icon references. Full layout resets clear the view; its next
native refresh can repopulate current summons. Nothing is saved or replayed.

The fixed 348-by-218 edit bounds include all eight slots and the overflow line.
The default anchor is UIParent TOPLEFT `(12, -220)`; roster growth/shrinkage does
not move confirmed or draft geometry. An empty group exposes only the normal
layout editing handles, without fictional pets. Caption translations cover all
fourteen source/runtime catalogs; native names are never translated again.

The roster supplies no per-summon health, power, unit token, target or damage
identity. This feature changes neither the pet-damage filter nor SCT icons.
There is no documented pets/summons HUD visibility part to take over.

Local tests, syntax checks, formatting tools and addon/game execution were not
run. GitHub Actions supplies static checks; static artwork previews do not
establish live client rendering or native replay behavior.
