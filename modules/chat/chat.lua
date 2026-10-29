-- CleanerChat presentation with only the explicitly requested message formats.
-- Source credits are retained in third_party/CleanerChat-NOTICE.txt.
DFRL:NewMod("Chat", 1, function()
    if DFRL.display.Get("defaultChat") then return end
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local chat = DFRL.CleanerChat
    local initialized = false
    local Initialize

    Initialize = function()
        if initialized or not ChatFrame1 then return end
        initialized = true

        local WIDTH, HEIGHT = 520, 340
        local FOOTER_HEIGHT = 32
        local HOLD, FADE, SLIDE = 14, 0.6, 0.35
        local states, selected = {}, nil
        local input = _G.ChatFrameEditBox or _G.ChatFrame1EditBox or ChatFrame1.editBox
        local RefreshFrames, SelectChat, PositionInput, UpdateIndicator
        local focused = false
        local performanceMode = DFRL.display.Get("performanceMode")

        local root = CreateFrame("Frame", "SurvivorsDragonUiChat", UIParent)
        root:SetWidth(WIDTH)
        root:SetHeight(HEIGHT)
        -- Leave only enough bottom clearance for the input and scroll indicator.
        root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 40)
        root:SetFrameStrata("LOW")
        root:SetAlpha(1)
        root:Show()
        chat.frame = root
        local rootWidth, rootHeight = WIDTH, HEIGHT
        -- Include the native input and passive indicator below the message pane.
        local moveRegion = CreateFrame("Frame", nil, root)
        moveRegion:SetPoint("TOPLEFT", root, "TOPLEFT", -1, 0)
        moveRegion:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, -FOOTER_HEIGHT)

        local function Flag(value) return value == true or value == 1 end
        local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end
        local function Contains(list, value)
            if type(list) ~= "table" then return false end
            for _, entry in pairs(list) do
                if entry == value then return true end
            end
            return false
        end
        local function Label(parent, text, size)
            local label = parent:CreateFontString(nil, "OVERLAY")
            DFRL.locale.Bind(label)
            T.SetFont(label, size or 12, "OUTLINE")
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            label:SetText(text or "")
            return label
        end
        local function HideControl(control)
            if not control then return end
            control:Hide()
            control.Show = control.Hide
        end
        local function ReadDimensions()
            rootWidth, rootHeight = root:GetWidth(), root:GetHeight()
        end
        local function HasAnchor(frame, point, relative, relativePoint, x, y)
            if not frame.GetNumPoints or not frame.GetPoint or frame:GetNumPoints() ~= 1 then return false end
            local currentPoint, currentRelative, currentRelativePoint, currentX, currentY = frame:GetPoint(1)
            return currentPoint == point
                and currentRelative == relative
                and currentRelativePoint == relativePoint
                and T.NearlyEqual(currentX, x)
                and T.NearlyEqual(currentY, y)
        end
        local function LockNativeMovement(frame)
            -- FloatingChatFrameTemplate gives the message pane a full-size
            -- TitleRegion. Its native drag path is separate from SetMovable;
            -- only the shared Layout handles may move the chat container.
            local title = frame.GetTitleRegion and frame:GetTitleRegion()
            if
                title
                and (
                    not HasAnchor(title, "TOPLEFT", frame, "TOPLEFT", 0, 0)
                    or title:GetWidth() ~= 0
                    or title:GetHeight() ~= 0
                )
            then
                frame:StopMovingOrSizing()
                title:ClearAllPoints()
                title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                title:SetWidth(0)
                title:SetHeight(0)
            end
            if frame.IsMovable and Flag(frame:IsMovable()) then
                frame:StopMovingOrSizing()
                frame:SetMovable(false)
            end
        end

        local regularNotices = {
            COMBAT_XP_GAIN = true,
            COMBAT_HONOR_GAIN = true,
            COMBAT_FACTION_CHANGE = true,
            SPELL_TRADESKILLS = true,
            SPELL_ITEM_ENCHANTMENTS = true,
        }
        local function IsCombatLogGroup(group)
            if regularNotices[group] then return false end
            return string.find(group, "^COMBAT_") ~= nil or string.find(group, "^SPELL_") ~= nil
        end
        local function ConfigureRegularChat()
            if type(ChatTypeGroup) == "table" then
                for group in pairs(ChatTypeGroup) do
                    if type(group) == "string" then
                        if IsCombatLogGroup(group) then
                            -- Undo combat subscriptions saved by the earlier
                            -- all-groups setup; leave ChatFrame2 untouched.
                            if ChatFrame_RemoveMessageGroup and Contains(ChatFrame1.messageTypeList, group) then
                                ChatFrame_RemoveMessageGroup(ChatFrame1, group)
                            end
                        elseif ChatFrame_AddMessageGroup and not Contains(ChatFrame1.messageTypeList, group) then
                            ChatFrame_AddMessageGroup(ChatFrame1, group)
                        end
                    end
                end
            end
            if GetChannelList and ChatFrame_AddChannel then
                local channels = { GetChannelList() }
                for i = 2, table.getn(channels), 2 do
                    local name = channels[i]
                    if name and not Contains(ChatFrame1.channelList, name) then
                        ChatFrame_AddChannel(ChatFrame1, name)
                    end
                end
            end
        end
        local function AtBottom(state)
            if state.native.AtBottom then return Flag(state.native:AtBottom()) end
            return not state.scrolled
        end
        local function FadeSettings(state, held)
            local duration = performanceMode and 0 or FADE
            if state.fadeConfigured and state.fadeDuration == duration and state.held == held then return end
            if not root:IsVisible() then return end
            local frame = state.native
            if not state.fadeConfigured or state.fadeDuration ~= duration then
                -- Keep the same total lifetime; Performance Mode replaces
                -- only the final fade with an instant native disappearance.
                if frame.SetTimeVisible then frame:SetTimeVisible(performanceMode and HOLD + FADE or HOLD) end
                if frame.SetFadeDuration then frame:SetFadeDuration(duration) end
                state.fadeConfigured, state.fadeDuration = true, duration
            end
            if state.held ~= held then
                if frame.SetFading then frame:SetFading(not held) end
                state.held = held
            end
        end
        local function Rearm(state)
            if not state then return end
            local frame = state.native
            -- The native engine rearms displayed-line fade timers on scroll.
            -- At the bottom, Down is a no-op. Else Down/Up restores the offset.
            -- This preserves stored text, colors, hyperlinks and message order.
            if AtBottom(state) then
                if frame.ScrollDown then frame:ScrollDown() end
            elseif frame.ScrollDown and frame.ScrollUp then
                frame:ScrollDown()
                frame:ScrollUp()
            end
        end
        local function Reveal(state)
            local now = GetTime()
            if state then
                local lastVisible = math.max(state.lastActivity or 0, state.lastReveal or 0)
                if not performanceMode and now - lastVisible >= HOLD + FADE then
                    state.revealStart, state.visualAlpha = now, 0
                end
                state.lastReveal = now
                Rearm(state)
            end
        end
        local function PositionNative(state, now, refresh)
            if not root:IsVisible() then return end
            local frame = state.native
            local progress = not performanceMode and state.slideStart and Clamp((now - state.slideStart) / SLIDE, 0, 1)
                or 1
            local shift = -12 * (1 - progress) * (1 - progress) * (1 - progress)
            local y, width, height = -5 + shift, rootWidth - 6, rootHeight - 5
            -- Native window events can replace presentation settings. Recheck
            -- them at the existing refresh points, outside the slide hot path.
            if refresh then
                LockNativeMovement(frame)
                state.anchored = HasAnchor(frame, "TOPLEFT", root, "TOPLEFT", 3, y)
                state.positionY = state.anchored and y or nil
                state.width, state.height = frame:GetWidth(), frame:GetHeight()
                T.SetChatFont(frame)
                T.SetChatShadow(frame)
                if frame.SetJustifyH and (not frame.GetJustifyH or frame:GetJustifyH() ~= "LEFT") then
                    frame:SetJustifyH("LEFT")
                end
            end
            if not state.anchored then
                frame:ClearAllPoints()
                state.anchored = true
                state.positionY = nil
            end
            if state.positionY ~= y then
                frame:SetPoint("TOPLEFT", root, "TOPLEFT", 3, y)
                state.positionY = y
            end
            if state.width ~= width then
                frame:SetWidth(width)
                state.width = width
            end
            if state.height ~= height then
                frame:SetHeight(height)
                state.height = height
            end
        end

        local indicator = CreateFrame("Frame", nil, root)
        indicator:SetWidth(WIDTH)
        indicator:SetHeight(FOOTER_HEIGHT)
        indicator:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, 0)
        indicator:SetFrameLevel(root:GetFrameLevel() + 5)
        local indicatorText = Label(indicator, "Scroll down for latest messages")
        indicatorText:SetPoint("CENTER", indicator, "CENTER", 0, 0)
        indicatorText:SetTextColor(223 / 255, 186 / 255, 105 / 255)
        indicator:Hide()
        local indicatorShown = false
        local indicatorMessage = "Scroll down for latest messages"

        UpdateIndicator = function(atBottom)
            if not root:IsVisible() then return end
            if atBottom == nil and selected then atBottom = AtBottom(selected) end
            if selected and not atBottom and not focused then
                local message = selected.unread and "Unread messages" or "Scroll down for latest messages"
                if indicatorMessage ~= message then
                    indicatorText:SetText(message)
                    indicatorMessage = message
                end
                if not indicatorShown then
                    indicator:Show()
                    indicatorShown = true
                end
            elseif indicatorShown then
                indicator:Hide()
                indicatorShown = false
            end
        end
        local function Scroll(state, direction)
            if direction == 0 then return end
            local steps = IsShiftKeyDown() and 10 or 3
            for _ = 1, steps do
                if direction > 0 then
                    state.native:ScrollUp()
                else
                    state.native:ScrollDown()
                end
            end
            if state.native.AtBottom then
                state.scrolled = not AtBottom(state)
            else
                state.scrolled = direction > 0
            end
            if not state.scrolled then state.unread = false end
            Reveal(state)
            FadeSettings(state, true)
            UpdateIndicator()
        end
        local function NoticeMessage(state)
            local now = GetTime()
            state.lastActivity = now
            state.slideStart = not performanceMode and state == selected and root:IsVisible() and now or nil
            if state ~= selected or not AtBottom(state) then state.unread = true end
            if UpdateIndicator then UpdateIndicator() end
        end

        PositionInput = function()
            if not input then return end
            if not HasAnchor(input, "TOPLEFT", root, "BOTTOMLEFT", -1, -1) then
                input:ClearAllPoints()
                input:SetPoint("TOPLEFT", root, "BOTTOMLEFT", -1, -1)
            end
            if not T.NearlyEqual(input:GetWidth(), rootWidth) then input:SetWidth(rootWidth) end
            if not T.NearlyEqual(input:GetHeight(), 28) then input:SetHeight(28) end
            T.SetChatFont(input)
            T.SetChatShadow(input)
            if input:GetAlpha() ~= 1 then input:SetAlpha(1) end
            local inputName = input:GetName()
            local header = inputName and _G[inputName .. "Header"]
            if header then
                T.SetChatFont(header)
                if not HasAnchor(header, "LEFT", input, "LEFT", 8, 0) then
                    header:ClearAllPoints()
                    header:SetPoint("LEFT", input, "LEFT", 8, 0)
                end
            end
            local left = (header and header:GetStringWidth() or 0) + 12
            local currentLeft, right, top, bottom
            if input.GetTextInsets then
                currentLeft, right, top, bottom = input:GetTextInsets()
            end
            if
                not T.NearlyEqual(currentLeft, left)
                or not T.NearlyEqual(right, 8)
                or not T.NearlyEqual(top, 6)
                or not T.NearlyEqual(bottom, 6)
            then
                input:SetTextInsets(left, 8, 6, 6)
            end
        end

        root:EnableMouse(true)
        root:EnableMouseWheel(true)
        root:SetScript("OnMouseWheel", function()
            if selected then Scroll(selected, arg1 or 0) end
        end)

        local function AttachNative(index)
            local native = _G["ChatFrame" .. index]
            if not native or states[index] then return end
            local state = { native = native, index = index, unread = false }
            states[index] = state
            if not selected then selected = state end

            -- Keep actual native rendering, including direct client writes.
            -- Only approved message categories are formatted. Rendering still
            -- uses the actual native frame, with raw-text fallback on failure.
            native:SetParent(root)
            LockNativeMovement(native)
            PositionNative(state, GetTime(), true)
            FadeSettings(state, false)
            -- SetMaxLines clears the native ring; preserve existing history.
            if native.SetSpacing then native:SetSpacing(3) end
            if native.SetIndentedWordWrap then native:SetIndentedWordWrap(true) end
            if native.SetBackdrop then native:SetBackdrop(nil) end
            for _, region in ipairs({ native:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then HideControl(region) end
            end
            native:EnableMouse(state == selected)
            native:EnableMouseWheel(state == selected)
            native:SetScript("OnMouseWheel", function() Scroll(state, arg1 or 0) end)
            local setAlpha = native.SetAlpha
            native.SetAlpha = function(frame)
                if not root:IsVisible() then return end
                local alpha = state == selected and (state.visualAlpha or 1) or 0
                if frame:GetAlpha() ~= alpha then setAlpha(frame, alpha) end
            end
            native:SetAlpha(1)
            local addMessage = native.AddMessage
            local function RenderMessage(frame, displayed, r, g, b, id, addToStart)
                local result = addMessage(frame, displayed, r, g, b, id, addToStart)
                if type(displayed) == "string" then NoticeMessage(state) end
                return result
            end
            state.FlushLevel = function()
                local pending = state.pendingLevel
                if not pending then return end
                state.pendingLevel = nil
                return RenderMessage(
                    pending.frame,
                    pending.text,
                    pending.r,
                    pending.g,
                    pending.b,
                    pending.id,
                    pending.addToStart
                )
            end
            native.AddMessage = function(frame, text, r, g, b, id, addToStart)
                if chat.CaptureRaw then
                    chat.CaptureRaw(frame, text, state.eventContext, state.eventSpeaker, state.eventMessage)
                end
                local banners = DFRL.banners
                if banners and banners.RedirectChat then
                    local success, redirected = pcall(
                        banners.RedirectChat,
                        frame,
                        text,
                        state.eventContext,
                        state.eventSpeaker,
                        state.eventMessage
                    )
                    if success and redirected then
                        state.eventHadSuppression = true
                        return
                    end
                end
                local displayed, kind = text, nil
                if index ~= 2 and type(text) == "string" and chat.PrettifyMessage then
                    local success, formatted, messageKind =
                        pcall(chat.PrettifyMessage, text, state.eventContext, state.eventSpeaker, state.eventMessage)
                    if success and messageKind == "hide" then
                        state.eventHadSuppression = true
                        return
                    end
                    if success and type(formatted) == "string" then
                        displayed, kind = formatted, messageKind
                    end
                end
                if kind == "level" then
                    state.FlushLevel()
                    state.pendingLevel = {
                        frame = frame,
                        text = displayed,
                        r = r,
                        g = g,
                        b = b,
                        id = id,
                        addToStart = addToStart,
                        deadline = GetTime() + 0.25,
                    }
                    return
                end
                local pending = state.pendingLevel
                if
                    kind == "level_stats"
                    and pending
                    and GetTime() <= pending.deadline
                    and Flag(pending.addToStart) == Flag(addToStart)
                then
                    state.pendingLevel = nil
                    return RenderMessage(
                        pending.frame,
                        pending.text .. ": " .. displayed,
                        pending.r,
                        pending.g,
                        pending.b,
                        pending.id,
                        pending.addToStart
                    )
                end
                -- Preserve order and retain level announcements without gains.
                state.FlushLevel()
                return RenderMessage(frame, displayed, r, g, b, id, addToStart)
            end
            local oldEvent = native:GetScript("OnEvent")
            native:SetScript("OnEvent", function()
                local currentEvent = event
                local previousContext = state.eventContext
                local previousSpeaker, previousMessage = state.eventSpeaker, state.eventMessage
                local previousSuppression = state.eventHadSuppression
                state.eventContext = currentEvent
                state.eventSpeaker, state.eventMessage = arg2, arg1
                state.eventHadSuppression = false
                if oldEvent then oldEvent() end
                local suppressed = state.eventHadSuppression
                state.eventContext = previousContext
                state.eventSpeaker, state.eventMessage = previousSpeaker, previousMessage
                state.eventHadSuppression = previousSuppression
                if not suppressed and currentEvent and string.find(currentEvent, "^CHAT_MSG_") then
                    NoticeMessage(state)
                end
                if
                    currentEvent == "UPDATE_CHAT_WINDOWS"
                    or currentEvent == "PLAYER_ENTERING_WORLD"
                    or currentEvent == "CHANNEL_UI_UPDATE"
                then
                    if index == 1 then ConfigureRegularChat() end
                    state.fadeConfigured, state.held = nil, nil
                    FadeSettings(state, state == selected and not AtBottom(state))
                    ReadDimensions()
                    PositionNative(state, GetTime(), true)
                    PositionInput()
                    if RefreshFrames then RefreshFrames() end
                end
            end)

            -- Classic chat has eight separate resize buttons. Hiding only
            -- ResizeButton leaves those native hit areas active.
            for _, suffix in ipairs({
                "Tab",
                "ResizeButton",
                "ResizeTopLeft",
                "ResizeTopRight",
                "ResizeBottomLeft",
                "ResizeBottomRight",
                "ResizeTop",
                "ResizeBottom",
                "ResizeLeft",
                "ResizeRight",
                "UpButton",
                "DownButton",
                "BottomButton",
                "ButtonFrame",
            }) do
                HideControl(_G["ChatFrame" .. index .. suffix])
            end
            -- Preserve FrameXML's resize capability; /sdui owns the container
            -- dimensions and the native mouse resize controls stay hidden.
            if native.SetResizable then native:SetResizable(true) end
        end

        RefreshFrames = function()
            for i = 1, NUM_CHAT_WINDOWS or 7 do
                AttachNative(i)
            end
        end

        SelectChat = function(state)
            if not state then return end
            selected = state
            selected.unread = false
            _G.SELECTED_CHAT_FRAME = state.native
            if FCF_SelectDockFrame and Flag(state.native.isDocked) then
                FCF_SelectDockFrame(state.native)
            else
                _G.SELECTED_DOCK_FRAME = state.native
            end
            ReadDimensions()
            local now = GetTime()
            for _, other in pairs(states) do
                other.native:SetAlpha(other == selected and 1 or 0)
                other.native:EnableMouse(other == selected)
                other.native:EnableMouseWheel(other == selected)
                PositionNative(other, now, true)
            end
            state.native:Show()
            if FCF_StopAlertFlash then FCF_StopAlertFlash(state.native) end
            FadeSettings(state, not AtBottom(state))
            PositionInput()
            RefreshFrames()
            UpdateIndicator()
        end

        if input then
            input:SetParent(UIParent)
            input:SetFrameStrata("LOW")
            input:SetFrameLevel(root:GetFrameLevel() + 6)
            for _, region in ipairs({ input:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then HideControl(region) end
            end
            if input.SetBackdrop then input:SetBackdrop(nil) end
            local oldShow, oldHide = input:GetScript("OnShow"), input:GetScript("OnHide")
            input:SetScript("OnShow", function()
                if oldShow then oldShow() end
                focused = true
                PositionInput()
                UpdateIndicator()
            end)
            input:SetScript("OnHide", function()
                if oldHide then oldHide() end
                focused = false
                UpdateIndicator()
            end)
            local oldGained, oldLost = input:GetScript("OnEditFocusGained"), input:GetScript("OnEditFocusLost")
            input:SetScript("OnEditFocusGained", function()
                if oldGained then oldGained() end
                focused = true
                UpdateIndicator()
            end)
            input:SetScript("OnEditFocusLost", function()
                if oldLost then oldLost() end
                focused = false
                UpdateIndicator()
            end)
            if _G.ChatEdit_UpdateHeader then
                local oldHeader = _G.ChatEdit_UpdateHeader
                _G.ChatEdit_UpdateHeader = function(editBox)
                    oldHeader(editBox)
                    if editBox == input then PositionInput() end
                end
            end
        end

        ConfigureRegularChat()
        RefreshFrames()
        SelectChat(states[1])
        HideControl(ChatFrameMenuButton)
        local refresh = 0
        local function UpdateChat()
            if not root:IsVisible() then return end
            local now, elapsed = nil, arg1 or 0
            -- Only wheel navigation uncovers retained history. Hover and input
            -- focus never rearm lines or hold their fading.
            local atBottom = not selected or AtBottom(selected)
            local held = not atBottom
            for _, state in pairs(states) do
                if state.pendingLevel or state.revealStart or state.slideStart then now = now or GetTime() end
                if state.pendingLevel and now >= state.pendingLevel.deadline then
                    state.FlushLevel()
                    if state == selected then atBottom = nil end
                end
                if state.revealStart then
                    state.visualAlpha = Clamp((now - state.revealStart) / FADE, 0, 1)
                    if state.visualAlpha == 1 then state.revealStart = nil end
                end
                if state.slideStart then
                    -- Other native panes keep their messages and unread state,
                    -- but only the selected pane needs animated geometry.
                    if state == selected then PositionNative(state, now) end
                    if now - state.slideStart >= SLIDE then state.slideStart = nil end
                end
                FadeSettings(state, state == selected and held)
            end
            if selected then
                selected.native:SetAlpha(1)
                if not Flag(selected.native:IsShown()) then
                    selected.native:Show()
                    atBottom = nil
                end
                if atBottom == nil then atBottom = AtBottom(selected) end
                if atBottom then selected.unread = false end
            end
            UpdateIndicator(atBottom)
            refresh = refresh + elapsed
            if refresh >= 1 then
                refresh = 0
                now = now or GetTime()
                ReadDimensions()
                PositionInput()
                RefreshFrames()
                for _, state in pairs(states) do
                    PositionNative(state, now, true)
                end
            end
        end
        root:SetScript("OnUpdate", UpdateChat)
        DFRL.display.Listen(function()
            local enabled = DFRL.display.Get("performanceMode")
            if performanceMode == enabled then return end
            performanceMode = enabled
            for _, state in pairs(states) do
                state.slideStart, state.revealStart = nil, nil
                state.visualAlpha = 1
                if root:IsVisible() then
                    state.native:SetAlpha(1)
                    PositionNative(state, 0)
                    FadeSettings(state, state == selected and not AtBottom(state))
                end
            end
        end)
        HookScript(root, "OnHide", function()
            for _, state in pairs(states) do
                state.slideStart, state.revealStart = nil, nil
            end
        end)
        HookScript(root, "OnShow", function()
            ReadDimensions()
            for _, state in pairs(states) do
                state.visualAlpha = 1
                state.native:SetAlpha(1)
                PositionNative(state, GetTime(), true)
            end
            UpdateIndicator()
        end)
        DFRL.layout.Register("chat", root, nil, {
            region = moveRegion,
            resize = "dimensions",
            edgeHandles = true,
            minWidth = 240,
            minHeight = 120,
            maxWidth = 2400,
            maxHeight = 1600,
            onResize = function(frame)
                rootWidth, rootHeight = frame:GetWidth(), frame:GetHeight()
                if not T.NearlyEqual(indicator:GetWidth(), rootWidth) then indicator:SetWidth(rootWidth) end
                local now = GetTime()
                for _, state in pairs(states) do
                    PositionNative(state, now)
                end
                PositionInput()
            end,
            -- The layout-edit overlay must preserve wheel navigation. Movement
            -- itself never rearms retained messages or changes their fading.
            onMouseWheel = function(direction)
                if selected then Scroll(selected, direction or 0) end
            end,
        })
    end

    Initialize()
    if not initialized then
        local waiting = CreateFrame("Frame")
        waiting:RegisterEvent("PLAYER_LOGIN")
        waiting:RegisterEvent("PLAYER_ENTERING_WORLD")
        waiting:SetScript("OnEvent", function()
            Initialize()
            if initialized then waiting:UnregisterAllEvents() end
        end)
    end
end)
