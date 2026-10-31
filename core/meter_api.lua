-- Native v1 meter boundary. No legacy metadata, combat intake or gameplay clock.
setfenv(1, DFRL:GetEnv())

function DFRL.tools.NewNativeMeter()
    local adapter = {}
    local state = { views = {}, releases = {}, contextRetry = {}, sequence = 0, usage = 0 }
    local phases = { ready = true, playing = true, choosing = true, paused = true, dead = true, victory = true }
    local waiting =
        { NO_WORLD = true, NO_PLAYER = true, NO_RUN = true, NOT_READY = true, NO_PARTY = true, NO_ENCOUNTER = true }
    local invalidCheckpoints = { INVALID_CHECKPOINT = true, CHECKPOINT_EXPIRED = true, CHECKPOINT_INVALIDATED = true }
    local classes = {
        warrior = true,
        paladin = true,
        hunter = true,
        rogue = true,
        priest = true,
        shaman = true,
        mage = true,
        warlock = true,
        druid = true,
    }
    local endpoints = {
        "AZS_GetMeterCapabilities",
        "AZS_GetMeterContext",
        "AZS_GetMeterSnapshot",
        "AZS_CreateMeterCheckpoint",
        "AZS_ReleaseMeterCheckpoint",
        "AZS_SetMeterPortrait",
    }

    local function Id(value) return type(value) == "string" and value ~= "" end
    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end
    local function Error(code, message) return { code = code, message = message, retryable = false } end
    local function Malformed() return Error("INVALID_RESPONSE", "Native meter returned an invalid response.") end
    local function NativeError(value)
        return type(value) == "table"
            and Id(value.code)
            and Id(value.message)
            and type(value.retryable) == "boolean"
            and (not value.retryable or (Number(value.retryAfterSeconds) and value.retryAfterSeconds > 0))
    end
    local function RetryClock()
        if type(_G.GetTime) == "function" then
            local ok, value = pcall(_G.GetTime)
            if ok and Number(value) then return value end
        end
        return 0
    end
    local function ClearRetry(record)
        record.failure, record.attemptedAt, record.retryAt = nil, nil, nil
    end
    local function DeferredError(record)
        if not record.retryAt then return end
        local now = RetryClock()
        if now >= record.attemptedAt and now < record.retryAt then return record.failure end
        -- UI-clock regression makes an old retry deadline unusable.
        ClearRetry(record)
    end
    local function RememberError(record, failure)
        ClearRetry(record)
        if failure.retryable == true and Number(failure.retryAfterSeconds) and failure.retryAfterSeconds > 0 then
            record.failure, record.attemptedAt = failure, RetryClock()
            record.retryAt = record.attemptedAt + failure.retryAfterSeconds
        end
    end
    local function Call(name, argument)
        local getter = _G[name]
        if type(getter) ~= "function" then
            return nil, Error("UNSUPPORTED_QUERY", "The native meter endpoint is unavailable.")
        end
        local ok, result, failure
        if argument == nil then
            ok, result, failure = pcall(getter)
        else
            ok, result, failure = pcall(getter, argument)
        end
        if not ok then return nil, Error("INTERNAL_ERROR", "The native meter call failed.") end
        if result == nil then return nil, NativeError(failure) and failure or Malformed() end
        if result == false then return nil, Malformed() end
        if failure ~= nil then return nil, Malformed() end
        return result
    end
    local function Capabilities()
        for _, name in ipairs(endpoints) do
            if type(_G[name]) ~= "function" then
                return nil, Error("UNSUPPORTED_QUERY", "The native meter endpoint set is incomplete.")
            end
        end
        if state.capabilities then return state.capabilities end
        local result, failure = Call("AZS_GetMeterCapabilities")
        if not result then return nil, failure end
        if type(result) ~= "table" or not Number(result.apiVersion) then return nil, Malformed() end
        if result.apiVersion ~= 1 then
            return nil, Error("UNSUPPORTED_VERSION", "Native meter version 1 is required.")
        end
        if not Id(result.uiSessionId) or type(result.features) ~= "table" then return nil, Malformed() end
        state.capabilities = { uiSessionId = result.uiSessionId, features = {} }
        for key, value in pairs(result.features) do
            if type(value) == "boolean" then state.capabilities.features[key] = value end
        end
        return state.capabilities
    end
    local function Feature(capabilities, key)
        if capabilities.features[key] == true then return true end
        return nil, Error("UNSUPPORTED_QUERY", "The requested native meter feature is unavailable.")
    end
    local function ContextValid(context)
        if
            not (
                type(context) == "table"
                and context.apiVersion == 1
                and Id(context.runId)
                and Id(context.uiSessionId)
                and Id(context.authorityId)
                and Id(context.counterEpoch)
                and Id(context.snapshotId)
                and Id(context.counterRevision)
                and Id(context.metadataRevision)
                and Id(context.languageCode)
                and Id(context.languageRevision)
                and Id(context.localOwnerId)
                and phases[context.phase] == true
                and Number(context.asOfRunSeconds)
            )
        then
            return false
        end
        local encounter = context.encounter
        if encounter ~= nil and (type(encounter) ~= "table" or not Id(encounter.encounterId)) then return false end
        return true
    end
    local function QueueRelease(checkpoint)
        if checkpoint and Id(checkpoint.checkpointId) and not state.releases[checkpoint.checkpointId] then
            state.releases[checkpoint.checkpointId] = {}
        end
    end
    function adapter.PendingCleanup() return next(state.releases) ~= nil end
    function adapter.RetryCleanup()
        if not next(state.releases) then return true end
        local firstFailure
        local now = RetryClock()
        for token, pending in pairs(state.releases) do
            if not pending.retryAt or now >= pending.retryAt or now < pending.attemptedAt then
                local result, failure = Call("AZS_ReleaseMeterCheckpoint", token)
                if result == true then
                    state.releases[token] = nil
                else
                    failure = failure or Malformed()
                    if failure.code == "INVALID_CHECKPOINT" then
                        -- An unissued token cannot own native resources.
                        state.releases[token] = nil
                    else
                        pending.attemptedAt = now
                        pending.retryAt = now + (failure.retryable and failure.retryAfterSeconds or 1)
                        pending.failure = failure
                    end
                    if not firstFailure then firstFailure = failure end
                end
            elseif not firstFailure then
                firstFailure = pending.failure
            end
        end
        if firstFailure then return nil, firstFailure end
        return true
    end
    local function BlockCheckpoint(failure)
        state.blocked = failure
        QueueRelease(state.checkpoint)
        state.checkpoint = nil
        state.views = {}
    end
    local function CheckCheckpoint(context)
        local checkpoint = state.checkpoint
        if not checkpoint then return end
        local reason
        if checkpoint.uiSessionId ~= context.uiSessionId then
            BlockCheckpoint(Error("CHECKPOINT_EXPIRED", "The native meter checkpoint session ended."))
            return
        elseif checkpoint.runId ~= context.runId then
            reason = "run_changed"
        elseif checkpoint.authorityId ~= context.authorityId then
            reason = "authority_changed"
        elseif checkpoint.counterEpoch ~= context.counterEpoch then
            reason = "counter_epoch_changed"
        end
        if reason then
            local failure = Error("CHECKPOINT_INVALIDATED", "The native meter checkpoint was invalidated.")
            failure.reason = reason
            BlockCheckpoint(failure)
        end
    end
    function adapter.Context()
        local deferred = DeferredError(state.contextRetry)
        if deferred then return nil, deferred end
        local capabilities, failure = Capabilities()
        if not capabilities then
            RememberError(state.contextRetry, failure)
            return nil, failure
        end
        local context
        context, failure = Call("AZS_GetMeterContext")
        if not context then
            RememberError(state.contextRetry, failure)
            return nil, failure
        end
        if not ContextValid(context) or context.uiSessionId ~= capabilities.uiSessionId then return nil, Malformed() end
        CheckCheckpoint(context)
        return context
    end
    function adapter.IsReset() return state.reset == true end
    local function Failure(failure, context)
        local meta = { error = failure, isReset = state.reset == true }
        if context then
            meta.runId, meta.counterEpoch, meta.authorityId = context.runId, context.counterEpoch, context.authorityId
        end
        return nil, nil, nil, not waiting[failure.code] and "Meter data is unavailable." or nil, nil, meta
    end
    local function Rate(rate, average)
        if type(rate) ~= "table" then return false end
        local status = rate.status
        if status == "not_requested" then return not average and rate.value == nil end
        if status ~= "ready" and status ~= "warming_up" and status ~= "unavailable" then return false end
        if average and status ~= "ready" then return false end
        if
            not Number(rate.startRunSeconds)
            or not Number(rate.endRunSeconds)
            or rate.endRunSeconds < rate.startRunSeconds
            or not Number(rate.elapsedSeconds)
        then
            return false
        end
        if status == "unavailable" then
            return rate.value == nil
                and (
                    rate.reason == "history_gap"
                    or rate.reason == "history_not_retained"
                    or rate.reason == "authority_changed"
                )
        end
        if
            not Number(rate.amount)
            or not Number(rate.denominatorSeconds)
            or rate.denominatorSeconds <= 0
            or not Number(rate.resolutionSeconds)
            or rate.resolutionSeconds > 0.2
            or type(rate.approximate) ~= "boolean"
        then
            return false
        end
        if status == "warming_up" then return rate.value == nil and rate.elapsedSeconds < 1 end
        return Number(rate.value)
    end
    local function Stats(stats, checkpoint, window)
        if
            type(stats) ~= "table"
            or not Number(stats.periodAmount)
            or not Number(stats.displayAmount)
            or not Rate(stats.periodAverage, true)
            or not Rate(stats.displayRate, window == 0)
            or not Rate(stats.recentRate, false)
        then
            return false
        end
        local average = stats.periodAverage
        if checkpoint then
            if
                not Number(stats.sinceCheckpointAmount)
                or not Rate(stats.checkpointAverage, true)
                or stats.displayAmount ~= stats.sinceCheckpointAmount
            then
                return false
            end
            average = stats.checkpointAverage
        elseif stats.displayAmount ~= stats.periodAmount then
            return false
        end
        local selected = window > 0 and stats.recentRate or average
        if stats.displayRate.status ~= selected.status or stats.displayRate.value ~= selected.value then
            return false
        end
        if window > 0 then
            if selected.status == "not_requested" then return false end
            if selected.status ~= "unavailable" and not Number(stats.windowAmount) then return false end
        elseif stats.recentRate.status ~= "not_requested" then
            return false
        end
        return true
    end
    local function Icon(icon)
        if type(icon) ~= "table" then return false end
        if icon.status == "ready" then return Id(icon.path) end
        if icon.status == "pending" then return Number(icon.retryAfterSeconds) and icon.retryAfterSeconds > 0 end
        return icon.status == "missing" and (icon.reason == "not_applicable" or icon.reason == "not_available")
    end
    local function Portrait(portrait)
        if type(portrait) ~= "table" or not Id(portrait.portraitKey) then return false end
        if portrait.status == "ready" then return true end
        if portrait.status == "pending" then
            return Number(portrait.retryAfterSeconds) and portrait.retryAfterSeconds > 0
        end
        return portrait.status == "missing"
            and (portrait.reason == "not_applicable" or portrait.reason == "not_available")
    end
    local function Hero(actors, owner)
        local actor = actors[owner]
        if
            type(actor) ~= "table"
            or actor.actorId ~= owner
            or actor.kind ~= "hero"
            or not Id(actor.name)
            or not classes[actor.classKey]
            or not Portrait(actor.portrait)
        then
            return
        end
        return actor
    end
    local function RowsValid(snapshot, query)
        if type(snapshot.ownerIds) ~= "table" then return false end
        local count, owners = 0, {}
        for _, owner in ipairs(snapshot.ownerIds) do
            if
                not Id(owner)
                or owners[owner]
                or not Hero(snapshot.actors, owner)
                or (query.scope == "self" and owner ~= snapshot.context.localOwnerId)
                or (query.scope == "owner" and owner ~= query.ownerId)
            then
                return false
            end
            owners[owner], count = true, count + 1
        end
        if count == 0 or (query.scope ~= "party" and count ~= 1) then return false end
        for key in pairs(snapshot.ownerIds) do
            if not Number(key) or key < 1 or key > count or key ~= math.floor(key) then return false end
        end
        local seen, maximum
        count, seen, maximum = 0, {}, 0
        for _, row in ipairs(snapshot.rows) do
            if
                type(row) ~= "table"
                or not Id(row.rowId)
                or seen[row.rowId]
                or not Id(row.ownerId)
                or not Number(row.share)
                or row.share > 1
                or not Stats(row, query.checkpointId, query.windowSeconds)
                or row.displayAmount <= 0
                or not owners[row.ownerId]
            then
                return false
            end
            if
                row.procClassification ~= "proc"
                and row.procClassification ~= "non_proc"
                and row.procClassification ~= "mixed"
            then
                return false
            end
            if query.groupBy ~= "owner" then
                local source = Id(row.sourceKey) and snapshot.sources[row.sourceKey]
                if
                    type(source) ~= "table"
                    or source.sourceKey ~= row.sourceKey
                    or not Id(source.name)
                    or not Icon(source.icon)
                    or type(row.nativeProc) ~= "boolean"
                then
                    return false
                end
            end
            seen[row.rowId], count = true, count + 1
            maximum = math.max(maximum, row.displayAmount)
        end
        for key in pairs(snapshot.rows) do
            if not Number(key) or key < 1 or key > count or key ~= math.floor(key) then return false end
        end
        return (snapshot.status == "ready_empty") == (count == 0)
            and (count > 0 or snapshot.totals.displayAmount == 0)
            and snapshot.maxRowAmount == maximum
    end
    local function View(query)
        state.usage = state.usage + 1
        local oldest
        for _, view in ipairs(state.views) do
            if
                view.metric == query.metric
                and view.scope == query.scope
                and view.ownerId == query.ownerId
                and view.period == query.period
                and view.groupBy == query.groupBy
                and view.healingPerspective == query.healingPerspective
                and view.windowSeconds == query.windowSeconds
                and view.checkpointId == query.checkpointId
                and view.runId == query.runId
            then
                view.used = state.usage
                return view
            end
            if not oldest or view.used < oldest.used then oldest = view end
        end
        local view = table.getn(state.views) < 4 and {} or oldest
        if table.getn(state.views) < 4 then table.insert(state.views, view) end
        for key in pairs(view) do
            view[key] = nil
        end
        for key, value in pairs(query) do
            view[key] = value
        end
        view.rows, view.used = {}, state.usage
        return view
    end
    local function CopyRows(view, snapshot, query)
        local count = 0
        for index, native in ipairs(snapshot.rows) do
            local row = view.rows[index] or {}
            local average = query.checkpointId and native.checkpointAverage or native.periodAverage
            row.rowId, row.dmg, row.dps, row.averageDps, row.share =
                native.rowId, native.displayAmount, native.displayRate.value, average.value, native.share
            row.icon, row.iconStatus, row.class = nil, nil, nil
            row.portraitKey, row.portraitRunId, row.portraitStatus = nil, nil, nil
            if query.groupBy == "owner" then
                local actor = snapshot.actors[native.ownerId]
                row.name, row.class, row.proc = actor.name, actor.classKey, 0
                row.portraitKey, row.portraitRunId, row.portraitStatus =
                    actor.portrait.portraitKey, snapshot.context.runId, actor.portrait.status
            else
                local source = snapshot.sources[native.sourceKey]
                row.name, row.proc, row.iconStatus = source.name, native.nativeProc and 1 or 0, source.icon.status
                if source.icon.status == "ready" then row.icon = source.icon.path end
            end
            view.rows[index], count = row, index
        end
        for index = count + 1, table.getn(view.rows) do
            view.rows[index] = nil
        end
        table.setn(view.rows, count)
    end
    local function Read(viewSpec, window)
        local context, failure = adapter.Context()
        if not context then return Failure(failure) end
        if state.blocked then return Failure(state.blocked, context) end
        local query = {
            apiVersion = 1,
            runId = context.runId,
            metric = viewSpec.metric,
            scope = viewSpec.scope,
            ownerId = viewSpec.ownerId,
            period = viewSpec.period,
            groupBy = viewSpec.groupBy,
            windowSeconds = window,
            checkpointId = state.checkpoint and state.checkpoint.checkpointId or nil,
        }
        if query.metric == "healing" then query.healingPerspective = viewSpec.healingPerspective or "received" end
        local features = { "completeSourceBreakdowns", "nativeSourceIcons", "localizedMetadata" }
        if query.scope ~= "self" then table.insert(features, "partySourceBreakdowns") end
        if query.metric == "healing" and query.scope ~= "self" then table.insert(features, "partyHealing") end
        if query.healingPerspective == "performed" then table.insert(features, "performedHealing") end
        if window > 0 then table.insert(features, "nativeRecentWindows") end
        if query.checkpointId then table.insert(features, "atomicCheckpoints") end
        for _, key in ipairs(features) do
            local available
            available, failure = Feature(state.capabilities, key)
            if not available then return Failure(failure, context) end
        end
        local view = View(query)
        if view.retryAuthorityId ~= context.authorityId or view.retryCounterEpoch ~= context.counterEpoch then
            ClearRetry(view)
        end
        local deferred = DeferredError(view)
        if deferred then return Failure(deferred, context) end
        local snapshot
        snapshot, failure = Call("AZS_GetMeterSnapshot", query)
        if not snapshot then
            if state.reset and invalidCheckpoints[failure.code] then BlockCheckpoint(failure) end
            RememberError(view, failure)
            view.retryAuthorityId, view.retryCounterEpoch = context.authorityId, context.counterEpoch
            return Failure(failure, context)
        end
        if
            type(snapshot) ~= "table"
            or snapshot.apiVersion ~= 1
            or snapshot.complete ~= true
            or (snapshot.status ~= "ready" and snapshot.status ~= "ready_empty")
            or not ContextValid(snapshot.context)
            or snapshot.context.runId ~= query.runId
            or snapshot.context.uiSessionId ~= context.uiSessionId
            or type(snapshot.query) ~= "table"
            or type(snapshot.rows) ~= "table"
            or type(snapshot.sources) ~= "table"
            or type(snapshot.actors) ~= "table"
            or snapshot.amountBasis ~= (query.checkpointId and "checkpoint" or "period")
            or not Stats(snapshot.totals, query.checkpointId, window)
        then
            return Failure(Malformed(), context)
        end
        for key, value in pairs(query) do
            if snapshot.query[key] ~= value then return Failure(Malformed(), context) end
        end
        for key, value in pairs(snapshot.query) do
            if query[key] ~= value then return Failure(Malformed(), context) end
        end
        CheckCheckpoint(snapshot.context)
        if state.blocked then return Failure(state.blocked, snapshot.context) end
        if
            query.checkpointId
            and (type(snapshot.checkpoint) ~= "table" or snapshot.checkpoint.checkpointId ~= query.checkpointId)
        then
            return Failure(Malformed(), snapshot.context)
        end
        if query.checkpointId then
            for _, key in ipairs({ "runId", "uiSessionId", "authorityId", "counterEpoch", "atRunSeconds", "fenceId" }) do
                if snapshot.checkpoint[key] ~= state.checkpoint[key] then
                    return Failure(Malformed(), snapshot.context)
                end
            end
        end
        if not RowsValid(snapshot, query) then return Failure(Malformed(), snapshot.context) end
        local current = snapshot.context
        if
            view.counterRevision ~= current.counterRevision
            or view.metadataRevision ~= current.metadataRevision
            or view.languageRevision ~= current.languageRevision
            or view.counterEpoch ~= current.counterEpoch
            or view.authorityId ~= current.authorityId
            or view.encounterId ~= (current.encounter and current.encounter.encounterId)
        then
            state.sequence = state.sequence + 1
            view.revision = state.sequence
        end
        view.counterRevision, view.metadataRevision, view.languageRevision =
            current.counterRevision, current.metadataRevision, current.languageRevision
        view.counterEpoch, view.authorityId = current.counterEpoch, current.authorityId
        view.encounterId = current.encounter and current.encounter.encounterId
        CopyRows(view, snapshot, query)
        local average = query.checkpointId and snapshot.totals.checkpointAverage or snapshot.totals.periodAverage
        local meta = {
            averageRate = average.value,
            isReset = state.reset == true,
            amountBasis = snapshot.amountBasis,
            runId = current.runId,
            counterEpoch = current.counterEpoch,
            authorityId = current.authorityId,
            uiSessionId = current.uiSessionId,
            snapshotId = current.snapshotId,
            counterRevision = current.counterRevision,
            metadataRevision = current.metadataRevision,
            languageRevision = current.languageRevision,
            languageCode = current.languageCode,
            recentStatus = snapshot.totals.recentRate.status,
            encounterId = current.encounter and current.encounter.encounterId,
        }
        return view.rows, snapshot.totals.displayAmount, snapshot.totals.displayRate.value, nil, view.revision, meta
    end
    function adapter.Read(viewSpec, window)
        local ok, source, amount, rate, message, revision, meta = pcall(Read, viewSpec, window)
        if not ok then return Failure(Error("INTERNAL_ERROR", "The native meter response could not be read.")) end
        return source, amount, rate, message, revision, meta
    end
    function adapter.Reset()
        local context, failure = adapter.Context()
        if not context then return nil, failure end
        local available
        available, failure = Feature(state.capabilities, "atomicCheckpoints")
        if not available then return nil, failure end
        local checkpoint
        checkpoint, failure = Call("AZS_CreateMeterCheckpoint", context.runId)
        if not checkpoint then return nil, failure end
        if
            type(checkpoint) ~= "table"
            or not Id(checkpoint.checkpointId)
            or checkpoint.runId ~= context.runId
            or checkpoint.uiSessionId ~= context.uiSessionId
            or not Id(checkpoint.authorityId)
            or not Id(checkpoint.counterEpoch)
            or not Id(checkpoint.fenceId)
            or not Number(checkpoint.atRunSeconds)
            or (checkpoint.authorityId == context.authorityId and checkpoint.counterEpoch == context.counterEpoch and checkpoint.atRunSeconds < context.asOfRunSeconds)
            or (state.checkpoint and checkpoint.checkpointId == state.checkpoint.checkpointId)
        then
            if
                type(checkpoint) == "table"
                and (not state.checkpoint or checkpoint.checkpointId ~= state.checkpoint.checkpointId)
            then
                QueueRelease(checkpoint)
            end
            adapter.RetryCleanup()
            return nil, Malformed()
        end
        QueueRelease(state.checkpoint)
        state.checkpoint, state.reset, state.blocked, state.views = checkpoint, true, nil, {}
        adapter.RetryCleanup()
        return true
    end
    function adapter.Clear()
        QueueRelease(state.checkpoint)
        state.checkpoint, state.reset, state.blocked, state.views = nil, false, nil, {}
        ClearRetry(state.contextRetry)
        return adapter.RetryCleanup()
    end
    return adapter
end
