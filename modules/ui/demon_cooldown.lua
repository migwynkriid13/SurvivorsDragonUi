-- Inferred recurring-summon timing from received native packets. The 0.113.2
-- scheduler and summon publication share the spawn clock; see docs/DEMON-COOLDOWN.md.
DFRL:NewMod("DemonCooldown", 3, function()
    local timer = {}
    DFRL.demonCooldown = timer
    local streams = {
        pets = { name = "AZS_PETS", stamp = "AZS_PETS_UPDATED", received = 0, consumed = 0 },
        stats = { name = "AZS_STATS", received = 0, consumed = 0 },
        run = { name = "AZS_RUN", stamp = "AZS_RUN_UPDATED", received = 0, consumed = 0 },
    }
    local prefixes = { AZSPETS = "pets", AZS = "stats", AZSRUN = "run" }
    local inWorld = true
    local PACKET_MARGIN = 0.11
    local spawn, expires, summonId, kind, icon, rawTime, birthFloor
    local acceptedPets, acceptedStamp, acceptedReceived

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Native(getter)
        if type(getter) ~= "function" then return end
        local ok, value = pcall(getter)
        if ok then return value end
    end
    local function ClearSpawn()
        spawn, expires, summonId, kind, icon = nil, nil, nil, nil, nil
    end
    local function Retire(keepPending)
        ClearSpawn()
        rawTime, birthFloor, acceptedPets, acceptedStamp, acceptedReceived = nil, nil, nil, nil, nil
        for _, stream in pairs(streams) do
            -- Preserve packets delivered since the last read when zone and
            -- snapshot messages arrive together. Other retained references retire.
            if not keepPending or stream.received == stream.consumed then
                stream.blocked = _G[stream.name]
                stream.blockedStamp = stream.stamp and _G[stream.stamp]
                stream.blockedReceived = stream.received
            end
        end
    end
    local function Packet(stream)
        local packet = _G[stream.name]
        local stamp = stream.stamp and _G[stream.stamp]
        if type(packet) ~= "table" or (stream.stamp and not Number(stamp)) then return end
        if
            packet == stream.blocked
            and stamp == stream.blockedStamp
            and stream.received == stream.blockedReceived
        then
            return
        end
        return packet, stamp
    end
    local function ReadPets(packet, now)
        local newest, birth, selectedKind
        local currentPresent = false
        for _, pet in ipairs(packet) do
            if type(pet) ~= "table" then return false end
            local matching = (pet.key == "felguard" and pet.kind == "felguard")
                or (pet.key == "pit_lord" and pet.kind == "pitlord")
            if matching then
                if
                    not Number(pet.id)
                    or pet.id <= 0
                    or pet.id ~= math.floor(pet.id)
                    or not Number(pet.ends)
                    or not Number(pet.dur)
                    or pet.dur <= 0
                    or pet.ends <= now - PACKET_MARGIN
                    or type(pet.icon) ~= "string"
                    or pet.icon == ""
                then
                    return false
                end
                local started = pet.ends - pet.dur
                if not Number(started) or started < 0 or started > now + PACKET_MARGIN then return false end
                -- These capstones are exclusive. Contradictory rosters do not
                -- establish which scheduler owns the next summon.
                if selectedKind and selectedKind ~= pet.kind then return false end
                selectedKind = pet.kind
                if pet.id == summonId and pet.kind == kind then currentPresent = true end
                if not birth or started > birth then newest, birth = pet, started end
            end
        end
        if birthFloor and birth and birth < birthFloor then return false end
        if spawn and not currentPresent and now < expires - PACKET_MARGIN and (not birth or birth <= spawn) then
            return false
        end
        if newest and (not spawn or kind ~= newest.kind or birth >= spawn) then
            spawn, expires, summonId = birth, newest.ends, newest.id
            kind, icon = newest.kind, newest.icon
            birthFloor = birth
        end
        return true
    end
    function timer.Read()
        if not inWorld then return end
        -- Phase precedes every retained table read. Raw packet time, rather
        -- than an interpolated getter correction, detects a restarted run.
        local phase = Native(_G.AZS_GetPhase)
        if not DFRL.navigation or not DFRL.navigation.IsRunPhase(phase) then
            Retire(false)
            return
        end
        local run = Packet(streams.run)
        if not run or not Number(run.t) or run.t < 0 then return end
        if rawTime and run.t < rawTime then
            Retire(true)
            run = Packet(streams.run)
            if not run then return end
        end
        rawTime = run.t
        local now = Native(_G.AZS_GetRunTime)
        if not Number(now) or now < 0 then return end
        local pets, stamp = Packet(streams.pets)
        local stats = Packet(streams.stats)
        if not pets or not stats or not Number(stats.cd) or stats.cd < 0 then return end
        if pets ~= acceptedPets or stamp ~= acceptedStamp or streams.pets.received ~= acceptedReceived then
            acceptedPets, acceptedStamp, acceptedReceived = pets, stamp, streams.pets.received
            if not ReadPets(pets, now) then
                ClearSpawn()
                return
            end
        end
        for _, stream in pairs(streams) do
            stream.consumed = stream.received
        end
        if not spawn then return end
        -- Packet values are rounded. This follows the recovered native rule,
        -- resynchronizing on each summon instead of running a private clock.
        local period = math.max(30 * stats.cd, 13)
        local remaining = math.max(spawn + period - now, 0)
        if not Number(period) or not Number(remaining) then return end
        return icon, remaining
    end
    function timer.Event(name, prefix)
        if name == "PLAYER_LEAVING_WORLD" or name == "PLAYER_LOGOUT" then
            inWorld = false
            Retire(false)
        elseif name == "PLAYER_ENTERING_WORLD" then
            inWorld = true
        elseif name == "CHAT_MSG_ADDON" then
            local key = prefixes[prefix]
            if key then streams[key].received = streams[key].received + 1 end
            if prefix == "AZSZONE" then Retire(true) end
        end
    end
end)
