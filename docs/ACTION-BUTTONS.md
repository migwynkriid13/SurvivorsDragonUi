# Action buttons

## Bar choice

**Use SDUI action bar** in `/sdui` → **Action bar** starts on. The normalized
`customActionBar` boolean lives in the existing display table. Missing or
invalid values and both full resets select SDUI. The shared editor retains
live preview, Confirm-only saving, Cancel/discard and profiles.

Turning it off restores the game's default bottom bar, including its native XP
bar. The SDUI bar and XP presentation are hidden. Jewelry and counters use their
existing detached owners and saved detached geometry; their attachment choices
stay saved and become effective again when SDUI is selected. The native bar
keeps its original artwork, buttons, geometry and handlers.

SDUI's Lock action buttons, Cooldown numbers, Show gryphons, Attach XP and Show
XP text controls dim and disable input while the game bar is selected. Jewelry
and counter attachment controls also disable without changing their values;
jewelry keeps its existing Equipped jewelry dependency. These controls reuse the
shared availability refresh and add no separate listener or updater. The title
and hint have all fourteen UI translations.

Both Performance Mode states use the same native-bar handoff and detached
attachments. Existing normal/static SDUI effects return with the SDUI bar.
CI-only coverage is authored; local work uses source review and pinned formatting,
with no local tests, standalone validation or addon/game execution.

## SDUI button swapping

`lockActionButtons` is a normalized boolean in the existing display table. It
starts true, previews through the shared editor, saves only with Confirm, and
uses the existing discard and full-reset paths. Both full resets restore locked.

When unlocked, Shift-left-click selects an occupied native button without
picking anything up. The gold overlay marks that selection. Shift-left-click a
second occupied button to exchange the actions. Selecting the same or an empty
button cancels. Ordinary clicks cancel selection and retain native activation;
key bindings and self-cast handling remain native.

The exchange checks both slots and requires the native pickup/place and cursor
APIs with no held spell or item. Only the synchronous exchange calls
`PickupAction(source)`, `PlaceAction(target)` and, while a spell remains held,
`PlaceAction(source)`. A refused target therefore returns the source spell.
The first two calls are protected so an error still reaches source restoration.
No user interaction or frame update is inserted between these calls. All drag
handlers remain disabled and ordinary activation still uses `checkCursor = 0`.
There is no removal path, empty destination or external replacement intake.

Selection is session-only and clears on action-slot updates, world boundaries,
logout, hiding, ordinary activation, display changes and layout entry/exit.
No action order or gameplay state is copied into addon SavedVariables; the
native action APIs own the exchanged slots and their usual persistence.

The installed executable exposes `PickupAction`, `PlaceAction`, `CursorHasSpell`
and `CursorHasItem`; no retail-only cursor or action-info API is required.
Local work uses source review and pinned formatting. GitHub Actions supplies
static checks and CI-only mocked lifecycle coverage; native swap behavior and
rendering still require in-game confirmation. No local tests, standalone
validation or addon/game execution were run.

## Native source evidence

Read-only disassembly of the installed Windows executable, SHA-256
`e069bf3152f8d8f7160d66388907fc181c733bd170aa150d3b7ff7adf251e048`,
resolves the registered callbacks to pickup at `0x1458078d0` and place at
`0x145804930`. Pickup reads the action through `0x145808d40` and removes its
slot entry. Place reads the destination through the same helper at
`0x14580660a`, retains that displaced action, writes the incoming action, and
returns the retained action through the native cursor setter at
`0x1458054df`. This supports the three-call occupied-slot exchange; it does
not establish live rendering or persistence across a native run reset.
