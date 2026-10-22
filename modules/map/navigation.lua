-- Map geometry stays session-only. Native map coordinates are east/south;
-- world X/Y are north/west, respectively, in yards.
DFRL:NewMod("Navigation", 2, function()
    local navigation = {}
    DFRL.navigation = navigation
    local phases = { playing = true, choosing = true, paused = true, victory = true }
    local minimapLevels = { cache = 10, guardian = 11, player = 12 }
    local identity, expected, realZone, arrow
    local playerOverlay, playerTexture, playerSide, playerFacing
    local points = {}
    local samples, seen, width, height = {}, {}, nil, nil

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Coordinates(x, y) return Number(x) and Number(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 end
    function navigation.IsRunPhase(phase) return phases[phase] == true end
    function navigation.MinimapLevel(kind) return Minimap:GetFrameLevel() + minimapLevels[kind] end
    function navigation.Reset()
        identity, expected, realZone, arrow = nil, nil, nil, nil
        samples, seen, width, height = {}, {}, nil, nil
    end
    function navigation.SetPoints(key, list) points[key] = list end
    local function RunState()
        if type(_G.AZS_GetPhase) ~= "function" then return end
        local ok, phase = pcall(_G.AZS_GetPhase)
        if not ok or not navigation.IsRunPhase(phase) then return end
        local state = _G.AZS_RUN
        if type(state) == "table" and Number(_G.AZS_RUN_UPDATED) then return state end
    end
    local function Context()
        if type(_G.AZS_GetPhase) ~= "function" then return end
        local ok, phase = pcall(_G.AZS_GetPhase)
        if not ok or not navigation.IsRunPhase(phase) then return end
        local zone = _G.AZS_ZONE
        if
            type(zone) ~= "table"
            or type(zone.zone) ~= "string"
            or zone.zone == ""
            or not Number(zone.map)
            or not Number(_G.AZS_ZONE_UPDATED)
        then
            return
        end
        local current = zone.zone .. ":" .. tostring(zone.map) .. ":" .. tostring(_G.AZS_ZONE_UPDATED)
        local name = type(GetRealZoneText) == "function" and GetRealZoneText() or nil
        if current ~= identity or name ~= realZone then
            navigation.Reset()
            identity, realZone = current, name
        end
        return zone
    end
    local function Selection()
        if type(GetMapInfo) ~= "function" then return end
        local ok, name = pcall(GetMapInfo)
        if not ok or type(name) ~= "string" or name == "" then return end
        local continent = type(GetCurrentMapContinent) == "function" and GetCurrentMapContinent() or nil
        local zone = type(GetCurrentMapZone) == "function" and GetCurrentMapZone() or nil
        return name .. ":" .. tostring(continent) .. ":" .. tostring(zone)
    end
    function navigation.Position()
        if not Context() or type(GetPlayerMapPosition) ~= "function" then return end
        local selected = Selection()
        local browsing = WorldMapFrame and WorldMapFrame:IsShown()
        if not browsing and (not expected or selected ~= expected) then
            if type(SetMapToCurrentZone) ~= "function" then return end
            local ok = pcall(SetMapToCurrentZone)
            if not ok then return end
            selected = Selection()
            expected = selected
        end
        -- Browsing another map must never lend its coordinates to this run.
        if not expected or selected ~= expected then return end
        local ok, x, y = pcall(GetPlayerMapPosition, "player")
        if ok and Coordinates(x, y) and (x ~= 0 or y ~= 0) then return x, y end
    end
    function navigation.Project(target)
        local zone = Context()
        if not zone or type(target) ~= "table" then return end
        if type(GetWorldLocMapPosition) == "function" then
            if not Number(target.x) or not Number(target.y) then return end
            -- This native getter checks the world map id and projects onto the
            -- displayed sheet without changing the user's selected map.
            local ok, x, y = pcall(GetWorldLocMapPosition, zone.map, target.x, target.y)
            if ok and Coordinates(x, y) and (x ~= 0 or y ~= 0) then return x, y end
        end
        -- An unavailable native projection must not discard official map
        -- coordinates on the confirmed current-zone sheet.
        if navigation.Position() and Coordinates(target.mx, target.my) then return target.mx, target.my end
    end

    local function Sample(point)
        if type(point) ~= "table" or not Coordinates(point.mx, point.my) then return end
        if not Number(point.x) or not Number(point.y) then return end
        local copy = { x = point.x, y = point.y, mx = point.mx, my = point.my }
        local horizontal, vertical = samples.horizontal, samples.vertical
        if not horizontal then
            samples.horizontal = copy
        elseif not width and math.abs(copy.mx - horizontal.mx) > 0.0001 then
            local span = -(copy.y - horizontal.y) / (copy.mx - horizontal.mx)
            if Number(span) and span > 0 then width = span end
        end
        if not vertical then
            samples.vertical = copy
        elseif not height and math.abs(copy.my - vertical.my) > 0.0001 then
            local span = -(copy.x - vertical.x) / (copy.my - vertical.my)
            if Number(span) and span > 0 then height = span end
        end
    end
    local function ReadPoints(key)
        local list = points[key]
        if not list or seen[key] == list then return end
        seen[key] = list
        for _, point in ipairs(list) do
            Sample(point)
        end
    end
    local function WorldPoint(map, x, y)
        local ok, mx, my = pcall(GetWorldLocMapPosition, map, x, y)
        if ok and Coordinates(mx, my) and (mx ~= 0 or my ~= 0) then return mx, my end
    end
    local function Measure(point, map)
        if type(point) ~= "table" then return end
        if not Number(point.x) or not Number(point.y) then return end
        local mx, my = WorldPoint(map, point.x, point.y)
        if not mx then return end
        for _, step in ipairs({ 32, -32 }) do
            if not height then
                local x, y = WorldPoint(map, point.x + step, point.y)
                if x and math.abs(x - mx) < 0.00001 and math.abs(y - my) > 0.000001 then
                    local span = -step / (y - my)
                    if Number(span) and span > 0 then height = span end
                end
            end
            if not width then
                local x, y = WorldPoint(map, point.x, point.y + step)
                if x and math.abs(y - my) < 0.00001 and math.abs(x - mx) > 0.000001 then
                    local span = -step / (x - mx)
                    if Number(span) and span > 0 then width = span end
                end
            end
        end
    end
    function navigation.Metric()
        local zone = Context()
        if not zone or not expected or Selection() ~= expected then return end
        if (not width or not height) and type(GetWorldLocMapPosition) == "function" then
            -- A native projection can establish scale from one current point.
            -- Probes are read-only and both signs allow points near map edges.
            for _, key in ipairs({ "AZS_CHESTS", "AZS_LAIRS" }) do
                local list = points[key]
                if list then
                    for _, point in ipairs(list) do
                        Measure(point, zone.map)
                        if width and height then break end
                    end
                end
                if width and height then break end
            end
        end
        if not width or not height then
            -- When native projection cannot establish scale, official coordinates must use
            -- the same current-zone sheet as GetPlayerMapPosition. Distinct
            -- world/map pairs establish its axes without guessed extents.
            ReadPoints("AZS_CHESTS")
            ReadPoints("AZS_LAIRS")
        end
        if width and height then return width, height end
    end
    local function Aspect()
        if type(GetMapInfo) == "function" then
            local ok, _, w, h = pcall(GetMapInfo)
            if ok and Number(w) and Number(h) and w > 0 and h > 0 then return w / h end
        end
        if WorldMapDetailFrame and WorldMapDetailFrame.GetWidth and WorldMapDetailFrame.GetHeight then
            local w, h = WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight()
            if Number(w) and Number(h) and w > 0 and h > 0 then return w / h end
        end
        return 1
    end
    local function MapDelta(target)
        if type(target) ~= "table" then return end
        local x, y = navigation.Position()
        if not x then return end
        local targetX, targetY = target.mx, target.my
        if type(GetWorldLocMapPosition) == "function" then
            local projectedX, projectedY = navigation.Project(target)
            if projectedX then
                targetX, targetY = projectedX, projectedY
            end
        end
        if not Coordinates(targetX, targetY) then return end
        local w, h = navigation.Metric()
        if w and h then
            local east, north = (targetX - x) * w, (y - targetY) * h
            return east, north, math.sqrt(east * east + north * north), true
        end
        return (targetX - x) * Aspect(), y - targetY, nil, false
    end
    function navigation.Delta(target)
        if type(target) ~= "table" then return end
        local state = RunState()
        if state and Number(state.px) and Number(state.py) and Number(target.x) and Number(target.y) then
            -- Official world coordinates work without a map sheet or calibration,
            -- including instances. The stamp identifies sampled HUD presentation.
            local east, north = state.py - target.y, target.x - state.px
            return east, north, math.sqrt(east * east + north * north), true, _G.AZS_RUN_UPDATED
        end
        return MapDelta(target)
    end
    function navigation.GuideDelta(target)
        -- A valid current-sheet native reading follows movement every frame.
        -- Keep sampled world coordinates for instances and other map sheets.
        local east, north, distance, metric = MapDelta(target)
        if metric then return east, north, distance, true end
        return navigation.Delta(target)
    end

    local function PlayerArrow()
        if not Minimap or not Minimap.GetChildren then return end
        local children = { Minimap:GetChildren() }
        local player
        for _, child in ipairs(children) do
            if child.GetModel and child.GetFacing then
                local ok, path = pcall(child.GetModel, child)
                if ok and type(path) == "string" then
                    path = string.gsub(string.lower(path), "/", "\\")
                    if string.find(path, "\\minimaparrow", 1, true) then
                        player = child
                    elseif string.find(path, "\\rotating-minimaparrow", 1, true) then
                        -- The native updater can show these indicators again;
                        -- transparent models stay hidden without stopping it.
                        child:SetAlpha(0)
                    end
                end
            end
        end
        if player then return player end
        -- Native minimaps construct nine Model children before addon children.
        -- Use that fallback only when every native slot still has that shape.
        for index = 1, 9 do
            local child = children[index]
            if not child or not child.GetObjectType or child:GetObjectType() ~= "Model" then return end
        end
        local candidate = children[9]
        if candidate.GetFacing then
            for index = 1, 8 do children[index]:SetAlpha(0) end
            return candidate
        end
    end
    function navigation.StyleMinimap()
        if not arrow then arrow = PlayerArrow() end
        if not arrow then return end
        local strata, level = Minimap:GetFrameStrata(), navigation.MinimapLevel("player")
        if arrow:GetFrameStrata() ~= strata then arrow:SetFrameStrata(strata) end
        if arrow:GetFrameLevel() < level then arrow:SetFrameLevel(level) end
    end
    function navigation.Heading()
        if not arrow then arrow = PlayerArrow() end
        if arrow and arrow.GetFacing then
            local ok, facing = pcall(arrow.GetFacing, arrow)
            -- This native model is fed every frame, unlike the run snapshot.
            if ok and Number(facing) then return facing end
        end
        arrow = nil
        local state = RunState()
        -- Both headings use native radians: north, counterclockwise.
        if state and Number(state.pf) then return state.pf, _G.AZS_RUN_UPDATED end
    end
    function navigation.UpdateMinimapPlayer(visible)
        -- Older clients paint the native arrows inside the map, ignoring the
        -- Model children's alpha and frame level. Redraw the native player art
        -- above our pins there; keep its live Model facing as the source.
        if not visible or not Minimap or type(Minimap.SetPlayerModel) == "function" then
            if playerOverlay then playerOverlay:Hide() end
            return
        end
        local facing = navigation.Heading()
        local width, height = T.GetLocalSize(Minimap)
        if not Number(facing) or not Number(width) or not Number(height) or width <= 0 or height <= 0 then
            if playerOverlay then playerOverlay:Hide() end
            return
        end
        if not playerOverlay then
            playerOverlay = CreateFrame("Frame", nil, Minimap)
            playerOverlay:EnableMouse(false)
            playerTexture = playerOverlay:CreateTexture(nil, "OVERLAY")
            playerTexture:SetTexture("Interface\\Minimap\\MinimapArrow")
            playerTexture:SetAllPoints(playerOverlay)
        end
        local strata, level = Minimap:GetFrameStrata(), navigation.MinimapLevel("player")
        if playerOverlay:GetFrameStrata() ~= strata then playerOverlay:SetFrameStrata(strata) end
        if playerOverlay:GetFrameLevel() ~= level then playerOverlay:SetFrameLevel(level) end
        local side = math.min(width, height)
        if not T.NearlyEqual(playerSide, side) or not T.NearlyEqual(playerFacing, facing) then
            -- Match the legacy renderer's native 33.6-pixel quad and rotating
            -- authored centre offset, both measured against its 140.8 basis.
            local scale, c, s = side / 140.8, math.cos(facing), math.sin(facing)
            playerOverlay:SetWidth(33.6 * scale)
            playerOverlay:SetHeight(33.6 * scale)
            playerOverlay:ClearAllPoints()
            playerOverlay:SetPoint(
                "CENTER",
                Minimap,
                "CENTER",
                (0.51 * c - 1.73 * s) * scale,
                (0.51 * s + 1.73 * c) * scale
            )
            c, s = c / 2, -s / 2
            playerTexture:SetTexCoord(
                0.5 - c - s,
                0.5 + s - c,
                0.5 - c + s,
                0.5 + s + c,
                0.5 + c - s,
                0.5 - s - c,
                0.5 + c + s,
                0.5 - s + c
            )
            playerSide, playerFacing = side, facing
        end
        playerOverlay:Show()
    end
end)
