# Editing without the dialog

`/sdui lock` enters the existing layout editing session with move/resize handles and the same shared Confirm button, centered 24 UI units above the bottom of UIParent. It does not create or show the settings dialog on first use. Clicking a handle does not open it either. The button retains the editor's normal artwork, dimensions and confirmation action.

`/sdui` shows the full editor within the same session. Switching either way retains staged geometry and display, timer and combat-text drafts. Entering handles-only mode discards unapplied numeric text, while keeping geometry already staged with Apply or pointer editing. Confirm saves the session and hides the handles. World leave, logout and reload retain the existing draft-discard behavior; neither command adds a saved mode or window position.

`core/layout.lua` owns the session, mode, handles and Confirm button. The settings dialog registers one visibility callback; run-font editing still owns its existing previews and saving. This separates showing the dialog from beginning its drafts without another confirmation control or parallel layout store. A closed session clears the handles-only mode, so ordinary `/sdui` continues to open the full editor.

No local checks, tests, syntax/formatting tools or addon/game execution were run. GitHub Actions supplies the authorized static checks; live input and appearance remain unverified.
