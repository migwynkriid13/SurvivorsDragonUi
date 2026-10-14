# Integrated chat port

The supplied CleanerChat 2.44 source targets Interface 30300. Its chat presentation and message formatting are adapted directly into SurvivorsDragonUi for Interface 11200; CleanerChat is not a separate installation requirement. Source attribution and the supplied license metadata are retained in `third_party/CleanerChat-NOTICE.txt`.

## Chat presentation

The replacement uses a fixed 520-by-340 chat window anchored at the bottom left, 20 pixels from the left edge and 230 pixels above the bottom edge. Chat tabs retain separate session-only histories of up to 128 messages. New messages slide into view over 0.35 seconds, remain visible for 14 seconds and fade over 0.6 seconds. Mouse hover or edit-box focus reveals the history.

Native `ScrollingMessageFrame` rows retain hyperlink handling. The replacement includes scrolling, a jump-to-bottom control with an unread indicator, and a copy-history window. The native chat edit box remains responsible for input and sending, so native routing and channel membership continue to apply.

Scroll with the mouse wheel; hold Shift for larger steps. Clicking the bottom indicator returns to the newest message. The Copy button selects the active tab's captured history in a fixed dialog; URL clicks select the address there. Use Ctrl+C to copy. History is not saved across reloads. The combat-log tab uses the same presentation while retaining its full text.

## Fixed addon policy

Chat uses the game's DEFAULT font, with appearance and placement defined in code. The port does not import the Ace framework, CleanerChat's settings windows, profiles, frame movers, SavedVariables or configuration slash commands. `/sct on|off|default` remain the addon's only configuration commands.

The 3.3.5 compatibility layers are not imported. The port uses 1.12 chat dispatch and edit-box behavior and preserves messages that its formatter cannot recognize. Money formatting uses text for gold, silver and copper, avoiding reliance on newer embedded texture markup.

The native `ChatFrameEditBox` keeps slash commands, whisper/reply routing and sent-message history. Native chat frames remain active at alpha zero: forcing `Hide()` would invoke vanilla's saved window-visibility handling. Non-URL links use the native link handler, including its item viewing, modifier-click and player-link behavior. Recognized loot, XP, reputation, skill, quest and status notices become shorter; unknown announcements and errors remain visible. Wrath-only/server-specific filters and inventory/vendor/trade synthesis are omitted.

Original Blizzard 1.12.1 implementation references: [chat dispatch](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/ChatFrame.lua), [shared edit box and saved window visibility](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/FloatingChatFrame.xml), [dock selection](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/FloatingChatFrame.lua), and [native link actions](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/ItemRef.lua).

## Source assets

The supplied `Assets/overlayMask.tga` and `Assets/snapToBottomIcon.tga` are incorporated as `media/tex/chat/cleaner_overlayMask.tga` and `media/tex/chat/cleaner_snapToBottomIcon.tga`. They support the Glass scroll overlay and jump-to-bottom control and use `SurvivorsDragonUi` runtime paths. The source's `Assets/coins.tga` atlas is not incorporated.

## Validation limit

This integration is edited without addon execution. No validation, tests, syntax checks, AzerothSurvivors startups or WoWSilicon startups are run. These notes record the adaptation decisions; they do not claim that its rendering or runtime behavior has been verified in-game.
