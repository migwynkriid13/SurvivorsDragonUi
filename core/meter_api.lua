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
    function adapter.Supported()
        if state.supported then return true end
        if type(_G.AZS_GetMeterCapabilities) ~= "function" then return false end
        state.supported = true
        return true
    end
    local function Capabilities()
        if state.capabilities then return state.capabilities end
        local result, failure = Call("AZS_GetMeterCapabilities")
        if not result then return nil, failure end
        if type(result) ~= "table" or not Number(result.apiVersion) then return nil, Malformed() end
        if result.apiVersion ~= 1 then
            return nil, Error("UNSUPPORTED_VERSION", "Native meter version 1 is required.")
        end
        for _, name in ipairs(endpoints) do
            if type(_G[name]) ~= "function" then
                return nil, Error("UNSUPPORTED_QUERY", "The native meter endpoint set is incomplete.")
            end
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
        state.views, state.details = {}, nil
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
        if not rawequal(stats.displayRate, selected) and not Rate(stats.displayRate, window == 0) then return false end
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
    local petKinds = { pet = true, summon = true, totem = true }
    local actorKinds =
        { hero = true, pet = true, summon = true, totem = true, enemy = true, system = true, unknown = true }
    local function Actor(actors, id)
        local actor = Id(id) and actors[id]
        if
            type(actor) ~= "table"
            or actor.actorId ~= id
            or not actorKinds[actor.kind]
            or not Id(actor.name)
            or not Portrait(actor.portrait)
            or (actor.state ~= "present" and actor.state ~= "departed" and actor.state ~= "despawned")
            or (actor.summonKey ~= nil and not Id(actor.summonKey))
            or (actor.totemKey ~= nil and not Id(actor.totemKey))
        then
            return
        end
        return actor
    end
    local function RowsValid(snapshot, query)
        if type(snapshot.ownerIds) ~= "table" then return false end
        -- These checks do not depend on order. The greatest positive integer
        -- key equals the entry count only when the list has no holes.
        local count, lastIndex, owners = 0, 0, {}
        for key, owner in pairs(snapshot.ownerIds) do
            if
                not Number(key)
                or key < 1
                or key ~= math.floor(key)
                or not Id(owner)
                or owners[owner]
                or not Hero(snapshot.actors, owner)
                or (query.scope == "self" and owner ~= snapshot.context.localOwnerId)
                or (query.scope == "owner" and owner ~= query.ownerId)
            then
                return false
            end
            owners[owner], count = true, count + 1
            if key > lastIndex then lastIndex = key end
        end
        if lastIndex ~= count or count == 0 or (query.scope ~= "party" and count ~= 1) then return false end
        local seen, maximum = {}, 0
        count, lastIndex = 0, 0
        for key, row in pairs(snapshot.rows) do
            if
                not Number(key)
                or key < 1
                or key ~= math.floor(key)
                or type(row) ~= "table"
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
                if query.groupBy == "actor_source" and not Actor(snapshot.actors, row.actorId) then return false end
            end
            seen[row.rowId], count = true, count + 1
            if key > lastIndex then lastIndex = key end
            maximum = math.max(maximum, row.displayAmount)
        end
        return lastIndex == count
            and (snapshot.status == "ready_empty") == (count == 0)
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
    local function KeyPart(value) return string.len(value) .. ":" .. value end
    local function ActorKey(actor, native)
        local identity
        if actor.kind == "totem" then
            identity = actor.totemKey
        elseif petKinds[actor.kind] then
            identity = actor.summonKey
        end
        local kind = identity and "definition" or "actor"
        return KeyPart(native.ownerId) .. KeyPart(actor.kind) .. KeyPart(kind) .. KeyPart(identity or actor.actorId)
    end
    local familyFields = { "variantKey", "itemInstanceKey", "talentKey", "itemKey" }
    local nonItemOrigins =
        { ability = true, effect = true, talent = true, basic_attack = true, system = true, generic = true }
    local function Rank(source) return Number(source.rank) and source.rank == math.floor(source.rank) end
    local function ItemFields(source)
        for _, field in ipairs(familyFields) do
            if source[field] ~= nil and not Id(source[field]) then return false end
        end
        return source.itemId == nil
            or (Number(source.itemId) and source.itemId > 0 and source.itemId == math.floor(source.itemId))
    end
    local function Item(source)
        return type(source) == "table" and Id(source.itemKey) and Rank(source) and ItemFields(source)
    end
    local function MemberValid(native, leaf)
        if
            type(leaf) == "table"
            and leaf.sourceKey == native.sourceKey
            and leaf.ownerId == native.ownerId
            and (native.actorId == nil or leaf.actorId == native.actorId)
            and leaf.nativeProc == native.nativeProc
            and Number(leaf.displayAmount)
        then
            return leaf
        end
    end
    local function TalentOrigin(source, native, snapshot, row)
        if
            source.kind == "talent"
            or not native.nativeProc
            or (not nonItemOrigins[source.kind] and source.kind ~= "item")
        then
            return
        end
        local count = row.memberCount
        if not count or count == 0 then return end
        local talent
        for _, member in ipairs(row.members) do
            if not member.valid then return end
            if member.positive then
                local origins = member.origins
                if member.originCount ~= 1 then return end
                local origin = snapshot.sources[origins[1]]
                if
                    type(origin) ~= "table"
                    or origin.sourceKey ~= origins[1]
                    or origin.kind ~= "talent"
                    or origin.attribution ~= "known"
                    or not Id(origin.name)
                    or not Icon(origin.icon)
                    or (talent and talent.sourceKey ~= origin.sourceKey)
                then
                    return
                end
                talent = origin
            end
        end
        return talent
    end
    local function BoundItem(source, snapshot, row)
        local own = source.itemKey ~= nil
        local ownRank = Item(source)
        local item, candidate, invalid =
            ownRank and source or nil, own, not ItemFields(source) or (source.rank ~= nil and not Rank(source))
        local missingOrigin, acceptedOrigin = false, nil
        local members = row.memberCount
        if not members or members == 0 then return nil, true end
        for _, member in ipairs(row.members) do
            if not member.valid then
                invalid, candidate = true, true
            elseif member.positive then
                local origins, count = member.origins, member.originCount
                local origin = count == 1 and snapshot.sources[origins[1]] or nil
                if count == false then candidate = true end
                for _, key in ipairs(origins) do
                    local descriptor = snapshot.sources[key]
                    if
                        type(descriptor) ~= "table"
                        or descriptor.sourceKey ~= key
                        or not nonItemOrigins[descriptor.kind]
                    then
                        candidate = true
                    end
                end
                if count == 0 then
                    missingOrigin = true
                elseif count ~= 1 or not Item(origin) or origin.kind ~= "item" or origin.sourceKey ~= origins[1] then
                    invalid = true
                else
                    if
                        (source.itemKey ~= nil and source.itemKey ~= origin.itemKey)
                        or (source.itemInstanceKey ~= nil and origin.itemInstanceKey ~= nil and source.itemInstanceKey ~= origin.itemInstanceKey)
                        or (
                            acceptedOrigin
                            and (
                                acceptedOrigin.itemKey ~= origin.itemKey
                                or acceptedOrigin.rank ~= origin.rank
                                or acceptedOrigin.itemInstanceKey ~= origin.itemInstanceKey
                                or acceptedOrigin.variantKey ~= origin.variantKey
                                or acceptedOrigin.talentKey ~= origin.talentKey
                            )
                        )
                    then
                        invalid = true
                    end
                    item, acceptedOrigin = origin, origin
                end
            end
        end
        if invalid or (missingOrigin and not ownRank) then return nil, candidate end
        return item, candidate
    end
    local function ItemFamilyKey(source, native, snapshot, row)
        if source.kind ~= "item" and source.kind ~= "ability" and source.kind ~= "effect" then return end
        local item, candidate
        if source.kind == "item" then
            item, candidate = Item(source) and source or nil, true
        else
            item, candidate = BoundItem(source, snapshot, row)
        end
        if not item then return nil, nil, candidate end
        local component = source.abilityKey
        if source.kind == "effect" and component == nil then component = source.variantKey end
        if source.kind == "item" and component == nil then component = "" end
        if (component ~= "" and not Id(component)) or (component == "" and source.kind ~= "item") then
            return nil, nil, true
        end
        if not ItemFields(source) then return nil, nil, true end
        local key = "item-rank:"
            .. KeyPart(native.ownerId)
            .. (native.nativeProc and "1" or "0")
            .. KeyPart(source.kind)
            .. KeyPart(component)
            .. KeyPart(item.itemKey)
            .. KeyPart(source.itemInstanceKey or item.itemInstanceKey or "")
            .. KeyPart(source.variantKey or "")
            .. KeyPart(source.talentKey or "")
            .. KeyPart(item ~= source and (item.variantKey or "") or "")
            .. KeyPart(item ~= source and (item.talentKey or "") or "")
        return key, item.rank, true
    end
    local function FamilyDetails(source, pairedTalent)
        local key = ""
        for _, field in ipairs(familyFields) do
            local value = source[field]
            if value ~= nil and not Id(value) then return end
            if pairedTalent and field == "talentKey" and value == pairedTalent then value = nil end
            value = value or ""
            key = key .. string.len(value) .. ":" .. value
        end
        if
            source.itemId ~= nil
            and (not Number(source.itemId) or source.itemId <= 0 or source.itemId ~= math.floor(source.itemId))
        then
            return
        end
        return key .. KeyPart(source.itemId and tostring(source.itemId) or "")
    end
    local function TalentAbilityKey(talentKey)
        if not Id(talentKey) then return end
        local _, _, class, ability = string.find(talentKey, "^([a-z]+)%.([a-z][a-z0-9_]*)_talent$")
        if classes[class] then return ability end
    end
    -- Exact canonical keys pair a skill with class.<skill>_talent, independently
    -- of their received captions. Native accounting/proc roles stay distinct.
    local function SkillPairKey(source, native, actorKey)
        local talentKey = source.talentKey
        local pairedAbility = TalentAbilityKey(talentKey)
        local ability = source.kind == "ability" and native.nativeProc == false
        local talent = source.kind == "talent" and native.nativeProc == true
        local abilityKey = talent and pairedAbility or source.abilityKey
        if
            not (ability or talent)
            or not Id(abilityKey)
            or not string.find(abilityKey, "^[a-z][a-z0-9_]*$")
            or source.attribution ~= "known"
            or not Rank(source)
            or source.rank < 1
            or not Id(native.actorId)
            or not actorKey
            or (ability and talentKey ~= nil and pairedAbility ~= abilityKey)
            or (talent and source.abilityKey ~= nil and source.abilityKey ~= abilityKey)
            or (talent and not pairedAbility)
        then
            return
        end
        local details = FamilyDetails(source, talentKey)
        if not details then return end
        return "skill-pair:" .. KeyPart(abilityKey) .. KeyPart(actorKey) .. details,
            source.rank,
            source.kind .. ":" .. (native.nativeProc and "1:" or "0:") .. tostring(source.rank),
            ability and 1 or 0,
            talentKey
    end
    local function TalentRankKey(source)
        if
            source.kind ~= "talent"
            or source.attribution ~= "known"
            or not Id(source.talentKey)
            or not Rank(source)
            or (source.abilityKey ~= nil and not Id(source.abilityKey))
        then
            return
        end
        local details = FamilyDetails(source)
        if details then
            return "talent-rank:" .. KeyPart(source.talentKey) .. KeyPart(source.abilityKey or "") .. details,
                source.rank
        end
    end
    local function TalentProcKey(source, display, native, actorKey)
        if
            display == source
            or source.kind ~= "ability"
            or source.attribution ~= "known"
            or not Id(source.abilityKey)
            or (source.rank ~= nil and not Rank(source))
        then
            return
        end
        local talentKey, talentRank = TalentRankKey(display)
        local details = FamilyDetails(source)
        if not talentKey or not details then return end
        local key = "talent-proc:"
            .. KeyPart(talentKey)
            .. KeyPart(native.ownerId)
            .. (native.nativeProc and "1" or "0")
            .. KeyPart(actorKey or "")
            .. details
        local slot = tostring(talentRank)
            .. ":"
            .. KeyPart(source.abilityKey)
            .. KeyPart(source.rank ~= nil and tostring(source.rank) or "")
        return key, talentRank, slot, display.sourceKey
    end
    local function FamilyKey(source, native, actorKey, display)
        local talentKey, talentRank = TalentRankKey(source)
        if talentKey then
            return talentKey .. KeyPart(native.ownerId) .. (native.nativeProc and "1" or "0") .. KeyPart(actorKey or ""),
                talentRank
        end
        local procKey, procRank, procSlot, originKey = TalentProcKey(source, display, native, actorKey)
        if procKey then return procKey, procRank, procSlot, originKey end
        if source.kind ~= "ability" or not Id(source.abilityKey) or not Rank(source) then return end
        local details = FamilyDetails(source)
        if not details then return end
        return KeyPart(native.ownerId)
            .. KeyPart(source.abilityKey)
            .. (native.nativeProc and "1" or "0")
            .. details
            .. KeyPart(actorKey or ""),
            source.rank
    end
    local function RowOrder(left, right)
        if left.dmg == right.dmg then return left.order < right.order end
        return left.dmg > right.dmg
    end
    local function GroupRows(view, snapshot, query, sort)
        if not sort then
            for _, family in pairs(view.families) do
                family.row.share = snapshot.totals.displayAmount > 0
                        and math.min(1, family.row.dmg / snapshot.totals.displayAmount)
                    or 0
            end
            return
        end
        local count = 0
        for _, row in ipairs(view.pool) do
            local family = row.family
            if family and not family.ambiguous then
                if not family.emitted then
                    family.emitted = true
                    count = count + 1
                    family.row.share = snapshot.totals.displayAmount > 0
                            and math.min(1, family.row.dmg / snapshot.totals.displayAmount)
                        or 0
                    view.rows[count] = family.row
                end
            else
                count = count + 1
                view.rows[count] = row
            end
        end
        for index = count + 1, table.getn(view.rows) do
            view.rows[index] = nil
        end
        table.setn(view.rows, count)
        if sort and (query.groupBy == "source" or query.groupBy == "actor_source") then
            table.sort(view.rows, RowOrder)
        end
    end
    local function IndexContributions(view, leaves, reset)
        local positions = view.positions or {}
        view.positions = positions
        local count = type(leaves) == "table" and table.getn(leaves) or 0
        local previous = view.positionCount or 0
        if reset or count < previous then
            for id in pairs(positions) do
                positions[id] = nil
            end
            previous = 0
        end
        for index = previous + 1, count do
            local leaf = leaves[index]
            if type(leaf) == "table" and Id(leaf.rowId) then
                if positions[leaf.rowId] ~= nil then
                    positions[leaf.rowId] = false
                else
                    positions[leaf.rowId] = index
                end
            end
        end
        view.positionCount = count
    end
    local function ContributionPosition(view, leaves, id)
        local index = view.positions[id]
        local leaf = index and type(leaves) == "table" and leaves[index]
        if type(leaf) == "table" and leaf.rowId == id then return index end
        if not view.reindexed then
            IndexContributions(view, leaves, true)
            view.reindexed = true
            index = view.positions[id]
            leaf = index and type(leaves) == "table" and leaves[index]
            if type(leaf) == "table" and leaf.rowId == id then return index end
        end
    end
    local function ArrayIndex(index, count)
        return type(index) == "number" and index >= 1 and index <= count and index == math.floor(index)
    end
    local function IdsChanged(cache, values)
        local count = type(values) == "table" and table.getn(values) or nil
        local used, changed = 0, false
        if count then
            for index, id in pairs(values) do
                if not ArrayIndex(index, count) or not Id(id) then
                    count = nil
                    break
                end
                if cache[index] ~= id then changed = true end
                cache[index], used = id, used + 1
            end
            if count and used ~= count then count = nil end
        end
        if count then
            for index = count + 1, table.getn(cache) do
                cache[index], changed = nil, true
            end
        else
            for index in pairs(cache) do
                cache[index], changed = nil, true
            end
        end
        return count, changed
    end
    local function MembersChanged(view, row, native, leaves)
        local values = native.memberIds
        local count = type(values) == "table" and table.getn(values) or nil
        local used, changed = 0, false
        local schoolMask, schoolUnknown
        local periodicity, periodicUnknown
        row.members = row.members or {}
        if count then
            for index, id in pairs(values) do
                if not ArrayIndex(index, count) or not Id(id) then
                    count = nil
                    break
                end
                local member = row.members[index] or { origins = {} }
                local position = ContributionPosition(view, leaves, id)
                local leaf = position and MemberValid(native, leaves[position])
                local positive = leaf and leaf.displayAmount > 0 or false
                if not leaf then
                    schoolUnknown = true
                    periodicUnknown = true
                elseif positive then
                    local mask = leaf.schoolMask
                    if
                        leaf.schoolState ~= "known"
                        or not Number(mask)
                        or mask < 1
                        or mask > 127
                        or mask ~= math.floor(mask)
                    then
                        schoolUnknown = true
                    elseif schoolMask and schoolMask ~= mask then
                        schoolUnknown = true
                    else
                        schoolMask = mask
                    end
                    local value = leaf.periodicity
                    if leaf.creditKind ~= "health_damage" or (value ~= "periodic" and value ~= "non_periodic") then
                        periodicUnknown = true
                    elseif periodicity and periodicity ~= value then
                        periodicUnknown = true
                    else
                        periodicity = value
                    end
                end
                local origins, originsChanged = IdsChanged(member.origins, positive and leaf.originSourceKeys or nil)
                if positive then
                    origins = origins or false
                else
                    origins = 0
                end
                if
                    originsChanged
                    or member.id ~= id
                    or member.valid ~= (leaf ~= nil)
                    or member.positive ~= positive
                    or member.originCount ~= origins
                then
                    changed = true
                end
                member.id, member.valid, member.positive, member.originCount = id, leaf ~= nil, positive, origins
                row.members[index], used = member, used + 1
            end
            if count and used ~= count then count = nil end
        end
        if count then
            for index = count + 1, table.getn(row.members) do
                row.members[index], changed = nil, true
            end
        else
            for index in pairs(row.members) do
                row.members[index], changed = nil, true
            end
        end
        if row.memberCount ~= count then changed = true end
        row.memberCount = count
        -- Presentation metadata does not change attribution/rate identities.
        row.schoolMask = count and not schoolUnknown and schoolMask or nil
        row.periodicDamage = count and not periodicUnknown and periodicity == "periodic" or nil
        return changed
    end
    local sourceFields = {
        "sourceKey",
        "kind",
        "name",
        "attribution",
        "abilityKey",
        "rank",
        "variantKey",
        "itemInstanceKey",
        "talentKey",
        "itemKey",
        "itemId",
    }
    local actorFields = { "actorId", "kind", "name", "classKey", "state", "summonKey", "totemKey" }
    local iconFields = { "status", "path", "reason", "retryAfterSeconds", "portraitKey" }
    local function FieldsChanged(cache, value, fields)
        local present = type(value) == "table"
        local changed = cache.present ~= present
        cache.present = present
        for index, key in ipairs(fields) do
            local field
            if present then field = value[key] end
            if cache[index] ~= field then changed = true end
            cache[index] = field
        end
        return changed
    end
    local function DescriptorChanged(cache, value, fields, art)
        local changed = FieldsChanged(cache, value, fields)
        cache.art = cache.art or {}
        if FieldsChanged(cache.art, type(value) == "table" and value[art], iconFields) then changed = true end
        return changed
    end
    local function MetadataChanged(row, native, snapshot, query)
        row.sourceMetadata, row.actorMetadata, row.originMetadata =
            row.sourceMetadata or {}, row.actorMetadata or {}, row.originMetadata or {}
        local source = query.groupBy ~= "owner" and snapshot.sources[native.sourceKey] or nil
        local actor = (query.groupBy == "owner" or query.groupBy == "actor_source")
                and snapshot.actors[native.actorId or native.ownerId]
            or nil
        local changed = DescriptorChanged(row.sourceMetadata, source, sourceFields, "icon")
        if DescriptorChanged(row.actorMetadata, actor, actorFields, "portrait") then changed = true end
        for _, origin in pairs(row.originMetadata) do
            origin.used = false
        end
        for _, member in ipairs(row.members or {}) do
            for _, key in ipairs(member.origins) do
                local origin = row.originMetadata[key] or {}
                if not origin.used and DescriptorChanged(origin, snapshot.sources[key], sourceFields, "icon") then
                    changed = true
                end
                origin.used, row.originMetadata[key] = true, origin
            end
        end
        for key, origin in pairs(row.originMetadata) do
            if not origin.used then
                row.originMetadata[key] = nil
                changed = true
            end
        end
        return changed
    end
    local function PrepareRow(view, row, native, snapshot, query)
        row.icon, row.iconStatus, row.class = nil, nil, nil
        row.portraitKey, row.portraitRunId, row.portraitStatus = nil, nil, nil
        row.familyKey, row.familyRank, row.groupKind = nil, nil, nil
        row.familyTalentRank, row.familyRankKey, row.familyMemberKey = nil, nil, nil
        row.familyOriginKey = nil
        row.familyPriority = nil
        row.familyPairTalent = nil
        row.familyName = nil
        row.colorKind = nil
        if query.groupBy == "owner" then
            row.schoolMask = nil
            row.periodicDamage = nil
            local actor = snapshot.actors[native.ownerId]
            row.name, row.class, row.proc = actor.name, actor.classKey, 0
            row.portraitKey, row.portraitRunId, row.portraitStatus =
                actor.portrait.portraitKey, snapshot.context.runId, actor.portrait.status
            return
        end
        local source = snapshot.sources[native.sourceKey]
        local actor = query.groupBy == "actor_source" and snapshot.actors[native.actorId] or nil
        local pet = actor and petKinds[actor.kind]
        local display = TalentOrigin(source, native, snapshot, row) or source
        row.colorKind = (nonItemOrigins[display.kind] or display.kind == "item") and display.kind or nil
        row.proc, row.iconStatus = native.nativeProc and 1 or 0, display.icon.status
        if display.icon.status == "ready" then row.icon = display.icon.path end
        row.name = pet and display.name ~= actor.name and (display.name .. " (" .. actor.name .. ")") or display.name
        row.actorId, row.actorName = actor and actor.actorId, actor and actor.name
        row.actorPortraitKey = actor and actor.portrait.portraitKey
        row.actorPortraitStatus = actor and actor.portrait.status
        local actorKey = actor and ActorKey(actor, native)
        if query.groupBy == "source" or query.groupBy == "actor_source" then
            -- Item accounting spans casters; pet summaries contain the remaining sources.
            local itemCandidate
            row.familyKey, row.familyRank, itemCandidate = ItemFamilyKey(source, native, snapshot, row)
            if row.familyKey then
                row.groupKind, row.familyName = "rank", display.name
                row.colorKind = "item"
            elseif pet and view.groupPets then
                row.familyKey, row.groupKind = "pet:" .. actorKey, "pet"
            else
                if not itemCandidate then
                    if query.metric == "damage" then
                        row.familyKey, row.familyRank, row.familyRankKey, row.familyPriority, row.familyPairTalent =
                            SkillPairKey(source, native, actorKey)
                    end
                    if not row.familyKey then
                        row.familyKey, row.familyRank, row.familyRankKey, row.familyOriginKey =
                            FamilyKey(source, native, actorKey, display)
                    end
                end
                if row.familyKey then
                    row.groupKind = "rank"
                elseif pet then
                    row.familyKey = "pet-source:"
                        .. actorKey
                        .. KeyPart(native.sourceKey)
                        .. (native.nativeProc and "1" or "0")
                    row.groupKind = "source"
                end
            end
            if row.familyKey and row.groupKind ~= "pet" and display ~= source and not row.familyOriginKey then
                local talentKey, talentRank
                if row.groupKind == "rank" then
                    talentKey, talentRank = TalentRankKey(display)
                end
                row.familyKey = row.familyKey
                    .. (talentKey and ":talent-rank:" or ":talent:")
                    .. KeyPart(talentKey or display.sourceKey)
                row.familyTalentRank = talentRank
                if talentRank then row.familyMemberKey = KeyPart(native.sourceKey) .. KeyPart(display.sourceKey) end
            end
            if row.groupKind == "rank" then
                row.familyRankKey = row.familyRankKey
                    or (
                        row.familyTalentRank
                            and (tostring(row.familyRank) .. ":talent:" .. tostring(row.familyTalentRank))
                        or row.familyRank
                    )
                row.familyMemberKey = row.familyOriginKey
                        and (KeyPart(native.sourceKey) .. KeyPart(row.familyOriginKey))
                    or row.familyMemberKey
                    or native.sourceKey
            end
        end
    end
    local function PrepareFamilies(view, snapshot)
        for _, family in pairs(view.families) do
            family.used, family.ambiguous, family.rank, family.actorId = false, false, nil, nil
            family.talentRank, family.priority = nil, nil
            family.pairTalent = nil
            family.pairRoles, family.pairActorConflict = nil, nil
            family.previousCount, family.count, family.rateChanged = family.count or 0, 0, false
            for rank in pairs(family.ranks) do
                family.ranks[rank] = nil
            end
            if family.talentOrigins then
                for rank in pairs(family.talentOrigins) do
                    family.talentOrigins[rank] = nil
                end
            end
        end
        for _, row in ipairs(view.pool) do
            local key = row.familyKey
            local previous = row.family
            row.family = nil
            if key then
                local family = view.families[key]
                if not family then
                    family = { row = {}, token = {}, ranks = {}, count = 0, previousCount = 0 }
                    view.families[key] = family
                end
                local grouped = family.row
                family.count = family.count + 1
                if previous ~= family or row.rateChanged then family.rateChanged = true end
                if previous and previous ~= family then previous.rateChanged = true end
                if not family.used then
                    grouped.rowId, grouped.order, grouped.proc = family.token, row.order, row.proc
                    grouped.portraitKey, grouped.portraitRunId, grouped.portraitStatus = nil, nil, nil
                elseif grouped.proc ~= row.proc then
                    grouped.proc = 0
                end
                if row.groupKind == "rank" then
                    if row.familyPriority ~= nil then
                        local role = row.familyPriority == 1 and 1 or 2
                        if not family.pairRoles then
                            family.pairRoles = role
                        elseif family.pairRoles ~= role then
                            family.pairRoles = 3
                        end
                        if family.actorId and family.actorId ~= row.nativeActor then family.pairActorConflict = true end
                        family.actorId = row.nativeActor
                    end
                    if row.familyPairTalent then
                        if family.pairTalent and family.pairTalent ~= row.familyPairTalent then
                            family.ambiguous = true
                        end
                        family.pairTalent = row.familyPairTalent
                    end
                    local previous = family.ranks[row.familyRankKey]
                    if previous and previous ~= row.familyMemberKey then family.ambiguous = true end
                    family.ranks[row.familyRankKey] = row.familyMemberKey
                    if row.familyOriginKey then
                        family.talentOrigins = family.talentOrigins or {}
                        local origin = family.talentOrigins[row.familyRank]
                        if origin and origin ~= row.familyOriginKey then family.ambiguous = true end
                        family.talentOrigins[row.familyRank] = row.familyOriginKey
                    end
                end
                local priority = row.familyPriority or 0
                if row.groupKind == "pet" then
                    if not family.actorId or row.actorId < family.actorId then
                        grouped.name, grouped.icon, grouped.iconStatus = row.actorName, nil, nil
                        grouped.portraitKey, grouped.portraitRunId, grouped.portraitStatus =
                            row.actorPortraitKey, snapshot.context.runId, row.actorPortraitStatus
                        family.actorId = row.actorId
                    end
                elseif
                    row.groupKind == "source"
                    or not family.rank
                    or priority > (family.priority or 0)
                    or (
                        priority == (family.priority or 0)
                        and (
                            row.familyRank > family.rank
                            or (
                                row.familyRank == family.rank
                                and row.familyTalentRank
                                and (not family.talentRank or row.familyTalentRank > family.talentRank)
                            )
                        )
                    )
                then
                    grouped.name, grouped.iconStatus, grouped.icon =
                        row.familyName or row.name, row.iconStatus, row.icon
                    family.rank, family.talentRank = row.familyRank, row.familyTalentRank
                    family.priority = priority
                end
                row.family, family.used = family, true
            elseif previous then
                previous.rateChanged = true
            end
        end
        for key, family in pairs(view.families) do
            if family.pairRoles == 3 and family.pairActorConflict then family.ambiguous = true end
            if not family.used then
                view.families[key] = nil
            elseif family.rateChanged or family.count ~= family.previousCount then
                family.row.rateIdentity = {}
            end
        end
    end
    local function CopyRows(view, snapshot, query, deferRecent)
        view.pool, view.families, view.identities = view.pool or {}, view.families or {}, view.identities or {}
        local current = snapshot.context
        local metadata = view.preparedMetadata ~= current.metadataRevision
        local invalidate = view.preparedLanguage ~= current.languageRevision
            or view.preparedEpoch ~= current.counterEpoch
            or view.preparedAuthority ~= current.authorityId
            or view.preparedEncounter ~= (current.encounter and current.encounter.encounterId)
            or view.preparedPets ~= view.groupPets
        local mapping, amounts, count = invalidate, false, 0
        view.reindexed = false
        if query.groupBy ~= "owner" then IndexContributions(view, snapshot.contributions, false) end
        for _, row in pairs(view.identities) do
            row.present = false
        end
        for index, native in ipairs(snapshot.rows) do
            local row = view.identities[native.rowId] or {}
            local dirty = invalidate
                or row.nativeSource ~= native.sourceKey
                or row.nativeOwner ~= native.ownerId
                or row.nativeActor ~= native.actorId
                or row.nativeProc ~= native.nativeProc
            if query.groupBy ~= "owner" and MembersChanged(view, row, native, snapshot.contributions) then
                dirty = true
            end
            if dirty or metadata then
                if MetadataChanged(row, native, snapshot, query) then dirty = true end
            end
            if view.pool[index] ~= row or dirty then mapping = true end
            row.rowId, row.order, row.present = native.rowId, index, true
            row.nativeSource, row.nativeOwner, row.nativeActor, row.nativeProc =
                native.sourceKey, native.ownerId, native.actorId, native.nativeProc
            local average = query.checkpointId and native.checkpointAverage or native.periodAverage
            if row.dmg ~= native.displayAmount then amounts = true end
            row.dmg, row.dps, row.averageDps, row.share =
                native.displayAmount, not deferRecent and native.displayRate.value or nil, average.value, native.share
            row.rateChanged = dirty or row.name == nil
            if row.rateChanged then
                row.rateIdentity = {}
                PrepareRow(view, row, native, snapshot, query)
            end
            view.pool[index], view.identities[native.rowId], count = row, row, index
        end
        if view.reindexed and query.groupBy ~= "owner" then
            for index, native in ipairs(snapshot.rows) do
                local row = view.pool[index]
                if MembersChanged(view, row, native, snapshot.contributions) then
                    MetadataChanged(row, native, snapshot, query)
                    PrepareRow(view, row, native, snapshot, query)
                    row.rateIdentity, row.rateChanged = {}, true
                    mapping = true
                end
            end
        end
        for index = count + 1, table.getn(view.pool) do
            view.pool[index] = nil
        end
        table.setn(view.pool, count)
        for id, row in pairs(view.identities) do
            if not row.present then
                view.identities[id] = nil
                mapping = true
            end
        end
        if mapping then PrepareFamilies(view, snapshot) end
        for _, family in pairs(view.families) do
            family.summed, family.emitted = false, false
        end
        for _, row in ipairs(view.pool) do
            local family = row.family
            if family then
                local grouped = family.row
                if not family.summed then
                    grouped.dmg, grouped.dps, grouped.averageDps = row.dmg, row.dps, row.averageDps
                    grouped.schoolMask = row.schoolMask
                    grouped.colorKind, grouped.periodicDamage = row.colorKind, row.periodicDamage
                    family.summed = true
                else
                    if grouped.schoolMask ~= row.schoolMask then grouped.schoolMask = nil end
                    if grouped.colorKind ~= row.colorKind then grouped.colorKind = nil end
                    if not row.periodicDamage then grouped.periodicDamage = nil end
                    grouped.dmg = grouped.dmg + row.dmg
                    grouped.dps = grouped.dps and row.dps and grouped.dps + row.dps or nil
                    grouped.averageDps = grouped.averageDps and row.averageDps and grouped.averageDps + row.averageDps
                        or nil
                end
                if
                    not Number(grouped.dmg)
                    or (grouped.dps ~= nil and not Number(grouped.dps))
                    or (grouped.averageDps ~= nil and not Number(grouped.averageDps))
                then
                    return false
                end
            end
        end
        GroupRows(view, snapshot, query, mapping or amounts)
        view.preparedMetadata, view.preparedLanguage, view.preparedEpoch =
            current.metadataRevision, current.languageRevision, current.counterEpoch
        view.preparedAuthority, view.preparedEncounter, view.preparedPets =
            current.authorityId, current.encounter and current.encounter.encounterId, view.groupPets
        return true
    end
    local function DetailValue(value)
        local kind = type(value)
        if kind == "string" or kind == "number" or kind == "boolean" then
            return string.gsub(tostring(value), "|", "||")
        end
        return "--"
    end
    local function DetailField(metadata, field)
        for index, key in ipairs(sourceFields) do
            if key == field then return metadata[index] end
        end
    end
    local function DetailLine(details, text)
        if details.count < 23 then
            details.count = details.count + 1
            details.lines[details.count] = text
        else
            details.truncated = true
        end
    end
    local function DetailMetadata(details, metadata)
        if not metadata.present then return end
        DetailLine(
            details,
            "kind="
                .. DetailValue(DetailField(metadata, "kind"))
                .. "; attribution="
                .. DetailValue(DetailField(metadata, "attribution"))
                .. "; rank="
                .. DetailValue(DetailField(metadata, "rank"))
        )
        for index, key in ipairs(sourceFields) do
            if
                key ~= "sourceKey"
                and key ~= "kind"
                and key ~= "name"
                and key ~= "attribution"
                and key ~= "rank"
                and metadata[index] ~= nil
            then
                DetailLine(details, key .. ": " .. DetailValue(metadata[index]))
            end
        end
    end
    function adapter.Describe(source, rowId)
        if state.blocked then return end
        for _, view in ipairs(state.views) do
            if view.rows == source and view.capture then
                local display
                for _, row in ipairs(view.rows) do
                    if row.rowId == rowId then
                        display = row
                        break
                    end
                end
                if not display then return end
                local details = state.details
                if
                    details
                    and details.view == view
                    and details.rowId == rowId
                    and details.identity == display.rateIdentity
                then
                    return details.lines
                end
                details = details or { lines = {} }
                for index = table.getn(details.lines), 1, -1 do
                    details.lines[index] = nil
                end
                details.view, details.rowId, details.identity = view, rowId, display.rateIdentity
                details.truncated, details.count = false, 0
                local count = 0
                for _, row in ipairs(view.pool) do
                    if row == display or (row.family and not row.family.ambiguous and row.family.row == display) then
                        count = count + 1
                        if count <= 3 then
                            DetailLine(details, "rowId: " .. DetailValue(row.rowId))
                            if row.nativeSource then
                                DetailLine(details, "sourceKey: " .. DetailValue(row.nativeSource))
                            end
                            DetailLine(
                                details,
                                "ownerId: "
                                    .. DetailValue(row.nativeOwner)
                                    .. "; actorId: "
                                    .. DetailValue(row.nativeActor)
                                    .. "; nativeProc="
                                    .. DetailValue(row.nativeProc)
                            )
                            DetailMetadata(details, row.sourceMetadata)
                            local origins = 0
                            for key, metadata in pairs(row.originMetadata) do
                                origins = origins + 1
                                if origins <= 3 then
                                    DetailLine(details, "originSourceKey: " .. DetailValue(key))
                                    DetailMetadata(details, metadata)
                                else
                                    details.truncated = true
                                end
                            end
                        else
                            details.truncated = true
                        end
                    end
                end
                if details.truncated then
                    details.count = details.count + 1
                    details.lines[details.count] = "..."
                end
                table.setn(details.lines, details.count)
                state.details = details
                return details.lines
            end
        end
    end
    local captureFields = {
        "snapshotId",
        "uiSessionId",
        "runId",
        "authorityId",
        "counterEpoch",
        "counterRevision",
        "metadataRevision",
        "languageRevision",
        "languageCode",
        "phase",
        "asOfRunSeconds",
        "localOwnerId",
        "partyState",
        "partyId",
    }
    local encounterFields = { "encounterId", "state", "startRunSeconds", "endRunSeconds", "startFenceId", "endFenceId" }
    local function Capture(context, saved)
        if not saved then return false end
        for _, key in ipairs(captureFields) do
            if context[key] ~= saved[key] then return false end
        end
        local encounter = context.encounter
        if (encounter ~= nil) ~= saved.hasEncounter then return false end
        if encounter then
            for _, key in ipairs(encounterFields) do
                if encounter[key] ~= saved.encounter[key] then return false end
            end
        end
        return true
    end
    local function SaveCapture(view, context)
        local saved = view.captureStorage or { encounter = {} }
        view.captureStorage = saved
        for _, key in ipairs(captureFields) do
            saved[key] = context[key]
        end
        saved.hasEncounter = context.encounter ~= nil
        for _, key in ipairs(encounterFields) do
            saved.encounter[key] = context.encounter and context.encounter[key]
        end
        view.capture = saved
    end
    local function ReadCapture(view, query, context, groupPets, sharedContext, deferRecent)
        local retryKey = query.windowSeconds > 0 and "recentRetry" or "counterRetry"
        local attempt = view[retryKey] or {}
        view[retryKey] = attempt
        local failure
        if attempt.retryAuthorityId ~= context.authorityId or attempt.retryCounterEpoch ~= context.counterEpoch then
            ClearRetry(attempt)
        end
        local deferred = DeferredError(attempt)
        if deferred then return Failure(deferred, context) end
        if
            sharedContext ~= nil
            and view.captureWindow == query.windowSeconds
            and view.groupPets == (groupPets == true)
            and Capture(context, view.capture)
        then
            return view.rows, view.acceptedAmount, view.acceptedRate, nil, view.revision, view.acceptedMeta
        end
        view.capture = nil
        local snapshot
        snapshot, failure = Call("AZS_GetMeterSnapshot", query)
        if not snapshot then
            if state.reset and invalidCheckpoints[failure.code] then BlockCheckpoint(failure) end
            RememberError(attempt, failure)
            attempt.retryAuthorityId, attempt.retryCounterEpoch = context.authorityId, context.counterEpoch
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
            or not Stats(snapshot.totals, query.checkpointId, query.windowSeconds)
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
            or view.groupPets ~= (groupPets == true)
        then
            state.sequence = state.sequence + 1
            view.revision = state.sequence
        end
        view.counterRevision, view.metadataRevision, view.languageRevision =
            current.counterRevision, current.metadataRevision, current.languageRevision
        view.counterEpoch, view.authorityId = current.counterEpoch, current.authorityId
        view.encounterId = current.encounter and current.encounter.encounterId
        view.groupPets = groupPets == true
        if not CopyRows(view, snapshot, query, deferRecent) then return Failure(Malformed(), current) end
        local average = query.checkpointId and snapshot.totals.checkpointAverage or snapshot.totals.periodAverage
        local meta = {
            averageRate = average.value,
            asOfRunSeconds = current.asOfRunSeconds,
            isReset = state.reset == true,
            amountBasis = snapshot.amountBasis,
            runId = current.runId,
            counterEpoch = current.counterEpoch,
            authorityId = current.authorityId,
            localOwnerId = current.localOwnerId,
            uiSessionId = current.uiSessionId,
            snapshotId = current.snapshotId,
            counterRevision = current.counterRevision,
            metadataRevision = current.metadataRevision,
            languageRevision = current.languageRevision,
            languageCode = current.languageCode,
            recentStatus = snapshot.totals.recentRate.status,
            encounterId = current.encounter and current.encounter.encounterId,
        }
        view.acceptedAmount, view.acceptedRate, view.acceptedMeta =
            snapshot.totals.displayAmount, snapshot.totals.displayRate.value, meta
        SaveCapture(view, current)
        view.captureWindow = query.windowSeconds
        return view.rows, view.acceptedAmount, view.acceptedRate, nil, view.revision, meta
    end
    -- These samples contain only native rates for the current visible identities.
    -- Zero-window captures never supply recent DPS, including during warmup/gaps.
    local function ClearRecent(view)
        view.rateContext, view.recentRows, view.recentRate, view.recentStatus = nil, nil, nil, nil
    end
    function adapter.SuspendRecent()
        for _, view in ipairs(state.views) do
            ClearRecent(view)
        end
    end
    local function RateContext(view, meta)
        local saved = view.rateContext
        return saved
            and saved.runId == meta.runId
            and saved.uiSessionId == meta.uiSessionId
            and saved.authorityId == meta.authorityId
            and saved.counterEpoch == meta.counterEpoch
            and saved.localOwnerId == meta.localOwnerId
            and saved.encounterId == (meta.encounter and meta.encounter.encounterId or meta.encounterId)
            and meta.asOfRunSeconds >= saved.asOfRunSeconds
    end
    local function RateBounds(view, policy)
        local count = table.getn(view.rows)
        local offset = math.max(0, math.min(policy.offset, count - policy.count))
        return offset + 1, math.min(count, offset + policy.count)
    end
    local function HasRecent(view, policy, meta)
        if not RateContext(view, meta) then return false end
        local first, last = RateBounds(view, policy)
        local samples = view.recentRows
        for index = first, last do
            local row = view.rows[index]
            local sample = samples[row.rowId]
            if not sample or sample.identity ~= row.rateIdentity then return false end
        end
        return true
    end
    local function RestoreRecent(view, policy, meta)
        if not HasRecent(view, policy, meta) then return false end
        local first, last = RateBounds(view, policy)
        local samples = view.recentRows
        for _, sample in pairs(samples) do
            sample.used = false
        end
        for index = first, last do
            local row = view.rows[index]
            local sample = samples[row.rowId]
            row.dps, row.averageDps, sample.used = sample.rate, sample.average, true
        end
        for id, sample in pairs(samples) do
            if not sample.used then samples[id] = nil end
        end
        meta.recentStatus, meta.recentAsOfRunSeconds = view.recentStatus, view.rateContext.asOfRunSeconds
        return true
    end
    local function SaveRecent(view, policy, meta)
        local samples = view.recentRows or {}
        view.recentRows = samples
        for _, sample in pairs(samples) do
            sample.used = false
        end
        local first, last = RateBounds(view, policy)
        for index = first, last do
            local row = view.rows[index]
            local sample = samples[row.rowId] or {}
            sample.identity, sample.rate, sample.average, sample.used = row.rateIdentity, row.dps, row.averageDps, true
            samples[row.rowId] = sample
        end
        for id, sample in pairs(samples) do
            if not sample.used then samples[id] = nil end
        end
        local saved = view.rateContext or {}
        view.rateContext = saved
        for _, key in ipairs({
            "runId",
            "uiSessionId",
            "authorityId",
            "counterEpoch",
            "localOwnerId",
            "encounterId",
            "asOfRunSeconds",
        }) do
            saved[key] = meta[key]
        end
        view.recentRate, view.recentStatus = view.acceptedRate, meta.recentStatus
        meta.recentAsOfRunSeconds = meta.asOfRunSeconds
    end
    local function Read(viewSpec, window, groupPets, sharedContext, rateView)
        local context, failure
        if sharedContext ~= nil then
            local capabilities
            capabilities, failure = Capabilities()
            if not capabilities then return Failure(failure) end
            if not ContextValid(sharedContext) or sharedContext.uiSessionId ~= capabilities.uiSessionId then
                return Failure(Malformed())
            end
            context = sharedContext
            CheckCheckpoint(context)
        else
            context, failure = adapter.Context()
        end
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
        local scheduled = window > 0 and rateView ~= nil
        if
            scheduled
            and (
                type(rateView) ~= "table"
                or not Number(rateView.offset)
                or rateView.offset ~= math.floor(rateView.offset)
                or not Number(rateView.count)
                or rateView.count < 1
                or rateView.count > 10
                or rateView.count ~= math.floor(rateView.count)
                or type(rateView.refresh) ~= "boolean"
            )
        then
            return Failure(Malformed(), context)
        end
        for _, cached in ipairs(state.views) do
            if cached ~= view or not scheduled then ClearRecent(cached) end
        end
        if scheduled and not rateView.refresh and HasRecent(view, rateView, context) then query.windowSeconds = 0 end
        local previous = view.acceptedAmount
        local source, amount, rate, message, revision, meta =
            ReadCapture(view, query, context, groupPets, sharedContext, scheduled and query.windowSeconds == 0)
        if not source then
            if scheduled then ClearRecent(view) end
            return source, amount, rate, message, revision, meta
        end
        if scheduled and query.windowSeconds == 0 then
            if (previous and amount < previous) or not RestoreRecent(view, rateView, meta) then
                query.windowSeconds = window
                source, amount, rate, message, revision, meta =
                    ReadCapture(view, query, context, groupPets, sharedContext, false)
                if not source then
                    ClearRecent(view)
                    return source, amount, rate, message, revision, meta
                end
            end
        end
        if scheduled then
            if query.windowSeconds > 0 then SaveRecent(view, rateView, meta) end
            rate = view.recentRate
        end
        return source, amount, rate, message, revision, meta
    end
    function adapter.Read(viewSpec, window, groupPets, sharedContext, rateView)
        local ok, source, amount, rate, message, revision, meta =
            pcall(Read, viewSpec, window, groupPets, sharedContext, rateView)
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
        state.checkpoint, state.reset, state.blocked, state.views, state.details = checkpoint, true, nil, {}, nil
        adapter.RetryCleanup()
        return true
    end
    function adapter.Clear()
        QueueRelease(state.checkpoint)
        state.checkpoint, state.reset, state.blocked, state.views, state.details = nil, false, nil, {}, nil
        ClearRetry(state.contextRetry)
        return adapter.RetryCleanup()
    end
    return adapter
end
