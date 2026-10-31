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
                    kind = "pet",
                    name = "Hunter pet",
                    nameLanguageCode = self.context.languageCode,
                    state = "despawned",
                    parentActorId = owner,
                    currentOwnerId = owner,
                    petFamilyKey = "wolf",
                    portrait = { portraitKey = "portrait-" .. actor, status = "missing", reason = "not_available" },
                }
            end
            response.sources[record.id] = {
                sourceKey = record.id,
                kind = record.kind or "ability",
                name = record.name,
                nameLanguageCode = self.context.languageCode,
                icon = record.icon or { status = "ready", path = "Interface\\Icons\\" .. record.id },
                spellIds = {},
                originSourceKeys = {},
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
            leaf.originSourceKeys, leaf.tieOrder = {}, index
            local row = Stats(query, record.amount, record.recent, record.after, record.recentStatus)
            row.rowId, row.memberIds, row.rank = "group-" .. record.rowId, { record.rowId }, index
            row.ownerId, row.sourceKey, row.nativeProc, row.tieOrder = owner, record.id, leaf.nativeProc, index
            row.procClassification = leaf.nativeProc and "proc" or "non_proc"
            if query.groupBy == "owner" then
                row.rowId, row.actorId, row.sourceKey, row.nativeProc = "owner-" .. owner, nil, nil, nil
            else
                row.actorId = nil
            end
            amount, recent, after = amount + record.amount, recent + record.recent, after + (record.after or 0)
            table.insert(response.contributions, leaf)
            if row.displayAmount > 0 then
                table.insert(response.rows, row)
                response.maxRowAmount = math.max(response.maxRowAmount, row.displayAmount)
            end
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

if helperMode == "helpers" then return { New = Native, languages = languages, labels = labels, Ranks = Ranks } end

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
