# Action buttons

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
Local tests, syntax checks, formatters and addon/game execution were intentionally
not run. GitHub Actions supplies static checks; native swap behavior and rendering
still require in-game confirmation.

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
