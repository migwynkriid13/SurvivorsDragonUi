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
                maxEventsPerRead = 256,
                maxAnchorsPerRead = 256,
                eventCapacity = 4096,
                anchorCapacity = 4096,
                eventRetentionSeconds = 5,
                anchorRetentionSeconds = 5,
            }
        end
        env.AZS_GetCombatTextEvents = function(cursor, limit)
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
            basicAttack = false,
            damageType = "spell",
            schoolMask = 4,
            abilityKey = "ability-one",
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
    function context:Prime() self:Tick(0.01) end
    return context
end
local function Holder(label) return label:GetParent():GetParent() end
local function Close(left, right) assert(math.abs(left - right) < 0.000001, "trajectory changed") end

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

Test("native depth makes distant text smaller, with stable readable bounds in both performance modes", function()
    for _, performance in ipairs({ false, true }) do
        local context = Scene("enemy", performance)
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

Test("native grouping keeps target and source IDs, original amounts and exact normal/performance windows", function()
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
            assert(#labels == (extra == 0 and 1 or 2), "receipt batching changed the fixed native deadline")
            if performance and extra == 0 then assert(labels[1]:GetText() == "200", "equal hits did not sum") end
        end
    end
end)

Test("native misses, pet attribution and damage-category filters retain the existing controls", function()
    local localizationReads = 0
    local context = Scene("enemy", false, function(_, env)
        env.DFRL.locale.CombatText = function(text)
            assert(text == "Dodge", "native miss caption changed before localization")
            localizationReads = localizationReads + 1
            return "Translated dodge"
        end
    end)
    context:Prime()
    context:NativeHit(111, { periodic = true })
    context:NativeHit(222, { sourceKind = "totem", sourceId = "totem-one" })
    local miss = context:NativeHit(0, { kind = "miss", result = { key = "dodge", text = "Dodge" } })
    miss.amount = nil
    context:Tick(0.31)
    assert(#context:Labels() == 3, "native miss or attributed damage disappeared")
    assert(localizationReads == 1 and miss.result.text == "Dodge", "miss localization mutated native metadata")
    context:SetSetting("sctPeriodicDamage", false)
    assert(#context:Labels() == 2, "periodic filter did not retain its native meaning")
    context:SetSetting("sctPetDamage", false)
    assert(
        #context:Labels() == 1 and context:Labels()[1]:GetText() == "Translated dodge",
        "totem filtering lost the localized native miss"
    )
    context:SetSetting("sctMisses", false)
    assert(#context:Labels() == 0, "native miss bypassed its independent control")
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
    local context = Scene("enemy", false, function(_, env) env.AZS_ProjectCombatTextAnchors = nil end)
    assert(context.backing, "partial API disabled legacy tracking")
    context:Hit(321)
    context:Tick(0.31)
    assert(context:Labels()[1]:GetText() == "321" and context.native.reads == 0, "partial API consumed hits")
end)

print("PASS " .. passed .. " native world SCT contracts")
