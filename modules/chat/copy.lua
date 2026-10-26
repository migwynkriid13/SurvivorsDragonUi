-- Copy-history dialog adapted from CleanerChat 2.44 Components/Modules/CopyChat.lua.
-- See third_party/CleanerChat-NOTICE.txt for the supplied source attribution.
-- Resizable dialog and session-only capture; native text selection/clipboard.

DFRL:NewMod("ChatCopy", 0, function()
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local Chat = DFRL.CleanerChat
    local dialog
    local WIDTH = 600
    local HEIGHT = 400
    local PAGE_BYTES = 6144

    local function PlainText(text)
        if type(text) ~= "string" then text = tostring(text or "") end
        if not string.find(text, "|", 1, true) and not string.find(text, "\001", 1, true) then return text end
        -- Protect escaped literal pipes before removing display-only markup.
        text = string.gsub(text, "||", "\001")
        text = string.gsub(text, "|H.-|h(.-)|h", "%1")
        text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        text = string.gsub(text, "|r", "")
        text = string.gsub(text, "|T.-|t", "")
        text = string.gsub(text, "|A.-|a", "")
        text = string.gsub(text, "|n", "\n")
        text = string.gsub(text, "\001", "|")
        return text
    end

    local function TextSource(text)
        return {
            first = { last = string.len(text) },
            Read = function(position)
                local last = position and position.last or 0
                if last == 0 then return "", nil end
                local first = math.max(1, last - PAGE_BYTES + 1)
                local proposed = first
                for _ = 1, 3 do
                    if first > last then break end
                    local byte = string.byte(text, first)
                    if byte < 128 or byte >= 192 then break end
                    first = first + 1
                end
                local byte = first <= last and string.byte(text, first)
                if first > last or (byte and byte >= 128 and byte < 192) then first = proposed end
                return string.sub(text, first, last), first > 1 and { last = first - 1 } or nil
            end,
        }
    end

    local function ShortDiagnostics(text)
        if string.len(text) <= 1024 then return text end
        local last = 1021
        for _ = 1, 3 do
            local byte = string.byte(text, last + 1)
            if byte < 128 or byte >= 192 then break end
            last = last - 1
        end
        local byte = string.byte(text, last + 1)
        if byte >= 128 and byte < 192 then last = 1021 end
        return string.sub(text, 1, last) .. "..."
    end

    local function BannerDiagnostics()
        if type(DFRL.GetBannerDiagnostics) ~= "function" then return "[BANNERS] module unavailable" end
        local success, text = pcall(DFRL.GetBannerDiagnostics)
        if success and type(text) == "string" then return ShortDiagnostics(text) end
        return ShortDiagnostics("[BANNERS] diagnostics unavailable: " .. tostring(text))
    end

    local function CreateDialog()
        local frame = CreateFrame("Frame", "SurvivorsDragonUiChatCopy", UIParent)
        frame:SetWidth(WIDTH)
        frame:SetHeight(HEIGHT)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0.35, 0.42, 0.48, 0.9)

        local title = frame:CreateFontString(nil, "OVERLAY")
        DFRL.locale.Bind(title)
        T.SetFont(title, 12, "")
        title:SetWidth(WIDTH - 56)
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
        title:SetTextColor(0.87, 0.73, 0.41)

        local hint = frame:CreateFontString(nil, "OVERLAY")
        T.SetFont(hint, 12, "")
        hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
        hint:SetWidth(WIDTH - 24)
        hint:SetHeight(30)
        hint:SetJustifyH("LEFT")
        hint:SetJustifyV("BOTTOM")
        DFRL.locale.Bind(hint):SetText("Select text and press Ctrl+C. Escape closes this window.")
        hint:SetTextColor(0.7, 0.74, 0.78)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() frame:Hide() end)

        local scroll =
            CreateFrame("ScrollFrame", "SurvivorsDragonUiChatCopyScroll", frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -36)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 78)

        local edit = CreateFrame("EditBox", "SurvivorsDragonUiChatCopyText", scroll)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(0)
        edit:SetAutoFocus(false)
        T.SetFont(edit, 12, "")
        edit:SetTextColor(0.94, 0.94, 0.94)
        edit:SetWidth(WIDTH - 48)
        edit:SetHeight(HEIGHT - 98)
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)

        -- A same-width FontString measures wrapping for the scroll child.
        -- In 1.12, GetHeight returns its wrapped height when no height is set;
        -- GetStringHeight is not available in this client.
        local measure = frame:CreateFontString(nil, "ARTWORK")
        T.SetFont(measure, 12, "")
        measure:SetWidth(WIDTH - 56)
        measure:SetJustifyH("LEFT")
        measure:SetJustifyV("TOP")
        measure:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        measure:Hide()

        local textRevision = 0
        local observedText = edit:GetText()
        local measuredRevision, measuredWidth, measuredHeight, measuredScale
        local function ResizeText(text)
            local textWidth = frame:GetWidth() - 48
            local height, scale = frame:GetHeight(), frame:GetEffectiveScale()
            if
                measuredRevision == textRevision
                and T.NearlyEqual(measuredWidth, textWidth)
                and T.NearlyEqual(measuredHeight, height)
                and T.NearlyEqual(measuredScale, scale)
            then
                return
            end
            if not T.NearlyEqual(edit:GetWidth(), textWidth) then edit:SetWidth(textWidth) end
            if not T.NearlyEqual(measure:GetWidth(), textWidth - 8) then measure:SetWidth(textWidth - 8) end
            measure:SetText(text or "")
            local textHeight = measure:GetHeight() or 0
            -- The hidden measurer need not retain another complete snapshot.
            measure:SetText("")
            local editHeight = math.max(height - 98, textHeight + 16)
            if not T.NearlyEqual(edit:GetHeight(), editHeight) then edit:SetHeight(editHeight) end
            measuredRevision, measuredWidth, measuredHeight, measuredScale = textRevision, textWidth, height, scale
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
        edit:SetScript("OnTextChanged", function()
            local text = this:GetText()
            if observedText ~= text then
                observedText = text
                textRevision = textRevision + 1
            end
            ResizeText(text)
        end)

        local function ScrollWheel(direction)
            local slider = _G.SurvivorsDragonUiChatCopyScrollScrollBar
            if not slider then return end
            local low, high = slider:GetMinMaxValues()
            local value = slider:GetValue() - (direction or arg1 or 0) * 36
            slider:SetValue(math.max(low, math.min(high, value)))
        end
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", ScrollWheel)
        edit:EnableMouseWheel(true)
        edit:SetScript("OnMouseWheel", ScrollWheel)
        local previous = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        previous:SetWidth(28)
        previous:SetHeight(20)
        previous:SetPoint("CENTER", frame, "BOTTOM", -48, 56)
        previous:SetText("<")
        local following = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        following:SetWidth(28)
        following:SetHeight(20)
        following:SetPoint("CENTER", frame, "BOTTOM", 48, 56)
        following:SetText(">")
        local pageNumber = frame:CreateFontString(nil, "OVERLAY")
        T.SetFont(pageNumber, 12, "")
        pageNumber:SetPoint("CENTER", frame, "BOTTOM", 0, 56)
        pageNumber:SetWidth(60)
        pageNumber:SetHeight(20)
        pageNumber:SetJustifyH("CENTER")

        local source, positions, pages, page
        frame:SetScript("OnHide", function()
            edit:ClearFocus()
            source, positions, pages, page = nil, nil, nil, nil
        end)

        frame.title = title
        frame.edit = edit
        frame.scroll = scroll
        frame.resizeText = ResizeText
        frame.setText = function(text)
            if edit:GetText() == text then
                ResizeText(text)
                return
            end
            -- Also invalidate clients whose SetText does not send OnTextChanged.
            observedText = text
            textRevision = textRevision + 1
            edit:SetText(text)
            ResizeText(text)
        end
        local function ShowPage(index)
            if not source or index < 1 or (index > 1 and not positions[index]) then return end
            local entry = pages[index]
            if not entry then
                local text, nextPosition = source.Read(positions[index])
                entry = { text = text or "", nextPosition = nextPosition }
                pages[index] = entry
                positions[index + 1] = nextPosition
            end
            page = index
            local text = entry.text
            if source.includeDiagnostics then text = BannerDiagnostics() .. "\n\n" .. text end
            if text == "" then text = DFRL.locale.Text("No chat messages are available to copy.") end
            frame.setText(text)
            pageNumber:SetText(tostring(index))
            if index > 1 then
                previous:Enable()
            else
                previous:Disable()
            end
            if entry.nextPosition then
                following:Enable()
            else
                following:Disable()
            end
            local slider = _G.SurvivorsDragonUiChatCopyScrollScrollBar
            if slider then slider:SetValue(0) end
            scroll:SetVerticalScroll(0)
            edit:SetFocus()
            edit:HighlightText()
        end
        previous:SetScript("OnClick", function()
            if page then ShowPage(page - 1) end
        end)
        following:SetScript("OnClick", function()
            if page then ShowPage(page + 1) end
        end)
        frame.setSource = function(value)
            source, positions, pages = value, { value.first }, {}
            ShowPage(1)
        end
        _G.UISpecialFrames = _G.UISpecialFrames or {}
        table.insert(_G.UISpecialFrames, "SurvivorsDragonUiChatCopy")
        frame:Hide()
        DFRL.layout.Register("copyWindow", frame, nil, {
            onlyWhenShown = true,
            onMouseWheel = ScrollWheel,
            resize = "dimensions",
            minWidth = 360,
            minHeight = 180,
            maxWidth = 2400,
            maxHeight = 1600,
            onResize = function(window)
                title:SetWidth(window:GetWidth() - 56)
                hint:SetWidth(window:GetWidth() - 24)
                ResizeText(edit:GetText())
            end,
        })
        return frame
    end

    function Chat.ShowCopy(text, title, plainText, snapshot)
        if not Chat.IsCaptureEnabled() then return end
        if not dialog then dialog = CreateDialog() end
        dialog.title:SetText(PlainText(title or "Copy chat history"))
        dialog.setSource(snapshot or TextSource(plainText and (text or "") or PlainText(text)))
        dialog:Show()
        local slider = _G.SurvivorsDragonUiChatCopyScrollScrollBar
        if slider then slider:SetValue(0) end
        dialog.scroll:SetVerticalScroll(0)
        dialog.edit:SetFocus()
        dialog.edit:HighlightText()
    end

    Chat.ListenCapture(function(enabled)
        if enabled or not dialog then return end
        dialog:Hide()
        dialog.setText("")
    end)

    -- Register in real globals: module initialization uses DFRL's private env.
    -- This entry point does not depend on the visible chat frame's mouse hooks.
    _G.SLASH_SURVIVORSDRAGONUICOPY1 = "/copy"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList["SURVIVORSDRAGONUICOPY"] = function(message)
        local command = string.lower(string.gsub(message or "", "^%s*(.-)%s*$", "%1"))
        local feedback
        if command == "enable" then
            Chat.SetCaptureEnabled(true)
            feedback = "Copy enabled. New diagnostics will be collected."
        elseif command == "disable" then
            Chat.SetCaptureEnabled(false)
            feedback = "Copy disabled. Captured diagnostics cleared."
        elseif command ~= "" then
            feedback = "Usage: /copy, /copy enable, /copy disable."
        elseif not Chat.IsCaptureEnabled() then
            feedback = "Copy is disabled. Use /copy enable to start collecting diagnostics."
        end
        if feedback then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(DFRL.locale.Text(feedback)) end
            return
        end
        local snapshot = Chat.NewCaptureSnapshot and Chat.NewCaptureSnapshot(nil, true) or TextSource("")
        snapshot.includeDiagnostics = true
        Chat.ShowCopy(nil, "Copy chat - raw messages and events", true, snapshot)
    end
end)
