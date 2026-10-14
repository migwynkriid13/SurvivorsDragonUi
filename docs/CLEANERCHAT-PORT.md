# Integrated chat port

The supplied CleanerChat 2.44 source targets Interface 30300. SurvivorsDragonUi adapts its glass-style presentation for a fixed Interface 11200 chat window, including fading, animation and styled controls. Incoming messages retain their original text. Here, "prettify" means formatting the messages themselves; those changes are deferred until requested. No separate chat addon is required. Source attribution and the supplied license metadata are retained in `third_party/CleanerChat-NOTICE.txt`.

## Presentation and incoming text

The chat window is fixed at 520 by 340 pixels, anchored at the bottom left, 20 pixels from the left edge and 230 pixels above the bottom edge. It uses the game's DEFAULT font at 12 pixels with an outline, #111111 backgrounds at 0.05 opacity, amber text-only tabs and a stripped native input skin. New activity slides the message pane into position over 0.35 seconds. Native message lines remain visible for 14 seconds before a 0.6-second fade; hovering, scrolling or opening the input reveals retained messages. Revealing old, faded history fades the pane in over 0.6 seconds, without restarting that intro on each wheel notch. The tab dock fades in over 0.3 seconds and out over 0.6 seconds after 10 seconds of inactivity. A scroll indicator provides a way to return to the latest messages and signals unread activity while viewing history; inactive tabs pulse for unread messages.

The primary chat frame receives all available vanilla message groups while preserving native channel membership and routing. Chat text is passed through unchanged: no message filters, shortened notices, name or channel abbreviations, URL rewriting, or synthesized replacements. Presentation animation does not authorize changes to that text. The separate combat-log tab retains native combat-log text.

Native chat frames retain scrolling, their own history and game hyperlinks. The shared vanilla `ChatFrameEditBox` keeps slash commands, whisper/reply routing and sent-message history. Native link handling keeps item viewing, modifier-click and player-link actions. The addon does not turn ordinary URLs into custom hyperlinks.

Rendering stays with the native frames, preserving their output even when a write does not pass through the Lua `AddMessage` hook. Message visibility is independent of the copy/animation hook. The original blank custom-row display was not diagnosed in-game; this implementation also retries setup if the first native frame is not ready at addon initialization.

The [benilla message-frame API](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/messageframe/scrolling.rs) exposes native fade and scroll controls. Its [message-frame state](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/widget/kinds/messageframe.rs) rearms displayed-line fade timers on scroll. The addon reveals without copying or rewriting messages: Down at the bottom, or Down followed by Up elsewhere, restores the same scroll position and refreshes displayed lines. Hover/focus temporarily disables native fading, and leaving restores fading with a fresh hold interval. Optional methods are feature-detected; these primary-source references do not establish the exact packaged client's implementation. Native history is preserved: the addon does not call `SetMaxLines`, which clears that history in the referenced implementation.

## Copy behavior

The Copy button opens a fixed dialog for the active tab's available history. Use Ctrl+C to copy the selected text. When the client exposes native `GetNumMessages` and `GetMessageInfo` methods, the addon can read the native frame's retained messages. Otherwise it falls back to session capture of Lua `AddMessage` calls. That fallback cannot capture direct client writes and does not promise a complete transcript. Captured text is not saved across reloads.

## Fixed addon policy

Chat uses the game's DEFAULT font, with appearance and placement defined in code. The port does not import the Ace framework, settings windows, profiles, frame movers, SavedVariables, configuration slash commands or 3.3.5 compatibility layers. `/sct on|off|default` remain the addon's only configuration commands.

The earlier message-formatting module is retained as unused source and is not loaded by the TOC. Message visibility does not depend on it or on capturing Lua `AddMessage` calls. The visual skin and animation remain active around the native message renderer.

Original Blizzard 1.12.1 implementation references: [chat dispatch](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/ChatFrame.lua), [shared edit box and saved window visibility](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/FloatingChatFrame.xml), [dock selection](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/FloatingChatFrame.lua), and [native link actions](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/ItemRef.lua).

## Source assets

The supplied `Assets/overlayMask.tga` and `Assets/snapToBottomIcon.tga` remain in `media/tex/chat/cleaner_overlayMask.tga` and `media/tex/chat/cleaner_snapToBottomIcon.tga` with their attribution. The scroll indicator uses the supplied return-to-bottom artwork. The source's `Assets/coins.tga` atlas is not incorporated because incoming money notices retain their original text.

## Validation limit

This integration is edited without addon execution. No validation, tests, syntax checks, AzerothSurvivors startups or WoWSilicon startups are run. These notes record the implementation decisions; they do not claim that rendering, message coverage or runtime behavior has been verified in-game.
