DFRL:NewMod("Xprep", 1, function()
    local texpath = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\xprep\\"
    KillFrame(MainMenuBarPerformanceBarFrame)
    KillFrame(MainMenuExpBar)
    KillFrame(ReputationWatchBar)

    local bar = CreateFrame("StatusBar", "DFRL_XPBar", UIParent)
    bar:SetHeight(6)
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
    leftBorder:SetHeight(12)

    local rightBorder = bar:CreateTexture(nil, "OVERLAY")
    rightBorder:SetTexture(texpath .. "border_half.tga")
    rightBorder:SetPoint("LEFT", bar, "CENTER", 0, 0)
    rightBorder:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    rightBorder:SetHeight(12)
    rightBorder:SetTexCoord(1, 0, 0, 1)

    local attached = false
    local function UpdateXP()
        local currentXP = UnitXP("player") or 0
        local maximumXP = UnitXPMax("player") or 0
        bar:SetMinMaxValues(0, maximumXP > 0 and maximumXP or 1)
        bar:SetValue(currentXP)
        if attached and maximumXP > 0 then bar:Show() else bar:Hide() end
    end

    function DFRL.AttachXPBar(mainBar)
        bar:SetParent(mainBar)
        bar:ClearAllPoints()
        -- Match the action-bar artwork's six-pixel outer edge on each side.
        bar:SetPoint("TOPLEFT", mainBar, "BOTTOMLEFT", -6, -6)
        bar:SetPoint("TOPRIGHT", mainBar, "BOTTOMRIGHT", 6, -6)
        bar:SetFrameLevel(mainBar:GetFrameLevel() + 2)
        attached = true
        UpdateXP()
        if DFRL.AttachRunTally then DFRL.AttachRunTally() end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:SetScript("OnEvent", function()
        if event ~= "PLAYER_XP_UPDATE" or arg1 == "player" or arg1 == nil then
            UpdateXP()
        end
    end)
    DFRL.xpBar = bar
    -- The bar may already exist, or its world-entry callback will attach us.
    if DFRL.mainBar then DFRL.AttachXPBar(DFRL.mainBar) end
end)
