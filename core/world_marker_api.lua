-- Draft general-anchor consumer. Optional provider shape: docs/FALLEN-ALLY-POSITION-API-PROPOSAL.md.
-- Uses existing waypoint artwork and its controller; no nameplate/entity inference.
setfenv(1, DFRL:GetEnv())

function DFRL.tools.NewWorldMarkerApi(navigation)
    local api = {}
    local state = { records = {}, staging = {}, requests = {}, points = {}, markers = {}, pool = {} }
    local styles = {
        cache = { key = "worldCacheIcons", art = "Chest.blp", state = "available", crop = { 0, 1, 0, 1 } },
        guardian = {
            key = "worldBossIcons",
            art = "GuardianFloating.blp",
            state = "alive",
            crop = { 0, 65 / 128, 0, 65 / 128 },
        },
        boss = {
            key = "worldBossIcons",
            art = "GuardianFloating.blp",
            state = "alive",
            crop = { 0, 65 / 128, 0, 65 / 128 },
        },
        finalBoss = {
            key = "worldBossIcons",
            art = "GuardianFloating.blp",
            state = "alive",
            crop = { 0, 65 / 128, 0, 65 / 128 },
        },
        downedPartyMember = { key = "worldPartyIcons", art = "FallenAlly.blp", state = "downed", crop = { 0, 1, 0, 1 } },
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
    function api.Reset()
        state.session, state.enabled, state.retire = nil, false, nil
        HideAll()
        for id, marker in pairs(state.markers) do
            Recycle(id, marker)
        end
        Trim(state.records, 0)
        Trim(state.staging, 0)
        Trim(state.requests, 0)
        Trim(state.points, 0)
        state.catalog, state.cursor, state.seen, state.world = nil, nil, nil, nil
        state.query, state.cursors, state.stagingCount, state.total = nil, nil, nil, nil
        state.mapId, state.runId, state.spaceId, state.clock = nil, nil, nil, nil
        state.options, state.capabilities = nil, nil
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
        if not position or not Context(state, position) then
            state.retire = true
            return
        end
        local sample, clock, total = nil, nil, table.getn(state.records)
        local first = 1
        -- Validate every batch before showing any icon. Reuse scalar result slots.
        while first <= total do
            local size = math.min(state.capabilities.maxAnchorsPerRead, total - first + 1)
            for index = 1, size do
                local request = state.requests[index] or {}
                request.anchorId, request.attachment = state.records[first + index - 1].anchorId, "overhead"
                state.requests[index] = request
            end
            Trim(state.requests, size)
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
                local entry, record = projection.entries[index], state.records[first + index - 1]
                if
                    type(entry) ~= "table"
                    or entry.anchorId ~= record.anchorId
                    or entry.attachment ~= "overhead"
                    or not projectionStates[entry.state]
                then
                    return
                end
                if entry.state == "worldChanged" then
                    state.retire = true
                    return
                end
                local point = state.points[first + index - 1] or {}
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
                    point.x, point.y = entry.x, entry.y + 6
                elseif entry.x ~= nil or entry.y ~= nil then
                    return
                end
                state.points[first + index - 1] = point
            end
            first = first + size
        end
        if clock then state.clock = clock end
        state.drawPass = (state.drawPass or 0) + 1
        for index = 1, total do
            local record, point = state.records[index], state.points[index]
            if point.visible and Wanted(record.kind) then
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
            or caps.attachments.overhead ~= true
            or not Integer(caps.maxEntriesPerRead, 1, 256)
            or not Integer(caps.maxAnchorsPerRead, 1, 256)
        then
            return
        end
        local kinds = {}
        for _, kind in ipairs({ "cache", "guardian", "boss", "finalBoss", "downedPartyMember" }) do
            if Wanted(kind) and caps.kinds[kind] == true then table.insert(kinds, kind) end
        end
        if table.getn(kinds) == 0 then return end
        state.query = { kinds = kinds, states = { "available", "alive", "downed" } }
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
        local page = Read("AZS_GetWorldAnchors", state.query, state.cursor, state.capabilities.maxEntriesPerRead)
        local count = page and Array(page.entries, state.capabilities.maxEntriesPerRead)
        if
            not page
            or page.apiVersion ~= 1
            or not Id(page.catalogId)
            or not Id(page.worldId)
            or not Context(page, position)
            or not count
            or type(page.hasMore) ~= "boolean"
            or (page.hasMore and (not Id(page.nextCursor) or page.nextCursor == state.cursor))
            or (not page.hasMore and page.nextCursor ~= nil)
        then
            return false
        end
        if state.cursor and (state.catalog ~= page.catalogId or state.world ~= page.worldId) then return false end
        if not state.cursor then
            if state.world and (state.world ~= page.worldId or not Context(state, position)) then
                HideAll()
                Trim(state.records, 0)
                state.clock = nil
            end
            state.catalog, state.world = page.catalogId, page.worldId
            state.mapId, state.runId, state.spaceId = page.mapId, page.runId, page.spaceId
            state.seen, state.cursors, state.pages, state.stagingCount, state.total = {}, {}, 0, 0, 0
        end
        state.pages, state.total = state.pages + 1, state.total + count
        if state.pages > 256 or state.total > 256 then return false end
        if page.hasMore then
            if state.cursors[page.nextCursor] then return false end
            state.cursors[page.nextCursor] = true
        end
        for index = 1, count do
            local entry = page.entries[index]
            if
                type(entry) ~= "table"
                or not styles[entry.kind]
                or not Wanted(entry.kind)
                or entry.state ~= styles[entry.kind].state
                or (entry.anchorStatus ~= "ready" and entry.anchorStatus ~= "unavailable")
            then
                return false
            end
            if entry.anchorStatus == "ready" then
                if not Id(entry.anchorId) or state.seen[entry.anchorId] or type(entry.attachments) ~= "table" then
                    return false
                end
                state.seen[entry.anchorId] = true
                if entry.attachments.overhead == true then
                    state.stagingCount = state.stagingCount + 1
                    local record = state.staging[state.stagingCount] or {}
                    record.anchorId, record.kind = entry.anchorId, entry.kind
                    state.staging[state.stagingCount] = record
                end
            elseif entry.anchorId ~= nil then
                return false
            end
        end
        state.cursor = page.nextCursor
        if not page.hasMore then
            Trim(state.staging, state.stagingCount)
            state.records, state.staging = state.staging, state.records
            for id, marker in pairs(state.markers) do
                if not state.seen[id] then Recycle(id, marker) end
            end
            Trim(state.points, table.getn(state.records))
            state.seen = nil
        end
        return true
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
            state.retryStarted, state.retryAt = now, now + 0.5
            return
        end
        if state.options and state.options ~= options then api.Reset() end
        if state.retryAt and now >= state.retryStarted and now < state.retryAt then return end
        local function Retry()
            api.Reset()
            state.retryStarted, state.retryAt = now, now + 0.5
        end
        if not state.enabled then
            if not Release() or not Configure() then
                Retry()
                return
            end
            state.options = options
        end
        local position = navigation.WorldPosition()
        if not position or not Discover(position) then Retry() end
    end
    return api
end
