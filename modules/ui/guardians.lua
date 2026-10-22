-- Guardian roster data only. The shared waypoint reader owns lair acceptance
-- and run boundaries; this module creates no widgets or visible notifications.
DFRL:NewMod("GuardianRoster", 2, function()
    local roster = {}
    DFRL.guardians = roster
    local lairs, changes = {}, {}
    local revision, generation = 0, 0
    local stamp, packet, clock
    local zone
    local unitGeneration, blockedUnitGeneration = 0, -1
    local blockedUnits, blockedUnitStamp
    local droppedThroughRevision = 0
    local ready = false
    local MAX_SMOOTHING, MAX_CHANGES = 1.5, 64
    local copiedFields = { "left", "x", "y", "z", "mx", "my" }
    local health, healthSeen = {}, {}

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Integer(value, minimum) return Number(value) and value >= minimum and value == math.floor(value) end
    local function Native(name)
        local getter = _G[name]
        if type(getter) ~= "function" then return end
        local ok, value = pcall(getter)
        if ok then return value end
    end
    local function Active()
        local navigation = DFRL.navigation
        return navigation and navigation.IsRunPhase(Native("AZS_GetPhase")) or false
    end
    local function Living(row) return row.state == "asleep" or row.state == "awake" end
    local function Copy(row, copy)
        copy = copy or {}
        for key in pairs(copy) do copy[key] = nil end
        for key, value in pairs(row) do
            copy[key] = value
        end
        return copy
    end

    function roster.Clear()
        blockedUnits, blockedUnitStamp = _G.AZS_UNITS, _G.AZS_UNITS_UPDATED
        blockedUnitGeneration = unitGeneration
        if not ready then return end
        lairs, changes = {}, {}
        stamp, packet, clock, zone = nil, nil, nil, nil
        ready = false
        generation = generation + 1
        revision = revision + 1
        droppedThroughRevision = revision
    end

    function roster.UnitsReceived() unitGeneration = unitGeneration + 1 end

    local function Change(kind, row, previous)
        table.insert(changes, {
            revision = revision,
            kind = kind,
            index = row.index,
            id = row.id,
            previousId = previous.id,
            state = row.state,
            previousState = previous.state,
            name = row.name,
        })
        if table.getn(changes) > MAX_CHANGES then
            local removed = table.remove(changes, 1)
            droppedThroughRevision = removed.revision
        end
    end

    -- Called only with copied rows from the existing accepted lair snapshot.
    -- The private source table is never read here or exposed to consumers.
    function roster.AcceptLairs(rows, updated, received, context)
        if not Active() or not Number(updated) or type(rows) ~= "table" then
            roster.Clear()
            return
        end
        if type(context) == "table" then
            zone = zone or {}
            zone.key = type(context.zone) == "string" and context.zone or nil
            zone.name = type(context.zname) == "string" and context.zname or nil
            zone.map = Number(context.map) and context.map or nil
        else
            zone = nil
        end
        if ready and stamp == updated and packet == received then return end
        local nextLairs, previous, seen = {}, {}, {}
        for _, row in ipairs(lairs) do
            previous[row.index] = row
        end
        for _, row in ipairs(rows) do
            if
                type(row) ~= "table"
                or not Integer(row.index, 1)
                or seen[row.index]
                or (row.state ~= "asleep" and row.state ~= "awake" and row.state ~= "empty")
                or not Integer(row.id, Living(row) and 1 or 0)
                or (row.state == "empty" and row.id ~= 0)
            then
                roster.Clear()
                return
            end
            seen[row.index] = true
            local copy = { index = row.index, id = row.id, state = row.state }
            if type(row.name) == "string" and row.name ~= "" then copy.name = row.name end
            for _, key in ipairs(copiedFields) do
                if Number(row[key]) then copy[key] = row[key] end
            end
            copy.key = tostring(row.index) .. ":" .. tostring(row.id)
            table.insert(nextLairs, copy)
        end
        revision = revision + 1
        if ready then
            for _, row in ipairs(nextLairs) do
                local old = previous[row.index]
                -- An initial/replayed row establishes a baseline. Missing lairs
                -- do not establish a death, and a new spawn is never the old one.
                if old then
                    if Living(old) and not Living(row) then
                        Change("vacated", row, old)
                    elseif not Living(old) and Living(row) then
                        Change("returned", row, old)
                    elseif Living(old) and Living(row) and old.id ~= row.id then
                        Change("replaced", row, old)
                    elseif old.state ~= row.state then
                        Change("state", row, old)
                    end
                end
            end
        end
        lairs, stamp, packet = nextLairs, updated, received
        local now = Native("AZS_GetRunTime")
        clock = Number(now) and now or nil
        ready = true
    end

    local function Health()
        for id in pairs(healthSeen) do healthSeen[id] = nil end
        local list
        if
            Number(_G.AZS_UNITS_UPDATED)
            and not (
                unitGeneration == blockedUnitGeneration
                and _G.AZS_UNITS == blockedUnits
                and _G.AZS_UNITS_UPDATED == blockedUnitStamp
            )
        then
            list = Native("AZS_GetGuardians")
        end
        if type(list) == "table" then
            for _, entry in ipairs(list) do
                if type(entry) == "table" and Integer(entry.id, 1) then
                    local id = entry.id
                    if healthSeen[id] then
                        health[id] = nil
                    elseif Number(entry.hp) and entry.hp >= 0 and Number(entry.hpm) and entry.hpm > 0 then
                        local unit = health[id] or {}
                        unit.hp, unit.maximum = entry.hp, entry.hpm
                        health[id] = unit
                    else
                        health[id] = nil
                    end
                    healthSeen[id] = true
                end
            end
        end
        for id in pairs(health) do
            if not healthSeen[id] then health[id] = nil end
        end
        return health
    end

    -- Callers may reuse their own copy; accepted private rows are never exposed.
    -- No UI clock advances gameplay.
    function roster.GetSnapshot(snapshot)
        snapshot = snapshot or { rows = {}, counts = {} }
        snapshot.revision, snapshot.generation, snapshot.status = revision, generation, "inactive"
        local counts = snapshot.counts
        counts.total, counts.living, counts.asleep, counts.fighting = 0, 0, 0, 0
        counts.returning, counts.due, counts.empty = 0, 0, 0
        if not Active() then
            for index in ipairs(snapshot.rows) do snapshot.rows[index] = nil end
            table.setn(snapshot.rows, 0)
            snapshot.zone = nil
            return snapshot
        end
        snapshot.status = ready and "ready" or "unavailable"
        if not ready then
            for index in ipairs(snapshot.rows) do snapshot.rows[index] = nil end
            table.setn(snapshot.rows, 0)
            snapshot.zone = nil
            return snapshot
        end
        snapshot.zone = zone and Copy(zone, snapshot.zone) or nil
        local health = Health()
        local now = Native("AZS_GetRunTime")
        local gap = 0
        if clock and Number(now) and now >= clock then gap = math.min(MAX_SMOOTHING, now - clock) end
        for index, entry in ipairs(lairs) do
            local row = Copy(entry, snapshot.rows[index])
            counts.total = counts.total + 1
            if Living(row) then
                row.status = row.state == "awake" and "fighting" or "asleep"
                counts.living = counts.living + 1
                local unit = health[row.id]
                if unit then
                    row.hp, row.maximum = unit.hp, unit.maximum
                    row.healthFraction = math.max(0, math.min(1, unit.hp / unit.maximum))
                end
            elseif Number(row.left) and row.left > 0 then
                row.status = "returning"
                row.remaining = math.max(0, row.left - gap)
            elseif row.left == 0 then
                -- Due is confirmed by the native snapshot. A cosmetic zero
                -- above never invents a return, spawn, or state transition.
                row.status, row.remaining = "due", 0
            else
                row.status = "empty"
            end
            counts[row.status] = counts[row.status] + 1
            snapshot.rows[index] = row
        end
        for index = table.getn(lairs) + 1, table.getn(snapshot.rows) do snapshot.rows[index] = nil end
        table.setn(snapshot.rows, table.getn(lairs))
        return snapshot
    end

    -- Optional future notification consumers use revision + generation as a
    -- cursor. Nothing emits chat, sound or alerts in this foundation.
    function roster.GetChanges(afterRevision, afterGeneration)
        local result = { revision = revision, generation = generation, entries = {}, reset = false }
        if not Active() or not ready then
            result.reset = true
            return result
        end
        if not Integer(afterRevision, 0) or afterRevision > revision or afterGeneration ~= generation then
            result.reset = true
            return result
        end
        result.truncated = afterRevision < droppedThroughRevision
        for _, change in ipairs(changes) do
            if change.revision > afterRevision then table.insert(result.entries, Copy(change)) end
        end
        return result
    end
end)
