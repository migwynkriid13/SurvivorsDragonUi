-- Optional native world-SCT boundary. Never infer an enemy from a nameplate.
setfenv(1, DFRL:GetEnv())

function DFRL.tools.NewCombatTextApi()
    local adapter = {}
    local state = { selected = false, seen = {}, order = {}, slot = 0, ids = {}, origins = {} }
    local kinds = { player = true, pet = true, summon = true, totem = true, ownedUnknown = true }
    local attacks = { melee = "autoattack", ranged = "autoattack", spell = "spell" }
    local schools = {
        [1] = "Physical",
        [2] = "Holy",
        [4] = "Fire",
        [8] = "Nature",
        [16] = "Frost",
        [32] = "Shadow",
        [64] = "Arcane",
    }
    local results = {
        miss = true,
        dodge = true,
        parry = true,
        block = true,
        resist = true,
        immune = true,
        evade = true,
        absorb = true,
        reflect = true,
        deflect = true,
    }
    local states = {
        onScreen = true,
        offscreen = true,
        behindCamera = true,
        clipped = true,
        notReady = true,
        expired = true,
        unknownAnchor = true,
        worldChanged = true,
    }
    local targets = { alive = true, dead = true, unavailable = true }

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Id(value) return type(value) == "string" and value ~= "" end
    local function Integer(value, minimum, maximum)
        return Number(value) and value >= minimum and value <= maximum and value == math.floor(value)
    end
    local function Array(value, limit)
        if type(value) ~= "table" then return end
        local count = 0
        for key in pairs(value) do
            if not Integer(key, 1, limit) then return end
            count = count + 1
        end
        for index = 1, count do
            if value[index] == nil then return end
        end
        return count
    end
    local function Part(value)
        value = value or ""
        return string.len(value) .. ":" .. value
    end
    local function Call(name, first, second)
        if type(_G[name]) ~= "function" then return end
        local ok, result, failure
        if first == nil and second == nil then
            ok, result, failure = pcall(_G[name])
        else
            ok, result, failure = pcall(_G[name], first, second)
        end
        if not ok or failure ~= nil or type(result) ~= "table" then
            return nil, type(failure) == "table" and failure.code or nil
        end
        return result
    end
    local function Header(value)
        return value.apiVersion == 1
            and Id(value.streamId)
            and Id(value.worldId)
            and Number(value.clockSeconds)
            and value.clockSeconds >= 0
    end
    function adapter.Selected() return state.selected end
    local function Clock()
        local ok, now = pcall(_G.GetTime)
        return ok and Number(now) and now or 0
    end
    local function FrameCall(callback, handler)
        local ok, result, failure = pcall(callback, handler)
        return ok and result ~= false and failure == nil
    end
    local function PendingFrame()
        state.handoffStarted = Clock()
        state.handoffAt = state.handoffStarted + 0.5
    end
    function adapter.BindFrame(handler) state.handler = handler end
    function adapter.Reset()
        state.cursor, state.streamId, state.worldId, state.clock, state.presentedAt = nil, nil, nil, nil, nil
        state.retryAt, state.retryStarted = nil, nil
        state.seen, state.order, state.slot = {}, {}, 0
        state.ids, state.origins = {}, {}
    end
    function adapter.Configure(wanted)
        adapter.Reset()
        state.wanted, state.handoffAt, state.handoffStarted = wanted, nil, nil
        state.selected, state.limit, state.playerDistanceMetrics = false, nil, false
        if state.registered then
            if not FrameCall(state.unregister, state.handler) then
                PendingFrame()
                return
            end
            state.registered, state.unregister = false, nil
        end
        if
            not wanted
            or type(state.handler) ~= "function"
            or type(_G.AZS_GetCombatTextCapabilities) ~= "function"
            or type(_G.AZS_GetCombatTextEvents) ~= "function"
            or type(_G.AZS_ProjectCombatTextAnchors) ~= "function"
            or type(_G.AZS_RegisterCombatTextFrameHandler) ~= "function"
            or type(_G.AZS_UnregisterCombatTextFrameHandler) ~= "function"
        then
            return
        end
        local value = Call("AZS_GetCombatTextCapabilities")
        if
            not value
            or value.apiVersion ~= 1
            or value.impactAnchors ~= true
            or value.followAnchors ~= true
            or value.frameProjection ~= true
            or value.distanceMetrics ~= true
            or value.frameHandler ~= true
            or not Integer(value.maxEventsPerRead, 1, 256)
            or not Integer(value.maxAnchorsPerRead, 1, 256)
            or not Integer(value.eventCapacity, 4096, 1000000)
            or not Integer(value.anchorCapacity, 4096, 1000000)
            or not Number(value.eventRetentionSeconds)
            or value.eventRetentionSeconds < 5
            or not Number(value.anchorRetentionSeconds)
            or value.anchorRetentionSeconds < 5
        then
            return
        end
        state.limit, state.projectLimit = value.maxEventsPerRead, value.maxAnchorsPerRead
        state.playerDistanceMetrics = value.playerDistanceMetrics == true
        -- A native call may fail after installing the handler. Always release
        -- that same function before a retry can register it again.
        state.registered, state.unregister = true, _G.AZS_UnregisterCombatTextFrameHandler
        if not FrameCall(_G.AZS_RegisterCombatTextFrameHandler, state.handler) then
            PendingFrame()
            return
        end
        state.selected = true
    end
    function adapter.Service()
        if not state.handoffAt then return false end
        local now = Clock()
        if now >= state.handoffStarted and now < state.handoffAt then return false end
        local selected = state.selected
        adapter.Configure(state.wanted)
        return selected ~= state.selected
    end
    local function Retry(now)
        adapter.Reset()
        state.retryStarted, state.retryAt = now, now + 0.5
    end
    local function Event(value, clock)
        if
            type(value) ~= "table"
            or not Id(value.eventId)
            or not Number(value.presentedAt)
            or value.presentedAt < 0
            or value.presentedAt > clock
            or not kinds[value.sourceKind]
            or type(value.critical) ~= "boolean"
            or type(value.periodic) ~= "boolean"
            or type(value.reflected) ~= "boolean"
            or (value.kind ~= "damage" and value.kind ~= "miss")
            or (value.anchorStatus ~= "ready" and value.anchorStatus ~= "unavailable")
        then
            return
        end
        for _, key in ipairs({ "targetId", "targetName", "sourceId", "abilityName", "icon" }) do
            if value[key] ~= nil and not Id(value[key]) then return end
        end
        if value.spellId ~= nil and not Integer(value.spellId, 1, 4294967295) then return end
        if value.damageType ~= nil and not attacks[value.damageType] then return end
        if value.schoolMask ~= nil and not Integer(value.schoolMask, 1, 127) then return end
        if value.anchorStatus == "ready" then
            if not Id(value.anchorId) or not Id(value.targetId) then return end
        elseif value.anchorId ~= nil then
            return
        end
        if value.kind == "damage" then
            if not Number(value.amount) or value.amount < 0 or value.result ~= nil then return end
        elseif
            value.amount ~= nil
            or type(value.result) ~= "table"
            or not results[value.result.key]
            or (value.result.text ~= nil and not Id(value.result.text))
        then
            return
        end
        local damageType = attacks[value.damageType]
        if value.periodic then damageType = "periodic" end
        if value.reflected then damageType = "reflected" end
        local attack
        -- Newer clients identify the credited meter line even when its proc
        -- borrows another spell. Optional captions never establish identity.
        local meterSourceKey = Id(value.meterSourceKey) and value.meterSourceKey or nil
        if value.spellId then
            attack = "spell:" .. tostring(value.spellId)
        elseif damageType == "autoattack" then
            attack = "attack:" .. value.damageType
        end
        return {
            kind = value.kind,
            amount = value.amount,
            text = value.result and value.result.text,
            sourceName = value.sourceId or "",
            sourceIsPet = value.sourceKind ~= "player",
            targetName = value.targetName or "",
            spell = value.abilityName,
            spellId = value.spellId,
            meterSource = Id(value.meterSource) and value.meterSource or nil,
            meterSourceKey = meterSourceKey,
            damageType = damageType,
            school = schools[value.schoolMask] or (value.schoolMask and tostring(value.schoolMask)),
            critical = value.critical,
            iconTexture = value.icon,
            nativeAttack = attack,
            nativeIdentity = Part(value.sourceId or value.eventId) .. Part(value.sourceKind) .. Part(
                value.targetId or value.eventId
            ) .. Part(attack or value.eventId) .. Part(meterSourceKey or ""),
            nativeEventId = value.eventId,
            nativeTime = value.presentedAt,
            nativeOrigin = value.anchorStatus == "ready" and {
                native = true,
                anchorId = value.anchorId,
                targetId = value.targetId,
                visible = false,
                x = 0,
                y = 0,
                distanceScale = 1,
            } or nil,
        }
    end
    function adapter.Read(now)
        if not state.selected then return end
        if state.retryAt and now >= state.retryStarted and now < state.retryAt then return end
        state.retryAt, state.retryStarted = nil, nil
        local value = Call("AZS_GetCombatTextEvents", state.cursor, state.limit)
        local count = value and Array(value.events, state.limit)
        if
            not value
            or not Header(value)
            or not count
            or not Id(value.cursor)
            or type(value.hasMore) ~= "boolean"
            or not Integer(value.droppedCount, 0, 9007199254740991)
            or (state.clock and value.clockSeconds < state.clock)
            or (state.streamId and (value.streamId ~= state.streamId or value.worldId ~= state.worldId))
            or (state.cursor and (count > 0 or value.droppedCount > 0 or value.hasMore) and value.cursor == state.cursor)
            or (not state.cursor and (count > 0 or value.droppedCount ~= 0 or value.hasMore))
        then
            Retry(now)
            return nil, true
        end
        local events, seen, previous = {}, {}, state.presentedAt
        for index = 1, count do
            local event = Event(value.events[index], value.clockSeconds)
            if
                not event
                or state.seen[event.nativeEventId]
                or seen[event.nativeEventId]
                or (previous and event.nativeTime < previous)
            then
                Retry(now)
                return nil, true
            end
            previous = event.nativeTime
            seen[event.nativeEventId] = true
            -- Skip stale intake and unanchored hits; neither gets an invented position.
            if
                value.clockSeconds - event.nativeTime <= 0.65
                and event.nativeOrigin
                and (event.kind ~= "miss" or event.text ~= nil)
            then
                table.insert(events, event)
            end
        end
        state.cursor, state.streamId, state.worldId = value.cursor, value.streamId, value.worldId
        state.clock, state.presentedAt = value.clockSeconds, previous
        for id in pairs(seen) do
            state.slot = math.mod(state.slot, 4096) + 1
            local old = state.order[state.slot]
            if old then state.seen[old] = nil end
            state.order[state.slot], state.seen[id] = id, true
        end
        return events
    end
    local function Point(value, id)
        if
            type(value) ~= "table"
            or value.anchorId ~= id
            or not states[value.state]
            or (value.targetState ~= nil and not targets[value.targetState])
        then
            return false
        end
        if value.state == "onScreen" then
            return targets[value.targetState]
                and Number(value.x)
                and Number(value.y)
                and Number(value.cameraDistance)
                and value.cameraDistance >= 0
                and Number(value.cameraDepth)
                and value.cameraDepth > 0
                and Number(value.uiUnitsPerYard)
                and value.uiUnitsPerYard > 0
        end
        return value.x == nil
            and value.y == nil
            and (value.state ~= "expired" or value.reason == "age" or value.reason == "resourceLimit")
    end
    function adapter.Project(texts, now, scaleByDistance, referenceDistance, minimumPercent)
        if not state.selected then return true end
        local count = table.getn(texts)
        if count == 0 or not state.cursor then return true end
        local ids, origins, sample, clock = state.ids, state.origins, nil, nil
        local size, failed = 0, false
        -- Hide old projections before any native call, including a thrown call.
        for index = 1, count do
            local origin = texts[index].origin
            if origin and origin.native then origin.visible = false end
        end
        local function Flush()
            if size == 0 or failed then return end
            table.setn(ids, size)
            local value = Call("AZS_ProjectCombatTextAnchors", ids, "follow")
            if
                not value
                or not Header(value)
                or value.frameCurrent ~= true
                or value.streamId ~= state.streamId
                or value.worldId ~= state.worldId
                or not Id(value.cameraSampleId)
                or Array(value.entries, state.projectLimit) ~= size
                or (sample and value.cameraSampleId ~= sample)
                or (clock and value.clockSeconds ~= clock)
                or (state.clock and value.clockSeconds < state.clock)
            then
                failed = true
                return
            end
            for index = 1, size do
                local point = value.entries[index]
                if not Point(point, ids[index]) or point.state == "worldChanged" then
                    failed = true
                    return
                end
            end
            sample, clock = value.cameraSampleId, value.clockSeconds
            for index = 1, size do
                local point, origin = value.entries[index], origins[index]
                if point.state == "onScreen" then
                    origin.x, origin.y, origin.visible = point.x, point.y, true
                    -- Camera metrics never substitute for distance from the hero.
                    local distance = state.playerDistanceMetrics and point.playerDistance
                    local factor = 1
                    if scaleByDistance and Number(distance) and distance > 0 then
                        factor =
                            math.max((minimumPercent or 55) / 100, math.min(1, (referenceDistance or 20) / distance))
                    end
                    origin.distanceScale = factor
                end
            end
            for index = 1, size do
                ids[index], origins[index] = nil, nil
            end
            size = 0
            table.setn(ids, 0)
        end
        for index = 1, count do
            local origin = texts[index].origin
            if origin and origin.native and not failed and now - texts[index].started < texts[index].duration then
                size = size + 1
                ids[size], origins[size] = origin.anchorId, origin
                if size == state.projectLimit then Flush() end
            end
        end
        Flush()
        if failed then
            for index = 1, count do
                local origin = texts[index].origin
                if origin and origin.native then origin.visible = false end
            end
            Retry(now)
            return false
        end
        if clock then state.clock = clock end
        return true
    end
    return adapter
end
