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

Floating-label HUD glyphs are Blizzard game artwork from source commit
00197f223180323ea7297c0157edbd1a43d2f99f:
Textures/Nameplates/Quests/Loot/loot_bag.tga (CachePouch.tga)
Textures/Nameplates/Quests/Kill/kill_elite.tga (GuardianFloating.tga)
Source provenance and license: third_party/CacheWaypoints-ARTWORK.md.
The upstream LICENSE excludes World of Warcraft artwork from its core MIT
license: game textures are copyright Blizzard Entertainment and included only
for use with the game. No upstream Lua is imported.

Detailed preparation: third_party/CacheWaypoints-ARTWORK.md.
]]
DFRL:NewMod("Waypoints", 3, function()
    local navigation = DFRL.navigation
    if not navigation then return end
    local texturePath = DFRL:GetInfoOrCons("tex") .. "waypoint\\"
    local actionDefaults, xpDefaults = DFRL.actionBarDefaults, DFRL.xpBarDefaults
    if not actionDefaults or not xpDefaults then return end
    local stackTop = actionDefaults.bottom + actionDefaults.height + actionDefaults.topInset
    local stackBottom = xpDefaults.top - (xpDefaults.height + xpDefaults.borderHeight) / 2
    local HUD_WIDTH, HUD_HEIGHT = 190, 46
    local stackCenter = (stackTop + stackBottom) / 2
    local sideOffset = actionDefaults.width / 2 + actionDefaults.sideInset + 8 + HUD_WIDTH / 2
    -- The selected preview shows 19 visible pixels; the source glyph spans 24/32.
    local POINTER_SIZE = 19 * 1.2 * 32 / 24
    local trackers = {
        {
            kind = "cache",
            source = "AZS_CHESTS",
            prefix = "AZSCHESTS",
            displayKey = "cacheGuidance",
            mirrorKey = "mirrorCacheWaypoint",
            layoutKey = "cacheWaypoint",
            frameName = "DFRL_CacheWaypoint",
            title = "Cache",
            defaultSide = "LEFT",
            mapArt = "MapPin.tga",
            hudArt = "CachePouch.tga",
            hudTexCoord = { 0, 119 / 128, 0, 119 / 128 },
        },
        {
            kind = "guardian",
            source = "AZS_LAIRS",
            prefix = "AZSLAIRS",
            displayKey = "guardianGuidance",
            mirrorKey = "mirrorGuardianWaypoint",
            layoutKey = "guardianWaypoint",
            frameName = "DFRL_GuardianWaypoint",
            title = "Guardian",
            defaultSide = "RIGHT",
            mapArt = "Guardian.tga",
            hudArt = "GuardianFloating.tga",
            hudTexCoord = { 0, 65 / 128, 0, 65 / 128 },
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

    local UpdateMinimapPins, ClearMinimapPins, DirtyMinimapScale, StopMinimapPins
    do
        local PIN_SIZE = 20
        local outdoorDiameter = { 14, 12, 10, 8, 6, 4 }
        local indoorDiameter = { 300, 240, 180, 120, 80, 50 }
        local originalFlag
        local mode, modeDirty, probing, reloading = nil, true, false, false
        local pendingZoom, RollbackZoom
        for _, tracker in ipairs(trackers) do
            tracker.minimapPins, tracker.minimapPool, tracker.minimapCycle = {}, {}, 0
        end

        local function Shown(value)
            if value == true or value == 1 or value == "1" then return true end
            if value == false or value == 0 or value == "0" then return false end
        end

        local function FlagShown()
            if type(_G.AZS_IsHudShown) ~= "function" then return end
            local ok, value = pcall(_G.AZS_IsHudShown, "flag")
            if ok then return Shown(value) end
        end

        local function RecyclePins(tracker, cycle)
            for key, pin in pairs(tracker.minimapPins) do
                if not cycle or pin.cycle ~= cycle then
                    pin:Hide()
                    pin.entryKey, pin.cycle = nil, nil
                    tracker.minimapPins[key] = nil
                    table.insert(tracker.minimapPool, pin)
                end
            end
        end

        ClearMinimapPins = function(kind, retryZoom)
            for _, tracker in ipairs(trackers) do
                if not kind or tracker.kind == kind then RecyclePins(tracker, nil) end
            end
            if not kind then navigation.UpdateMinimapPlayer(false) end
            if pendingZoom and (pendingZoom.retry or retryZoom) and not probing then RollbackZoom() end
        end

        local function RestoreNativeFlag()
            if originalFlag == nil or type(_G.AZS_SetHudShown) ~= "function" then return end
            local ok = pcall(_G.AZS_SetHudShown, "flag", originalFlag)
            if ok and FlagShown() == originalFlag then originalFlag = nil end
        end

        local function HideNativeFlag()
            if type(_G.AZS_SetHudShown) ~= "function" then return false end
            local shown = FlagShown()
            if shown == nil then return false end
            if originalFlag == nil then originalFlag = shown end
            if shown then
                local ok = pcall(_G.AZS_SetHudShown, "flag", false)
                if not ok then return false end
            end
            return FlagShown() == false
        end

        DirtyMinimapScale = function()
            if probing then return end
            mode, modeDirty = nil, true
            if pendingZoom then
                pendingZoom.retry = true
                RollbackZoom()
            end
        end

        local function ReadZoom()
            if not Minimap or type(Minimap.GetZoom) ~= "function" or type(_G.GetCVar) ~= "function" then return end
            local ok, zoom = pcall(Minimap.GetZoom, Minimap)
            local outsideOK, outside = pcall(_G.GetCVar, "minimapZoom")
            local insideOK, inside = pcall(_G.GetCVar, "minimapInsideZoom")
            outside, inside = tonumber(outside), tonumber(inside)
            if
                not ok
                or not outsideOK
                or not insideOK
                or not Integer(zoom, 0)
                or zoom > 5
                or not Integer(outside, 0)
                or outside > 5
                or not Integer(inside, 0)
                or inside > 5
            then
                return
            end
            return zoom, outside, inside
        end

        RollbackZoom = function()
            local saved = pendingZoom
            if not saved then return true end
            saved.retry = false
            local wasProbing = probing
            probing = true
            if Minimap and type(Minimap.SetZoom) == "function" then pcall(Minimap.SetZoom, Minimap, saved.zoom) end
            local zoom, outside, inside = ReadZoom()
            if zoom ~= saved.zoom or outside ~= saved.outside or inside ~= saved.inside then
                -- SetCVar restores each saved slot; SetZoom separately restores
                -- the active native index. Neither is trusted without readback.
                if type(_G.SetCVar) == "function" then
                    pcall(_G.SetCVar, "minimapZoom", saved.outside)
                    pcall(_G.SetCVar, "minimapInsideZoom", saved.inside)
                end
                if Minimap and type(Minimap.SetZoom) == "function" then pcall(Minimap.SetZoom, Minimap, saved.zoom) end
                zoom, outside, inside = ReadZoom()
            end
            probing = wasProbing
            if zoom == saved.zoom and outside == saved.outside and inside == saved.inside then
                pendingZoom = nil
                return true
            end
            return false
        end

        local function ResolveMode(zoom, outside, inside)
            -- Defer an ambiguous probe until a valid minimap destination needs it.
            -- Failed measurements wait for a native mode/zone/zoom event to retry.
            modeDirty = false
            if zoom == outside and zoom ~= inside then
                mode = "outdoor"
            elseif zoom == inside and zoom ~= outside then
                mode = "indoor"
            elseif zoom == outside and zoom == inside and type(Minimap.SetZoom) == "function" then
                -- SetZoom changes only the active zoom CVar. Restore synchronously
                -- before any drawing, including when the probe reports a failure.
                local neighbor = zoom == 5 and 4 or zoom + 1
                pendingZoom = { zoom = zoom, outside = outside, inside = inside, retry = true }
                probing = true
                local changed = pcall(Minimap.SetZoom, Minimap, neighbor)
                local sampledZoom, sampledOutside, sampledInside = ReadZoom()
                local restored = RollbackZoom()
                probing = false
                if not changed or not restored or sampledZoom ~= neighbor then return end
                if sampledOutside == neighbor and sampledInside == inside then
                    mode = "outdoor"
                elseif sampledInside == neighbor and sampledOutside == outside then
                    mode = "indoor"
                end
            end
        end

        local function Diameter()
            -- An unresolved rollback blocks every new probe and replacement.
            if pendingZoom then return end
            local zoom, outside, inside = ReadZoom()
            if zoom == nil then return end
            if modeDirty then ResolveMode(zoom, outside, inside) end
            if mode == "outdoor" and zoom == outside then
                return outdoorDiameter[zoom + 1] * (533.3333 / 16)
            elseif mode == "indoor" and zoom == inside then
                return indoorDiameter[zoom + 1]
            end
            mode = nil
        end

        local function MakeMinimapPin(tracker)
            local pin = CreateFrame("Frame", nil, Minimap)
            local size = tracker.kind == "cache" and PIN_SIZE * 0.8 or PIN_SIZE
            pin:Hide()
            pin:SetWidth(size)
            pin:SetHeight(size)
            pin:SetFrameLevel(navigation.MinimapLevel(tracker.kind))
            pin:EnableMouse(false)
            local art = pin:CreateTexture(nil, "OVERLAY")
            art:SetTexture(texturePath .. tracker.hudArt)
            art:SetTexCoord(unpack(tracker.hudTexCoord))
            art:SetAllPoints(pin)
            return pin
        end

        local function PlacePin(pin, x, y)
            if pin.drawnX ~= x or pin.drawnY ~= y then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
                pin.drawnX, pin.drawnY = x, y
            end
            if not pin:IsShown() then pin:Show() end
            return Shown(pin:IsVisible()) == true
        end

        local function Geometry()
            if not Minimap then return end
            local visibleOK, visible = pcall(Minimap.IsVisible, Minimap)
            if not visibleOK or Shown(visible) ~= true then return end
            local sizeOK, width, height = pcall(T.GetLocalSize, Minimap)
            if not sizeOK or not Number(width) or not Number(height) or width <= PIN_SIZE or height <= PIN_SIZE then
                return
            end
            local diameter = Diameter()
            if not Number(diameter) or diameter <= 0 then return end
            return math.min(width, height) / diameter, (math.min(width, height) - PIN_SIZE) / 2
        end

        local function Offset(entry, scale)
            local east, north, _, metric = navigation.GuideDelta(entry)
            if not metric or not Number(east) or not Number(north) then return end
            local x, y = east * scale, north * scale
            if Number(x) and Number(y) then return x, y end
        end

        local function DrawTrackedPin(tracker, entry, x, y)
            local pin = tracker.minimapPins[entry.key]
            if not pin then
                pin = table.remove(tracker.minimapPool) or MakeMinimapPin(tracker)
                tracker.minimapPins[entry.key] = pin
            end
            pin.entryKey, pin.cycle = entry.key, tracker.minimapCycle
            return PlacePin(pin, x, y)
        end

        local function UpdateTrackerPins(tracker, scale, edge)
            tracker.minimapCycle = tracker.minimapCycle + 1
            if scale and DFRL.display.Get(tracker.displayKey) then
                for _, entry in ipairs(tracker.entries) do
                    local x, y = Offset(entry, scale)
                    -- Every living guardian keeps its own distant indicator.
                    -- Off-map caches hide instead of piling up on the edge.
                    if x and tracker.kind == "guardian" then
                        local ratio = math.max(1, math.abs(x) / edge, math.abs(y) / edge)
                        x, y = x / ratio, y / ratio
                    end
                    if x and (tracker.kind == "guardian" or (math.abs(x) <= edge and math.abs(y) <= edge)) then
                        local drawOK, drawn = pcall(DrawTrackedPin, tracker, entry, x, y)
                        if not drawOK or not drawn then
                            local pin = tracker.minimapPins[entry.key]
                            if pin then pin.cycle = nil end
                        end
                    end
                end
            end
            RecyclePins(tracker, tracker.minimapCycle)
        end

        UpdateMinimapPins = function()
            if not inWorld or reloading then
                ClearMinimapPins()
                RestoreNativeFlag()
                return
            end
            navigation.StyleMinimap()
            -- Flag ownership does not depend on a destination or its geometry:
            -- empty/dead lairs and snapshot refreshes must never restore it.
            if DFRL.display.Get("guardianGuidance") then
                HideNativeFlag()
            else
                RestoreNativeFlag()
            end
            if not navigation.IsRunPhase(Native("AZS_GetPhase")) then
                ClearMinimapPins()
                return
            end
            local scale, edge
            for _, tracker in ipairs(trackers) do
                if DFRL.display.Get(tracker.displayKey) and tracker.entries[1] then
                    scale, edge = Geometry()
                    break
                end
            end
            local pinsVisible = false
            for _, tracker in ipairs(trackers) do
                UpdateTrackerPins(tracker, scale, edge)
                if next(tracker.minimapPins) then pinsVisible = true end
            end
            navigation.UpdateMinimapPlayer(pinsVisible)
        end

        StopMinimapPins = function()
            reloading = true
            inWorld = false
            if pendingZoom then pendingZoom.retry = true end
            ClearMinimapPins()
            RestoreNativeFlag()
        end
    end

    local function FloatingRail(hud)
        -- Keep only the thin gold stripe beneath the floating icon and text.
        local rail = hud:CreateTexture(nil, "BACKGROUND")
        rail:SetTexture("Interface\\Buttons\\WHITE8X8")
        rail:SetWidth(HUD_WIDTH)
        rail:SetHeight(1)
        rail:SetPoint("BOTTOMLEFT", hud, "BOTTOMLEFT", 0, 0)
        rail:SetBlendMode("BLEND")
        rail:SetVertexColor(186 / 255, 148 / 255, 87 / 255, 85 / 255)
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

    local function LayoutHUD(tracker)
        local mirrored = DFRL.display.Get(tracker.mirrorKey)
        if tracker.mirrored == mirrored then return end
        local hud = tracker.hud
        local side = mirrored and "RIGHT" or "LEFT"
        local sign = mirrored and -1 or 1
        tracker.marker:ClearAllPoints()
        tracker.marker:SetPoint(side, hud, side, sign * 26, 0)
        for _, entry in ipairs({ { tracker.titleText, -6 }, { tracker.distanceText, -22 } }) do
            local label = entry[1]
            label:ClearAllPoints()
            label:SetPoint("TOP" .. side, hud, "TOP" .. side, sign * 68, entry[2])
            label:SetJustifyH(side)
        end
        -- Move the arrow's pivot only; its native direction and UV rotation stay intact.
        tracker.pointer:ClearAllPoints()
        tracker.pointer:SetPoint("CENTER", hud, "LEFT", mirrored and 27 or HUD_WIDTH - 27, 0)
        tracker.mirrored = mirrored
    end

    local function MakeHUD(tracker)
        tracker.entries, tracker.pins = {}, {}
        tracker.emptyEntries = tracker.entries
        local hud = CreateFrame("Frame", tracker.frameName, UIParent)
        hud:SetWidth(HUD_WIDTH)
        hud:SetHeight(HUD_HEIGHT)
        hud:SetFrameStrata("HIGH")
        hud:EnableMouse(false)
        hud:Hide()
        FloatingRail(hud)
        local marker = hud:CreateTexture(nil, "ARTWORK")
        marker:SetTexture(texturePath .. (tracker.hudArt or tracker.mapArt))
        marker:SetWidth(32)
        marker:SetHeight(32)
        marker:SetTexCoord(unpack(tracker.hudTexCoord))
        tracker.marker = marker
        local pointer = hud:CreateTexture(nil, "OVERLAY")
        pointer:SetTexture(texturePath .. "HudArrow.tga")
        pointer:SetWidth(POINTER_SIZE)
        pointer:SetHeight(POINTER_SIZE)
        pointer:Hide()
        local title = hud:CreateFontString(nil, "OVERLAY")
        DFRL.locale.Bind(title)
        T.SetFont(title, 13, "OUTLINE")
        title:SetTextColor(0.93, 0.8, 0.53)
        title:SetWidth(76)
        title:SetHeight(16)
        title:SetJustifyV("MIDDLE")
        title:SetShadowColor(0, 0, 0, 0.9)
        title:SetShadowOffset(1, -1)
        title:SetText(tracker.title)
        local distanceText = hud:CreateFontString(nil, "OVERLAY")
        T.SetFont(distanceText, 15, "OUTLINE")
        distanceText:SetTextColor(1, 0.96, 0.85)
        distanceText:SetWidth(76)
        distanceText:SetHeight(19)
        distanceText:SetJustifyV("MIDDLE")
        distanceText:SetShadowColor(0, 0, 0, 0.9)
        distanceText:SetShadowOffset(1, -1)
        tracker.hud, tracker.pointer = hud, pointer
        tracker.titleText, tracker.distanceText = title, distanceText
        LayoutHUD(tracker)
        RegisterHUD(tracker)
    end
    for _, tracker in ipairs(trackers) do
        MakeHUD(tracker)
    end

    local function HidePin(pin)
        if GameTooltip and GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        if pin:IsShown() then pin:Hide() end
        pin.entry = nil
    end
    local function HidePins(tracker)
        for _, pin in ipairs(tracker.pins) do
            HidePin(pin)
        end
    end
    local function Clear(tracker)
        if tracker.kind == "guardian" and DFRL.guardians then DFRL.guardians.Clear() end
        ClearMinimapPins(tracker.kind)
        tracker.entries = tracker.emptyEntries
        tracker.acceptedEntries, tracker.acceptedLairs, tracker.acceptedStamp = nil, nil, nil
        navigation.SetPoints(tracker.source, nil)
        tracker.selectedKey, tracker.selected, tracker.provisionalSelection = nil, nil, nil
        tracker.presentation = nil
        if tracker.hudWanted ~= false then
            tracker.hudWanted = false
            tracker.hud:Hide()
        end
        if tracker.pointer:IsShown() then tracker.pointer:Hide() end
        T.SetTextIfChanged(tracker.distanceText, "")
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
        local stamp, received = _G[tracker.source .. "_UPDATED"], tracker.packetGeneration or 0
        if
            tracker.acceptedSnapshot == list
            and tracker.acceptedStamp == stamp
            and tracker.acceptedGeneration == received
            and tracker.acceptedEntries
        then
            if tracker.kind == "guardian" and DFRL.guardians then
                local context = Number(_G.AZS_ZONE_UPDATED) and _G.AZS_ZONE or nil
                DFRL.guardians.AcceptLairs(tracker.acceptedLairs, stamp, received, context)
            end
            return tracker.acceptedEntries
        end
        local guardian = tracker.kind == "guardian"
        local result, seen, lairs = {}, {}, {}
        for _, entry in ipairs(list) do
            if type(entry) ~= "table" then return end
            -- Both occupied states mean a living guardian. Coordinates belong
            -- to its lair, not to the creature while it moves during a fight.
            local occupied = (entry.state == "asleep" or entry.state == "awake") and Integer(entry.id, 1)
            if guardian then
                if not Integer(entry.index, 1) or seen[entry.index] then return end
                seen[entry.index] = true
                table.insert(lairs, {
                    index = entry.index,
                    id = entry.id,
                    name = entry.name,
                    state = entry.state,
                    left = entry.left,
                    x = entry.x,
                    y = entry.y,
                    z = entry.z,
                    mx = entry.mx,
                    my = entry.my,
                })
            end
            if not guardian or occupied then
                if
                    not Integer(entry.id, guardian and 1 or 0)
                    or not Number(entry.x)
                    or not Number(entry.y)
                    or (guardian and not Integer(entry.index, 1))
                then
                    return
                end
                if not guardian then
                    if seen[entry.id] then return end
                    seen[entry.id] = true
                end
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
        tracker.acceptedGeneration, tracker.acceptedStamp, tracker.acceptedEntries = received, stamp, result
        if guardian and DFRL.guardians then
            tracker.acceptedLairs = lairs
            local context = Number(_G.AZS_ZONE_UPDATED) and _G.AZS_ZONE or nil
            DFRL.guardians.AcceptLairs(lairs, _G.AZS_LAIRS_UPDATED, tracker.acceptedGeneration, context)
        end
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
        GameTooltip:SetText(DFRL.locale.Text(tracker.title), 1, 0.9, 0.58)
        if tracker.kind == "guardian" then
            if type(entry.name) == "string" and entry.name ~= "" then GameTooltip:AddLine(entry.name, 1, 1, 1) end
            GameTooltip:AddLine(
                DFRL.locale.Text(entry.state == "awake" and "Fighting; marker shows its lair" or "Waiting at its lair"),
                0.8,
                0.8,
                0.8
            )
        end
        GameTooltip:AddLine(
            DFRL.locale.Text(entry.key == tracker.selectedKey and "Tracking this waypoint" or "Click to track"),
            1,
            1,
            1
        )
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
            if DFRL.display.Get(tracker.displayKey) then
                for _, entry in ipairs(tracker.entries) do
                    local x, y = navigation.Project(entry)
                    if x then
                        index = index + 1
                        local pin = MapPin(tracker, index)
                        pin.entry = entry
                        local tracked = entry.key == tracker.selectedKey
                        local size = tracked and 32 or 26
                        if pin.drawnSize ~= size then
                            pin:SetWidth(size)
                            pin:SetHeight(size)
                            pin:SetAlpha(tracked and 1 or 0.75)
                            pin.drawnSize = size
                        end
                        local drawnX, drawnY = x * width, -y * height
                        if pin.drawnRegion ~= region or pin.drawnX ~= drawnX or pin.drawnY ~= drawnY then
                            pin:ClearAllPoints()
                            pin:SetPoint("CENTER", region, "TOPLEFT", drawnX, drawnY)
                            pin.drawnRegion, pin.drawnX, pin.drawnY = region, drawnX, drawnY
                        end
                        if not pin:IsShown() then pin:Show() end
                        if GameTooltip and GameTooltip:IsOwned(pin) then PinTooltip(tracker, pin) end
                    end
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

    local function WrapAngle(angle)
        local turn = math.pi * 2
        return angle - math.floor((angle + math.pi) / turn) * turn
    end

    local function Blend(presentation, key, target, stamp, elapsed, angular, playing)
        if not playing or not Number(target) or not Number(stamp) then
            presentation[key] = nil
            return target
        end
        local value = presentation[key]
        if not value or stamp < value.stamp or stamp - value.stamp > 1 then
            value = { current = target, from = target, target = target, stamp = stamp, age = 0, duration = 0 }
            presentation[key] = value
        elseif target ~= value.target then
            local interval = stamp - value.stamp
            value.from, value.target, value.age = value.current, target, 0
            value.duration = math.max(0, math.min(interval, 0.5))
        end
        value.stamp = stamp
        value.age = math.min(value.age + elapsed, value.duration)
        if value.duration == 0 or value.age >= value.duration then
            value.current = target
        else
            local delta = target - value.from
            if angular then delta = WrapAngle(delta) end
            value.current = value.from + delta * value.age / value.duration
        end
        if angular then value.current = WrapAngle(value.current) end
        return value.current
    end

    local function UpdateGuide(tracker, elapsed)
        if not DFRL.display.Get(tracker.displayKey) or not tracker.selected then
            tracker.presentation = nil
            if tracker.hudWanted ~= false then
                tracker.hudWanted = false
                tracker.hud:Hide()
            end
            return
        end
        if not tracker.hudWanted then
            tracker.hudWanted = true
            tracker.hud:Show()
        end
        if not tracker.hud:IsVisible() then
            tracker.presentation = nil
            return
        end
        elapsed = elapsed or 0
        local selected = tracker.selected
        local east, north, distance, metric, stamp = navigation.GuideDelta(selected)
        local facing, headingStamp = navigation.Heading()
        local presentation = tracker.presentation
        if
            not presentation
            or presentation.key ~= selected.key
            or presentation.x ~= selected.x
            or presentation.y ~= selected.y
            or elapsed > 0.5
            or (
                east
                and presentation.east
                and (east - presentation.east) ^ 2 + (north - presentation.north) ^ 2 > 32 ^ 2
            )
        then
            presentation = { key = selected.key, x = selected.x, y = selected.y }
            tracker.presentation = presentation
        end
        presentation.east, presentation.north = east, north
        local playing = Native("AZS_GetPhase") == "playing"
        local moving = east and (east ~= 0 or north ~= 0)
        local bearing = moving and metric and math.atan2(east, north) or nil
        -- Only the paint values blend. Selection and map pins keep native data,
        -- and interpolation stops at each received sample without prediction.
        distance = Blend(presentation, "distance", distance, stamp, elapsed, false, playing)
        bearing = Blend(presentation, "bearing", bearing, stamp, elapsed, true, playing)
        facing = Blend(presentation, "facing", facing, headingStamp, elapsed, true, playing)
        if moving and metric and facing then
            -- Native heading is counterclockwise, destination bearing clockwise.
            local angle = bearing + facing
            if tracker.pointerAngle ~= angle then
                Rotate(tracker.pointer, angle)
                tracker.pointerAngle = angle
            end
            if not tracker.pointer:IsShown() then tracker.pointer:Show() end
        else
            if tracker.pointer:IsShown() then tracker.pointer:Hide() end
        end
        local text = distance and DFRL.locale.Native("common.yards", { n = math.floor(distance + 0.5) })
            or DFRL.locale.Text("On map")
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
        "ZONE_CHANGED_INDOORS",
        "ZONE_CHANGED",
        "MINIMAP_UPDATE_ZOOM",
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
            DirtyMinimapScale()
            UpdateMinimapPins()
            return
        end
        if
            event == "PLAYER_ENTERING_WORLD"
            or event == "ZONE_CHANGED_NEW_AREA"
            or event == "ZONE_CHANGED_INDOORS"
            or event == "ZONE_CHANGED"
            or event == "MINIMAP_UPDATE_ZOOM"
        then
            DirtyMinimapScale()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 == "AZSZONE" then
                if identity then RetireSnapshots(false) end
                identity = nil
                navigation.Reset()
                ClearAll()
            elseif arg1 == "AZSUNITS" then
                if DFRL.guardians then DFRL.guardians.UnitsReceived() end
                return
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
        local elapsed = tonumber(arg1) or 0
        if not Number(elapsed) or elapsed < 0 then elapsed = 0 end
        age = age + elapsed
        if dirty or age >= 0.1 then
            dirty, age = false, 0
            Refresh()
        end
        if inWorld then
            for _, tracker in ipairs(trackers) do
                UpdateGuide(tracker, elapsed)
            end
        end
        UpdateMinimapPins()
    end)
    DFRL.display.Listen(function()
        -- Visibility drafts do not retire snapshots, selections or calibration.
        UpdateMap()
        for _, tracker in ipairs(trackers) do
            LayoutHUD(tracker)
            UpdateGuide(tracker)
        end
        if not DFRL.display.Get("guardianGuidance") then ClearMinimapPins("guardian", true) end
        UpdateMinimapPins()
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            StopMinimapPins()
            return reloadUI()
        end
    end
    Refresh()
end)
