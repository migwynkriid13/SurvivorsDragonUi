DFRL:NewMod("Map", 1, function()
    local texpath = DFRL:GetInfoOrCons("tex") .. "minimap\\"
    local function WatchClock(frame, label, zoneButton, zoneText, panel)
        local native = T.NewHudOwner("localClock", "hudLocalClock")
        local elapsed, enabled = 0, nil
        local inWorld = UnitExists("player") and true or false
        local caption, ready, tooltipCaption
        local nativeHour, nativeMinute, nativeText
        local function HideTooltip()
            if GameTooltip and GameTooltip:IsOwned(frame) and GameTooltip:IsShown() then GameTooltip:Hide() end
            tooltipCaption = nil
        end
        local function DrawTooltip()
            if not caption or not GameTooltip or not GameTooltip:IsOwned(frame) then return end
            if tooltipCaption ~= caption then
                GameTooltip:ClearLines()
                GameTooltip:AddLine("Local time: " .. caption, 1, 1, 1)
                tooltipCaption = caption
            end
            if not GameTooltip:IsShown() then GameTooltip:Show() end
        end
        local function HideReading()
            ready, caption = false, nil
            if label:IsShown() then label:Hide() end
            HideTooltip()
        end
        local function NativeSupported()
            return type(_G.AZS_GetLocalTime) == "function"
                and type(_G.AZS_IsHudShown) == "function"
                and type(_G.AZS_SetHudShown) == "function"
                and native.Read() ~= nil
        end
        local function SyncNative()
            if enabled and ready then
                local font = label:GetFont()
                if type(font) ~= "string" or font == "" or label:GetText() ~= caption then HideReading() end
            end
            if inWorld and NativeSupported() and (not enabled or ready) then
                if not native.Acquire(false) then
                    native.Release()
                    if enabled then HideReading() end
                end
            else
                native.Release()
            end
        end
        local function ClockPart(value, maximum)
            return type(value) == "number"
                and value - value == 0
                and value >= 0
                and value <= maximum
                and value == math.floor(value)
        end
        local function ReadClock()
            if type(_G.AZS_GetLocalTime) == "function" then
                local ok, value = pcall(_G.AZS_GetLocalTime)
                if
                    not ok
                    or type(value) ~= "table"
                    or not ClockPart(value.hour, 23)
                    or not ClockPart(value.minute, 59)
                    or type(value.text) ~= "string"
                    or value.text == ""
                    or type(value.is24Hour) ~= "boolean"
                then
                    return
                end
                if nativeHour ~= value.hour or nativeMinute ~= value.minute then
                    nativeHour, nativeMinute = value.hour, value.minute
                    nativeText = string.format("%02d:%02d", nativeHour, nativeMinute)
                end
                return nativeText
            end
            if type(date) ~= "function" then return end
            local ok, value = pcall(date, "%H:%M")
            if ok and type(value) == "string" and value ~= "" then return value end
        end
        local function Refresh()
            if not inWorld or not enabled or not frame:IsVisible() then return end
            local value = ReadClock()
            local ok = value and pcall(T.SetTextIfChanged, label, value)
            local font = label:GetFont()
            if value and (type(font) ~= "string" or font == "") then
                pcall(T.SetFont, label, 10, "")
                font = label:GetFont()
            end
            ready = ok and type(font) == "string" and font ~= "" and label:GetText() == value or false
            caption = ready and value or nil
            if ready then
                if not label:IsShown() then label:Show() end
                if GameTooltip and GameTooltip:IsOwned(frame) and GameTooltip:IsShown() then DrawTooltip() end
            else
                HideReading()
            end
            SyncNative()
        end
        local function Tick()
            elapsed = elapsed + math.max(0, tonumber(arg1) or 0)
            if elapsed < 5 then return end
            elapsed = 0
            Refresh()
        end
        local function Start()
            if not enabled or not inWorld or not frame:IsVisible() then
                SyncNative()
                return
            end
            elapsed = 0
            if frame:GetScript("OnUpdate") ~= Tick then frame:SetScript("OnUpdate", Tick) end
            Refresh()
        end
        local function Stop()
            if frame:GetScript("OnUpdate") then frame:SetScript("OnUpdate", nil) end
            HideTooltip()
        end
        local function Retire()
            inWorld = false
            Stop()
            HideReading()
            native.Release()
        end
        frame:SetScript("OnShow", Start)
        frame:SetScript("OnHide", Stop)
        frame:SetScript("OnEnter", function()
            if not inWorld or not enabled or not ready or not frame:IsVisible() or not GameTooltip then return end
            GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMLEFT")
            tooltipCaption = nil
            DrawTooltip()
        end)
        frame:SetScript("OnLeave", HideTooltip)
        local function UpdateChoice()
            local shown = DFRL.display.Get("minimapShowClock")
            if enabled == shown then
                SyncNative()
                return
            end
            enabled, elapsed = shown, 0
            zoneButton:ClearAllPoints()
            if shown then
                zoneButton:SetPoint("LEFT", panel, "LEFT", 4, -3)
                zoneText:SetJustifyH("LEFT")
                if not frame:IsShown() then
                    frame:Show()
                else
                    Start()
                end
            else
                Stop()
                if frame:IsShown() then frame:Hide() end
                zoneButton:SetPoint("CENTER", panel, "CENTER", 0, -3)
                zoneText:SetJustifyH("CENTER")
            end
            SyncNative()
        end
        DFRL.display.Listen(UpdateChoice)
        DFRL.locale.Listen(function()
            if enabled then
                Start()
            else
                SyncNative()
            end
        end)
        for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "CVAR_UPDATE" }) do
            frame:RegisterEvent(name)
        end
        frame:SetScript("OnEvent", function()
            if event == "PLAYER_ENTERING_WORLD" then
                inWorld = true
                if enabled then
                    Start()
                else
                    SyncNative()
                end
            elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
                Retire()
            elseif event == "CVAR_UPDATE" and native.Observe(arg1) then
                SyncNative()
            end
        end)
        if type(_G.ReloadUI) == "function" then
            local reloadUI = _G.ReloadUI
            _G.ReloadUI = function()
                Retire()
                return reloadUI()
            end
        end
        UpdateChoice()
    end
    local defaults = { width = 180, height = 180, right = -8, top = -26, zoomX = -21, zoomY = 40, zoomScale = 0.8 }
    -- Export appearance geometry before layout restores any confirmed placement.
    DFRL.minimapDefaults = defaults

    local container = CreateFrame("Frame", "DFRL_Minimap", UIParent)
    container:SetWidth(defaults.width)
    container:SetHeight(defaults.height)
    container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", defaults.right, defaults.top)
    Minimap:SetParent(container)
    Minimap:ClearAllPoints()
    -- Keep the zone strip at the top edge and tuck the map closer beneath it.
    Minimap:SetAllPoints(container)
    Minimap:SetWidth(defaults.width)
    Minimap:SetHeight(defaults.height)
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
        section:SetTexture(texpath .. "map_dragonflight_square2.blp")
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
    shadow:SetTexture(texpath .. "map_dragonflight_square_shadow.blp")
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
    panel:SetPoint("BOTTOM", Minimap, "TOP", 0, 12)

    local panelBackground = panel:CreateTexture(nil, "BACKGROUND")
    panelBackground:SetTexture(texpath .. "uiminimap_toppanel.blp")
    panelBackground:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panelBackground:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 5, -20)

    MinimapZoneTextButton:ClearAllPoints()
    MinimapZoneTextButton:SetParent(panel)
    MinimapZoneTextButton:SetPoint("LEFT", panel, "LEFT", 4, -3)
    MinimapZoneText:SetJustifyH("LEFT")
    T.SetFont(MinimapZoneText, 10, "")

    local timeFrame = CreateFrame("Frame", "MinimapTimeFrame", panel)
    timeFrame:SetWidth(40)
    timeFrame:SetHeight(20)
    timeFrame:SetPoint("RIGHT", panel, "RIGHT", -4, -3)
    timeFrame:EnableMouse(true)

    local timeText = timeFrame:CreateFontString("MinimapTimeText", "OVERLAY", "GameFontNormal")
    timeText:SetPoint("CENTER", timeFrame, "CENTER", 0, 0)
    T.SetFont(timeText, 10, "")
    timeText:SetTextColor(1, 1, 1, 1)
    WatchClock(timeFrame, timeText, MinimapZoneTextButton, MinimapZoneText, panel)

    MinimapZoomIn:ClearAllPoints()
    MinimapZoomIn:SetParent(Minimap)
    MinimapZoomIn:SetPoint("TOPLEFT", Minimap, "BOTTOMRIGHT", defaults.zoomX, defaults.zoomY)
    MinimapZoomOut:ClearAllPoints()
    MinimapZoomOut:SetParent(Minimap)
    MinimapZoomOut:SetPoint("TOPRIGHT", MinimapZoomIn, "BOTTOMLEFT", 0, 0)
    for _, button in ipairs({ MinimapZoomIn, MinimapZoomOut }) do
        local name = button == MinimapZoomIn and "ZoomIn32" or "ZoomOut32"
        button:SetScale(defaults.zoomScale)
        T.StyleMinimapZoomButton(button, name)
        button:Show()
    end

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

    for _, name in ipairs({ "QuestWatchFrame", "QuestTimerFrame", "MiniMapMailFrame" }) do
        PermanentlyDisableFrame(_G[name])
    end

    DFRL.topPanel = panel
    DFRL.minimapRoot = container
    local function SetLauncherEditing(active)
        local launcher = _G.SurvivorsDragonUiMinimapButton
        if not launcher then return end
        -- Keep the toggle reachable above Layout's level-100 selection,
        -- while the settings dialog (150) and its controls remain above it.
        local strata = active and "TOOLTIP" or Minimap:GetFrameStrata()
        local level = active and 125 or Minimap:GetFrameLevel() + 20
        if launcher:GetFrameStrata() ~= strata then launcher:SetFrameStrata(strata) end
        if launcher:GetFrameLevel() ~= level then launcher:SetFrameLevel(level) end
    end
    DFRL.layout.Register("minimap", container, nil, { wheelFrame = Minimap, onEdit = SetLauncherEditing })
end)
