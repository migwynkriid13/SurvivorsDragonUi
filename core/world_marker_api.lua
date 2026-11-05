-- Native version-one world anchors: docs/AzerothSurvivors-Addon-API.md.
-- Uses existing waypoint artwork and its controller; no nameplate/entity inference.
setfenv(1, DFRL:GetEnv())

function DFRL.tools.NewWorldMarkerApi(navigation)
    local api = {}
    local DISCOVERY_INTERVAL, TRANSIENT_RETRY, FAILURE_RETRY = 0.2, 0.1, 0.5
    local NATIVE_PLATE_RANGE = 20
    local markerKinds = { "cache", "guardian", "boss", "finalBoss", "downedPartyMember", "elite" }
    local plateKinds = { guardian = "guardian", boss = "boss", finalBoss = "final", elite = "elite" }
    local distant = { kinds = {}, views = {}, pool = {}, range = NATIVE_PLATE_RANGE }
    local state = {
        records = {},
        staging = {},
        requests = {},
        indices = {},
        points = {},
        markers = {},
        pool = {},
        cachePool = {},
        seen = {},
        cursors = {},
        choices = {},
    }
    local path = DFRL:GetInfoOrCons("tex") .. "waypoint\\"
    local beamTop = { z = 6 }
    local reviveArt = path .. "KyrianWake.blp"
    local poolArt = DFRL:GetInfoOrCons("tex") .. "tally\\AffordableGlow.blp"
    local styles = {
        cache = {
            key = "worldCacheIcons",
            mode = "worldCacheIconMode",
            distance = "worldCacheIconDistance",
            art = path .. "Chest.blp",
            lightArt = path .. "CacheBeam.blp",
            state = "present",
            attachment = "position",
            size = 22.4,
            offset = { z = 4 },
            padding = 0,
            crop = { 0, 1, 0, 1 },
        },
        guardian = {
            key = "worldGuardianIcons",
            mode = "worldGuardianIconMode",
            distance = "worldGuardianIconDistance",
            state = "alive",
            attachment = "overhead",
            size = 27.2,
            padding = 6,
            crop = { 0, 65 / 128, 0, 65 / 128 },
        },
        elite = {
            key = "worldEliteIcons",
            mode = "worldEliteIconMode",
            distance = "worldEliteIconDistance",
            art = path .. "EliteWorldStar.blp",
            state = "alive",
            attachment = "overhead",
            size = 25.6,
            padding = 6,
            crop = { 0, 1, 0, 1 },
        },
        boss = {
            key = "worldBossIcons",
            mode = "worldBossIconMode",
            distance = "worldBossIconDistance",
            state = "alive",
            attachment = "overhead",
            size = 25.6,
            padding = 6,
        },
        downedPartyMember = {
            key = "worldPartyIcons",
            art = path .. "FallenAlly.blp",
            lightArt = reviveArt,
            state = "downed",
            attachment = "position",
            size = 29.12,
            offset = { z = 5 },
            padding = 0,
            crop = { 0, 1, 0, 1 },
        },
    }
    styles.finalBoss = styles.boss
    local projectionStates = {
        onScreen = true,
        offscreen = true,
        behindCamera = true,
        clipped = true,
        notReady = true,
        unavailable = true,
        expired = true,
        unknownAnchor = true,
        worldChanged = true,
    }
    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Id(value) return type(value) == "string" and value ~= "" end
    local function Integer(value, minimum, maximum)
        return Number(value) and value >= minimum and value <= maximum and value == math.floor(value)
    end
    local function Array(value, maximum)
        if type(value) ~= "table" then return end
        local count = 0
        for key in pairs(value) do
            if not Integer(key, 1, maximum) then return end
            count = count + 1
        end
        for index = 1, count do
            if value[index] == nil then return end
        end
        return count
    end
    local function StringList(value)
        local count = Array(value, 256)
        if not count then return end
        for index = 1, count do
            if not Id(value[index]) then return end
        end
        return count
    end
    local function Contains(list, count, value)
        for index = 1, count do
            if list[index] == value then return true end
        end
        return false
    end
    local function Trim(list, count)
        for index = table.getn(list), count + 1, -1 do
            list[index] = nil
        end
        if table.setn then table.setn(list, count) end
    end
    local function Read(name, first, second, third)
        local getter = _G[name]
        if type(getter) ~= "function" then return end
        local ok, value, failure
        if third ~= nil then
            ok, value, failure = pcall(getter, first, second, third)
        elseif first ~= nil then
            ok, value, failure = pcall(getter, first)
        else
            ok, value, failure = pcall(getter)
        end
        if ok and failure == nil and type(value) == "table" then return value end
        return nil, type(failure) == "table" and failure.code or nil
    end
    local function HideWorldLight(marker)
        local light = marker.light
        if light and light.shown then
            light.beam:Hide()
            if light.pool and light.art ~= reviveArt then light.pool:Hide() end
            light.shown = nil
        end
    end
    local function HideMarker(marker)
        HideWorldLight(marker)
        if marker:IsShown() then marker:Hide() end
        marker.fadeStarted, marker.fadeTarget, marker.fadeFrom = nil, nil, nil
        if marker.alpha and marker.alpha ~= 1 then marker:SetAlpha(1) end
        marker.alpha = 1
    end
    local function HideAll()
        for _, marker in pairs(state.markers) do
            HideMarker(marker)
        end
        for _, view in pairs(distant.views) do
            if view.style.visual:IsShown() then view.style.visual:Hide() end
        end
    end
    local function RecyclePlate(id, view)
        if view.style.visual:IsShown() then view.style.visual:Hide() end
        view.drawPass, distant.views[id] = nil, nil
        table.insert(distant.pool, view)
    end
    local function RequestRoster(wanted)
        local sct = DFRL.sct
        if sct and sct.RequestDistantNameplateRoster then sct.RequestDistantNameplateRoster(wanted) end
    end
    local function Recycle(id, marker)
        HideMarker(marker)
        marker.x, marker.y, marker.kind, marker.ready = nil, nil, nil, nil
        local light = marker.light
        if light then
            light.x, light.y = nil, nil
        end
        state.markers[id] = nil
        table.insert(light and light.pool and state.cachePool or state.pool, marker)
    end
    local function Release()
        if not state.handler then return true end
        local now = GetTime()
        if state.releaseAt and now >= state.releaseStarted and now < state.releaseAt then return false end
        local ok, result, failure = pcall(state.unregister, state.handler)
        if not ok or result == false or failure ~= nil then
            state.releaseStarted, state.releaseAt = now, now + FAILURE_RETRY
            return false
        end
        state.handler, state.unregister = nil, nil
        state.releaseStarted, state.releaseAt = nil, nil
        return true
    end
    local function ClearMap(map)
        for key in pairs(map) do
            map[key] = nil
        end
    end
    local function ClearCatalog()
        HideAll()
        for id, marker in pairs(state.markers) do
            Recycle(id, marker)
        end
        for id, view in pairs(distant.views) do
            RecyclePlate(id, view)
        end
        Trim(state.records, 0)
        Trim(state.staging, 0)
        Trim(state.requests, 0)
        Trim(state.indices, 0)
        Trim(state.points, 0)
        ClearMap(state.seen)
        ClearMap(state.cursors)
        state.world, state.stream = nil, nil
        state.mapId, state.runId, state.spaceId, state.clock = nil, nil, nil, nil
        state.discoveryAt, state.discoveryStarted, state.discoveryFailures = nil, nil, nil
    end
    function api.Reset()
        RequestRoster(false)
        if not state.reset then
            state.session, state.enabled, state.retire = nil, false, nil
            ClearCatalog()
            state.query, state.kinds, state.capabilities = nil, nil, nil
            state.queryCache, state.queryParty, state.queryPlates = nil, nil, nil
            state.active, state.reset = false, true
        end
        -- Failure backoff can be installed after Reset. Off/hidden cleanup
        -- still clears it, and an unfinished release keeps its original retry.
        state.configFailures = nil
        state.retryAt, state.retryStarted = nil, nil
        Release() -- A partial/failed release is retried by the existing controller.
    end
    local function Context(value, position)
        return value.mapId == position.mapId and value.spaceId == position.spaceId and value.runId == position.runId
    end
    local function IconWanted(kind)
        local style = styles[kind]
        return style and style.key and state.choices[style.key]
    end
    local function PlateWanted(kind)
        return state.requestPlates and distant.range > NATIVE_PLATE_RANGE and distant.kinds[kind]
    end
    local function Wanted(kind) return IconWanted(kind) or PlateWanted(kind) end
    local function DistanceVisible(kind, distance)
        local style = styles[kind]
        local mode = style.mode and state.choices[style.mode] or "always"
        if mode == "always" then return true end
        if not state.capabilities.playerDistanceMetrics or not Number(distance) or distance < 0 then return false end
        local cutoff = state.choices[style.distance]
        return (mode == "near" and distance <= cutoff) or (mode == "far" and distance > cutoff)
    end
    local function UpdateVisibility(marker, visible, now, animate)
        if not animate or state.choices.performanceMode then
            if not visible then
                HideMarker(marker)
                return
            end
            marker.fadeStarted, marker.fadeTarget, marker.fadeFrom = nil, nil, nil
            if marker.alpha ~= 1 then marker:SetAlpha(1) end
            marker.alpha = 1
            if not marker:IsShown() then marker:Show() end
            return
        end
        local target = visible and 1 or 0
        if not visible and not marker:IsShown() then return end
        if visible and not marker:IsShown() then
            marker:SetAlpha(0)
            marker.alpha = 0
            marker:Show()
        end
        if marker.fadeTarget ~= target then
            marker.fadeStarted, marker.fadeFrom, marker.fadeTarget = now, marker.alpha or 1, target
        end
        if marker.fadeStarted then
            local progress = math.max(0, math.min(1, (now - marker.fadeStarted) / 0.12))
            local alpha = marker.fadeFrom + (target - marker.fadeFrom) * progress
            if marker.alpha ~= alpha then marker:SetAlpha(alpha) end
            marker.alpha = alpha
            if progress == 1 then
                marker.fadeStarted = nil
                if target == 0 then HideMarker(marker) end
            end
        end
    end
    local function Marker(record)
        local style = styles[record.kind]
        local marker = state.markers[record.anchorId]
        if not marker then
            if record.kind == "cache" then
                marker = table.remove(state.cachePool) or table.remove(state.pool)
            else
                marker = table.remove(state.pool) or table.remove(state.cachePool)
            end
            if not marker then
                marker = CreateFrame("Frame", nil, WorldFrame)
                marker:Hide()
                marker:SetFrameStrata("LOW")
                marker:EnableMouse(false)
                marker.icon = marker:CreateTexture(nil, "ARTWORK")
                marker.icon:SetAllPoints(marker)
            end
            state.markers[record.anchorId] = marker
        end
        local size = style.size
        if marker.size ~= size then
            marker:SetWidth(size)
            marker:SetHeight(size)
            marker.size = size
        end
        if marker.art ~= style.art or not marker.ready then
            local ok, result = pcall(marker.icon.SetTexture, marker.icon, style.art)
            marker.ready = ok and result ~= false
            if marker.ready then marker.icon:SetTexCoord(unpack(style.crop)) end
            marker.art = style.art
        end
        if marker.kind ~= record.kind then marker.kind = record.kind end
        return marker
    end
    local function CacheAffordable()
        if not state.choices.worldCacheAffordableOnly then return true end
        local run = _G.AZS_RUN
        return type(run) == "table"
            and Number(_G.AZS_RUN_UPDATED)
            and Number(run.gold)
            and run.gold >= 0
            and Number(run.chest)
            and run.chest >= 0
            and run.gold >= run.chest
    end
    local function Shown(frame)
        if not frame then return false end
        local visible = frame:IsVisible()
        return visible == true or visible == 1
    end
    local function UpdatePlateOptions()
        local range = DFRL.display.Get("nameplateDistance") or NATIVE_PLATE_RANGE
        local guardians = DFRL.display.Get("nameplatesShowGuardians") ~= false
        local bosses = DFRL.display.Get("nameplatesShowBosses") ~= false
        local elites = DFRL.display.Get("nameplatesShowElites") ~= false
        distant.namesOnly = DFRL.display.Get("nameplatesNamesOnly")
        distant.fontSize = DFRL.display.Get("nameplateFontSize")
        local kinds = distant.kinds
        if kinds.guardian ~= guardians or kinds.boss ~= bosses or kinds.elite ~= elites then
            kinds.guardian, kinds.boss, kinds.finalBoss, kinds.elite = guardians, bosses, bosses, elites
            state.queryDirty = true
        end
        local wanted = range > NATIVE_PLATE_RANGE and (guardians or bosses or elites)
        if distant.wanted ~= wanted then state.queryDirty = true end
        distant.range, distant.wanted = range, wanted
    end
    function api.UpdateOptions()
        UpdatePlateOptions()
        local bossIcon = DFRL.display.BossIcon()
        styles.boss.art, styles.boss.crop = bossIcon.world, bossIcon.crop
        styles.guardian.art = DFRL.display.GuardianIcon()
        local choices = state.choices
        local visibilityChanged = false
        for _, kind in ipairs(markerKinds) do
            if kind ~= "finalBoss" then
                local style = styles[kind]
                local enabled = DFRL.display.Get(style.key)
                if choices[style.key] ~= enabled then
                    choices[style.key] = enabled
                    visibilityChanged = true
                end
                if style.mode then
                    choices[style.mode] = DFRL.display.Get(style.mode)
                    choices[style.distance] = DFRL.display.Get(style.distance)
                end
            end
        end
        state.encounterIcons = choices.worldBossIcons or choices.worldGuardianIcons or choices.worldEliteIcons
        local affordable = DFRL.display.Get("worldCacheAffordableOnly")
        if visibilityChanged or choices.worldCacheAffordableOnly ~= affordable then state.queryDirty = true end
        choices.worldCacheAffordableOnly = affordable
        choices.performanceMode = DFRL.display.Get("performanceMode")
        if visibilityChanged then
            local used = 0
            for index = 1, table.getn(state.records) do
                local record = state.records[index]
                local marker = state.markers[record.anchorId]
                if marker and not IconWanted(record.kind) then Recycle(record.anchorId, marker) end
                if Wanted(record.kind) then
                    used = used + 1
                    state.records[used], state.points[used] = record, state.points[index]
                end
            end
            Trim(state.records, used)
            Trim(state.points, used)
            for _, record in ipairs(state.staging) do
                if record.kind and not Wanted(record.kind) then
                    record.anchorId, record.kind, record.attachment, record.unitId = nil, nil, nil, nil
                end
            end
        end
        if
            visibilityChanged
            and not choices.worldCacheIcons
            and not state.encounterIcons
            and not choices.worldPartyIcons
            and not distant.wanted
        then
            state.active = false
            HideAll()
        end
    end
    local function Projection(size, sample, clock)
        local projection, failure = Read("AZS_ProjectWorldAnchors", state.requests)
        if failure == "STREAM_CHANGED" then return nil, failure end
        if
            not projection
            or projection.apiVersion ~= 1
            or projection.frameCurrent ~= true
            or not Id(projection.worldId)
            or not Id(projection.streamId)
            or not Id(projection.cameraSampleId)
            or not Number(projection.clockSeconds)
            or projection.clockSeconds < 0
            or (sample and sample ~= projection.cameraSampleId)
            or (clock and clock ~= projection.clockSeconds)
            or Array(projection.entries, size) ~= size
        then
            return
        end
        if
            projection.worldId ~= state.world
            or projection.streamId ~= state.stream
            or (state.clock and projection.clockSeconds < state.clock)
        then
            return nil, "STREAM_CHANGED"
        end
        return projection
    end
    local function SampleWorldLights(total, sample, clock)
        local first, top = 1, false
        while first <= total do
            local size = 0
            while first <= total and size < state.capabilities.maxProjectionsPerCall do
                local record, point = state.records[first], state.points[first]
                if styles[record.kind].lightArt and point and point.visible then
                    size = size + 1
                    local request = state.requests[size] or {}
                    request.anchorId, request.attachment = record.anchorId, record.attachment
                    request.offset = top and beamTop or nil
                    state.requests[size], state.indices[size] = request, first
                    if not top then
                        point.lightYard, point.lightHeight = nil, nil
                    end
                    top = not top
                end
                if not top then first = first + 1 end
            end
            Trim(state.requests, size)
            Trim(state.indices, size)
            if size > 0 then
                local projection, failure = Projection(size, sample, clock)
                if not projection then return nil, failure end
                for index = 1, size do
                    local entry, request = projection.entries[index], state.requests[index]
                    if
                        type(entry) ~= "table"
                        or entry.anchorId ~= request.anchorId
                        or entry.attachment ~= request.attachment
                        or not projectionStates[entry.state]
                    then
                        return
                    end
                    if entry.state == "worldChanged" then return nil, "STREAM_CHANGED" end
                    local recordIndex = state.indices[index]
                    local style = styles[state.records[recordIndex].kind]
                    if entry.state == "onScreen" and entry.entityState == style.state then
                        local point = state.points[recordIndex]
                        if not Number(entry.x) or not Number(entry.y) then return end
                        if request.offset then
                            if point.lightYard then point.lightHeight = entry.y - point.lightY end
                        elseif Number(entry.uiUnitsPerYard) and entry.uiUnitsPerYard > 0 then
                            point.lightX, point.lightY, point.lightYard = entry.x, entry.y, entry.uiUnitsPerYard
                        end
                    end
                end
            end
        end
        return true
    end
    local function DrawWorldLight(marker, point, art, alpha)
        local yard, height = point.lightYard, point.lightHeight
        if not yard or not Number(height) or height <= 1 then
            HideWorldLight(marker)
            return
        end
        local isRevive = art == reviveArt
        local light = marker.light
        if not light then
            local beam = marker:CreateTexture(nil, "BORDER")
            beam:Hide()
            beam:SetBlendMode("ADD")
            light = { beam = beam }
            marker.light = light
        end
        if light.art ~= art then
            HideWorldLight(marker)
            light.art, light.beamReady = art, nil
            light.x, light.y, light.yard = nil, nil, nil
            if isRevive then
                light.beam:SetVertexColor(1, 1, 1, 1)
            else
                light.beam:SetVertexColor(1, 0.78, 0.38, 1)
            end
        end
        if not isRevive then
            if not light.pool then
                local pool = marker:CreateTexture(nil, "BACKGROUND")
                pool:Hide()
                pool:SetBlendMode("ADD")
                pool:SetVertexColor(1, 0.78, 0.38, 0.68)
                light.pool = pool
            end
            if not light.poolReady then
                local ok, result = pcall(light.pool.SetTexture, light.pool, poolArt)
                light.poolReady = ok and result ~= false
            end
            if not light.poolReady then return end
        end
        if not light.beamReady then
            local ok, result = pcall(light.beam.SetTexture, light.beam, art)
            light.beamReady = ok and result ~= false
        end
        if not light.beamReady then return end
        local bottom = point.lightY - (isRevive and height * 0.16 or 0)
        if light.x ~= point.lightX or light.y ~= bottom then
            if not isRevive then light.pool:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", point.lightX, bottom) end
            light.beam:SetPoint("BOTTOM", WorldFrame, "BOTTOMLEFT", point.lightX, bottom)
            light.x, light.y = point.lightX, bottom
        end
        if light.yard ~= yard or light.height ~= height then
            if isRevive then
                light.beam:SetWidth(4.4 * yard)
                light.beam:SetHeight(height * 1.16)
            else
                local rise = math.min(1, height / (beamTop.z * yard))
                light.pool:SetWidth(3.4 * yard)
                light.pool:SetHeight(3.4 * yard * math.max(0.25, math.sqrt(1 - rise * rise)))
                light.beam:SetWidth(2.4 * yard)
                light.beam:SetHeight(height)
            end
            light.yard, light.height = yard, height
        end
        if not isRevive and light.poolAlpha ~= alpha then
            light.pool:SetAlpha(alpha)
            light.poolAlpha = alpha
        end
        if light.alpha ~= alpha then
            light.beam:SetAlpha(alpha)
            light.alpha = alpha
        end
        if not light.shown then
            if not isRevive then light.pool:Show() end
            light.beam:Show()
            light.shown = true
        end
    end
    local function SamplePlateDistances(total, sample, clock)
        -- Use the feet for the native range boundary and the head for drawing.
        -- Both projections must come from this same post-camera frame.
        local first = 1
        while first <= total do
            local size = 0
            while first <= total and size < state.capabilities.maxProjectionsPerCall do
                local point = state.points[first]
                if point and point.plate then
                    size = size + 1
                    local request = state.requests[size] or {}
                    request.anchorId = state.records[first].anchorId
                    request.attachment, request.offset = "position", nil
                    state.requests[size], state.indices[size] = request, first
                end
                first = first + 1
            end
            Trim(state.requests, size)
            Trim(state.indices, size)
            if size > 0 then
                local projection, failure = Projection(size, sample, clock)
                if not projection then return nil, failure end
                for index = 1, size do
                    local entry = projection.entries[index]
                    if
                        type(entry) ~= "table"
                        or entry.anchorId ~= state.requests[index].anchorId
                        or entry.attachment ~= "position"
                        or not projectionStates[entry.state]
                    then
                        return
                    end
                    if entry.state == "worldChanged" then return nil, "STREAM_CHANGED" end
                    local distance = entry.playerDistance
                    state.points[state.indices[index]].plate = entry.state == "onScreen"
                        and entry.entityState == "alive"
                        and Number(distance)
                        and distance > NATIVE_PLATE_RANGE
                        and distance <= distant.range
                end
            end
        end
        return true
    end
    local function DrawPlate(unit, point)
        local style = T.NameplateStyle
        local view = distant.views[unit.id]
        if not view then
            view = table.remove(distant.pool) or style.CreateProjected()
            distant.views[unit.id] = view
        end
        if view.drawPass == state.drawPass then return end
        style.UpdateProjected(
            view,
            unit,
            point.x,
            point.plateY,
            distant.namesOnly,
            distant.fontSize,
            state.choices.performanceMode
        )
        view.drawPass = state.drawPass
    end
    local function Project()
        if not state.enabled or not state.world or not state.active then return true end
        if not Shown(WorldFrame) or not Shown(UIParent) then
            HideAll()
            return true
        end
        -- Projection already validates this frame's world epoch. The shared
        -- discovery reader checks map/run/space without another player getter per frame.
        local sample, clock, total = nil, nil, table.getn(state.records)
        local lightOnScreen, allyOnScreen = false, false
        local first = 1
        local cacheVisible = CacheAffordable()
        local sct = DFRL.sct
        local drawPlates = state.hasPlateQuery and state.requestPlates and sct.EnemyNameplatesVisible()
        -- Validate every batch before showing any visual. Reuse result slots.
        while first <= total do
            local size = 0
            while first <= total and size < state.capabilities.maxProjectionsPerCall do
                local record = state.records[first]
                record.plateUnit = drawPlates
                    and PlateWanted(record.kind)
                    and record.unitId
                    and sct.DistantNameplateUnit(record.unitId, plateKinds[record.kind])
                if
                    record.plateUnit
                    or (
                        IconWanted(record.kind)
                        and (record.kind ~= "cache" or cacheVisible)
                        and (record.kind ~= "downedPartyMember" or state.requestParty)
                    )
                then
                    size = size + 1
                    local request = state.requests[size] or {}
                    request.anchorId, request.attachment = record.anchorId, record.attachment
                    request.offset = styles[record.kind].offset
                    state.requests[size], state.indices[size] = request, first
                else
                    local point = state.points[first]
                    if point then
                        point.visible, point.onScreen, point.plate = false, false, false
                    end
                end
                first = first + 1
            end
            Trim(state.requests, size)
            Trim(state.indices, size)
            if size > 0 then
                local projection, failure = Projection(size, sample, clock)
                if failure == "STREAM_CHANGED" then
                    ClearCatalog()
                    return true
                end
                if not projection then return end
                sample, clock = projection.cameraSampleId, projection.clockSeconds
                for index = 1, size do
                    local entry, record = projection.entries[index], state.records[state.indices[index]]
                    if
                        type(entry) ~= "table"
                        or entry.anchorId ~= record.anchorId
                        or entry.attachment ~= record.attachment
                        or not projectionStates[entry.state]
                    then
                        return
                    end
                    if entry.state == "worldChanged" then
                        ClearCatalog()
                        return true
                    end
                    local point = state.points[state.indices[index]] or {}
                    point.visible, point.onScreen, point.plate = false, false, false
                    point.retired = entry.state == "expired" or entry.state == "unknownAnchor"
                    if entry.state == "onScreen" then
                        if
                            not Number(entry.x)
                            or not Number(entry.y)
                            or not Number(entry.cameraDistance)
                            or entry.cameraDistance < 0
                            or not Number(entry.cameraDepth)
                            or entry.cameraDepth <= 0
                            or not Number(entry.uiUnitsPerYard)
                            or entry.uiUnitsPerYard <= 0
                        then
                            return
                        end
                        point.onScreen = true
                        point.visible = IconWanted(record.kind)
                            and entry.entityState == styles[record.kind].state
                            and DistanceVisible(record.kind, entry.playerDistance)
                        if point.visible and styles[record.kind].lightArt then
                            lightOnScreen = true
                            if record.kind == "downedPartyMember" then allyOnScreen = true end
                        end
                        point.x, point.y = entry.x, entry.y + styles[record.kind].padding
                        point.plate = record.plateUnit and entry.entityState == "alive"
                        point.plateY = entry.y
                    elseif entry.x ~= nil or entry.y ~= nil then
                        return
                    end
                    state.points[state.indices[index]] = point
                end
            end
        end
        if drawPlates then
            local accepted, failure = SamplePlateDistances(total, sample, clock)
            if failure == "STREAM_CHANGED" then
                ClearCatalog()
                return true
            end
            if not accepted then return end
        end
        local lightAlpha
        local wave = (allyOnScreen or (lightOnScreen and not state.choices.performanceMode)) and math.sin(clock * 2.2)
            or 0
        if lightOnScreen then
            local ready, failure = SampleWorldLights(total, sample, clock)
            if failure == "STREAM_CHANGED" then
                ClearCatalog()
                return true
            end
            if ready then lightAlpha = state.choices.performanceMode and 0.85 or 0.85 + 0.15 * wave end
        end
        if clock then state.clock = clock end
        state.drawPass = (state.drawPass or 0) + 1
        local used = 0
        for index = 1, total do
            local record, point = state.records[index], state.points[index]
            if point and point.retired then
                local marker = state.markers[record.anchorId]
                if marker then Recycle(record.anchorId, marker) end
            else
                used = used + 1
                state.records[used], state.points[used] = record, point
            end
            if point and point.onScreen and IconWanted(record.kind) then
                local marker = point.visible and Marker(record) or state.markers[record.anchorId]
                if marker and marker.ready then
                    local y = point.y + (record.kind == "downedPartyMember" and 2 * wave or 0)
                    if (point.visible or marker:IsShown()) and (marker.x ~= point.x or marker.y ~= y) then
                        marker:ClearAllPoints()
                        marker:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", point.x, y)
                        marker.x, marker.y = point.x, y
                    end
                    marker.drawPass = state.drawPass
                    UpdateVisibility(marker, point.visible, clock, styles[record.kind].mode ~= nil)
                    local art = styles[record.kind].lightArt
                    if art and lightAlpha and point.visible then
                        DrawWorldLight(marker, point, art, lightAlpha)
                    else
                        HideWorldLight(marker)
                    end
                end
            end
            if point and point.plate then DrawPlate(record.plateUnit, point) end
            record.plateUnit = nil
        end
        Trim(state.records, used)
        Trim(state.points, used)
        for _, marker in pairs(state.markers) do
            if marker.drawPass ~= state.drawPass then HideMarker(marker) end
        end
        for id, view in pairs(distant.views) do
            if view.drawPass ~= state.drawPass then RecyclePlate(id, view) end
        end
        return true
    end
    local function SetQuery()
        if
            not state.queryDirty
            and state.queryCache == state.requestCache
            and state.queryParty == state.requestParty
            and state.queryPlates == state.requestPlates
        then
            return table.getn(state.query.kinds)
        end
        state.queryCache, state.queryParty = state.requestCache, state.requestParty
        state.queryPlates = state.requestPlates
        state.hasPlateQuery = false
        state.queryDirty = nil
        ClearMap(state.kinds)
        local count, list = 0, state.query.kinds
        for _, kind in ipairs(markerKinds) do
            local plate = state.capabilities.plateDistances and PlateWanted(kind)
            local icon
            if kind == "cache" then
                icon = state.requestCache
            elseif kind == "downedPartyMember" then
                icon = state.requestParty
            else
                icon = IconWanted(kind)
            end
            if (icon or plate) and state.capabilities.kinds[kind] then
                count = count + 1
                list[count], state.kinds[kind] = kind, true
                if plate then state.hasPlateQuery = true end
            end
        end
        Trim(list, count)
        state.discoveryAt, state.discoveryStarted, state.discoveryFailures = nil, nil, nil
        return count
    end
    local function Configure(now)
        for _, name in ipairs({
            "AZS_GetWorldAnchorCapabilities",
            "AZS_GetWorldAnchors",
            "AZS_ProjectWorldAnchors",
            "AZS_RegisterWorldAnchorFrameHandler",
            "AZS_UnregisterWorldAnchorFrameHandler",
        }) do
            if type(_G[name]) ~= "function" then return end
        end
        local getter = _G.AZS_GetWorldAnchorCapabilities
        local cached = state.cachedCapabilities
        if
            not cached
            or state.capabilityGetter ~= getter
            or now < state.capabilityAt
            or now - state.capabilityAt >= 30
        then
            local caps = Read("AZS_GetWorldAnchorCapabilities")
            local kinds = caps and StringList(caps.kinds)
            local attachments = caps and StringList(caps.attachments)
            if
                not caps
                or caps.apiVersion ~= 1
                or caps.frameHandler ~= true
                or caps.frameProjection ~= true
                or not kinds
                or not attachments
                or not Integer(caps.maxEntriesPerCall, 1, 256)
                or not Integer(caps.maxProjectionsPerCall, 1, 256)
            then
                return
            end
            cached = {
                maxEntriesPerCall = caps.maxEntriesPerCall,
                maxProjectionsPerCall = caps.maxProjectionsPerCall,
                kinds = {},
                playerDistanceMetrics = caps.playerDistanceMetrics == true,
                plateDistances = caps.playerDistanceMetrics == true
                    and Contains(caps.attachments, attachments, "position"),
            }
            for _, kind in ipairs(markerKinds) do
                cached.kinds[kind] = Contains(caps.kinds, kinds, kind)
                    and Contains(caps.attachments, attachments, styles[kind].attachment)
                    and (not styles[kind].offset or caps.worldOffsets == true)
            end
            state.cachedCapabilities, state.capabilityGetter, state.capabilityAt = cached, getter, now
        end
        state.capabilities = cached
        state.query, state.kinds = { kinds = {}, states = { "present", "alive", "downed" } }, {}
        state.queryDirty = true
        if SetQuery() == 0 then return end
        local session = {}
        state.session = session
        local handler = function()
            if state.session ~= session or state.retire then return end
            local ok, projected = pcall(Project)
            if not ok or not projected then
                HideAll()
                state.retire = true
            end
        end
        -- Track attempted registration even when native code installs then fails.
        state.handler, state.unregister = handler, _G.AZS_UnregisterWorldAnchorFrameHandler
        local ok, result, failure = pcall(_G.AZS_RegisterWorldAnchorFrameHandler, handler)
        if not ok or result == false or failure ~= nil then
            state.session = nil
            return
        end
        state.enabled = true
        return true
    end
    local function Discover(position)
        -- Cursors are valid only inside this synchronous, bounded frame pass.
        -- Never publish a partial list or discard live handles for a failed refresh.
        local cursor, catalog, world, stream, clock
        local used, total, stagingSize = 0, 0, table.getn(state.staging)
        ClearMap(state.seen)
        ClearMap(state.cursors)
        for pageNumber = 1, 256 do
            local page, failure = Read("AZS_GetWorldAnchors", state.query, cursor, state.capabilities.maxEntriesPerCall)
            if not page then return false, failure end
            local count = Array(page.entries, state.capabilities.maxEntriesPerCall)
            if
                page.apiVersion ~= 1
                or not Id(page.catalogId)
                or not Id(page.worldId)
                or not Id(page.streamId)
                or not Number(page.clockSeconds)
                or page.clockSeconds < 0
                or page.overflowed ~= false
                or not Context(page, position)
                or not count
                or type(page.hasMore) ~= "boolean"
                or (page.hasMore and (not Id(page.nextCursor) or state.cursors[page.nextCursor]))
                or (not page.hasMore and page.nextCursor ~= nil)
            then
                return false
            end
            if pageNumber == 1 then
                catalog, world, stream, clock = page.catalogId, page.worldId, page.streamId, page.clockSeconds
                if
                    state.world
                    and (
                        state.world ~= world
                        or state.stream ~= stream
                        or not Context(state, position)
                        or (state.clock and clock < state.clock)
                    )
                then
                    ClearCatalog()
                    stagingSize = 0
                end
            elseif world ~= page.worldId or stream ~= page.streamId then
                return false, "STREAM_CHANGED"
            elseif catalog ~= page.catalogId or clock ~= page.clockSeconds then
                return false, "CATALOG_CHANGED"
            end
            total = total + count
            if total > 256 then return false end
            if page.hasMore then state.cursors[page.nextCursor] = true end
            for index = 1, count do
                local entry = page.entries[index]
                if
                    type(entry) ~= "table"
                    or not state.kinds[entry.kind]
                    or entry.state ~= styles[entry.kind].state
                    or not Id(entry.anchorId)
                    or state.seen[entry.anchorId] ~= nil
                then
                    return false
                end
                local attachments = StringList(entry.attachments)
                if not attachments then return false end
                local attachment = styles[entry.kind].attachment
                local usable = Contains(entry.attachments, attachments, attachment)
                state.seen[entry.anchorId] = usable
                if usable then
                    used = used + 1
                    local record = state.staging[used] or {}
                    record.anchorId, record.kind, record.attachment = entry.anchorId, entry.kind, attachment
                    record.unitId = plateKinds[entry.kind]
                            and Integer(entry.unitId, 1, 4294967295)
                            and Contains(entry.attachments, attachments, "position")
                            and entry.unitId
                        or nil
                    state.staging[used] = record
                    -- Failed partial scans must also remain clearable on Lua 5.0.
                    if used > stagingSize then
                        if table.setn then table.setn(state.staging, used) end
                        stagingSize = used
                    end
                end
            end
            if not page.hasMore then
                for _, old in ipairs(state.records) do
                    if
                        not state.kinds[old.kind]
                        and Wanted(old.kind)
                        and used < 256
                        and state.seen[old.anchorId] == nil
                    then
                        used = used + 1
                        local record = state.staging[used] or {}
                        record.anchorId, record.kind, record.attachment = old.anchorId, old.kind, old.attachment
                        record.unitId = old.unitId
                        state.staging[used], state.seen[old.anchorId] = record, true
                        if used > stagingSize then
                            if table.setn then table.setn(state.staging, used) end
                            stagingSize = used
                        end
                    end
                end
                Trim(state.staging, used)
                state.records, state.staging = state.staging, state.records
                state.world, state.stream, state.clock = world, stream, clock
                state.mapId, state.runId, state.spaceId = page.mapId, page.runId, page.spaceId
                for id, marker in pairs(state.markers) do
                    if not state.seen[id] then Recycle(id, marker) end
                end
                Trim(state.points, table.getn(state.records))
                return true
            end
            cursor = page.nextCursor
        end
        return false
    end
    local function RetryDelay(base, failures) return math.min(8, base * 2 ^ math.min(failures - 1, 7)) end
    function api.Service(inWorld)
        local choices = state.choices
        local sct = DFRL.sct
        state.requestPlates = distant.wanted
            and T.NameplateStyle
            and sct
            and sct.EnemyNameplatesVisible
            and sct.EnemyNameplatesVisible()
        if
            not inWorld
            or not Shown(WorldFrame)
            or not Shown(UIParent)
            or (
                not choices.worldCacheIcons
                and not state.encounterIcons
                and not choices.worldPartyIcons
                and not state.requestPlates
            )
        then
            api.Reset()
            return
        end
        state.requestCache = choices.worldCacheIcons and CacheAffordable()
        state.requestParty = choices.worldPartyIcons
            and (not navigation.HasParty or navigation.HasParty())
            and (not navigation.NeedsPartyMarker or navigation.NeedsPartyMarker())
        local active = state.requestCache or state.encounterIcons or state.requestParty or state.requestPlates
        if not active then
            RequestRoster(false)
            if state.active ~= false then HideAll() end
            state.active = false
            return
        end
        if not navigation.IsRunPhase(navigation.Phase()) then
            api.Reset()
            return
        end
        if not state.active then
            state.discoveryAt, state.discoveryStarted = nil, nil
        end
        state.active, state.reset = true, nil
        local now = GetTime()
        if state.retire then
            api.Reset()
            state.retryStarted, state.retryAt = now, now + FAILURE_RETRY
            return
        end
        if state.retryAt and now >= state.retryStarted and now < state.retryAt then return end
        if not state.enabled then
            if not Release() or not Configure(now) then
                local failures = (state.configFailures or 0) + 1
                api.Reset()
                state.configFailures = failures
                state.retryStarted, state.retryAt = now, now + RetryDelay(FAILURE_RETRY, failures)
                return
            end
            state.configFailures = nil
        end
        if SetQuery() == 0 then
            RequestRoster(false)
            state.active = false
            HideAll()
            return
        end
        RequestRoster(state.hasPlateQuery)
        if state.discoveryAt and now >= state.discoveryStarted and now < state.discoveryAt then return end
        local position = navigation.WorldPosition()
        if position and state.world and not Context(state, position) then ClearCatalog() end
        if not position then
            HideAll()
            state.discoveryStarted, state.discoveryAt = now, now + FAILURE_RETRY
            return
        end
        local accepted, failure = Discover(position)
        local delay = DISCOVERY_INTERVAL
        if accepted then
            state.discoveryFailures = nil
        elseif failure == "STREAM_CHANGED" then
            ClearCatalog()
            delay = TRANSIENT_RETRY
        else
            state.discoveryFailures = (state.discoveryFailures or 0) + 1
            local base = (failure == "NOT_READY" or failure == "CATALOG_CHANGED") and TRANSIENT_RETRY or FAILURE_RETRY
            delay = RetryDelay(base, state.discoveryFailures)
        end
        state.discoveryStarted, state.discoveryAt = now, now + delay
    end
    api.UpdateOptions()
    return api
end
