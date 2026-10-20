# Layout handles and alignment grid

`/sdui lock` enters the existing layout editing session with move/resize handles and the same shared Confirm button, centered in the middle of UIParent. It does not create or show the settings dialog on first use. Clicking a handle does not open it either. The button retains the editor's normal artwork, dimensions and confirmation action.

`/sdui` shows the full editor within the same session. Switching either way retains staged geometry and display, timer and combat-text drafts. Entering handles-only mode discards unapplied numeric text, while keeping geometry already staged with Apply or pointer editing. Confirm saves the session and hides the handles. World leave, logout and reload retain the existing draft-discard behavior; neither command adds a saved mode or window position.

Both modes show a screen-wide alignment grid behind the HUD and editing controls. Squares are 32 UI units apart, measured outward from the exact screen center, with stronger lines every four squares. The horizontal and vertical center axes are gold and two physical pixels thick; other lines are one physical pixel thick. The overlay accepts no mouse input and adds no snapping or movement changes.

`core/layout.lua` lazily creates the grid from pooled native `WHITE8X8` textures. It uses `GetLocalSize(UIParent)` for rendered extents and effective UI scale for line thickness. While editing, cached dimensions/scale trigger a rebuild only when the viewport changes; surplus lines hide and later sessions reuse the pool. The shared close path hides it immediately on Confirm, Cancel, either reset, world leave, logout or reload discard. Invalid numeric input keeps the existing session and its grid open. Switching between `/sdui` and `/sdui lock` keeps the same centered grid. It adds no asset, setting, SavedVariable or layout entry.

`core/layout.lua` owns the session, mode, handles and Confirm button. The settings dialog registers one visibility callback; run-font editing still owns its existing previews and saving. This separates showing the dialog from beginning its drafts without another confirmation control or parallel layout store. A closed session clears the handles-only mode, so ordinary `/sdui` continues to open the full editor.

No local checks, tests, syntax/formatting tools or addon/game execution were run. GitHub Actions supplies the authorized static checks; live input and appearance remain unverified.
