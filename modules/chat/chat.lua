-- CleanerChat visual presentation; incoming message text is never rewritten.
-- Source credits are retained in third_party/CleanerChat-NOTICE.txt.
DFRL:NewMod("Chat", 1, function()
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local chat = DFRL.CleanerChat
    local initialized = false
    local Initialize

    Initialize = function()
        if initialized or not ChatFrame1 then return end
        initialized = true

        local WIDTH, HEIGHT, DOCK_HEIGHT = 520, 340, 20
        local HOLD, FADE, SLIDE = 14, 0.6, 0.35
        local tex = DFRL:GetInfoOrCons("tex") .. "chat\\"
        local states, selected = {}, nil
        local input = _G.ChatFrameEditBox or _G.ChatFrame1EditBox or ChatFrame1.editBox
        local RefreshTabs, SelectTab, PositionInput, UpdateIndicator
        local hovered, focused = false, false
        local dockUntil, dockAlpha = GetTime() + 10, 1

        local root = CreateFrame("Frame", "SurvivorsDragonUiChat", UIParent)
        root:SetWidth(WIDTH)
        root:SetHeight(HEIGHT)
        root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 230)
        root:SetFrameStrata("LOW")
        root:SetAlpha(1)
        root:Show()
        chat.frame = root
        local dock = CreateFrame("Frame", nil, root)
        dock:SetWidth(WIDTH)
        dock:SetHeight(DOCK_HEIGHT)
        dock:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)

        local function Flag(value) return value == true or value == 1 end
        local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end
        local function Contains(list, value)
            if type(list) ~= "table" then return false end
            for _, entry in pairs(list) do if entry == value then return true end end
            return false
        end
        local function Label(parent, text, size)
            local label = parent:CreateFontString(nil, "OVERLAY")
            label:SetFont("DEFAULT", size or 12, "OUTLINE")
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            label:SetText(text or "")
            return label
        end
        local function Background(parent)
            local texture = parent:CreateTexture(nil, "BACKGROUND")
            texture:SetTexture(17 / 255, 17 / 255, 17 / 255, 0.05)
            texture:SetAllPoints(parent)
            return texture
        end
        local function HideControl(control)
            if not control then return end
            control:Hide()
            control.Show = control.Hide
        end
        local function Over(frame)
            if not frame or not frame:IsVisible() then return false end
            local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
            if not left or not right or not top or not bottom then return false end
            local x, y = GetCursorPosition()
            local scale = frame:GetEffectiveScale()
            x, y = x / scale, y / scale
            return x >= left and x <= right and y >= bottom and y <= top
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
                local channels = {GetChannelList()}
                for i = 2, table.getn(channels), 2 do
                    local name = channels[i]
                    if name and not Contains(ChatFrame1.channelList, name) then ChatFrame_AddChannel(ChatFrame1, name) end
                end
            end
        end
        local function AtBottom(state)
            if state.native.AtBottom then return Flag(state.native:AtBottom()) end
            return not state.scrolled
        end
        local function FadeSettings(state, held)
            local frame = state.native
            if not state.fadeConfigured then
                if frame.SetTimeVisible then frame:SetTimeVisible(HOLD) end
                if frame.SetFadeDuration then frame:SetFadeDuration(FADE) end
                state.fadeConfigured = true
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
            dockUntil = now + 10
            if state then
                local lastVisible = math.max(state.lastActivity or 0, state.lastReveal or 0)
                if now - lastVisible >= HOLD + FADE then
                    state.revealStart, state.visualAlpha = now, 0
                end
                state.lastReveal = now
                Rearm(state)
            end
        end
        local function PositionNative(state, now)
            local frame = state.native
            local progress = state.slideStart and Clamp((now - state.slideStart) / SLIDE, 0, 1) or 1
            local shift = -12 * (1 - progress) * (1 - progress) * (1 - progress)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", root, "TOPLEFT", 3, -DOCK_HEIGHT - 5 + shift)
            frame:SetWidth(WIDTH - 6)
            frame:SetHeight(HEIGHT - DOCK_HEIGHT - 5)
            local font, size, flags
            if frame.GetFont then font, size, flags = frame:GetFont() end
            if font ~= "DEFAULT" or size ~= 12 or flags ~= "OUTLINE" then
                frame:SetFont("DEFAULT", 12, "OUTLINE")
            end
            if frame.SetShadowColor then frame:SetShadowColor(0, 0, 0, 1) end
            if frame.SetShadowOffset then frame:SetShadowOffset(1, -1) end
            if frame.SetJustifyH then frame:SetJustifyH("LEFT") end
        end

        local indicator = CreateFrame("Button", nil, root)
        indicator:SetWidth(WIDTH)
        indicator:SetHeight(32)
        indicator:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, 0)
        indicator:SetFrameLevel(root:GetFrameLevel() + 5)
        local mask = indicator:CreateTexture(nil, "BACKGROUND")
        mask:SetTexture(tex .. "cleaner_overlayMask.tga")
        mask:SetVertexColor(17 / 255, 17 / 255, 17 / 255, 0.6)
        mask:SetAllPoints(indicator)
        local indicatorText = Label(indicator, "Bring me to the present")
        indicatorText:SetPoint("CENTER", indicator, "CENTER", -10, 0)
        indicatorText:SetTextColor(223 / 255, 186 / 255, 105 / 255)
        local icon = indicator:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(tex .. "cleaner_snapToBottomIcon.tga")
        icon:SetWidth(16)
        icon:SetHeight(16)
        icon:SetPoint("LEFT", indicatorText, "RIGHT", 6, 0)
        indicator:Hide()

        UpdateIndicator = function()
            if selected and not AtBottom(selected) and not focused then
                indicatorText:SetText(selected.unread and "Unread messages" or "Bring me to the present")
                indicator:Show()
            else
                indicator:Hide()
            end
        end
        local function SnapToBottom()
            if not selected then return end
            if selected.native.ScrollToBottom then selected.native:ScrollToBottom() end
            selected.scrolled, selected.unread = false, false
            Reveal(selected)
            UpdateIndicator()
        end
        indicator:SetScript("OnClick", SnapToBottom)

        local function Scroll(state, direction)
            local steps = IsShiftKeyDown() and 10 or 3
            for i = 1, steps do
                if direction > 0 then state.native:ScrollUp() else state.native:ScrollDown() end
            end
            if state.native.AtBottom then state.scrolled = not AtBottom(state)
            else state.scrolled = direction > 0 end
            if not state.scrolled then state.unread = false end
            Reveal(state)
            FadeSettings(state, true)
            UpdateIndicator()
        end
        local function NoticeMessage(state)
            state.slideStart = GetTime()
            state.lastActivity = state.slideStart
            dockUntil = state.slideStart + 10
            if state ~= selected or not AtBottom(state) then state.unread = true end
            if UpdateIndicator then UpdateIndicator() end
        end

        PositionInput = function()
            if not input then return end
            input:ClearAllPoints()
            input:SetPoint("TOPLEFT", root, "BOTTOMLEFT", -1, -1)
            input:SetWidth(WIDTH)
            input:SetHeight(28)
            input:SetFont("DEFAULT", 12, "OUTLINE")
            if input.SetShadowColor then input:SetShadowColor(0, 0, 0, 1) end
            if input.SetShadowOffset then input:SetShadowOffset(1, -1) end
            input:SetAlpha(1)
            local header = input:GetName() and _G[input:GetName() .. "Header"]
            if header then
                header:SetFont("DEFAULT", 12, "OUTLINE")
                header:ClearAllPoints()
                header:SetPoint("LEFT", input, "LEFT", 8, 0)
            end
            input:SetTextInsets((header and header:GetStringWidth() or 0) + 12, 8, 6, 6)
        end

        local function AttachNative(index)
            local native = _G["ChatFrame" .. index]
            if not native or states[index] then return end
            local state = {native = native, messages = {}, index = index, unread = false}
            states[index] = state
            if not selected then selected = state end

            -- Keep actual native rendering, including direct client writes.
            -- The Lua hook never filters or substitutes text and renders first.
            native:SetParent(root)
            PositionNative(state, GetTime())
            FadeSettings(state, false)
            -- SetMaxLines clears the native ring; preserve existing history.
            if native.SetSpacing then native:SetSpacing(3) end
            if native.SetIndentedWordWrap then native:SetIndentedWordWrap(true) end
            if native.SetBackdrop then native:SetBackdrop(nil) end
            for _, region in ipairs({native:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then HideControl(region) end
            end
            state.background = Background(native)
            native:EnableMouse(state == selected)
            native:EnableMouseWheel(state == selected)
            native:SetScript("OnMouseWheel", function() Scroll(state, arg1 or 0) end)
            local setAlpha = native.SetAlpha
            native.SetAlpha = function(frame)
                setAlpha(frame, state == selected and (state.visualAlpha or 1) or 0)
            end
            native:SetAlpha(1)
            local addMessage = native.AddMessage
            native.AddMessage = function(frame, text, r, g, b, id, addToStart)
                local result = addMessage(frame, text, r, g, b, id, addToStart)
                if type(text) == "string" then
                    table.insert(state.messages, text)
                    if table.getn(state.messages) > 512 then table.remove(state.messages, 1) end
                    NoticeMessage(state)
                end
                return result
            end
            local oldEvent = native:GetScript("OnEvent")
            native:SetScript("OnEvent", function()
                local currentEvent = event
                if oldEvent then oldEvent() end
                if currentEvent and string.find(currentEvent, "^CHAT_MSG_") then NoticeMessage(state) end
                if currentEvent == "UPDATE_CHAT_WINDOWS" or currentEvent == "PLAYER_ENTERING_WORLD"
                    or currentEvent == "CHANNEL_UI_UPDATE" then
                    if index == 1 then ConfigureRegularChat() end
                    state.fadeConfigured, state.held = nil, nil
                    FadeSettings(state, state == selected and (hovered or focused or not AtBottom(state)))
                    PositionNative(state, GetTime())
                    PositionInput()
                    if RefreshTabs then RefreshTabs() end
                end
            end)

            for _, suffix in ipairs({"Tab", "ResizeButton", "UpButton", "DownButton", "BottomButton", "ButtonFrame"}) do
                HideControl(_G["ChatFrame" .. index .. suffix])
            end
            if native.SetMovable then native:SetMovable(false) end
            if native.SetResizable then native:SetResizable(false) end
            local tab = CreateFrame("Button", nil, dock)
            tab:SetHeight(DOCK_HEIGHT)
            tab.text = Label(tab, "", 12)
            tab.text:SetAllPoints(tab)
            tab.text:SetJustifyH("LEFT")
            tab:SetScript("OnClick", function() SelectTab(state) end)
            state.tab = tab
        end

        RefreshTabs = function()
            local active = {}
            for i = 1, NUM_CHAT_WINDOWS or 7 do
                AttachNative(i)
                local state = states[i]
                if state then
                    local name, size, r, g, b, alpha, shown
                    if GetChatWindowInfo then name, size, r, g, b, alpha, shown = GetChatWindowInfo(i) end
                    state.active = i <= 2 or Flag(state.native.isDocked) or Flag(shown)
                    state.name = name and name ~= "" and name or (i == 2 and "Combat Log" or "Chat")
                    if state.active then table.insert(active, state) else state.tab:Hide() end
                end
            end
            local count = table.getn(active)
            local maxWidth = count > 0 and (WIDTH - 52) / count or 100
            local x = 5
            for _, state in ipairs(active) do
                state.tab.text:SetText(state.name)
                state.tab:SetWidth(math.min(maxWidth - 5, math.max(48, state.tab.text:GetStringWidth() + 10)))
                state.tab:ClearAllPoints()
                state.tab:SetPoint("TOPLEFT", dock, "TOPLEFT", x, 0)
                state.tab:Show()
                x = x + state.tab:GetWidth() + 5
            end
        end

        SelectTab = function(state)
            if not state then return end
            selected = state
            selected.unread = false
            _G.SELECTED_CHAT_FRAME = state.native
            if FCF_SelectDockFrame and Flag(state.native.isDocked) then FCF_SelectDockFrame(state.native)
            else _G.SELECTED_DOCK_FRAME = state.native end
            for _, other in pairs(states) do
                other.native:SetAlpha(other == selected and 1 or 0)
                other.native:EnableMouse(other == selected)
                other.native:EnableMouseWheel(other == selected)
                PositionNative(other, GetTime())
            end
            state.native:Show()
            if FCF_StopAlertFlash then FCF_StopAlertFlash(state.native) end
            Reveal(state)
            FadeSettings(state, hovered or focused or not AtBottom(state))
            PositionInput()
            RefreshTabs()
            UpdateIndicator()
        end

        local copy = CreateFrame("Button", nil, dock)
        copy:SetWidth(42)
        copy:SetHeight(DOCK_HEIGHT)
        copy:SetPoint("TOPRIGHT", dock, "TOPRIGHT", -2, 0)
        copy.text = Label(copy, "Copy", 11)
        copy.text:SetAllPoints(copy)
        copy.text:SetTextColor(223 / 255, 186 / 255, 105 / 255)
        copy:SetScript("OnClick", function()
            if not selected or not chat.ShowCopy then return end
            local frame, lines = selected.native, {}
            if frame.GetNumMessages and frame.GetMessageInfo then
                local count = frame:GetNumMessages() or 0
                for i = 1, count do
                    local text = frame:GetMessageInfo(i)
                    if type(text) == "string" then table.insert(lines, text) end
                end
            end
            if table.getn(lines) == 0 then
                for _, text in ipairs(selected.messages) do table.insert(lines, text) end
            end
            chat.ShowCopy(table.concat(lines, "\n"), "Copy chat - press Ctrl+C")
        end)

        if input then
            input:SetParent(UIParent)
            input:SetFrameStrata("LOW")
            input:SetFrameLevel(root:GetFrameLevel() + 6)
            for _, region in ipairs({input:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then HideControl(region) end
            end
            if input.SetBackdrop then input:SetBackdrop(nil) end
            input.cleanerBackground = Background(input)
            local oldShow, oldHide = input:GetScript("OnShow"), input:GetScript("OnHide")
            input:SetScript("OnShow", function()
                if oldShow then oldShow() end
                focused = true
                PositionInput()
                SnapToBottom()
            end)
            input:SetScript("OnHide", function()
                if oldHide then oldHide() end
                focused = false
                Reveal(selected)
                UpdateIndicator()
            end)
            local oldGained, oldLost = input:GetScript("OnEditFocusGained"), input:GetScript("OnEditFocusLost")
            input:SetScript("OnEditFocusGained", function()
                if oldGained then oldGained() end
                focused = true
                SnapToBottom()
            end)
            input:SetScript("OnEditFocusLost", function()
                if oldLost then oldLost() end
                focused = false
                Reveal(selected)
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
        RefreshTabs()
        SelectTab(states[1])
        HideControl(ChatFrameMenuButton)
        local refresh = 0
        root:SetScript("OnUpdate", function()
            local now, elapsed = GetTime(), arg1 or 0
            local over = Over(root) or Over(input) or Over(indicator)
            if over ~= hovered then
                hovered = over
                Reveal(selected)
            end
            local held = hovered or focused or (selected and not AtBottom(selected))
            if held then dockUntil = now + 10 end
            local target = held or now < dockUntil
            local duration = target and 0.3 or 0.6
            dockAlpha = Clamp(dockAlpha + (target and 1 or -1) * elapsed / duration, 0, 1)
            dock:SetAlpha(dockAlpha)
            copy:EnableMouse(dockAlpha > 0.05)
            for _, state in pairs(states) do
                state.tab:EnableMouse(dockAlpha > 0.05)
                local pulse = state.unread and (0.5 + 0.5 * math.sin(now * 6)) or 1
                state.tab.text:SetTextColor(1, 191 / 255, 0, (state == selected and 1 or 0.7) * pulse)
                if state.revealStart then
                    state.visualAlpha = Clamp((now - state.revealStart) / FADE, 0, 1)
                    if state.visualAlpha == 1 then state.revealStart = nil end
                end
                if state.slideStart then
                    PositionNative(state, now)
                    if now - state.slideStart >= SLIDE then state.slideStart = nil end
                end
                FadeSettings(state, state == selected and held)
            end
            if selected then
                selected.native:SetAlpha(1)
                selected.native:Show()
                if AtBottom(selected) then selected.unread = false end
            end
            UpdateIndicator()
            refresh = refresh + elapsed
            if refresh >= 1 then
                refresh = 0
                PositionInput()
                RefreshTabs()
                for _, state in pairs(states) do PositionNative(state, now) end
            end
        end)
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
