-- Native version-one world anchors: docs/AzerothSurvivors-Addon-API.md.
-- Uses existing waypoint artwork and its controller; no nameplate/entity inference.
setfenv(1, DFRL:GetEnv())

function DFRL.tools.NewWorldMarkerApi(navigation)
    local api = {}
    local DISCOVERY_INTERVAL, TRANSIENT_RETRY, FAILURE_RETRY = 0.2, 0.1, 0.5
    local markerKinds = { "cache", "guardian", "boss", "finalBoss", "downedPartyMember" }
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
        choices = {},
    }
    local positionIconSize, positionIconOffset = 22.4, { z = 5 }
    local styles = {
        cache = {
            key = "worldCacheIcons",
            art = "Chest.blp",
            state = "present",
            attachment = "position",
            size = positionIconSize,
            offset = positionIconOffset,
            padding = 0,
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
            size = positionIconSize,
            offset = positionIconOffset,
            padding = 0,
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
        Trim(state.records, 0)
        Trim(state.staging, 0)
        Trim(state.requests, 0)
        Trim(state.indices, 0)
        Trim(state.points, 0)
        ClearMap(state.seen)
        ClearMap(state.cursors)
        state.catalog, state.world, state.stream = nil, nil, nil
        state.mapId, state.runId, state.spaceId, state.clock = nil, nil, nil, nil
        state.discoveryAt, state.discoveryStarted, state.discoveryFailures = nil, nil, nil
    end
    function api.Reset()
        state.session, state.enabled, state.retire = nil, false, nil
        ClearCatalog()
        state.query, state.kinds, state.capabilities = nil, nil, nil
        state.queryCache, state.queryBoss, state.queryParty = nil, nil, nil
        state.active, state.configFailures = false, nil
        state.retryAt, state.retryStarted = nil, nil
        Release() -- A partial/failed release is retried by the existing controller.
    end
    local function Context(value, position)
        return value.mapId == position.mapId and value.spaceId == position.spaceId and value.runId == position.runId
    end
    local function Wanted(kind)
        local style = styles[kind]
        return style and state.choices[style.key]
    end
    local function Marker(record)
        local style = styles[record.kind]
        local marker = state.markers[record.anchorId]
        if not marker then
            marker = table.remove(state.pool)
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
        local size = style.size or 32
        if marker.size ~= size then
            marker:SetWidth(size)
            marker:SetHeight(size)
            marker.size = size
        end
        if marker.kind ~= record.kind or not marker.ready then
            local ok, result = pcall(marker.icon.SetTexture, marker.icon, path .. style.art)
            marker.ready = ok and result ~= false
            if marker.ready then marker.icon:SetTexCoord(unpack(style.crop)) end
            marker.kind = record.kind
        end
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
    function api.UpdateOptions()
        local cache = DFRL.display.Get("worldCacheIcons")
        local boss = DFRL.display.Get("worldBossIcons")
        local party = DFRL.display.Get("worldPartyIcons")
        local affordable = DFRL.display.Get("worldCacheAffordableOnly")
        local choices = state.choices
        if
            choices.worldCacheIcons == cache
            and choices.worldBossIcons == boss
            and choices.worldPartyIcons == party
            and choices.worldCacheAffordableOnly == affordable
        then
            return
        end
        local visibilityChanged = choices.worldCacheIcons ~= cache
            or choices.worldBossIcons ~= boss
            or choices.worldPartyIcons ~= party
        choices.worldCacheIcons, choices.worldBossIcons, choices.worldPartyIcons = cache, boss, party
        choices.worldCacheAffordableOnly = affordable
        state.queryDirty = true
        if visibilityChanged then
            local used = 0
            for index = 1, table.getn(state.records) do
                local record = state.records[index]
                if Wanted(record.kind) then
                    used = used + 1
                    state.records[used], state.points[used] = record, state.points[index]
                else
                    local marker = state.markers[record.anchorId]
                    if marker then Recycle(record.anchorId, marker) end
                end
            end
            Trim(state.records, used)
            Trim(state.points, used)
            for _, record in ipairs(state.staging) do
                if record.kind and not Wanted(record.kind) then
                    record.anchorId, record.kind, record.attachment = nil, nil, nil
                end
            end
        end
        if not cache and not boss and not party then
            state.active = false
            HideAll()
        end
    end
    local function Project()
        if not state.enabled or not state.world or not state.active then return true end
        if not Shown(WorldFrame) or not Shown(UIParent) then
            HideAll()
            return true
        end
        if table.getn(state.records) == 0 then return true end
        -- Projection already validates this frame's world epoch. The shared
        -- discovery reader checks map/run/space without another player getter per frame.
        local sample, clock, total = nil, nil, table.getn(state.records)
        local first = 1
        local cacheVisible = CacheAffordable()
        -- Validate every batch before showing any icon. Reuse scalar result slots.
        while first <= total do
            local size = 0
            while first <= total and size < state.capabilities.maxProjectionsPerCall do
                local record = state.records[first]
                if
                    Wanted(record.kind)
                    and (record.kind ~= "cache" or cacheVisible)
                    and (record.kind ~= "downedPartyMember" or state.requestParty)
                then
                    size = size + 1
                    local request = state.requests[size] or {}
                    request.anchorId, request.attachment = record.anchorId, record.attachment
                    request.offset = styles[record.kind].offset
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
                local projection, failure = Read("AZS_ProjectWorldAnchors", state.requests)
                if failure == "STREAM_CHANGED" then
                    ClearCatalog()
                    return true
                end
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
                    ClearCatalog()
                    return true
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
                        ClearCatalog()
                        return true
                    end
                    local point = state.points[state.indices[index]] or {}
                    point.visible = false
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
                        point.visible = entry.entityState == styles[record.kind].state
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
        Trim(state.records, used)
        Trim(state.points, used)
        for _, marker in pairs(state.markers) do
            if marker.drawPass ~= state.drawPass and marker:IsShown() then marker:Hide() end
        end
        return true
    end
    local function SetQuery()
        if
            not state.queryDirty
            and state.queryCache == state.requestCache
            and state.queryBoss == state.requestBoss
            and state.queryParty == state.requestParty
        then
            return table.getn(state.query.kinds)
        end
        state.queryCache, state.queryBoss, state.queryParty = state.requestCache, state.requestBoss, state.requestParty
        state.queryDirty = nil
        ClearMap(state.kinds)
        local count, list = 0, state.query.kinds
        for _, kind in ipairs(markerKinds) do
            local requested = kind == "cache" and state.requestCache
                or kind == "downedPartyMember" and state.requestParty
                or (kind ~= "cache" and kind ~= "downedPartyMember" and state.requestBoss)
            if requested and state.capabilities.kinds[kind] then
                count = count + 1
                list[count], state.kinds[kind] = kind, true
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
                        state.staging[used], state.seen[old.anchorId] = record, true
                        if used > stagingSize then
                            if table.setn then table.setn(state.staging, used) end
                            stagingSize = used
                        end
                    end
                end
                Trim(state.staging, used)
                state.records, state.staging = state.staging, state.records
                state.catalog, state.world, state.stream, state.clock = catalog, world, stream, clock
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
        if
            not inWorld
            or not Shown(WorldFrame)
            or not Shown(UIParent)
            or (not choices.worldCacheIcons and not choices.worldBossIcons and not choices.worldPartyIcons)
        then
            api.Reset()
            return
        end
        state.requestCache = choices.worldCacheIcons and CacheAffordable()
        state.requestBoss = choices.worldBossIcons
        state.requestParty = choices.worldPartyIcons
            and (not navigation.HasParty or navigation.HasParty())
            and (not navigation.NeedsPartyMarker or navigation.NeedsPartyMarker())
        local active = state.requestCache or state.requestBoss or state.requestParty
        if not active then
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
        state.active = true
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
            state.active = false
            HideAll()
            return
        end
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
