# Integrated chat port

The supplied CleanerChat 2.44 source targets Interface 30300. SurvivorsDragonUi uses its glass-style presentation as the starting point for a fixed Interface 11200 chat window. The current priority is visible, complete message text; further visual changes can follow incrementally. No separate chat addon is required. Source attribution and the supplied license metadata are retained in `third_party/CleanerChat-NOTICE.txt`.

## Visible raw-message baseline

The chat window is fixed at 520 by 340 pixels, anchored at the bottom left, 20 pixels from the left edge and 230 pixels above the bottom edge. Tabs remain visible. The selected native `ChatFrameN` renders messages at full opacity inside that window, without a hover or input-focus requirement. Messages do not slide, fade or expire on an addon timer.

The primary chat frame receives all available vanilla message groups while preserving native channel membership and routing. Chat text is passed through unchanged: no message filters, shortened notices, name or channel abbreviations, URL rewriting, or synthesized replacements. The separate combat-log tab retains native combat-log text.

Native chat frames retain scrolling, their own history and game hyperlinks. The shared vanilla `ChatFrameEditBox` keeps slash commands, whisper/reply routing and sent-message history. Native link handling keeps item viewing, modifier-click and player-link actions. The addon does not turn ordinary URLs into custom hyperlinks.

Rendering stays with the native frames because this client can write messages directly to them without going through a Lua `AddMessage` hook. A hook-only replacement would miss those messages even if its own captured history looked complete.

## Copy behavior

The Copy button opens a fixed dialog for the active tab's available history. Use Ctrl+C to copy the selected text. When the client exposes native `GetNumMessages` and `GetMessageInfo` methods, the addon can read the native frame's retained messages. Otherwise it falls back to session capture of Lua `AddMessage` calls. That fallback cannot capture direct client writes and does not promise a complete transcript. Captured text is not saved across reloads.

## Fixed addon policy

Chat uses the game's DEFAULT font, with appearance and placement defined in code. The port does not import the Ace framework, settings windows, profiles, frame movers, SavedVariables, configuration slash commands or 3.3.5 compatibility layers. `/sct on|off|default` remain the addon's only configuration commands.

The earlier message-formatting module is retained as unused source and is not loaded by the TOC. Message visibility does not depend on it or on an animated replacement renderer.

Original Blizzard 1.12.1 implementation references: [chat dispatch](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/ChatFrame.lua), [shared edit box and saved window visibility](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/FloatingChatFrame.xml), [dock selection](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/FloatingChatFrame.lua), and [native link actions](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/ItemRef.lua).

## Source assets

The supplied `Assets/overlayMask.tga` and `Assets/snapToBottomIcon.tga` remain in `media/tex/chat/cleaner_overlayMask.tga` and `media/tex/chat/cleaner_snapToBottomIcon.tga` with their attribution. Retaining those assets does not require the earlier animated renderer or scroll overlay to be active. The source's `Assets/coins.tga` atlas is not incorporated.

## Validation limit

This integration is edited without addon execution. No validation, tests, syntax checks, AzerothSurvivors startups or WoWSilicon startups are run. These notes record the implementation decisions; they do not claim that rendering, message coverage or runtime behavior has been verified in-game.
