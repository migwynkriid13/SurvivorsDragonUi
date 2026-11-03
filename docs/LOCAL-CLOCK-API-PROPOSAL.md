# Proposal: native local-clock API

Status: proposed game API with a capability-detected addon consumer. Game-side
availability and live behavior remain unverified.

## Problem

The supplied game changelog describes a small local-time clock below the
minimap. It shows the computer's or phone's local time: `10:42 PM` in English
and `22:42` in the other languages. It moves and hides with the minimap and
follows the game's HUD Scale setting.

As reported, addons cannot read this clock or independently hide/show it.
An addon that draws its own clock therefore leaves the native clock visible
too. Turning off the addon's clock also cannot control the native one.

Please expose the native local time and add this widget to the existing HUD
visibility API so addons can offer Game, Custom or Off without duplicate clocks.

## Requested API

### Read the native local time

```lua
local clock = AZS_GetLocalTime()
```

Return one snapshot from the same device-local wall-clock source and formatter
used by the native minimap clock:

| Field      | Type    | Meaning                                                         |
| ---------- | ------- | --------------------------------------------------------------- |
| `text`     | string  | Exact native display text, such as `10:42 PM` or `22:42`.       |
| `hour`     | number  | Local hour as an integer from 0 to 23, regardless of format.    |
| `minute`   | number  | Local minute as an integer from 0 to 59.                        |
| `is24Hour` | boolean | `false` for the English format; `true` for the other languages. |

All fields must describe the same reading. The returned table is a detached
snapshot; changing it must not change native state. Return `nil` if local time
is temporarily unavailable, rather than a placeholder or stale reading.

The getter must work while the native clock or minimap is hidden, so an addon
can replace the presentation. It must not depend on an active run, target,
server packet or visible native widget.

Use the game's selected language for `text` and `is24Hour`, matching the
changelog rather than assuming the operating system's language. Reflect minute
rollovers, midnight/noon, language changes, device time/timezone changes,
daylight-saving changes and resuming the game. Pausing or choosing a card must
not freeze local wall time. This is separate from `AZS_GetRunTime()`.

### Hide or show only the native local clock

Extend the existing HUD API with a distinct `localClock` part:

```lua
AZS_SetHudShown("localClock", false) -- Hide the native local clock.
AZS_SetHudShown("localClock", true)  -- Allow the native local clock to show.
local enabled = AZS_IsHudShown("localClock")
```

| Part         | Controls                       | Proposed CVar   |
| ------------ | ------------------------------ | --------------- |
| `localClock` | Local time below the minimap   | `hudLocalClock` |
| `clock`      | Existing run timer / next boss | `hudClock`      |

Keep the existing `clock` part unchanged. Hiding `localClock` must not hide the
minimap, zone name, run timer or another HUD component.

Follow the existing HUD preference contract: `hudLocalClock` is `"1"` when
enabled and `"0"` when disabled, shared with a game Interface checkbox and saved
by the game. Existing installations default to enabled, preserving the new
native clock. Include this part in `AZS_SetHudShown("all", shown)` and its
existing `nil` equivalent.

`AZS_IsHudShown("localClock")` returns the boolean configured preference,
independently of whether the minimap is currently visible. Setting it to `true`
must not force a hidden minimap or its clock onto the screen. When enabled, the
native clock retains its normal minimap movement, inherited hiding and HUD
Scale behavior. Disabling it hides only its native presentation; the time
getter remains available.

## Addon handoff

Ship the new getter and HUD part together. Addons must feature-detect
`AZS_GetLocalTime` as well as the existing HUD functions; the HUD functions alone
already exist on builds that lack local-clock support.

| Addon choice | Custom clock | Native local clock                                           |
| ------------ | ------------ | ------------------------------------------------------------ |
| Game         | Hidden       | Explicitly enabled; still follows minimap visibility.        |
| Custom       | Shown        | Hidden only after the replacement has a usable time reading. |
| Off          | Hidden       | Explicitly disabled.                                         |

For temporary replacement ownership, capture the prior native preference and
restore it when the replacement is disabled, unavailable or unloaded. Respect
later external preference changes through the addon's existing HUD ownership
helper; cleanup must not unconditionally enable a previously hidden clock.
Keep preview/Cancel and reload cleanup consistent with other replaced HUD parts.

On older builds, keep the existing addon fallback and avoid calling an unknown
HUD part. Read through an existing visible-clock controller at a bounded cadence
and skip unchanged text writes; no per-frame getter polling or additional server
messages are needed for a minute display.

## Acceptance criteria

- English displays `10:42 PM`; other game languages display `22:42` for the same
  local time. Midnight and noon have correct native formatting.
- The getter continues returning current device-local time while the native
  clock is disabled, the minimap is hidden or the game is paused.
- Hiding/showing `localClock` affects only that widget and leaves the existing
  `clock` part independent. Getter reads have no visibility side effects.
- The native clock moves, hides and scales with the minimap as before; enabling
  its preference while the minimap is hidden does not reveal either widget.
- Custom mode shows one clock. Off shows neither. Cleanup restores the captured
  preference unless a later external choice superseded it.
- Time, timezone and game-language changes recover without a restart. Reload
  reinstalls the API and exposes current time without waiting for run packets.

## Reference and scope

### Current addon integration

The existing **Minimap → Show clock** checkbox selects Custom when on and Off
when off; it is on by default. Missing/invalid choices and resets select on,
while an explicitly saved off choice stays off. The addon consumes this proposal's native
snapshot when available and formats its hour/minute fields as 24-hour `HH:MM`,
independently of the native text's language or AM/PM format. Its hover uses the
same reading. Native visibility is acquired only after the separate `localClock`
part is recognized; the existing shared HUD owner handles external preferences
and cleanup. Older builds keep the date fallback without unknown visibility
writes. This integration adds no Game mode or format setting.

The existing visible sixty-second worker handles reads and retries; off and
hidden clocks detach it. Missing/invalid native readings or failed handoffs
hide custom text and release the native preference. Reappearing clocks sample
fresh time. CI-only cases cover these contracts, but were not run locally and
do not establish provider availability, native rendering or persistence.

The existing names and preference behavior come from the supplied
[addon API reference](AzerothSurvivors-Addon-API.md#hiding-the-games-hud).
The current addon clock is described in
[Minimap buttons](MINIMAP-BUTTONS.md#optional-local-clock).

The native-clock behavior and access limitation above come from the user's
changelog and report. The proposed names and contracts require game-side
implementation and confirmation. The addon integration described above does
not implement the native provider or claim live API verification.
