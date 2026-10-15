-- Official cache and occupied guardian-lair snapshots supply these waypoints.
--[[
Original artwork is owned by Blizzard Entertainment. The Gethe archive is a public extraction of World of Warcraft client UI assets; it does not grant a new license to Blizzard artwork.

Cache/navigation artwork: retail 9.2.7 (45114), Gethe mirror commit
d23deaf8f44a7d280dc974a5c9d5321c013db59b. The tracked map pin and navigation
atlas were converted/cropped to TGA, preserving original colors and alpha:
https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/MINIMAP/Minimap-Waypoint-MapPin-Tracked.PNG
https://raw.githubusercontent.com/Gethe/wow-ui-textures/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Navigation/IngameNavigationUI.PNG

Guardian artwork: Dragonflight 10.2.7.54847 VignetteKillElite, FileDataID
1121272, atlas 647. The 1024x1024 atlas rectangle [265, 131, 329, 195) is
preserved at 64x64 without rescaling; its native display override is 32x32:
https://wago.tools/api/casc/1121272?version=10.2.7.54847
https://wago.tools/db2/UiTextureAtlasMember/csv?build=10.2.7.54847

Frame slices reuse the original Blizzard WidgetStatusBar artwork:
https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Widgets/WidgetStatusBar.PNG
Detailed preparation: third_party/CacheWaypoints-ARTWORK.md and
third_party/WidgetStatusBar-SOURCE.md.
]]
DFRL:NewMod("Waypoints", 3, function()
    local navigation = DFRL.navigation
    if not navigation then return end
    local texturePath = DFRL:GetInfoOrCons("tex") .. "waypoint\\"
    local pillPath = DFRL:GetInfoOrCons("tex") .. "timer\\"
    local actionDefaults, xpDefaults = DFRL.actionBarDefaults, DFRL.xpBarDefaults
    if not actionDefaults or not xpDefaults then return end
    local stackTop = actionDefaults.bottom + actionDefaults.height + actionDefaults.topInset
    local stackBottom = xpDefaults.top - (xpDefaults.height + xpDefaults.borderHeight) / 2
    local HUD_SIZE = (stackTop - stackBottom) * 0.95
    local stackCenter = (stackTop + stackBottom) / 2
    local sideOffset = actionDefaults.width / 2 + actionDefaults.sideInset + 8 + HUD_SIZE / 2
    local POINTER_SIZE = 18
    local trackers = {
        {
            kind = "cache",
            source = "AZS_CHESTS",
            prefix = "AZSCHESTS",
            layoutKey = "cacheWaypoint",
            frameName = "DFRL_CacheWaypoint",
            title = "Cache",
            defaultSide = "LEFT",
            mapArt = "MapPin.tga",
            hudArt = "HudDiamond.tga",
            hudWidth = 14,
            hudHeight = 20,
            hudTexCoord = { 3 / 32, 29 / 32, 13 / 64, 50 / 64 },
        },
        {
            kind = "guardian",
            source = "AZS_LAIRS",
            prefix = "AZSLAIRS",
            layoutKey = "guardianWaypoint",
            frameName = "DFRL_GuardianWaypoint",
            title = "Guardian",
            defaultSide = "RIGHT",
            mapArt = "Guardian.tga",
        },
    }
    local identity
    local runWasActive = false
    local inWorld, dirty, age = true, true, 0
    local mapLayer, mapRegion

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Integer(value, minimum) return Number(value) and value >= minimum and value == math.floor(value) end
    local function Native(name)
        local getter = _G[name]
        if type(getter) ~= "function" then return end
        local ok, value = pcall(getter)
        if ok then return value end
    end

    local function PillTexture(hud, name, layer, width, height, left, right, top, bottom)
        local texture = hud:CreateTexture(nil, layer)
        texture:SetTexture(pillPath .. name .. ".tga")
        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetTexCoord(left, right, top, bottom)
        return texture
    end

    local function WaypointSquare(hud)
        -- Keep the pill artwork's complete beveled corners and gold shading.
        -- Split its caps vertically so only straight sections stretch taller.
        local artScale = 1.5
        local capWidth, cornerHeight = 11 * artScale, 7 * artScale
        local columns = {
            { "BorderLeft", 0, capWidth, 5 / 64, 16 / 64 },
            { "BorderCenter", capWidth, HUD_SIZE - 2 * capWidth, 0, 1 },
            { "BorderRight", HUD_SIZE - capWidth, capWidth, 19 / 64, 30 / 64 },
        }
        local rows = {
            { 0, cornerHeight, 5 / 32, 12 / 32 },
            { cornerHeight, HUD_SIZE - 2 * cornerHeight, 12 / 32, 19 / 32 },
            { HUD_SIZE - cornerHeight, cornerHeight, 19 / 32, 26 / 32 },
        }
        for columnIndex, column in ipairs(columns) do
            for rowIndex, row in ipairs(rows) do
                if columnIndex ~= 2 or rowIndex ~= 2 then
                    local rim =
                        PillTexture(hud, column[1], "BORDER", column[3], row[2], column[4], column[5], row[3], row[4])
                    rim:SetPoint("TOPLEFT", hud, "TOPLEFT", column[2], -row[1])
                    -- The original caps contain black outer shadows.
                    rim:SetBlendMode("ADD")
                    rim:SetAlpha(0.9)
                end
            end
        end

        -- Follow the original inner contour instead of drawing a black square
        -- behind its cut corners. The central band expands with the frame.
        local bands = {
            { 2 * artScale, artScale, 5 * artScale },
            { 3 * artScale, artScale, 4 * artScale },
            { 4 * artScale, artScale, 3 * artScale },
            { 5 * artScale, HUD_SIZE - 10 * artScale, 2 * artScale },
            { HUD_SIZE - 5 * artScale, artScale, 3 * artScale },
            { HUD_SIZE - 4 * artScale, artScale, 4 * artScale },
            { HUD_SIZE - 3 * artScale, artScale, 5 * artScale },
        }
        for _, band in ipairs(bands) do
            local fill =
                PillTexture(hud, "BackgroundCenter", "BACKGROUND", HUD_SIZE - 2 * band[3], band[2], 0, 1, 0, 18 / 32)
            fill:SetPoint("TOP", hud, "TOP", 0, -band[1])
            fill:SetAlpha(0.45)
        end
    end

    local function RegisterHUD(tracker)
        if tracker.registered then return true end
        DFRL.layout.Register(tracker.layoutKey, tracker.hud, function()
            local hud = tracker.hud
            local x = tracker.defaultSide == "LEFT" and -sideOffset or sideOffset
            hud:ClearAllPoints()
            hud:SetPoint("CENTER", UIParent, "BOTTOM", x, stackCenter)
        end)
        -- Defaults come from the action/XP modules' static appearance geometry;
        -- all confirmed positions and scales remain independent of those bars.
        tracker.registered = true
        return true
    end

    local function MakeHUD(tracker)
        tracker.entries, tracker.pins = {}, {}
        local hud = CreateFrame("Frame", tracker.frameName, UIParent)
        hud:SetWidth(HUD_SIZE)
        hud:SetHeight(HUD_SIZE)
        hud:SetFrameStrata("HIGH")
        hud:EnableMouse(false)
        hud:Hide()
        WaypointSquare(hud)
        local marker = hud:CreateTexture(nil, "ARTWORK")
        marker:SetTexture(texturePath .. (tracker.hudArt or tracker.mapArt))
        marker:SetWidth(tracker.hudWidth or 20)
        marker:SetHeight(tracker.hudHeight or 20)
        if tracker.hudTexCoord then marker:SetTexCoord(unpack(tracker.hudTexCoord)) end
        marker:SetPoint("CENTER", hud, "TOP", -11, -HUD_SIZE * 0.27)
        tracker.marker = marker
        local pointer = hud:CreateTexture(nil, "OVERLAY")
        pointer:SetTexture(texturePath .. "HudArrow.tga")
        pointer:SetWidth(POINTER_SIZE)
        pointer:SetHeight(POINTER_SIZE)
        pointer:Hide()
        local title = hud:CreateFontString(nil, "OVERLAY")
        title:SetFont("DEFAULT", 9, "OUTLINE")
        title:SetTextColor(1, 0.9, 0.58)
        title:SetPoint("CENTER", hud, "TOP", 0, -HUD_SIZE * 0.58)
        title:SetWidth(HUD_SIZE - 8)
        title:SetHeight(12)
        title:SetJustifyH("CENTER")
        title:SetJustifyV("MIDDLE")
        title:SetShadowColor(0, 0, 0, 0.9)
        title:SetShadowOffset(1, -1)
        title:SetText(tracker.title)
        local distanceText = hud:CreateFontString(nil, "OVERLAY")
        distanceText:SetFont("DEFAULT", 10, "OUTLINE")
        distanceText:SetTextColor(1, 1, 1)
        distanceText:SetPoint("CENTER", hud, "TOP", 0, -HUD_SIZE * 0.8)
        distanceText:SetWidth(HUD_SIZE - 8)
        distanceText:SetHeight(12)
        distanceText:SetJustifyH("CENTER")
        distanceText:SetJustifyV("MIDDLE")
        distanceText:SetShadowColor(0, 0, 0, 0.9)
        distanceText:SetShadowOffset(1, -1)
        tracker.hud, tracker.pointer, tracker.distanceText = hud, pointer, distanceText
        RegisterHUD(tracker)
    end
    for _, tracker in ipairs(trackers) do
        MakeHUD(tracker)
    end

    local function HidePin(pin)
        if GameTooltip and GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        pin:Hide()
        pin.entry = nil
    end
    local function HidePins(tracker)
        for _, pin in ipairs(tracker.pins) do
            HidePin(pin)
        end
    end
    local function Clear(tracker)
        tracker.entries = {}
        navigation.SetPoints(tracker.source, nil)
        tracker.selectedKey, tracker.selected, tracker.provisionalSelection = nil, nil, nil
        tracker.hud:Hide()
        tracker.pointer:Hide()
        tracker.distanceText:SetText("")
        HidePins(tracker)
    end
    local function ClearAll()
        for _, tracker in ipairs(trackers) do
            Clear(tracker)
        end
    end
    local function RetireSnapshots(force)
        for _, tracker in ipairs(trackers) do
            if force then
                tracker.blockedSnapshot = _G[tracker.source]
            elseif
                tracker.acceptedSnapshot
                and (tracker.packetGeneration or 0) == (tracker.acceptedGeneration or 0)
            then
                -- A matching packet since acceptance may already carry the new
                -- run, including parsers that reuse the same native array.
                tracker.blockedSnapshot = tracker.acceptedSnapshot
            end
        end
    end

    local function Snapshot(tracker)
        local list = _G[tracker.source]
        -- Each list has its own readiness. Last-change times from different
        -- prefixes are not run ids and cannot establish snapshot ordering.
        if type(list) ~= "table" or not Number(_G[tracker.source .. "_UPDATED"]) or list == tracker.blockedSnapshot then
            return
        end
        local guardian = tracker.kind == "guardian"
        local result, seen = {}, {}
        for _, entry in ipairs(list) do
            if type(entry) ~= "table" then return end
            -- Both occupied states mean a living guardian. Coordinates belong
            -- to its lair, not to the creature while it moves during a fight.
            local occupied = (entry.state == "asleep" or entry.state == "awake") and Integer(entry.id, 1)
            if not guardian or occupied then
                if
                    not Integer(entry.id, guardian and 1 or 0)
                    or not Number(entry.x)
                    or not Number(entry.y)
                    or (guardian and not Integer(entry.index, 1))
                then
                    return
                end
                local identityKey = guardian and entry.index or entry.id
                if seen[identityKey] then return end
                seen[identityKey] = true
                local key = guardian and (tostring(entry.index) .. ":" .. tostring(entry.id)) or tostring(entry.id)
                table.insert(result, {
                    key = key,
                    id = entry.id,
                    index = guardian and entry.index or nil,
                    name = guardian and entry.name or nil,
                    state = guardian and entry.state or nil,
                    x = entry.x,
                    y = entry.y,
                    mx = entry.mx,
                    my = entry.my,
                })
            end
        end
        tracker.acceptedSnapshot = list
        tracker.acceptedGeneration = tracker.packetGeneration or 0
        return result
    end

    local function Choose(tracker)
        tracker.selected = nil
        local previous
        for _, entry in ipairs(tracker.entries) do
            if entry.key == tracker.selectedKey then
                previous = entry
                if not tracker.provisionalSelection then
                    tracker.selected = entry
                    return
                end
                break
            end
        end
        local best
        for _, entry in ipairs(tracker.entries) do
            local east, north, distance = navigation.Delta(entry)
            local score = distance or (east and math.sqrt(east * east + north * north))
            if score and (not best or score < best) then
                tracker.selected, best = entry, score
            end
        end
        if tracker.selected then
            tracker.provisionalSelection = nil
        else
            -- Keep known destinations available while position data arrives,
            -- then resolve the automatic nearest selection on a later refresh.
            tracker.selected = previous or tracker.entries[1]
            tracker.provisionalSelection = tracker.selected ~= nil
        end
        tracker.selectedKey = tracker.selected and tracker.selected.key or nil
    end

    local function PinTooltip(tracker, pin)
        local entry = pin.entry
        if not entry or not GameTooltip then return end
        GameTooltip:SetText(tracker.title, 1, 0.9, 0.58)
        if tracker.kind == "guardian" then
            if type(entry.name) == "string" and entry.name ~= "" then GameTooltip:AddLine(entry.name, 1, 1, 1) end
            GameTooltip:AddLine(
                entry.state == "awake" and "Fighting; marker shows its lair" or "Waiting at its lair",
                0.8,
                0.8,
                0.8
            )
        end
        GameTooltip:AddLine(entry.key == tracker.selectedKey and "Tracking this waypoint" or "Click to track", 1, 1, 1)
        GameTooltip:Show()
    end

    local function MapPin(tracker, index)
        local pin = tracker.pins[index]
        if pin then return pin end
        pin = CreateFrame("Button", nil, mapLayer)
        pin:SetWidth(26)
        pin:SetHeight(26)
        pin:SetFrameLevel(mapLayer:GetFrameLevel() + 1)
        pin:RegisterForClicks("LeftButtonUp")
        local art = pin:CreateTexture(nil, "ARTWORK")
        art:SetTexture(texturePath .. tracker.mapArt)
        art:SetAllPoints(pin)
        pin:SetScript("OnClick", function()
            if not pin.entry then return end
            tracker.selectedKey = pin.entry.key
            tracker.provisionalSelection = nil
            dirty = true
        end)
        pin:SetScript("OnEnter", function()
            if not pin.entry or not GameTooltip then return end
            GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
            PinTooltip(tracker, pin)
        end)
        pin:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        end)
        tracker.pins[index] = pin
        return pin
    end

    local function UpdateMap()
        local region = WorldMapDetailFrame or WorldMapButton
        local parent = WorldMapButton or region
        if not region or not parent or not WorldMapFrame or not WorldMapFrame:IsShown() then
            for _, tracker in ipairs(trackers) do
                HidePins(tracker)
            end
            return
        end
        if not mapLayer then
            mapLayer = CreateFrame("Frame", nil, parent)
            mapLayer:SetFrameLevel(parent:GetFrameLevel() + 10)
            mapLayer:EnableMouse(false)
        end
        if mapRegion ~= region then
            mapRegion = region
            mapLayer:SetAllPoints(region)
        end
        local width, height = region:GetWidth(), region:GetHeight()
        if not Number(width) or not Number(height) or width <= 0 or height <= 0 then
            for _, tracker in ipairs(trackers) do
                HidePins(tracker)
            end
            return
        end
        for _, tracker in ipairs(trackers) do
            local index = 0
            for _, entry in ipairs(tracker.entries) do
                local x, y = navigation.Project(entry)
                if x then
                    index = index + 1
                    local pin = MapPin(tracker, index)
                    pin.entry = entry
                    local tracked = entry.key == tracker.selectedKey
                    local size = tracked and 32 or 26
                    pin:SetWidth(size)
                    pin:SetHeight(size)
                    pin:SetAlpha(tracked and 1 or 0.75)
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", region, "TOPLEFT", x * width, -y * height)
                    pin:Show()
                    if GameTooltip and GameTooltip:IsOwned(pin) then PinTooltip(tracker, pin) end
                end
            end
            for unused = index + 1, table.getn(tracker.pins) do
                HidePin(tracker.pins[unused])
            end
        end
    end

    local function Rotate(texture, angle)
        local c, s = math.cos(angle) / 2, math.sin(angle) / 2
        texture:SetTexCoord(
            0.5 - c - s,
            0.5 + s - c,
            0.5 - c + s,
            0.5 + s + c,
            0.5 + c - s,
            0.5 - s - c,
            0.5 + c + s,
            0.5 - s + c
        )
    end

    local function UpdateGuide(tracker)
        if not tracker.selected then
            tracker.hud:Hide()
            return
        end
        tracker.hud:Show()
        local east, north, distance, metric = navigation.Delta(tracker.selected)
        local facing = navigation.Heading()
        local moving = east and (east ~= 0 or north ~= 0)
        if moving and metric and facing then
            -- Native heading is counterclockwise, destination bearing clockwise.
            local angle = math.atan2(east, north) + facing
            tracker.pointer:ClearAllPoints()
            tracker.pointer:SetPoint("CENTER", tracker.hud, "TOP", 11, -HUD_SIZE * 0.27)
            Rotate(tracker.pointer, angle)
            tracker.pointer:Show()
        else
            tracker.pointer:Hide()
        end
        local text = distance and (tostring(math.floor(distance + 0.5)) .. " yd") or "On map"
        if tracker.distanceText:GetText() ~= text then tracker.distanceText:SetText(text) end
    end

    local function Refresh()
        for _, tracker in ipairs(trackers) do
            if not RegisterHUD(tracker) then
                ClearAll()
                return
            end
        end
        if not inWorld then
            ClearAll()
            return
        end
        local phase = Native("AZS_GetPhase")
        if not navigation.IsRunPhase(phase) then
            if runWasActive and (phase == "ready" or phase == "dead") then
                RetireSnapshots(true)
                navigation.Reset()
                runWasActive = false
            end
            ClearAll()
            return
        end
        runWasActive = true
        local zone = _G.AZS_ZONE
        if
            type(zone) == "table"
            and type(zone.zone) == "string"
            and Number(zone.map)
            and Number(_G.AZS_ZONE_UPDATED)
        then
            local nextIdentity = zone.zone .. ":" .. tostring(zone.map) .. ":" .. tostring(_G.AZS_ZONE_UPDATED)
            if nextIdentity ~= identity then
                if identity then RetireSnapshots(false) end
                ClearAll()
                navigation.Reset()
                identity = nextIdentity
            end
        end
        for _, tracker in ipairs(trackers) do
            local snapshot = Snapshot(tracker)
            if snapshot then
                tracker.entries = snapshot
                navigation.SetPoints(tracker.source, snapshot)
            else
                Clear(tracker)
            end
        end
        for _, tracker in ipairs(trackers) do
            Choose(tracker)
        end
        UpdateMap()
    end

    local controller = CreateFrame("Frame", "DFRL_CacheWaypointReader", UIParent)
    for _, eventName in ipairs({
        "CHAT_MSG_ADDON",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_LOGOUT",
        "WORLD_MAP_UPDATE",
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED",
    }) do
        controller:RegisterEvent(eventName)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            runWasActive = false
            RetireSnapshots(true)
            identity = nil
            navigation.Reset()
            ClearAll()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 == "AZSZONE" then
                if identity then RetireSnapshots(false) end
                identity = nil
                navigation.Reset()
                ClearAll()
            elseif arg1 ~= "AZSRUN" then
                local received = false
                for _, tracker in ipairs(trackers) do
                    if arg1 == tracker.prefix then
                        -- A packet also releases parsers that reuse their table.
                        tracker.packetGeneration = (tracker.packetGeneration or 0) + 1
                        tracker.blockedSnapshot = nil
                        received = true
                    end
                end
                if not received then return end
            end
        end
        -- Defer reads until the native parser and map event handlers finish.
        dirty = true
    end)
    controller:SetScript("OnUpdate", function()
        age = age + (tonumber(arg1) or 0)
        if dirty or age >= 0.1 then
            dirty, age = false, 0
            Refresh()
        end
        if inWorld then
            for _, tracker in ipairs(trackers) do
                UpdateGuide(tracker)
            end
        end
    end)
    Refresh()
end)
