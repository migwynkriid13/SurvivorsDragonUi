-- CI only: production SCT and native adapter over explicit fake game endpoints.
assert(_VERSION == "Lua 5.1", "native SCT fixtures require CI Lua 5.1")
local SCT = dofile("scripts/tests/fixtures/ui_sct_helpers.lua")
local passed = 0
local function Test(name, callback)
    callback()
    passed = passed + 1
    print("PASS " .. name)
end

local function Scene(style, performance, configure)
    local context = SCT(style == "msbt", function(context, env)
        context.settings.sctStyle, context.settings.performanceMode = style, performance == true
        context.settings.sctDirectDamage, context.settings.sctPetDamage = true, true
        context.settings.sctPeriodicDamage, context.settings.sctReflectedDamage = true, true
        local random = {}
        for key, value in pairs(math) do
            random[key] = value
        end
        random.random = function(low) return low end
        env.math = random
        local native = {
            events = {},
            points = {},
            reads = 0,
            projections = 0,
            handlers = {},
            registers = 0,
            unregisters = 0,
            streamId = "stream-one",
            worldId = "world-one",
        }
        context.native = native
        env.AZS_GetCombatTextCapabilities = function(...)
            assert(select("#", ...) == 0, "capabilities received arguments")
            return {
                apiVersion = 1,
                impactAnchors = true,
                followAnchors = true,
                frameProjection = true,
                distanceMetrics = true,
                frameHandler = true,
                maxEventsPerRead = 256,
                maxAnchorsPerRead = 256,
                eventCapacity = 4096,
                anchorCapacity = 4096,
                eventRetentionSeconds = 5,
                anchorRetentionSeconds = 5,
            }
        end
        env.AZS_RegisterCombatTextFrameHandler = function(handler)
            assert(type(handler) == "function", "invalid native frame handler")
            native.registers = native.registers + 1
            native.handlers[handler] = true
            if native.registerFault then return nil, { code = "NOT_READY", message = "registration failed" } end
            return true
        end
        env.AZS_UnregisterCombatTextFrameHandler = function(handler)
            native.unregisters = native.unregisters + 1
            if native.unregisterFault then return nil, { code = "NOT_READY", message = "release failed" } end
            native.handlers[handler] = nil
            return true
        end
        env.AZS_GetCombatTextEvents = function(cursor, limit)
            assert(native.inHandler, "native events read before the post-camera phase")
            native.reads = native.reads + 1
            assert(limit == 256, "native event reads exceeded the advertised limit")
            local from = #native.events
            if cursor then
                local prefix, position = string.match(cursor, "^(.*):(%d+)$")
                if prefix ~= native.streamId then return nil, { code = "STREAM_CHANGED", message = "retired" } end
                from = tonumber(position)
            end
            local events, ending = {}, math.min(#native.events, from + limit)
            for index = from + 1, ending do
                table.insert(events, native.events[index])
            end
            local batch = {
                apiVersion = 1,
                streamId = native.streamId,
                worldId = native.worldId,
                clockSeconds = context.now,
                cursor = native.streamId .. ":" .. ending,
                events = events,
                hasMore = ending < #native.events,
                droppedCount = 0,
            }
            if native.readFault then return native.readFault(batch) end
            return batch
        end
        env.AZS_ProjectCombatTextAnchors = function(ids, mode)
            native.projections = native.projections + 1
            assert(mode == "follow" and #ids > 0 and #ids <= 256, "invalid projection request")
            local entries = {}
            for index, id in ipairs(ids) do
                local point = native.points[id] or { state = "unknownAnchor" }
                local entry = { anchorId = id }
                for key, value in pairs(point) do
                    entry[key] = value
                end
                entries[index] = entry
            end
            local projection = {
                apiVersion = 1,
                streamId = native.streamId,
                worldId = native.worldId,
                clockSeconds = context.now,
                cameraSampleId = tostring(context.now),
                frameCurrent = native.inHandler == true,
                entries = entries,
            }
            if native.projectFault then return native.projectFault(projection) end
            return projection
        end
        if configure then configure(context, env) end
    end)
    function context:NativeHit(amount, fields)
        local index = #self.native.events + 1
        local event = {
            eventId = tostring(index),
            presentedAt = self.now,
            targetId = "target-one",
            targetName = "Same enemy name",
            sourceId = "player-one",
            sourceKind = "player",
            kind = "damage",
            amount = amount,
            critical = false,
            periodic = false,
            reflected = false,
            damageType = "spell",
            schoolMask = 4,
            spellId = 133,
            abilityName = "Native attack",
            icon = "Interface\\Icons\\Spell_Fire_FireBolt",
            anchorId = "anchor:" .. index,
            anchorStatus = "ready",
        }
        for key, value in pairs(fields or {}) do
            event[key] = value
        end
        self.native.events[index] = event
        if event.anchorId then
            self.native.points[event.anchorId] = {
                state = "onScreen",
                targetState = "alive",
                x = 200,
                y = 300,
                cameraDistance = 20,
                cameraDepth = 20,
                uiUnitsPerYard = 16,
            }
        end
        return event, self.native.points[event.anchorId]
    end
    local earlyTick = context.Tick
    function context:BeforeCamera(elapsed) earlyTick(self, elapsed) end
    function context:AfterCamera()
        local handlers = {}
        for handler in pairs(self.native.handlers) do
            table.insert(handlers, handler)
        end
        self.native.inHandler = true
        for _, handler in ipairs(handlers) do
            if self.native.handlers[handler] then handler() end
        end
        self.native.inHandler = false
    end
    function context:Tick(elapsed)
        self:BeforeCamera(elapsed)
        self:AfterCamera()
    end
    function context:Prime() self:Tick(0.01) end
    return context
end
local function Holder(label) return label:GetParent():GetParent() end
local function Close(left, right) assert(math.abs(left - right) < 0.000001, "trajectory changed") end
local function HandlerCount(context)
    local count = 0
    for _ in pairs(context.native.handlers) do
        count = count + 1
    end
    return count
end

Test("documented events and label positioning run only in the post-camera handler", function()
    local context = Scene("enemy", false)
    assert(HandlerCount(context) == 1 and context.native.registers == 1, "native frame handler was not acquired once")
    context:Prime()
    local event, point = context:NativeHit(123)
    assert(
        event.basicAttack == nil and event.abilityKey == nil and event.spellId == 133,
        "fixture retained proposed fields"
    )
    local reads = context.native.reads
    context:BeforeCamera(0.31)
    assert(
        context.native.reads == reads and context.native.projections == 0 and #context:Labels() == 0,
        "OnUpdate ran native SCT"
    )
    point.x = 600
    context:AfterCamera()
    local label = assert(context:Labels()[1])
    Close(Holder(label).anchor.x, 600)
    local x, projections = Holder(label).anchor.x, context.native.projections
    context:BeforeCamera(0.1)
    assert(
        Holder(label).anchor.x == x and context.native.projections == projections,
        "early update moved an active label"
    )
    point.x, point.targetState = 200, "dead"
    context:AfterCamera()
    assert(Holder(label).anchor.x < 300, "native handler used the previous camera position")
end)

Test("native mode primes its own cursor, ignores duplicate chat and releases invisible plate tracking", function()
    local context = Scene("enemy", false)
    assert(not context.backing, "native anchors kept forced nameplate tracking")
    assert(context.native.reads == 0, "initialization read historical events")
    context:Prime()
    context:Hit(999)
    context:NativeHit(123)
    context:Tick(0.31)
    local labels = context:Labels()
    assert(#labels == 1 and labels[1]:GetText() == "123", "chat duplicated the native hit")
end)

Test("dead enemy anchors follow camera projection without changing any animation or lifetime", function()
    for _, style in ipairs({ "enemy", "diablo" }) do
        for _, performance in ipairs({ false, true }) do
            local moving, stationary = Scene(style, performance), Scene(style, performance)
            moving:Prime()
            stationary:Prime()
            local _, point = moving:NativeHit(123)
            stationary:NativeHit(123)
            moving:Tick(0.31)
            stationary:Tick(0.31)
            local label, control = assert(moving:Labels()[1]), assert(stationary:Labels()[1])
            -- A one-shot target has no plate in this fixture and can be gone.
            point.targetState = "dead"
            for _, offset in ipairs({ 300, -100, 150 }) do
                point.x, point.y = 200 + offset, 300 - offset
                moving:Tick(0.1)
                stationary:Tick(0.1)
                assert(moving:Labels()[1] == label, "camera movement restarted or replaced the hit")
                Close(Holder(label).anchor.x - Holder(control).anchor.x, offset)
                Close(Holder(label).anchor.y - Holder(control).anchor.y, -offset)
                Close(label:GetParent().scale, control:GetParent().scale)
                Close(Holder(label):GetAlpha(), Holder(control):GetAlpha())
            end
            moving:Tick(2)
            stationary:Tick(2)
            assert(#moving:Labels() == 0 and #stationary:Labels() == 0, "camera motion extended expiry")
        end
    end
end)

Test("offscreen living and dead hits hide, recover for remaining life and never replay after expiry", function()
    for _, targetState in ipairs({ "alive", "dead" }) do
        local context = Scene("diablo", true)
        context:Prime()
        local _, point = context:NativeHit(120)
        context:Tick(0.31)
        local label = assert(context:Labels()[1])
        point.state, point.targetState, point.x, point.y = "behindCamera", targetState, nil, nil
        context:Tick(0.2)
        assert(#context:Labels() == 0 and not Holder(label):IsShown(), "last screen position stayed visible")
        point.state, point.x, point.y = "onScreen", 600, 400
        context:Tick(0.2)
        assert(context:Labels()[1] == label, "returning camera replaced the original hit")
        point.state, point.x, point.y = "offscreen", nil, nil
        context:Tick(1)
        local reads = context.native.projections
        point.state, point.x, point.y = "onScreen", 600, 400
        context:Tick(0.1)
        assert(#context:Labels() == 0 and context.native.projections == reads, "expired hit replayed or projected")
    end
end)

Test("native distance sizing defaults off while death anchors continue tracking the camera", function()
    for _, style in ipairs({ "enemy", "diablo" }) do
        for _, performance in ipairs({ false, true }) do
            local context, control = Scene(style, performance), Scene(style, performance)
            context:Prime()
            control:Prime()
            local _, point = context:NativeHit(123)
            local _, reference = control:NativeHit(123)
            point.cameraDepth = 100000
            context:Tick(0.31)
            control:Tick(0.31)
            local label, original = assert(context:Labels()[1]), assert(control:Labels()[1])
            Close(label:GetParent().scale, original:GetParent().scale)
            point.x, reference.x, point.targetState, reference.targetState = 650, 650, "dead", "dead"
            context:Tick(0.1)
            control:Tick(0.1)
            Close(label:GetParent().scale, original:GetParent().scale)
            Close(Holder(label).anchor.x, Holder(original).anchor.x)
            assert(Holder(label).anchor.x > 600, "default-off sizing disabled death-location tracking")
        end
    end
end)

Test("native depth makes distant text smaller, with stable readable bounds in both performance modes", function()
    for _, performance in ipairs({ false, true }) do
        local context = Scene("enemy", performance, function(setup) setup.settings.sctDistanceScaling = true end)
        context:Prime()
        local _, point = context:NativeHit(123)
        context:Tick(0.31)
        local label = assert(context:Labels()[1])
        local visual = label:GetParent()
        Close(visual.scale, 1)
        point.cameraDepth = 30
        context:Tick(0.1)
        Close(visual.scale, 20 / 30)
        point.cameraDepth = 100000
        context:Tick(0.1)
        Close(visual.scale, 0.55)
        point.cameraDepth = 1
        context:Tick(0.1)
        Close(visual.scale, 1)
        context.writes.SetScale = nil
        context:Tick(0.1)
        assert(not context.writes.SetScale, "unchanged distance rewrote scale")
    end
end)

Test("distance scaling choice preserves live death anchors, animations and expiry in both performance modes", function()
    for _, style in ipairs({ "enemy", "diablo" }) do
        for _, performance in ipairs({ false, true }) do
            local context = Scene(style, performance, function(setup) setup.settings.sctDistanceScaling = true end)
            local control = Scene(style, performance, function(setup) setup.settings.sctDistanceScaling = true end)
            context:Prime()
            control:Prime()
            local _, point = context:NativeHit(123)
            local _, reference = control:NativeHit(123)
            point.cameraDepth, reference.cameraDepth = 40, 40
            context:Tick(0.31)
            control:Tick(0.31)
            local label, original = assert(context:Labels()[1]), assert(control:Labels()[1])
            local objects, registrations = #context.objects, context.native.registers
            context:SetSetting("sctDistanceScaling", false)
            context:Tick(0.2)
            control:Tick(0.2)
            assert(context:Labels()[1] == label, "distance preview restarted the hit")
            Close(original:GetParent().scale / label:GetParent().scale, 0.55)
            point.x, reference.x, point.targetState, reference.targetState = 650, 650, "dead", "dead"
            context:Tick(0.1)
            control:Tick(0.1)
            Close(Holder(label).anchor.x, Holder(original).anchor.x)
            Close(Holder(label).anchor.y, Holder(original).anchor.y)
            context:SetSetting("sctDistanceScaling", true)
            context:Tick(0.1)
            control:Tick(0.1)
            Close(label:GetParent().scale, original:GetParent().scale)
            Close(Holder(label):GetAlpha(), Holder(original):GetAlpha())
            assert(
                #context.objects == objects and context.native.registers == registrations,
                "distance choice allocated or rebound SCT"
            )
            context:Tick(2)
            control:Tick(2)
            assert(#context:Labels() == 0 and #control:Labels() == 0, "distance choice extended hit lifetime")
        end
    end
end)

Test("native hits keep target and source IDs, individual normal labels and Performance Mode sums", function()
    for _, performance in ipairs({ false, true }) do
        local context = Scene("enemy", performance)
        context:Prime()
        local first = context:NativeHit(20)
        local second = context:NativeHit(100)
        context:Tick(0.31)
        local labels = context:Labels()
        assert(#labels == (performance and 1 or 2), "native grouping changed admission")
        if performance then assert(labels[1]:GetText() == "120", "native totals were not grouped") end
        assert(first.amount == 20 and second.amount == 100, "display grouping mutated native events")
        local separate = Scene("enemy", performance)
        separate:Prime()
        separate:NativeHit(100)
        separate:NativeHit(100, { targetId = "target-two" })
        separate:NativeHit(100, { sourceId = "another-owned-caster", sourceKind = "totem" })
        separate:Tick(0.31)
        assert(#separate:Labels() == 3, "same-name targets or distinct casters exchanged anchors")
    end
end)

Test("normal native bursts keep every equal hit over its own enemy anchor", function()
    for _, style in ipairs({ "enemy", "diablo" }) do
        local context = Scene(style)
        context:Prime()
        for index = 1, 24 do
            local _, point = context:NativeHit(100, { targetId = "target:" .. math.ceil(index / 2) })
            point.x, point.y = 100 + index * 20, 200 + index * 5
        end
        context:Tick(0.1)
        local labels, anchors = context:Labels(), {}
        assert(#labels == 24, "normal native burst suppressed equal hits on the same or different enemies")
        for _, label in ipairs(labels) do
            assert(label:GetText() == "100", "normal native burst summed an amount")
            local holder = Holder(label)
            anchors[holder.anchor.x .. ":" .. holder.anchor.y] = true
        end
        local count = 0
        for _ in pairs(anchors) do
            count = count + 1
        end
        assert(count == 24, "normal native hits shared an arbitrary enemy anchor")
        context:Tick(2)
        assert(#context:Labels() == 0, "normal native burst retained expired hits")
    end
end)

Test("credited native meter sources separate borrowed-spell sums without caption or spell guesses", function()
    for _, performance in ipairs({ false, true }) do
        local context = Scene("enemy", performance)
        context:Prime()
        context:NativeHit(20, { meterSource = "Same caption", meterSourceKey = "source:cast" })
        context:NativeHit(30, { meterSource = "Same caption", meterSourceKey = "source:proc" })
        context:NativeHit(40, { meterSource = "Translated caption", meterSourceKey = "source:proc" })
        context:Tick(0.31)
        local labels, amounts = context:Labels(), {}
        assert(#labels == (performance and 2 or 3), "borrowed spell exchanged credited meter sources")
        for _, label in ipairs(labels) do
            amounts[label:GetText()] = true
        end
        if performance then assert(amounts["20"] and amounts["70"], "same native source stopped summing") end
    end
    local context = Scene("enemy", true)
    context:Prime()
    context:NativeHit(20, { meterSource = "Caption alone" })
    context:NativeHit(30, { meterSource = "Another caption", meterSourceKey = "" })
    context:Tick(0.31)
    assert(#context:Labels() == 1 and context:Labels()[1]:GetText() == "50", "optional metadata dropped legacy hits")
end)

Test("native presentation timestamps retain inclusive grouping deadlines across batched receipt", function()
    for _, performance in ipairs({ false, true }) do
        local window = performance and 0.3 or 0.075
        for _, extra in ipairs({ 0, 0.001 }) do
            local context = Scene("enemy", performance)
            context:Prime()
            context:NativeHit(100)
            context:NativeHit(100, { presentedAt = context.now + window + extra })
            context:Tick(0.31)
            context:Tick(0.31)
            local labels = context:Labels()
            assert(
                #labels == (performance and extra == 0 and 1 or 2),
                "receipt batching grouped normal hits or changed the Performance Mode deadline"
            )
            if performance and extra == 0 then assert(labels[1]:GetText() == "200", "equal hits did not sum") end
        end
    end
end)

Test("spell IDs group unnamed attacks and preserve distinct spells without proposed ability keys", function()
    for _, performance in ipairs({ false, true }) do
        local context = Scene("enemy", performance)
        context:Prime()
        local first = context:NativeHit(100)
        local second = context:NativeHit(100)
        first.abilityName, first.icon, second.abilityName, second.icon = nil, nil, nil, nil
        local third = context:NativeHit(100, { spellId = 134 })
        third.abilityName, third.icon = nil, nil
        context:Tick(0.31)
        local labels = context:Labels()
        assert(
            #labels == (performance and 2 or 3),
            "native spell IDs grouped normal hits or changed Performance Mode separation"
        )
        if performance then assert(labels[1]:GetText() == "200", "native spell identity did not sum") end
        local unknown = Scene("enemy", performance)
        unknown:Prime()
        local left, right = unknown:NativeHit(100), unknown:NativeHit(100)
        left.spellId, right.spellId = nil, nil
        unknown:Tick(0.31)
        assert(#unknown:Labels() == 2, "same-name sources without native spell identity were guessed together")
    end
end)

Test("documented melee and ranged categories keep autoattack filtering without a basicAttack field", function()
    for _, kind in ipairs({ "melee", "ranged" }) do
        local context = Scene("enemy", true)
        context:Prime()
        local first, second =
            context:NativeHit(100, { damageType = kind }), context:NativeHit(100, { damageType = kind })
        first.spellId, first.abilityName, first.icon = nil, nil, nil
        second.spellId, second.abilityName, second.icon = nil, nil, nil
        context:Tick(0.31)
        assert(
            #context:Labels() == 1 and context:Labels()[1]:GetText() == "200",
            "plain native attacks lost stable identity"
        )
        context:SetSetting("sctAutoAttacks", false)
        assert(#context:Labels() == 0, "native attack category bypassed the existing autoattack filter")
    end
end)

Test(
    "native area spell IDs respect critical/direct choices without confusing area pulses and targeted damage",
    function()
        for _, style in ipairs({ "enemy", "diablo" }) do
            for _, performance in ipairs({ false, true }) do
                local context = Scene(style, performance, function(current)
                    current.settings.sctAreaDamage = false
                    current.settings.sctNormalHits, current.settings.sctCriticalHits = false, true
                    current.settings.sctAutoAttacks, current.settings.sctPeriodicDamage = false, false
                    current.settings.sctReflectedDamage = false
                end)
                context:Prime()
                local area = context:NativeHit(111, { spellId = 26573, abilityName = "Consecration", critical = true })
                context:NativeHit(222, { spellId = 8187, sourceKind = "totem", sourceId = "magma", critical = true })
                context:NativeHit(333, { critical = true })
                context:NativeHit(444)
                context:Tick(0.4)
                local labels = context:Labels()
                assert(
                    #labels == 1 and labels[1]:GetText() == "333",
                    "native area damage bypassed the independent off choice"
                )
                local direct, registrations = labels[1], context.native.registers
                context:SetSetting("sctAreaDamage", true)
                context:NativeHit(555, { spellId = 26573, critical = true })
                context:NativeHit(666, { spellId = 26573, critical = true, periodic = true })
                context:Tick(0.4)
                assert(#context:Labels() == 2, "area on bypassed the separate periodic filter")
                context:SetSetting("sctAreaDamage", false)
                assert(
                    #context:Labels() == 1 and context:Labels()[1] == direct,
                    "area preview retired a direct critical"
                )
                assert(
                    area.amount == 111 and area.critical == true and area.periodic == false,
                    "classification rewrote native fields"
                )
                assert(context.native.registers == registrations, "area filtering rebound the native frame handler")
                context:Event(context.controller, "PLAYER_LEAVING_WORLD")
                assert(#context:Labels() == 0, "native area filtering retained labels after world cleanup")
            end
        end
    end
)

Test("native misses, pet attribution and damage-category filters retain the existing controls", function()
    local context = Scene("enemy", false, function(_, env)
        env.DFRL.locale.CombatText = function() error("native miss captions are already localized") end
    end)
    context:Prime()
    context:NativeHit(111, { periodic = true })
    context:NativeHit(222, { sourceKind = "totem", sourceId = "totem-one" })
    local miss = context:NativeHit(0, { kind = "miss", result = { key = "dodge", text = "Dodge" } })
    miss.amount = nil
    context:Tick(0.31)
    assert(#context:Labels() == 3, "native miss or attributed damage disappeared")
    assert(miss.result.text == "Dodge", "native miss metadata was changed")
    context:SetSetting("sctPeriodicDamage", false)
    assert(#context:Labels() == 2, "periodic filter did not retain its native meaning")
    context:SetSetting("sctPetDamage", false)
    assert(
        #context:Labels() == 1 and context:Labels()[1]:GetText() == "Dodge",
        "totem filtering lost the localized native miss"
    )
    context:SetSetting("sctMisses", false)
    assert(#context:Labels() == 0, "native miss bypassed its independent control")
end)

Test("missing native miss captions are skipped without rejecting or re-priming valid damage", function()
    local context = Scene("enemy", false)
    context:Prime()
    context:NativeHit(123)
    context:Tick(0.31)
    local original = assert(context:Labels()[1])
    local miss = context:NativeHit(0, { kind = "miss", result = { key = "dodge" } })
    miss.amount = nil
    context:NativeHit(456)
    context:Tick(0.31)
    assert(
        #context:Labels() == 2 and context:Labels()[1] == original,
        "missing caption retired the valid native session"
    )
    assert(
        context:Labels()[2]:GetText() == "456" and miss.result.text == nil,
        "missing caption was invented or blocked damage"
    )
end)

Test("stale and unanchored native hits do not acquire a shared screen fallback", function()
    local context = Scene("enemy", false)
    context:Prime()
    context:NativeHit(111, { presentedAt = context.now - 1 })
    local missing = context:NativeHit(222)
    missing.anchorStatus, missing.anchorId = "unavailable", nil
    context:Tick(0.31)
    assert(#context:Labels() == 0 and context.native.projections == 0, "unusable hit received a fake position")
    context:NativeHit(333)
    context:Tick(0.31)
    assert(context:Labels()[1]:GetText() == "333", "valid intake did not survive skipped events")
end)

Test("large active sets use bounded batches and reject incoherent camera samples atomically", function()
    local context = Scene("enemy", false)
    context:Prime()
    for index = 1, 257 do
        context:NativeHit(index, { targetId = "target:" .. index })
    end
    context:Tick(0.31)
    context:Tick(0.01)
    assert(#context:Labels() == 257, "bounded intake lost the next batch")
    local calls = 0
    context.native.projectFault = function(projection)
        calls = calls + 1
        projection.cameraSampleId = tostring(calls)
        return projection
    end
    context:Tick(0.01)
    assert(calls == 2 and #context:Labels() == 0, "mixed camera samples left part of a frame visible")
end)

Test("malformed batches retire atomically, throttle retries and never fall back to duplicate chat", function()
    local context = Scene("enemy", false)
    context:Prime()
    context:NativeHit(10)
    context:Tick(0.31)
    assert(context:Labels()[1])
    context.native.readFault = function(batch)
        batch.events = { { eventId = "broken" } }
        batch.cursor = "invalid"
        return batch
    end
    context:Tick(0.01)
    assert(#context:Labels() == 0, "invalid batch left stale world labels")
    local reads = context.native.reads
    context:Hit(999)
    context:Tick(0.1)
    assert(context.native.reads == reads and #context:Labels() == 0, "error retried per frame or used chat")
    context.native.readFault = nil
    context:Tick(0.5)
    context:NativeHit(42)
    context:Tick(0.31)
    assert(context:Labels()[1]:GetText() == "42", "fresh native intake failed to recover")
end)

Test("missing projection, mismatched handles and invalid distance never paint stale coordinates", function()
    for _, fault in ipairs({
        function() error("native failure") end,
        function(projection)
            projection.entries[1].anchorId = "foreign"
            return projection
        end,
        function(projection)
            projection.entries[1].cameraDepth = 0 / 0
            return projection
        end,
        function(projection)
            projection.entries[1].x = math.huge
            return projection
        end,
        function(projection)
            projection.worldId = "another-world"
            return projection
        end,
        function(projection)
            projection.frameCurrent = false
            return projection
        end,
        function(projection)
            projection.frameCurrent = nil
            return projection
        end,
    }) do
        local context = Scene("enemy", false)
        context:Prime()
        context:NativeHit(123)
        context:Tick(0.31)
        assert(context:Labels()[1])
        context.native.projectFault = fault
        context:Tick(0.1)
        assert(#context:Labels() == 0, "invalid projection reused a screen point")
    end
end)

Test("frame registration and release failures retry without duplicate handlers or combat reads", function()
    local context = Scene("enemy", false, function(current) current.native.registerFault = true end)
    assert(context.backing and HandlerCount(context) == 1, "failed registration did not retain legacy presentation")
    context:Tick(0.1)
    assert(context.native.reads == 0 and context.native.registers == 1, "failed handler read data or retried per frame")
    context.native.registerFault = false
    context:Tick(0.5)
    assert(
        not context.backing and HandlerCount(context) == 1 and context.native.registers == 2,
        "native handoff did not recover"
    )
    assert(context.native.unregisters == 1 and context.native.reads == 1, "retry did not release before registering")
    context.native.unregisterFault = true
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    local reads, releases = context.native.reads, context.native.unregisters
    context:Tick(0.1)
    assert(
        context.native.reads == reads and context.native.unregisters == releases,
        "retired handler worked or release retried per frame"
    )
    context.native.unregisterFault = false
    context:Tick(0.5)
    assert(
        HandlerCount(context) == 0 and context.native.unregisters == releases + 1,
        "world cleanup did not release its pending handler"
    )
end)

Test("native frame ownership follows style, mode, world, reload and Performance Mode lifecycles", function()
    local context = Scene("enemy", false, function(current, env)
        env.ReloadUI = function() current.reloaded = true end
    end)
    context:SetSetting("performanceMode", true)
    context:SetSetting("performanceMode", false)
    assert(context.native.registers == 1 and HandlerCount(context) == 1, "Performance Mode registered another handler")
    context:SetSetting("sctStyle", "msbt")
    assert(HandlerCount(context) == 0, "MSBT retained the world handler")
    context:SetSetting("sctStyle", "diablo")
    assert(HandlerCount(context) == 1, "enemy style did not reacquire its world handler")
    context.env.DFRL.sct.BeginEdit()
    context.env.DFRL.sct.SetMode("off")
    assert(HandlerCount(context) == 0, "Off retained the native frame handler")
    context.env.DFRL.sct.FinishEdit(false)
    assert(HandlerCount(context) == 1, "Cancel did not restore the native frame handler")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(HandlerCount(context) == 0, "world leave retained the native frame handler")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    assert(HandlerCount(context) == 1, "world entry did not restore the native frame handler")
    context.env.ReloadUI()
    assert(context.reloaded and HandlerCount(context) == 0, "reload did not release the native frame handler")
end)

Test("native frame cleanup preserves another addon's handler", function()
    local foreignCalls = 0
    local foreign = function() foreignCalls = foreignCalls + 1 end
    local context = Scene("enemy", false, function(current) current.native.handlers[foreign] = true end)
    assert(HandlerCount(context) == 2, "fixture lost an independent handler")
    context.env.DFRL.sct.BeginEdit()
    context.env.DFRL.sct.SetMode("off")
    assert(HandlerCount(context) == 1 and context.native.handlers[foreign], "Off removed a foreign handler")
    context:Tick(0.1)
    assert(foreignCalls == 1 and context.native.reads == 0, "foreign handler stopped or retired SCT still read events")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(context.native.handlers[foreign], "world cleanup removed a foreign handler")
end)

Test("stream retirement, disabled SCT, MSBT and world cleanup bound native work", function()
    local context = Scene("enemy", false)
    context:Prime()
    context:NativeHit(123)
    context:Tick(0.31)
    context.native.streamId, context.native.worldId = "new-stream", "new-world"
    context:Tick(0.1)
    assert(#context:Labels() == 0, "old world hit survived stream retirement")
    context:SetSetting("sctStyle", "msbt")
    local reads, projections = context.native.reads, context.native.projections
    context:Hit(77)
    context:Tick(0.31)
    assert(context:Labels()[1]:GetText() == "77", "MSBT lost its independent chat stream")
    assert(context.native.reads == reads and context.native.projections == projections, "MSBT polled world SCT")
    context:SetSetting("sctStyle", "enemy")
    context:Tick(0.1)
    context.env.DFRL.sct.BeginEdit()
    context.env.DFRL.sct.SetMode("off")
    reads, projections = context.native.reads, context.native.projections
    context:Tick(0.2)
    assert(context.native.reads == reads and context.native.projections == projections, "off SCT polled native data")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    context:Tick(0.2)
    assert(#context:Labels() == 0 and context.native.reads == reads, "world cleanup left native work")
end)

Test("a hidden world suspends native reads while existing labels retain their expiry", function()
    local context = Scene("enemy", false)
    context:Prime()
    local _, point = context:NativeHit(123)
    context:Tick(0.31)
    local label = assert(context:Labels()[1])
    context.env.WorldFrame:Hide()
    local reads, projections = context.native.reads, context.native.projections
    context:Tick(0.4)
    assert(
        context.native.reads == reads and context.native.projections == projections,
        "hidden world polled native SCT"
    )
    point.x = 600
    context.env.WorldFrame:Show()
    context:Tick(0.1)
    assert(context:Labels()[1] == label and Holder(label).anchor.x > 500, "showing the world reused stale projection")
    context.env.WorldFrame:Hide()
    context:Tick(2)
    context.env.WorldFrame:Show()
    context:Tick(0.1)
    assert(#context:Labels() == 0, "hidden-world time froze label expiry")
end)

Test("incomplete capability sets retain the existing legacy nameplate path", function()
    for _, endpoint in ipairs({
        "AZS_ProjectCombatTextAnchors",
        "AZS_RegisterCombatTextFrameHandler",
        "AZS_UnregisterCombatTextFrameHandler",
    }) do
        local context = Scene("enemy", false, function(_, env) env[endpoint] = nil end)
        assert(context.backing and HandlerCount(context) == 0, "partial API disabled legacy tracking")
        context:Hit(321)
        context:Tick(0.31)
        assert(context:Labels()[1]:GetText() == "321" and context.native.reads == 0, "partial API consumed hits")
    end
    local context = Scene("enemy", false, function(_, env)
        local capabilities = env.AZS_GetCombatTextCapabilities
        env.AZS_GetCombatTextCapabilities = function()
            local value = capabilities()
            value.frameHandler = false
            return value
        end
    end)
    assert(context.backing and HandlerCount(context) == 0, "missing frameHandler capability selected native mode")
end)

print("PASS " .. passed .. " native world SCT contracts")
