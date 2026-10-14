-- Visible, unfiltered 1.12.1 chat baseline. Presentation can be added gradually.
-- CleanerChat attribution is retained in third_party/CleanerChat-NOTICE.txt.
DFRL:NewMod("Chat", 1, function()
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local chat = DFRL.CleanerChat
    local initialized = false
    local Initialize

    Initialize = function()
        if initialized or not ChatFrame1 then return end
        initialized = true

        local WIDTH, HEIGHT, DOCK_HEIGHT = 520, 340, 24
        local states, selected = {}, nil
        local input = _G.ChatFrameEditBox or _G.ChatFrame1EditBox or ChatFrame1.editBox
        local RefreshTabs, SelectTab
        local root = CreateFrame("Frame", "SurvivorsDragonUiChat", UIParent)
        root:SetWidth(WIDTH)
        root:SetHeight(HEIGHT)
        root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 230)
        root:SetFrameStrata("LOW")
        root:SetAlpha(1)
        root:Show()
        chat.frame = root
        local background = root:CreateTexture(nil, "BACKGROUND")
        background:SetTexture(0.067, 0.067, 0.067, 0.15)
        background:SetAllPoints(root)

        local function Flag(value)
            return value == true or value == 1
        end

        local function Contains(list, value)
            if type(list) ~= "table" then return false end
            for _, entry in pairs(list) do if entry == value then return true end end
            return false
        end

        local function EnableAllMessages()
            -- Use native subscriptions, not a second raw CHAT_MSG dispatcher.
            if ChatFrame_AddMessageGroup and type(ChatTypeGroup) == "table" then
                for group in pairs(ChatTypeGroup) do
                    if type(group) == "string" and not Contains(ChatFrame1.messageTypeList, group) then
                        ChatFrame_AddMessageGroup(ChatFrame1, group)
                    end
                end
            end
            -- Include already-joined channels without joining additional ones.
            if GetChannelList and ChatFrame_AddChannel then
                local channels = {GetChannelList()}
                for i = 2, table.getn(channels), 2 do
                    local name = channels[i]
                    if name and not Contains(ChatFrame1.channelList, name) then
                        ChatFrame_AddChannel(ChatFrame1, name)
                    end
                end
            end
        end

        local function HideControl(control)
            if not control then return end
            control:Hide()
            control.Show = control.Hide
        end

        local function PositionNative(frame)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", root, "TOPLEFT", 6, -DOCK_HEIGHT - 4)
            frame:SetWidth(WIDTH - 24)
            frame:SetHeight(HEIGHT - DOCK_HEIGHT - 10)
            frame:SetFont("DEFAULT", 12, "")
            if frame.SetJustifyH then frame:SetJustifyH("LEFT") end
            if frame.SetFading then frame:SetFading(false) end
            if frame.SetTimeVisible then frame:SetTimeVisible(31536000) end
            if frame.SetFadeDuration then frame:SetFadeDuration(0) end
        end

        local function PositionInput()
            if not input then return end
            input:ClearAllPoints()
            input:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, -2)
            input:SetWidth(WIDTH)
            input:SetHeight(28)
            input:SetFont("DEFAULT", 12, "")
            input:SetAlpha(1)
            local header = input:GetName() and _G[input:GetName() .. "Header"]
            if header then header:SetFont("DEFAULT", 12, "") end
        end

        local function Scroll(frame, direction)
            local steps = IsShiftKeyDown() and 10 or 3
            for i = 1, steps do
                if direction > 0 then frame:ScrollUp() else frame:ScrollDown() end
            end
        end

        local function AttachNative(index)
            local native = _G["ChatFrame" .. index]
            if not native or states[index] then return end
            local state = {native = native, messages = {}, index = index}
            states[index] = state
            if not selected then selected = state end

            -- Render the actual game chat frame. Client-side writes can bypass a
            -- Lua AddMessage hook, so they must not depend on a replacement row.
            native:SetParent(root)
            PositionNative(native)
            native:EnableMouse(state == selected)
            native:EnableMouseWheel(state == selected)
            native:SetScript("OnMouseWheel", function() Scroll(native, arg1 or 0) end)
            local setAlpha = native.SetAlpha
            native.SetAlpha = function(frame)
                setAlpha(frame, state == selected and 1 or 0)
            end
            native:SetAlpha(1)

            -- Copy capture is secondary: the original renderer runs first,
            -- unchanged, and never depends on this session-history bookkeeping.
            local addMessage = native.AddMessage
            native.AddMessage = function(frame, text, r, g, b, id, addToStart)
                local result = addMessage(frame, text, r, g, b, id, addToStart)
                if type(text) == "string" then
                    table.insert(state.messages, text)
                    if table.getn(state.messages) > 512 then table.remove(state.messages, 1) end
                end
                return result
            end
            local oldEvent = native:GetScript("OnEvent")
            native:SetScript("OnEvent", function()
                local currentEvent = event
                if oldEvent then oldEvent() end
                if currentEvent == "UPDATE_CHAT_WINDOWS" or currentEvent == "PLAYER_ENTERING_WORLD"
                    or currentEvent == "CHANNEL_UI_UPDATE" then
                    if index == 1 then EnableAllMessages() end
                    PositionNative(native)
                    PositionInput()
                    if RefreshTabs then RefreshTabs() end
                end
            end)

            HideControl(_G["ChatFrame" .. index .. "Tab"])
            HideControl(_G["ChatFrame" .. index .. "ResizeButton"])
            if native.SetMovable then native:SetMovable(false) end
            if native.SetResizable then native:SetResizable(false) end
            local tab = CreateFrame("Button", nil, root)
            tab:SetHeight(DOCK_HEIGHT)
            local text = tab:CreateFontString(nil, "OVERLAY")
            text:SetFont("DEFAULT", 12, "")
            text:SetAllPoints(tab)
            text:SetJustifyH("LEFT")
            tab.text = text
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
            local x = 6
            for _, state in ipairs(active) do
                state.tab.text:SetText(state.name)
                state.tab:SetWidth(math.min(maxWidth, math.max(48, state.tab.text:GetStringWidth() + 16)))
                state.tab:ClearAllPoints()
                state.tab:SetPoint("TOPLEFT", root, "TOPLEFT", x, 0)
                state.tab.text:SetTextColor(1, state == selected and 0.8 or 1, state == selected and 0.35 or 1)
                state.tab:Show()
                x = x + state.tab:GetWidth()
            end
        end

        SelectTab = function(state)
            if not state then return end
            selected = state
            _G.SELECTED_CHAT_FRAME = state.native
            if FCF_SelectDockFrame and Flag(state.native.isDocked) then
                FCF_SelectDockFrame(state.native)
            else
                _G.SELECTED_DOCK_FRAME = state.native
            end
            for _, other in pairs(states) do
                other.native:SetAlpha(other == selected and 1 or 0)
                other.native:EnableMouse(other == selected)
                other.native:EnableMouseWheel(other == selected)
                PositionNative(other.native)
            end
            -- Native OnShow is preserved; no forced Hide changes window prefs.
            state.native:Show()
            if FCF_StopAlertFlash then FCF_StopAlertFlash(state.native) end
            PositionInput()
            RefreshTabs()
        end

        local copy = CreateFrame("Button", nil, root)
        copy:SetWidth(42)
        copy:SetHeight(DOCK_HEIGHT)
        copy:SetPoint("TOPRIGHT", root, "TOPRIGHT", -2, 0)
        local copyText = copy:CreateFontString(nil, "OVERLAY")
        copyText:SetFont("DEFAULT", 11, "")
        copyText:SetAllPoints(copy)
        copyText:SetText("Copy")
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

        EnableAllMessages()
        PositionInput()
        RefreshTabs()
        SelectTab(states[1])
        HideControl(ChatFrameMenuButton)
        local elapsed = 0
        root:SetScript("OnUpdate", function()
            elapsed = elapsed + (arg1 or 0)
            if elapsed < 1 then return end
            elapsed = 0
            root:SetAlpha(1)
            if selected then
                selected.native:SetAlpha(1)
                selected.native:Show()
                PositionNative(selected.native)
            end
            PositionInput()
            RefreshTabs()
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
