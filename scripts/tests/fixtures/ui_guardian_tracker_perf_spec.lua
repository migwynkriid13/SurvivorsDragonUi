-- CI only: production guardian tracker and shared health text over native mocks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "guardian tracker fixtures require CI Lua 5.1")

local function Tracker()
    local context = H.New()
    local env = context.env
    context.settings.guardianRows = 0
    context.settings.guardianShowDead = true
    context.settings.guardianShowCurrentHealth, context.settings.guardianShowMaximumHealth = true, true
    context.entry =
        { key = "1:0", index = 1, id = 0, name = "Guardian", state = "empty", status = "returning", remaining = 61.9 }
    context.entries = { context.entry }
    env.DFRL.minimapDefaults = { right = 16 }
    env.DFRL.guardians = {
        GetSnapshot = function(snapshot)
            context.reads.snapshot = (context.reads.snapshot or 0) + 1
            snapshot.status, snapshot.rows = "ready", context.entries
            return snapshot
        end,
    }
    env.DFRL.locale.code = "en"
    env.DFRL.locale.data = {
        en = { ui = {} },
        fr = {
            ui = { ["Respawns in %s"] = "Retour dans %s", ["Lair %d"] = "Repaire %d", Alive = "Vivant", Empty = "Vide" },
        },
    }
    env.DFRL.locale.Text = function(source)
        if source == "Respawns in %s" or source == "Alive" or source == "Empty" then
            context.reads.statusTranslations = (context.reads.statusTranslations or 0) + 1
        end
        return env.DFRL.locale.data[env.DFRL.locale.code].ui[source] or source
    end
    env.string = {}
    for name, value in pairs(string) do
        env.string[name] = value
    end
    env.string.format = function(format, ...)
        if format == "%d:%02d" then context.reads.clockFormats = (context.reads.clockFormats or 0) + 1 end
        if format == "Respawns in %s" or format == "Retour dans %s" then
            context.reads.captionFormats = (context.reads.captionFormats or 0) + 1
        end
        if format == "Lair %d" or format == "Repaire %d" then
            context.reads.nameFormats = (context.reads.nameFormats or 0) + 1
        end
        return string.format(format, ...)
    end
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        function object:SetScale(value)
            context.writes.SetScale = (context.writes.SetScale or 0) + 1
            self.scale = value
        end
        function object:GetEffectiveScale() return self.scale or 1 end
        function object:GetStringWidth() return string.len(self:GetText()) * 7 end
        function object:EnableMouseWheel() end
        if object.kind == "StatusBar" then
            function object:SetMinMaxValues(low, high)
                self.minimum, self.maximum = low, high
            end
            function object:SetStatusBarTexture(texture) self.fill = texture end
            function object:SetStatusBarColor(...) self.color = { ... } end
            function object:SetValue(value)
                context.writes.SetValue = (context.writes.SetValue or 0) + 1
                self.value = value
            end
        end
        return object
    end
    env.DFRL.layout.IsHidden = function() return context.hidden end
    local listen = env.DFRL.layout.ListenVisibility
    env.DFRL.layout.ListenVisibility = function(name, callback)
        context.visibility = callback
        listen(name, callback)
    end
    context:Load("core/widgets.lua")
    context:Load("modules/ui/guardian_tracker.lua", "GuardianTracker")
    context.controller = context:Controller("PLAYER_ENTERING_WORLD")
    function context:Tick()
        self.now = self.now + 0.1
        self:Call(self.controller, "OnUpdate", 0.1)
    end
    function context:SetHidden(hidden)
        self.hidden = hidden
        self:SetLayoutHidden(hidden)
        self.visibility(not hidden)
    end
    function context:Row()
        for _, object in ipairs(self.objects) do
            if object.parent == env.DFRL_GuardianTracker and object.status and object.bar then return object end
        end
        error("missing production guardian row")
    end
    -- Settle the shared measurement label's font after initial column sizing.
    context:Tick()
    context:ResetCounts()
    return context, context:Row()
end

do
    local context, row = Tracker()
    assert(row.status:GetText() == "Respawns in 1:02")
    context.entry.remaining = 61.1
    context:Tick()
    context:NoPresentationWrites()
    assert(context.reads.snapshot == 1 and not context.reads.clockFormats and not context.reads.statusTranslations)
    context.entry.remaining = 61
    context:ResetCounts()
    context:Tick()
    assert(row.status:GetText() == "Respawns in 1:01" and context.reads.captionFormats == 1)
    context.entry.remaining = 60.0001
    context:ResetCounts()
    context:Tick()
    assert(
        not context.reads.clockFormats and not context.reads.captionFormats,
        "the same rounded native second was reformatted"
    )
    context.entry.remaining = 60
    context:Tick()
    assert(row.status:GetText() == "Respawns in 1:00", "exact minute boundary changed")
    context.entry.remaining = 0
    context:Tick()
    assert(row.status:GetText() == "Respawns in 0:00", "a countdown zero invented a status change")
    context.entry.status = "due"
    context:Tick()
    assert(row.status:GetText() == "Alive")
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.statusTranslations, "unchanged static guardian status was translated again")
    context.entry.status = "empty"
    context:Tick()
    assert(row.status:GetText() == "Empty", "static status transition reused an old caption")
end
print("PASS guardian status captions retain native rounded boundaries and skip unchanged formatting")

do
    local context, row = Tracker()
    context.env.DFRL.locale.code = "fr"
    context:NotifyLocale()
    assert(row.status:GetText() == "Retour dans 1:02", "language change retained the previous guardian caption")
    context:Tick()
    context:ResetCounts()
    row.status.text = "native reset"
    context:Tick()
    assert(row.status:GetText() == "Retour dans 1:02" and context.writes.SetText == 1)
    assert(
        not context.reads.captionFormats and not context.reads.statusTranslations,
        "native reset repeated formatting"
    )
    context.entry.remaining, context.failText = 60, "Retour dans 1:00"
    local success = pcall(function() context:Tick() end)
    assert(not success and row.status:GetText() == "Retour dans 1:02", "native setter failure did not reach the row")
    context:ResetCounts()
    context:Tick()
    assert(
        row.status:GetText() == "Retour dans 1:00" and context.writes.SetText == 1,
        "failed native text did not retry"
    )
    assert(not context.reads.captionFormats, "a failed native setter discarded successful formatting")
end
print("PASS guardian caption caches preserve language changes, actual native repairs and failed setter retries")

do
    local context, row = Tracker()
    local allocated = #context.objects
    context:SetHidden(true)
    assert(context.controller:GetScript("OnUpdate") == nil and row.statusText == nil)
    context.entry.remaining = 59.1
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(
        not context.reads.snapshot and not context.reads.captionFormats,
        "hidden guardian captions retained view work"
    )
    context:SetHidden(false)
    assert(context:Row() == row and row.status:GetText() == "Respawns in 1:00" and #context.objects == allocated)
    context:Tick()
    context:ResetCounts()
    context.entry.key, context.entry.index = "2:0", 2
    context:Tick()
    assert(
        row.statusIdentity == "2:0" and context.reads.captionFormats == 1,
        "row reuse retained another lair's caption cache"
    )
    context:SetSetting("guardianShowMaximumHealth", false)
    assert(row.statusText == nil, "option changes retained the old row caption cache")
    context:Tick()
    context.entries = {}
    context:Tick()
    assert(row.statusText == nil and not row:IsShown(), "row retirement retained caption state")
    context.entries, context.entry.remaining = { context.entry }, 20.3
    context:Tick()
    assert(
        context:Row() == row and row.status:GetText() == "Respawns in 0:21",
        "retired row did not reuse current values"
    )
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(row.statusText == nil and context.controller:GetScript("OnUpdate") == nil)
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.snapshot, "world retirement continued guardian view reads")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:Tick()
    assert(row.status:GetText() == "Respawns in 0:21", "world entry did not rebuild current status")
end
print("PASS guardian caption caches retire on hiding, options, row reuse and world cleanup")

do
    local context, row = Tracker()
    context.entry.key, context.entry.id, context.entry.state, context.entry.status = "1:7", 7, "awake", "fighting"
    context.entry.hp, context.entry.maximum, context.entry.healthFraction = 50, 100, 0.5
    context:Tick()
    assert(row.bar.value == 0.5 and row.health:GetText() == "50 / 100" and row.pill:IsShown())
    assert(row.statusText == nil and not row.status:IsShown(), "health rows retained status caption ownership")
    context:Tick()
    context:ResetCounts()
    context:Tick()
    assert(not context.writes.SetValue and row.bar.value == 0.5, "status caching changed unchanged health values")
    context:SetSetting("guardianShowCurrentHealth", false)
    context:Tick()
    assert(row.health:GetText() == "100" and row.bar.value == 0.5, "current-health choice changed the bar")
    context:SetSetting("guardianShowMaximumHealth", false)
    context:Tick()
    assert(not row.health:IsShown() and row.bar.value == 0.5, "both health choices failed to hide only the label")
end
print("PASS guardian status caching preserves the shared health branch, values and independent health controls")

do
    local context, row = Tracker()
    context.entry.name = nil
    context:Tick()
    assert(row.name:GetText() == "Lair 1" and context.reads.nameFormats == 1)
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.nameFormats, "unchanged unnamed lair was reformatted")
    row.name.text = "native reset"
    context:Tick()
    assert(row.name:GetText() == "Lair 1" and not context.reads.nameFormats)
    context.entry.index = 2
    context:Tick()
    assert(row.name:GetText() == "Lair 2" and context.reads.nameFormats == 1)
    context.env.DFRL.locale.code = "fr"
    context:NotifyLocale()
    assert(row.name:GetText() == "Repaire 2", "language change retained the old fallback name")
    context.entry.index, context.failText = 3, "Repaire 3"
    assert(not pcall(function() context:Tick() end), "injected name setter failure was swallowed")
    context:ResetCounts()
    context:Tick()
    assert(row.name:GetText() == "Repaire 3" and not context.reads.nameFormats, "failed fallback text did not retry")
    context.entries = {}
    context:Tick()
    assert(row.lairText == nil, "retired row retained its fallback caption cache")
end
print("PASS guardian fallback names cache by lair and language while actual text repairs and retirement remain intact")
