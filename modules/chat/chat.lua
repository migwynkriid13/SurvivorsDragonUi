-- Fixed 1.12.1 adaptation of CleanerChat's Glass presentation.
-- Source credits are retained in third_party/CleanerChat-NOTICE.txt.
DFRL:NewMod("Chat", 1, function()
    local chat = DFRL.CleanerChat
    if not chat or not ChatFrame1 then return end

    local WIDTH, HEIGHT = 520, 340
    local DOCK_HEIGHT, INPUT_HEIGHT = 24, 28
    local BODY_HEIGHT = HEIGHT - DOCK_HEIGHT - 4
    local TEXT_WIDTH = WIDTH - 12
    local HOLD, FADE, SLIDE, HISTORY = 14, 0.6, 0.35, 128
    local tex = DFRL:GetInfoOrCons("tex") .. "chat\\"
    local states, rows = {}, {}
    local selected, input, inputHeader
    local hovered, focused = false, false
    local revealUntil, dockUntil = 0, GetTime() + 10
    local tabRefresh = 0
    local Layout, SelectTab, RefreshTabs

    local root = CreateFrame("Frame", "SurvivorsDragonUiChat", UIParent)
    root:SetWidth(WIDTH)
    root:SetHeight(HEIGHT)
    root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 230)
    root:SetFrameStrata("LOW")
    root:SetClampedToScreen(true)
    chat.frame = root

    local dock = CreateFrame("Frame", nil, root)
    dock:SetWidth(WIDTH)
    dock:SetHeight(DOCK_HEIGHT)
    dock:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)

    -- Native message rows retain wrapping and clickable links. The ScrollFrame
    -- clips rows at the fixed boundary, including during slide animations.
    local viewport = CreateFrame("ScrollFrame", nil, root)
    viewport:SetWidth(WIDTH)
    viewport:SetHeight(BODY_HEIGHT)
    viewport:SetPoint("TOPLEFT", dock, "BOTTOMLEFT", 0, -4)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, viewport)
    content:SetWidth(WIDTH)
    content:SetHeight(BODY_HEIGHT)
    viewport:SetScrollChild(content)
    viewport:SetVerticalScroll(0)

    local measure = root:CreateFontString(nil, "ARTWORK")
    measure:SetFont("DEFAULT", 12, "OUTLINE")
    measure:SetWidth(TEXT_WIDTH)
    measure:SetJustifyH("LEFT")
    measure:Hide()

    local function Clamp(value, low, high)
        return math.max(low, math.min(high, value))
    end

    local function Flag(value)
        return value == true or value == 1
    end

    local function Label(parent, text, size)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetFont("DEFAULT", size or 12, "OUTLINE")
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        label:SetText(text or "")
        return label
    end

    local function Solid(parent, layer, r, g, b, a)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetTexture(r, g, b, a)
        texture:SetAllPoints(parent)
        return texture
    end

    local function SuppressControl(frame)
        if not frame then return end
        frame:Hide()
        frame.Show = frame.Hide
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

    local function Reveal()
        local now = GetTime()
        revealUntil, dockUntil = now + HOLD, now + 10
    end

    local indicator = CreateFrame("Button", nil, root)
    indicator:SetWidth(WIDTH)
    indicator:SetHeight(24)
    indicator:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)
    indicator:SetFrameLevel(viewport:GetFrameLevel() + 4)
    local mask = indicator:CreateTexture(nil, "BACKGROUND")
    mask:SetTexture(tex .. "cleaner_overlayMask.tga")
    mask:SetVertexColor(0.067, 0.067, 0.067, 0.6)
    mask:SetAllPoints(indicator)
    local indicatorText = Label(indicator, "Bring me to the present")
    indicatorText:SetPoint("CENTER", indicator, "CENTER", -10, 0)
    indicatorText:SetTextColor(223 / 255, 186 / 255, 105 / 255)
    local snapIcon = indicator:CreateTexture(nil, "ARTWORK")
    snapIcon:SetTexture(tex .. "cleaner_snapToBottomIcon.tga")
    snapIcon:SetWidth(16)
    snapIcon:SetHeight(16)
    snapIcon:SetPoint("LEFT", indicatorText, "RIGHT", 6, 0)
    indicator:Hide()

    local function UpdateIndicator()
        if selected and selected.offset > 0 and not focused then
            indicatorText:SetText(selected.unread and "Unread messages" or "Bring me to the present")
            indicator:Show()
        else
            indicator:Hide()
        end
    end

    local function SnapToBottom()
        if not selected then return end
        selected.offset, selected.unread = 0, false
        Reveal()
        Layout(true)
        UpdateIndicator()
    end
    indicator:SetScript("OnClick", SnapToBottom)

    local function Scroll(delta)
        if not selected then return end
        local step = IsShiftKeyDown() and 10 or 3
        selected.offset = Clamp(selected.offset + (delta > 0 and step or -step),
            0, math.max(0, table.getn(selected.messages) - 1))
        if selected.offset == 0 then selected.unread = false end
        Reveal()
        Layout(true)
        UpdateIndicator()
    end
    viewport:SetScript("OnMouseWheel", function() Scroll(arg1 or 0) end)

    local function HyperlinkClick()
        local link = arg1
        if link and string.sub(link, 1, 4) == "url:" then
            chat.ShowCopy(string.sub(link, 5), "Copy URL - press Ctrl+C")
        elseif _G.ChatFrame_OnHyperlinkShow then
            _G.ChatFrame_OnHyperlinkShow(arg1, arg2, arg3)
        elseif _G.SetItemRef then
            _G.SetItemRef(arg1, arg2, arg3)
        end
    end

    local function HyperlinkEnter()
        if not GameTooltip or not arg1 then return end
        local link = arg1
        if string.sub(link, 1, 4) == "url:" then
            GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
            GameTooltip:SetText("Click to copy URL")
            GameTooltip:Show()
        elseif string.sub(link, 1, 5) == "item:" then
            GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
            local success = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
            if success then GameTooltip:Show() else GameTooltip:Hide() end
        end
    end

    local function NewRow()
        local row = CreateFrame("ScrollingMessageFrame", nil, content)
        row:SetWidth(TEXT_WIDTH)
        if row.SetFontObject and ChatFontNormal then row:SetFontObject(ChatFontNormal) end
        row:SetFont("DEFAULT", 12, "OUTLINE")
        if row.SetShadowColor then row:SetShadowColor(0, 0, 0, 1) end
        if row.SetShadowOffset then row:SetShadowOffset(1, -1) end
        row:SetJustifyH("LEFT")
        if row.SetJustifyV then row:SetJustifyV("BOTTOM") end
        if row.SetFading then row:SetFading(false)
        else
            row:SetTimeVisible(86400)
            row:SetFadeDuration(0)
        end
        if row.SetMaxLines then row:SetMaxLines(128) end
        row:EnableMouse(true)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function() Scroll(arg1 or 0) end)
        row:SetScript("OnHyperlinkClick", HyperlinkClick)
        if not row.HasScript or row:HasScript("OnHyperlinkEnter") then
            row:SetScript("OnHyperlinkEnter", HyperlinkEnter)
        end
        if not row.HasScript or row:HasScript("OnHyperlinkLeave") then
            row:SetScript("OnHyperlinkLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
        row.background = Solid(row, "BACKGROUND", 17 / 255, 17 / 255, 17 / 255, 0.05)
        table.insert(rows, row)
        return row
    end

    Layout = function(snap)
        if not selected then return end
        local messages = selected.messages
        local last = table.getn(messages) - selected.offset
        local y, used = 2, 0
        local index = last
        while index > 0 and y < BODY_HEIGHT + 32 do
            local message = messages[index]
            used = used + 1
            local row = rows[used] or NewRow()
            if not message.height then
                measure:SetText(message.text)
                message.height = math.max(14, measure:GetStringHeight() or 14) + 3
            end
            if snap or not message.y then message.y = y end
            message.targetY = y
            row.message = message
            row:SetHeight(message.height)
            row:ClearAllPoints()
            row:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 6, message.y)
            row:Clear()
            row:AddMessage(message.text, message.r, message.g, message.b)
            row:SetAlpha(message.alpha or 0)
            row:Show()
            y = y + message.height
            index = index - 1
        end
        for i = used + 1, table.getn(rows) do
            rows[i].message = nil
            rows[i]:Clear()
            rows[i]:Hide()
        end
    end

    local copy = CreateFrame("Button", nil, dock)
    copy:SetWidth(42)
    copy:SetHeight(DOCK_HEIGHT)
    copy:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0)
    copy.text = Label(copy, "Copy", 11)
    copy.text:SetAllPoints(copy)
    copy.text:SetTextColor(223 / 255, 186 / 255, 105 / 255)
    copy:SetScript("OnClick", function()
        if not selected then return end
        local lines = {}
        for _, message in ipairs(selected.messages) do table.insert(lines, message.text) end
        chat.ShowCopy(table.concat(lines, "\n"), "Copy chat - press Ctrl+C")
    end)

    local function InputLayout()
        if not input then return end
        input:ClearAllPoints()
        input:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, -1)
        input:SetWidth(WIDTH)
        input:SetHeight(INPUT_HEIGHT)
        input:SetFont("DEFAULT", 12, "OUTLINE")
        if inputHeader then
            inputHeader:SetFont("DEFAULT", 12, "OUTLINE")
            inputHeader:ClearAllPoints()
            inputHeader:SetPoint("LEFT", input, "LEFT", 8, 0)
        end
        local inset = inputHeader and inputHeader:GetStringWidth() or 0
        input:SetTextInsets(inset + 12, 8, 6, 6)
    end

    local function SetupInput()
        input = _G.ChatFrameEditBox or _G.ChatFrame1EditBox or ChatFrame1.editBox
        if not input then return end
        inputHeader = _G[input:GetName() .. "Header"]
        -- Retain native Enter/Escape/slash/history scripts and keep the shared
        -- input independent of the invisible native chat frames.
        input:SetParent(UIParent)
        input:SetFrameStrata("LOW")
        input:SetFrameLevel(root:GetFrameLevel() + 5)
        for _, region in ipairs({input:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then
                SuppressControl(region)
            end
        end
        input:SetBackdrop(nil)
        input.cleanerBackground = Solid(input, "BACKGROUND", 17 / 255, 17 / 255, 17 / 255, 0.05)
        InputLayout()
        local oldShow = input:GetScript("OnShow")
        input:SetScript("OnShow", function()
            if oldShow then oldShow() end
            InputLayout()
            input:SetAlpha(1)
            focused = true
            SnapToBottom()
        end)
        local oldHide = input:GetScript("OnHide")
        input:SetScript("OnHide", function()
            if oldHide then oldHide() end
            focused = false
            Reveal()
            UpdateIndicator()
        end)
        local oldGained = input:GetScript("OnEditFocusGained")
        input:SetScript("OnEditFocusGained", function()
            if oldGained then oldGained() end
            focused = true
            SnapToBottom()
        end)
        local oldLost = input:GetScript("OnEditFocusLost")
        input:SetScript("OnEditFocusLost", function()
            if oldLost then oldLost() end
            focused = false
            Reveal()
            UpdateIndicator()
        end)
        if _G.ChatEdit_UpdateHeader then
            local updateHeader = _G.ChatEdit_UpdateHeader
            _G.ChatEdit_UpdateHeader = function(editBox)
                updateHeader(editBox)
                if editBox == input then InputLayout() end
            end
        end
    end

    SelectTab = function(state, userClick)
        if not state then return end
        selected = state
        selected.unread = false
        _G.SELECTED_CHAT_FRAME = state.native
        if _G.FCF_SelectDockFrame and Flag(state.native.isDocked) then
            _G.FCF_SelectDockFrame(state.native)
        else
            _G.SELECTED_DOCK_FRAME = state.native
        end
        if _G.FCF_StopAlertFlash then _G.FCF_StopAlertFlash(state.native) end
        Reveal()
        Layout(true)
        UpdateIndicator()
        RefreshTabs()
        if userClick and input and input:IsShown() then InputLayout() end
    end

    local function Receive(state, text, r, g, b)
        local now = GetTime()
        local messages = state.messages
        table.insert(messages, {text = text, r = r or 1, g = g or 1, b = b or 1,
            received = now, alpha = 0})
        if state.offset > 0 then
            state.offset = state.offset + 1
            state.unread = true
        elseif state ~= selected then
            state.unread = true
        end
        if table.getn(messages) > HISTORY then table.remove(messages, 1) end
        state.offset = Clamp(state.offset, 0, math.max(0, table.getn(messages) - 1))
        if state == selected then
            Layout(false)
            UpdateIndicator()
        end
    end

    local function AttachNative(index)
        local native = _G["ChatFrame" .. index]
        if not native or states[index] then return end
        local state = {native = native, index = index, messages = {}, offset = 0, unread = false}
        states[index] = state
        local nativeAdd = native.AddMessage
        native.AddMessage = function(frame, text, r, g, b, id, addToStart)
            if text == nil then return end
            -- Combat log is preserved in full; only normal chat is cleaned.
            local clean = index == 2 and text or chat.FilterMessage(text)
            if not clean then return end
            Receive(state, clean, r, g, b)
            return nativeAdd(frame, clean, r, g, b, id, addToStart)
        end
        -- Never Hide native frames: vanilla OnHide saves a closed window.
        -- They keep receiving and routing the game's chat events at alpha zero.
        local setAlpha = native.SetAlpha
        native.SetAlpha = function(frame) setAlpha(frame, 0) end
        native:SetAlpha(0)
        native:EnableMouse(false)
        native:EnableMouseWheel(false)
        for _, suffix in ipairs({"Tab", "UpButton", "DownButton", "BottomButton", "ButtonFrame"}) do
            SuppressControl(_G["ChatFrame" .. index .. suffix])
        end
        local tab = CreateFrame("Button", nil, dock)
        tab:SetHeight(DOCK_HEIGHT)
        tab.text = Label(tab, "", 12)
        tab.text:SetAllPoints(tab)
        tab.text:SetJustifyH("LEFT")
        tab.underline = tab:CreateTexture(nil, "ARTWORK")
        tab.underline:SetTexture(223 / 255, 186 / 255, 105 / 255, 0.8)
        tab.underline:SetHeight(1)
        tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 1)
        tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 1)
        tab:SetScript("OnClick", function() SelectTab(state, true) end)
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
        local x = 4
        for _, state in ipairs(active) do
            state.tab.text:SetText(state.name)
            local width = math.min(maxWidth, math.max(48, state.tab.text:GetStringWidth() + 16))
            state.tab:SetWidth(width)
            state.tab:ClearAllPoints()
            state.tab:SetPoint("TOPLEFT", dock, "TOPLEFT", x, 0)
            state.tab:Show()
            if state == selected then state.tab.underline:Show() else state.tab.underline:Hide() end
            x = x + width
        end
        if selected and not selected.active then SelectTab(states[1], false) end
    end

    SuppressControl(ChatFrameMenuButton)
    SuppressControl(FriendsMicroButton)
    SetupInput()
    RefreshTabs()
    local initial = _G.SELECTED_CHAT_FRAME or _G.SELECTED_DOCK_FRAME or ChatFrame1
    local initialState = states[1]
    for _, state in pairs(states) do if state.native == initial then initialState = state end end
    SelectTab(initialState, false)

    root:SetScript("OnUpdate", function()
        local now, elapsed = GetTime(), arg1 or 0
        local over = Over(root) or Over(input)
        if over ~= hovered then
            hovered = over
            Reveal()
        end
        local held = hovered or focused or (selected and selected.offset > 0)
        if held then dockUntil = now + 10 end
        local dockAlpha = held and 1 or Clamp(1 - (now - dockUntil) / FADE, 0, 1)
        dock:SetAlpha(dockAlpha)
        copy:EnableMouse(dockAlpha > 0.05)
        for _, state in pairs(states) do
            state.tab:EnableMouse(dockAlpha > 0.05)
            local pulse = state.unread and (0.5 + 0.5 * math.sin(now * 6)) or 1
            local selectedAlpha = state == selected and 1 or 0.7
            state.tab.text:SetTextColor(223 / 255, 186 / 255, 105 / 255, pulse * selectedAlpha)
        end
        for _, row in ipairs(rows) do
            local message = row.message
            if message then
                local holdUntil = math.max(message.received + HOLD, revealUntil)
                local targetAlpha = held and 1 or Clamp(1 - (now - holdUntil) / FADE, 0, 1)
                local alpha = message.alpha or 0
                if targetAlpha > alpha then alpha = math.min(targetAlpha, alpha + elapsed / FADE)
                else alpha = targetAlpha end
                message.alpha = alpha
                local progress = Clamp((now - message.received) / SLIDE, 0, 1)
                local shift = -12 * (1 - progress) * (1 - progress) * (1 - progress)
                message.y = message.y + (message.targetY - message.y) * math.min(1, elapsed * 15)
                row:ClearAllPoints()
                row:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 6, message.y + shift)
                row:SetAlpha(alpha)
                row:EnableMouse(alpha > 0.05)
            end
        end
        tabRefresh = tabRefresh + elapsed
        if tabRefresh >= 1 then
            tabRefresh = 0
            RefreshTabs()
        end
    end)
end)
