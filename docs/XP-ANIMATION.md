# XP gain animation

The existing purple XP fill now moves over 0.18–0.45 seconds, with a brief
highlight on the gained portion and a moving native spark. Both fade over
0.35 seconds after arrival. New gains retarget from the displayed position;
the latest native XP is the destination, rather than a sum of event payloads.

`UnitXP`, `UnitXPMax` and `UnitLevel` remain the only XP sources. XP and level
events schedule a read for the next OnUpdate, after native event handling.
The status bar displays a normalized fraction; no consumer reads its value
as gameplay XP. No gameplay value is changed or persisted.

An observed increase of exactly one level finishes the known old bar, then
fills from zero to the received new-level fraction. Unknown or skipped levels,
XP decreases, changed maxima without a level increase, first attachment and
world entry establish an immediate baseline. No missing thresholds, XP awards
or intermediate levels are invented. Further native gains during a rollover
update its final destination without restarting the old-level sweep.

Hiding, invalid native data, world leave/logout, layout entry/exit and both
full resets stop the effect and remove both regions. Hidden or edited bars
accept current XP immediately. Showing the bar schedules an immediate native
baseline, so hidden gains are not replayed. The event controller has no idle
OnUpdate: it runs only for a pending read or an active visual effect.

The purple color, six-unit height, mouse transparency and lack of XP
text/tooltips stay intact. The animation uses two passive texture regions and
adds no asset, setting, SavedVariable or runtime dependency. The separate
border and independent `xpBar` geometry remain available when detached;
[XP-ATTACHMENT.md](XP-ATTACHMENT.md) describes the default joined shell.
Both fill regions use the same prepared texture with the original shading
and fading reduced by 30% overall. Slight rounding remains at both ends.

Source research, precise upstream pins and artwork ownership are recorded in
[XPBar-ANIMATION.md](../third_party/XPBar-ANIMATION.md). This is an adaptation of
the retail presentation pattern to legacy drawing APIs, not a claim of exact
retail flipbook parity. No local tests, syntax checks, formatters or addon/game
execution were run; static validation belongs to GitHub Actions. Live timing,
level-event ordering and appearance remain unverified in the packaged game.
