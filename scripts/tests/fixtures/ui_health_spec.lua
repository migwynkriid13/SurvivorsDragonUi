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
    function context:Publish(hp, hpm, id, name)
        -- Deliver the event before native parsing, then replace the table before OnUpdate.
        self:Event(controller, "CHAT_MSG_ADDON", "AZSTGT")
        env.AZS_TARGET = { kind = "guardian", id = id or 90, name = name or self.targetName, hp = hp, hpm = hpm }
        env.AZS_TARGET_UPDATED = self.now
        self:Call(controller, "OnUpdate", 0.01)
    end
    context:Publish(current, maximum)
    context:ResetCounts()
    return context, controller, bar, label, labels.percentage, loss, animator
end

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
    end
    assert(context.env.T.EncounterHealthText(35e12, 70e12) == "35T / 70T")
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

Test("same name target switches block retired health and reset the loss baseline", function()
    local context, controller, bar, label, _, loss, animator = Target(70e12, 70e12)
    context:Publish(35e12, 70e12)
    context:Event(controller, "PLAYER_TARGET_CHANGED")
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "" and bar:GetValue() == 0, "old same-name health survived selection")
    assert(not loss:IsShown() and animator:GetScript("OnUpdate") == nil, "old target loss survived selection")
    context:Publish(20e12, 70e12, 91)
    assert(label:GetText() == "20T" and not loss:IsShown(), "new spawn inherited old target loss")
end)

Test("invalid and mismatched publications cannot display another target's health", function()
    local context, _, bar, label, percent = Target(70e12, 70e12)
    context:Publish(35e12, 70e12, 91, "Other guardian")
    assert(label:GetText() == "" and percent:GetText() == "" and bar:GetValue() == 0)
    for _, hp in ipairs({ -1, math.huge, 0 / 0, 71e12 }) do
        context:Publish(hp, 70e12)
        assert(label:GetText() == "" and bar:GetValue() == 0, "invalid HP was accepted")
    end
    context:Publish(35e12, 0)
    assert(label:GetText() == "" and bar:GetValue() == 0, "zero maximum was accepted")
end)

Test("hidden targets skip publication reads and painting and resume with a fresh baseline", function()
    local context, controller, bar, label, _, loss = Target(70e12, 70e12)
    context.env.TargetFrame:Hide()
    context:ResetCounts()
    context:Publish(35e12, 70e12)
    context:NoPresentationWrites()
    assert(not context.reads.health and not context.reads.maximum, "hidden target read native health")
    assert(controller:GetScript("OnUpdate") == nil, "hidden target kept a reader")
    context.env.TargetFrame:Show()
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "35T" and bar:GetValue() == 0.5 and not loss:IsShown())
end)

Test("phase zone and world retirement clear target values and active loss", function()
    local context, controller, bar, label, _, loss, animator = Target(70e12, 70e12)
    context:Publish(35e12, 70e12)
    context:Event(controller, "CHAT_MSG_ADDON", "AZSZONE")
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "" and bar:GetValue() == 0 and not loss:IsShown(), "zone reused old health")
    context:Publish(70e12, 70e12)
    context.phase = "dead"
    context:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "" and bar:GetValue() == 0, "dead phase retained enemy health")
    context.phase = "playing"
    context:Publish(70e12, 70e12)
    context:Publish(35e12, 70e12)
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    assert(label:GetText() == "" and not loss:IsShown() and animator:GetScript("OnUpdate") == nil)
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    context:Event(animator, "PLAYER_ENTERING_WORLD")
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "", "world entry accepted a retired publication")
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
