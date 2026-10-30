# Named profiles

`/sdui` has a **Profiles** page for saving, loading, overwriting and deleting named addon setups. **Save profile and close** and **Overwrite and close** validate and save the named profile together with the current layout, display choices, timer styling and combat-text mode, then close the editor. Enter in the name field uses the same save action. No second Confirm click is required.

Loading or deleting a profile remains a preview until Confirm. Cancel, world leave, logout and the wrapped ReloadUI path discard only uncommitted edits. Addon defaults and `/sdui reset` reset the active setup without erasing saved profiles.

## Stored data

The explicit profiles request adds one SavedVariable, `SurvivorsDragonUiProfiles`, containing a table keyed by the user-supplied name. Each record contains only:

- `layout`: independent copies of confirmed or currently staged geometry and optional hidden flags, including registered defaults and retained lazy-window records. Explicit `hidden = false` is retained for opt-ins such as the default-hidden Revive group.
- `display`: the existing normalized display options.
- `runFont`: the existing normalized timer font settings.
- `sctMode`: the existing addon combat-text mode, when that module is available.

No run snapshots, boss-schedule handoff, inventory, subjects, timer values, summon data or native game preferences are included. Incoming/self combat text stays in the game's own settings; choosing a saved addon SCT mode reuses the same native outgoing-text preview and rollback as the existing mode buttons.

The registry is not an active-profile pointer or an automatically updated binding. Saving captures that setup at that moment; later edits do not alter it unless the user chooses **Overwrite and close**. Copies pass through the owning layout, display, timer and SCT normalization paths, with no arbitrary recursive serialization or shared nested tables. Invalid stored profile records are ignored. Names are trimmed and kept case-sensitive; control characters, markup pipes and excessive byte lengths are rejected. The UI uses a single-line, 48-character native input and never slices UTF-8 names. Names remain literal even when they match a translated addon caption.

## Editor integration

`core/profiles.lua` initializes after shared Layout and Display. It exposes the registry transaction and builds one editor page with a name input, five paged selection rows and the existing button artwork. Actions and sidebar sizing measure all fourteen caption catalogs. Paging supports any number of user-created profiles without a new scroll frame or updater.

Layout captures pending valid numeric text and finishes pointer editing before a save. Invalid numeric values retain the session and open Layout's existing error display. Loading explicitly replaces the staged setup and clears unapplied coordinate text; it does not save the result. Display options load before geometry so attached/detached groups use the loaded attachment choices. Native per-module visibility ownership remains in the shared layout path; loading cannot force an inactive target or encounter visible.

The shared layout session begins and finishes the profile transaction once. `layout.ConfirmEdit()` is the common entry point for the main Confirm button and `profiles.Save`. A successful profile save stages its normalized snapshot and completes that whole transaction, including any earlier staged profile changes. The commit returns success only after closing and restoring the registered views. A rejected commit restores the previous staged record; invalid names or numeric Layout input leave editing open without changing confirmed data. The Profiles page avoids hidden caption writes after a successful close.

SavedVariables are updated through the existing owners. The client writes those globals using its normal reload/logout persistence; SDUI adds no direct filesystem writer or persistence hook. Saved profiles survive both full-reset entry points; pending profile edits are discarded on reset. `core/profiles.lua` is included in the shared TOC and runtime manifest. No command, asset, external dependency or gameplay persistence is added.

Layout side widths are copied alongside position, scale and hidden state. The default-on grid preference and meter/boss/guardian row capacities use the existing normalized display snapshot. Boss/guardian zero capacity retains automatic full-list sizing; positive values define a scrollable viewport. Scroll offsets remain session-only. Loading a profile without these choices uses their defaults, and Cancel restores the previous width and row choices through the same shared owners.

## Verification boundary

CI-only cases exercise the real Layout, Display and Profiles owners together, with explicit fake native geometry and font/SCT owner boundaries. They cover pending numeric input, one-step save/overwrite, independent snapshots, failed validation, Cancel, load/delete preview, reload/world cleanup and saved-profile preservation on reset. Fresh Display/Profiles owners receive copied confirmed globals and load the saved setup. Production editor controls cover the save button, overwrite, Enter, failure recovery and translated captions. These mocks do not exercise the client's on-disk serializer, external addon managers or filesystem failures.

Source and diff inspection plus pinned StyLua/Prettier formatting only. Local tests, standalone syntax/validation and addon/game execution were not run. GitHub Actions supplies static checks and was not awaited or polled. Packaged-client rendering and interaction remain unverified.
