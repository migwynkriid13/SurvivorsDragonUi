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
    local function Copy(row)
        local copy = {}
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
        zone = nil
        if type(context) == "table" then
            zone = {}
            if type(context.zone) == "string" then zone.key = context.zone end
            if type(context.zname) == "string" then zone.name = context.zname end
            if Number(context.map) then zone.map = context.map end
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
            for _, key in ipairs({ "left", "x", "y", "z", "mx", "my" }) do
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
        if not Number(_G.AZS_UNITS_UPDATED) then return {} end
        if
            unitGeneration == blockedUnitGeneration
            and _G.AZS_UNITS == blockedUnits
            and _G.AZS_UNITS_UPDATED == blockedUnitStamp
        then
            return {}
        end
        local list = Native("AZS_GetGuardians")
        if type(list) ~= "table" then return {} end
        local result, seen = {}, {}
        for _, entry in ipairs(list) do
            if type(entry) == "table" and Integer(entry.id, 1) then
                local id = entry.id
                if seen[id] then
                    result[id] = nil
                elseif Number(entry.hp) and entry.hp >= 0 and Number(entry.hpm) and entry.hpm > 0 then
                    result[id] = { hp = entry.hp, maximum = entry.hpm }
                end
                seen[id] = true
            end
        end
        return result
    end

    -- A fresh copy on every read prevents a future view from mutating the
    -- accepted data used by other consumers. No UI clock advances gameplay.
    function roster.GetSnapshot()
        local snapshot = {
            revision = revision,
            generation = generation,
            status = "inactive",
            rows = {},
            counts = { total = 0, living = 0, asleep = 0, fighting = 0, returning = 0, due = 0, empty = 0 },
        }
        if not Active() then return snapshot end
        snapshot.status = ready and "ready" or "unavailable"
        if not ready then return snapshot end
        if zone then snapshot.zone = Copy(zone) end
        local health = Health()
        local now = Native("AZS_GetRunTime")
        local gap = 0
        if clock and Number(now) and now >= clock then gap = math.min(MAX_SMOOTHING, now - clock) end
        for _, entry in ipairs(lairs) do
            local row = Copy(entry)
            local counts = snapshot.counts
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
            table.insert(snapshot.rows, row)
        end
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
