-- Copy-history dialog adapted from CleanerChat 2.44 Components/Modules/CopyChat.lua.
-- See third_party/CleanerChat-NOTICE.txt for the supplied source attribution.
-- Resizable dialog and session-only capture; native text selection/clipboard.

DFRL:NewMod("ChatCopy", 0, function()
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local Chat = DFRL.CleanerChat
    local dialog
    local WIDTH = 600
    local HEIGHT = 400

    local function PlainText(text)
        if type(text) ~= "string" then text = tostring(text or "") end
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
        title:SetFont("DEFAULT", 12, "")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
        title:SetTextColor(0.87, 0.73, 0.41)

        local hint = frame:CreateFontString(nil, "OVERLAY")
        hint:SetFont("DEFAULT", 12, "")
        hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
        hint:SetText("Select text and press Ctrl+C. Escape closes this window.")
        hint:SetTextColor(0.7, 0.74, 0.78)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() frame:Hide() end)

        local scroll = CreateFrame("ScrollFrame", "SurvivorsDragonUiChatCopyScroll", frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -36)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 30)

        local edit = CreateFrame("EditBox", "SurvivorsDragonUiChatCopyText", scroll)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(0)
        edit:SetAutoFocus(false)
        edit:SetFont("DEFAULT", 12, "")
        edit:SetTextColor(0.94, 0.94, 0.94)
        edit:SetWidth(WIDTH - 48)
        edit:SetHeight(HEIGHT - 66)
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)

        -- A same-width FontString measures wrapping for the scroll child.
        -- In 1.12, GetHeight returns its wrapped height when no height is set;
        -- GetStringHeight is not available in this client.
        local measure = frame:CreateFontString(nil, "ARTWORK")
        measure:SetFont("DEFAULT", 12, "")
        measure:SetWidth(WIDTH - 56)
        measure:SetJustifyH("LEFT")
        measure:SetJustifyV("TOP")
        measure:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        measure:Hide()

        local function ResizeText(text)
            local textWidth = frame:GetWidth() - 48
            edit:SetWidth(textWidth)
            measure:SetWidth(textWidth - 8)
            measure:SetText(text or "")
            local textHeight = measure:GetHeight() or 0
            edit:SetHeight(math.max(frame:GetHeight() - 66, textHeight + 16))
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
        edit:SetScript("OnTextChanged", function() ResizeText(this:GetText()) end)

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
        frame:SetScript("OnHide", function() edit:ClearFocus() end)

        frame.title = title
        frame.edit = edit
        frame.scroll = scroll
        frame.resizeText = ResizeText
        _G.UISpecialFrames = _G.UISpecialFrames or {}
        table.insert(_G.UISpecialFrames, "SurvivorsDragonUiChatCopy")
        frame:Hide()
        DFRL.layout.Register("copyWindow", frame, function(window)
            window:ClearAllPoints()
            window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end, {
            onlyWhenShown = true, onMouseWheel = ScrollWheel,
            resize = "dimensions",
            minWidth = 360, minHeight = 180,
            maxWidth = 2400, maxHeight = 1600,
            onResize = function(window)
                title:SetWidth(window:GetWidth() - 56)
                hint:SetWidth(window:GetWidth() - 24)
                ResizeText(edit:GetText())
            end,
        })
        return frame
    end

    function Chat.ShowCopy(text, title)
        if not dialog then dialog = CreateDialog() end
        local plain = PlainText(text)
        if plain == "" then plain = "No chat messages are available to copy." end
        dialog.title:SetText(PlainText(title or "Copy chat history"))
        dialog.edit:SetText(plain)
        dialog.resizeText(plain)
        dialog:Show()
        local slider = _G.SurvivorsDragonUiChatCopyScrollScrollBar
        if slider then slider:SetValue(0) end
        dialog.scroll:SetVerticalScroll(0)
        dialog.edit:SetFocus()
        dialog.edit:HighlightText()
    end

    -- Register in real globals: module initialization uses DFRL's private env.
    -- This entry point does not depend on the visible chat frame's mouse hooks.
    _G.SLASH_SURVIVORSDRAGONUICOPY1 = "/copy"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList["SURVIVORSDRAGONUICOPY"] = function()
        local text = Chat.GetCaptureText and Chat.GetCaptureText() or ""
        Chat.ShowCopy(text, "Copy chat - raw messages and events")
    end
end)
