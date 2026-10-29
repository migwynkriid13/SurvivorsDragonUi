-- CI only: actual health owner, shared labels and loss animation over native mocks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "health fixtures require the CI Lua 5.1 interpreter")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Target(current, maximum)
    local context = H.New()
    local env = context.env
    context.phase, context.targetName, context.targetExists = "playing", "Gurubashi Champion", true
    context.nativeHealth, context.nativeMaximum = 4294967295, 4294967295
    context.settings.showHealthValue, context.settings.showHealthPercentage = true, true
    context.settings.healthLossAnimation = true
    env.UnitExists = function(unit) return unit == "player" or (unit == "target" and context.targetExists) end
    env.UnitName = function() return context.targetName end
    env.UnitIsPlayer = function() return context.playerTarget end
    env.UnitPlayerControlled = function() return context.controlledTarget end
    env.UnitCanAttack = function() return not context.playerTarget and not context.friendlyTarget end
    env.UnitIsDead = function(unit) return unit == "target" and context.dead end
    env.UnitIsGhost = function() return false end
    env.UnitHealth = function()
        context.reads.health = (context.reads.health or 0) + 1
        return context.nativeHealth
    end
    env.UnitHealthMax = function()
        context.reads.maximum = (context.reads.maximum or 0) + 1
        return context.nativeMaximum
    end
    env.AZS_GetPhase = function() return context.phase end
    env.AZS_UnitKind = function() error("border matching must not consult the stale-name target helper") end
    local target = env.CreateFrame("Frame", "TargetFrame", env.UIParent)
    local bar = env.CreateFrame("StatusBar", "TargetFrameHealthBar", target)
    bar.minimum, bar.maximum, bar.value = 0, 4294967295, 4294967295
    function bar:GetMinMaxValues() return self.minimum, self.maximum end
    function bar:GetValue() return self.value end
    function bar:SetMinMaxValues(low, high)
        context.writes.SetMinMaxValues = (context.writes.SetMinMaxValues or 0) + 1
        self.minimum, self.maximum = low, high
        self.value = math.max(low, math.min(high, self.value))
        context:Call(self, "OnValueChanged", self.value)
    end
    function bar:SetValue(value)
        context.writes.SetValue = (context.writes.SetValue or 0) + 1
        self.value = math.max(self.minimum, math.min(self.maximum, value))
        context:Call(self, "OnValueChanged", self.value)
    end
    context:Load("core/widgets.lua")
    context:Load("modules/unit/health.lua", "TargetHealth")
    local controller = context:Controller("CHAT_MSG_ADDON")
    local label = bar:CreateFontString(nil, "OVERLAY")
    label:SetFont("DEFAULT_TEST", 10, "OUTLINE")
    local labels = env.T.BindUnitHealthText(bar, label, "target", true)
    env.DFRL.targetHealth.Listen(labels.Update)
    context:Load("modules/unit/cut.lua", "Cut-Out")
    local loss
    for _, object in ipairs(context.objects) do
        if object.kind == "Texture" and object.parent and object.parent.parent == bar then loss = object end
    end
    assert(loss, "missing production loss texture")
    local animator = context:Controller("UNIT_TARGET")
    function context:Publish(hp, hpm, id, name, kind)
        -- Deliver the event before native parsing, then replace the table before OnUpdate.
        self:Event(controller, "CHAT_MSG_ADDON", "AZSTGT")
        env.AZS_TARGET =
            { kind = kind or "guardian", id = id or 90, name = name or self.targetName, hp = hp, hpm = hpm }
        env.AZS_TARGET_UPDATED = self.now
        self:Call(controller, "OnUpdate", 0.01)
    end
    function context:PublishUnits(rows, defer)
        self:Event(controller, "CHAT_MSG_ADDON", "AZSUNITS")
        env.AZS_UNITS, env.AZS_UNITS_UPDATED = rows, self.now
        if not defer then self:Call(controller, "OnUpdate", 0.01) end
    end
    context:Publish(current, maximum)
    context:ResetCounts()
    return context, controller, bar, label, labels.percentage, loss, animator, labels
end

local function Encounter(kind, id, name, maximum, current, state)
    return { kind = kind, id = id, name = name, hp = current or maximum, hpm = maximum, state = state or 0 }
end

local function Border(context)
    local env = context.env
    env.tex = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\unitframes\\"
    env.UnitClassification = function()
        context.reads.classification = (context.reads.classification or 0) + 1
        return "elite"
    end
    env.UpdateBorderTexture = function(path)
        context.borderPath = path
        context.borderBindings = (context.borderBindings or 0) + 1
    end
    -- Keep the production cache and choice logic, with only native drawing replaced.
    local file = assert(io.open("modules/unit/target.lua", "r"))
    local source = file:read("*a")
    file:close()
    local first = assert(string.find(source, "    local borderTexture", 1, true))
    local last = assert(string.find(source, "    _G.TargetFrame_CheckClassification", first, true))
    local chunk = assert(loadstring(string.sub(source, first, last - 1) .. "\nreturn UpdateClassification"))
    setfenv(chunk, env)
    local update = chunk()
    env.DFRL.targetHealth.Listen(update)
    return update
end

Test("known encounter borders select synchronously before the next target publication", function()
    local context, controller, bar, label, _, loss = Target(70e12, 70e12)
    local env = context.env
    Border(context)
    context:PublishUnits({
        Encounter("guardian", 101, "Sleeping guardian", 1234),
        Encounter("boss", 102, "Known boss", 20000),
        Encounter("final", 103, "Known final", 40000),
    })
    for _, row in ipairs({
        { "Sleeping guardian", 1235, "UI-TargetingFrame-RareElite.blp" },
        { "Known boss", 20000, "UI-TargetingFrame-Boss.blp" },
        { "Known final", 40000, "UI-TargetingFrame-Boss.blp" },
    }) do
        context.targetName, context.nativeHealth, context.nativeMaximum = row[1], row[2] / 2, row[2]
        context.friendlyTarget = row[1] == "Sleeping guardian"
        context:Event(controller, "PLAYER_TARGET_CHANGED")
        assert(context.borderPath == env.tex .. row[3], "known dragon waited for AZSTGT or OnUpdate")
        assert(env.DFRL.targetHealth.GetKind() == nil, "cosmetic roster match became accepted target identity")
        assert(bar:GetValue() == 0.5 and label:GetText() ~= "70T", "roster supplied target health")
        assert(not loss:IsShown(), "cosmetic match changed the health-loss baseline")
    end
    context:Publish(18000, 40000, 103, nil, "normal")
    assert(env.DFRL.targetHealth.GetBorderKind() == "normal", "roster overrode an authoritative target kind")
    assert(context.borderPath == env.tex .. "UI-TargetingFrame-Elite.blp", "accepted normal kept a guessed boss border")
end)

Test("roster matching uses exact shared maxima and rejects namesake ambiguity", function()
    local context, controller = Target(70e12, 70e12)
    local health = context.env.DFRL.targetHealth
    context.nativeHealth, context.nativeMaximum = 500, 1235
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    local name = context.targetName
    for _, maximum in ipairs({ 1234.25, 1234 }) do
        context:PublishUnits({ Encounter("guardian", 101, name, maximum), Encounter("elite", 102, name, 500) })
        assert(health.GetBorderKind() == "guardian", "sleeping/waking native maximum lost its exact alias")
        context.nativeMaximum = 500
        assert(health.GetBorderKind() == nil, "ordinary namesake elite inherited a guardian border")
        context.nativeMaximum = 1235
    end
    context:PublishUnits({ Encounter("guardian", 101, name, 1234.25), Encounter("elite", 102, name, 1235) })
    assert(health.GetBorderKind() == nil, "collided native maximum was assigned a guardian kind")
    context.nativeMaximum = 4294967295
    context:PublishUnits({ Encounter("guardian", 101, name, 70e12), Encounter("boss", 102, name, 80e12) })
    assert(health.GetBorderKind() == nil, "uint32-clamped guardian/boss collision chose an arbitrary dragon")
    context:PublishUnits({ Encounter("guardian", 101, name, 70e12), Encounter("elite", 102, name, 80e12) })
    assert(health.GetBorderKind() == nil, "clamped elite collision did not block a guardian border")
    context.nativeMaximum = 100
    context:PublishUnits({ Encounter("guardian", 101, name, 20000) })
    assert(health.GetBorderKind() == nil, "percentage-only or unknown maximum matched a guardian")
    context.nativeMaximum, context.targetName = 20000, "Unknown creature"
    assert(health.GetBorderKind() == nil, "unknown native name matched a known encounter")
    context.targetName, context.playerTarget = name, true
    assert(health.GetBorderKind() == nil, "player target inherited roster artwork")
    context.playerTarget, context.controlledTarget = false, true
    assert(health.GetBorderKind() == nil, "player-controlled target inherited roster artwork")
end)

Test("cosmetic roster copying is atomic and caches unchanged native publications", function()
    local context, controller = Target(70e12, 70e12)
    local env, health = context.env, context.env.DFRL.targetHealth
    context.nativeHealth, context.nativeMaximum = 500, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    local index, calls = env.T.IndexUnitMaximum, 0
    env.T.IndexUnitMaximum = function(maxima, maximum, value)
        calls = calls + 1
        return index(maxima, maximum, value)
    end
    local rows = { Encounter("guardian", 101, context.targetName, 1000) }
    context:PublishUnits(rows)
    assert(health.GetBorderKind() == "guardian", "valid roster was not copied")
    local indexed, allocated = calls, table.getn(context.objects)
    local _, _, generation = health.Get()
    rows[1].kind = "boss"
    for _ = 1, 4 do
        assert(health.GetBorderKind() == "guardian", "unpublished native row mutation changed copied kind")
    end
    local _, _, afterGeneration = health.Get()
    assert(calls == indexed and indexed > 0, "unchanged lookup rebuilt native-maximum aliases")
    assert(generation == afterGeneration, "cosmetic lookup changed target health generation")
    assert(table.getn(context.objects) == allocated, "roster lookup allocated UI objects")

    local malformed = {
        { Encounter("guardian", 101, context.targetName, 1000), Encounter("boss", 101, "Duplicate id", 2000) },
        { Encounter("guardian", 101, context.targetName, 1000), Encounter("unknown", 102, "Unknown kind", 2000) },
        { Encounter("guardian", 101, context.targetName, 1000), Encounter("elite", 102, "Bad health", 2000, 2001) },
        { Encounter("guardian", 101, context.targetName, 1000), Encounter("elite", 102, "Bad maximum", 0) },
        {
            Encounter("guardian", 101, context.targetName, 1000),
            Encounter("elite", 102, "Nonfinite health", 2000, 0 / 0),
        },
        { Encounter("guardian", 101, context.targetName, 1000), Encounter("elite", 102, "", 2000) },
    }
    local oversized = {}
    for id = 1, 41 do
        oversized[id] = Encounter("guardian", id, context.targetName, 1000)
    end
    table.insert(malformed, oversized)
    for _, invalid in ipairs(malformed) do
        context:PublishUnits(invalid)
        assert(health.GetBorderKind() == nil, "partially valid or oversized roster leaked a cosmetic kind")
    end
end)

Test("unit receipts stay deferred and refresh a retired target without another target packet", function()
    local context, controller = Target(70e12, 70e12)
    local env, health = context.env, context.env.DFRL.targetHealth
    Border(context)
    context.nativeHealth, context.nativeMaximum = 500, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    context:Call(controller, "OnUpdate", 0.01)
    assert(health.GetKind() == nil, "fixture accepted a retired target publication")
    context:PublishUnits({ Encounter("guardian", 101, context.targetName, 1000) }, true)
    assert(health.GetBorderKind() == nil, "unit receipt read pending native parser state")
    context:Call(controller, "OnUpdate", 0.01)
    assert(
        context.borderPath == env.tex .. "UI-TargetingFrame-RareElite.blp",
        "new roster did not refresh retired target border"
    )
    context:PublishUnits({ Encounter("boss", 101, context.targetName, 1000) })
    assert(
        context.borderPath == env.tex .. "UI-TargetingFrame-Boss.blp",
        "unchanged target packet blocked a roster border change"
    )
    assert(
        health.GetKind() == nil and controller:GetScript("OnUpdate") == nil,
        "cosmetic update accepted target identity or kept an idle reader"
    )
end)

Test("copied provisional borders survive pending unit and run packets without rebuilding aliases", function()
    local context, controller = Target(70e12, 70e12)
    local env, health = context.env, context.env.DFRL.targetHealth
    Border(context)
    context.nativeHealth, context.nativeMaximum = 500, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    context:PublishUnits({ Encounter("guardian", 101, context.targetName, 1000) })
    local index, calls = env.T.IndexUnitMaximum, 0
    env.T.IndexUnitMaximum = function(maxima, maximum, value)
        calls = calls + 1
        return index(maxima, maximum, value)
    end
    context:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
    env.AZS_RUN, env.AZS_RUN_UPDATED = { t = 6 }, context.now
    assert(health.GetBorderKind() == "guardian", "pending run packet flashed the fallback border")
    assert(calls == 0, "pending run packet rebuilt a copied roster")
    context:Call(controller, "OnUpdate", 0.01)
    assert(health.GetBorderKind() == "guardian" and calls == 0, "ordinary run update rebuilt or lost the roster")

    context:PublishUnits({ Encounter("boss", 101, context.targetName, 1000) }, true)
    assert(health.GetBorderKind() == "guardian", "pending units replaced the copied guardian before parser settlement")
    assert(
        calls == 0 and context.borderPath == env.tex .. "UI-TargetingFrame-RareElite.blp",
        "pending units rebuilt or flashed the border"
    )
    context:Call(controller, "OnUpdate", 0.01)
    assert(health.GetBorderKind() == "boss" and calls == 1, "settled roster did not replace its cosmetic kind once")
    assert(context.borderPath == env.tex .. "UI-TargetingFrame-Boss.blp", "settled roster did not refresh the dragon")

    context:Event(controller, "CHAT_MSG_ADDON", "AZSZONE")
    assert(health.GetBorderKind() == nil, "zone receipt retained the old copied border before settlement")
    assert(calls == 1, "zone receipt read or re-indexed pending native data")
end)

Test("hidden unit receipts settle without reading roster fields or native target health", function()
    local context, controller = Target(70e12, 70e12)
    local env, health = context.env, context.env.DFRL.targetHealth
    Border(context)
    env.TargetFrame:Hide()
    local row, reads = Encounter("guardian", 101, context.targetName, 1000), 0
    local proxy = setmetatable({}, {
        __index = function(_, key)
            reads = reads + 1
            return row[key]
        end,
    })
    context:ResetCounts()
    context:PublishUnits({ proxy }, true)
    assert(controller:GetScript("OnUpdate"), "hidden receipt had no parser-readiness handoff")
    context:Call(controller, "OnUpdate", 0.01)
    assert(
        reads == 0 and not context.reads.health and not context.reads.maximum,
        "hidden receipt inspected roster or native health"
    )
    assert(health.GetBorderKind() == nil, "hidden target performed cosmetic matching")
    assert(controller:GetScript("OnUpdate") == nil, "hidden receipt left an idle worker")
    env.TargetFrame:Show()
    context.nativeHealth, context.nativeMaximum = 500, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    assert(
        context.borderPath == env.tex .. "UI-TargetingFrame-RareElite.blp",
        "first visible selection waited for a new roster packet"
    )
end)

Test("hiding after a unit receipt preserves the deferred handoff for the next selection", function()
    local context, controller = Target(70e12, 70e12)
    local env, health = context.env, context.env.DFRL.targetHealth
    Border(context)
    context.nativeHealth, context.nativeMaximum = 500, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    context:PublishUnits({ Encounter("guardian", 101, context.targetName, 1000) })
    context:PublishUnits({ Encounter("boss", 101, context.targetName, 1000) }, true)
    env.TargetFrame:Hide()
    assert(controller:GetScript("OnUpdate"), "target hide cancelled a pending unit-parser handoff")
    context:ResetCounts()
    context:Call(controller, "OnUpdate", 0.01)
    assert(not context.reads.health and not context.reads.maximum, "hidden handoff sampled target health")
    assert(controller:GetScript("OnUpdate") == nil, "hidden handoff kept an idle reader")
    env.TargetFrame:Show()
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    assert(health.GetKind() == nil, "show accepted the old target publication")
    assert(
        context.borderPath == env.tex .. "UI-TargetingFrame-Boss.blp",
        "visible selection lost the settled hidden roster"
    )
end)

Test("zone world phase language and run rollback retire cosmetic roster evidence", function()
    local context, controller = Target(70e12, 70e12)
    local env, health = context.env, context.env.DFRL.targetHealth
    context.nativeHealth, context.nativeMaximum = 500, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    local function Fresh()
        context:PublishUnits({ Encounter("guardian", 101, context.targetName, 1000) })
        assert(health.GetBorderKind() == "guardian", "fresh roster did not cross its retirement barrier")
    end
    Fresh()
    context:Event(controller, "CHAT_MSG_ADDON", "AZSZONE")
    context:Call(controller, "OnUpdate", 0.01)
    assert(health.GetBorderKind() == nil, "zone retirement reused old roster")
    Fresh()
    context:NotifyLocale()
    assert(health.GetBorderKind() == nil, "language change reused old localized names")
    Fresh()
    context.phase = "ready"
    context:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
    context:Call(controller, "OnUpdate", 0.01)
    context.phase = "playing"
    assert(health.GetBorderKind() == nil, "active phase resurrected retired roster")
    Fresh()
    env.AZS_RUN, env.AZS_RUN_UPDATED = { t = 50 }, context.now
    context:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
    context:Call(controller, "OnUpdate", 0.01)
    env.AZS_RUN = { t = 1 }
    context:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
    context:Call(controller, "OnUpdate", 0.01)
    assert(health.GetBorderKind() == nil, "run-clock rollback reused prior-run roster")
    Fresh()
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    context:Call(controller, "OnUpdate", 0.01)
    assert(health.GetBorderKind() == nil, "world entry reused a retired encounter roster")
    Fresh()
    context:Event(controller, "PLAYER_LOGOUT")
    assert(health.GetBorderKind() == nil, "logout retained cosmetic roster evidence")
end)

Test("target kind shares accepted publications without native health reads or new objects", function()
    local context = Target(70e12, 70e12)
    local health = context.env.DFRL.targetHealth
    local allocated = table.getn(context.objects)
    assert(health.GetKind() == "guardian", "validated guardian kind was not exposed")
    -- Accepted display metadata is copied, not read again from the mutable native table.
    context.env.AZS_TARGET.kind = "boss"
    assert(health.GetKind() == "guardian", "unpublished native mutation replaced accepted kind")
    for _, kind in ipairs({ "boss", "final", "elite", "normal", "guardian" }) do
        context:Publish(70e12, 70e12, 90, nil, kind)
        context:ResetCounts()
        assert(health.GetKind() == kind, "accepted kind did not follow the publication")
        assert(not context.reads.health and not context.reads.maximum, "kind lookup sampled native health")
        context:NoPresentationWrites()
    end
    assert(table.getn(context.objects) == allocated, "kind lookup allocated UI objects")
    context.targetName = "Another enemy"
    assert(health.GetKind() == nil, "kind lookup crossed a native target-name mismatch")
    context.targetName = "Gurubashi Champion"
    context.targetExists = false
    assert(health.GetKind() == nil, "missing target retained an enemy kind")
    context.targetExists, context.playerTarget = true, true
    assert(health.GetKind() == nil, "player target inherited an enemy kind")
end)

Test("target kind changes only after deferred parsing of a new publication", function()
    local context, controller = Target(70e12, 70e12)
    local health = context.env.DFRL.targetHealth
    context:Event(controller, "CHAT_MSG_ADDON", "AZSTGT")
    context.env.AZS_TARGET = { kind = "boss", id = 90, name = context.targetName, hp = 70e12, hpm = 70e12 }
    context.env.AZS_TARGET_UPDATED = context.now
    assert(health.GetKind() == "guardian", "packet receipt read kind before native parsing settled")
    context:Call(controller, "OnUpdate", 0.01)
    assert(health.GetKind() == "boss", "deferred publication did not update accepted kind")
    assert(controller:GetScript("OnUpdate") == nil, "kind change added an idle reader")
end)

Test("health labels use decimal K M B T tiers without changing the counters", function()
    local context = Target(70e12, 70e12)
    local compact = context.env.T.CompactHealth
    for _, row in ipairs({
        { 0, "0" },
        { 999, "999" },
        { 1000, "1K" },
        { 1299, "1.2K" },
        { 999999, "999.9K" },
        { 1e6, "1M" },
        { 1999999, "1.9M" },
        { 1e9, "1B" },
        { 1e12, "1T" },
        { 70e12, "70T" },
    }) do
        assert(compact(row[1]) == row[2], "wrong compact tier for " .. tostring(row[1]))
        assert(compact(row[1], false) == string.format("%.0f", row[1]), "full health used a suffix or exponent")
    end
    assert(context.env.T.EncounterHealthText(35e12, 70e12) == "35T / 70T")
end)

Test("boss and guardian health choices default on and share display transactions", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    local keys = {
        "bossShowCurrentHealth",
        "bossShowMaximumHealth",
        "guardianShowCurrentHealth",
        "guardianShowMaximumHealth",
        "unitShortHealth",
        "bossShortHealth",
        "guardianShortHealth",
    }
    for _, key in ipairs(keys) do
        assert(display.Get(key) == true, key .. " did not default on")
        assert(display.Copy({ [key] = "false" })[key] == true, key .. " accepted an invalid boolean")
        assert(display.Copy({ [key] = false })[key] == false, key .. " lost explicit false")
        display.BeginEdit()
        display.Set(key, false)
        assert(display.Get(key) == false and not context.env.SurvivorsDragonUiDisplay, "preview saved early")
        for _, other in ipairs(keys) do
            if other ~= key then assert(display.Get(other) == true, "health choices were coupled") end
        end
        display.FinishEdit(false)
        assert(display.Get(key) == true, "Cancel lost the saved choice")
        display.BeginEdit()
        display.Set(key, false)
        display.FinishEdit(true)
        assert(context.env.SurvivorsDragonUiDisplay[key] == false, "Confirm lost the choice")
        display.BeginEdit()
        display.Load({ [key] = true })
        assert(display.Get(key) == true, "profile preview lost the choice")
        display.FinishEdit(false)
        assert(display.Get(key) == false, "profile discard lost the saved choice")
        display.Reset()
        for _, resetKey in ipairs(keys) do
            assert(display.Get(resetKey) == true, "reset did not restore both health values")
        end
    end
end)

Test("boss and guardian percentage choices default off and share display transactions", function()
    local context = H.New()
    context:Load("core/display.lua", "Display")
    local display = context.env.DFRL.display
    local keys = { "bossShowHealthPercentage", "guardianShowHealthPercentage" }
    for _, key in ipairs(keys) do
        assert(display.Get(key) == false, "percentage did not default off")
        assert(display.Copy({ [key] = "true" })[key] == false, "invalid percentage choice did not default off")
        assert(display.Copy({ [key] = true })[key] == true, "explicit percentage choice was lost")
        display.BeginEdit()
        display.Set(key, true)
        assert(display.Get(key) == true and not context.env.SurvivorsDragonUiDisplay, "percentage preview saved early")
        for _, other in ipairs(keys) do
            if other ~= key then assert(display.Get(other) == false, "percentage choices were coupled") end
        end
        display.FinishEdit(false)
        assert(display.Get(key) == false, "percentage Cancel did not restore the saved choice")
        display.BeginEdit()
        display.Set(key, true)
        display.FinishEdit(true)
        assert(context.env.SurvivorsDragonUiDisplay[key] == true, "percentage Confirm did not save")
        display.BeginEdit()
        display.Load({ [key] = false })
        assert(display.Get(key) == false, "profile percentage preview failed")
        display.FinishEdit(false)
        assert(display.Get(key) == true, "profile discard lost the saved percentage choice")
        display.Reset()
        for _, resetKey in ipairs(keys) do
            assert(display.Get(resetKey) == false, "reset did not turn percentages off")
        end
    end
end)

Test("encounter percentages use full values and allow percentage-only labels", function()
    local context = H.New()
    context:Load("core/widgets.lua")
    local tools = context.env.T
    for _, choice in ipairs({
        { true, true, "1.2K / 9.9K (13%)" },
        { true, false, "1.2K (13%)" },
        { false, true, "9.9K (13%)" },
        { false, false, "13%" },
    }) do
        local text = tools.EncounterHealthText(1299, 9999, choice[1], choice[2], nil, true, true)
        assert(text == choice[3], "percentage used rounded health or lost an independent visibility choice")
    end
    assert(
        tools.EncounterHealthText(35e12, 70e12, true, true, nil, false, true) == "35000000000000 / 70000000000000 (50%)",
        "full-number mode changed the percentage"
    )
    for _, row in ipairs({
        { 0, 100, "0%" },
        { 100, 100, "100%" },
        { 120, 100, "100%" },
        { -1, 100, "" },
        { 50, 0, "" },
        { 50, math.huge, "" },
        { math.huge, 100, "" },
        { 0 / 0, 100, "" },
    }) do
        assert(
            tools.EncounterHealthText(row[1], row[2], false, false, nil, true, true) == row[3],
            "invalid percentage boundary"
        )
    end
    local label = context.env.UIParent:CreateFontString(nil, "OVERLAY")
    tools.SetEncounterHealthText(label, 50.1, 100, false, false, true, true)
    assert(label:GetText() == "50%" and label:IsShown(), "percentage-only health label stayed hidden")
    context:ResetCounts()
    tools.SetEncounterHealthText(label, 50.2, 100, false, false, true, true)
    tools.SetEncounterHealthText(label, 50.2, 100, false, false, true, true)
    context:NoPresentationWrites()
    assert(label.encounterPercentCurrent == 50.2, "unchanged rounded percentage retained an old basis")
    tools.SetEncounterHealthText(label, 50.2, 100, false, false, true, false)
    assert(
        not label:IsShown() and label.encounterPercentCurrent == nil,
        "disabled percentage retained optional text/cache"
    )
end)

Test("unit full-number preview preserves health and percentages and defers hidden labels", function()
    local context, _, bar, label, percentage, _, _, labels = Target(166983, 331328)
    local allocated, value, percent = #context.objects, bar:GetValue(), percentage:GetText()
    assert(label:GetText() == "166.9K", "missing unit shortening choice did not retain the default")
    context:SetSetting("unitShortHealth", false)
    assert(label:GetText() == "166983" and percentage:GetText() == percent, "full units changed health percentage")
    assert(bar:GetValue() == value and #context.objects == allocated, "format choice changed native health or regions")
    context:ResetCounts()
    context:SetSetting("unitShortHealth", false)
    assert(not context.writes.SetText, "unchanged format repainted health text")
    bar:Hide()
    context:ResetCounts()
    context:SetSetting("unitShortHealth", true)
    assert(not context.writes.SetText, "hidden unit formatted or painted a choice change")
    bar:Show()
    labels.Update()
    assert(label:GetText() == "166.9K" and bar:GetValue() == value, "shown unit did not resume the current format")
end)

Test("encounter format changes invalidate only presentation caches", function()
    local context = H.New()
    context:Load("core/widgets.lua")
    local tools, cache = context.env.T, {}
    assert(tools.EncounterHealthText(166983, 331328, true, true, cache) == "166.9K / 331.3K")
    assert(
        tools.EncounterHealthText(166983, 331328, true, true, cache, false) == "166983 / 331328",
        "cache retained suffixes"
    )
    assert(
        tools.EncounterHealthText(166983, 331328, true, true, cache, true) == "166.9K / 331.3K",
        "cache retained full numbers"
    )
    local label = context.env.UIParent:CreateFontString(nil, "OVERLAY")
    tools.SetEncounterHealthText(label, 35e12, 70e12, true, true, false)
    assert(label:GetText() == "35000000000000 / 70000000000000", "full encounter values used exponent notation")
    context:ResetCounts()
    tools.SetEncounterHealthText(label, 35e12, 70e12, true, true, false)
    context:NoPresentationWrites()
    tools.SetEncounterHealthText(label, 35e12, 70e12, false, true, false)
    assert(label:GetText() == "70000000000000", "full maximum-only text retained a slash")
    tools.SetEncounterHealthText(label, 35e12, 70e12, false, false, false)
    assert(not label:IsShown(), "full-number mode overrode disabled health labels")
end)

Test("encounter health labels hide the slash and skip disabled or unchanged formatting", function()
    local context = H.New()
    context:Load("core/widgets.lua")
    local tools = context.env.T
    local label = context.env.UIParent:CreateFontString(nil, "OVERLAY")
    local compact, calls = tools.CompactHealth, 0
    tools.CompactHealth = function(value, shorten)
        calls = calls + 1
        return compact(value, shorten)
    end
    local allocated = table.getn(context.objects)
    for _, choice in ipairs({
        { true, true, "35T / 70T", 2 },
        { true, false, "35T", 1 },
        { false, true, "70T", 1 },
        { false, false, "", 0 },
    }) do
        calls = 0
        tools.SetEncounterHealthText(label, 35e12, 70e12, choice[1], choice[2])
        assert(label:GetText() == choice[3], "encounter health separator differs")
        assert(label:IsShown() == (choice[1] or choice[2]), "empty health label still draws")
        assert(calls == choice[4], "disabled health was formatted")
        context:ResetCounts()
        calls = 0
        tools.SetEncounterHealthText(label, 35e12, 70e12, choice[1], choice[2])
        context:NoPresentationWrites()
        assert(calls == 0, "unchanged health was formatted")
    end
    tools.SetEncounterHealthText(label, 35e12, 70e12, false, true)
    context:ResetCounts()
    calls = 0
    tools.SetEncounterHealthText(label, 30e12, 70e12, false, true)
    context:NoPresentationWrites()
    assert(calls == 0, "hidden current health invalidated maximum-only text")
    label:SetText("")
    tools.SetEncounterHealthText(label, 30e12, 70e12, false, true)
    assert(label:GetText() == "70T", "pooled label retirement stranded cached text")
    assert(table.getn(context.objects) == allocated, "health choices allocated drawing regions")
end)

Test("large target labels percentage and fill share the AZS publication", function()
    local context, controller, bar, label, percent = Target(15107393536, 18407319552)
    assert(label:GetText() == "15.1B" and percent:GetText() == "82%", "labels used capped UNIT health")
    assert(context.env.T.NearlyEqual(bar:GetValue(), 15107393536 / 18407319552), "fill used capped health")
    local hp, maximum = context.env.T.GetUnitHealth("target")
    assert(hp == 15107393536 and maximum == 18407319552, "display abbreviation changed actual health")
    assert(not context.reads.health and not context.reads.maximum, "enemy health fell back to UNIT getters")
    assert(controller:GetScript("OnUpdate") == nil, "settled target kept an idle reader")
    context.friendlyTarget = true
    bar:SetValue(4294967295)
    assert(
        context.env.T.NearlyEqual(bar:GetValue(), 15107393536 / 18407319552),
        "unattackable guardian lost AZS health"
    )
end)

Test("native capped writes cannot replace the true fraction or repaint unchanged content", function()
    local context, _, bar = Target(35e12, 70e12)
    local allocated = table.getn(context.objects)
    bar:SetMinMaxValues(0, 4294967295)
    bar:SetValue(4294967295)
    assert(bar:GetValue() == 0.5, "native UNIT update restored a full bar")
    local low, high = bar:GetMinMaxValues()
    assert(low == 0 and high == 1, "native UNIT update restored the capped range")
    context:NoPresentationWrites()
    assert(not context.writes.SetValue and not context.writes.SetMinMaxValues, "unchanged fill was written")
    assert(table.getn(context.objects) == allocated, "native update allocated more regions")
end)

Test("loss animation measures real damage above the 32 bit ceiling", function()
    local context, _, bar, _, _, loss, animator = Target(70e12, 70e12)
    context:Publish(35e12, 70e12)
    assert(bar:GetValue() == 0.5 and loss:IsShown(), "large damage did not reach the loss effect")
    assert(loss:GetWidth() == bar:GetWidth() / 2, "loss width used capped or abbreviated health")
    assert(animator:GetScript("OnUpdate"), "loss fade did not start")
    context.now = context.now + 0.5
    context:Call(animator, "OnUpdate", 0.5)
    assert(not loss:IsShown() and animator:GetScript("OnUpdate") == nil, "finished loss kept animating")
    context:Publish(35e12, 80e12)
    assert(not loss:IsShown(), "a maximum change was treated as damage")
    context:Publish(0, 80e12)
    assert(bar:GetValue() == 0 and loss:IsShown(), "valid zero HP was discarded")
end)

Test("same name target switches show current native health and block retired AZS health", function()
    local context, controller, bar, label, percent, loss, animator = Target(70e12, 70e12)
    context:Publish(35e12, 70e12)
    context.nativeHealth, context.nativeMaximum = 25, 100
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "selection reused a retired namesake kind")
    assert(
        label:GetText() == "25" and percent:GetText() == "25%" and bar:GetValue() == 0.25,
        "selection waited for AZSTGT"
    )
    context:Call(controller, "OnUpdate", 0.01)
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "retired publication restored a namesake kind")
    assert(
        label:GetText() == "25" and bar:GetValue() == 0.25,
        "retired same-name health replaced current native health"
    )
    assert(controller:GetScript("OnUpdate") == nil, "waiting selection added an idle poll")
    assert(not loss:IsShown() and animator:GetScript("OnUpdate") == nil, "old target loss survived selection")
    context:Publish(20e12, 70e12, 91)
    assert(context.env.DFRL.targetHealth.GetKind() == "guardian", "fresh selection did not accept its kind")
    assert(label:GetText() == "20T" and not loss:IsShown(), "new spawn inherited old target loss")
end)

Test("native selection hands off to full precision without a false loss or capped overwrite", function()
    local context, controller, bar, label, percent, loss = Target(70e12, 70e12)
    context.targetName, context.nativeHealth, context.nativeMaximum = "New guardian", 750, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    assert(label:GetText() == "750" and percent:GetText() == "75%" and bar:GetValue() == 0.75)
    context:Publish(35e12, 70e12, 91, "Old guardian")
    assert(
        label:GetText() == "750" and bar:GetValue() == 0.75,
        "late old-target packet blanked the current native unit"
    )
    context:Publish(35e12, 70e12, 92)
    assert(label:GetText() == "35T" and percent:GetText() == "50%" and bar:GetValue() == 0.5)
    assert(not loss:IsShown(), "source handoff was animated as damage")
    context:ResetCounts()
    bar:SetMinMaxValues(0, 1000)
    bar:SetValue(1000)
    assert(bar:GetValue() == 0.5 and not context.reads.health and not context.reads.maximum)
    context:NoPresentationWrites()
end)

Test("provisional native target health rejects invalid values and maxima", function()
    local context, controller, bar, label = Target(70e12, 70e12)
    for _, values in ipairs({ { -1, 100 }, { math.huge, 100 }, { 0 / 0, 100 }, { 101, 100 }, { 20, 0 } }) do
        context.nativeHealth, context.nativeMaximum = values[1], values[2]
        context:Event(controller, "PLAYER_TARGET_CHANGED")
        assert(label:GetText() == "" and bar:GetValue() == 0, "invalid provisional native health was displayed")
    end
    context.nativeHealth, context.nativeMaximum = 40, 100
    bar:SetValue(40)
    local value, maximum = context.env.T.GetUnitHealth("target")
    assert(value == 40 and maximum == 100 and bar:GetValue() == 0.4, "ready native health did not update the selection")
end)

Test("invalid and mismatched publications cannot display another target's health", function()
    local context, _, bar, label, percent = Target(70e12, 70e12)
    context:Publish(35e12, 70e12, 91, "Other guardian")
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "mismatched publication retained enemy kind")
    assert(label:GetText() == "" and percent:GetText() == "" and bar:GetValue() == 0)
    for _, hp in ipairs({ -1, math.huge, 0 / 0, 71e12 }) do
        context:Publish(hp, 70e12)
        assert(context.env.DFRL.targetHealth.GetKind() == nil, "invalid health retained accepted kind")
        assert(label:GetText() == "" and bar:GetValue() == 0, "invalid HP was accepted")
    end
    context:Publish(35e12, 0)
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "invalid maximum retained accepted kind")
    assert(label:GetText() == "" and bar:GetValue() == 0, "zero maximum was accepted")
    context:Publish(35e12, 70e12, 90, nil, "unknown")
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "unknown target kind was accepted")
end)

Test("hidden targets skip publication reads and painting and resume with a fresh baseline", function()
    local context, controller, bar, label, _, loss = Target(70e12, 70e12)
    context.env.TargetFrame:Hide()
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "hidden target retained accepted kind")
    context:ResetCounts()
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    context:Publish(35e12, 70e12)
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "hidden packet accepted enemy kind")
    context:NoPresentationWrites()
    assert(not context.reads.health and not context.reads.maximum, "hidden target read native health")
    assert(controller:GetScript("OnUpdate") == nil, "hidden target kept a reader")
    context.env.TargetFrame:Show()
    context:Call(controller, "OnUpdate", 0.01)
    assert(context.env.DFRL.targetHealth.GetKind() == "guardian", "shown target did not recover current kind")
    assert(label:GetText() == "35T" and bar:GetValue() == 0.5 and not loss:IsShown())
end)

Test("phase zone and world retirement clear target values and active loss", function()
    local context, controller, bar, label, _, loss, animator = Target(70e12, 70e12)
    context:Publish(35e12, 70e12)
    context:Event(controller, "CHAT_MSG_ADDON", "AZSZONE")
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "zone receipt retained old target kind")
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "" and bar:GetValue() == 0 and not loss:IsShown(), "zone reused old health")
    context:Publish(70e12, 70e12)
    context.phase = "dead"
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "inactive phase exposed accepted enemy kind")
    context:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "" and bar:GetValue() == 0, "dead phase retained enemy health")
    context.phase = "playing"
    context:Publish(70e12, 70e12)
    context:Publish(35e12, 70e12)
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "world retirement retained old target kind")
    assert(label:GetText() == "" and not loss:IsShown() and animator:GetScript("OnUpdate") == nil)
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    context:Event(animator, "PLAYER_ENTERING_WORLD")
    context:Call(controller, "OnUpdate", 0.01)
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "world entry accepted a retired enemy kind")
    assert(label:GetText() == "", "world entry accepted a retired publication")
    context:Publish(70e12, 70e12)
    context:Event(controller, "PLAYER_LOGOUT")
    assert(context.env.DFRL.targetHealth.GetKind() == nil, "logout retained accepted enemy kind")
end)

Test("player targets retain native health and visibility controls", function()
    local context, controller, bar, label, percent = Target(70e12, 70e12)
    context.playerTarget, context.nativeHealth, context.nativeMaximum = true, 500, 1000
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    assert(label:GetText() == "500" and percent:GetText() == "50%" and bar:GetValue() == 0.5)
    context:SetSetting("showHealthValue", false)
    assert(label:GetText() == "" and percent:GetText() == "50%")
    context:SetSetting("showHealthPercentage", false)
    assert(label:GetText() == "" and percent:GetText() == "")
    context.playerTarget, context.friendlyTarget, context.phase = false, true, "ready"
    context:SetSetting("showHealthValue", true)
    context:SetSetting("showHealthPercentage", true)
    assert(label:GetText() == "500" and percent:GetText() == "50%", "friendly target lost native health outside a run")
end)

print("PASS " .. passed .. " target health scenarios")
