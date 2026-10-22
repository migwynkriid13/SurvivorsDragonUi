DFRL:NewMod("Xprep", 1, function()
    local texpath = DFRL:GetInfoOrCons("tex") .. "xprep\\"
    local defaults = { top = 49, height = 6, borderHeight = 12 }
    DFRL.xpBarDefaults = defaults
    KillFrame(MainMenuBarPerformanceBarFrame)
    KillFrame(MainMenuExpBar)
    KillFrame(ReputationWatchBar)

    local bar = CreateFrame("StatusBar", "DFRL_XPBar", UIParent)
    bar:SetHeight(defaults.height)
    bar:SetFrameStrata("LOW")
    bar:SetStatusBarTexture(texpath .. "main.tga")
    bar:SetStatusBarColor(0.85, 0.4, 0.85)
    bar:EnableMouse(false)
    bar:Hide()

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    background:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- Border halves stay inside the same horizontal bounds as the bar.
    local leftBorder = bar:CreateTexture(nil, "OVERLAY")
    leftBorder:SetTexture(texpath .. "border_half.tga")
    leftBorder:SetPoint("LEFT", bar, "LEFT", 0, 0)
    leftBorder:SetPoint("RIGHT", bar, "CENTER", 0, 0)
    leftBorder:SetHeight(defaults.borderHeight)

    local rightBorder = bar:CreateTexture(nil, "OVERLAY")
    rightBorder:SetTexture(texpath .. "border_half.tga")
    rightBorder:SetPoint("LEFT", bar, "CENTER", 0, 0)
    rightBorder:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    rightBorder:SetHeight(defaults.borderHeight)
    rightBorder:SetTexCoord(1, 0, 0, 1)

    local attached = false
    local registered = false
    local function UpdateXP()
        local currentXP = UnitXP("player") or 0
        local maximumXP = UnitXPMax("player") or 0
        bar:SetMinMaxValues(0, maximumXP > 0 and maximumXP or 1)
        bar:SetValue(currentXP)
        if attached and maximumXP > 0 then
            bar:Show()
        else
            bar:Hide()
        end
    end

    function DFRL.AttachXPBar(mainBar)
        -- Keep the artwork width, while positioning XP independently of the
        -- action bar. Moving or hiding another group never moves this bar.
        bar:SetParent(UIParent)
        bar:SetWidth(mainBar:GetWidth() + 2 * DFRL.actionBarDefaults.sideInset)
        bar:SetFrameLevel(mainBar:GetFrameLevel() + 2)
        if not registered then
            local moveRegion = CreateFrame("Frame", nil, bar)
            local borderInset = (defaults.borderHeight - defaults.height) / 2
            moveRegion:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, borderInset)
            moveRegion:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -borderInset)
            DFRL.layout.Register("xpBar", bar, function()
                bar:ClearAllPoints()
                bar:SetPoint("TOP", UIParent, "BOTTOM", 0, defaults.top)
            end, { region = moveRegion })
            registered = true
        else
            DFRL.layout.Place("xpBar", bar)
        end
        attached = true
        UpdateXP()
        if DFRL.AttachRunTally then DFRL.AttachRunTally() end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:SetScript("OnEvent", function()
        if event ~= "PLAYER_XP_UPDATE" or arg1 == "player" or arg1 == nil then UpdateXP() end
    end)
    DFRL.xpBar = bar
    -- The bar may already exist, or its world-entry callback will attach us.
    if DFRL.mainBar then DFRL.AttachXPBar(DFRL.mainBar) end
end)
