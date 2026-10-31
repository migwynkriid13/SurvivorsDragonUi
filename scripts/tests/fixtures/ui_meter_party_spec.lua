-- CI only: native-v1 meter presentation, navigation and lifecycle boundaries.
local helpers = assert(loadfile("scripts/tests/fixtures/ui_native_meter_view_spec.lua"))("helpers")
assert(_VERSION == "Lua 5.1", "meter presentation fixtures require CI Lua 5.1")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local Error = helpers.Error
local function Meter(configure)
    local context, state = helpers.New({
        start = false,
        configure = function(c, native, env)
            c.native = native
            c.settings.meterShowDamage = true
            native.context.asOfRunSeconds = 10
            native.records = { { id = "strike", rowId = "strike", name = "Strike", amount = 100, recent = 100 } }
            if configure then configure(c, native, env) end
        end,
    })
    function context:SetAmount(amount)
        state.records[1].amount = amount
        state.context.counterRevision, state.context.snapshotId = "amount-" .. amount, "snapshot-" .. amount
    end
    function context:Party()
        self:Tick()
        self:Cycle()
        self:Cycle()
        self:Cycle()
        assert(self.title:GetText() == "Party Damage", "party is not the fourth view")
    end
    return context
end
local function BoundedPass(context, start)
    local counts = {}
    for index = start + 1, #context.native.queries do
        local query = context.native.queries[index]
        local key = query.scope == "party" and "party" or query.period == "encounter" and "boss" or query.metric
        counts[key] = (counts[key] or 0) + 1
        assert(counts[key] == 1, "a deferred pass repeated a native view snapshot")
    end
end

Test("deferred native navigation skips unavailable scopes and reads each view once", function()
    local context = Meter(
        function(_, state) state.viewErrors = { boss = Error("NO_ENCOUNTER"), party = Error("NO_PARTY") } end
    )
    context:Tick()
    local reads, queries = context.native.calls.snapshot, #context.native.queries
    context:Call(context.header, "OnClick", "LeftButton")
    assert(context.native.calls.snapshot == reads and context.title:GetText() == "Damage Done")
    context:Tick()
    assert(context.title:GetText() == "Healing Done", "deferred selection skipped native healing")
    BoundedPass(context, queries)
    context:Cycle()
    assert(context.title:GetText() == "Damage Done", "unavailable scopes interrupted navigation")
    context:Cycle("RightButton")
    assert(context.title:GetText() == "Healing Done", "reverse navigation entered an unavailable scope")
    context.native.viewErrors.boss = nil
    context:Cycle()
    assert(context.title:GetText() == "Boss Damage", "new native encounter did not join the ring")
    assert(not context.native.calls.legacy and not context.controller.events.CHAT_MSG_ADDON)
end)

Test("queued clicks preserve direction without synchronous reads or private click history", function()
    local context = Meter()
    context:Tick()
    local reads = context.native.calls.snapshot
    context:Call(context.header, "OnClick", "LeftButton")
    context:Call(context.header, "OnClick", "LeftButton")
    assert(context.native.calls.snapshot == reads)
    context:Tick()
    assert(context.title:GetText() == "Boss Damage", "two queued clicks collapsed into one")
    context:Cycle("RightButton")
    assert(context.title:GetText() == "Healing Done")
end)

Test("ready-empty native views remain selectable and explicit errors remain truthful", function()
    local context = Meter(function(_, state)
        state.viewRecords = { healing = { { id = "empty", rowId = "empty", name = "Empty", amount = 0, recent = 0 } } }
        state.viewErrors = { boss = Error("NO_ENCOUNTER"), party = Error("NO_PARTY") }
    end)
    context:Tick()
    context:Cycle()
    assert(context.title:GetText() == "Healing Done" and not context:Row(1).active)
    assert(context.status:IsShown() and context.status:GetText() == "No meter entries yet.")
    context.native.viewErrors.healing = Error("INTERNAL_ERROR")
    context:Tick()
    assert(context.title:GetText() == "Healing Done" and context.status:GetText() == "Meter data is unavailable.")
end)

Test("all unready native scopes stay bounded and recover without publication packets", function()
    local context = Meter(
        function(_, state)
            state.viewErrors = {
                damage = Error("NOT_READY"),
                healing = Error("NOT_READY"),
                boss = Error("NO_ENCOUNTER"),
                party = Error("NO_PARTY"),
            }
        end
    )
    context:Tick()
    assert(context.title:GetText() == "Damage Done" and not context.status:IsShown())
    context:ResetCounts()
    for _ = 1, 4 do
        local start = #context.native.queries
        context:Tick()
        BoundedPass(context, start)
    end
    context:NoPresentationWrites()
    context.native.viewErrors.healing = nil
    context:Tick()
    assert(context.title:GetText() == "Healing Done" and context:Row(1).active)
end)

Test("failed drawing retires pass results and recovers from a fresh native snapshot", function()
    local context = Meter()
    context:Tick()
    context.failText = "Healing Done"
    local ok = pcall(function() context:Cycle() end)
    assert(not ok and not context.controller:GetScript("OnUpdate"))
    context:SetAmount(300)
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    local queries = #context.native.queries
    context:Tick()
    BoundedPass(context, queries)
    assert(context:Row(1).entry.dmg == 300, "failed pass survived into recovery")
end)

Test("hidden native navigation waits for Show and disabling collects no snapshots", function()
    local context = Meter()
    context:Tick()
    context:SetLayoutHidden(true)
    local snapshots = context.native.calls.snapshot
    context:Call(context.header, "OnClick", "LeftButton")
    context:Tick()
    assert(context.native.calls.snapshot == snapshots, "hidden queued navigation collected native rows")
    context:SetLayoutHidden(false)
    context:Tick()
    assert(context.title:GetText() == "Healing Done", "Show lost its queued native view")
    context:SetSetting("meterEnabled", false)
    local contexts = context.native.calls.context
    snapshots = context.native.calls.snapshot
    context:Call(context.header, "OnClick", "LeftButton")
    context:Tick()
    assert(context.native.calls.context == contexts and context.native.calls.snapshot == snapshots)
    context:SetSetting("meterEnabled", true)
    context:Tick()
    assert(context:Row(1).active, "enabling required a removed publication packet")
end)

Test("numeric reservation follows the final caption instead of fixed empty columns", function()
    local context = Meter()
    context:SetSetting("meterShowDamage", false)
    context:Tick()
    context:Cycle()
    local row = context:Row(1)
    assert(row.value:GetText() == "10" and row.value.measuredText == "10", "layout measured the previous caption")
    assert(row.value:GetWidth() == 9 and row.name:GetWidth() == 173, "short DPS retained a fixed numeric deadzone")
    local allocated = #context.objects
    local nameWidth = row.name:GetWidth()
    context:SetAmount(12100)
    for _ = 1, 5 do
        context:Tick()
    end
    assert(
        row.value:GetText() == "1.2K" and row.value.measuredText == "1.2K",
        "new values were measured one sample late"
    )
    assert(
        row.value:GetWidth() == 17 and row.name:GetWidth() == nameWidth - 8,
        "numeric growth did not take only its glyph space"
    )
    assert(row.entry.dps == 1210 and context.native.records[1].amount == 12100, "layout changed native values")
    context:ResetCounts()
    context:SetAmount(12400)
    for _ = 1, 5 do
        context:Tick()
    end
    assert(row.entry.dps == 1240 and row.value:GetText() == "1.2K")
    assert(not context.reads.metrics, "unchanged compact text was measured again")
    context:NoPresentationWrites()
    assert(#context.objects == allocated, "numeric layout allocated extra drawing regions")
    context:SetSetting("meterShowDamage", true)
    context:SetSetting("meterShowPercentage", true)
    context:Tick()
    local values = row.value:GetText()
    assert(
        string.find(values, "12.4K", 1, true) and string.find(values, "100.0%", 1, true),
        "enabled numeric information was removed"
    )
    assert(row.name:GetWidth() >= 48, "numeric columns consumed the minimum name space")
    context:SetSetting("meterShowDamage", false)
    context:SetSetting("meterShowDps", false)
    context:SetSetting("meterShowPercentage", false)
    context:ResetCounts()
    context:Tick()
    assert(
        not row.value:IsShown() and row.name:GetWidth() == 187,
        "disabled numbers did not return their entire gutter"
    )
    assert(not context.reads.metrics, "disabled numeric text still requested glyph metrics")
    context:SetSetting("meterShowIcons", false)
    context:ResetCounts()
    context:Tick()
    assert(row.name:GetWidth() == 219 and not context.reads.metrics, "disabled icons retained unused name space")
end)

Test("name and number fonts stay independent and rejected native sizes retry", function()
    local context = Meter()
    context:Tick()
    local row = context:Row(1)
    local allocated, numericAttempts = #context.objects, row.value.fontAttempts
    local iconWidth, rowHeight = row.icon:GetWidth(), row:GetHeight()
    context:SetSetting("meterNameFontSize", 8)
    context:Tick()
    local _, nameSize, nameFlags = row.name:GetFont()
    local _, numberSize, numberFlags = row.value:GetFont()
    assert(nameSize == 8 and numberSize == 11, "name font changed numeric text")
    assert(row.value.fontAttempts == numericAttempts, "name-only preview rebound the numeric font")
    assert(nameFlags == "OUTLINE" and numberFlags == "OUTLINE", "font preview removed outlines")
    assert(row.name.shadowColor[4] == 1 and row.name.shadowOffset[1] == 1 and row.name.shadowOffset[2] == -1)
    local nameAttempts = row.name.fontAttempts
    context:SetSetting("meterFontSize", 14)
    context:Tick()
    _, nameSize = row.name:GetFont()
    _, numberSize = row.value:GetFont()
    local _, headerSize = context.title:GetFont()
    assert(
        nameSize == 8 and numberSize == 14 and headerSize == 16,
        "numeric size changed names or lost the header offset"
    )
    assert(row.name.fontAttempts == nameAttempts, "number-only preview rebound the name font")
    context.failFontObject, context.failFontSize = row.name, 10
    context:SetSetting("meterNameFontSize", 10)
    context:Tick()
    _, nameSize = row.name:GetFont()
    assert(nameSize == 8, "rejected name font was recorded as usable")
    context.failFontObject = nil
    context:Tick()
    _, nameSize, nameFlags = row.name:GetFont()
    assert(nameSize == 10 and nameFlags == "OUTLINE", "failed name-size assignment did not retry")
    context.failFontObject, context.failFontSize = row.value, 16
    context:SetSetting("meterFontSize", 16)
    context:Tick()
    _, numberSize = row.value:GetFont()
    assert(numberSize == 14, "rejected numeric font was cached as applied")
    context.failFontObject = nil
    context:Tick()
    _, numberSize, numberFlags = row.value:GetFont()
    assert(numberSize == 16 and numberFlags == "OUTLINE", "failed numeric-size assignment did not retry")
    assert(row:GetHeight() == rowHeight and row.icon:GetWidth() == iconWidth and #context.objects == allocated)
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(not context.reads.metrics, "settled font retry kept measuring unchanged values")
end)

Test("global outline choices preserve successful size caching and rejected-size retries", function()
    for _, outline in ipairs({ "", "THICKOUTLINE" }) do
        local context = Meter()
        -- The real font registry is covered separately. This boundary models
        -- its effective flags so the production meter checks the accepted style.
        context.env.T.GetFontFlags = function() return outline end
        context.env.T.SetFont = function(object, size) object:SetFont("DEFAULT_TEST", size, outline) end
        context:SetSetting("meterNameFontSize", 10)
        context:SetSetting("meterFontSize", 13)
        context:Tick()
        local row = context:Row(1)
        local _, nameSize, nameFlags = row.name:GetFont()
        local _, numberSize, numberFlags = row.value:GetFont()
        assert(nameSize == 10 and nameFlags == outline and numberSize == 13 and numberFlags == outline)
        assert(
            row.layoutNameFontSize == 10 and row.layoutFontSize == 13,
            "accepted global outline did not settle the meter's size cache"
        )
        context.failFontObject, context.failFontSize = row.name, 9
        context:SetSetting("meterNameFontSize", 9)
        context:Tick()
        _, nameSize = row.name:GetFont()
        assert(nameSize == 10 and row.layoutNameFontSize == 10, "rejected size was cached with a global outline")
        context.failFontObject = nil
        context:Tick()
        _, nameSize, nameFlags = row.name:GetFont()
        assert(nameSize == 9 and nameFlags == outline and row.layoutNameFontSize == 9)
        context:ResetCounts()
        context:Tick()
        context:NoPresentationWrites()
        assert(not context.reads.metrics, "settled global outline kept measuring the meter")
    end
end)

Test("numeric metrics follow font scale and width changes and retry unavailable glyphs", function()
    local context = Meter()
    context:Tick()
    context:Cycle()
    local row = context:Row(1)
    local allocated = #context.objects
    local _, size, flags = row.value:GetFont()
    row.value:SetFont("OTHER_NATIVE_FACE", size, flags)
    context:ResetCounts()
    context:Tick()
    assert(context.reads.metrics == 1, "actual native font change retained the previous measurement")
    context.root:SetScale(1.1)
    context:ResetCounts()
    context:Tick()
    assert(context.reads.metrics == 1, "owner scale change retained native glyph metrics")
    context:ResetCounts()
    context:Resize(200)
    assert(context.reads.metrics == 1, "width change retained a measurement from another viewport")
    context:Resize(120)
    assert(row.name:GetWidth() >= 48 and row.value:GetWidth() > 0, "narrow viewport lost the name reservation")
    context:Resize(240)
    for _, metric in ipairs({ 0, -1, math.huge, 0 / 0 }) do
        context.metricOverride = metric
        row.value:SetFont("UNREADY_" .. tostring(metric), size, flags)
        context:ResetCounts()
        context:Tick()
        context:Tick()
        assert(context.reads.metrics == 2, "unavailable glyph width was cached as ready")
        assert(row.name:GetWidth() >= 48 and row.value:GetWidth() > 0, "metric failure broke safe layout")
        context.metricOverride = nil
        context:Tick()
        assert(row.value.measuredText == row.value:GetText(), "ready metrics did not recover against current text")
        context:ResetCounts()
        context:Tick()
        assert(not context.reads.metrics, "successful recovery failed to cache its native measurement")
    end
    context.metricMissing = true
    row.value:SetFont("MISSING_NATIVE_METRICS", size, flags)
    context:ResetCounts()
    context:Tick()
    context:Tick()
    assert(context.reads.metrics == 2, "missing native metrics were cached as ready")
    context.metricMissing = nil
    context:Tick()
    assert(#context.objects == allocated, "metric retries allocated extra labels or rulers")
end)

Test("hidden disabled and retired meter rows do no glyph work and reuse their pool", function()
    local context = Meter()
    context:Tick()
    context:Cycle()
    local row = context:Row(1)
    local allocated = #context.objects
    context:SetLayoutHidden(true)
    context:SetSetting("meterNameFontSize", 9)
    context:SetSetting("meterFontSize", 13)
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(not context.reads.metrics, "hidden meter measured numeric labels")
    context:SetLayoutHidden(false)
    context:Tick()
    local _, nameSize = row.name:GetFont()
    local _, numberSize = row.value:GetFont()
    assert(
        nameSize == 9 and numberSize == 13 and #context.objects == allocated,
        "visible recovery lost font choices or rebuilt rows"
    )
    context:SetSetting("meterEnabled", false)
    context:ResetCounts()
    context:Tick()
    assert(
        not context.reads.metrics and not context.controller:GetScript("OnUpdate"),
        "disabled meter retained glyph work"
    )
    context:SetSetting("meterEnabled", true)
    context:Tick()
    assert(row.active and #context.objects == allocated, "enabled meter did not reuse its existing row")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.metrics and not row.active, "world retirement measured or retained rows")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:Tick()
    assert(row.active and #context.objects == allocated, "fresh native data failed to reuse the retired row")
end)

Test("native party identity drives class colors and retained portraits in both directions", function()
    local context = Meter(
        function(_, state)
            state.viewRecords = {
                party = {
                    {
                        id = "friend",
                        rowId = "friend",
                        name = "Ability",
                        heroName = "Friend",
                        ownerId = "hero-2",
                        class = "mage",
                        amount = 200,
                        recent = 100,
                        departed = true,
                    },
                    {
                        id = "me",
                        rowId = "me",
                        name = "Ability",
                        heroName = "Me",
                        ownerId = "hero-1",
                        class = "rogue",
                        amount = 100,
                        recent = 50,
                    },
                },
            }
        end
    )
    context:Party()
    local first, second = context:Row(1), context:Row(2)
    assert(first.entry.name == "Friend" and first.entry.dps == 20 and first.entry.dmg == 200)
    assert(
        first.icon:GetTexture() == "Retained\\portrait-hero-2"
            and second.icon:GetTexture() == "Retained\\portrait-hero-1"
    )
    assert(first.bar.color[1] == 0.41 and second.bar.color[1] == 1, "native class colors were lost")
    context:Cycle()
    assert(context.title:GetText() == "Damage Done")
    context:Cycle("RightButton")
    assert(context.title:GetText() == "Party Damage")
    assert(not context.native.calls.legacy, "party presentation searched the current roster")
end)

Test("settled native party rows skip drawing and artwork while hidden or icons-off", function()
    local context = Meter()
    context:Party()
    local allocated, portraits = #context.objects, context.native.calls.portrait
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(#context.objects == allocated and context.native.calls.portrait == portraits)
    context:SetSetting("meterShowIcons", false)
    context:Tick()
    portraits = context.native.calls.portrait
    context:SetLayoutHidden(true)
    local snapshots = context.native.calls.snapshot
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(context.native.calls.portrait == portraits and context.native.calls.snapshot == snapshots)
    context:SetSetting("meterEnabled", false)
    context:Tick()
    assert(not context.controller:GetScript("OnUpdate") and not context.native.calls.legacy)
end)

Test("atomic native Reset includes party rows without rewriting counters or class metadata", function()
    local context = Meter()
    context:Party()
    context.env.DFRL.ResetMeterStats()
    assert(context.native.calls.create == 1 and not context:Row(1).active)
    context:Tick()
    assert(not context:Row(1).active, "checkpoint replayed pre-reset native damage")
    context.native.records[1].after = 30
    context.native.context.asOfRunSeconds = 12
    context.native.context.counterRevision, context.native.context.snapshotId = "post-X", "post-X"
    context:Tick()
    local entry = context:Row(1).entry
    assert(entry.dmg == 30 and entry.dps == 15 and entry.class == "hunter")
    assert(context.native.records[1].amount == 100 and not context.native.records[1].share)
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(context.native.calls.release == 1 and not context:Row(1).active)
end)

Test("unchanged native counters use native clock rates while pauses freeze their values", function()
    local context = Meter()
    context:Tick()
    context:Cycle()
    context:SetSetting("meterShowTotalDps", true)
    context.native.context.asOfRunSeconds = 20
    context.native.context.snapshotId = "clock-only"
    for _ = 1, 5 do
        context:Tick()
    end
    assert(context:Row(1).entry.dps == 5 and context.title:GetText() == "HPS: 5")
    context.native.context.phase = "paused"
    for _ = 1, 6 do
        context:Tick()
    end
    assert(context:Row(1).entry.dps == 5, "UI time changed a paused native rate")
    assert(not context.native.calls.legacy)
end)

print("PASS " .. passed .. " native meter presentation contracts")
