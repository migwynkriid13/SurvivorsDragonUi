# XP attachment

The selected design 01 extends the action bar's metal shell below its ability
buttons. XP uses the existing purple six-unit fill inside that shell; its
separate border is hidden. Its prepared fill has uniform horizontal color and
interior opacity, without the original left vignette, and slightly rounded ends.
The walls and bottom bevel belong to the action bar,
including when jewelry's upper rail is detached or disabled.

`attachXP` is a normalized boolean in the existing display table, default true.
The Action bar page uses shared preview, Confirm-only saving, Cancel,
world/logout/reload discard and both full resets. Unrelated display changes
do not reparent XP or restart its animation.

The existing animated status bar stays inside a mouse-transparent outer frame.
Attached mode parents this frame to `DFRL.mainBar`, at local scale 1; movement,
effective scale and hiding therefore follow the action bar. Static
`actionBarDefaults.xpTop`, `xpInset` and `xpExtension` own the geometry. The
Action bar edit region includes the joined lower artwork. Jewelry continues
to own only its upper edit bound.

The existing `xpBar` layout key now belongs to a detached root with the same
default dimensions and anchor. Its saved and draft position, scale and hidden
flag are retained while attached and apply when the toggle is off. They do not
hide or move attached XP. The separate handle is absent while attached. The
Layout caption says **XP (detached)**; numeric edits affect that arrangement.

Valid native XP and a positive maximum are required. Unavailable XP and world
cleanup close the lower shell back to the original action artwork. Hiding the
action-bar group hides its attached children. The existing deferred reads,
gain motion, rollover, spark, glow and stop/rebaseline lifecycle stay in place.
Switching attachment clears the effect and snaps to current native XP. See
[XP-ANIMATION.md](XP-ANIMATION.md).

The outer XP width stays unchanged, preserving the tally's existing default
width calculation. Tally geometry and static waypoint defaults stay independent.
There is no position migration, gameplay save, new command or SavedVariable.

Artwork pins and preparation are in [XP-ARTWORK.md](../third_party/XP-ARTWORK.md).
Only artwork preparation and source inspection were performed locally. Local
tests, syntax checks, formatters and addon/game execution were intentionally
not run. GitHub Actions supplies static checks; the preview does not establish
packaged-client rendering.
