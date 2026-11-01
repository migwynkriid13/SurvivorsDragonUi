# Native timers in Buffs

On Azeroth Survivors 0.115.0 or newer, the existing Buffs group shows received
talent and jewelry timers alongside native buffs and weapon enchants.
Debuffs have their own group below Buffs. In `/sdui` → **Layout**, select
**Debuffs** to move, scale or hide them separately, then Confirm to save.
Cancel discards the preview; profiles and Addon defaults include both groups.

The received timers occupy the first slots at the selected left or right anchor
in their received order, including separate effects with the same name. Every
timer icon stays bright, without fading or dimming, and has no text underneath
at any remaining value. Timer icons have no added outer border and fill their
existing buttons. Ready/waiting changes do not move the icons within that group.

Hover shows the supplied source name, Next summon or Cooldown, full wait to
one decimal place, and remaining seconds or Ready. These five captions use all
fourteen source/runtime UI catalogs. Ready means the wait has elapsed; native
proc triggers, summon caps and other conditions still apply. Summon timers
describe the next summon. Existing Pet frames continue to describe the summons
already out and their lifetimes.

## Shared view and native boundary

`modules/unit/auras.lua` owns both the original native buttons and a passive
pool of timer buttons. Both use the same 28-unit icons, six-column wrapping,
flip direction and existing `buffs` Layout entry. Native harmful buttons
`BuffButton16`–`BuffButton23` are reparented once to the sibling
`DFRL_PlayerDebuffs` root and use the independent `debuffs` Layout entry.
Each group starts its own six-column grid. The unsaved debuff default resolves
below the current Buffs bounds, including buff row/scale changes; a saved/draft
debuff position stays independent. Both groups retain a one-row editing bound
when empty. Only harmful icon artwork uses the existing boss-debuff inset
(`0.07`–`0.93` UVs), preventing its baked pale rim from peeking past the native
colored overlay. The border's texture, crop and dispel tint stay native; ordinary
buffs, weapon enchants and API timer artwork retain their full images. Both
Performance Mode states use this static crop through existing layout calls,
with no new region, asset, reader or updater.

Native duration labels retain their original placement; API timer
buttons have no countdown FontString. Changing
the pool's visible row count updates measured bounds through shared Layout,
preserving confirmed/draft center and scale and the default top-right edge.
Move, resize, hide, Confirm, Cancel, profiles and both resets keep their existing
ownership. New native auras do not need a separate layout path.

Native Show/Hide hooks share one callback per group, bound through a stable
function parameter. They never retain the generic-for entry, which becomes nil
when iteration ends in the client's Lua 5.0. Original native scripts still run
first; callbacks only mark their own group dirty and request the existing layout.

Timer buttons have no cast, cancel-aura or other click action. Their hover uses
shared `GameTooltip` and `RegisterTooltipIcon`. By default it follows below the
icon; **Tooltip at cursor** uses the shared cursor placement instead. Both modes
retain shared Tooltip scale/hiding, screen clamping and edit suppression. Hiding a
timer or its group clears its hover. Native aura duration captions, including
zero, opacity, expiry, identities, stacks, input handlers and tooltips remain
native. The always-bright, text-free presentation applies only to the received
`AZS_GetTimers()` buttons. Their tooltips retain remaining seconds, full wait and
Ready text; their native timing data is unchanged.

The adapter reads `AZS_GetPhase()` first, then requires received `AZS_TIMERS`
and `AZS_TIMERS_UPDATED` plus a received run clock. It calls the feature-detected
`AZS_GetTimers()` for fresh normalized rows; it never changes the cache or
retains getter tables. Names, kind, duration, remaining and ready are copied
into the pooled view. The native icon string is used directly, with the normal
`Interface\\Icons\\` prefix for bare names and the question-mark fallback for
missing icons. Finite nonnegative times and coherent boolean ready states are
required. Remaining time is not clamped to duration.

`CHAT_MSG_ADDON` prefixes `AZSTIMERS` and `AZSRUN` schedule a deferred read,
after the native API frame has parsed them. `AZS_TIMERS_UPDATED` is a receipt
timestamp rather than a custom event or an expiry deadline. Visible running
waits sample the native getter at most ten times per second. Static, paused,
empty and hidden views stop their updater until relevant delivery or visibility
wakes it. No private cooldown deadline or wall-clock countdown is calculated.

New zones and world leave/logout/reload clear the pooled display and retire
both the timer and run cache identities. Old packets cannot repopulate the view
until new timer/run snapshots arrive. An unavailable phase, getter, clock or
invalid timer list clears only the addon timer icons. The ordinary native aura
buttons remain available on older clients. Both full resets clear the pool and
resample eligible native state. No gameplay data is saved.

The separate Debuffs root adds one passive frame
and reuses shared Layout selection artwork when editing; no gameplay drawing
region, setting, SavedVariable, command, asset, event, reader, updater,
dependency or additional runtime module is added. Both Performance Mode states
share instant placement and per-group hidden deferral.

## Recovery and verification

The API was recovered using REA 6.5.0/Ghidra 12.1.4 from the installed 0.115.0
EXE, SHA-256
`0258b8a43d9ba3170b15e5fc07a646a606eb2972a5dd6aa0e6349a07ec390e2c`.
The native selector is `0x1459721c0..0x145972592`; its formatter is
`0x1458e4220..0x1458e454a`. The exact embedded Lua and hash-bound recovery
reference are documented separately in AzerothSurvivorsRE's
`docs/addon-api/AZS_GetTimers.md` and 0.115.0 addon-timers evidence.

This integration received source review and local formatting with the repository
configuration and pinned StyLua/Prettier versions. No local tests, standalone
syntax/validation checks or addon/game execution were run. GitHub Actions
provides the PR static checks; its results are not awaited during delivery. Live
rendering and event ordering remain unverified.
