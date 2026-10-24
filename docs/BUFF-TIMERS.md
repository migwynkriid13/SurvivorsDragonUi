# Native timers in Buffs

On Azeroth Survivors 0.115.0 or newer, the existing Buffs group appends the
received talent and jewelry timers after native buffs, debuffs and weapon
enchants. All returned effects are shown in native order, including separate
effects with the same name. An elapsed wait stays visible with a bright icon
and zero beneath it. Timer borders stay neutral. A waiting timer uses a dimmed icon and its
remaining time, rounded upward for the compact label.

Hover shows the supplied source name, Next summon or Cooldown, full wait to
one decimal place, and remaining seconds or Ready. These five captions use all
fourteen source/runtime UI catalogs. Ready means the wait has elapsed; native
proc triggers, summon caps and other conditions still apply. Summon timers
describe the next summon. Existing Pet frames continue to describe the summons
already out and their lifetimes.

## Shared view and native boundary

`modules/unit/auras.lua` owns both the original native buttons and a passive
pool of timer buttons. Both use the same 28-unit icons, six-column wrapping,
duration placement, flip direction and existing `buffs` Layout entry. Changing
the pool's visible row count updates measured bounds through shared Layout,
preserving confirmed/draft center and scale and the default top-right edge.
Move, resize, hide, Confirm, Cancel, profiles and both resets keep their existing
ownership. New native auras do not need a separate layout path.

Timer buttons have no cast, cancel-aura or other click action. Their hover uses
shared `GameTooltip` and `RegisterTooltipIcon`. By default it follows below the
icon; **Tooltip at cursor** uses the shared cursor placement instead. Both modes
retain shared Tooltip scale/hiding, screen clamping and edit suppression. Hiding a
timer or its group clears its hover. Native aura content, stacks, updates,
input handlers and tooltips remain native.

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
resample eligible native state. No gameplay data is saved and no setting,
SavedVariable, command, asset, dependency or additional runtime module is added.

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
