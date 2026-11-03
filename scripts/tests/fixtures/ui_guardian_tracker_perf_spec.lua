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
        GetSnapshot = function(snapshot, trackerShowDead)
            assert(trackerShowDead == context.settings.guardianShowDead, "tracker lost the current dead-row filter")
            context.reads.snapshot = (context.reads.snapshot or 0) + 1
            snapshot.status, snapshot.rows = "ready", context.entries
            snapshot.revision, snapshot.generation = context.revision, context.generation
            snapshot.counts.fighting = context.fighting
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

for _, performance in ipairs({ false, true }) do
    local context, row = Tracker()
    local env = context.env
    context.settings.performanceMode = performance
    context.revision, context.generation = 1, 1
    context:Tick()
    local nativeTable, listUpdates = env.table, 0
    env.table = {}
    for name, value in pairs(nativeTable) do
        env.table[name] = value
    end
    env.table.setn = function(list, count)
        listUpdates = listUpdates + 1
        return nativeTable.setn(list, count)
    end
    context.entry.remaining = 60
    context:Tick()
    assert(
        listUpdates == 0 and row.status:GetText() == "Respawns in 1:00",
        "roster reuse held countdowns or refiltered"
    )
    context.entries[2] = { key = "2:8", index = 2, id = 8, name = "New guardian", state = "asleep", status = "asleep" }
    context.revision = 2
    context:Tick()
    assert(listUpdates == 1, "a new roster publication did not rebuild the visible list")
    context.generation = 2
    context:Tick()
    assert(listUpdates == 2, "roster generation recovery reused an old filter")
    context:SetHidden(true)
    local hiddenUpdates = listUpdates
    context:Tick()
    assert(listUpdates == hiddenUpdates, "hidden tracker kept rebuilding the roster filter")
    context:SetHidden(false)
    context:Tick()
    assert(listUpdates > hiddenUpdates, "visible recovery failed to rebuild its retired filter")
end
print("PASS guardian filters reuse accepted revisions while countdowns, publications and hidden recovery stay live")

for _, performance in ipairs({ false, true }) do
    local context, first = Tracker()
    local env = context.env
    context.settings.performanceMode = performance
    local entry = {
        key = "2:8",
        index = 2,
        id = 8,
        name = "Fighting guardian",
        state = "awake",
        status = "fighting",
        hp = 50,
        maximum = 100,
        healthFraction = 0.5,
    }
    context.entries[2], context.revision, context.generation = entry, 1, 1
    context:Tick()
    local second
    for _, object in ipairs(context.objects) do
        if object.parent == env.DFRL_GuardianTracker and object.status and object.bar and object ~= first then
            second = object
            break
        end
    end
    assert(second and second:IsShown() and second.health:GetText() == "50 / 100")
    local allocated, isShown = #context.objects, second.pill.IsShown
    local failCleanup = true
    function second.pill:IsShown()
        context.reads.sparePill = (context.reads.sparePill or 0) + 1
        if failCleanup then
            failCleanup = false
            error("injected guardian cleanup failure")
        end
        return isShown(self)
    end
    context.entries[2], context.revision = nil, 2
    local ok = pcall(function() context:Tick() end)
    assert(not ok and second:IsShown(), "guardian retirement did not reach the failed native operation")
    context:ResetCounts()
    context:Tick()
    assert(
        context.reads.sparePill == 1
            and not second:IsShown()
            and not isShown(second.pill)
            and second.health:GetText() == ""
            and second.bar.value == 0,
        "failed guardian retirement did not retry and clear the departed row"
    )
    context:ResetCounts()
    for _ = 1, 5 do
        context:Tick()
    end
    assert(not context.reads.sparePill, "settled guardian refresh visited an already retired row")
    entry.name, entry.hp, entry.healthFraction = "Returned guardian", 25, 0.25
    context.entries[2], context.revision = entry, 3
    context:Tick()
    assert(second:IsShown() and second.health:GetText() == "25 / 100" and #context.objects == allocated)
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(not second:IsShown() and not isShown(second.pill), "world leave missed the reused active row")
end
print("PASS guardian spare rows retire once with native cleanup retries and pool reuse")

for _, performance in ipairs({ false, true }) do
    local context, row = Tracker()
    local env = context.env
    context.settings.performanceMode = performance
    local compact = env.T.CompactHealth
    env.T.CompactHealth = function(...)
        context.reads.healthFormats = (context.reads.healthFormats or 0) + 1
        return compact(...)
    end
    context.revision, context.generation, context.fighting = 1, 1, 1
    context.entry.state, context.entry.status = "awake", "fighting"
    context.entry.hp, context.entry.maximum, context.entry.healthFraction = 50, 100, 0.5
    context:Tick()
    assert(
        row.health:GetText() == "50 / 100" and context.reads.healthFormats == 2,
        "health was formatted for measurement and paint"
    )
    context:ResetCounts()
    row.health.text = "native reset"
    context:Tick()
    assert(
        row.health:GetText() == "50 / 100" and not context.reads.healthFormats,
        "prepared caption lost actual text repair"
    )
    context.entry.hp, context.entry.healthFraction = 40, 0.4
    context:Tick()
    assert(row.health:GetText() == "40 / 100" and row.bar.value == 0.4 and context.reads.healthFormats == 2)
    context.entry.state, context.entry.status = "empty", "returning"
    context.entry.hp, context.entry.maximum, context.entry.healthFraction = nil, nil, nil
    context.revision, context.fighting = 2, 0
    context:Tick()
    assert(row.health:GetText() == "" and row.bar.value == 0, "zero-fighting roster retained visible health")
    env.ipairs = function(list)
        if list == context.entries then context.reads.healthScans = (context.reads.healthScans or 0) + 1 end
        return ipairs(list)
    end
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.healthScans, "settled zero-fighting roster still scanned for health captions")
    context.revision, context.fighting = 3, 1
    context.entries[2] = {
        key = "2:8",
        index = 2,
        id = 8,
        name = "Other",
        state = "awake",
        status = "fighting",
        hp = 75,
        maximum = 100,
        healthFraction = 0.75,
    }
    context:SetSetting("guardianShowDead", false)
    context:Tick()
    assert(
        row.health:GetText() == "75 / 100" and row.bar.value == 0.75,
        "filtered row borrowed another slot's prepared caption"
    )
end
print(
    "PASS guardian health shares prepared captions across measurement and painting with filtered-row and native repair parity"
)

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
    context.entry.key, context.entry.id, context.entry.state, context.entry.status = "1:7", 7, "awake", "fighting"
    context.entry.hp, context.entry.maximum = 166983, 331328
    context.entry.healthFraction = context.entry.hp / context.entry.maximum
    context:Tick()
    local allocated, value = #context.objects, row.bar.value
    assert(row.health:GetText() == "166.9K / 331.3K", "guardian default lost abbreviations")
    context:SetSetting("guardianShortHealth", false)
    context:Tick()
    assert(
        row.health:GetText() == "166983 / 331328" and row.bar.value == value,
        "full guardian labels changed native health"
    )
    assert(#context.objects == allocated, "guardian format choice allocated another view")
    context:ResetCounts()
    context:Tick()
    assert(not context.writes.SetText and not context.writes.SetValue, "unchanged full guardian health kept painting")
    context:SetHidden(true)
    context:SetSetting("guardianShortHealth", true)
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(not context.reads.snapshot, "hidden format change retained guardian reads")
    context:SetHidden(false)
    context:Tick()
    assert(
        row.health:GetText() == "166.9K / 331.3K" and #context.objects == allocated,
        "guardian format did not resume from its pool"
    )
end
print("PASS guardian full/short health choice, cache invalidation, native fill preservation and hidden reuse")

do
    local context, row = Tracker()
    context.entry.key, context.entry.id, context.entry.state, context.entry.status = "1:7", 7, "awake", "fighting"
    context.entry.hp, context.entry.maximum, context.entry.healthFraction = 50, 100, 0.5
    context:Tick()
    local allocated = #context.objects
    assert(row.health:GetText() == "50 / 100", "guardian percentages were not off by default")
    context:SetSetting("guardianShowHealthPercentage", true)
    context:Tick()
    assert(row.health:GetText() == "50 / 100 (50%)" and row.bar.value == 0.5, "guardian percentage changed health/fill")
    context.entry.hp, context.entry.maximum = 131122, 333333
    context.entry.healthFraction = context.entry.hp / context.entry.maximum
    context:Tick()
    assert(
        row.statusWidth >= string.len(row.health:GetText()) * 7 + 16,
        "percentage did not receive its measured pill width"
    )
    context.entry.hp, context.entry.maximum, context.entry.healthFraction = 50, 100, 0.5
    context:SetSetting("guardianShowCurrentHealth", false)
    context:SetSetting("guardianShowMaximumHealth", false)
    context:Tick()
    assert(
        row.health:GetText() == "50%" and row.health:IsShown() and row.pill:IsShown(),
        "percentage-only pill disappeared"
    )
    context.entry.hp, context.entry.healthFraction = 50.2, 0.502
    context:ResetCounts()
    context:Tick()
    assert(
        not context.writes.SetText and row.bar.value == 0.502,
        "unchanged percentage kept painting or blocked the fill"
    )
    context:SetHidden(true)
    context:SetSetting("guardianShowHealthPercentage", false)
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(not context.reads.snapshot, "hidden percentage choice retained tracker reads")
    context:SetHidden(false)
    context:Tick()
    assert(not row.health:IsShown() and row.pill:IsShown(), "all text off hid the native health fill")
    context:SetSetting("guardianShowHealthPercentage", true)
    context:Tick()
    assert(
        row.health:GetText() == "50%" and #context.objects == allocated,
        "percentage recovery replaced the existing view"
    )
end
print("PASS guardian percentage visibility, whole-percent caching, hidden recovery and native fill preservation")

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
