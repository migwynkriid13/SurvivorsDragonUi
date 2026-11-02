-- Draft general-anchor consumer. Optional provider shape: docs/FALLEN-ALLY-POSITION-API-PROPOSAL.md.
-- Uses existing waypoint artwork and its controller; no nameplate/entity inference.
setfenv(1, DFRL:GetEnv())

function DFRL.tools.NewWorldMarkerApi(navigation)
    local api = {}
    local DISCOVERY_INTERVAL, TRANSIENT_RETRY, FAILURE_RETRY = 0.2, 0.1, 0.5
    local state = {
        records = {},
        staging = {},
        requests = {},
        indices = {},
        points = {},
        markers = {},
        pool = {},
        seen = {},
        cursors = {},
    }
    local styles = {
        cache = {
            key = "worldCacheIcons",
            art = "Chest.blp",
            state = "available",
            attachment = "position",
            padding = 22,
            crop = { 0, 1, 0, 1 },
        },
        guardian = {
            key = "worldBossIcons",
            art = "GuardianFloating.blp",
            state = "alive",
            attachment = "overhead",
            padding = 6,
            crop = { 0, 65 / 128, 0, 65 / 128 },
        },
        boss = {
            key = "worldBossIcons",
            art = "GuardianFloating.blp",
            state = "alive",
            attachment = "overhead",
            padding = 6,
            crop = { 0, 65 / 128, 0, 65 / 128 },
        },
        finalBoss = {
            key = "worldBossIcons",
            art = "GuardianFloating.blp",
            state = "alive",
            attachment = "overhead",
            padding = 6,
            crop = { 0, 65 / 128, 0, 65 / 128 },
        },
        downedPartyMember = {
            key = "worldPartyIcons",
            art = "FallenAlly.blp",
            state = "downed",
            attachment = "position",
            padding = 22,
            crop = { 0, 1, 0, 1 },
        },
    }
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
    local path = DFRL:GetInfoOrCons("tex") .. "waypoint\\"
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
    local function HideAll()
        for _, marker in pairs(state.markers) do
            if marker:IsShown() then marker:Hide() end
        end
    end
    local function Recycle(id, marker)
        marker:Hide()
        marker.x, marker.y, marker.kind, marker.ready = nil, nil, nil, nil
        state.markers[id] = nil
        table.insert(state.pool, marker)
    end
    local function Release()
        if not state.handler then return true end
        local ok, result, failure = pcall(state.unregister, state.handler)
        if not ok or result == false or failure ~= nil then return false end
        state.handler, state.unregister = nil, nil
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
        Trim(state.records, 0)
        Trim(state.staging, 0)
        Trim(state.requests, 0)
        Trim(state.indices, 0)
        Trim(state.points, 0)
        ClearMap(state.seen)
        ClearMap(state.cursors)
        state.catalog, state.world = nil, nil
        state.mapId, state.runId, state.spaceId, state.clock = nil, nil, nil, nil
        state.discoveryAt, state.discoveryStarted = nil, nil
    end
    function api.Reset()
        state.session, state.enabled, state.retire = nil, false, nil
        ClearCatalog()
        state.query, state.kinds, state.options, state.capabilities = nil, nil, nil, nil
        state.retryAt, state.retryStarted = nil, nil
        Release() -- A partial/failed release is retried by the existing controller.
    end
    local function Context(value, position)
        return value.mapId == position.mapId and value.spaceId == position.spaceId and value.runId == position.runId
    end
    local function Wanted(kind)
        local style = styles[kind]
        return style and DFRL.display.Get(style.key)
    end
    local function Marker(record)
        local marker = state.markers[record.anchorId]
        if not marker then
            marker = table.remove(state.pool)
            if not marker then
                marker = CreateFrame("Frame", nil, WorldFrame)
                marker:Hide()
                marker:SetFrameStrata("LOW")
                marker:EnableMouse(false)
                marker:SetWidth(32)
                marker:SetHeight(32)
                marker.icon = marker:CreateTexture(nil, "ARTWORK")
                marker.icon:SetAllPoints(marker)
            end
            state.markers[record.anchorId] = marker
        end
        if marker.kind ~= record.kind or not marker.ready then
            local style = styles[record.kind]
            local ok, result = pcall(marker.icon.SetTexture, marker.icon, path .. style.art)
            marker.ready = ok and result ~= false
            if marker.ready then marker.icon:SetTexCoord(unpack(style.crop)) end
            marker.kind = record.kind
        end
        return marker
    end
    local function CacheAffordable()
        if not DFRL.display.Get("worldCacheAffordableOnly") then return true end
        local run = _G.AZS_RUN
        return type(run) == "table"
            and Number(_G.AZS_RUN_UPDATED)
            and Number(run.gold)
            and run.gold >= 0
            and Number(run.chest)
            and run.chest >= 0
            and run.gold >= run.chest
    end
    local function Project()
        if
            not state.enabled
            or not state.world
            or not WorldFrame:IsVisible()
            or not navigation.IsRunPhase(navigation.Phase())
        then
            return
        end
        if table.getn(state.records) == 0 then
            HideAll()
            return true
        end
        local position = navigation.WorldPosition()
        if not position then
            HideAll()
            return true
        end
        if not Context(state, position) then
            state.retire = true
            return
        end
        local sample, clock, total = nil, nil, table.getn(state.records)
        local first = 1
        local cacheVisible = CacheAffordable()
        -- Validate every batch before showing any icon. Reuse scalar result slots.
        while first <= total do
            local size = 0
            while first <= total and size < state.capabilities.maxAnchorsPerRead do
                local record = state.records[first]
                if record.kind ~= "cache" or cacheVisible then
                    size = size + 1
                    local request = state.requests[size] or {}
                    request.anchorId, request.attachment = record.anchorId, record.attachment
                    state.requests[size], state.indices[size] = request, first
                else
                    local point = state.points[first]
                    if point then point.visible = false end
                end
                first = first + 1
            end
            Trim(state.requests, size)
            Trim(state.indices, size)
            if size > 0 then
                local projection = Read("AZS_ProjectWorldAnchors", state.requests)
                if
                    projection
                    and Number(projection.clockSeconds)
                    and state.clock
                    and projection.clockSeconds < state.clock
                then
                    state.retire = true
                    return
                end
                if
                    not projection
                    or projection.apiVersion ~= 1
                    or projection.frameCurrent ~= true
                    or projection.worldId ~= state.world
                    or not Id(projection.cameraSampleId)
                    or not Number(projection.clockSeconds)
                    or projection.clockSeconds < 0
                    or (sample and sample ~= projection.cameraSampleId)
                    or (clock and clock ~= projection.clockSeconds)
                    or Array(projection.entries, size) ~= size
                then
                    return
                end
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
                        state.retire = true
                        return
                    end
                    local point = state.points[state.indices[index]] or {}
                    point.visible = false
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
                            or (
                                entry.occlusion ~= nil
                                and entry.occlusion ~= "visible"
                                and entry.occlusion ~= "notTested"
                                and entry.occlusion ~= "occluded"
                            )
                        then
                            return
                        end
                        point.visible = entry.entityState == styles[record.kind].state and entry.occlusion ~= "occluded"
                        point.x, point.y = entry.x, entry.y + styles[record.kind].padding
                    elseif entry.x ~= nil or entry.y ~= nil then
                        return
                    end
                    state.points[state.indices[index]] = point
                end
            end
        end
        if clock then state.clock = clock end
        state.drawPass = (state.drawPass or 0) + 1
        for index = 1, total do
            local record, point = state.records[index], state.points[index]
            if point and point.visible and Wanted(record.kind) then
                local marker = Marker(record)
                if marker.ready then
                    if marker.x ~= point.x or marker.y ~= point.y then
                        marker:ClearAllPoints()
                        marker:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", point.x, point.y)
                        marker.x, marker.y = point.x, point.y
                    end
                    marker.drawPass = state.drawPass
                    if not marker:IsShown() then marker:Show() end
                end
            end
        end
        for _, marker in pairs(state.markers) do
            if marker.drawPass ~= state.drawPass and marker:IsShown() then marker:Hide() end
        end
        return true
    end
    local function Configure()
        for _, name in ipairs({
            "AZS_GetWorldAnchorCapabilities",
            "AZS_GetWorldAnchors",
            "AZS_ProjectWorldAnchors",
            "AZS_RegisterWorldAnchorFrameHandler",
            "AZS_UnregisterWorldAnchorFrameHandler",
        }) do
            if type(_G[name]) ~= "function" then return end
        end
        local caps = Read("AZS_GetWorldAnchorCapabilities")
        if
            not caps
            or caps.apiVersion ~= 1
            or caps.frameHandler ~= true
            or type(caps.kinds) ~= "table"
            or type(caps.attachments) ~= "table"
            or not Integer(caps.maxEntriesPerRead, 1, 256)
            or not Integer(caps.maxAnchorsPerRead, 1, 256)
        then
            return
        end
        local kinds, selected = {}, {}
        for _, kind in ipairs({ "cache", "guardian", "boss", "finalBoss", "downedPartyMember" }) do
            if Wanted(kind) and caps.kinds[kind] == true and caps.attachments[styles[kind].attachment] == true then
                table.insert(kinds, kind)
                selected[kind] = true
            end
        end
        if table.getn(kinds) == 0 then return end
        state.query = { kinds = kinds, states = { "available", "alive", "downed" } }
        state.kinds = selected
        state.capabilities = { maxEntriesPerRead = caps.maxEntriesPerRead, maxAnchorsPerRead = caps.maxAnchorsPerRead }
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
        local cursor, catalog, world
        local used, total, stagingSize = 0, 0, table.getn(state.staging)
        ClearMap(state.seen)
        ClearMap(state.cursors)
        for pageNumber = 1, 256 do
            local page, failure = Read("AZS_GetWorldAnchors", state.query, cursor, state.capabilities.maxEntriesPerRead)
            if not page then return false, failure end
            local count = Array(page.entries, state.capabilities.maxEntriesPerRead)
            if
                page.apiVersion ~= 1
                or not Id(page.catalogId)
                or not Id(page.worldId)
                or not Context(page, position)
                or not count
                or type(page.hasMore) ~= "boolean"
                or (page.hasMore and (not Id(page.nextCursor) or state.cursors[page.nextCursor]))
                or (not page.hasMore and page.nextCursor ~= nil)
            then
                return false
            end
            if pageNumber == 1 then
                catalog, world = page.catalogId, page.worldId
                if state.world and (state.world ~= world or not Context(state, position)) then
                    ClearCatalog()
                    stagingSize = 0
                end
            elseif catalog ~= page.catalogId or world ~= page.worldId then
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
                    or (entry.anchorStatus ~= "ready" and entry.anchorStatus ~= "unavailable")
                then
                    return false
                end
                if entry.anchorStatus == "ready" then
                    if
                        not Id(entry.anchorId)
                        or state.seen[entry.anchorId] ~= nil
                        or type(entry.attachments) ~= "table"
                    then
                        return false
                    end
                    local attachment = styles[entry.kind].attachment
                    local usable = entry.attachments[attachment] == true
                    state.seen[entry.anchorId] = usable
                    if usable then
                        used = used + 1
                        local record = state.staging[used] or {}
                        record.anchorId, record.kind, record.attachment = entry.anchorId, entry.kind, attachment
                        state.staging[used] = record
                        -- Failed partial scans must also remain clearable on Lua 5.0.
                        if used > stagingSize then
                            if table.setn then table.setn(state.staging, used) end
                            stagingSize = used
                        end
                    end
                elseif entry.anchorId ~= nil then
                    return false
                end
            end
            if not page.hasMore then
                Trim(state.staging, used)
                state.records, state.staging = state.staging, state.records
                state.catalog, state.world = catalog, world
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
    function api.Service(inWorld)
        local options = (DFRL.display.Get("worldCacheIcons") and "1" or "0")
            .. (DFRL.display.Get("worldBossIcons") and "1" or "0")
            .. (DFRL.display.Get("worldPartyIcons") and "1" or "0")
        if
            not inWorld
            or options == "000"
            or not WorldFrame
            or not WorldFrame:IsVisible()
            or not navigation.IsRunPhase(navigation.Phase())
        then
            api.Reset()
            return
        end
        local now = GetTime()
        if state.retire then
            api.Reset()
            state.retryStarted, state.retryAt = now, now + FAILURE_RETRY
            return
        end
        if state.options and state.options ~= options then api.Reset() end
        if state.retryAt and now >= state.retryStarted and now < state.retryAt then return end
        local function Retry()
            api.Reset()
            state.retryStarted, state.retryAt = now, now + FAILURE_RETRY
        end
        if not state.enabled then
            if not Release() or not Configure() then
                Retry()
                return
            end
            state.options = options
        end
        local position = navigation.WorldPosition()
        if position and state.world and not Context(state, position) then ClearCatalog() end
        if not position then
            HideAll()
            return
        end
        if state.discoveryAt and now >= state.discoveryStarted and now < state.discoveryAt then return end
        local accepted, failure = Discover(position)
        local delay = accepted and DISCOVERY_INTERVAL or FAILURE_RETRY
        if failure == "NOT_READY" or failure == "CATALOG_CHANGED" then delay = TRANSIENT_RETRY end
        state.discoveryStarted, state.discoveryAt = now, now + delay
    end
    return api
end
