# Stored-level button

The game's stored-level **Level Up!** button is drawn outside Lua's frame system. Its public addon API supports hiding the original, reading the waiting count and opening the choices. It does not expose the original button's anchors or artwork for direct movement or reskinning.

`modules/ui/levels.lua` supplies an addon-owned replacement with a plain gold border around the native class icon and a round waiting-count badge at its upper-right, inset below the backdrop's top edge. The single **CHOOSE UPGRADE** heading centers vertically beside the icon, with no current-level caption or decorative flourishes. It uses native Skurri 22 with outline and shadow, initialized with DEFAULT as a fallback, and the existing fourteen-language system. The badge and editor label retain DEFAULT. The complete icon/text group and its backdrop fit the active translation with compact side padding, centered inside the multilingual edit bounds. A soft-edged translucent black backdrop improves contrast, with a gold halo and icon-frame glow pulsing every 1.8 seconds while the button is visible with waiting levels. Text stays steady. Hiding the group, spending its final waiting level or world cleanup stops and resets its cosmetic pulse. See [artwork sources and preparation](../third_party/LevelUp-ARTWORK.md).

## Native API

Read-only inspection of the current local executable's embedded Lua confirms:

- `AZS_GetStoredLevels()` reads `AZS_RUN.sl`, defaulting to zero before that field arrives.
- `AZS_OpenStoredLevels()` requests the game's existing action with `SetCVar("spendLevels", "1")`.
- `AZS_SetHudShown("levels", false)` and `AZS_IsHudShown("levels")` control the original button through `hudLevels`.

The replacement requires these functions, a recognized active run phase, a received `AZS_RUN_UPDATED` snapshot and a positive integer count. Missing data, unsupported APIs, zero waiting levels and terminal/out-of-run phases hide the replacement and release its native visibility ownership. The native count, queue, choices, pause behavior and Store Level-Ups preference remain game-owned; the addon does not change the storing preference.

Data is read at most ten times a second. `AZSRUN` schedules a read on the next frame so native parsing can finish first. World leave retires the old run-table reference, so re-entry waits for a replacement snapshot. No count, level, queue or run snapshot is saved.

The original is hidden only after the replacement has been built and populated and the supported HUD getter confirms suppression. Its captured visibility distinguishes an originally hidden preference from an uncaptured one. The addon restores it when data is unavailable, on world leave/logout and before the real ReloadUI call saves native preferences. Older builds retain their original UI.

## Shared layout

`levelUp` is an independent group in the existing layout registry, labeled **CHOOSE UPGRADE**. Its default anchor is centered 190 UI units above the bottom of UIParent. Its width fits the new heading across all supported languages, while its compact backdrop fits only the active translation. The inner visual retains the requested 0.7 default scale. The icon, text, badge and gold frame scale together. The shared Layout scale stays relative to this design, so confirmed scale and position records remain unchanged.

The existing editor owns dragging, corner resizing, numeric placement, Hide frame, Confirm, Cancel, both full resets and world/reload draft discard. Only confirmed geometry and optional visibility use `SurvivorsDragonUiLayout`; no SavedVariable, display setting or command is added. The layout handle remains available when no levels are waiting without showing invented counts or enabling a gameplay click. Its label sits above the box so it cannot overlap the real heading. Editing disables the button's click action.

## Evidence limits

The executable inspected for the API contract on 2026-10-20 has SHA-256 `96e24dcd0e53fc13a6fdef5826aa46f77a29aa1aad4abd585adf04e94b2756d3`. The user-requested **CHOOSE UPGRADE** heading is addon wording, with thirteen translations in `localization/ui.tsv` and matching runtime entries. The removed native `Level Up!` and `LEVEL {n}` captions are no longer selected by this addon. Other generated text and the localization generator's reviewed source fingerprint are unchanged.

Source inspection and text-data extraction do not establish packaged-game rendering, mouse behavior or reload parity. Local validation, tests, syntax/formatting tools and addon/game execution were intentionally not run. The PR uses the existing GitHub Actions static checks.
