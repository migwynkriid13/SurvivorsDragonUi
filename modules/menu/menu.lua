DFRL:NewMod("Menu", 1, function()
    KillFrame(GameMenuFrame)
    -- OptionsFrame is the original client's Video Options window. Newer
    -- benilla builds expose their complete game settings as BenillaOptionsFrame.
    local optionsFrame = BenillaOptionsFrame
    local menu = T.CreateDFRLFrame(UIParent, 200, optionsFrame and 165 or 130)
    menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    menu:SetFrameStrata("DIALOG")
    menu:Hide()
    local title = menu:CreateFontString(nil, "OVERLAY")
    title:SetFont("DEFAULT", 18, "OUTLINE")
    title:SetText("Azeroth Survivors")
    title:SetPoint("TOP", menu, "TOP", 0, -15)
    local resume = T.CreateButton(menu, "Resume Game", 140, 30)
    resume:SetPoint("TOP", title, "BOTTOM", 0, -10)
    resume:SetScript("OnClick", function() menu:Hide() end)
    local previous = resume
    if optionsFrame then
        local options = T.CreateButton(menu, "Options", 140, 30)
        options:SetPoint("TOP", resume, "BOTTOM", 0, -5)
        options:SetScript("OnClick", function()
            menu:Hide()
            ShowUIPanel(optionsFrame)
        end)
        previous = options
    end
    local quit = T.CreateButton(menu, "Exit Game", 140, 30)
    quit:SetPoint("TOP", previous, "BOTTOM", 0, -5)
    quit:SetScript("OnClick", function() Quit() end)
    menu:SetScript("OnShow", function()
        if MainMenuMicroButton then MainMenuMicroButton:SetButtonState("PUSHED", 1) end
    end)
    menu:SetScript("OnHide", function()
        if MainMenuMicroButton then MainMenuMicroButton:SetButtonState("NORMAL") end
    end)
    local function CloseOptions()
        if optionsFrame and optionsFrame:IsShown() then
            if BenillaOptionsFrameCloseButton then
                BenillaOptionsFrameCloseButton:Click()
            else
                HideUIPanel(optionsFrame)
            end
            return true
        end
        if OptionsFrame and OptionsFrame:IsShown() then
            if OptionsFrameCancel then
                OptionsFrameCancel:Click()
            else
                HideUIPanel(OptionsFrame)
            end
            return true
        end
    end
    _G.ToggleGameMenu = function(clicked)
        -- A deliberate button click opens the menu even with a target selected.
        -- Only ESC follows the normal close-window / clear-target sequence.
        if clicked then
            CloseOptions()
            if menu:IsShown() then
                menu:Hide()
            else
                CloseMenus()
                CloseAllWindows()
                menu:Show()
            end
            return
        end
        if StaticPopup_EscapePressed() then return end
        if CloseOptions() then return end
        if menu:IsShown() then
            menu:Hide()
            return
        end
        if CloseMenus() then return end
        if SpellStopCasting() then return end
        if SpellStopTargeting() then return end
        if CloseAllWindows() then return end
        if UnitExists("target") then
            ClearTarget()
        else
            menu:Show()
        end
    end
    DFRL.menuframe = menu
    DFRL.layout.Register("menu", menu, function(frame)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end, { onlyWhenShown = true })
end)
