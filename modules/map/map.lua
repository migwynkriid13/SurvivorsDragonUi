DFRL:NewMod("Map", 1, function()
    local texpath = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\minimap\\"

    local container = CreateFrame("Frame", "DFRL_Minimap", UIParent)
    container:SetWidth(180)
    container:SetHeight(180)
    container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -32)
    Minimap:SetParent(container)
    Minimap:ClearAllPoints()
    -- Keep the zone strip at the top edge and tuck the map closer beneath it.
    Minimap:SetAllPoints(container)
    Minimap:SetWidth(180)
    Minimap:SetHeight(180)
    Minimap:SetAlpha(1)
    Minimap:SetFrameStrata("MEDIUM")
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
    MinimapCluster:EnableMouse(false)
    MinimapBorder:Hide()
    MinimapBorderTop:Hide()
    KillFrame(MinimapToggleButton)
    KillFrame(GameTimeFrame)

    -- The gold up arrow is baked into the border; replace only its top-center section.
    local borderSize = 206
    local function CreateBorderSection(left, right, top, bottom, textureLeft, textureRight)
        local section = Minimap:CreateTexture(nil, "OVERLAY")
        section:SetTexture(texpath .. "map_dragonflight_square2.tga")
        section:SetTexCoord(textureLeft or left, textureRight or right, top, bottom)
        section:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -13 + borderSize * left, 13 - borderSize * top)
        section:SetWidth(borderSize * (right - left))
        section:SetHeight(borderSize * (bottom - top))
    end
    CreateBorderSection(0, 1, 0.125, 1)
    CreateBorderSection(0, 0.375, 0, 0.125)
    CreateBorderSection(0.625, 1, 0, 0.125)
    CreateBorderSection(0.375, 0.625, 0, 0.125, 0.25, 0.375)

    local shadow = Minimap:CreateTexture(nil, "BORDER")
    shadow:SetTexture(texpath .. "map_dragonflight_square_shadow.tga")
    shadow:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -13, 13)
    shadow:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 13, -13)
    shadow:SetAlpha(0.3)

    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function()
        if arg1 > 0 then
            MinimapZoomIn:Click()
        elseif arg1 < 0 then
            MinimapZoomOut:Click()
        end
    end)

    local panel = CreateFrame("Frame", "MinimapTopPanel", Minimap)
    panel:SetWidth(180)
    panel:SetHeight(12)
    panel:SetPoint("BOTTOM", Minimap, "TOP", 0, 18)

    local panelBackground = panel:CreateTexture(nil, "BACKGROUND")
    panelBackground:SetTexture(texpath .. "uiminimap_toppanel.tga")
    panelBackground:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panelBackground:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 5, -20)

    MinimapZoneTextButton:ClearAllPoints()
    MinimapZoneTextButton:SetParent(panel)
    MinimapZoneTextButton:SetPoint("LEFT", panel, "LEFT", 4, -3)
    MinimapZoneText:SetJustifyH("LEFT")
    MinimapZoneText:SetFont("DEFAULT", 10, "")

    local timeFrame = CreateFrame("Frame", "MinimapTimeFrame", panel)
    timeFrame:SetWidth(40)
    timeFrame:SetHeight(20)
    timeFrame:SetPoint("RIGHT", panel, "RIGHT", -4, -3)
    timeFrame:EnableMouse(true)

    local timeText = timeFrame:CreateFontString("MinimapTimeText", "OVERLAY", "GameFontNormal")
    timeText:SetPoint("CENTER", timeFrame, "CENTER", 0, 0)
    timeText:SetFont("DEFAULT", 10, "")
    timeText:SetTextColor(1, 1, 1, 1)
    timeText:SetText(date("%H:%M"))
    local nextClockUpdate = 0
    timeFrame:SetScript("OnUpdate", function()
        local now = GetTime()
        if now >= nextClockUpdate then
            nextClockUpdate = now + 5
            timeText:SetText(date("%H:%M"))
        end
    end)
    timeFrame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("Local time: " .. date("%H:%M"), 1, 1, 1)
        GameTooltip:Show()
    end)
    timeFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    MinimapZoomIn:ClearAllPoints()
    MinimapZoomIn:SetParent(Minimap)
    MinimapZoomIn:SetPoint("TOPLEFT", Minimap, "BOTTOMRIGHT", -21, 40)
    MinimapZoomOut:ClearAllPoints()
    MinimapZoomOut:SetParent(Minimap)
    MinimapZoomOut:SetPoint("TOPRIGHT", MinimapZoomIn, "BOTTOMLEFT", 0, 0)
    for _, button in ipairs({MinimapZoomIn, MinimapZoomOut}) do
        local name = button == MinimapZoomIn and "ZoomIn32" or "ZoomOut32"
        button:SetScale(0.8)
        button:SetAlpha(1)
        button:SetNormalTexture(texpath .. name .. ".tga")
        button:SetDisabledTexture(texpath .. name .. "-disabled.tga")
        button:SetHighlightTexture(texpath .. name .. "-over.tga")
        button:SetPushedTexture(texpath .. name .. "-push.tga")
        button:Show()
    end

    MiniMapMailFrame:ClearAllPoints()
    MiniMapMailFrame:SetParent(Minimap)
    MiniMapMailFrame:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", -2, -1)
    MiniMapMailIcon:SetTexture(texpath .. "mail.tga")
    MiniMapMailIcon:SetWidth(32)
    MiniMapMailIcon:SetHeight(32)
    MiniMapMailBorder:Hide()

    MiniMapTrackingFrame:ClearAllPoints()
    MiniMapTrackingFrame:SetParent(Minimap)
    MiniMapTrackingFrame:SetPoint("TOPRIGHT", panel, "TOPLEFT", -15, 0)
    MiniMapTrackingFrame:SetScale(0.6)
    MiniMapTrackingBorder:Hide()

    DurabilityFrame:ClearAllPoints()
    DurabilityFrame:SetParent(Minimap)
    DurabilityFrame:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", 15, 15)
    DurabilityFrame.SetPoint = function() end
    DurabilityFrame:SetScale(0.7)

    local questframe = CreateFrame("Frame", "DFRL_questframe", UIParent)
    local function PlaceQuestDefault()
        questframe:ClearAllPoints()
        -- This is the default minimap-relative position expressed on the screen.
        questframe:SetPoint("LEFT", UIParent, "TOPRIGHT", -338, -252)
    end
    PlaceQuestDefault()
    questframe:SetWidth(170)
    questframe:SetHeight(5)
    QuestWatchFrame:SetParent(questframe)
    QuestWatchFrame:ClearAllPoints()
    QuestWatchFrame:SetAllPoints(questframe)
    QuestWatchFrame:SetFrameLevel(1)
    QuestWatchFrame.SetPoint = function() end

    DFRL.topPanel = panel
    DFRL.minimapRoot = container
    DFRL.questframe = questframe
    DFRL.layout.Register("minimap", container, nil, {wheelFrame = Minimap})
    DFRL.layout.Register("questWatch", questframe, PlaceQuestDefault)
end)
