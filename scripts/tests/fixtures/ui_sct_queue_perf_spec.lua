-- CI only: exact production SCT intake/queues over explicit metadata/origin sinks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "SCT queue fixtures require CI Lua 5.1")
local function Queues(scrolling)
    local context = H.New()
    local env = context.env
    env.msbtStyle, env.inWorld = scrolling, true
    env.pending, env.pendingGroups, env.intakeBuckets, env.recentDamage = {}, {}, {}, {}
    -- Origin matching/cache behavior is covered by the production plate fixture.
    env.originIndex = { ClearQueries = function() end }
    env.T.SourceIconFallback = "Interface\\Icons\\INV_Misc_QuestionMark"
    env.CustomEnabled = function() return true end
    env.UsesPlateOrigins = function() return false end
    env.ParseCombatEvent = function(_, info) return info end
    context.icons, context.origins, context.displays = 0, {}, {}
    env.CombatIcon = function(info)
        context.icons = context.icons + 1
        return info.fixtureIcon or "Interface\\Icons\\Spell_Nature_Thorns"
    end
    env.ResolveOrigin = function(info, now, fallback)
        assert(not env.msbtStyle, "MSBT attempted native origin matching")
        table.insert(context.origins, { info = info, now = now, fallback = fallback })
        if context.resolve or fallback then return info.fixtureX or 4, info.fixtureY or 6 end
    end
    env.DisplayDamage = function(info, x, y) table.insert(context.displays, { info = info, x = x, y = y }) end
    -- Production Lua 5.0 queues remember their size after compaction.
    local insert, remove = env.table.insert, env.table.remove
    env.table.insert = function(list, ...)
        insert(list, ...)
        env.table.setn(list, #list)
    end
    env.table.remove = function(list, index)
        local value = remove(list, index)
        env.table.setn(list, #list)
        return value
    end
    local chunk = assert(loadfile(assert(arg[1], "missing extracted SCT queue source")))
    setfenv(chunk, env)
    context.queue = chunk()
    function context:Hit(amount, now, critical, icon)
        local info = {
            kind = "damage",
            damageType = "autoattack",
            sourceName = "Player",
            targetName = "Enemy",
            amount = amount,
            critical = critical,
            fixtureIcon = icon,
        }
        self.queue.Handle("TEST_COMBAT", info, now)
        return info
    end
    return context, env
end

do
    local context, env = Queues(true)
    local first = context:Hit(100, 1)
    local group = assert(env.pendingGroups[1])
    assert(#env.pending == 0 and group.count == 1 and group.remaining == 0, "MSBT retained a per-hit pending record")
    assert(group.info == first and group.lastArrival == 1, "MSBT lost the original hit or its settle coordinate")
    context.queue.Update(group.closesAt)
    assert(group.bucket and #context.displays == 0, "the inclusive intake deadline changed")
    context.queue.Update(1.079)
    assert(not group.bucket and #context.displays == 0, "MSBT displayed before the first member settled")
    context.queue.Update(1.081)
    local displayed = assert(context.displays[1])
    assert(displayed.info == first and displayed.x == 0 and displayed.y == 0, "MSBT changed its first hit or origin")
    assert(#context.displays == 1 and #env.pendingGroups == 0 and not next(env.intakeBuckets))
    assert(#context.origins == 0 and context.icons == 1, "MSBT added matching or omitted icon intake")
end
print("PASS MSBT groups skip per-hit pending records and retain first-hit settle and intake deadlines")

do
    local context, env = Queues(true)
    local first = context:Hit(100, 2)
    local color, icon = first.color, first.iconTexture
    context.queue.Update(2.06)
    context:Hit(100, 2.07)
    context:Hit(100, 2.03)
    local group = assert(env.pendingGroups[1])
    assert(
        #env.pendingGroups == 1 and #env.pending == 0 and group.count == 3,
        "duplicates allocated extra stream records"
    )
    assert(group.closesAt == 2 + 0.075 and group.lastArrival == 2.07, "a member extended intake or shortened settling")
    context.queue.Update(2.081)
    assert(#context.displays == 0, "a late member used the first member's settle deadline")
    context.queue.Update(2.149)
    assert(#context.displays == 0, "a nonmonotonic arrival replaced the latest member's settle coordinate")
    context.queue.Update(2.151)
    assert(#context.displays == 1 and context.displays[1].info == first, "duplicates changed the first display record")
    assert(
        first.amount == 100 and first.color == color and first.iconTexture == icon,
        "duplicates changed amount or styling"
    )
    local samples
    for _, value in pairs(env.recentDamage) do
        assert(not samples, "identical arrivals split their damage-color history")
        samples = value
    end
    assert(samples and #samples == 3 and context.icons == 3, "original arrivals skipped color or icon intake")
    assert(samples[3].time == 2.03, "nonmonotonic original color sample order changed")
end
print("PASS late and nonmonotonic MSBT members retain maximum settle age and every original metadata/color sample")

do
    local context, env = Queues(true)
    local first = context:Hit(100, 3)
    local amount = context:Hit(200, 3)
    local critical = context:Hit(100, 3, true)
    local icon = context:Hit(100, 3, nil, "Interface\\Icons\\Spell_Fire_Fire")
    assert(#env.pending == 0 and #env.pendingGroups == 4, "distinct amount, critical or icon identities merged")
    context.queue.Update(3.081)
    assert(#context.displays == 4 and context.icons == 4, "distinct stream groups were dropped")
    for index, info in ipairs({ first, amount, critical, icon }) do
        assert(context.displays[index].info == info, "stream groups changed arrival order or first records")
    end
end
print("PASS MSBT retains separate amount, critical and resolved-icon identities without summing")

do
    local context, env = Queues(true)
    local first = context:Hit(100, 4)
    local earlier = context:Hit(100, 3.99)
    assert(#env.pendingGroups == 2, "an arrival before the first receipt joined its intake")
    context.queue.Update(4.081)
    assert(#context.displays == 2 and context.displays[1].info == first and context.displays[2].info == earlier)
    assert(not next(env.intakeBuckets), "an older group retained or replaced the newer intake owner")
    local future = context:Hit(100, 5)
    context.queue.Update(4.9)
    assert(#context.displays == 2 and #env.pendingGroups == 1, "a future receipt bypassed settling")
    context.queue.Update(5.081)
    assert(#context.displays == 3 and context.displays[3].info == future, "a future receipt never settled")
end
print("PASS MSBT preserves earlier-than-first rejection, intake ownership and future receipt handling")

do
    local context = Queues(true)
    context:Hit(100, 0.1)
    -- Addition rounds this deadline differently from the original age test.
    assert(0.18 - 0.1 < 0.08, "fixture requires the CI interpreter's double precision")
    context.queue.Update(0.18)
    assert(#context.displays == 0, "an added deadline changed the original floating-point settle boundary")
    context.queue.Update(0.18000000000000002)
    assert(#context.displays == 1, "the next representable settled sample was not displayed")
end
print("PASS MSBT retains the original raw subtraction at a floating-point settle boundary")

do
    local context, env = Queues(false)
    local first = context:Hit(100, 6)
    local second = context:Hit(100, 6.01)
    local group = assert(env.pendingGroups[1])
    assert(#env.pending == 2 and group.remaining == 2 and group.count == 0 and not group.lastArrival)
    assert(env.pending[1].info == first and env.pending[2].info == second, "default SCT dropped an original record")
    context.queue.Update(6.079)
    assert(#context.origins == 0 and #context.displays == 0, "default matching ran before the existing settle age")
    context.queue.Update(6.1)
    assert(
        #context.origins == 2 and #env.pending == 2 and #context.displays == 0,
        "default unmatched hits were retired"
    )
    assert(not context.origins[1].fallback and not context.origins[2].fallback, "default fallback started early")
    context.queue.Update(6.18)
    assert(
        #context.origins == 4 and #env.pending == 0 and #context.displays == 1,
        "default fallback lost per-hit matching"
    )
    assert(
        context.origins[3].info == first and context.origins[4].info == second,
        "default native message order changed"
    )
    assert(context.origins[3].fallback and context.origins[4].fallback, "default fallback deadline changed")
    local displayed = context.displays[1]
    assert(displayed.info == first and displayed.x == 4 and displayed.y == 6, "default resolved centroid changed")
    assert(group.count == 2 and group.remaining == 0 and not next(env.intakeBuckets))
end
print("PASS default SCT retains original per-hit pending records, ordered matching, fallback age and centroid")
