-- Map geometry stays session-only. Native map coordinates are east/south;
-- world X/Y are north/west, respectively, in yards.
DFRL:NewMod("Navigation", 2, function()
    local navigation = {}
    DFRL.navigation = navigation
    local phases = { playing = true, choosing = true, paused = true, victory = true }
    local minimapLevels = { cache = 10, guardian = 11, party = 12, player = 13 }
    local identity, expected, realZone, arrow
    local playerOverlay, playerTexture, playerSide, playerFacing
    local points = {}
    local samples, seen, width, height = {}, {}, nil, nil
    local sampling, frameSample = false, {}
    local runSample = {}
    local liveSample, liveAdvertised = {}, false
    local capabilitiesRetry, positionRetry = {}, {}
    local projections, projectionRows, projectionCells = {}, {}, {}
    local projectionDirty, projectionPass = true, 0

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Id(value) return type(value) == "string" and value ~= "" end
    local function MapId(value)
        return Number(value) and value >= 0 and value <= 4294967295 and value == math.floor(value)
    end
    local function Coordinates(x, y) return Number(x) and Number(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 end
    local function ClearRetry(retry)
        retry.started, retry.delay = nil, nil
    end
    local function RetryReady(retry)
        if not retry.started then return true end
        local now = GetTime()
        if Number(now) and now >= retry.started and now - retry.started < retry.delay then return false end
        ClearRetry(retry)
        return true
    end
    local function RememberRetry(retry, failure)
        if
            type(failure) ~= "table"
            or not Id(failure.code)
            or not Id(failure.message)
            or failure.retryable ~= true
            or not Number(failure.retryAfterSeconds)
            or failure.retryAfterSeconds <= 0
        then
            return
        end
        local now = GetTime()
        if Number(now) then
            retry.started, retry.delay = now, failure.retryAfterSeconds
        end
    end
    local function ClearProjections()
        for x, row in pairs(projections) do
            for y, cell in pairs(row) do
                row[y] = nil
                cell.pass, cell.map, cell.getter, cell.selection, cell.u, cell.v = nil, nil, nil, nil, nil, nil
                table.insert(projectionCells, cell)
            end
            projections[x] = nil
            table.insert(projectionRows, row)
        end
        projectionDirty, projectionPass = true, projectionPass + 1
    end
    local function IndexProjections()
        if not projectionDirty then return end
        for _, list in pairs(points) do
            if type(list) == "table" then
                for _, point in ipairs(list) do
                    if type(point) == "table" and Number(point.x) and Number(point.y) then
                        local row = projections[point.x]
                        if not row then
                            row = table.remove(projectionRows) or {}
                            projections[point.x] = row
                        end
                        if not row[point.y] then row[point.y] = table.remove(projectionCells) or {} end
                    end
                end
            end
        end
        projectionDirty = false
    end
    function navigation.IsRunPhase(phase) return phases[phase] == true end
    function navigation.MinimapLevel(kind) return Minimap:GetFrameLevel() + minimapLevels[kind] end
    function navigation.MinimapSize(minimum)
        minimum = minimum or 0
        local w, h = frameSample.minimapWidth, frameSample.minimapHeight
        if sampling and Number(w) and Number(h) and w > minimum and h > minimum then return w, h end
        if sampling then
            frameSample.minimapWidth, frameSample.minimapHeight = nil, nil
        end
        w, h = T.GetLocalSize(Minimap)
        -- Cache usable geometry only; missing/tiny native bounds can recover
        -- later in this same callback without waiting for another frame.
        if sampling and Number(w) and Number(h) and w > minimum and h > minimum then
            frameSample.minimapWidth, frameSample.minimapHeight = w, h
        end
        return w, h
    end
    local function ClearSample()
        for key in pairs(frameSample) do
            frameSample[key] = nil
        end
    end
    function navigation.BeginSample()
        -- Guides and pins share only this synchronous controller pass. Usable
        -- values stay fresh; typed failures retain only their retry deadline.
        ClearSample()
        projectionPass = projectionPass + 1
        sampling = true
    end
    function navigation.EndSample() sampling = false end
    function navigation.WithSample(callback)
        navigation.BeginSample()
        local ok, failure = pcall(callback)
        navigation.EndSample()
        if not ok then error(failure) end
    end
    local function ResetCalibration()
        ClearProjections()
        identity, expected, realZone, arrow = nil, nil, nil, nil
        samples, seen, width, height = {}, {}, nil, nil
    end
    function navigation.Reset()
        ResetCalibration()
        ClearSample()
        ClearRetry(capabilitiesRetry)
        ClearRetry(positionRetry)
    end
    function navigation.SetPoints(key, list)
        if points[key] ~= list then
            frameSample.metricRead = nil
            ClearProjections()
        end
        points[key] = list
    end
    function navigation.Phase()
        if sampling and frameSample.phaseRead then return frameSample.phase end
        local phase
        if type(_G.AZS_GetPhase) == "function" then
            local ok, value = pcall(_G.AZS_GetPhase)
            if ok then phase = value end
        end
        if sampling then
            frameSample.phaseRead, frameSample.phase = true, phase
        end
        return phase
    end
    local function ReadLivePosition()
        if not RetryReady(capabilitiesRetry) then return nil, true end
        local capabilities = _G.AZS_GetMeterCapabilities
        if type(capabilities) ~= "function" then return nil, liveAdvertised end
        local ok, supported, failure = pcall(capabilities)
        if ok and supported == nil then RememberRetry(capabilitiesRetry, failure) end
        if
            not ok
            or failure ~= nil
            or type(supported) ~= "table"
            or supported.apiVersion ~= 1
            or type(supported.features) ~= "table"
            or type(supported.features.liveInstancePosition) ~= "boolean"
        then
            -- An unreadable advertisement does not prove the old path is safe.
            liveAdvertised = true
            return nil, true
        end
        if not supported.features.liveInstancePosition then return nil, liveAdvertised end
        liveAdvertised = true
        if not RetryReady(positionRetry) then return nil, true end
        if type(_G.AZS_GetPlayerPosition) ~= "function" then return nil, true end
        local read, position, problem = pcall(_G.AZS_GetPlayerPosition)
        if read and position == nil then RememberRetry(positionRetry, problem) end
        if
            not read
            or problem ~= nil
            or type(position) ~= "table"
            or position.apiVersion ~= 1
            or not MapId(position.mapId)
            or not Id(position.spaceId)
            or not Id(position.sampleId)
            or not Number(position.x)
            or not Number(position.y)
            or not Number(position.z)
            or not Number(position.facing)
            or position.facing < 0
            or position.facing >= math.pi * 2
            or (position.runId ~= nil and not Id(position.runId))
        then
            return nil, true
        end
        return position, true
    end
    local function LivePosition()
        if sampling and frameSample.liveRead then return frameSample.live, frameSample.liveSupported end
        local position, supported = ReadLivePosition()
        if sampling then
            if position then
                liveSample.mapId, liveSample.spaceId, liveSample.sampleId =
                    position.mapId, position.spaceId, position.sampleId
                liveSample.x, liveSample.y, liveSample.z = position.x, position.y, position.z
                liveSample.facing, liveSample.runId = position.facing, position.runId
                position = liveSample
            end
            frameSample.liveRead, frameSample.live, frameSample.liveSupported = true, position, supported
        end
        return position, supported
    end
    local function MatchesLivePosition(target, position)
        return position
            and Id(target.runId)
            and target.runId == position.runId
            and MapId(target.mapId)
            and target.mapId == position.mapId
            and Id(target.spaceId)
            and target.spaceId == position.spaceId
            and Number(target.x)
            and Number(target.y)
    end
    function navigation.IsCurrentDestination(target)
        if type(target) ~= "table" then return false end
        if target.mapSelection then return true end
        local position, supported = LivePosition()
        return not supported or (MatchesLivePosition(target, position) and true or false)
    end
    local function LiveDelta(target)
        local position, supported = LivePosition()
        if not supported then return false end
        if not MatchesLivePosition(target, position) then return true end
        local east, north = position.y - target.y, target.x - position.x
        local distance = math.sqrt(east * east + north * north)
        if Number(east) and Number(north) and Number(distance) then return true, east, north, distance end
        return true
    end
    local function ReadRunState()
        if not navigation.IsRunPhase(navigation.Phase()) then return end
        local state = _G.AZS_RUN
        if type(state) == "table" and Number(_G.AZS_RUN_UPDATED) then return state, _G.AZS_RUN_UPDATED end
    end
    local function RunState()
        if sampling and frameSample.runRead then return frameSample.run, frameSample.runStamp end
        local state, stamp = ReadRunState()
        if sampling then
            if state then
                runSample.px, runSample.py, runSample.pf = state.px, state.py, state.pf
                state = runSample
            end
            frameSample.runRead, frameSample.run, frameSample.runStamp = true, state, stamp
        end
        return state, stamp
    end
    local function ReadContext()
        if not navigation.IsRunPhase(navigation.Phase()) then return end
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
            ResetCalibration()
            identity, realZone = current, name
        end
        return zone
    end
    local function Context()
        if sampling and frameSample.contextRead then return frameSample.context end
        local zone = ReadContext()
        if sampling then
            frameSample.contextRead, frameSample.context = true, zone
        end
        return zone
    end
    local function MapInfo()
        if sampling and frameSample.mapRead then
            return frameSample.mapName, frameSample.mapWidth, frameSample.mapHeight
        end
        local name, w, h
        if type(GetMapInfo) == "function" then
            local ok, mapName, mapWidth, mapHeight = pcall(GetMapInfo)
            if ok then
                name, w, h = mapName, mapWidth, mapHeight
            end
        end
        if sampling then
            frameSample.mapRead = true
            frameSample.mapName, frameSample.mapWidth, frameSample.mapHeight = name, w, h
        end
        return name, w, h
    end
    local function Selection()
        if sampling and frameSample.selectionRead then return frameSample.selection end
        local name = MapInfo()
        if type(name) ~= "string" or name == "" then return end
        local continent = type(GetCurrentMapContinent) == "function" and GetCurrentMapContinent() or nil
        local zone = type(GetCurrentMapZone) == "function" and GetCurrentMapZone() or nil
        local selected = name .. ":" .. tostring(continent) .. ":" .. tostring(zone)
        if sampling then
            frameSample.selectionRead, frameSample.selection = true, selected
        end
        return selected
    end
    local function ReadPosition()
        if not Context() or type(GetPlayerMapPosition) ~= "function" then return end
        local selected = Selection()
        local browsing = WorldMapFrame and WorldMapFrame:IsShown()
        if not browsing and (not expected or selected ~= expected) then
            if type(SetMapToCurrentZone) ~= "function" then return end
            local ok = pcall(SetMapToCurrentZone)
            if not ok then return end
            frameSample.mapRead, frameSample.selectionRead = nil, nil
            projectionPass = projectionPass + 1
            selected = Selection()
            expected = selected
        end
        -- Browsing another map must never lend its coordinates to this run.
        if not expected or selected ~= expected then return end
        local ok, x, y = pcall(GetPlayerMapPosition, "player")
        if ok and Coordinates(x, y) and (x ~= 0 or y ~= 0) then return x, y end
    end
    function navigation.Position()
        if sampling and frameSample.positionRead then return frameSample.x, frameSample.y end
        local x, y = ReadPosition()
        if sampling then
            frameSample.positionRead, frameSample.x, frameSample.y = true, x, y
        end
        return x, y
    end
    function navigation.UnitMapPosition(unit)
        -- The player read confirms the current-zone sheet without moving an
        -- open world map. Remote UVs are meaningful only on that same sheet.
        if not navigation.Position() or type(GetPlayerMapPosition) ~= "function" then return end
        local ok, x, y = pcall(GetPlayerMapPosition, unit)
        if ok and Coordinates(x, y) and (x ~= 0 or y ~= 0) then return x, y, Selection() end
    end
    local function ProjectWorld(map, x, y)
        local getter = GetWorldLocMapPosition
        if type(getter) ~= "function" then return end
        local cell, selected
        if sampling then
            IndexProjections()
            local row = projections[x]
            cell = row and row[y]
            if cell then selected = Selection() end
            if
                cell
                and selected
                and cell.pass == projectionPass
                and cell.map == map
                and cell.getter == getter
                and cell.selection == selected
            then
                return cell.u, cell.v
            end
        end
        -- Projection also depends on a native catalog/direct-area selection
        -- with no complete Lua revision. Reuse only within this callback.
        local ok, u, v = pcall(getter, map, x, y)
        if ok and Coordinates(u, v) and (u ~= 0 or v ~= 0) then
            if cell and selected then
                cell.pass, cell.map, cell.getter, cell.selection = projectionPass, map, getter, selected
                cell.u, cell.v = u, v
            end
            return u, v
        end
    end
    local function Project(target)
        local zone = Context()
        if not zone or type(target) ~= "table" then return end
        if target.mapSelection and target.mapSelection ~= Selection() then return end
        if type(GetWorldLocMapPosition) == "function" and Number(target.x) and Number(target.y) then
            local x, y = ProjectWorld(zone.map, target.x, target.y)
            if x then return x, y end
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
    local function WorldPoint(map, x, y) return ProjectWorld(map, x, y) end
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
    local function ReadMetric()
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
    function navigation.Metric()
        if sampling and frameSample.metricRead then return frameSample.width, frameSample.height end
        local w, h = ReadMetric()
        if sampling then
            frameSample.metricRead, frameSample.width, frameSample.height = true, w, h
        end
        return w, h
    end
    local function ReadAspect()
        local _, w, h = MapInfo()
        if Number(w) and Number(h) and w > 0 and h > 0 then return w / h end
        if WorldMapDetailFrame and WorldMapDetailFrame.GetWidth and WorldMapDetailFrame.GetHeight then
            local w, h = WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight()
            if Number(w) and Number(h) and w > 0 and h > 0 then return w / h end
        end
        return 1
    end
    local function Aspect()
        if sampling and frameSample.aspect then return frameSample.aspect end
        local aspect = ReadAspect()
        if sampling then frameSample.aspect = aspect end
        return aspect
    end
    local function MapDelta(target)
        if type(target) ~= "table" then return end
        local x, y = navigation.Position()
        if not x then return end
        if target.mapSelection and target.mapSelection ~= Selection() then return end
        local targetX, targetY = target.mx, target.my
        if type(GetWorldLocMapPosition) == "function" then
            local projectedX, projectedY = Project(target)
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
        if not navigation.IsRunPhase(navigation.Phase()) then return end
        if not target.mapSelection then
            local supported, east, north, distance = LiveDelta(target)
            if supported then return east, north, distance, east ~= nil end
        end
        local state, stamp = RunState()
        if state and Number(state.px) and Number(state.py) and Number(target.x) and Number(target.y) then
            -- Official world coordinates work without a map sheet or calibration,
            -- including instances. The stamp identifies sampled HUD presentation.
            local east, north = state.py - target.y, target.x - state.px
            return east, north, math.sqrt(east * east + north * north), true, stamp
        end
        return MapDelta(target)
    end
    function navigation.GuideDelta(target)
        if type(target) ~= "table" or not navigation.IsRunPhase(navigation.Phase()) then return end
        if not target.mapSelection then
            local supported, east, north, distance = LiveDelta(target)
            if supported then return east, north, distance, east ~= nil end
        end
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
            for index = 1, 8 do
                children[index]:SetAlpha(0)
            end
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
    local function ReadHeading()
        local position, supported = LivePosition()
        if supported then return position and position.facing end
        if not arrow then arrow = PlayerArrow() end
        if arrow and arrow.GetFacing then
            local ok, facing = pcall(arrow.GetFacing, arrow)
            -- This native model is fed every frame, unlike the run snapshot.
            if ok and Number(facing) then return facing end
        end
        arrow = nil
        local state, stamp = RunState()
        -- Both headings use native radians: north, counterclockwise.
        if state and Number(state.pf) then return state.pf, stamp end
    end
    function navigation.Heading()
        if sampling and frameSample.headingRead then return frameSample.facing, frameSample.headingStamp end
        local facing, stamp = ReadHeading()
        if sampling then
            frameSample.headingRead, frameSample.facing, frameSample.headingStamp = true, facing, stamp
        end
        return facing, stamp
    end
    function navigation.UpdateMinimapPlayer(visible)
        -- Older clients paint the native arrows inside the map, ignoring the
        -- Model children's alpha and frame level. Redraw the native player art
        -- above our pins there; keep its live Model facing as the source.
        if not visible or not Minimap or type(Minimap.SetPlayerModel) == "function" then
            if playerOverlay and playerOverlay:IsShown() then playerOverlay:Hide() end
            return
        end
        local facing = navigation.Heading()
        local width, height = navigation.MinimapSize()
        if not Number(facing) or not Number(width) or not Number(height) or width <= 0 or height <= 0 then
            if playerOverlay and playerOverlay:IsShown() then playerOverlay:Hide() end
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
        local resized = not T.NearlyEqual(playerSide, side)
        local turned = not T.NearlyEqual(playerFacing, facing)
        if resized or turned then
            -- Match the legacy renderer's native 33.6-pixel quad and rotating
            -- authored centre offset, both measured against its 140.8 basis.
            local scale, c, s = side / 140.8, math.cos(facing), math.sin(facing)
            if resized then
                playerOverlay:SetWidth(33.6 * scale)
                playerOverlay:SetHeight(33.6 * scale)
            end
            playerOverlay:SetPoint(
                "CENTER",
                Minimap,
                "CENTER",
                (0.51 * c - 1.73 * s) * scale,
                (0.51 * s + 1.73 * c) * scale
            )
            if turned then
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
            end
            playerSide, playerFacing = side, facing
        end
        if not playerOverlay:IsShown() then playerOverlay:Show() end
    end
end)
