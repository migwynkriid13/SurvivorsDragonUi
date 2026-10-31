-- CI only: production compact frame and loss controller over explicit native mocks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "compact health fixtures require CI Lua 5.1")
local function CompactContext()
    local context = H.New()
    local function Write(name) context.writes[name] = (context.writes[name] or 0) + 1 end
    local create = context.Object
    function context:Object(kind, name, parent)
        local object = create(self, kind, name, parent)
        object.points = {}
        function object:SetParent(value)
            Write("SetParent")
            self.parent = value
        end
        function object:SetScale(value)
            Write("SetScale")
            self.scale = value
        end
        function object:SetDrawLayer(value)
            Write("SetDrawLayer")
            self.layer = value
        end
        function object:SetPoint(...)
            Write("SetPoint")
            table.insert(self.points, { ... })
        end
        function object:ClearAllPoints()
            Write("ClearAllPoints")
            self.points = {}
        end
        function object:SetAllPoints(value)
            Write("SetAllPoints")
            self.allPoints = value
        end
        function object:SetTexCoord(...)
            Write("SetTexCoord")
            self.uv = { ... }
        end
        function object:SetStatusBarTexture(path)
            Write("SetStatusBarTexture")
            self.fill = self:CreateTexture(nil, "ARTWORK")
            self.fill:SetTexture(path)
        end
        function object:GetStatusBarColor() return unpack(self.color or { 0, 1, 0, 1 }) end
        function object:GetStatusBarTexture() return self.fill end
        function object:SetMovable(value)
            Write("SetMovable")
            self.movable = value
        end
        function object:SetStatusBarColor(r, g, b)
            Write("SetStatusBarColor")
            self.color = { r, g, b, 1 }
        end
        return object
    end
    return context
end
local context = CompactContext()
local env = context.env

context.current, context.maximum, context.name = 1200, 1200, "Zyde"
context.settings.hidePortraits = false
context.settings.showHealthValue, context.settings.showHealthPercentage = true, true
context.settings.healthLossAnimation = true
env.UnitExists = function(unit) return unit == "player" or unit == "targettarget" end
env.UnitIsPlayer = function() return true end
env.UnitIsDead = function() return context.dead end
env.UnitIsGhost = function() return false end
env.UnitIsUnit = function(unit, candidate) return unit == "targettarget" and candidate == "player" end
env.UnitReaction = function() return 5 end
env.UnitName = function()
    context.reads.name = (context.reads.name or 0) + 1
    return context.name
end
env.UnitHealth = function()
    context.reads.health = (context.reads.health or 0) + 1
    return context.current
end
env.UnitHealthMax = function() return context.maximum end
env.DFRL.locale.Preview = function(text, count) return string.sub(text, 1, count), string.len(text) > count end
env.TargetofTarget_Update = function() context.nativeUpdates = (context.nativeUpdates or 0) + 1 end

local root = env.CreateFrame("Frame", "TargetofTargetFrame", env.UIParent)
root:SetWidth(93)
root:SetHeight(45)
root.name = root:CreateFontString(nil, "OVERLAY")
local bar = env.CreateFrame("StatusBar", "TargetofTargetHealthBar", root)
local background = bar:CreateTexture("TargetofTargetBackground", "BACKGROUND")
env.TargetofTargetPortrait = root:CreateTexture(nil, "ARTWORK")
env.TargetofTargetTexture = root:CreateTexture(nil, "OVERLAY")
env.TargetofTargetDeadText = root:CreateFontString(nil, "OVERLAY")
context:Load("core/widgets.lua")
context:Load("modules/unit/mini.lua", "Mini")

local label, percentage, border
for _, object in ipairs(context.objects) do
    if object.kind == "FontString" and object:GetText() == "1.2K" then label = object end
    if object.kind == "FontString" and object:GetText() == "100%" then percentage = object end
end
assert(label and percentage, "production native-health labels were not populated")
border = root.name:GetParent()
assert(border ~= root and border == label:GetParent(), "name was left behind the health/portrait layers")
local strips = {}
for _, object in ipairs(context.objects) do
    if object.kind == "Texture" and object:GetParent() == border and object ~= env.TargetofTargetPortrait then
        table.insert(strips, object)
    end
end
assert(table.getn(strips) == 15, "compact frame did not reuse the clean pooled border crops")
assert(bar.fill:GetTexture() == env.T.LargeHealthFill.texture, "old shaded/transparent fill remained bound")
assert(background.allPoints == bar, "background did not follow the health rectangle")

local function LabelPositions()
    local left, width = bar.points[1][4], bar:GetWidth()
    return left + label.points[1][4], left + width + percentage.points[1][4]
end
local function CaptionBounds()
    local point, anchor, anchorPoint, x, y = unpack(root.name.points[1])
    assert(point == "BOTTOMLEFT" and anchor == bar and anchorPoint == "TOPLEFT", "name escaped the bar's header")
    local bottom = -root:GetHeight() / 2 + bar.points[1][5] + bar:GetHeight() / 2 + y
    assert(bottom < 0 and bottom + root.name:GetHeight() <= 0, "name overflowed above the compact frame")
    assert(bar.points[1][4] + x == 40 and root.name:GetWidth() == 60, "name moved outside its original column")
    assert(
        bar.points[1][4] + bar:GetWidth() / 2 + env.TargetofTargetDeadText.points[1][4] == 70,
        "portrait choice moved the native dead caption"
    )
end
CaptionBounds()
local left, right = LabelPositions()
assert(left == 44 and right == 96, "ring overlap moved the native-health label area")
assert(bar.points[1][4] < 40 and bar.points[1][4] + bar:GetWidth() > 100, "fill left a ring/end seam")

context:SetSetting("hidePortraits", true)
CaptionBounds()
local closedLeft, closedRight = LabelPositions()
assert(closedLeft == left and closedRight == right, "portraitless preview moved the health labels")
assert(bar.points[1][4] > 39 and bar:GetWidth() < 62, "portraitless mode retained the ring extension")
for _, strip in ipairs(strips) do
    assert(not strip:IsShown(), "hidden portrait border remained submitted")
end
local allocated = table.getn(context.objects)
context:SetSetting("hidePortraits", false)
CaptionBounds()
for _, strip in ipairs(strips) do
    assert(strip:IsShown(), "portrait border did not restore from its pool")
end
context:ResetCounts()
env.TargetofTarget_Update()
context:NoPresentationWrites()
assert(table.getn(context.objects) == allocated, "unchanged refresh allocated artwork")

root:Hide()
context:ResetCounts()
context:SetSetting("hidePortraits", true)
env.TargetofTarget_Update()
context:NoPresentationWrites()
assert(not next(context.reads), "hidden compact frame read cosmetic/name/health state")
root:Show()
CaptionBounds()
assert(bar:GetWidth() < 62, "Show did not apply the deferred portrait choice")
context:SetSetting("hidePortraits", false)
assert(table.getn(context.objects) == allocated, "portrait transitions rebuilt the artwork pool")
context:SetSetting("showHealthPercentage", false)
assert(
    label.points[1][1] == "CENTER" and bar.points[1][4] + bar:GetWidth() / 2 + label.points[1][4] == 70,
    "a lone health value moved beneath the portrait"
)
context:SetSetting("showHealthPercentage", true)

context.name = "Long target name"
env.TargetofTarget_Update()
assert(root.name:GetText() == "Long tar...", "native target name lost its existing clipped presentation")
CaptionBounds()
context.dead = true
context:Call(bar, "OnValueChanged")
assert(label:GetText() == "" and percentage:GetText() == "", "dead target-of-target retained health captions")
context.dead = false
context:Call(bar, "OnValueChanged")
assert(label:GetText() == "1.2K" and percentage:GetText() == "100%", "native health did not recover")

context:Load("modules/unit/cut.lua", "Cut-Out")
local loss, animator
for _, object in ipairs(context.objects) do
    if object.kind == "Texture" and object.parent and object.parent.parent == bar then loss = object end
    if object.events.PLAYER_LEAVING_WORLD then animator = object end
end
assert(loss and animator and loss:GetTexture() == bar.fill:GetTexture(), "loss trail restored the old shaded fill")
context.current = 900
context:Call(bar, "OnValueChanged")
assert(loss:IsShown() and loss:GetWidth() == bar:GetWidth() / 4, "real damage lost its original proportional trail")
context:SetSetting("performanceMode", true)
assert(not loss:IsShown() and animator:GetScript("OnUpdate") == nil, "Performance Mode retained trail work")
assert(label:GetText() == "900" and percentage:GetText() == "75%", "Performance Mode changed native health")
context:SetSetting("performanceMode", false)
assert(not loss:IsShown(), "mode exit replayed suppressed damage")
context.current = 600
context:Call(bar, "OnValueChanged")
assert(loss:IsShown(), "the next native damage did not rearm the normal trail")
root:Hide()
assert(not loss:IsShown() and animator:GetScript("OnUpdate") == nil, "hidden compact frame kept an active trail")
print("PASS compact target name containment, seamless fill, pooled borders, hidden recovery and Performance Mode")

local function PartyContext()
    local party = CompactContext()
    local native = party.env
    party.units = {}
    party.settings.hidePortraits = false
    party.settings.classResources = true
    party.settings.showHealthValue, party.settings.showHealthPercentage = true, true
    native.DFRL.layout.IsEditing = function() return false end
    local function State(unit, field)
        party.reads[unit .. ":" .. field] = (party.reads[unit .. ":" .. field] or 0) + 1
        local entry = party.units[unit]
        return entry and entry[field]
    end
    native.UnitExists = function(unit) return State(unit, "exists") end
    native.UnitIsDead = function(unit) return State(unit, "dead") end
    native.UnitIsGhost = function(unit) return State(unit, "ghost") end
    native.UnitIsConnected = function(unit) return State(unit, "connected") end
    native.UnitHealth = function(unit) return State(unit, "current") end
    native.UnitHealthMax = function(unit) return State(unit, "maximum") end
    native.UnitIsUnit = function(unit, candidate) return unit == candidate end
    native.UnitClass = function() return "Warlock", "WARLOCK" end
    native.DFRL.locale.Text = function(text)
        if party.language == "fr" then
            if text == "Dead" then return "Mort" end
            if text == "Ghost" then return "Fantôme" end
        end
        return text
    end
    for index = 1, 4 do
        local prefix, unit = "PartyMemberFrame" .. index, "party" .. index
        local frame = native.CreateFrame("Frame", prefix, native.UIParent)
        frame:SetWidth(100)
        frame:SetHeight(50)
        local health = native.CreateFrame("StatusBar", prefix .. "HealthBar", frame)
        local mana = native.CreateFrame("StatusBar", prefix .. "ManaBar", frame)
        health:SetWidth(70)
        mana:SetWidth(70)
        health.nativeValue, mana.nativeValue = 17 + index, 31 + index
        health.SetValue = function() error("party captions wrote native health") end
        mana.SetValue = function() error("party captions wrote native resources") end
        party.units[unit] = {
            exists = true,
            connected = true,
            dead = 0,
            ghost = 0,
            current = 800 + index,
            maximum = 1600 + index * 2,
            frame = frame,
            health = health,
            mana = mana,
        }
    end
    party:Load("core/widgets.lua")
    party:Load("modules/unit/mini.lua", "Mini")
    for _, entry in pairs(party.units) do
        for _, object in ipairs(party.objects) do
            if object.kind == "FontString" and object.points[1] and object.points[1][2] == entry.health then
                if object.points[1][1] == "LEFT" then entry.label = object end
                if object.points[1][1] == "RIGHT" then entry.percentage = object end
            end
        end
        assert(entry.label and entry.percentage, "native party row did not bind its existing health labels")
        assert(entry.percentage:GetText() == "50%", "numeric-zero flags incorrectly marked a living party member dead")
    end
    party.controller = party:Controller("UNIT_FLAGS")
    assert(party.controller.events.UNIT_CONNECTION, "party connection transitions do not refresh captions")
    return party
end

local party = PartyContext()
local prepared = table.getn(party.objects)
for _, performance in ipairs({ false, true }) do
    party:SetSetting("performanceMode", performance)
    for index = 1, 4 do
        local unit = "party" .. index
        local entry = party.units[unit]
        entry.dead = index == 1 and true or 1
        party:ResetCounts()
        party:Event(party.controller, "UNIT_FLAGS", unit)
        assert(
            entry.label:GetText() == "Dead" and entry.percentage:GetText() == "",
            "death retained stale positive health"
        )
        assert(entry.label.points[1][1] == "CENTER", "party death caption was left in the numeric column")
        assert(
            not party.reads[unit .. ":current"] and not party.reads[unit .. ":maximum"],
            "dead party caption read health values"
        )
        for other = 1, 4 do
            if other ~= index then
                assert(
                    not party.reads["party" .. other .. ":exists"],
                    "a unit flags event refreshed unrelated party rows"
                )
            end
        end
        party:ResetCounts()
        party:Event(party.controller, "UNIT_FLAGS", unit)
        party:NoPresentationWrites()
        entry.ghost = index == 1 and true or 1
        party:Event(party.controller, "UNIT_FLAGS", unit)
        assert(
            entry.label:GetText() == "Ghost" and entry.percentage:GetText() == "",
            "ghost did not take priority over dead"
        )
        entry.dead, entry.ghost = 0, 0
        party:Event(party.controller, "UNIT_FLAGS", unit)
        assert(
            entry.label:GetText() == tostring(entry.current) and entry.percentage:GetText() == "50%",
            "resurrection did not restore native health captions"
        )
        assert(
            entry.health.nativeValue == 17 + index and entry.mana.nativeValue == 31 + index,
            "status presentation changed native bar values"
        )
    end
end

local member = party.units.party1
member.dead = true
party:Event(party.controller, "UNIT_CONNECTION", "party1")
party:SetSetting("showHealthValue", false)
party:SetSetting("showHealthPercentage", false)
assert(
    member.label:GetText() == "Dead" and member.percentage:GetText() == "",
    "numeric choices hid a party death state"
)
party.language = "fr"
party:NotifyLocale()
assert(member.label:GetText() == "Mort", "language change retained the previous party death caption")
member.ghost = true
party:Event(party.controller, "UNIT_CONNECTION", "party1")
assert(member.label:GetText() == "Fantôme", "connection-only refresh did not reflect current ghost state")
member.exists = false
party:Event(party.controller, "UNIT_CONNECTION", "party1")
assert(
    member.label:GetText() == "" and member.percentage:GetText() == "",
    "missing native unit retained its prior death caption"
)
member.exists, member.dead, member.ghost = true, false, false
party:Event(party.controller, "UNIT_CONNECTION", "party1")
assert(member.label:GetText() == "" and member.percentage:GetText() == "", "revival discarded disabled numeric choices")
party:SetSetting("showHealthValue", true)
party:SetSetting("showHealthPercentage", true)
assert(
    member.label:GetText() == "801" and member.percentage:GetText() == "50%",
    "health choices did not recover after resurrection"
)

party:SetLayoutHidden(true)
party:ResetCounts()
member.dead, member.ghost = true, true
party.language = nil
party:Event(party.controller, "UNIT_FLAGS", "party1")
party:NotifyLocale()
party:NoPresentationWrites()
assert(not next(party.reads), "hidden party frames read health or death presentation")
party:SetLayoutHidden(false)
assert(
    member.label:GetText() == "Ghost" and member.percentage:GetText() == "",
    "Show replayed hidden party health or language state"
)
assert(table.getn(party.objects) == prepared, "party death transitions allocated new UI objects")
assert(party.controller:GetScript("OnUpdate") == nil, "party death captions added an idle updater")
print("PASS party Dead/Ghost flags, localized reused labels, numeric choices, resurrection and hidden recovery")
