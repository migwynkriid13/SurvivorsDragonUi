-- CI only: the production v1 meter adapter over explicit native table boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "native meter fixtures require CI Lua 5.1")
local helperMode = ...

local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    print("PASS " .. name)
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do
        result[key] = Copy(child)
    end
    return result
end

local function Error(code)
    local value = { code = code, message = code, retryable = code == "NOT_READY" or code == "INTERNAL_ERROR" }
    if value.retryable then value.retryAfterSeconds = code == "INTERNAL_ERROR" and 1 or 0.2 end
    if code == "CHECKPOINT_INVALIDATED" then value.reason = "counter_epoch_changed" end
    return value
end

local languages = { "en", "pl", "cs", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko" }
local labels = {
    "Bite, rank=2; [pet]",
    "Ugryzienie",
    "Kousnutí",
    "Beißen",
    "Mordida",
    "Mordedura",
    "Morsure",
    "Mușcătură",
    "Isırık",
    "Укус",
    "Укус",
    "撕咬",
    "噛みつき",
    "물기",
}

local damage = { metric = "damage", scope = "self", period = "run", groupBy = "source" }
local healing =
    { metric = "healing", healingPerspective = "received", scope = "self", period = "run", groupBy = "source" }
local boss = { metric = "damage", scope = "self", period = "encounter", groupBy = "source" }
local party = { metric = "damage", scope = "party", period = "run", groupBy = "owner" }

local function Ranks(count)
    local records = {}
    for rank = count, 1, -1 do
        table.insert(records, {
            id = "flamestrike-rank-" .. rank,
            rowId = "flamestrike-leaf-" .. rank,
            abilityKey = "flamestrike",
            rank = rank,
            name = "Flamestrike",
            amount = rank * 10,
            recent = rank * 2,
            after = rank * 3,
        })
    end
    return records
end

local function TalentRanks(count, key, name)
    local records = Ranks(count)
    for _, record in ipairs(records) do
        record.talentKey = key or "shaman.enh_flametongue_weapon"
        record.id = "talent:" .. record.talentKey .. ":r" .. record.rank
        record.rowId = record.id .. ":leaf"
        record.kind, record.attribution, record.omitAbilityKey = "talent", "known", true
        record.abilityKey, record.proc = nil, true
        record.name = name or "Flametongue Weapon"
    end
    return records
end

local function TalentProcRanks(count)
    local records, origins = TalentRanks(count), {}
    for _, record in ipairs(records) do
        local key = record.id
        origins[key] = {
            sourceKey = key,
            kind = "talent",
            attribution = "known",
            talentKey = record.talentKey,
            rank = record.rank,
            name = record.name,
            icon = { status = "ready", path = "Interface\\Icons\\" .. key },
        }
        record.id, record.name = "fire-nova-origin-rank-" .. record.rank, "Fire Nova"
        record.kind, record.abilityKey, record.omitAbilityKey = "ability", "fire_nova", nil
        record.talentKey, record.origins, record.rank = nil, { key }, 1
    end
    return records, origins
end

local function TalentTriggers(talentKey, name, triggers)
    local records, originKey = Ranks(table.getn(triggers)), "talent:" .. talentKey .. ":r3"
    for index, trigger in ipairs(triggers) do
        local record = records[index]
        record.id, record.rowId = trigger.id, "trigger-leaf-" .. index
        record.name, record.abilityKey, record.rank =
            trigger.name or trigger.abilityKey, trigger.abilityKey, trigger.rank
        record.kind, record.attribution, record.proc, record.origins = "ability", "known", true, { originKey }
    end
    return records,
        {
            [originKey] = {
                sourceKey = originKey,
                kind = "talent",
                attribution = "known",
                rank = 3,
                talentKey = talentKey,
                name = name,
                icon = { status = "ready", path = "Interface\\Icons\\" .. originKey },
            },
        }
end

local function ItemRanks(count)
    local records = {}
    for rank = count, 1, -1 do
        table.insert(records, {
            id = "hakkar-rank-" .. rank,
            rowId = "hakkar-leaf-" .. rank,
            kind = "item",
            omitAbilityKey = true,
            itemKey = "eye_of_hakkar",
            itemInstanceKey = "hakkar-copy-one",
            itemId = 9000 + rank,
            rank = rank,
            name = "The Eye of Hakkar " .. rank,
            amount = rank * 10,
            recent = rank * 2,
            after = rank * 3,
        })
    end
    return records
end

local function ItemEffects(count)
    local records, origins = ItemRanks(count), {}
    for _, record in ipairs(records) do
        local origin = Copy(record)
        origin.sourceKey = origin.id
        origins[origin.sourceKey] = origin
        record.id = "hakkar-pulse-rank-" .. record.rank
        record.kind, record.abilityKey, record.omitAbilityKey = "effect", "hakkar-pulse", nil
        record.origins = { origin.sourceKey }
        record.itemKey, record.itemInstanceKey, record.itemId, record.rank = nil, nil, nil, nil
    end
    return records, origins
end

local function ItemCasters()
    local ranks, records = ItemRanks(2), {}
    local actors = {
        { "hero-1", "hero", "Hero" },
        { "searing-1", "totem", "Searing Totem", "searing" },
        { "magma-1", "totem", "Magma Totem", "magma" },
        { "searing-2", "totem", "Searing Totem", "searing" },
        { "pet-1", "pet", "Wolf" },
    }
    for index, actor in ipairs(actors) do
        local record = Copy(ranks[index % 2 + 1])
        record.rowId = "item-caster-leaf-" .. index
        record.actorId, record.actorKind, record.actorName, record.totemKey = actor[1], actor[2], actor[3], actor[4]
        record.amount, record.recent, record.after = index * 10, index * 2, index * 3
        records[index] = record
    end
    return records
end

local function TotemItems(count)
    local effects, origins = ItemEffects(1)
    local records = {}
    for index = 1, count do
        local record = Copy(effects[1])
        record.rowId, record.actorId = "totem-item-leaf-" .. index, "totem-" .. index
        record.actorKind, record.actorName, record.totemKey = "totem", "Searing Totem", "searing"
        records[index] = record
    end
    return records, origins
end

local function Talents()
    local records = {
        { id = "pyroblast-normal", rowId = "pyroblast-normal", name = "Pyroblast", amount = 9400 },
        { id = "pyroblast-proc", rowId = "pyroblast-proc", name = "Pyroblast", amount = 4900, origin = "hot-streak" },
        { id = "holy-nova-proc", rowId = "holy-nova-proc", name = "FX Holy nova", amount = 2900, origin = "chastise" },
        { id = "fire-nova-proc", rowId = "fire-nova-proc", name = "Fire Nova", amount = 1900, origin = "shaman-proc" },
    }
    local origins = {
        ["hot-streak"] = { name = "Hot Streak", talentKey = "hot_streak", art = "hot-streak-talent" },
        chastise = { name = "Chastise", talentKey = "chastise", art = "chastise-talent" },
        ["shaman-proc"] = { name = "Received shaman talent", talentKey = "native_shaman_talent", art = "shaman-talent" },
    }
    for _, record in ipairs(records) do
        record.abilityKey = string.find(record.id, "pyroblast", 1, true) and "pyroblast" or record.id
        record.rank, record.recent, record.after = 1, record.amount / 5, record.amount / 10
        record.proc, record.origins = record.origin ~= nil, record.origin and { record.origin } or {}
    end
    for key, origin in pairs(origins) do
        origin.sourceKey, origin.kind, origin.attribution = key, "talent", "known"
        origin.nameLanguageCode, origin.spellIds, origin.originSourceKeys, origin.relatedSourceKeys = "en", {}, {}, {}
        origin.icon = { status = "ready", path = "Interface\\Icons\\" .. origin.art }
        origin.art = nil
    end
    return records, origins
end

local function Pets()
    local records = {
        { id = "shadowbolt", rowId = "hero-bolt", name = "Shadowbolt", amount = 100, recent = 50, after = 10 },
        { id = "shadowbolt", rowId = "imp-one-bolt", name = "Shadowbolt", amount = 40, recent = 20, after = 4 },
        { id = "shadowbolt", rowId = "imp-two-bolt", name = "Shadowbolt", amount = 20, recent = 10, after = 2 },
        { id = "hellfire", rowId = "imp-one-fire", name = "Hellfire", amount = 60, recent = 30, after = 6 },
    }
    for index, record in ipairs(records) do
        record.abilityKey, record.rank = record.id, 1
        if index > 1 then
            record.actorId = index == 3 and "imp-2" or "imp-1"
            record.actorKind, record.actorName, record.summonKey = "summon", "Imp", "imp"
            record.actorPortrait = { portraitKey = "portrait-" .. record.actorId, status = "ready" }
        end
    end
    return records
end

local function Native()
    local c = H.New()
    local env = c.env
    local state = { calls = {}, released = {}, queries = {}, serial = 1, nextCheckpoint = 0, recentStatus = "ready" }
    state.context = {
        apiVersion = 1,
        uiSessionId = "ui-1",
        runId = "run-1",
        authorityId = "authority-1",
        counterEpoch = "epoch-1",
        snapshotId = "snapshot-1",
        counterRevision = "counter-1",
        metadataRevision = "metadata-1",
        languageCode = "en",
        languageRevision = "language-1",
        phase = "playing",
        asOfRunSeconds = 20,
        localOwnerId = "hero-1",
        partyState = "active",
        partyId = "party-1",
        encounter = {
            encounterId = "encounter-1",
            state = "active",
            startRunSeconds = 10,
            startFenceId = "fence-start",
            bossActorIds = { "boss-1" },
        },
    }
    state.capabilities = {
        apiVersion = 1,
        apiMinor = 0,
        uiSessionId = "ui-1",
        languageCode = "en",
        languageRevision = "language-1",
        metrics = { "damage", "healing" },
        healingPerspectives = { "received", "performed" },
        scopes = { "self", "party", "owner" },
        periods = { "run", "encounter" },
        groupings = { "source", "owner", "actor_source", "detail" },
        minWindowSeconds = 5,
        maxWindowSeconds = 120,
        historyResolutionSeconds = 0,
        maxCheckpoints = 64,
        languageCodes = languages,
        features = {
            liveInstancePosition = true,
            completeSourceBreakdowns = true,
            partySourceBreakdowns = true,
            partyHealing = true,
            performedHealing = true,
            nativeSourceIcons = true,
            currentLoadouts = true,
            partyLoadouts = true,
            retainedPortraits = true,
            atomicCheckpoints = true,
            nativeRecentWindows = true,
            localizedMetadata = true,
        },
    }
    state.records = {
        { id = "source-a", rowId = "leaf-a", name = "Same name", amount = 100, recent = 50, actorId = "pet-1" },
        { id = "source-b", rowId = "leaf-b", name = "Same name", amount = 40, recent = 10, actorId = "hero-1" },
    }
    local function Call(name) state.calls[name] = (state.calls[name] or 0) + 1 end
    local function Rate(amount, start, ending, status)
        local elapsed = ending - start
        local value = {
            status = status or "ready",
            amount = amount,
            startRunSeconds = start,
            endRunSeconds = ending,
            elapsedSeconds = elapsed,
            denominatorSeconds = math.max(1, elapsed),
            resolutionSeconds = 0,
            approximate = false,
        }
        if value.status == "ready" then value.value = amount / value.denominatorSeconds end
        if value.status == "unavailable" then
            value.amount, value.denominatorSeconds, value.resolutionSeconds, value.approximate = nil, nil, nil, nil
            value.reason = "history_gap"
        end
        return value
    end
    local function Stats(query, amount, recent, checkpointAmount, sourceRecentStatus)
        local ending = state.context.asOfRunSeconds
        local start = query.period == "encounter" and 10 or 0
        local result = { periodAmount = amount, displayAmount = amount, periodAverage = Rate(amount, start, ending) }
        if query.checkpointId then
            result.sinceCheckpointAmount = checkpointAmount or 0
            result.displayAmount = result.sinceCheckpointAmount
            result.checkpointAverage = Rate(result.displayAmount, state.checkpoint.atRunSeconds, ending)
        end
        result.recentRate = { status = "not_requested" }
        if query.windowSeconds > 0 then
            local recentStart =
                math.max(start, ending - query.windowSeconds, query.checkpointId and state.checkpoint.atRunSeconds or 0)
            if query.checkpointId then recent = math.min(recent, checkpointAmount or 0) end
            local recentStatus = sourceRecentStatus or state.recentStatus
            if recentStatus == "ready" and ending - recentStart < 1 then recentStatus = "warming_up" end
            result.recentRate = Rate(recent, recentStart, ending, recentStatus)
            if recentStatus ~= "unavailable" then result.windowAmount = recent end
        end
        result.displayRate = query.windowSeconds > 0 and result.recentRate
            or result.checkpointAverage
            or result.periodAverage
        return result
    end
    function state:Snapshot(query)
        local response = {
            apiVersion = 1,
            status = "ready",
            complete = true,
            context = Copy(self.context),
            query = Copy(query),
            ownerIds = {},
            amountBasis = query.checkpointId and "checkpoint" or "period",
            contributions = {},
            rows = {},
            maxRowAmount = 0,
            sources = {},
            actors = {},
            period = {
                kind = query.period,
                startRunSeconds = query.period == "encounter" and 10 or 0,
                endRunSeconds = self.context.asOfRunSeconds,
            },
        }
        response.period.elapsedSeconds = response.period.endRunSeconds - response.period.startRunSeconds
        if query.period == "encounter" then response.period.encounter = Copy(self.context.encounter) end
        response.actors["boss-1"] = {
            actorId = "boss-1",
            kind = "enemy",
            name = "Boss",
            nameLanguageCode = self.context.languageCode,
            state = "present",
            portrait = { portraitKey = "portrait-boss-1", status = "missing", reason = "not_applicable" },
        }
        local amount, recent, after = 0, 0, 0
        local owners = {}
        for index, record in ipairs(self.records) do
            local owner = record.ownerId or "hero-1"
            local actor = record.actorId or owner
            if not owners[owner] then table.insert(response.ownerIds, owner) end
            owners[owner] = true
            response.actors[owner] = {
                actorId = owner,
                kind = "hero",
                name = record.heroName or "Hero",
                classKey = record.class or "hunter",
                nameLanguageCode = "und",
                state = record.departed and "departed" or "present",
                portrait = { status = "ready", portraitKey = record.portraitKey or "portrait-" .. owner },
            }
            if actor ~= owner then
                response.actors[actor] = {
                    actorId = actor,
                    kind = record.actorKind or "pet",
                    name = record.actorName or "Hunter pet",
                    nameLanguageCode = self.context.languageCode,
                    state = record.actorState or "despawned",
                    parentActorId = owner,
                    currentOwnerId = owner,
                    petFamilyKey = record.petFamilyKey or "wolf",
                    summonKey = record.summonKey,
                    totemKey = record.totemKey,
                    portrait = record.actorPortrait
                        or { portraitKey = "portrait-" .. actor, status = "missing", reason = "not_available" },
                }
            end
            response.sources[record.id] = {
                sourceKey = record.id,
                kind = record.kind or "ability",
                attribution = record.attribution,
                name = record.name,
                nameLanguageCode = self.context.languageCode,
                icon = record.icon or { status = "ready", path = "Interface\\Icons\\" .. record.id },
                spellIds = {},
                originSourceKeys = Copy(record.definitionOrigins or {}),
                relatedSourceKeys = {},
                abilityKey = not record.omitAbilityKey and (record.abilityKey or record.id) or nil,
                rank = record.rank,
                variantKey = record.variantKey,
                itemInstanceKey = record.itemInstanceKey,
                talentKey = record.talentKey,
                itemKey = record.itemKey,
                itemId = record.itemId,
            }
            local leaf = Stats(query, record.amount, record.recent, record.after, record.recentStatus)
            leaf.rowId, leaf.ownerId, leaf.actorId, leaf.sourceKey = record.rowId, owner, actor, record.id
            leaf.nativeProc, leaf.periodicity = record.proc == true, record.periodic and "periodic" or "non_periodic"
            leaf.reflection, leaf.schoolState, leaf.schoolMask = "not_reflected", "known", 1
            leaf.creditKind = query.metric == "healing" and "health_restored" or "health_damage"
            leaf.sourceOwnerState, leaf.sourceOwnerId = "known", owner
            if query.metric == "healing" then
                leaf.recipientActorId, leaf.recipientOwnerState, leaf.recipientOwnerId = owner, "known", owner
            end
            leaf.originSourceKeys, leaf.tieOrder = Copy(record.origins or {}), index
            local row = Stats(query, record.amount, record.recent, record.after, record.recentStatus)
            row.rowId, row.memberIds, row.rank = "group-" .. record.rowId, { record.rowId }, index
            row.actorId = actor
            row.ownerId, row.sourceKey, row.nativeProc, row.tieOrder = owner, record.id, leaf.nativeProc, index
            row.procClassification = leaf.nativeProc and "proc" or "non_proc"
            if query.groupBy == "owner" then
                row.rowId, row.actorId, row.sourceKey, row.nativeProc = "owner-" .. owner, nil, nil, nil
            elseif query.groupBy ~= "actor_source" then
                row.actorId = nil
            end
            amount, recent, after = amount + record.amount, recent + record.recent, after + (record.after or 0)
            table.insert(response.contributions, leaf)
            if row.displayAmount > 0 then
                table.insert(response.rows, row)
                response.maxRowAmount = math.max(response.maxRowAmount, row.displayAmount)
            end
        end
        for key, descriptor in pairs(self.extraSources or {}) do
            response.sources[key] = Copy(descriptor)
        end
        response.totals = Stats(query, amount, recent, after)
        for _, leaf in ipairs(response.contributions) do
            leaf.share = response.totals.displayAmount > 0 and leaf.displayAmount / response.totals.displayAmount or 0
        end
        for _, row in ipairs(response.rows) do
            row.share = row.displayAmount / response.totals.displayAmount
        end
        if table.getn(response.rows) == 0 then response.status = "ready_empty" end
        if query.checkpointId then response.checkpoint = Copy(self.checkpoint) end
        return response
    end
    env.AZS_GetMeterCapabilities = function()
        Call("capabilities")
        return Copy(state.capabilities), nil
    end
    env.AZS_GetMeterContext = function()
        Call("context")
        if state.contextError then return nil, state.contextError end
        return Copy(state.context), nil
    end
    env.AZS_GetMeterSnapshot = function(query)
        Call("snapshot")
        table.insert(state.queries, Copy(query))
        if state.snapshotError then return nil, state.snapshotError end
        state.lastResponse = state:Snapshot(query)
        if state.malformed then state.lastResponse.sources = {} end
        if state.mutate then state.mutate(state.lastResponse) end
        return state.lastResponse, nil
    end
    env.AZS_CreateMeterCheckpoint = function(runId)
        Call("create")
        assert(runId == state.context.runId, "checkpoint used a stale or inferred run identity")
        if state.createError then return nil, state.createError end
        state.nextCheckpoint = state.nextCheckpoint + 1
        state.checkpoint = {
            checkpointId = "checkpoint-" .. state.nextCheckpoint,
            runId = runId,
            uiSessionId = state.context.uiSessionId,
            authorityId = state.context.authorityId,
            counterEpoch = state.context.counterEpoch,
            atRunSeconds = state.context.asOfRunSeconds,
            fenceId = "reset-fence-" .. state.nextCheckpoint,
        }
        return Copy(state.checkpoint), nil
    end
    env.AZS_ReleaseMeterCheckpoint = function(token)
        Call("release")
        table.insert(state.released, token)
        if state.releaseError then return nil, state.releaseError end
        return true, nil
    end
    env.AZS_SetMeterPortrait = function()
        Call("portrait")
        return true, nil
    end
    env.AZS_GetPlayerPosition = function() error("the meter queried live player coordinates") end
    env.AZS_GetMeterLoadout = function() error("the meter scanned the current loadout for historical metadata") end
    env.AZS_GetMeter = function() error("native v1 adapter fell back to legacy damage") end
    env.AZS_GetHealing = function() error("native v1 adapter fell back to legacy healing") end
    env.AZS_GetBossMeter = function() error("native v1 adapter fell back to legacy bosses") end
    env.AZS_GetPartyMeter = function() error("native v1 adapter fell back to legacy party") end
    env.DFRL.sct = { GetSourceIcon = function() error("native v1 adapter guessed an icon from a name") end }
    env.UnitName = function() error("native v1 adapter matched a historical hero by current unit name") end
    c:Load("core/meter_api.lua")
    return c, state, env.T.NewNativeMeter(), env
end

if helperMode == "helpers" then
    return {
        New = Native,
        languages = languages,
        labels = labels,
        Ranks = Ranks,
        TalentRanks = TalentRanks,
        TalentTriggers = TalentTriggers,
        ItemRanks = ItemRanks,
        ItemCasters = ItemCasters,
        TotemItems = TotemItems,
        Pets = Pets,
        Talents = Talents,
    }
end

Test("missing native endpoints retain the legacy selection boundary", function()
    local c = H.New()
    c:Load("core/meter_api.lua")
    assert(not c.env.T.NewNativeMeter().Supported(), "missing API selected the native v1 path")
end)

Test("native source keys preserve equal labels, original values and authoritative icons", function()
    local _, state, meter = Native()
    assert(meter.Supported(), "complete native endpoint set was not detected")
    local source, total, rate, message, revision, meta = meter.Read(damage, 10)
    assert(source and not message and revision and meta, "ready native snapshot was rejected")
    assert(table.getn(source) == 2 and total == 140 and rate == 6, "native totals or recent rates were recalculated")
    assert(source[1].name == source[2].name and source[1].rowId ~= source[2].rowId, "equal labels collapsed native IDs")
    assert(source[1].dmg == 100 and source[2].dmg == 40, "native source amounts changed")
    assert(source[1].icon == "Interface\\Icons\\source-a" and source[2].icon == "Interface\\Icons\\source-b")
    assert(meta.averageRate == 7 and meta.runId == "run-1", "whole-run averages lost their native basis")
    assert(state.queries[1].apiVersion == 1 and state.queries[1].runId == "run-1")
    assert(state.queries[1].windowSeconds == 10 and state.queries[1].checkpointId == nil)
end)

Test("all native catalog languages keep literal source labels and distinct metadata", function()
    local _, state, meter = Native()
    for index, language in ipairs(languages) do
        state.context.languageCode, state.context.languageRevision = language, "language-" .. index
        state.context.metadataRevision, state.context.snapshotId = "metadata-" .. index, "snapshot-" .. index
        state.records[1].name = labels[index]
        state.records[2].name = "123"
        local source, _, _, message, _, meta = meter.Read(damage, 10)
        assert(source and not message and source[1].name == labels[index], "native translated label was rewritten")
        assert(source[2].name == "123" and type(source[2].name) == "string", "numeric-looking source name changed type")
        assert(meta.languageCode == language, "native metadata did not follow the selected game language")
    end
end)

Test("native view queries preserve healing, boss and party scopes", function()
    local _, state, meter = Native()
    for _, view in ipairs({ healing, boss, party }) do
        state.records = {
            { id = "a", rowId = "a", name = "Ability", amount = 100, recent = 10, ownerId = "hero-1" },
            {
                id = "b",
                rowId = "b",
                name = "Ability",
                amount = 40,
                recent = 4,
                ownerId = view.scope == "party" and "hero-2" or "hero-1",
                departed = view.scope == "party",
            },
        }
        local source, total, _, message = meter.Read(view, 0)
        assert(source and not message and total == 140, "native view was treated as an unavailable legacy publication")
        local query = state.queries[table.getn(state.queries)]
        assert(query.metric == view.metric and query.scope == view.scope and query.period == view.period)
        assert(
            query.groupBy == view.groupBy and query.windowSeconds == 0,
            "view query changed native grouping/rate scope"
        )
        if view.healingPerspective then assert(query.healingPerspective == "received") end
        if view.party or view.scope == "party" then
            assert(source[1].portraitKey == "portrait-hero-1" and source[2].portraitKey == "portrait-hero-2")
            assert(
                source[2].portraitRunId == "run-1" and source[2].class == "hunter",
                "retained hero metadata disappeared"
            )
        end
    end
end)

Test("native warmup and history gaps retain totals without fabricating rates", function()
    local _, state, meter = Native()
    state.context.asOfRunSeconds, state.context.encounter = 0.5, nil
    state.recentStatus = "warming_up"
    local source, total, rate, message = meter.Read(damage, 10)
    assert(
        source and total == 140 and rate == nil and not message,
        "native warmup invented a DPS value or hid counters"
    )
    assert(source[1].dps == nil, "native warmup source invented a rate")
    state.context.asOfRunSeconds = 20
    state.recentStatus = "unavailable"
    source, total, rate, message = meter.Read(damage, 10)
    assert(source and total == 140 and rate == nil and not message, "native history gap erased valid amounts")
    state.recentStatus = "ready"
    source, total, rate, message = meter.Read(damage, 0)
    assert(source and total == 140 and rate == 7 and not message, "All reused a recent or UI-clock rate")
end)

Test("X captures immediately and failed replacement retains the prior checkpoint", function()
    local _, state, meter = Native()
    assert(meter.Read(damage, 10))
    local reads = state.calls.snapshot
    assert(meter.Reset(), "native checkpoint capture failed")
    assert(
        state.calls.create == 1 and state.calls.snapshot == reads,
        "X deferred its capture or read counters in its place"
    )
    assert(meter.IsReset(), "successful native X did not activate its session")
    local source, total = meter.Read(damage, 10)
    assert(source and table.getn(source) == 0 and total == 0, "post-X empty snapshot replayed full-run totals")
    assert(state.queries[table.getn(state.queries)].checkpointId == "checkpoint-1")
    state.createError = Error("NOT_READY")
    assert(not meter.Reset(), "failed native X was treated as a successful baseline")
    assert(not state.calls.release, "failed checkpoint replacement released the active session")
    state.records[1].after, state.records[2].after = 20, 10
    source, total = meter.Read(damage, 10)
    assert(source and total == 30, "failed replacement discarded the previous native checkpoint")
    assert(state.queries[table.getn(state.queries)].checkpointId == "checkpoint-1")
    state.createError = nil
    assert(meter.Reset())
    assert(state.released[1] == "checkpoint-1", "successful replacement did not release the prior checkpoint")
    meter.Clear()
    assert(
        state.released[2] == "checkpoint-2" and not meter.IsReset(),
        "cleanup did not retire the native reset session"
    )
    local releases = state.calls.release
    meter.Clear()
    assert(state.calls.release == releases, "settled cleanup released a checkpoint twice")
end)

Test("waiting and invalid native publications never replay old rows or use legacy counters", function()
    local c, state, meter = Native()
    assert(meter.Read(damage, 10))
    state.snapshotError = Error("NOT_READY")
    local source, _, _, message = meter.Read(damage, 10)
    assert(not source and not message, "native wait reused old rows or invented an error caption")
    state.snapshotError, state.malformed = nil, true
    c.now = c.now + 0.21
    source, _, _, message = meter.Read(damage, 10)
    assert(not source and message == "Meter data is unavailable.", "malformed native source references were accepted")
    state.malformed = false
    assert(meter.Read(damage, 10), "a fresh coherent publication did not recover")
    assert(meter.Reset())
    state.context.counterEpoch = "epoch-2"
    state.snapshotError = Error("CHECKPOINT_INVALIDATED")
    source = meter.Read(damage, 10)
    assert(not source and meter.IsReset(), "invalidated checkpoint exposed pre-X totals")
    source = meter.Read(damage, 10)
    assert(not source and meter.IsReset(), "later poll silently removed an invalid reset fence")
end)

Test("context errors honor native retry delays without returning an old phase", function()
    local c, state, meter = Native()
    state.contextError = Error("INTERNAL_ERROR")
    local context, failure = meter.Context()
    assert(not context and failure.code == "INTERNAL_ERROR" and state.calls.context == 1)
    state.contextError = nil
    for _ = 1, 4 do
        c.now = c.now + 0.2
        context, failure = meter.Context()
        assert(not context and failure.code == "INTERNAL_ERROR", "deferred context error returned an old valid phase")
    end
    assert(
        state.calls.context == 1 and not state.calls.snapshot,
        "context backoff polled native state before its deadline"
    )
    c.now = c.now + 0.21
    assert(meter.Context() and state.calls.context == 2, "context did not recover at the native retry deadline")
    c.now, state.contextError = 10, Error("INTERNAL_ERROR")
    assert(not meter.Context() and state.calls.context == 3)
    c.now, state.contextError = 9, nil
    assert(meter.Context() and state.calls.context == 4, "UI-clock regression retained an unusable context deadline")
end)

Test("snapshot backoff is independent for the four exact view queries", function()
    local c, state, meter = Native()
    state.snapshotError = Error("INTERNAL_ERROR")
    for _, view in ipairs({ damage, healing, boss, party }) do
        local source, _, _, message = meter.Read(view, view == damage and 10 or 0)
        assert(not source and message == "Meter data is unavailable.", "native view error exposed cached rows")
    end
    assert(state.calls.snapshot == 4, "one view's retry deadline blocked an independent native query")
    c.now = c.now + 0.2
    for _, view in ipairs({ damage, healing, boss, party }) do
        assert(not meter.Read(view, view == damage and 10 or 0))
    end
    assert(state.calls.snapshot == 4, "view errors ignored the native one-second retry delay")
    state.snapshotError = nil
    c.now = c.now + 0.81
    local source, total, rate = meter.Read(damage, 10)
    assert(
        source and total == 140 and rate == 6 and state.calls.snapshot == 5,
        "native retry changed rate timing or failed to recover"
    )
end)

Test("snapshot query changes and native epoch changes retire only their own retry state", function()
    local c, state, meter = Native()
    state.snapshotError = Error("NOT_READY")
    assert(not meter.Read(damage, 10) and state.calls.snapshot == 1)
    state.snapshotError = nil
    local source, _, rate = meter.Read(damage, 0)
    assert(source and rate == 7 and state.calls.snapshot == 2, "All inherited a different window's native error")
    assert(not meter.Read(damage, 10) and state.calls.snapshot == 2, "unchanged failed query skipped its retry delay")
    state.context.counterEpoch = "epoch-2"
    assert(meter.Read(damage, 10) and state.calls.snapshot == 3, "new native epoch reused an old snapshot error")
    c.now, state.snapshotError = 10, Error("INTERNAL_ERROR")
    assert(not meter.Read(damage, 10) and state.calls.snapshot == 4)
    c.now, state.snapshotError = 9, nil
    assert(
        meter.Read(damage, 10) and state.calls.snapshot == 5,
        "UI-clock regression prevented native snapshot recovery"
    )
end)

Test("native readiness failures stay on the selected native path", function()
    do
        local _, state, meter = Native()
        state.capabilities.apiVersion = 2
        assert(meter.Supported())
        local source = meter.Read(damage, 10)
        assert(not source and meter.Supported(), "unsupported native version switched to legacy accounting")
    end
    do
        local _, state, meter, env = Native()
        state.capabilities.features.nativeRecentWindows = false
        assert(meter.Supported())
        local source = meter.Read(damage, 10)
        assert(not source and meter.Supported(), "unsupported native window fell back to a local DPS approximation")
        env.AZS_GetMeterSnapshot = function() error("injected native API failure") end
        source = meter.Read(damage, 0)
        assert(not source and meter.Supported(), "a thrown native failure changed the accounting source")
    end
end)

Test("a native response cannot smuggle another query or alter the captured reset fence", function()
    local _, state, meter = Native()
    assert(meter.Read(damage, 10))
    state.mutate = function(snapshot) snapshot.query.checkpointId = "unrequested-checkpoint" end
    local source, _, _, message = meter.Read(damage, 10)
    assert(
        not source and message == "Meter data is unavailable.",
        "native response silently changed the requested accounting period"
    )
    state.mutate = nil
    assert(meter.Reset())
    state.mutate = function(snapshot) snapshot.checkpoint.fenceId = "unrelated-fence" end
    source, _, _, message = meter.Read(damage, 10)
    assert(
        not source and message == "Meter data is unavailable.",
        "native response changed an existing checkpoint's fence"
    )
end)

Test("checkpoint cleanup retries only unresolved native resources", function()
    local c, state, meter = Native()
    assert(meter.Read(damage, 10) and meter.Reset())
    state.releaseError = Error("INTERNAL_ERROR")
    meter.Clear()
    assert(meter.PendingCleanup(), "failed native release was forgotten")
    local reads = state.calls.snapshot
    state.releaseError = nil
    c.now = c.now + 1.01
    meter.Clear()
    assert(
        not meter.PendingCleanup() and state.calls.snapshot == reads,
        "cleanup collected counters or retained settled work"
    )
end)

Test("nine native ability ranks form one ordered row without changing native counters", function()
    local _, state, meter = Native()
    state.records = Ranks(9)
    table.insert(state.records, 1, { id = "other", rowId = "other", name = "Other", amount = 200, recent = 40 })
    local source, total, rate, message, _, meta = meter.Read(damage, 10)
    assert(source and not message and table.getn(source) == 2, "nine ranks became nine displayed ability rows")
    assert(source[1].name == "Flamestrike" and source[1].dmg == 450 and source[2].name == "Other")
    assert(source[1].dps == 9 and source[1].averageDps == 22.5, "grouped native rates were not summed")
    assert(source[1].share == 450 / 650 and total == 650 and rate == 13 and meta.averageRate == 32.5)
    assert(source[1].icon == "Interface\\Icons\\flamestrike-rank-9", "group did not use highest-rank metadata")
    assert(table.getn(state.lastResponse.rows) == 10 and table.getn(state.lastResponse.contributions) == 10)
    for index = 1, 9 do
        local rank = 10 - index
        assert(state.lastResponse.rows[index + 1].displayAmount == rank * 10, "grouping rewrote a native source amount")
        assert(state.lastResponse.sources["flamestrike-rank-" .. rank].rank == rank)
    end
    local identity = source[1].rowId
    state.records = Ranks(10)
    state.context.snapshotId, state.context.counterRevision = "rank-ten", "rank-ten"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 550 and source[1].dps == 11)
    assert(source[1].rowId == identity, "adding a new rank restarted the displayed ability identity")
    assert(source[1].icon == "Interface\\Icons\\flamestrike-rank-10")
end)

Test("native rank groups preserve explicit family distinctions and ambiguous ranks", function()
    local distinctions = {
        { "abilityKey", "ability-a", "ability-b" },
        { "variantKey", "direct", "periodic" },
        { "itemInstanceKey", "item-one", "item-two" },
        { "talentKey", "talent-one", "talent-two" },
        { "itemKey", "item-one", "item-two" },
        { "itemId", 101, 102 },
        { "kind", "ability", "effect" },
        { "rank" },
        { "proc", false, true },
        { "omitAbilityKey", true, true },
    }
    for _, distinction in ipairs(distinctions) do
        local _, state, meter = Native()
        state.records = Ranks(2)
        state.records[1][distinction[1]], state.records[2][distinction[1]] = distinction[2], distinction[3]
        local source = assert(meter.Read(damage, 10))
        assert(table.getn(source) == 2, "rank grouping collapsed distinct " .. distinction[1] .. " values")
    end
    do
        local _, state, meter = Native()
        state.records = Ranks(2)
        state.records[1].ownerId, state.records[2].ownerId = "hero-1", "hero-2"
        local source = assert(meter.Read({ metric = "damage", scope = "party", period = "run", groupBy = "source" }, 0))
        assert(table.getn(source) == 2, "rank grouping merged different accounting heroes")
    end
    do
        local _, state, meter = Native()
        state.records = Ranks(3)
        state.records[2].rank, state.records[3].rank = 1, 1
        local source = assert(meter.Read(damage, 10))
        assert(table.getn(source) == 3, "same-rank ambiguity partially merged a native family")
        for _, row in ipairs(source) do
            assert(type(row.rowId) == "string", "ambiguous family lost its individual native row IDs")
        end
    end
end)

Test("native rank groups retain missing rates and highest-rank artwork readiness", function()
    local _, state, meter = Native()
    state.records = Ranks(3)
    state.recentStatus = "unavailable"
    local source, total, rate = meter.Read(damage, 10)
    assert(table.getn(source) == 1 and source[1].dmg == 60 and total == 60)
    assert(source[1].dps == nil and rate == nil and source[1].averageDps == 3)
    state.records[2].recentStatus, state.records[3].recentStatus = "ready", "ready"
    source = assert(meter.Read(damage, 10))
    assert(source[1].dps == nil, "later known ranks replaced an unknown member's rate")
    state.records[2].recentStatus, state.records[3].recentStatus = nil, nil
    state.context.asOfRunSeconds, state.context.encounter = 0.5, nil
    state.recentStatus = "warming_up"
    source = assert(meter.Read(damage, 10))
    assert(source[1].dps == nil, "rank aggregation manufactured a warming-up DPS value")
    state.context.asOfRunSeconds, state.recentStatus = 20, "ready"
    state.records[1].icon = { status = "pending", retryAfterSeconds = 0.2 }
    state.context.metadataRevision, state.context.snapshotId = "rank-art-pending", "rank-art-pending"
    source = assert(meter.Read(damage, 10))
    assert(source[1].icon == nil and source[1].iconStatus == "pending", "group borrowed old-rank art while pending")
    state.records[1].icon = { status = "missing", reason = "not_available" }
    state.context.metadataRevision, state.context.snapshotId = "rank-art-missing", "rank-art-missing"
    source = assert(meter.Read(damage, 10))
    assert(source[1].icon == nil and source[1].iconStatus == "missing")
    state.records[1].icon = { status = "ready", path = "Interface\\Icons\\new-rank-art" }
    state.context.metadataRevision, state.context.snapshotId = "rank-art-ready", "rank-art-ready"
    source = assert(meter.Read(damage, 10))
    assert(source[1].icon == "Interface\\Icons\\new-rank-art", "rank metadata readiness never recovered")
end)

Test("rank grouping uses native checkpoint deltas across language and later upgrades", function()
    local _, state, meter = Native()
    state.records = Ranks(3)
    local source = assert(meter.Read(damage, 0))
    assert(table.getn(source) == 1 and source[1].dmg == 60)
    assert(meter.Reset())
    state.context.asOfRunSeconds = 22
    source = assert(meter.Read(damage, 0))
    assert(table.getn(source) == 1 and source[1].dmg == 18 and source[1].dps == 9)
    assert(source[1].share == 1)
    local identity = source[1].rowId
    local checkpoint = state.queries[table.getn(state.queries)].checkpointId
    for _, record in ipairs(state.records) do
        record.name = "Flammenstoß"
    end
    state.context.languageCode, state.context.languageRevision = "de", "rank-language-de"
    state.context.metadataRevision, state.context.snapshotId = "rank-meta-de", "rank-snapshot-de"
    source = assert(meter.Read(damage, 0))
    assert(source[1].name == "Flammenstoß" and source[1].rowId == identity and source[1].dmg == 18)
    assert(state.queries[table.getn(state.queries)].checkpointId == checkpoint)
    table.insert(state.records, 1, {
        id = "flamestrike-rank-4",
        rowId = "flamestrike-leaf-4",
        abilityKey = "flamestrike",
        rank = 4,
        name = "Flammenstoß",
        amount = 40,
        recent = 8,
        after = 12,
    })
    state.context.snapshotId, state.context.counterRevision = "rank-four-after-X", "rank-four-after-X"
    source = assert(meter.Read(damage, 0))
    assert(source[1].dmg == 30 and source[1].dps == 15 and source[1].rowId == identity)
    assert(state.queries[table.getn(state.queries)].checkpointId == checkpoint, "rank change replaced the native fence")
end)

Test("item ranks combine native item IDs using the explicit family in all source views", function()
    for _, view in ipairs({ damage, healing, boss }) do
        local _, state, meter = Native()
        state.records = ItemRanks(9)
        local source, total, _, message = meter.Read(view, 10)
        assert(source and not message and table.getn(source) == 1, "item ranks remained separate rows")
        assert(source[1].dmg == 450 and source[1].dps == 9 and source[1].share == 1 and total == 450)
        assert(source[1].name == "The Eye of Hakkar 9" and source[1].icon == "Interface\\Icons\\hakkar-rank-9")
        assert(table.getn(state.lastResponse.rows) == 9 and state.lastResponse.sources["hakkar-rank-1"].itemId == 9001)
        local identity = source[1].rowId
        state.records = ItemRanks(10)
        state.context.counterRevision = "item-rank-ten"
        source = assert(meter.Read(view, 10))
        assert(source[1].dmg == 550 and source[1].rowId == identity and source[1].name == "The Eye of Hakkar 10")
    end
end)

Test("item rank families preserve copies, components, owners and unknown identities", function()
    local distinctions = {
        { "itemKey", "eye_of_hakkar", "another_item" },
        { "itemInstanceKey", "copy-one", "copy-two" },
        { "variantKey", "direct", "periodic" },
        { "talentKey", "talent-one", "talent-two" },
        { "proc", false, true },
        { "rank" },
        { "itemKey" },
        { "itemId", 0, 9001 },
        { "kind", "item", "generic" },
    }
    for _, distinction in ipairs(distinctions) do
        local _, state, meter = Native()
        state.records = ItemRanks(2)
        state.records[2].actorId, state.records[2].actorKind, state.records[2].actorName = "totem-1", "totem", "Totem"
        state.records[1][distinction[1]], state.records[2][distinction[1]] = distinction[2], distinction[3]
        local source =
            assert(meter.Read({ metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }, 10))
        assert(table.getn(source) == 2, "item grouping discarded " .. distinction[1] .. " distinction")
    end
    local _, state, meter = Native()
    state.records = ItemRanks(2)
    state.records[2].ownerId = "hero-2"
    local source = assert(meter.Read({ metric = "damage", scope = "party", period = "run", groupBy = "source" }, 10))
    assert(table.getn(source) == 2, "item grouping merged different credited owners")
    state.records = ItemRanks(3)
    state.records[2].rank, state.records[3].rank = 1, 1
    state.records[2].actorId, state.records[2].actorName = "searing-1", "Searing Totem"
    state.records[3].actorId, state.records[3].actorName = "magma-1", "Magma Totem"
    state.context.counterRevision = "ambiguous-item-rank"
    source = assert(meter.Read({ metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }, 10))
    assert(table.getn(source) == 3, "same-rank item ambiguity partially merged a family")
    for _, row in ipairs(source) do
        assert(type(row.rowId) == "string", "ambiguous item family lost native row IDs")
    end
    assert(source[2].name == "The Eye of Hakkar 2 (Searing Totem)", "ambiguous item fallback lost its caster")
end)

Test("item-triggered effects use actual single-item origins and retain separate components", function()
    local _, state, meter = Native()
    state.records, state.extraSources = ItemEffects(3)
    local source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 60 and source[1].name == "The Eye of Hakkar 3")
    assert(source[1].icon == "Interface\\Icons\\hakkar-pulse-rank-3")
    state.records[3].abilityKey = "hakkar-other-component"
    state.context.metadataRevision = "separate-item-components"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2, "independent item effects merged by their parent item")
    for _, record in ipairs(state.records) do
        record.abilityKey, record.variantKey, record.omitAbilityKey = nil, "hakkar-pulse", true
    end
    state.context.metadataRevision = "explicit-variant-component"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1, "explicit effect component identity was ignored")
    for _, record in ipairs(state.records) do
        record.variantKey = nil
    end
    state.context.metadataRevision = "missing-item-component"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 3, "missing component identity merged unrelated item effects")
end)

Test("item origins never come from definition links, missing members or mixed positive contributions", function()
    local mutations = {
        function(snapshot) snapshot.contributions[1].originSourceKeys = { "missing-item" } end,
        function(snapshot) snapshot.rows[1].memberIds = { "missing-member" } end,
        function(snapshot) snapshot.contributions[1].originSourceKeys = { "hakkar-rank-3", "hakkar-rank-2" } end,
        function(snapshot) snapshot.sources["hakkar-rank-3"].itemInstanceKey = "other-copy" end,
        function(snapshot) snapshot.sources["hakkar-rank-3"].rank = nil end,
        function(snapshot)
            for _, leaf in ipairs(snapshot.contributions) do
                leaf.originSourceKeys = {}
            end
        end,
    }
    for _, mutate in ipairs(mutations) do
        local _, state, meter = Native()
        state.records, state.extraSources = ItemEffects(3)
        for _, record in ipairs(state.records) do
            record.definitionOrigins = Copy(record.origins)
        end
        state.mutate = mutate
        local source = assert(meter.Read(damage, 10))
        assert(table.getn(source) > 1, "uncertain item origin was inferred from source metadata or names")
    end
    local _, state, meter = Native()
    state.records, state.extraSources = ItemEffects(2)
    state.mutate = function(snapshot)
        local leaf = Copy(snapshot.contributions[1])
        leaf.rowId, leaf.displayAmount, leaf.originSourceKeys = "retired-origin", 0, { "missing-item" }
        table.insert(snapshot.contributions, leaf)
        table.insert(snapshot.rows[1].memberIds, leaf.rowId)
    end
    local source = assert(meter.Read(damage, 10))
    assert(
        table.getn(source) == 1 and source[1].dmg == 30,
        "zero checkpoint contribution changed current item attribution"
    )
    state.mutate = function(snapshot)
        local leaf = Copy(snapshot.contributions[1])
        leaf.rowId, leaf.originSourceKeys = "mixed-origin", { "hakkar-rank-1" }
        table.insert(snapshot.contributions, leaf)
        table.insert(snapshot.rows[1].memberIds, leaf.rowId)
    end
    state.context.counterRevision = "mixed-positive-origins"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2, "one source row with mixed actual item ranks entered a guessed family")
end)

Test("explicit item-bound abilities retain native resets, missing rates and artwork readiness", function()
    local _, state, meter = Native()
    state.records = ItemRanks(3)
    for _, record in ipairs(state.records) do
        record.kind, record.abilityKey, record.omitAbilityKey = "ability", "hakkar-pulse", nil
    end
    local source = assert(meter.Read(damage, 0))
    assert(table.getn(source) == 1 and source[1].dmg == 60)
    assert(meter.Reset())
    state.context.asOfRunSeconds = 22
    source = assert(meter.Read(damage, 0))
    assert(source[1].dmg == 18 and source[1].dps == 9)
    local checkpoint = state.queries[table.getn(state.queries)].checkpointId
    state.records[1].recentStatus = "unavailable"
    state.records[1].icon = { status = "pending", retryAfterSeconds = 0.2 }
    state.context.metadataRevision = "item-pending"
    source = assert(meter.Read(damage, 10))
    assert(source[1].dps == nil and source[1].icon == nil and source[1].iconStatus == "pending")
    state.records[1].icon = { status = "ready", path = "Interface\\Icons\\current-item-rank" }
    state.context.metadataRevision = "item-ready"
    source = assert(meter.Read(damage, 10))
    assert(source[1].icon == "Interface\\Icons\\current-item-rank")
    assert(
        state.queries[table.getn(state.queries)].checkpointId == checkpoint,
        "item presentation replaced Reset fence"
    )
end)

Test("unresolved item origins cannot fall back to ordinary ability-rank grouping", function()
    local _, state, meter = Native()
    state.records = Ranks(2)
    for _, record in ipairs(state.records) do
        record.origins = { "unavailable-item-origin" }
    end
    local source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2, "unknown actual origin fell through to a guessed ability family")
    state.extraSources =
        { ["unavailable-item-origin"] = { sourceKey = "unavailable-item-origin", kind = "invalid-kind" } }
    state.context.metadataRevision = "malformed-origin-kind"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2, "malformed origin kind fell through to a guessed ability family")
    state.extraSources = { ["unavailable-item-origin"] = { sourceKey = "unavailable-item-origin", kind = "talent" } }
    state.context.metadataRevision = "known-non-item-origin"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1, "known non-item origin changed the original ability-rank behavior")
end)

Test("partial own item identity cannot borrow a rank from another positive member", function()
    local _, state, meter = Native()
    state.records, state.extraSources = ItemEffects(2)
    for _, record in ipairs(state.records) do
        record.itemKey = "eye_of_hakkar"
    end
    state.mutate = function(snapshot)
        local leaf = Copy(snapshot.contributions[1])
        leaf.rowId, leaf.originSourceKeys = "origin-free-member", {}
        table.insert(snapshot.contributions, leaf)
        table.insert(snapshot.rows[1].memberIds, leaf.rowId)
    end
    local source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2, "own item key without rank borrowed another member's item rank")
    state.mutate = nil
    for _, record in ipairs(state.records) do
        record.kind, record.rank = "ability", 7
    end
    state.context.metadataRevision = "skill-and-item-ranks-differ"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1 and source[1].name == "The Eye of Hakkar 2", "skill rank replaced actual item rank")
end)

Test("item families combine player, pet and totem damage independently of pet summaries", function()
    for _, itemKey in ipairs({ "eye_of_hakkar", "amulet:enlightenment", "another-native-item" }) do
        for _, period in ipairs({ "run", "encounter" }) do
            local _, state, meter = Native()
            local view = { metric = "damage", scope = "self", period = period, groupBy = "actor_source" }
            state.records = ItemCasters()
            for _, record in ipairs(state.records) do
                record.itemKey = itemKey
            end
            local source, total, rate = meter.Read(view, 10)
            assert(table.getn(source) == 1 and source[1].dmg == 150 and total == 150)
            assert(source[1].dps == 3 and rate == 3 and source[1].share == 1)
            assert(source[1].name == "The Eye of Hakkar 2" and source[1].icon == "Interface\\Icons\\hakkar-rank-2")
            assert(table.getn(state.lastResponse.rows) == 5 and state.lastResponse.rows[2].displayAmount == 20)
            assert(state.lastResponse.rows[2].actorId == "searing-1", "display grouping rewrote native casters")
            local identity = source[1].rowId
            local details = table.concat(assert(meter.Describe(source, identity)), "\n")
            for _, actor in ipairs({ "hero-1", "searing-1", "magma-1" }) do
                assert(string.find(details, "actorId: " .. actor, 1, true), "item hover lost recorded caster IDs")
            end
            source = assert(meter.Read(view, 10, true))
            assert(table.getn(source) == 1 and source[1].rowId == identity and source[1].dmg == 150)
            state.records[4].actorId = "searing-replacement"
            state.records[4].amount = 45
            state.context.counterRevision = "new-item-caster-and-amount"
            source = assert(meter.Read(view, 10, true))
            assert(table.getn(source) == 1 and source[1].rowId == identity and source[1].dmg == 155)
            local first = table.remove(state.records, 1)
            table.insert(state.records, first)
            state.context.counterRevision = "reordered-item-casters"
            source = assert(meter.Read(view, 10))
            assert(table.getn(source) == 1 and source[1].rowId == identity and source[1].dmg == 155)
        end
    end
end)

Test("item summaries exclude ordinary pet spells and retain native Reset and unavailable rates", function()
    local _, state, meter = Native()
    local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
    state.records = ItemCasters()
    local spell = Copy(Pets()[2])
    spell.actorId, spell.actorName = "pet-1", "Wolf"
    table.insert(state.records, spell)
    for _, grouped in ipairs({ false, true }) do
        local source, total = meter.Read(view, 10, grouped)
        assert(table.getn(source) == 2 and total == 190 and source[1].dmg == 150 and source[2].dmg == 40)
        assert(source[1].name == "The Eye of Hakkar 2")
        assert(source[2].name == (grouped and "Wolf" or "Shadowbolt (Wolf)"))
    end
    state.records = ItemCasters()
    state.records[2].after = 0
    state.context.counterRevision = "item-reset-ready"
    assert(meter.Read(view, 0))
    assert(meter.Reset())
    state.context.asOfRunSeconds = 22
    local source = assert(meter.Read(view, 0))
    assert(source[1].dmg == 39 and source[1].dps == 19.5)
    local identity = source[1].rowId
    state.records[2].after = 6
    state.context.counterRevision = "item-caster-zero-to-positive"
    source = assert(meter.Read(view, 0))
    assert(source[1].rowId == identity and source[1].dmg == 45 and source[1].dps == 22.5)
    state.records[2].recentStatus = "unavailable"
    state.context.counterRevision = "item-caster-rate-unavailable"
    source = assert(meter.Read(view, 10))
    assert(source[1].dmg == 45 and source[1].dps == nil, "item summary invented a missing caster rate")
end)

Test("item rank summaries combine distinct casters without relaxing actual member joins", function()
    local _, state, meter = Native()
    local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
    state.records = ItemRanks(2)
    local repeated = Copy(state.records[2])
    repeated.rowId = "hakkar-repeat"
    table.insert(state.records, repeated)
    for index, record in ipairs(state.records) do
        record.actorId, record.actorKind, record.actorName, record.summonKey = "imp-" .. index, "summon", "Imp", "imp"
    end
    local source = assert(meter.Read(view, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 40 and source[1].name == "The Eye of Hakkar 2")
    state.records[3].summonKey, state.records[3].actorName = "doomguard", "Doomguard"
    state.context.metadataRevision = "different-item-caster"
    source = assert(meter.Read(view, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 40, "item damage split by pet definition")
    source = assert(meter.Read(view, 10, true))
    assert(table.getn(source) == 1 and source[1].dmg == 40, "pet summaries split matching item damage")
    state.records, state.extraSources = ItemEffects(2)
    for index, record in ipairs(state.records) do
        record.actorId, record.actorKind, record.actorName, record.summonKey = "imp-" .. index, "summon", "Imp", "imp"
    end
    state.records[2].summonKey, state.records[2].actorName = "doomguard", "Doomguard"
    state.context.metadataRevision = "different-item-effect-casters"
    source = assert(meter.Read(view, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 30 and source[1].name == "The Eye of Hakkar 2")
    state.mutate = function(snapshot) snapshot.contributions[1].actorId = "unrelated-caster" end
    state.context.metadataRevision = "mismatched-item-member-caster"
    source = assert(meter.Read(view, 10))
    assert(table.getn(source) == 2, "item origin borrowed a contribution from a different actor")
end)

Test("actual talent triggers supply native captions and artwork without changing spell records", function()
    for _, view in ipairs({ damage, healing, boss }) do
        local _, state, meter = Native()
        state.records, state.extraSources = Talents()
        state.records[1].origins = { "hot-streak" }
        state.records[3].kind, state.records[4].kind = "effect", "generic"
        local source, total = meter.Read(view, 10)
        assert(table.getn(source) == 4 and total == 19100)
        assert(source[1].name == "Pyroblast" and source[1].proc == 0, "normal spell cast took its modifier's name")
        assert(source[2].name == "Hot Streak" and source[2].proc == 1 and source[2].dmg == 4900)
        assert(source[3].name == "Chastise" and source[4].name == "Received shaman talent")
        assert(source[2].icon == "Interface\\Icons\\hot-streak-talent")
        assert(state.lastResponse.sources["pyroblast-proc"].name == "Pyroblast")
        assert(state.lastResponse.sources["holy-nova-proc"].name == "FX Holy nova")
        assert(state.lastResponse.rows[2].displayAmount == 4900 and state.lastResponse.rows[2].nativeProc)
        local identity = source[2].rowId
        source = assert(meter.Read(view, 10))
        assert(source[2].rowId == identity and source[2].icon == "Interface\\Icons\\hot-streak-talent")
    end
end)

Test("talent presentation rejects absent, modifier-only, malformed and mixed attribution", function()
    local cases = {
        function(state) state.records[1].proc = false end,
        function(state)
            state.records[1].origins, state.records[1].definitionOrigins = {}, { "hot-streak" }
        end,
        function(state)
            state.records[1].origins, state.records[1].talentKey = {}, "hot_streak"
        end,
        function(state) state.extraSources["hot-streak"] = nil end,
        function(state) state.extraSources["hot-streak"].name = "" end,
        function(state) state.extraSources["hot-streak"].sourceKey = "different-source" end,
        function(state) state.extraSources["hot-streak"].kind = "generic" end,
        function(state) state.extraSources["hot-streak"].attribution = "unknown" end,
        function(state) state.extraSources["hot-streak"].attribution = "mixed" end,
        function(state) state.extraSources["hot-streak"].attribution = nil end,
        function(state) state.extraSources["hot-streak"].icon = { status = "ready" } end,
        function(state) state.records[1].origins = { "hot-streak", "chastise" } end,
        function(state)
            state.mutate = function(snapshot) snapshot.rows[1].memberIds = {} end
        end,
        function(state)
            state.mutate = function(snapshot) snapshot.rows[1].memberIds = { "unavailable" } end
        end,
        function(state)
            state.mutate = function(snapshot) snapshot.contributions[1].ownerId = "other-owner" end
        end,
        function(state)
            state.mutate = function(snapshot) snapshot.contributions[1].nativeProc = false end
        end,
    }
    for _, mutate in ipairs(cases) do
        local _, state, meter = Native()
        local records
        records, state.extraSources = Talents()
        state.records = { records[2] }
        mutate(state)
        local source = assert(meter.Read(damage, 10))
        assert(table.getn(source) == 1 and source[1].name == "Pyroblast", "uncertain origin invented a talent caption")
        assert(source[1].icon == "Interface\\Icons\\pyroblast-proc", "uncertain origin replaced native source artwork")
    end
end)

Test("all positive source members must agree on one actual talent while retired members are ignored", function()
    for _, origin in ipairs({ "hot-streak", "chastise", "missing" }) do
        local _, state, meter = Native()
        local records
        records, state.extraSources = Talents()
        state.records = { records[2] }
        state.mutate = function(snapshot)
            local leaf = Copy(snapshot.contributions[1])
            leaf.rowId, leaf.originSourceKeys = "second-positive-member", { origin }
            table.insert(snapshot.contributions, leaf)
            table.insert(snapshot.rows[1].memberIds, leaf.rowId)
        end
        local source = assert(meter.Read(damage, 10))
        assert(source[1].name == (origin == "hot-streak" and "Hot Streak" or "Pyroblast"))
        assert(source[1].dmg == 4900, "talent display counted actual member amounts a second time")
    end
    local _, state, meter = Native()
    local records
    records, state.extraSources = Talents()
    state.records = { records[2] }
    state.mutate = function(snapshot)
        local leaf = Copy(snapshot.contributions[1])
        leaf.rowId, leaf.displayAmount, leaf.originSourceKeys = "retired-member", 0, { "missing" }
        table.insert(snapshot.contributions, leaf)
        table.insert(snapshot.rows[1].memberIds, leaf.rowId)
    end
    local source = assert(meter.Read(damage, 10))
    assert(source[1].name == "Hot Streak", "retired zero-delta contribution supplied current attribution")
    state.mutate = function(snapshot)
        local leaf = Copy(snapshot.contributions[1])
        leaf.rowId, leaf.originSourceKeys = "unattributed-positive-member", {}
        table.insert(snapshot.contributions, leaf)
        table.insert(snapshot.rows[1].memberIds, leaf.rowId)
    end
    state.context.counterRevision = "positive-unattributed-member"
    source = assert(meter.Read(damage, 10))
    assert(source[1].name == "Pyroblast", "one known talent borrowed attribution for an unrelated positive member")
end)

Test("rank summaries separate actual talent origins and fallback spell sources", function()
    local _, state, meter = Native()
    local _
    _, state.extraSources = Talents()
    state.records = Ranks(3)
    for _, record in ipairs(state.records) do
        record.proc, record.origins = true, { "hot-streak" }
    end
    state.records[3].origins = { "chastise" }
    local source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2 and source[1].name == "Hot Streak" and source[1].dmg == 50)
    assert(source[2].name == "Chastise" and source[2].dmg == 10, "different triggering talents shared a rank caption")
    local identity = source[1].rowId
    state.records[3].origins = {}
    state.context.counterRevision = "fallback-rank-source"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2 and source[1].rowId == identity and source[1].dmg == 50)
    assert(source[2].name == "Flamestrike", "rank summary attached a talent label to unknown provenance")
    state.extraSources["hot-streak"].name = "Série brûlante"
    state.context.metadataRevision = "localized-talent-ranks"
    source = assert(meter.Read(damage, 10))
    assert(source[1].name == "Série brûlante" and source[1].rowId == identity)
end)

Test("talent metadata and pending artwork retain native checkpoints and stable display identities", function()
    local _, state, meter = Native()
    local records
    records, state.extraSources = Talents()
    state.records = { records[2] }
    local source = assert(meter.Read(damage, 0))
    assert(source[1].name == "Hot Streak" and source[1].dmg == 4900)
    assert(meter.Reset())
    state.context.asOfRunSeconds = 22
    source = assert(meter.Read(damage, 0))
    local identity = source[1].rowId
    local checkpoint = state.queries[table.getn(state.queries)].checkpointId
    local captures = state.calls.create
    assert(source[1].name == "Hot Streak" and source[1].dmg == 490 and source[1].dps == 245)
    for _, status in ipairs({ "pending", "missing", "ready" }) do
        local origin = state.extraSources["hot-streak"]
        origin.icon = status == "pending" and { status = "pending", retryAfterSeconds = 0.2 }
            or status == "missing" and { status = "missing", reason = "not_available" }
            or { status = "ready", path = "Interface\\Icons\\updated-talent" }
        origin.name = "Updated talent " .. status
        state.context.metadataRevision = "talent-art-" .. status
        source = assert(meter.Read(damage, 0))
        assert(source[1].name == origin.name and source[1].rowId == identity and source[1].dmg == 490)
        assert(
            source[1].iconStatus == status and source[1].icon == origin.icon.path,
            "talent art borrowed base spell artwork"
        )
        source = assert(meter.Read(damage, 0))
        assert(
            source[1].icon == origin.icon.path and source[1].rowId == identity,
            "unchanged pass restored base artwork"
        )
    end
    assert(state.calls.create == captures and state.queries[table.getn(state.queries)].checkpointId == checkpoint)
end)

Test("direct talent rows and combined pet summaries keep their authoritative presentation", function()
    local _, state, meter = Native()
    local records
    records, state.extraSources = Talents()
    state.records = { records[2] }
    state.records[1].kind, state.records[1].name = "talent", "Direct native talent"
    local source = assert(meter.Read(damage, 10))
    assert(source[1].name == "Direct native talent" and source[1].icon == "Interface\\Icons\\pyroblast-proc")
    records, state.extraSources = Talents()
    state.records = { records[1], records[2] }
    for _, record in ipairs(state.records) do
        record.actorId, record.actorKind, record.actorName, record.summonKey = "imp-1", "summon", "Imp", "imp"
    end
    state.context.counterRevision = "talent-pet-caster"
    local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
    source = assert(meter.Read(view, 10))
    assert(source[1].name == "Pyroblast (Imp)" and source[2].name == "Hot Streak (Imp)")
    state.mutate = function(snapshot) snapshot.contributions[2].actorId = "unrelated-pet" end
    state.context.counterRevision = "mismatched-talent-caster"
    source = assert(meter.Read(view, 10))
    assert(source[2].name == "Pyroblast (Imp)", "talent attribution borrowed another caster's member")
    state.mutate = nil
    source = assert(meter.Read(view, 10, true))
    assert(table.getn(source) == 1 and source[1].name == "Imp" and source[1].dmg == 14300)
end)

Test("native talent ranks combine across views and upgrades without rewriting native accounting", function()
    for _, view in ipairs({ damage, healing, boss }) do
        local _, state, meter = Native()
        state.records = TalentRanks(3)
        for _, record in ipairs(TalentRanks(2, "shaman.enh_windfury_weapon", "Windfury Weapon")) do
            table.insert(state.records, record)
        end
        local source, total, rate = meter.Read(view, 10)
        assert(table.getn(source) == 2 and total == 90 and rate == 1.8)
        assert(source[1].name == "Flametongue Weapon" and source[1].dmg == 60 and source[1].share == 60 / 90)
        assert(source[2].name == "Windfury Weapon" and source[2].dmg == 30)
        assert(math.abs(source[1].dps - 1.2) < 0.000001)
        assert(source[1].averageDps == (view.period == "encounter" and 6 or 3))
        assert(source[1].icon == "Interface\\Icons\\talent:shaman.enh_flametongue_weapon:r3")
        assert(table.getn(state.lastResponse.rows) == 5 and table.getn(state.lastResponse.contributions) == 5)
        assert(state.lastResponse.rows[1].displayAmount == 30 and state.lastResponse.rows[1].nativeProc)
        assert(state.lastResponse.sources["talent:shaman.enh_flametongue_weapon:r3"].rank == 3)
        local identity = source[1].rowId
        table.insert(state.records, 1, TalentRanks(4)[1])
        state.context.counterRevision = "later-talent-rank"
        source, total = meter.Read(view, 10)
        assert(table.getn(source) == 2 and total == 130 and source[1].dmg == 100)
        assert(source[1].rowId == identity and source[1].proc == 1, "talent upgrade replaced the display family")
        assert(source[1].icon == "Interface\\Icons\\talent:shaman.enh_flametongue_weapon:r4")
    end
end)

Test("talent rank families require explicit identity and preserve source distinctions and ambiguity", function()
    local distinctions = {
        { "talentKey", "talent-one", "talent-two" },
        { "abilityKey", "component-one", "component-two" },
        { "variantKey", "extra-strike", "nova" },
        { "itemInstanceKey", "copy-one", "copy-two" },
        { "itemKey", "item-one", "item-two" },
        { "itemId", 101, 102 },
        { "kind", "talent", "ability" },
        { "proc", false, true },
        { "rank", 1, 1 },
        { "rank" },
        { "rank", 1.5, -1 },
        { "talentKey" },
        { "talentKey", "", "" },
        { "variantKey", "", "" },
        { "itemId", -1, -1 },
        { "attribution" },
        { "attribution", "unknown", "unknown" },
        { "attribution", "mixed", "mixed" },
    }
    for _, distinction in ipairs(distinctions) do
        local _, state, meter = Native()
        state.records = TalentRanks(2)
        state.records[1][distinction[1]], state.records[2][distinction[1]] = distinction[2], distinction[3]
        if distinction[1] == "abilityKey" then
            state.records[1].omitAbilityKey, state.records[2].omitAbilityKey = false, false
        end
        local source = assert(meter.Read(damage, 10))
        assert(table.getn(source) == 2, "talent family collapsed distinct or invalid " .. distinction[1])
        local first, second = source[1].rowId, source[2].rowId
        assert(first ~= second, "distinct talent families shared a display identity for " .. distinction[1])
        assert(source[1].dmg == 20 and source[2].dmg == 10, "separate talent families changed native amounts")
        if distinction[1] == "rank" and distinction[2] == 1 and distinction[3] == 1 then
            assert(
                first == state.lastResponse.rows[1].rowId and second == state.lastResponse.rows[2].rowId,
                "ambiguous talent ranks lost their individual native row IDs"
            )
        end
        source = assert(meter.Read(damage, 10))
        assert(source[1].rowId == first and source[2].rowId == second, "unchanged talent identities were replaced")
    end
    local _, state, meter = Native()
    state.records = TalentRanks(2)
    state.records[2].ownerId = "hero-2"
    local source = assert(meter.Read({ metric = "damage", scope = "party", period = "run", groupBy = "source" }, 0))
    assert(table.getn(source) == 2, "talent ranks merged different accounting owners")
    state.records[2].ownerId = nil
    for index, record in ipairs(state.records) do
        record.actorId, record.actorKind, record.actorName = "caster-" .. index, "totem", "Same totem name"
    end
    source = assert(meter.Read({ metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }, 10))
    assert(table.getn(source) == 2, "talent ranks merged unrelated recorded casters by name")
end)

Test("actual talent origin ranks combine without treating one ability rank as an ambiguous talent rank", function()
    for _, view in ipairs({ damage, healing, boss }) do
        local _, state, meter = Native()
        state.records, state.extraSources = TalentProcRanks(3)
        local source, total = meter.Read(view, 10)
        assert(table.getn(source) == 1 and source[1].dmg == 60 and total == 60)
        assert(source[1].name == "Flametongue Weapon" and source[1].proc == 1)
        assert(source[1].icon == "Interface\\Icons\\talent:shaman.enh_flametongue_weapon:r3")
        assert(state.lastResponse.sources["fire-nova-origin-rank-3"].name == "Fire Nova")
        assert(state.lastResponse.sources["fire-nova-origin-rank-3"].rank == 1)
        local identity = source[1].rowId
        state.records, state.extraSources = TalentProcRanks(4)
        state.context.counterRevision = "later-actual-talent-origin"
        source = assert(meter.Read(view, 10))
        assert(table.getn(source) == 1 and source[1].dmg == 100 and source[1].rowId == identity)
        assert(source[1].icon == "Interface\\Icons\\talent:shaman.enh_flametongue_weapon:r4")
    end
end)

Test("normalized talent origins retain exact components, incomplete identities and same-rank conflicts", function()
    local distinctions = {
        { "talentKey", "different-talent" },
        { "abilityKey", "different-component" },
        { "variantKey", "different-variant" },
        { "itemInstanceKey", "different-copy" },
        { "itemKey", "different-item" },
        { "itemId", 101 },
        { "talentKey" },
        { "rank" },
        { "rank", 1 },
    }
    for _, distinction in ipairs(distinctions) do
        local _, state, meter = Native()
        state.records, state.extraSources = TalentProcRanks(2)
        state.extraSources[state.records[1].origins[1]][distinction[1]] = distinction[2]
        local source = assert(meter.Read(damage, 10))
        assert(table.getn(source) == 2, "origin normalization lost " .. distinction[1] .. " boundary")
    end
    local _, state, meter = Native()
    state.records, state.extraSources = TalentProcRanks(2)
    state.records[1].abilityKey = "other-ability"
    local source = assert(meter.Read(damage, 10))
    assert(
        table.getn(source) == 1 and source[1].dmg == 30,
        "one actual talent stayed split by its triggering abilities"
    )
end)

Test("received Flametongue and Windfury trigger shapes share their validated actual talent family", function()
    local cases = {
        {
            "shaman.enh_flametongue_weapon",
            "Flametongue Weapon",
            {
                { id = "ability:fire_nova", abilityKey = "fire_nova" },
                { id = "ability:fire_nova:r1", abilityKey = "fire_nova", rank = 1 },
            },
        },
        {
            "shaman.enh_windfury_weapon",
            "Windfury Weapon",
            {
                { id = "ability:rockbiter:r5", abilityKey = "rockbiter", rank = 5 },
                { id = "ability:stormstrike:r1", abilityKey = "stormstrike", rank = 1 },
            },
        },
    }
    for _, case in ipairs(cases) do
        for _, view in ipairs({ damage, healing, boss }) do
            local _, state, meter = Native()
            state.records, state.extraSources = TalentTriggers(case[1], case[2], case[3])
            local source, total, rate = meter.Read(view, 10)
            assert(table.getn(source) == 1 and source[1].name == case[2] and source[1].dmg == 30 and total == 30)
            assert(math.abs(source[1].dps - 0.6) < 0.000001 and rate == 0.6)
            assert(source[1].icon == "Interface\\Icons\\talent:" .. case[1] .. ":r3")
            for index, trigger in ipairs(case[3]) do
                assert(state.lastResponse.sources[trigger.id].rank == trigger.rank, "grouping invented an ability rank")
                assert(state.lastResponse.rows[index].sourceKey == trigger.id)
            end
            local identity = source[1].rowId
            local old = table.remove(state.records, 1)
            table.insert(state.records, old)
            state.context.counterRevision = "reordered-talent-triggers"
            source = assert(meter.Read(view, 10))
            assert(source[1].rowId == identity and source[1].dmg == 30)
            assert(meter.Reset())
            state.context.asOfRunSeconds = 22
            source = assert(meter.Read(view, 0))
            assert(table.getn(source) == 1 and source[1].dmg == 9 and source[1].dps == 4.5)
        end
    end
end)

Test("actual talent trigger summaries keep explicit distinctions and reject missing or ambiguous ownership", function()
    local triggers = {
        { id = "ability:fire_nova", abilityKey = "fire_nova" },
        { id = "ability:fire_nova:r1", abilityKey = "fire_nova", rank = 1 },
    }
    local mutations = {
        function(state) state.records[1].variantKey = "separate-variant" end,
        function(state) state.records[1].itemKey = "separate-item" end,
        function(state) state.records[1].itemInstanceKey = "separate-instance" end,
        function(state) state.records[1].itemId = 101 end,
        function(state) state.records[1].talentKey = "separate-explicit-talent" end,
        function(state) state.records[1].proc = false end,
        function(state) state.records[1].attribution = "unknown" end,
        function(state) state.records[1].rank = -1 end,
        function(state) state.records[1].omitAbilityKey = true end,
        function(state) state.records[1].origins = {} end,
        function(state) state.records[1].origins = { state.records[1].origins[1], "missing-second-origin" } end,
        function(state) state.extraSources[state.records[1].origins[1]].rank = nil end,
        function(state) state.extraSources[state.records[1].origins[1]].talentKey = nil end,
        function(state)
            local origin = Copy(state.extraSources[state.records[1].origins[1]])
            origin.sourceKey = "conflicting-origin-at-the-same-rank"
            state.extraSources[origin.sourceKey], state.records[1].origins = origin, { origin.sourceKey }
        end,
    }
    for _, mutate in ipairs(mutations) do
        local _, state, meter = Native()
        state.records, state.extraSources =
            TalentTriggers("shaman.enh_flametongue_weapon", "Flametongue Weapon", triggers)
        mutate(state)
        local source = assert(meter.Read(damage, 10))
        assert(
            table.getn(source) == 2,
            "actual talent summary erased a supplied distinction or accepted uncertain identity"
        )
    end
    local _, state, meter = Native()
    state.records, state.extraSources = TalentTriggers("shaman.enh_flametongue_weapon", "Flametongue Weapon", triggers)
    local duplicate = Copy(state.records[1])
    duplicate.id, duplicate.rowId = "second-unranked-fire-nova", "second-unranked-member"
    table.insert(state.records, duplicate)
    local source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 3, "ambiguous unranked trigger partially merged its talent family")
    for _, row in ipairs(source) do
        assert(type(row.rowId) == "string", "ambiguous triggers lost their exact native row identities")
    end
end)

Test("actual talent triggers preserve recorded owners and casters", function()
    local _, state, meter = Native()
    local triggers = {
        { id = "ability:rockbiter:r5", abilityKey = "rockbiter", rank = 5 },
        { id = "ability:stormstrike:r1", abilityKey = "stormstrike", rank = 1 },
    }
    state.records, state.extraSources = TalentTriggers("shaman.enh_windfury_weapon", "Windfury Weapon", triggers)
    state.records[2].ownerId = "hero-2"
    local source = assert(meter.Read({ metric = "damage", scope = "party", period = "run", groupBy = "source" }, 10))
    assert(table.getn(source) == 2, "talent triggers merged different credited owners")
    state.records[2].ownerId = nil
    for index, record in ipairs(state.records) do
        record.actorId, record.actorKind, record.actorName = "caster-" .. index, "totem", "Same totem"
    end
    source = assert(meter.Read({ metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }, 10))
    assert(table.getn(source) == 2, "talent triggers merged unrelated recorded casters")
end)

Test("talent ranks retain checkpoint deltas, missing rates, localization and highest-rank art retries", function()
    local _, state, meter = Native()
    state.records = TalentRanks(3)
    assert(meter.Read(damage, 0) and meter.Reset())
    state.context.asOfRunSeconds = 22
    local source = assert(meter.Read(damage, 0))
    assert(table.getn(source) == 1 and source[1].dmg == 18 and source[1].dps == 9)
    local identity = source[1].rowId
    local checkpoint = state.queries[table.getn(state.queries)].checkpointId
    for _, status in ipairs({ "pending", "missing", "ready" }) do
        state.records[1].icon = status == "pending" and { status = "pending", retryAfterSeconds = 0.2 }
            or status == "missing" and { status = "missing", reason = "not_available" }
            or { status = "ready", path = "Interface\\Icons\\updated-talent-rank" }
        for _, record in ipairs(state.records) do
            record.name = "Received localized weapon talent"
        end
        state.context.metadataRevision, state.context.languageRevision = "talent-rank-art-" .. status, "talent-fr"
        state.context.languageCode = "fr"
        source = assert(meter.Read(damage, 0))
        assert(source[1].rowId == identity and source[1].name == "Received localized weapon talent")
        assert(source[1].iconStatus == status and source[1].icon == state.records[1].icon.path)
        assert(source[1].dmg == 18 and state.queries[table.getn(state.queries)].checkpointId == checkpoint)
    end
    state.recentStatus = "unavailable"
    source = assert(meter.Read(damage, 10))
    assert(source[1].dps == nil and source[1].averageDps == 9)
    identity = source[1].rowId
    state.records = TalentRanks(4)
    for index = 2, 4 do
        state.records[index].after = 0
    end
    state.context.counterRevision = "new-talent-rank-after-reset"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 12 and source[1].averageDps == 6)
    assert(source[1].rowId == identity and source[1].dps == nil)
    assert(
        state.queries[table.getn(state.queries)].checkpointId == checkpoint,
        "talent upgrade replaced the reset fence"
    )
end)

Test("talent rank summaries reuse unchanged identity work for direct and actual-origin sources", function()
    for _, records in ipairs({ TalentRanks, TalentProcRanks }) do
        local c, state, meter = Native()
        state.records, state.extraSources = records(30)
        local lengths, nativeString = 0, c.env.string
        c.env.string = setmetatable({
            len = function(value)
                lengths = lengths + 1
                return nativeString.len(value)
            end,
        }, { __index = nativeString })
        local source = assert(meter.Read(damage, 10))
        local identity = source[1].rowId
        assert(table.getn(source) == 1 and source[1].dmg == 4650 and lengths > 0)
        lengths = 0
        state.context.counterRevision = "unchanged-talent-counters"
        source = assert(meter.Read(damage, 10))
        assert(source[1].rowId == identity and lengths == 0)
        state.context.metadataRevision = "unrelated-talent-metadata"
        source = assert(meter.Read(damage, 10))
        assert(source[1].rowId == identity and lengths == 0)
        state.records[1].amount = state.records[1].amount + 10
        state.context.counterRevision = "changed-talent-amount"
        source = assert(meter.Read(damage, 10))
        assert(source[1].dmg == 4660 and source[1].rowId == identity and lengths == 0)
    end
end)

Test("hover diagnostics distinguish native proc rows even when their source IDs and names match", function()
    local _, state, meter = Native()
    state.records = TalentRanks(2, "shaman.enh_windfury_weapon", "Windfury Weapon")
    for _, record in ipairs(state.records) do
        record.id, record.rank = "talent:shaman.enh_windfury_weapon:r1", 1
    end
    state.records[2].proc = false
    local source, total =
        meter.Read({ metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }, 10)
    assert(table.getn(source) == 2 and total == 30)
    local reads = state.calls.snapshot
    local first = table.concat(assert(meter.Describe(source, source[1].rowId)), "\n")
    local second = table.concat(assert(meter.Describe(source, source[2].rowId)), "\n")
    for _, text in ipairs({ first, second }) do
        assert(string.find(text, "sourceKey: talent:shaman.enh_windfury_weapon:r1", 1, true))
        assert(string.find(text, "ownerId: hero-1; actorId: hero-1", 1, true))
        assert(string.find(text, "kind=talent; attribution=known; rank=1", 1, true))
        assert(not string.find(text, "table:", 1, true), "hover exposed a private display token as a native ID")
    end
    assert(string.find(first, "nativeProc=true", 1, true) and string.find(second, "nativeProc=false", 1, true))
    assert(first ~= second and state.calls.snapshot == reads, "hover merged rows or collected another native snapshot")
    assert(meter.Describe(source, "not-a-current-row") == nil)
end)

Test("group hover diagnostics retain source and actual origin IDs while ignoring zero-display history", function()
    local _, state, meter = Native()
    state.records, state.extraSources = TalentProcRanks(2)
    state.mutate = function(snapshot)
        local leaf = Copy(snapshot.contributions[1])
        leaf.rowId, leaf.displayAmount, leaf.originSourceKeys = "retired-origin-member", 0, { "retired-origin" }
        table.insert(snapshot.contributions, leaf)
        table.insert(snapshot.rows[1].memberIds, leaf.rowId)
    end
    local source = assert(meter.Read(damage, 10))
    local text = table.concat(assert(meter.Describe(source, source[1].rowId)), "\n")
    assert(table.getn(source) == 1 and source[1].dmg == 30 and source[1].name == "Flametongue Weapon")
    for rank = 1, 2 do
        assert(string.find(text, "sourceKey: fire-nova-origin-rank-" .. rank, 1, true))
        assert(string.find(text, "originSourceKey: talent:shaman.enh_flametongue_weapon:r" .. rank, 1, true))
    end
    assert(not string.find(text, "retired-origin", 1, true), "zero-display history supplied current hover attribution")
    assert(string.find(text, "abilityKey: fire_nova", 1, true))
    assert(string.find(text, "talentKey: shaman.enh_flametongue_weapon", 1, true))
end)

Test("hover diagnostics prepare lazily, reuse counter-only text and refresh changed metadata", function()
    local c, state, meter = Native()
    state.records = TalentRanks(3)
    local formats, nativeString = 0, c.env.string
    c.env.string = setmetatable({
        gsub = function(...)
            formats = formats + 1
            return nativeString.gsub(...)
        end,
    }, { __index = nativeString })
    local source = assert(meter.Read(damage, 10))
    assert(formats == 0, "unhovered rows prepared diagnostic strings")
    local lines = assert(meter.Describe(source, source[1].rowId))
    assert(formats > 0)
    local formatted = formats
    state.records[1].amount = state.records[1].amount + 1
    state.context.counterRevision = "hover-counter-only"
    source = assert(meter.Read(damage, 10))
    assert(meter.Describe(source, source[1].rowId) == lines and formats == formatted)
    state.records[1].variantKey = "received-variant"
    state.context.metadataRevision = "hover-variant-metadata"
    source = assert(meter.Read(damage, 10))
    local changed = assert(meter.Describe(source, source[1].rowId))
    assert(changed == lines and formats > formatted, "changed hover allocated a new buffer or kept stale IDs")
    assert(string.find(table.concat(changed, "\n"), "variantKey: received-variant", 1, true))
    meter.Clear()
    assert(meter.Describe(source, source[1].rowId) == nil, "retired native handles replayed hover IDs")
end)

Test("hover diagnostic output stays bounded for large rank families", function()
    local _, state, meter = Native()
    state.records = TalentRanks(30)
    local source = assert(meter.Read(damage, 10))
    local lines = assert(meter.Describe(source, source[1].rowId))
    assert(table.getn(lines) <= 24 and lines[table.getn(lines)] == "...")
    assert(source[1].dmg == 4650 and state.lastResponse.totals.displayAmount == 4650)
end)

Test("large totem ledgers read each native member and origin ID once per fingerprint pass", function()
    local c, state, meter = Native()
    state.records, state.extraSources = TotemItems(120)
    local arrays, reads = {}, 0
    local nativePairs, nativeIpairs, nativeTable = c.env.pairs, c.env.ipairs, c.env.table
    local function Track(values)
        local proxy = {}
        arrays[proxy] = values
        return setmetatable(proxy, {
            __index = function(_, index)
                reads = reads + 1
                return values[index]
            end,
        })
    end
    c.env.table = setmetatable({
        getn = function(values) return nativeTable.getn(arrays[values] or values) end,
    }, { __index = nativeTable })
    c.env.pairs = function(values)
        local original = arrays[values]
        if not original then return nativePairs(values) end
        local iterator, source, key = nativePairs(original)
        return function(collection, previous)
            local index, value = iterator(collection, previous)
            if index ~= nil then reads = reads + 1 end
            return index, value
        end,
            source,
            key
    end
    c.env.ipairs = function(values)
        if arrays[values] then
            return function(collection, index)
                index = index + 1
                local value = collection[index]
                if value ~= nil then return index, value end
            end,
                values,
                0
        end
        return nativeIpairs(values)
    end
    state.mutate = function(snapshot)
        arrays = {}
        for _, row in ipairs(snapshot.rows) do
            row.memberIds = Track(row.memberIds)
        end
        for _, leaf in ipairs(snapshot.contributions) do
            leaf.originSourceKeys = Track(leaf.originSourceKeys)
        end
    end
    local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
    for tick = 1, 3 do
        reads = 0
        if tick == 3 then
            state.records, state.extraSources = TotemItems(180)
        end
        state.context.counterRevision = "totem-fingerprint-" .. tick
        local source, total = meter.Read(view, 10)
        local count = table.getn(state.records)
        assert(source and table.getn(source) == 1 and source[1].dmg == count * 10 and total == count * 10)
        assert(source[1].name == "The Eye of Hakkar 1")
        assert(reads == count * 2, "native member/origin IDs were skipped or read again during preparation")
        assert(state.calls.snapshot == tick, "fingerprint processing added a native capture")
    end
end)

Test("single-pass fingerprints reject malformed arrays and recover without a metadata revision", function()
    local mutations = {
        function(snapshot) snapshot.rows[1].memberIds.extra = "unexpected" end,
        function(snapshot) snapshot.rows[1].memberIds[1] = false end,
        function(snapshot)
            snapshot.rows[1].memberIds[3] = snapshot.rows[1].memberIds[1]
            snapshot.rows[1].memberIds[1] = nil
        end,
        function(snapshot) snapshot.contributions[1].originSourceKeys.extra = "unexpected" end,
        function(snapshot) snapshot.contributions[1].originSourceKeys[1] = false end,
        function(snapshot)
            snapshot.contributions[1].originSourceKeys[3] = snapshot.contributions[1].originSourceKeys[1]
            snapshot.contributions[1].originSourceKeys[1] = nil
        end,
    }
    for _, mutate in ipairs(mutations) do
        local _, state, meter = Native()
        local records
        records, state.extraSources = Talents()
        state.records = { records[2] }
        local source = assert(meter.Read(damage, 10))
        assert(source[1].name == "Hot Streak")
        state.mutate, state.context.counterRevision = mutate, "malformed-native-ids"
        source = assert(meter.Read(damage, 10))
        assert(source[1].name == "Pyroblast", "malformed array retained stale talent attribution")
        state.mutate, state.context.counterRevision = nil, "recovered-native-ids"
        source = assert(meter.Read(damage, 10))
        assert(source[1].name == "Hot Streak" and source[1].dmg == 4900)
    end
end)

Test("aliased native rates validate once while separate malformed rate tables remain rejected", function()
    for _, window in ipairs({ 0, 10 }) do
        for _, checkpoint in ipairs({ false, true }) do
            local counts = {}
            for _, alias in ipairs({ false, true }) do
                local _, state, meter = Native()
                local reads = 0
                state.records = Ranks(2)
                if checkpoint then
                    assert(meter.Reset())
                    state.context.asOfRunSeconds = 22
                end
                local function Track(value)
                    return setmetatable({}, {
                        __index = function(_, key)
                            reads = reads + 1
                            return value[key]
                        end,
                    })
                end
                state.mutate = function(snapshot)
                    local stats = { snapshot.totals }
                    for _, row in ipairs(snapshot.rows) do
                        table.insert(stats, row)
                    end
                    for _, value in ipairs(stats) do
                        local selected = window > 0 and value.recentRate
                            or value.checkpointAverage
                            or value.periodAverage
                        value.periodAverage, value.recentRate = Track(value.periodAverage), Track(value.recentRate)
                        if value.checkpointAverage then value.checkpointAverage = Track(value.checkpointAverage) end
                        value.displayRate = alias
                                and (window > 0 and value.recentRate or value.checkpointAverage or value.periodAverage)
                            or Track(Copy(selected))
                    end
                end
                local source = assert(meter.Read(damage, window))
                assert(table.getn(source) == 1 and source[1].dmg == (checkpoint and 9 or 30))
                counts[alias and 2 or 1] = reads
            end
            assert(counts[2] < counts[1], "aliased display rates repeated their full validation")
            local _, state, meter = Native()
            state.records = Ranks(2)
            if checkpoint then
                assert(meter.Reset())
                state.context.asOfRunSeconds = 22
            end
            state.mutate = function(snapshot)
                local row = snapshot.rows[1]
                local selected = window > 0 and row.recentRate or row.checkpointAverage or row.periodAverage
                local equal = { __eq = function() return true end }
                setmetatable(selected, equal)
                row.displayRate = setmetatable(Copy(selected), equal)
                row.displayRate.endRunSeconds = -1
                assert(row.displayRate == selected and not rawequal(row.displayRate, selected))
            end
            assert(not meter.Read(damage, window), "separate invalid display rate bypassed validation")
        end
    end
end)

Test("counter and unrelated metadata publications reuse prepared native identities", function()
    local c, state, meter = Native()
    state.records = Ranks(30)
    local lengths, sorts = 0, 0
    local nativeString, nativeTable = c.env.string, c.env.table
    c.env.string = setmetatable({
        len = function(value)
            lengths = lengths + 1
            return nativeString.len(value)
        end,
    }, { __index = nativeString })
    c.env.table = setmetatable({
        sort = function(values, compare)
            sorts = sorts + 1
            return nativeTable.sort(values, compare)
        end,
    }, { __index = nativeTable })
    local source = assert(meter.Read(damage, 10))
    local identity = source[1].rowId
    assert(source[1].dmg == 4650 and lengths > 0 and sorts == 1)
    lengths = 0
    for tick = 1, 5 do
        state.context.counterRevision = "counter-only-" .. tick
        state.context.asOfRunSeconds = 20 + tick
        source = assert(meter.Read(damage, 10))
        assert(source[1].rowId == identity and source[1].dmg == 4650)
    end
    assert(lengths == 0 and sorts == 1, "counter-only values rebuilt stable keys or sorted an unchanged view")
    state.context.metadataRevision = "unrelated-new-demon-metadata"
    source = assert(meter.Read(damage, 10))
    assert(source[1].rowId == identity and lengths == 0 and sorts == 1, "unrelated metadata rebuilt existing families")
    state.records[1].amount = state.records[1].amount + 10
    state.context.counterRevision = "amount-change"
    source = assert(meter.Read(damage, 10))
    assert(
        source[1].dmg == 4660 and lengths == 0 and sorts == 2,
        "numeric refresh lost ordering or repeated identity work"
    )
end)

Test("clock-only refresh preserves combined ordering and native rates", function()
    local _, state, meter = Native()
    state.records = Ranks(2)
    state.records[1].amount, state.records[2].amount = 40, 40
    table.insert(
        state.records,
        1,
        { id = "leading-native-row", rowId = "leading-native-row", name = "Other", amount = 60, recent = 12 }
    )
    local source = assert(meter.Read(damage, 10))
    local identity = source[1].rowId
    assert(source[1].name == "Flamestrike" and source[1].dmg == 80 and source[2].dmg == 60)
    state.context.asOfRunSeconds, state.context.snapshotId = 25, "clock-only-capture"
    state.records[2].recent, state.records[3].recent = 20, 10
    source = assert(meter.Read(damage, 10))
    assert(source[1].rowId == identity and source[1].name == "Flamestrike" and source[1].dps == 3)
    assert(source[1].averageDps == 3.2 and source[2].name == "Other", "clock pass lost grouped amount ordering")
end)

Test("incremental member positions recover new tails, reorder and retirement", function()
    local _, state, meter = Native()
    state.records, state.extraSources = ItemEffects(3)
    local source = assert(meter.Read(damage, 10))
    local identity = source[1].rowId
    local first = table.remove(state.records, 1)
    table.insert(state.records, first)
    state.context.counterRevision = "reordered-native-members"
    source = assert(meter.Read(damage, 10))
    assert(source[1].rowId == identity and source[1].dmg == 60 and source[1].name == "The Eye of Hakkar 3")
    state.records, state.extraSources = ItemEffects(4)
    state.context.counterRevision = "new-native-source-tail"
    source = assert(meter.Read(damage, 10))
    assert(source[1].rowId == identity and source[1].dmg == 100 and source[1].name == "The Eye of Hakkar 4")
    state.records, state.extraSources = ItemEffects(1)
    state.context.counterRevision = "native-source-retirement"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 10 and source[1].name == "The Eye of Hakkar 1")
    state.records, state.extraSources = ItemEffects(2)
    state.context.counterRevision = "new-source-after-retirement"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 1 and source[1].dmg == 30 and source[1].name == "The Eye of Hakkar 2")
end)

Test("counter-only late positive members reevaluate actual talent and item attribution", function()
    for _, kind in ipairs({ "talent", "item" }) do
        local _, state, meter = Native()
        if kind == "talent" then
            local records
            records, state.extraSources = Talents()
            state.records = { records[2] }
        else
            state.records, state.extraSources = ItemEffects(2)
        end
        local positive = false
        state.mutate = function(snapshot)
            local leaf = Copy(snapshot.contributions[1])
            leaf.rowId = "retained-zero-member"
            leaf.displayAmount, leaf.sinceCheckpointAmount = positive and 1 or 0, positive and 1 or 0
            leaf.originSourceKeys = { kind == "talent" and "chastise" or "hakkar-rank-1" }
            table.insert(snapshot.contributions, leaf)
            table.insert(snapshot.rows[1].memberIds, leaf.rowId)
        end
        assert(meter.Reset())
        state.context.asOfRunSeconds = 22
        local source = assert(meter.Read(damage, 0))
        assert(source[1].name == (kind == "talent" and "Hot Streak" or "The Eye of Hakkar 2"))
        positive = true
        state.context.counterRevision = "historical-member-now-positive"
        source = assert(meter.Read(damage, 0))
        if kind == "talent" then
            assert(source[1].name == "Pyroblast", "cached zero-member fingerprint mislabeled a mixed talent source")
        else
            assert(table.getn(source) == 2, "cached zero-member fingerprint merged incompatible item origins")
        end
    end
end)

Test("new active contribution tails do not reindex unrelated retained zero history", function()
    local _, state, meter = Native()
    state.records = { { id = "active-old", rowId = "active-old", name = "Old", amount = 100, recent = 20, after = 10 } }
    local historyReads = 0
    state.mutate = function(snapshot)
        local appended = snapshot.contributions[2]
        snapshot.contributions[2] = nil
        for index = 1, 1000 do
            local id = "retired-" .. index
            local leaf = Copy(snapshot.contributions[1])
            leaf.rowId, leaf.sourceKey, leaf.periodAmount = id, id, 1
            leaf.displayAmount, leaf.sinceCheckpointAmount, leaf.windowAmount = 0, 0, 0
            leaf.periodAverage.amount, leaf.periodAverage.value = 1, 1 / leaf.periodAverage.denominatorSeconds
            for _, rate in ipairs({ leaf.checkpointAverage, leaf.recentRate, leaf.displayRate }) do
                rate.amount, rate.value = 0, 0
            end
            leaf.share = 0
            snapshot.sources[id] = {
                sourceKey = id,
                kind = "generic",
                name = "Retired",
                icon = { status = "missing", reason = "not_available" },
            }
            table.insert(
                snapshot.contributions,
                setmetatable({}, {
                    __index = function(_, key)
                        if key == "rowId" then historyReads = historyReads + 1 end
                        return leaf[key]
                    end,
                })
            )
        end
        if appended then table.insert(snapshot.contributions, appended) end
        snapshot.totals.periodAmount = snapshot.totals.periodAmount + 1000
        snapshot.totals.periodAverage.amount = snapshot.totals.periodAverage.amount + 1000
        snapshot.totals.periodAverage.value = snapshot.totals.periodAverage.amount
            / snapshot.totals.periodAverage.denominatorSeconds
    end
    assert(meter.Reset())
    state.context.asOfRunSeconds = 22
    local source = assert(meter.Read(damage, 10))
    assert(source[1].dmg == 10 and historyReads >= 1000)
    historyReads = 0
    table.insert(
        state.records,
        { id = "active-new", rowId = "active-new", name = "New", amount = 50, recent = 10, after = 5 }
    )
    state.context.counterRevision = "appended-active-contribution"
    source = assert(meter.Read(damage, 10))
    assert(table.getn(source) == 2 and source[1].dmg == 10 and source[2].dmg == 5)
    assert(historyReads == 0, "new active tail rescanned the unrelated retained history prefix")
end)

Test("shared refresh context reuses only an exact accepted native capture", function()
    local _, state, meter = Native()
    local context = assert(meter.Context())
    local source, total, rate = meter.Read(damage, 10, false, context)
    assert(source and total == 140 and rate == 6 and state.calls.context == 1 and state.calls.snapshot == 1)
    source = assert(meter.Read(damage, 10, false, context))
    assert(source[1].dmg == 100 and state.calls.snapshot == 1, "exact native capture repeated full snapshot work")
    state.context.asOfRunSeconds, state.context.snapshotId = 21, "native-clock-moved"
    context = assert(meter.Context())
    assert(meter.Read(damage, 10, false, context) and state.calls.context == 2 and state.calls.snapshot == 2)
    state.mutate = function(snapshot) snapshot.query.checkpointId = "unrequested" end
    state.context.snapshotId = "fresh-malformed-capture"
    context = assert(meter.Context())
    assert(not meter.Read(damage, 10, false, context), "fresh malformed capture bypassed validation")
    state.mutate = nil
    assert(
        meter.Read(damage, 10, false, context) and state.calls.snapshot == 4,
        "rejected capture replayed an older cache"
    )
    local before = state.calls.context
    state.snapshotError = Error("NOT_READY")
    assert(
        not meter.Read(damage, 10) and state.calls.context == before + 1,
        "direct adapter call stopped reading fresh context/snapshot"
    )
end)

Test("shared context is validated and a newer embedded snapshot remains authoritative", function()
    local _, state, meter = Native()
    local context = assert(meter.Context())
    local invalid = Copy(context)
    invalid.asOfRunSeconds = -1
    assert(
        not meter.Read(damage, 10, false, invalid) and not state.calls.snapshot,
        "invalid forwarded context reached native snapshot"
    )
    state.mutate = function(snapshot)
        snapshot.context.asOfRunSeconds, snapshot.context.snapshotId = 22, "mid-call-capture"
    end
    local source, _, _, _, _, meta = meter.Read(damage, 10, false, context)
    assert(source and meta.snapshotId == "mid-call-capture", "earlier phase context replaced the snapshot's capture")
    assert(
        meter.Read(damage, 10, false, context) and state.calls.snapshot == 2,
        "older phase context reused a newer mismatched capture"
    )
end)

Test("pet skills keep the caster and combine repeated native summon definitions", function()
    local _, state, meter = Native()
    local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
    state.records = Pets()
    local source, total, rate = meter.Read(view, 10)
    assert(table.getn(source) == 3 and total == 220 and rate == 11)
    assert(source[1].name == "Shadowbolt" and source[1].dmg == 100, "pet casts merged with the hero's same source")
    assert(source[2].name == "Shadowbolt (Imp)" and source[2].dmg == 60 and source[2].dps == 3)
    assert(
        source[3].name == "Hellfire (Imp)" and source[3].dmg == 60 and source[3].icon == "Interface\\Icons\\hellfire"
    )
    assert(table.getn(state.lastResponse.rows) == 4 and state.lastResponse.rows[2].displayAmount == 40)
    local identity = source[2].rowId
    state.records[2].actorId, state.records[3].actorId = "imp-3", "imp-4"
    state.context.counterRevision = "new-imp-incarnations"
    source = assert(meter.Read(view, 10))
    assert(source[2].rowId == identity and source[2].dmg == 60, "new incarnations replaced the native summon family")
    state.records[3].id = "shadowbolt-distinct-definition"
    state.context.metadataRevision = "ambiguous-pet-rank"
    source = assert(meter.Read(view, 10))
    assert(table.getn(source) == 4, "different native descriptors at the same rank lost their ambiguity")
end)

Test(
    "equal pet spell and caster captions suppress only the suffix while keeping recorded identities separate",
    function()
        for _, kind in ipairs({ "pet", "summon", "totem" }) do
            local _, state, meter = Native()
            local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
            state.records = {
                {
                    id = "same-skill",
                    rowId = "hero-skill",
                    abilityKey = "searing",
                    rank = 1,
                    name = "Searing Totem",
                    amount = 100,
                    recent = 50,
                },
                {
                    id = "same-skill",
                    rowId = "caster-skill",
                    abilityKey = "searing",
                    rank = 1,
                    name = "Searing Totem",
                    amount = 40,
                    recent = 20,
                    actorId = "caster-one",
                    actorKind = kind,
                    actorName = "Searing Totem",
                },
            }
            local source, total, rate = meter.Read(view, 10)
            assert(table.getn(source) == 2 and total == 140 and rate == 7)
            assert(source[1].name == "Searing Totem" and source[2].name == "Searing Totem")
            assert(
                source[1].rowId ~= source[2].rowId and source[1].dmg == 100 and source[2].dmg == 40,
                "equal captions merged recorded player and pet damage"
            )
            local identity = source[2].rowId
            for _, record in ipairs(state.records) do
                record.name = "Totem incendiaire"
            end
            state.records[2].actorName = "Totem incendiaire"
            state.context.languageCode, state.context.languageRevision = "fr", "equal-pet-captions-fr"
            state.context.metadataRevision = "localized-equal-pet-caption"
            source = assert(meter.Read(view, 10))
            assert(source[2].name == "Totem incendiaire" and source[2].rowId == identity)
            state.records[2].actorName = "Different Totem"
            state.context.metadataRevision = "different-pet-caption"
            source = assert(meter.Read(view, 10))
            assert(source[2].name == "Totem incendiaire (Different Totem)" and source[2].rowId == identity)
        end
    end
)

Test("pet summaries preserve native rates, reset fences and presentation changes", function()
    local _, state, meter = Native()
    local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
    state.records = Pets()
    state.records[2].proc = true
    local source, total, rate, _, revision = meter.Read(view, 10, true)
    assert(table.getn(source) == 2 and source[1].name == "Imp" and source[1].dmg == 120)
    assert(source[1].dps == 6 and source[1].averageDps == 6 and source[1].share == 120 / 220)
    assert(total == 220 and rate == 11 and source[1].proc == 0, "mixed pet skills changed accounting or proc styling")
    assert(source[1].icon == nil and source[1].portraitKey == "portrait-imp-1" and source[1].portraitStatus == "ready")
    local _, _, _, _, detailRevision = meter.Read(view, 10, false)
    assert(detailRevision ~= revision, "option change did not publish the changed row presentation")
    source = assert(meter.Read(view, 10, true))
    assert(source[1].name == "Imp" and source[1].dmg == 120)
    assert(meter.Reset())
    state.context.asOfRunSeconds = 22
    source = assert(meter.Read(view, 0, true))
    assert(source[1].dmg == 12 and source[1].dps == 6 and source[2].dmg == 10)
    local checkpoint = state.queries[table.getn(state.queries)].checkpointId
    local captures = state.calls.create
    local identity = source[1].rowId
    for _, record in ipairs(state.records) do
        if record.actorId then record.actorName = "Wichtel" end
    end
    state.context.languageCode, state.context.languageRevision = "de", "pet-language-de"
    state.context.metadataRevision = "pet-meta-de"
    source = assert(meter.Read(view, 0, true))
    assert(source[1].name == "Wichtel" and source[1].rowId == identity and source[1].dmg == 12)
    state.records[3].recentStatus = "unavailable"
    source = assert(meter.Read(view, 10, true))
    assert(source[1].dps == nil and source[1].averageDps == 6, "known skills replaced an unavailable member rate")
    source = assert(meter.Read(view, 10, false))
    assert(table.getn(source) == 4, "mixed proc detail rows lost their native distinction")
    assert(state.calls.create == captures and state.queries[table.getn(state.queries)].checkpointId == checkpoint)
    assert(state.queries[table.getn(state.queries)].groupBy == "actor_source")
end)

Test("pet grouping never guesses relationships from names or broad pet families", function()
    local cases = {
        { kind = "summon", field = "summonKey", first = "imp", second = "imp", count = 1 },
        { kind = "summon", field = "summonKey", first = "imp", second = "doomguard", count = 2 },
        { kind = "pet", field = "summonKey", first = "pet-definition", second = "pet-definition", count = 1 },
        { kind = "pet", count = 2 },
        { kind = "totem", field = "totemKey", first = "searing", second = "searing", count = 1 },
        { kind = "totem", field = "summonKey", first = "same-unused-key", second = "same-unused-key", count = 2 },
        { kind = "summon", field = "summonKey", first = "imp", second = "imp", otherKind = "pet", count = 2 },
        { kind = "summon", field = "summonKey", first = "imp", second = "imp", otherOwner = "hero-2", count = 2 },
    }
    for _, case in ipairs(cases) do
        local _, state, meter = Native()
        state.records = {
            { id = "effect", rowId = "one", name = "Attack", amount = 20, recent = 10, actorId = "pet-one" },
            { id = "effect", rowId = "two", name = "Attack", amount = 10, recent = 5, actorId = "pet-two" },
        }
        for _, record in ipairs(state.records) do
            record.actorKind, record.actorName, record.petFamilyKey = case.kind, "Same received name", "wolf"
            record.kind = "effect"
        end
        if case.field then
            state.records[1][case.field], state.records[2][case.field] = case.first, case.second
        end
        state.records[2].actorKind = case.otherKind or case.kind
        state.records[2].ownerId = case.otherOwner
        local view = { metric = "damage", scope = "party", period = "run", groupBy = "actor_source" }
        local source = assert(meter.Read(view, 10))
        assert(table.getn(source) == case.count, "detail skills inferred a pet definition from name or family")
        source = assert(meter.Read(view, 10, true))
        assert(table.getn(source) == case.count, "pet summary discarded explicit actor/owner distinctions")
    end
end)

Test("pet attribution rejects missing native actor metadata and keeps unknown actors literal", function()
    local _, state, meter = Native()
    local view = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" }
    state.records = Pets()
    state.mutate = function(snapshot) snapshot.actors["imp-1"] = nil end
    local source = meter.Read(view, 10, true)
    assert(not source, "missing caster metadata silently guessed a pet name")
    state.mutate = function(snapshot) snapshot.actors["imp-1"].name = "" end
    source = meter.Read(view, 10, true)
    assert(not source, "empty caster metadata silently guessed a pet name")
    state.mutate = nil
    for _, record in ipairs(state.records) do
        if record.actorId then record.actorKind = "unknown" end
    end
    state.context.metadataRevision = "unknown-actors"
    source = assert(meter.Read(view, 10, true))
    assert(table.getn(source) == 4, "unknown actors were relabeled or combined as pets")
    for _, row in ipairs(source) do
        assert(row.name == "Shadowbolt" or row.name == "Hellfire")
    end
end)

Test("scheduled recent caches retain native zero, unavailable and warming-up results", function()
    local cases = {
        { time = 20, recent = 0, status = "ready", expected = 0 },
        { time = 20, recent = 50, status = "unavailable", expectedStatus = "unavailable" },
        { time = 0.5, recent = 5, status = "ready", expectedStatus = "warming_up" },
    }
    for _, case in ipairs(cases) do
        local _, state, meter = Native()
        state.records =
            { { id = "native-rate", rowId = "native-rate", name = "Native rate", amount = 100, recent = case.recent } }
        state.context.asOfRunSeconds, state.recentStatus = case.time, case.status
        if case.time < 10 then state.context.encounter = nil end
        local policy = { offset = 0, count = 1, refresh = true }
        local source, total, rate, _, _, meta = meter.Read(damage, 10, false, nil, policy)
        assert(source and total == 100 and source[1].dps == case.expected and rate == case.expected)
        assert(meta.recentStatus == (case.expectedStatus or case.status))
        state.records[1].amount, state.records[1].recent = 125, 90
        state.context.asOfRunSeconds, state.context.counterRevision = case.time + 0.1, "counter-with-cached-native-rate"
        policy.refresh = false
        source, total, rate, _, _, meta = meter.Read(damage, 10, false, nil, policy)
        assert(source and total == 125 and source[1].dps == case.expected and rate == case.expected)
        assert(
            table.getn(state.queries) == 2 and state.queries[2].windowSeconds == 0,
            "cached nil or zero repeated native history"
        )
        assert(meta.recentStatus == (case.expectedStatus or case.status))
        assert(meta.recentAsOfRunSeconds == case.time and meta.asOfRunSeconds == case.time + 0.1)
    end
end)

Test("new family members force native history and its newer capture supplies all returned values", function()
    local _, state, meter, env = Native()
    state.records = Ranks(1)
    local policy = { offset = 0, count = 1, refresh = true }
    local source = assert(meter.Read(damage, 10, false, nil, policy))
    local identity = source[1].rowId
    state.records = Ranks(2)
    state.context.asOfRunSeconds, state.context.counterRevision = 21, "rank-added-between-rate-samples"
    local original = env.AZS_GetMeterSnapshot
    env.AZS_GetMeterSnapshot = function(query)
        if query.windowSeconds > 0 then
            state.context.asOfRunSeconds, state.context.snapshotId = 22, "newer-positive-capture"
            state.context.counterRevision, state.records[1].amount = "newer-positive-counters", 200
        end
        return original(query)
    end
    policy.refresh = false
    local total, rate, meta
    source, total, rate, _, _, meta = meter.Read(damage, 10, false, nil, policy)
    assert(source and source[1].rowId == identity and source[1].dmg == 210 and total == 210)
    assert(meta.snapshotId == "newer-positive-capture" and meta.asOfRunSeconds == 22)
    assert(state.queries[2].windowSeconds == 0 and state.queries[3].windowSeconds == 10)
    local response = state.lastResponse
    assert(rate == response.totals.displayRate.value and meta.averageRate == response.totals.periodAverage.value)
    local expected = response.rows[1].displayRate.value + response.rows[2].displayRate.value
    assert(source[1].dps == expected, "new group reused a partial old native rate")
end)

Test("viewport recent caches retire old identities without adding a fifth physical-query view", function()
    do
        local _, state, meter = Native()
        state.records = {
            { id = "one", rowId = "one", name = "One", amount = 100, recent = 10, rank = 1 },
            { id = "two", rowId = "two", name = "Two", amount = 50, recent = 20, rank = 1 },
        }
        local policy = { offset = 0, count = 1, refresh = true }
        assert(meter.Read(damage, 10, false, nil, policy))
        policy.offset, policy.refresh = 1, false
        local source = assert(meter.Read(damage, 10, false, nil, policy))
        assert(source[2].dps == 2 and table.getn(state.queries) == 2)
        assert(state.queries[2].windowSeconds == 10, "known viewport miss copied counters before requesting rates")
        state.records[1].recent, state.context.counterRevision = 90, "reveal-retired-rate-identity"
        policy.offset = 0
        source = assert(meter.Read(damage, 10, false, nil, policy))
        assert(source[1].dps == 9 and table.getn(state.queries) == 3, "retired viewport reused stale native history")
    end
    do
        local _, state, meter = Native()
        state.records = Ranks(1)
        local policy = { offset = 0, count = 1, refresh = true }
        local source = assert(meter.Read(damage, 10, false, nil, policy))
        local identity = source[1].rowId
        policy.refresh = false
        state.context.asOfRunSeconds, state.context.counterRevision = 21, "logical-view-counter-capture"
        assert(meter.Read(damage, 10, false, nil, policy))
        assert(meter.Read(healing, 0) and meter.Read(boss, 0) and meter.Read(party, 0))
        source = assert(meter.Read(damage, 10, false, nil, policy))
        assert(source[1].rowId == identity, "counter-only physical query evicted one of the four logical views")
    end
end)

Test("physical recent failures never expose All rates and do not poison counter retries", function()
    local c, state, meter, env = Native()
    state.records = Ranks(1)
    local policy = { offset = 0, count = 1, refresh = true }
    assert(meter.Read(damage, 10, false, nil, policy))
    local original = env.AZS_GetMeterSnapshot
    local failWindow = 0
    env.AZS_GetMeterSnapshot = function(query)
        if query.windowSeconds == failWindow then
            state.snapshotError = Error("NOT_READY")
        else
            state.snapshotError = nil
        end
        return original(query)
    end
    policy.refresh = false
    assert(not meter.Read(damage, 10, false, nil, policy), "failed counter query replayed a stale source list")
    policy.refresh = true
    assert(meter.Read(damage, 10, false, nil, policy), "counter retry deadline blocked an independent recent query")
    c.now = c.now + 0.21
    state.records = Ranks(2)
    state.context.counterRevision, failWindow = "new-group-with-failed-native-history", 10
    policy.refresh = false
    local source, total, rate = meter.Read(damage, 10, false, nil, policy)
    assert(not source and total == nil and rate == nil, "failed forced history returned All data as recent")
    assert(state.queries[table.getn(state.queries) - 1].windowSeconds == 0)
    assert(state.queries[table.getn(state.queries)].windowSeconds == 10)
    state.snapshotError, failWindow = nil, nil
    c.now = c.now + 0.21
    source = assert(meter.Read(damage, 10, false, nil, policy))
    assert(
        source[1].dmg == 30 and math.abs(source[1].dps - 0.6) < 0.000000001,
        "fresh native history did not recover the changed family"
    )
end)
