-- CI only: the production Revive controller over explicit native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "Revive fixtures require the CI Lua 5.1 interpreter")

local function Revive()
    local context = H.New()
    local env = context.env
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        local width, point = object.GetWidth, object.SetPoint
        function object:GetWidth()
            if self.name == "SurvivorsDragonUiRevive" then
                context.reads.rootWidth = (context.reads.rootWidth or 0) + 1
            end
            return width(self)
        end
        function object:SetPoint(anchor, relative, relativePoint, x, y)
            point(self, anchor, relative, relativePoint, x, y)
            self.anchor = { point = anchor, relative = relative, relativePoint = relativePoint, x = x, y = y }
        end
        function object:GetEffectiveScale() return context.scale or 1 end
        function object:GetStringWidth()
            context.reads.measure = (context.reads.measure or 0) + 1
            return context.missingMetrics and 0 or string.len(self:GetText()) * 7
        end
        function object:SetBlendMode(value) self.blend = value end
        function object:SetMinMaxValues(low, high)
            self.minimum, self.maximum = low, high
        end
        function object:SetStatusBarTexture(value) self.fill = value end
        function object:SetStatusBarColor(...) self.color = { ... } end
        function object:SetValue(value)
            context.writes.SetValue = (context.writes.SetValue or 0) + 1
            self.value = value
        end
        return object
    end
    env.T.NewHudOwner = function(part)
        assert(part == "revive")
        return {
            Acquire = function() context.nativeOwned = true end,
            Release = function() context.nativeOwned = false end,
        }
    end
    env.T.GetLocalSize = function(frame) return frame:GetWidth(), frame:GetHeight() end
    env.DFRL.layout.IsHidden = function(key)
        assert(key == "revive")
        return context.hidden == true
    end
    env.DFRL.layout.Width = function(key, fallback)
        assert(key == "revive")
        return context.layoutWidth or fallback
    end
    env.DFRL.layout.Place = function() end
    env.DFRL.locale.code = "en"
    env.DFRL.locale.Text = function(template)
        assert(type(template) == "string", "Revive replaced a caption template with cache metadata")
        if env.DFRL.locale.code == "de" then
            if template == "%s is reviving you!" then return "%s hilft dir!" end
            if template == "Reviving %s!" then return "Hilf %s!" end
        end
        return template
    end
    env.string = {}
    for name, value in pairs(string) do
        env.string[name] = value
    end
    env.string.format = function(...)
        context.formats = (context.formats or 0) + 1
        return string.format(...)
    end
    env.tostring = function(value)
        if type(value) == "number" then context.percentFormats = (context.percentFormats or 0) + 1 end
        return tostring(value)
    end
    env.AZS_GetPhase = function() return context.phase or "playing" end
    env.AZS_GetRevive = function() return env.AZS_REVIVE end
    env.geterrorhandler = function()
        return function(message) context.lastError = message end
    end
    context:Load("modules/ui/revive.lua", "Revive")
    context.root = assert(env.SurvivorsDragonUiRevive)
    context.controller = context:Controller("CHAT_MSG_ADDON")
    context.crosses = {}
    for _, object in ipairs(context.objects) do
        if object.kind == "StatusBar" then context.bar = object end
        if object.kind == "FontString" then
            if object:GetFont() and select(2, object:GetFont()) == 12 then
                context.percent = object
            elseif object:GetHeight() == 22 then
                context.caption = object
            end
        elseif object.kind == "Texture" then
            local texture = object:GetTexture()
            if texture == "Interface\\Buttons\\WHITE8X8" then
                table.insert(context.crosses, object)
            elseif texture and string.find(texture, "Spark.blp", 1, true) then
                context.spark = object
            end
        end
    end
    assert(context.bar and context.caption and context.percent and context.spark and #context.crosses == 12)
    function context:ResetPerf()
        self:ResetCounts()
        self.formats, self.percentFormats = 0, 0
    end
    function context:Tick(elapsed)
        self.now = self.now + elapsed
        self:Call(self.controller, "OnUpdate", elapsed)
    end
    function context:Publish(state)
        self.env.AZS_REVIVE, self.env.AZS_REVIVE_UPDATED = state, self.now
        self:Event(self.controller, "CHAT_MSG_ADDON", "AZSREVIVE")
        self:Tick(0)
    end
    function context:Hidden(hidden)
        self.hidden = hidden
        self:SetLayoutHidden(hidden)
    end
    return context
end

do
    local context = Revive()
    context:Publish({ down = 1, by = "Alice", share = 0.25 })
    assert(context.caption:GetText() == "Alice is reviving you!" and context.percent:GetText() == "25%")
    context:ResetPerf()
    context:Publish({ down = 1, by = "Alice", share = 0.2504 })
    assert(context.formats == 0 and context.percentFormats == 0, "unchanged captions or rounded percent reformatted")
    context.caption.text, context.percent.text = "native reset", "native reset"
    context:ResetPerf()
    context:Publish({ down = 1, by = "Alice", share = 0.2504 })
    assert(context.formats == 0 and context.percentFormats == 0, "native repair rebuilt cached strings")
    assert(context.writes.SetText == 2 and context.percent:GetText() == "25%", "actual label state was not repaired")
    context.env.DFRL.locale.code = "de"
    context:NotifyLocale()
    context:ResetPerf()
    context:Tick(0)
    assert(context.formats == 1 and context.caption:GetText() == "Alice hilft dir!", "language retained an old caption")
    context:Publish({ down = 0, reviving = "Alice", rshare = 0.25 })
    assert(context.caption:GetText() == "Hilf Alice!", "direction reused the other caption")
    context:Hidden(true)
    context:ResetPerf()
    context:Publish({ down = 1, by = "Bob", share = 0.7 })
    context:Publish({ down = 1, by = "Bob", share = 0.8 })
    assert(
        context.formats == 0 and context.percentFormats == 0 and not context.reads.measure,
        "hidden revive formatted"
    )
    context:Hidden(false)
    context:ResetPerf()
    context:Tick(0)
    assert(
        context.caption:GetText() == "Bob hilft dir!" and context.percent:GetText() == "80%",
        "Show replayed old state"
    )
    context:Publish({ down = 1, by = "", share = 0.8 })
    assert(context.caption:GetText() == "" and context.percent:GetText() == "", "waiting retained captions")
    context:ResetPerf()
    context:Publish({ down = 1, by = "Bob", share = 0.8 })
    assert(context.formats == 1 and context.percentFormats == 1, "waiting cleanup retained caption caches")
end
print(
    "PASS Revive caches current subject/direction/language and rounded percentages while retaining repair and hidden recovery"
)

do
    local context = Revive()
    context:Publish({ down = 1, by = "Alice", share = 0.25 })
    assert(context.spark.anchor.x == 79, "standalone paint did not use its current root width")
    assert(context.crosses[3]:GetWidth() == 3 and context.crosses[4]:GetWidth() == 1, "cross clipping changed")
    context:Publish({ down = 1, by = "Alice", share = 0.2504 })
    context:ResetPerf()
    context:Tick(0.01)
    assert(
        context.percentFormats == 0 and context.percent:GetText() == "25%",
        "small smoothing steps reformatted percent"
    )
    assert(context.env.T.NearlyEqual(context.bar.value, 0.25 + 0.0004 * 0.01 / 0.14), "smoothing equation changed")
    context.layoutWidth = 508
    context:Publish({ down = 1, by = "Beatrice", share = 0.5 })
    assert(context.spark.anchor.x == 226 and context.percent:GetText() == "50%", "fresh paint retained the prior width")
    context:Publish({ down = 1, by = "Beatrice", share = 1 })
    context:Tick(0.5)
    assert(
        context.env.T.NearlyEqual(context.bar.value, 0.51) and context.percent:GetText() == "51%",
        "catch-up skipped its one-point step"
    )
end
print("PASS Revive preserves cross clipping, smoothing and percentage steps")

do
    local context = Revive()
    context.missingMetrics = true
    context:Publish({ down = 1, by = "Alice", share = 0.25 })
    context:ResetPerf()
    context.missingMetrics = false
    context:Publish({ down = 1, by = "Alice", share = 0.26 })
    assert(context.formats == 0 and context.reads.measure == 1, "caption cache blocked missing metric recovery")
    local allocated = #context.objects
    context.failText = "Bob is reviving you!"
    context:Publish({ down = 1, by = "Bob", share = 0.4 })
    assert(
        context.lastError and not context.controller:GetScript("OnUpdate"),
        "native setter failure did not retain cleanup"
    )
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:Tick(0)
    assert(
        context.caption:GetText() == "Bob is reviving you!" and context.percent:GetText() == "40%",
        "caption write did not retry"
    )
    context.failText = "41%"
    context:Publish({ down = 1, by = "Bob", share = 0.41 })
    context:Tick(0.14)
    assert(not context.controller:GetScript("OnUpdate"), "percent setter failure did not retire its animation")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:Tick(0)
    assert(
        context.percent:GetText() == "41%" and #context.objects == allocated,
        "percent retry rebuilt the view or stayed stale"
    )
end
print("PASS Revive caption caches retain missing-metric retries and existing native failure/cleanup recovery")

do
    local context = Revive()
    context.failText = "Alice is reviving you!"
    context:Publish({ down = 1, by = "Alice", share = 0.25 })
    assert(
        not context.controller:GetScript("OnUpdate"),
        "initial caption failure did not retain existing error cleanup"
    )
    context:ResetPerf()
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:Tick(0)
    assert(
        context.formats == 1 and context.caption:GetText() == "Alice is reviving you!",
        "inactive failure cleanup retained its formatted caption metadata"
    )
end
print("PASS Revive clears caption metadata after a failed initial write before the view becomes active")
