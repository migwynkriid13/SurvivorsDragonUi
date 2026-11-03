-- CI only: production absorb intake, labels and overlay over explicit native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "player absorb fixtures require the CI Lua 5.1 interpreter")

local file = assert(io.open("modules/unit/player.lua", "r"))
local playerSource = file:read("*a")
file:close()
local first = assert(string.find(playerSource, "    DFRL.playerResources = DFRL.playerResources or {}", 1, true))
local last = assert(string.find(playerSource, "    DFRL.playerResources.SetPrimary = function", first, true))
local hooks = {}
for _, hook in ipairs({
    '        HookScript(PlayerFrameHealthBar, "OnSizeChanged", PlaceAbsorb)',
    '        HookScript(PlayerFrameHealthBar, "OnHide", ClearAbsorb)',
}) do
    assert(string.find(playerSource, hook, last, true), "missing production absorb lifecycle hook")
    table.insert(hooks, hook)
end
local absorbSource = string.sub(playerSource, first, last - 1)
    .. "\n"
    .. table.concat(hooks, "\n")
    .. "\nreturn function() return absorbOverlay, absorbTexture, absorbEdge end\n"

local function Blue(value) return " |cffA6D9FF+" .. value .. "|r" end
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Player(performance)
    local context = H.New()
    local env = context.env
    context.phase, context.current, context.maximum, context.exists = "playing", 1000, 1000, true
    context.settings.performanceMode = performance == true
    context.settings.classResources = false
    context.settings.showHealthValue, context.settings.showHealthPercentage = true, true
    context.settings.unitShortHealth = true
    env.initialized = true
    env.DFRL.navigation = {
        IsRunPhase = function(phase) return phase == "playing" or phase == "paused" end,
    }
    env.AZS_GetPhase = function()
        context.reads.phase = (context.reads.phase or 0) + 1
        return context.phase
    end
    env.UnitExists = function(unit)
        context.reads.exists = (context.reads.exists or 0) + 1
        return unit == "player" and context.exists
    end
    env.UnitHealth = function() return context.current end
    env.UnitHealthMax = function() return context.maximum end
    env.UnitIsDead = function() return context.current == 0 end
    env.UnitIsGhost = function() return false end
    env.UnitPowerType = function() error("Class resources is off") end
    env.UnitMana = env.UnitPowerType
    env.UnitManaMax = env.UnitPowerType

    local function Write(name) context.writes[name] = (context.writes[name] or 0) + 1 end
    local create = context.Object
    function context:Object(kind, name, parent)
        local object = create(self, kind, name, parent)
        function object:SetStatusBarTexture(path)
            Write("SetStatusBarTexture")
            self.statusTexture = path
        end
        function object:SetMinMaxValues(low, high)
            Write("SetMinMaxValues")
            self.minimum, self.maximum = low, high
        end
        function object:GetMinMaxValues() return self.minimum, self.maximum end
        function object:SetValue(value)
            Write("SetValue")
            self.value = value
        end
        function object:GetValue() return self.value end
        function object:SetStatusBarColor(...)
            Write("SetStatusBarColor")
            self.color = { ... }
        end
        function object:SetVertexColor(...)
            Write("SetVertexColor")
            self.vertexColor = { ... }
        end
        return object
    end

    local frame = env.CreateFrame("Frame", "PlayerFrame", env.UIParent)
    local bar = env.CreateFrame("StatusBar", "PlayerFrameHealthBar", frame)
    bar:SetWidth(200)
    bar:SetHeight(20)
    local label = bar:CreateFontString(nil, "OVERLAY")
    label:SetFont("DEFAULT_TEST", 10, "OUTLINE")
    context:Load("core/widgets.lua")
    local nativeString = env.string
    env.string = {}
    for key, value in pairs(nativeString) do
        env.string[key] = value
    end
    env.string.format = function(...)
        context.reads.formats = (context.reads.formats or 0) + 1
        return string.format(...)
    end
    env.tostring = function(value)
        if type(value) == "number" then context.reads.formats = (context.reads.formats or 0) + 1 end
        return tostring(value)
    end
    local labels = env.T.BindUnitHealthText(bar, label, "player")
    env.healthLabels = labels
    local chunk = assert(loadstring(absorbSource, "production player absorbs"))
    setfenv(chunk, env)
    local overlay = chunk()
    -- Native primary-power drawing is outside the extracted absorb owner.
    env.DFRL.playerResources.SetPrimary = function(value, maximum, power)
        assert(value == nil and maximum == nil and power == nil, "disabled Class resources read primary power")
    end
    context:Load("modules/unit/resources.lua", "Class resources")
    local controller = context:Controller("CHAT_MSG_ADDON")
    function context:Snapshot(value, health, maximum)
        local values = { sh = value, hp = health, hpm = maximum }
        return setmetatable({}, {
            __index = function(_, key)
                self.reads.fields = (self.reads.fields or 0) + 1
                return values[key]
            end,
        })
    end
    function context:Tick() self:Call(controller, "OnUpdate", 0.1) end
    function context:Publish(value, health, maximum)
        self:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
        self.now = self.now + 0.1
        env.AZS_RUN = self:Snapshot(value, health or 1000, maximum or 1000)
        env.AZS_RUN_UPDATED = self.now
        self:Call(controller, "OnUpdate", 0.01)
    end
    context:ResetCounts()
    return context, controller, bar, label, labels, overlay
end

Test("silver shields retain a dark bounded edge over mage and default health colours", function()
    local context, _, bar, _, _, overlay = Player()
    local env = context.env
    env.UnitClass = function(unit)
        assert(unit == "player")
        return "Mage", "MAGE"
    end
    function bar:GetStatusBarColor() return unpack(self.color or { 0, 1, 0, 1 }) end
    local updateColor = env.T.BindClassHealthColor(bar, "player")
    updateColor()
    context:SetSetting("classHealth", true)
    context:Publish(250)
    local frame, texture, edge = overlay()
    local mage = env.T.GetClassColor("MAGE")
    assert(bar.color[1] == mage[1] and bar.color[2] == mage[2] and bar.color[3] == mage[3])
    assert(texture.vertexColor[1] == 1 and texture.vertexColor[2] == 1 and texture.vertexColor[3] == 1)
    assert(texture.vertexColor[4] == 0.9 and edge.vertexColor[4] == 1)
    assert(edge.vertexColor[1] < 0.15 and edge.vertexColor[2] < 0.15 and edge.vertexColor[3] < 0.15)
    assert(edge:GetParent() == frame and edge:IsVisible() and edge:GetWidth() == 1 and texture:GetWidth() == 50)
    local allocated = #context.objects
    context:SetSetting("classHealth", false)
    assert(bar.color[1] == 0 and bar.color[2] == 1 and bar.color[3] == 0)
    assert(edge:IsVisible() and texture.vertexColor[1] == 1 and #context.objects == allocated)
    context:Publish(1, 1000, 10000)
    assert(edge:GetWidth() == texture:GetWidth() and edge:GetWidth() < 1, "divider extended beyond a tiny shield")
    bar:SetWidth(400)
    context:Call(bar, "OnSizeChanged")
    assert(math.abs(texture:GetWidth() - 0.04) < 0.000001 and edge:GetWidth() == texture:GetWidth())
    context:Publish(0)
    assert(not frame:IsShown() and not edge:IsVisible())
    context:Publish(250)
    assert(edge:IsVisible() and edge:GetWidth() == 1 and #context.objects == allocated)
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
end)

Test("current shield and its uncapped max-health percentage distinguish saturated bars", function()
    local context, _, bar, label, labels, overlay = Player()
    context:Publish(7000)
    assert(label:GetText() == "1K" .. Blue("7K"), "current shield amount was not shown beside health")
    assert(labels.percentage:GetText() == "100%" .. Blue("700%"), "shield percentage was clamped to 100")
    local frame, texture = overlay()
    assert(frame:IsShown() and texture:GetWidth() == bar:GetWidth(), "large shield lost its full-bar overlay")
    local allocated = #context.objects
    context:Publish(1200)
    assert(label:GetText() == "1K" .. Blue("1.2K"))
    assert(labels.percentage:GetText() == "100%" .. Blue("120%"), "depleted saturated shield looked unchanged")
    assert(texture:GetWidth() == bar:GetWidth() and #context.objects == allocated)
    context.maximum = 2000
    labels.Update()
    assert(labels.percentage:GetText() == "50%" .. Blue("120%"), "shield used native health instead of published hpm")
end)

Test("existing health choices independently preview shield values and percentages", function()
    local context, _, _, label, labels = Player()
    context:Publish(7000)
    local allocated = #context.objects
    context:SetSetting("unitShortHealth", false)
    assert(label:GetText() == "1000" .. Blue("7000"), "full-number choice did not reach shield text")
    context:SetSetting("showHealthValue", false)
    assert(label:GetText() == "" and labels.percentage:GetText() == "100%" .. Blue("700%"))
    context:SetSetting("showHealthPercentage", false)
    assert(label:GetText() == "" and labels.percentage:GetText() == "")
    context:SetSetting("showHealthValue", true)
    assert(label:GetText() == "1000" .. Blue("7000") and labels.percentage:GetText() == "")
    context:SetSetting("unitShortHealth", true)
    context:SetSetting("showHealthPercentage", true)
    assert(label:GetText() == "1K" .. Blue("7K") and labels.percentage:GetText() == "100%" .. Blue("700%"))
    assert(#context.objects == allocated, "health previews allocated more shield regions")
end)

Test("Performance Mode retains static shield numbers and hides only the optional overlay", function()
    local context, _, _, label, labels, overlay = Player(true)
    context:Publish(7000)
    assert(label:GetText() == "1K" .. Blue("7K") and labels.percentage:GetText() == "100%" .. Blue("700%"))
    assert(overlay() == nil, "Performance Mode prepared unused overlay artwork")
    context:SetSetting("performanceMode", false)
    local frame, _, edge = overlay()
    assert(frame and frame:IsShown() and edge:IsVisible(), "normal presentation did not prepare its overlay")
    local allocated = #context.objects
    context:SetSetting("performanceMode", true)
    assert(
        not frame:IsShown() and not edge:IsVisible() and label:GetText() == "1K" .. Blue("7K"),
        "mode entry removed shield information"
    )
    context:Publish(1200)
    assert(labels.percentage:GetText() == "100%" .. Blue("120%") and not frame:IsShown())
    context:SetSetting("performanceMode", false)
    assert(frame:IsShown() and #context.objects == allocated, "mode exit recreated overlay artwork")
    context:SetSetting("performanceMode", true)
    context:SetSetting("showHealthValue", false)
    context:SetSetting("showHealthPercentage", false)
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.fields and not context.reads.exists, "disabled resources still read unused native values")
    assert(context.reads.phase == 1, "disabled resources stopped observing phase retirement")
    context:NoPresentationWrites()

    context.phase = "ready"
    context:SetSetting("performanceMode", false)
    context:ResetCounts()
    context:Tick()
    assert(context.reads.phase == 1 and not context.reads.exists, "an unavailable shield still read player existence")
    context.phase = "playing"
    context:Publish(1600)
    assert(context.reads.exists == 1 and frame:IsShown(), "normal mode did not check the player for usable shield data")
end)

Test("zero invalid and dead native shield data clear both numbers and artwork", function()
    local context, _, _, label, labels, overlay = Player()
    local invalid = {
        { 0, 1000, 1000 },
        { -1, 1000, 1000 },
        { math.huge, 1000, 1000 },
        { 0 / 0, 1000, 1000 },
        { 7000, 0, 1000 },
        { 7000, -1, 1000 },
        { 7000, math.huge, 1000 },
        { 7000, 0 / 0, 1000 },
        { 7000, 1000, 0 },
        { 7000, 1000, -1 },
        { 7000, 1000, math.huge },
        { 7000, 1000, 0 / 0 },
    }
    for _, values in ipairs(invalid) do
        context:Publish(7000)
        context:Publish(unpack(values))
        local frame = overlay()
        assert(
            label:GetText() == "1K" and labels.percentage:GetText() == "100%",
            "invalid shield retained numeric text"
        )
        assert(not frame:IsShown(), "invalid shield retained its overlay")
    end
    context:Publish(7000)
    context:Publish(nil)
    assert(label:GetText() == "1K" and labels.percentage:GetText() == "100%", "missing shield retained numeric text")
    context:Publish(7000)
    context.current = 0
    context:Publish(7000, 0)
    assert(not string.find(label:GetText(), "|c", 1, true), "dead player retained shield value")
    assert(not string.find(labels.percentage:GetText(), "|c", 1, true), "dead player retained shield percentage")
    context.current = 1000
    context:Publish(7000)
    context.exists = false
    context:Tick()
    assert(label:GetText() == "" and labels.percentage:GetText() == "", "missing player retained shield text")
end)

Test("the shared helper rejects invalid direct absorb inputs", function()
    local context, _, _, label, labels = Player()
    context:Publish(7000)
    for _, values in ipairs({
        { 0, 1000 },
        { -1, 1000 },
        { math.huge, 1000 },
        { 0 / 0, 1000 },
        { "missing", 1000 },
        { 5, 0 },
        { 5, math.huge },
        { 5, "missing" },
    }) do
        labels.SetAbsorb(unpack(values))
        assert(label:GetText() == "1K" and labels.percentage:GetText() == "100%")
        labels.SetAbsorb(7000, 1000)
    end
    labels.SetAbsorb()
    assert(label:GetText() == "1K" and labels.percentage:GetText() == "100%")
end)

Test("non-player labels never acquire player shield text", function()
    local context, _, bar = Player()
    local env = context.env
    env.UnitExists = function(unit) return unit == "player" or unit == "target" end
    local targetValue = bar:CreateFontString(nil, "OVERLAY")
    targetValue:SetFont("DEFAULT_TEST", 10, "OUTLINE")
    local targetLabels = env.T.BindUnitHealthText(bar, targetValue, "target")
    targetLabels.SetAbsorb(7000, 1000)
    assert(targetValue:GetText() == "1K" and targetLabels.percentage:GetText() == "100%")
end)

Test("packets defer native fields until parsing completes and unchanged samples stay idle", function()
    local context, controller, _, label, labels = Player()
    context:Publish(7000)
    local allocated = #context.objects
    context:ResetCounts()
    context:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
    assert(not context.reads.fields, "run receipt read native fields before parsing")
    context:NoPresentationWrites()
    context.env.AZS_RUN = context:Snapshot(1200, 1000, 1000)
    context:Call(controller, "OnUpdate", 0.01)
    assert(label:GetText() == "1K" .. Blue("1.2K") and labels.percentage:GetText() == "100%" .. Blue("120%"))
    context:ResetCounts()
    for _ = 1, 30 do
        context:Tick()
    end
    context:NoPresentationWrites()
    assert(not context.reads.formats, "unchanged native shield repeatedly formatted numbers")
    assert(#context.objects == allocated, "unchanged samples allocated shield artwork")
end)

Test("hidden players clear shield ownership and skip native field reads and presentation", function()
    local context, _, _, label, labels, overlay = Player()
    context:Publish(7000)
    local frame = overlay()
    context.env.PlayerFrame:Hide()
    assert(not frame:IsShown(), "hidden player retained shown absorb overlay")
    context:ResetCounts()
    context:Publish(1200)
    context:SetSetting("unitShortHealth", false)
    context:Tick()
    assert(not context.reads.fields and not context.reads.formats, "hidden player read or formatted shield data")
    context:NoPresentationWrites()
    context.env.PlayerFrame:Show()
    assert(label:GetText() == "1000" .. Blue("1200") and labels.percentage:GetText() == "100%" .. Blue("120%"))
    assert(frame:IsShown(), "shown player did not recover its current shield")
end)

Test("phase zone and world retirement reject the previous shield publication", function()
    local context, controller, _, label, labels, overlay = Player()
    local env = context.env
    local function Cleared()
        assert(label:GetText() == "1K" and labels.percentage:GetText() == "100%", "retirement retained numeric shield")
        local frame = overlay()
        assert(not frame:IsShown(), "retirement retained shield artwork")
    end
    context:Publish(7000)
    context.phase = "ready"
    context:Tick()
    Cleared()
    context.phase = "playing"
    context:Tick()
    Cleared()
    context:Publish(1200)
    assert(label:GetText() == "1K" .. Blue("1.2K"))
    context:Event(controller, "CHAT_MSG_ADDON", "AZSZONE")
    Cleared()
    context:Tick()
    Cleared()
    context:Publish(7000)
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    Cleared()
    assert(not controller:GetScript("OnUpdate"), "world retirement retained the resource updater")
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    context:Tick()
    Cleared()
    context:Publish(1200)
    assert(label:GetText() == "1K" .. Blue("1.2K"))
    context:Event(controller, "PLAYER_LOGOUT")
    Cleared()
    assert(not controller:GetScript("OnUpdate"), "logout retained the resource updater")
    assert(env.AZS_RUN.sh == 1200, "presentation changed native shield data")
end)

Test("failed overlay bindings retry without blocking shield numbers or allocating duplicates", function()
    local context, _, _, label, labels, overlay = Player()
    context.failTexture = context.env.T.LargeHealthFill.texture
    context:Publish(7000)
    local frame = overlay()
    assert(not frame:IsShown() and label:GetText() == "1K" .. Blue("7K"))
    assert(labels.percentage:GetText() == "100%" .. Blue("700%"), "texture failure suppressed shield percentage")
    local allocated = #context.objects
    context:Tick()
    assert(#context.objects == allocated and not frame:IsShown(), "failed binding allocated another overlay")
    context.failTexture = nil
    context:Tick()
    assert(frame:IsShown() and #context.objects == allocated, "successful retry failed to reuse its overlay")
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(not context.reads.formats, "settled retry reformatted shield labels")
end)

Test("failed numeric writes remain retryable on the existing resource reader", function()
    local context, _, _, label, labels = Player()
    context:Publish(7000)
    context.failText = "1K" .. Blue("1.2K")
    local ok = pcall(function() context:Publish(1200) end)
    assert(not ok, "native text failure was not injected")
    context:Tick()
    assert(label:GetText() == "1K" .. Blue("1.2K") and labels.percentage:GetText() == "100%" .. Blue("120%"))
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
end)

Test("divider binding retries preserve shield fill and numbers without hidden work", function()
    local context, _, _, label, _, overlay = Player()
    context.failTexture = "Interface\\Buttons\\WHITE8X8"
    context:Publish(250)
    local frame, texture, edge = overlay()
    assert(frame:IsShown() and texture:GetWidth() == 50 and not edge:IsShown())
    assert(label:GetText() == "1K" .. Blue("250"), "divider failure hid shield information")
    local allocated = #context.objects
    context:Tick()
    assert(frame:IsShown() and not edge:IsShown() and #context.objects == allocated)
    context:SetSetting("performanceMode", true)
    context:ResetCounts()
    context:Tick()
    assert(not frame:IsShown() and not edge:IsVisible())
    context:NoPresentationWrites()
    context.failTexture = nil
    context:SetSetting("performanceMode", false)
    assert(frame:IsShown() and edge:IsVisible() and #context.objects == allocated)
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
end)

Test("primary captions reuse numeric conversion while native presentation checks stay live", function()
    local begin = assert(string.find(playerSource, "    local primaryCaption = {}", first, true))
    local finish = assert(string.find(playerSource, "    local function CreateValueText", begin, true))
    local primarySource = string.sub(playerSource, begin, finish - 1)
    for _, performance in ipairs({ false, true }) do
        local c = H.New()
        local env = c.env
        c.settings.performanceMode = performance
        local bar = env.CreateFrame("StatusBar", nil, env.UIParent)
        local label = bar:CreateFontString(nil, "OVERLAY")
        local function Read(key) c.reads[key] = (c.reads[key] or 0) + 1 end
        local function Write(key) c.writes[key] = (c.writes[key] or 0) + 1 end
        function bar:GetStatusBarColor()
            Read("color")
            return unpack(self.color or { 1, 1, 1, 1 })
        end
        function bar:SetStatusBarColor(red, green, blue)
            Write("color")
            self.color = { red, green, blue, 1 }
        end
        function bar:GetMinMaxValues()
            Read("range")
            return self.minimum, self.maximum
        end
        function bar:SetMinMaxValues(low, high)
            Write("range")
            self.minimum, self.maximum = low, high
        end
        function bar:GetValue()
            Read("value")
            return self.value
        end
        function bar:SetValue(value)
            Write("value")
            self.value = value
        end
        function label:GetText()
            Read("text")
            return self.text or ""
        end
        function label:SetText(value)
            Write("SetText")
            self.argumentType, self.text = type(value), tostring(value)
        end
        env.tostring = function(value)
            if type(value) == "number" then Read("conversion") end
            return tostring(value)
        end
        env.primaryBar, env.primaryText = bar, label
        env.setPowerShown = function(shown) c.powerShown = shown end
        env.ManaBarColor = { [0] = { r = 0, g = 0, b = 1 }, [1] = { r = 1, g = 0.5, b = 0 } }
        env.DFRL.playerResources = {}
        local chunk = assert(loadstring(primarySource, "production primary power presentation"))
        setfenv(chunk, env)
        chunk()
        local update = env.DFRL.playerResources.SetPrimary
        update(25, 100, 0)
        assert(c.reads.conversion == 1 and label:GetText() == "25" and label.argumentType == "number")
        c:ResetCounts()
        for _ = 1, 10 do
            update(25, 100, 0)
        end
        c:NoPresentationWrites()
        assert(not c.reads.conversion and not next(c.writes), "unchanged primary power repeated conversion or writes")
        assert(c.reads.color == 10 and c.reads.range == 10 and c.reads.value == 10 and c.reads.text == 10)
        bar.color, bar.minimum, bar.maximum, bar.value = { 1, 0, 0, 0.5 }, -1, 50, 1
        label.text, bar.shown = "", false
        update(25, 100, 0)
        assert(bar.color[3] == 1 and bar.color[4] == 1 and bar.minimum == 0 and bar.maximum == 100)
        assert(bar.value == 25 and bar:IsShown() and c.powerShown and label:GetText() == "25")
        assert(label.argumentType == "number" and not c.reads.conversion, "repair changed native numeric input")
        update(30, 200, 1)
        assert(label:GetText() == "30" and bar.maximum == 200 and bar.color[2] == 0.5)
        update(nil, nil, nil)
        assert(not bar:IsShown() and not c.powerShown and label:GetText() == "", "invalid power retained presentation")
        c:ResetCounts()
        update(30, 200, 1)
        assert(c.reads.conversion == 1 and label:GetText() == "30", "invalid-to-valid recovery retained an old cache")
        local binding = { original = label.SetText }
        env.DFRL.locale.labels[label] = binding
        label.text = ""
        c:ResetCounts()
        update(30, 200, 1)
        assert(binding.source == 30 and label:GetText() == "30" and label.argumentType == "string")
        assert(not c.reads.conversion, "bound label repeated numeric conversion")
    end
end)

print("PASS " .. passed .. " player absorb/primary scenarios")
