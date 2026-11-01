-- CI only: the full production meter using native v1 snapshots and retained artwork.
local helpers = assert(loadfile("scripts/tests/fixtures/ui_native_meter_api_spec.lua"))("helpers")
assert(_VERSION == "Lua 5.1", "native meter view fixtures require CI Lua 5.1")

local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    print("PASS " .. name)
end

local function View(configure)
    local c, state, _, env = helpers.New()
    local function CountPresentation(object, key)
        if state.trackedPresentation and state.trackedPresentation[object] then
            state.presentationOps[key] = (state.presentationOps[key] or 0) + 1
        end
    end
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        for _, method in ipairs({ "GetText", "GetFont", "GetWidth" }) do
            local key, original = method, object[method]
            object[key] = function(self, ...)
                CountPresentation(self, key)
                return original(self, ...)
            end
        end
        local setFont = object.SetFont
        function object:SetFont(face, size, flags)
            CountPresentation(self, "SetFont")
            if state.rejectFontObject == self and state.rejectFontSize == size then return false end
            return setFont(self, face, size, flags)
        end
        function object:GetStringWidth()
            CountPresentation(self, "GetStringWidth")
            if state.missingMetrics then return 0 end
            return string.len(self:GetText()) * 4
        end
        function object:GetEffectiveScale()
            CountPresentation(self, "GetEffectiveScale")
            return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        function object:SetScale(value) self.scale = value end
        function object:SetMinMaxValues(low, high)
            self.minimum, self.maximum = low, high
        end
        function object:SetValue(value)
            CountPresentation(self, "SetValue")
            self.value = value
        end
        function object:SetStatusBarTexture(path)
            self.barTexture = path
            return true
        end
        function object:SetStatusBarColor(...)
            CountPresentation(self, "SetStatusBarColor")
            self.color = { ... }
        end
        function object:RegisterForClicks(...) self.clicks = { ... } end
        function object:EnableMouseWheel(value) self.mouseWheel = value end
        function object:SetBlendMode(value) self.blend = value end
        for _, name in ipairs({ "Normal", "Pushed", "Highlight" }) do
            local key = name
            object["Set" .. key .. "Texture"] = function(self, path)
                self[key] = self:CreateTexture(nil, "ARTWORK")
                self[key]:SetTexture(path)
            end
            object["Get" .. key .. "Texture"] = function(self) return self[key] end
        end
        return object
    end
    function env.UIParent:GetEffectiveScale() return 1 end
    env.geterrorhandler = function()
        return function(message) error(message) end
    end
    env.T.SourceIconFallback = "Interface\\Icons\\INV_Misc_QuestionMark"
    env.T.SetChatShadow = function(label)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
    end
    env.DFRL.locale.code = "en"
    env.DFRL.layout.IsHidden = function() return not c.layoutMask:IsShown() end
    env.DFRL.layout.Place = function() end
    env.UnitClass = function(unit)
        assert(unit == "player", "native meter read the current party roster for historical class metadata")
        return "Hunter", "HUNTER"
    end
    env.UnitExists = function() error("native meter searched the live roster for a retained hero") end
    env.SetPortraitTexture = function() error("native meter guessed a unit for its retained native portrait") end
    env.SetPortraitToTexture = function(name, path)
        local texture = assert(env[name], "native circle binding used an unknown texture name")
        texture:SetTexture(path)
    end
    env.AZS_GetPhase = function() error("native meter read the legacy phase instead of its snapshot context") end
    env.AZS_SetMeterPortrait = function(texture, runId, key)
        state.calls.portrait = (state.calls.portrait or 0) + 1
        assert(
            type(texture) == "table" and texture.kind == "Texture",
            "portrait binding did not receive the native texture object"
        )
        assert(runId == state.context.runId, "portrait binding lost its native run identity")
        if state.portraitError then return nil, state.portraitError end
        texture:SetTexture("Retained\\" .. key)
        return true, nil
    end
    c.settings = {
        meterEnabled = true,
        meterRows = 6,
        meterFontSize = 11,
        meterNameFontSize = 11,
        meterDpsWindow = 10,
        meterShowDamage = false,
        meterShowDps = true,
        meterShowPercentage = false,
        meterShowIcons = true,
        meterShowRanks = false,
        meterShowTotal = false,
        meterShowTotalDps = false,
    }
    if configure then configure(c, state, env) end
    c:Load("core/hud.lua")
    c:Load("core/meter_rates.lua")
    c:Load("core/widgets.lua")
    if state.instrumentPresentation then
        local factory = env.T.NewCircularIcon
        env.T.NewCircularIcon = function(...)
            local icon = factory(...)
            local bind = icon.Bind
            icon.Bind = function(path, ...)
                if state.trackedPresentation then state.presentationOps.Bind = (state.presentationOps.Bind or 0) + 1 end
                if state.rejectedIcon == path then return false end
                return bind(path, ...)
            end
            return icon
        end
        local register = env.DFRL.layout.Register
        env.DFRL.layout.Register = function(name, frame, anchor, options)
            if name == "damageMeter" then c.meterLayoutOptions = options end
            return register(name, frame, anchor, options)
        end
    end
    c:Load("modules/ui/meter.lua", "DamageMeter")
    c.root, c.controller = env.DFRL_DamageMeter, c:Controller("PLAYER_ENTERING_WORLD")
    for _, object in ipairs(c.objects) do
        if object.kind == "Button" and object.parent == c.root then c.header = object end
    end
    for _, object in ipairs(c.objects) do
        if object.kind == "FontString" and object.parent == c.header then c.title = object end
        if object.kind == "FontString" and object.parent == c.root then c.status = object end
    end
    function c:Tick(elapsed)
        local step = elapsed or 1.01
        self.now = self.now + step
        self:Call(self.controller, "OnUpdate", step)
    end
    function c:Cycle(direction)
        self:Call(self.header, "OnClick", direction or "LeftButton")
        self:Tick()
    end
    function c:Row(index) return assert(env["SurvivorsDragonUiMeterIcon" .. index]):GetParent() end
    c:Tick()
    return c, state, env
end

local function HistoryView(performance)
    return View(function(context, native)
        context.settings.performanceMode, context.settings.meterRows = performance, 2
        context.settings.meterShowTotal = true
        native.records = {}
        for index = 1, 8 do
            local amount = 1100 - index * 100
            native.records[index] = {
                id = "history-source-" .. index,
                rowId = "history-leaf-" .. index,
                name = "History " .. index,
                rank = 1,
                amount = amount,
                recent = index == 1 and 70 or index * 10,
                after = amount / 10,
            }
        end
    end)
end

local function HistoryCounts(state)
    local recent, all = 0, 0
    for _, query in ipairs(state.queries) do
        if query.metric == "damage" and query.scope == "self" and query.period == "run" then
            if query.windowSeconds > 0 then
                recent = recent + 1
            else
                all = all + 1
            end
        end
    end
    return recent, all
end

local function HistoryTick(context, state, suffix, elapsed)
    local step = elapsed or 1.01
    state.context.asOfRunSeconds = state.context.asOfRunSeconds + step
    state.context.counterRevision, state.context.snapshotId = "history-" .. suffix, "history-" .. suffix
    context:Tick(step)
end

local function WatchPresentation(context, state, count)
    state.trackedPresentation, state.presentationOps = {}, {}
    for index = 1, count do
        local row = context:Row(index)
        state.trackedPresentation[row], state.trackedPresentation[row.name] = true, true
        state.trackedPresentation[row.value], state.trackedPresentation[row.bar] = true, true
    end
end

Test("native IDs keep different rates for equal source names and bypass guessed artwork", function()
    local c = View()
    assert(c.root:IsVisible(), "native meter did not become ready without legacy publication packets")
    local first, second = c:Row(1), c:Row(2)
    assert(first.name:GetText() == "Same name (Hunter pet)" and second.name:GetText() == "Same name")
    assert(first.entry.rowId ~= second.entry.rowId, "production view lost native row identity")
    assert(first.value:GetText() == "5" and second.value:GetText() == "1", "equal names shared a sampled rate slot")
    assert(
        first.icon:GetTexture() == "Interface\\Icons\\source-a"
            and second.icon:GetTexture() == "Interface\\Icons\\source-b"
    )
    c:SetSetting("meterDpsWindow", 0)
    c:Tick()
    assert(
        first.value:GetText() == "5" and second.value:GetText() == "2",
        "All used recent rather than native average rates"
    )
end)

Test("settled native rows skip layout reads and static binding while changed values and leaders remain live", function()
    for _, performance in ipairs({ false, true }) do
        local c, state = View(function(context, native)
            context.settings.performanceMode, context.settings.meterRows = performance, 2
            native.instrumentPresentation = true
        end)
        WatchPresentation(c, state, 2)
        c:ResetCounts()
        c:Tick()
        local ops = state.presentationOps
        assert(ops.GetFont == 2, "settled rows did not retain one targeted numeric-font check each")
        assert(
            not ops.GetText
                and not ops.GetWidth
                and not ops.GetEffectiveScale
                and not ops.GetStringWidth
                and not ops.Bind
        )
        assert(not ops.SetValue and not ops.SetStatusBarColor)
        c:NoPresentationWrites()
        c:SetSetting("meterShowTotal", true)
        WatchPresentation(c, state, 2)
        c:Tick(0.01)
        ops = state.presentationOps
        assert(ops.GetFont == 2 and not ops.GetText and not ops.GetWidth and not ops.GetEffectiveScale)
        assert(not ops.GetStringWidth and not ops.Bind, "header-only choice refreshed unchanged row presentation")
        state.records[1].recent, state.context.counterRevision = 50.4, "same-formatted-dps"
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(
            c:Row(1).entry.dps == 5.04
                and not state.presentationOps.GetStringWidth
                and not state.presentationOps.GetWidth
        )
        assert(not state.presentationOps.Bind, "rate-only change rebound static artwork")
        state.records[1].recent, state.records[1].amount = 500, 1000
        state.context.counterRevision = "changed-formatted-dps"
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(c:Row(1).value:GetText() == "50" and (state.presentationOps.GetStringWidth or 0) > 0)
        local fraction = c:Row(2).bar.value
        state.records[1].amount, state.context.counterRevision = 2000, "changed-leader-maximum"
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(c:Row(2).bar.value == 0.02 and c:Row(2).bar.value ~= fraction)
        assert(
            not state.presentationOps.GetStringWidth
                and not state.presentationOps.GetWidth
                and not state.presentationOps.Bind
        )
        state.records[2].proc, state.context.counterRevision = true, "changed-native-proc-color"
        state.records[2].rowId = "native-proc-leaf-b"
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(c:Row(2).bar.color[1] == 0.25 and state.presentationOps.SetStatusBarColor == 1)
        assert(not state.presentationOps.GetStringWidth and not state.presentationOps.Bind)
        local icon = "Interface\\Icons\\rejected-static-icon"
        state.records[1].icon, state.rejectedIcon = { status = "ready", path = icon }, icon
        state.context.metadataRevision = "changed-static-icon"
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(state.presentationOps.Bind == 1, "metadata change did not attempt only its changed native artwork")
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(state.presentationOps.Bind == 1, "failed static artwork was treated as successfully cached")
        state.rejectedIcon = nil
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(c:Row(1).icon:GetTexture() == icon and state.presentationOps.Bind == 1)
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(not state.presentationOps.Bind, "successful artwork kept retrying")
        local allocated = #c.objects
        table.insert(state.records, { id = "third", rowId = "third", name = "Third", amount = 20, recent = 5 })
        state.context.counterRevision = "new-visible-pool-binding"
        c:Tick()
        c:Call(c.root, "OnMouseWheel", -1)
        WatchPresentation(c, state, 2)
        c:Tick(0.01)
        assert(c:Row(2).entry.name == "Third" and (state.presentationOps.Bind or 0) > 0 and #c.objects == allocated)
    end
end)

Test("enabling an unavailable native DPS column reveals its placeholder without changing the rate", function()
    for _, performance in ipairs({ false, true }) do
        local c = View(function(context, native)
            context.settings.performanceMode, context.settings.meterShowDps = performance, false
            native.recentStatus = "unavailable"
        end)
        local row = c:Row(1)
        assert(row.entry.dps == nil and not row.value:IsShown())
        c:SetSetting("meterShowDps", true)
        c:Tick(0.01)
        assert(row.entry.dps == nil and row.value:IsShown() and row.value:GetText() == "--")
        c:SetSetting("meterShowDps", false)
        c:Tick(0.01)
        assert(row.entry.dps == nil and not row.value:IsShown())
    end
end)

Test("row layout gates retain scale, dimensions, global fonts and failed-metric or font retries", function()
    for _, performance in ipairs({ false, true }) do
        local c, state = View(function(context, native, env)
            context.settings.performanceMode, context.settings.meterRows = performance, 2
            context.settings.uiFont, context.settings.uiFontOutline = "default", "OUTLINE"
            native.instrumentPresentation = true
            env.T.GetFontFlags = function(flags) return native.fontFlags or flags or "" end
            env.T.SetFont = function(object, size, flags)
                object:SetFont(native.fontFace or "DEFAULT_TEST", size, env.T.GetFontFlags(flags))
            end
        end)
        c.root:SetScale(0.9)
        WatchPresentation(c, state, 2)
        c:Tick()
        assert((state.presentationOps.GetStringWidth or 0) > 0 and (state.presentationOps.Bind or 0) > 0)
        c.root:SetWidth(300)
        c.meterLayoutOptions.onResize(c.root)
        WatchPresentation(c, state, 2)
        c:Tick(0.01)
        assert((state.presentationOps.GetStringWidth or 0) > 0, "width change reused a stale numeric-slot metric")
        state.fontFace, state.fontFlags = "CHANGED_NATIVE_FONT", "THICKOUTLINE"
        for _, object in ipairs(c.objects) do
            if object.kind == "FontString" and object.font then
                object:SetFont(state.fontFace, object.font[2], state.fontFlags)
            end
        end
        c:SetSetting("uiFont", "changed-native")
        c:SetSetting("uiFontOutline", "THICKOUTLINE")
        WatchPresentation(c, state, 2)
        c:Tick()
        assert((state.presentationOps.GetStringWidth or 0) > 0)
        assert(c:Row(1).value.font[1] == state.fontFace and c:Row(1).value.font[3] == state.fontFlags)
        c:Row(1).value:SetFont("EXTERNAL_NUMERIC_FACE", 13, "OUTLINE")
        WatchPresentation(c, state, 2)
        c:Tick()
        assert((state.presentationOps.GetStringWidth or 0) > 0, "numeric font mutation bypassed the layout gate")
        c:Tick()
        state.rejectFontObject, state.rejectFontSize = c:Row(1).name, 14
        c:SetSetting("meterNameFontSize", 14)
        c:Tick()
        assert(c:Row(1).name.font[2] ~= 14)
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(
            (state.presentationOps.SetFont or 0) > 0,
            "rejected name font stopped retrying after the first layout pass"
        )
        state.rejectFontObject = nil
        c:Tick()
        assert(c:Row(1).name.font[2] == 14)
        state.missingMetrics, state.records[1].recent = true, 500
        state.records[1].amount, state.context.counterRevision = 1000, "pending-metric-caption"
        c:Tick()
        WatchPresentation(c, state, 2)
        c:Tick()
        assert((state.presentationOps.GetStringWidth or 0) > 0, "missing metrics were recorded as settled")
        state.missingMetrics = false
        c:Tick()
        WatchPresentation(c, state, 2)
        c:Tick()
        assert(
            state.presentationOps.GetFont == 2
                and not state.presentationOps.GetStringWidth
                and not state.presentationOps.GetWidth
        )
        assert(
            not state.presentationOps.GetText
                and not state.presentationOps.GetEffectiveScale
                and not state.presentationOps.Bind
        )
    end
end)

Test("large native ledgers copy only the viewport and share one fresh context per refresh", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = View(function(context, native, environment)
            context.settings.performanceMode, context.settings.meterShowRanks = performance, true
            native.records = {}
            for index = 1, 1000 do
                native.records[index] = {
                    id = "large-source-" .. index,
                    rowId = "large-leaf-" .. index,
                    name = "Spell " .. index,
                    amount = 2000 - index,
                    recent = 100,
                }
            end
            native.ownerFields = {}
            local factory = environment.T.NewNativeMeter
            environment.T.NewNativeMeter = function()
                local api = factory()
                local read, captured, proxies = api.Read, nil, {}
                api.Read = function(...)
                    local source, total, rate, message, revision, meta = read(...)
                    if not source then return source, total, rate, message, revision, meta end
                    if source ~= captured then
                        captured, proxies = source, {}
                    end
                    for index = 1, table.getn(source) do
                        if not proxies[index] then
                            local slot = index
                            proxies[index] = setmetatable({}, {
                                __index = function(_, key)
                                    native.ownerFields[key] = (native.ownerFields[key] or 0) + 1
                                    return captured[slot][key]
                                end,
                            })
                        end
                    end
                    for index = table.getn(source) + 1, table.getn(proxies) do
                        proxies[index] = nil
                    end
                    return proxies, total, rate, message, revision, meta
                end
                return api
            end
        end)
        assert(
            state.ownerFields.name == 6 and state.ownerFields.rowId == 6,
            "controller copied the complete native ledger"
        )
        assert(state.calls.context == 1 and state.calls.snapshot == 1, "one refresh repeated its context getter")
        local allocated = #c.objects
        state.ownerFields = {}
        for index = 1001, 1200 do
            state.records[index] = {
                id = "large-source-" .. index,
                rowId = "large-leaf-" .. index,
                name = "Spell " .. index,
                amount = 2000 - index,
                recent = 100,
            }
        end
        state.records[1].amount = 2010
        state.context.counterRevision = "large-growth"
        c:Tick()
        assert(state.ownerFields.name == 6 and state.ownerFields.rowId == 6 and c:Row(1).entry.dmg == 2010)
        assert(state.calls.context == 2 and state.calls.snapshot == 2 and #c.objects == allocated)
        state.records[7].recent = 777
        state.context.counterRevision = "new-viewport-rate"
        local reads = state.calls.snapshot
        c:Call(c.root, "OnMouseWheel", -1)
        assert(
            c:Row(1).name:GetText() == "1. Spell 1" and state.calls.snapshot == reads,
            "scroll read native data synchronously"
        )
        c:Tick(0.01)
        assert(c:Row(1).name:GetText() == "2. Spell 2" and c:Row(6).entry.name == "Spell 7")
        assert(c:Row(6).entry.dps == 77.7, "newly revealed row inherited another identity's sampled rate")
        c:Call(c.root, "OnMouseWheel", -100)
        c:Tick(0.01)
        assert(c:Row(1).name:GetText() == "102. Spell 102")
        state.records[1].recent = 123
        state.context.counterRevision = "revisited-viewport-rate"
        c:Call(c.root, "OnMouseWheel", 10000)
        c:Tick(0.01)
        assert(c:Row(1).name:GetText() == "1. Spell 1" and c:Row(1).entry.dps == 12.3)
        state.records[1].recent, state.records[1].amount = 234, 2020
        state.context.counterRevision = "visible-rate-held"
        c:SetSetting("meterShowDamage", true)
        c:Tick(0.21)
        assert(c:Row(1).entry.dps == 12.3 and c:Row(1).entry.dmg == 2020, "viewport rates lost their one-Hz cadence")
        c:Tick(1.01)
        assert(c:Row(1).entry.dps == 23.4 and #c.objects == allocated)
        local contexts = state.calls.context
        env.DFRL.ResetMeterStats()
        assert(state.calls.context == contexts + 1, "manual Reset reused an earlier refresh context")
        c:SetLayoutHidden(true)
        c:Tick()
        reads = state.calls.snapshot
        c:Tick()
        assert(state.calls.snapshot == reads, "settled hidden viewport read complete native data")
        c:SetSetting("meterEnabled", false)
        c:Tick()
        assert(state.calls.snapshot == reads and not c.controller:GetScript("OnUpdate"))
    end
end)

Test("native controller waits one second between regular reads and defers input to the next frame", function()
    for _, performance in ipairs({ false, true }) do
        local c, state = HistoryView(performance)
        local identity, allocated = c:Row(1).entry.rowId, #c.objects
        assert(c:Row(1).entry.dps == 7 and c:Row(1).entry.averageDps == 50)
        local recent = HistoryCounts(state)
        assert(recent == 1, "initial viewport did not request one native recent capture")
        local contexts, reads, title = state.calls.context, state.calls.snapshot, c.title:GetText()
        state.records[1].recent = 90
        for tick = 1, 4 do
            state.records[1].amount = state.records[1].amount + 1000
            HistoryTick(c, state, "counter-" .. tick, 0.21)
            assert(
                state.calls.context == contexts and state.calls.snapshot == reads,
                "regular reads ran before one second"
            )
            assert(c:Row(1).entry.dmg == 1000 and c.title:GetText() == title)
            assert(
                c:Row(1).entry.dps == 7 and c:Row(1).entry.rowId == identity,
                "waiting for the next refresh changed a native rate or identity"
            )
            recent = HistoryCounts(state)
            assert(recent == 1, "native history ran before the one-second deadline")
        end
        HistoryTick(c, state, "rate-due", 0.21)
        recent = HistoryCounts(state)
        assert(recent == 2 and c:Row(1).entry.dps == 9 and #c.objects == allocated)
        assert(state.calls.context == contexts + 1 and state.calls.snapshot == reads + 1)
        assert(c:Row(1).entry.dmg == 5000 and c.title:GetText() ~= title)
        state.records[3].recent = 123
        reads = state.calls.snapshot
        c:Call(c.root, "OnMouseWheel", -1)
        assert(state.calls.snapshot == reads, "scroll fetched native history synchronously")
        HistoryTick(c, state, "revealed", 0.01)
        local revealed = HistoryCounts(state)
        assert(revealed > recent and c:Row(2).entry.name == "History 3" and c:Row(2).entry.dps == 12.3)
        c:Call(c.root, "OnMouseWheel", 100)
        HistoryTick(c, state, "first-page", 0.01)
        table.insert(state.records, 1, {
            id = "history-new",
            rowId = "history-new",
            name = "New native source",
            rank = 1,
            amount = 10000,
            recent = 140,
            after = 100,
        })
        recent = HistoryCounts(state)
        c:Call(c.root, "OnMouseWheel", 0)
        HistoryTick(c, state, "new-visible", 0.01)
        local admitted = HistoryCounts(state)
        assert(admitted > recent and c:Row(1).entry.name == "New native source" and c:Row(1).entry.dps == 14)
        c:SetSetting("meterDpsWindow", 0)
        HistoryTick(c, state, "all")
        recent = HistoryCounts(state)
        for tick = 1, 3 do
            HistoryTick(c, state, "all-" .. tick)
        end
        assert(HistoryCounts(state) == recent, "All requested a positive native history window")
        assert(c:Row(1).entry.dps == c:Row(1).entry.averageDps and #c.objects == allocated)
    end
end)

Test("a retained rank-group identity refreshes changed membership and regressed native time immediately", function()
    for _, performance in ipairs({ false, true }) do
        local c, state = View(function(context, native)
            context.settings.performanceMode = performance
            native.records = helpers.Ranks(1)
        end)
        local identity = c:Row(1).entry.rowId
        state.records = helpers.Ranks(2)
        c:Call(c.root, "OnMouseWheel", 0)
        HistoryTick(c, state, "new-rank-member", 0.01)
        local expected = state.lastResponse.rows[1].displayRate.value + state.lastResponse.rows[2].displayRate.value
        assert(c:Row(1).entry.rowId == identity and c:Row(1).entry.dmg == 30)
        assert(c:Row(1).entry.dps == expected, "same group ID kept its old partial rate until the next one-Hz sample")
        local recent = HistoryCounts(state)
        state.records[1].amount, state.records[1].recent = 200, 20
        state.records[2].amount, state.records[2].recent = 100, 10
        -- Defend against an unexpected host clock regression without deriving a rate locally.
        state.context.asOfRunSeconds, state.context.counterRevision = 19, "regressed-native-time"
        state.context.snapshotId = "regressed-native-time"
        c:Call(c.root, "OnMouseWheel", 0)
        c:Tick(0.01)
        assert(c:Row(1).entry.rowId == identity and c:Row(1).entry.dmg == 300)
        assert(c:Row(1).entry.dps == 3, "regressed native time retained the previous presentation sample")
        assert(HistoryCounts(state) > recent and state.queries[table.getn(state.queries)].windowSeconds == 10)
    end
end)

Test("reduced history cadence retains native unavailable, warmup, reset and view lifecycles", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = HistoryView(performance)
        state.recentStatus = "unavailable"
        HistoryTick(c, state, "history-gap", 1.01)
        assert(c:Row(1).entry.dps == nil and c:Row(1).entry.averageDps ~= nil)
        assert(c:Row(1).value:GetText() == "--", "native history gap was filled with an All average")
        local recent = HistoryCounts(state)
        HistoryTick(c, state, "gap-held", 0.21)
        assert(HistoryCounts(state) == recent and c:Row(1).entry.dps == nil)
        state.recentStatus = "ready"
        env.DFRL.ResetMeterStats()
        local checkpoint = state.checkpoint.checkpointId
        HistoryTick(c, state, "reset-warmup", 0.21)
        assert(c:Row(1).entry.dmg == 100 and c:Row(1).entry.dps == nil)
        assert(state.queries[table.getn(state.queries)].checkpointId == checkpoint)
        recent = HistoryCounts(state)
        HistoryTick(c, state, "warmup-held", 0.21)
        assert(HistoryCounts(state) == recent and c:Row(1).entry.dps == nil)
        HistoryTick(c, state, "warmup-ended", 1.01)
        local span = math.min(10, state.context.asOfRunSeconds - state.checkpoint.atRunSeconds)
        assert(c:Row(1).entry.dps == 70 / span and state.calls.create == 1)
        c:SetSetting("meterShowTotal", false)
        c:Cycle()
        assert(c.title:GetText() == "Healing Done")
        recent = HistoryCounts(state)
        HistoryTick(c, state, "healing-counters")
        assert(HistoryCounts(state) == recent, "another tab kept querying Damage Done history")
        state.records[1].recent = 160
        c:Cycle("RightButton")
        span = math.min(10, state.context.asOfRunSeconds - state.checkpoint.atRunSeconds)
        assert(c.title:GetText() == "Damage Done" and c:Row(1).entry.dps == 100 / span)
        assert(HistoryCounts(state) > recent and state.calls.create == 1)
        c:SetLayoutHidden(true)
        local reads = state.calls.snapshot
        c:Tick()
        c:Tick()
        assert(state.calls.snapshot == reads, "hidden history cache kept requesting native snapshots")
        c:SetLayoutHidden(false)
        HistoryTick(c, state, "shown-again")
        span = math.min(10, state.context.asOfRunSeconds - state.checkpoint.atRunSeconds)
        assert(c:Row(1).entry.dps == 100 / span and state.queries[table.getn(state.queries)].checkpointId == checkpoint)
        c:SetSetting("meterEnabled", false)
        reads = state.calls.snapshot
        c:Tick()
        assert(state.calls.snapshot == reads and not c.controller:GetScript("OnUpdate"))
    end
end)

Test("all native language labels remain literal in the production meter", function()
    local c, state = View()
    local counterRevision = state.context.counterRevision
    local firstId, secondId = c:Row(1).entry.rowId, c:Row(2).entry.rowId
    for index, language in ipairs(helpers.languages) do
        -- View has already painted the initial metadata-1/language-1 capture.
        -- Native labels may change only with a new metadata publication.
        state.context.languageCode, state.context.languageRevision = language, "view-language-" .. index
        state.context.metadataRevision, state.context.snapshotId = "view-metadata-" .. index, "view-snapshot-" .. index
        state.records[1].name, state.records[2].name = helpers.labels[index], "123"
        c.env.DFRL.locale.code = language
        c:NotifyLocale()
        c:Tick()
        assert(
            c:Row(1).name:GetText() == helpers.labels[index] .. " (Hunter pet)",
            "production view lost the native localized skill or caster caption"
        )
        assert(c:Row(2).name:GetText() == "123", "production view coerced a numeric-looking ability name")
        assert(
            c:Row(1).entry.rowId == firstId
                and c:Row(2).entry.rowId == secondId
                and state.context.counterRevision == counterRevision,
            "language metadata changed native row or counter identity"
        )
    end
end)

Test("metadata-only native publications refresh names and icons without a locale callback", function()
    local c, state = View()
    local row = c:Row(1)
    local rowId, counterRevision = row.entry.rowId, state.context.counterRevision
    state.records[1].name = "Updated native ability"
    state.records[1].icon = { status = "ready", path = "Interface\\Icons\\updated-native-ability" }
    state.context.metadataRevision, state.context.snapshotId = "updated-metadata", "updated-snapshot"
    c:Tick()
    assert(
        row.name:GetText() == "Updated native ability (Hunter pet)",
        "metadata-only publication retained the old ability label"
    )
    assert(
        row.icon:GetTexture() == "Interface\\Icons\\updated-native-ability",
        "metadata-only publication retained old artwork"
    )
    assert(
        row.entry.rowId == rowId and row.entry.dmg == 100 and state.context.counterRevision == counterRevision,
        "metadata-only publication rebased native counters or row identity"
    )
    c:ResetCounts()
    c:Tick()
    c:NoPresentationWrites()
end)

Test("talent proc captions keep ordinary casts and share metadata, reset and hidden lifecycles", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = View(function(context, native)
            context.settings.performanceMode = performance
            native.records, native.extraSources = helpers.Talents()
        end)
        local normal, streak, chastise, shaman = c:Row(1), c:Row(2), c:Row(3), c:Row(4)
        assert(normal.name:GetText() == "Pyroblast" and normal.entry.dmg == 9400)
        assert(streak.name:GetText() == "Hot Streak" and streak.entry.dmg == 4900)
        assert(chastise.name:GetText() == "Chastise" and shaman.name:GetText() == "Received shaman talent")
        assert(normal.icon:GetTexture() == "Interface\\Icons\\pyroblast-normal")
        assert(streak.icon:GetTexture() == "Interface\\Icons\\hot-streak-talent")
        assert(chastise.icon:GetTexture() == "Interface\\Icons\\chastise-talent")
        assert(shaman.icon:GetTexture() == "Interface\\Icons\\shaman-talent")
        for _, row in ipairs({ streak, chastise, shaman }) do
            assert(row.bar.color[1] == 0.25 and row.bar.color[2] == 0.58 and row.bar.color[3] == 1)
        end
        assert(normal.entry.proc == 0 and streak.entry.proc == 1, "talent captions changed native proc classification")
        assert(
            state.lastResponse.sources["pyroblast-proc"].name == "Pyroblast"
                and state.lastResponse.sources["holy-nova-proc"].name == "FX Holy nova",
            "talent presentation rewrote native source descriptors"
        )
        local identity, allocated, counters = streak.entry.rowId, #c.objects, state.context.counterRevision
        c:ResetCounts()
        c:Tick()
        c:NoPresentationWrites()
        for index, status in ipairs({ "pending", "missing" }) do
            state.extraSources["hot-streak"].icon = status == "pending" and { status = status, retryAfterSeconds = 0.2 }
                or { status = status, reason = "not_available" }
            state.context.metadataRevision = "talent-art-" .. index
            c:Tick()
            assert(streak.name:GetText() == "Hot Streak" and streak.entry.rowId == identity)
            assert(streak.icon:GetTexture() == env.T.SourceIconFallback, "talent art borrowed the triggered spell icon")
        end
        state.extraSources["hot-streak"].name = "Received talent renamed"
        state.extraSources["hot-streak"].icon = { status = "ready", path = "Interface\\Icons\\hot-streak-restored" }
        state.context.metadataRevision = "talent-art-restored"
        c:Tick()
        assert(streak.name:GetText() == "Received talent renamed" and streak.entry.rowId == identity)
        assert(streak.icon:GetTexture() == "Interface\\Icons\\hot-streak-restored")
        assert(streak.entry.dmg == 4900 and state.context.counterRevision == counters and #c.objects == allocated)
        env.DFRL.ResetMeterStats()
        state.context.asOfRunSeconds, state.context.counterRevision = 22, "talent-after-X"
        c:Tick()
        assert(streak.entry.dmg == 490 and state.calls.create == 1)
        local checkpoint = state.queries[table.getn(state.queries)].checkpointId
        c:SetLayoutHidden(true)
        state.extraSources["hot-streak"].name = "Hidden native talent"
        state.context.metadataRevision = "hidden-talent-metadata"
        local reads = state.calls.snapshot
        c:ResetCounts()
        c:Tick()
        assert(state.calls.snapshot == reads, "hidden talent captions read native snapshots")
        c:NoPresentationWrites()
        c:SetLayoutHidden(false)
        c:Tick()
        assert(streak.name:GetText() == "Hidden native talent" and streak.entry.dmg == 490)
        assert(state.calls.create == 1 and state.queries[table.getn(state.queries)].checkpointId == checkpoint)
        assert(#c.objects == allocated, "talent metadata grew the native row pool")
        c:SetSetting("meterEnabled", false)
        reads = state.calls.snapshot
        c:ResetCounts()
        c:Tick()
        assert(state.calls.snapshot == reads and not c.controller:GetScript("OnUpdate"))
        c:NoPresentationWrites()
    end
end)

Test("native X captures at the click and language changes preserve its exact session", function()
    local c, state, env = View()
    env.DFRL.ResetMeterStats()
    assert(state.calls.create == 1, "production X deferred native checkpoint capture")
    assert(not c:Row(1):IsShown(), "production X left pre-reset rows visible")
    state.records[1].after, state.records[2].after = 20, 10
    state.context.asOfRunSeconds, state.context.counterRevision = 21, "counter-after-X"
    state.context.snapshotId = "snapshot-after-X"
    c:SetSetting("meterShowDamage", true)
    c:SetSetting("meterShowDps", false)
    c:Tick()
    assert(
        c:Row(1).value:GetText() == "20" and c:Row(2).value:GetText() == "10",
        "X did not use native post-checkpoint amounts"
    )
    state.context.languageCode, state.context.languageRevision = "ru", "language-ru"
    state.context.metadataRevision, state.records[1].name = "metadata-ru", "Укус"
    state.context.snapshotId = "snapshot-ru"
    env.DFRL.locale.code = "ru"
    c:NotifyLocale()
    c:Tick()
    assert(state.calls.create == 1 and state.queries[table.getn(state.queries)].checkpointId == "checkpoint-1")
    assert(
        c:Row(1).name:GetText() == "Укус (Hunter pet)" and c:Row(1).value:GetText() == "20",
        "language change rebased native reset counters"
    )
    state.createError = { code = "NOT_READY", message = "waiting", retryable = true, retryAfterSeconds = 0.2 }
    env.DFRL.ResetMeterStats()
    assert(c:Row(1):IsShown() and c:Row(1).value:GetText() == "20", "failed native X erased its prior valid session")
end)

Test("pet details and combined portraits share the existing visible and hidden lifecycle", function()
    for _, performance in ipairs({ false, true }) do
        local c, state = View(function(context, native)
            native.records = helpers.Pets()
            context.settings.performanceMode = performance
        end)
        assert(c:Row(1).name:GetText() == "Shadowbolt" and c:Row(2).name:GetText() == "Shadowbolt (Imp)")
        local allocated = #c.objects
        c:SetSetting("meterGroupPets", true)
        c:Tick()
        assert(c:Row(1).name:GetText() == "Imp" and c:Row(1).entry.dmg == 120 and c:Row(1).value:GetText() == "6")
        assert(
            c:Row(1).icon:GetTexture() == "Retained\\portrait-imp-1",
            "pet summary discarded retained native artwork"
        )
        assert(not c:Row(3):IsShown() and #c.objects == allocated, "pet grouping allocated replacement rows")
        c:ResetCounts()
        c:Tick()
        c:NoPresentationWrites()
        c:SetLayoutHidden(true)
        c:SetSetting("meterGroupPets", false)
        local reads, portraits = state.calls.snapshot, state.calls.portrait
        c:ResetCounts()
        c:Tick()
        assert(
            state.calls.snapshot == reads and state.calls.portrait == portraits,
            "hidden pet option read or rebound artwork"
        )
        c:NoPresentationWrites()
        c:SetLayoutHidden(false)
        c:Tick()
        assert(c:Row(1).name:GetText() == "Shadowbolt" and c:Row(2).name:GetText() == "Shadowbolt (Imp)")
        assert(c:Row(2).icon:GetTexture() == "Interface\\Icons\\shadowbolt" and #c.objects == allocated)
    end
end)

Test("party rows bind retained native portraits without a live roster", function()
    local c, state = View()
    state.records = {
        {
            id = "a",
            rowId = "a",
            name = "Ability",
            amount = 100,
            recent = 50,
            ownerId = "hero-1",
            heroName = "Same hero",
        },
        {
            id = "b",
            rowId = "b",
            name = "Ability",
            amount = 40,
            recent = 10,
            ownerId = "hero-2",
            heroName = "Same hero",
            class = "mage",
            departed = true,
        },
    }
    state.context.counterRevision, state.context.metadataRevision = "party-counter", "party-metadata"
    state.context.snapshotId = "party-snapshot"
    c:Cycle()
    c:Cycle()
    c:Cycle()
    assert(c:Row(1).name:GetText() == "Same hero" and c:Row(2).name:GetText() == "Same hero")
    assert(
        c:Row(1).icon:GetTexture() == "Retained\\portrait-hero-1",
        "first native hero portrait was replaced with an inferred unit"
    )
    assert(c:Row(2).icon:GetTexture() == "Retained\\portrait-hero-2", "departed native hero portrait was lost")
    local bindings = state.calls.portrait
    for _ = 1, 6 do
        c:Tick()
    end
    assert(state.calls.portrait == bindings, "unchanged retained native portraits repeated image binding")
end)

Test("pending native portraits retry on their native deadline and stable failures stay memoized", function()
    local c, state = View()
    state.records = { { id = "a", rowId = "a", name = "Ability", amount = 100, recent = 50, ownerId = "hero-1" } }
    state.context.counterRevision, state.context.metadataRevision = "party-pending", "party-pending-metadata"
    state.context.snapshotId = "party-pending-snapshot"
    state.portraitError = { code = "ART_NOT_READY", message = "waiting", retryable = true, retryAfterSeconds = 1 }
    c:Cycle()
    c:Cycle()
    c:Cycle()
    assert(state.calls.portrait == 1, "pending portrait was not attempted once on first native identity")
    c:Tick(0.21)
    c:Tick(0.21)
    assert(state.calls.portrait == 1, "pending portrait ignored its retry delay")
    state.portraitError = nil
    c:Tick(1.01)
    assert(
        state.calls.portrait == 2 and c:Row(1).icon:GetTexture() == "Retained\\portrait-hero-1",
        "native art did not recover after its retry deadline"
    )
    state.records[1].portraitKey = "unknown-portrait"
    state.context.metadataRevision = "unknown-portrait-metadata"
    state.context.snapshotId = "unknown-portrait-snapshot"
    state.portraitError = { code = "UNKNOWN_PORTRAIT", message = "unknown", retryable = false }
    c:Tick()
    local attempts = state.calls.portrait
    assert(
        c:Row(1).icon:GetTexture() == c.env.T.SourceIconFallback,
        "invalid native portrait retained another actor's image"
    )
    for _ = 1, 6 do
        c:Tick()
    end
    assert(state.calls.portrait == attempts, "stable native portrait failure retried every refresh")
    state.records[1].portraitKey = "replacement-portrait"
    state.context.metadataRevision, state.portraitError = "replacement-portrait-metadata", nil
    state.context.snapshotId = "replacement-portrait-snapshot"
    c:Tick()
    assert(
        state.calls.portrait == attempts + 1 and c:Row(1).icon:GetTexture() == "Retained\\replacement-portrait",
        "new retained portrait identity did not rearm native binding"
    )
end)

Test("upgrade cards hide the native meter without suspending recent rates or replacing checkpoints", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = View(function(context, native, boundary)
            context.settings.performanceMode = performance
            local factory = boundary.T.NewNativeMeter
            boundary.T.NewNativeMeter = function()
                local adapter = factory()
                local suspend = adapter.SuspendRecent
                adapter.SuspendRecent = function()
                    native.recentSuspends = (native.recentSuspends or 0) + 1
                    return suspend()
                end
                return adapter
            end
        end)
        env.DFRL.ResetMeterStats()
        -- Reset hides zero-contribution rows; publish real post-checkpoint damage first.
        state.records[1].after, state.records[2].after = 20, 10
        HistoryTick(c, state, "before-cards")
        local checkpoint = state.checkpoint.checkpointId
        local row, allocated = c:Row(1), #c.objects
        local amount, rate, icon = row.entry.dmg, row.entry.dps, row.icon:GetTexture()
        local reads, captures, suspends = state.calls.snapshot, state.calls.create, state.recentSuspends or 0
        state.context.phase = "choosing"
        c:Tick()
        assert(not c.root:IsShown() and not row:IsVisible() and row.entry.dmg == amount)
        c.root:Show()
        assert(not c.root:IsShown(), "another Show bypassed the native meter's card-choice hide")
        assert(row.icon:GetTexture() == icon and row.entry.dps == rate)
        assert(state.calls.snapshot == reads and state.calls.create == captures and not state.calls.release)
        assert((state.recentSuspends or 0) == suspends, "choice hide suspended native recent-rate samples")
        c:ResetCounts()
        for _ = 1, 3 do
            c:Tick()
        end
        c:NoPresentationWrites()
        assert(state.calls.snapshot == reads and #c.objects == allocated and c.nativeShown == false)
        state.context.phase = "playing"
        c:Tick()
        assert(c.root:IsVisible() and row.entry.dmg == amount and row.entry.dps == rate)
        assert(state.calls.create == captures and state.queries[table.getn(state.queries)].checkpointId == checkpoint)
        assert((state.recentSuspends or 0) == suspends and #c.objects == allocated)
        state.context.phase = "choosing"
        c:Tick()
        c:SetLayoutHidden(true)
        state.context.phase = "playing"
        c:Tick()
        assert(not c.root:IsVisible() and state.recentSuspends == suspends + 1)
        c:SetLayoutHidden(false)
        c:Tick()
        assert(c.root:IsVisible() and state.calls.create == captures)
        state.context.phase = "choosing"
        c:Tick()
        c:SetSetting("meterEnabled", false)
        state.context.phase = "playing"
        c:Tick()
        assert(not c.root:IsShown() and state.calls.release == 1 and not c.controller:GetScript("OnUpdate"))
    end
end)

Test("hidden and disabled native meter does not poll source snapshots or paint rows", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = View(function(context) context.settings.performanceMode = performance end)
        env.DFRL.ResetMeterStats()
        c:Tick()
        c:SetLayoutHidden(true)
        local reads, portraits = state.calls.snapshot, state.calls.portrait
        c:ResetCounts()
        for _ = 1, 6 do
            c:Tick()
        end
        assert(
            state.calls.snapshot == reads and state.calls.portrait == portraits,
            "hidden native view continued source/art collection"
        )
        c:NoPresentationWrites()
        local contexts = state.calls.context
        c:SetLayoutHidden(false)
        assert(state.calls.context == contexts, "show read native context synchronously")
        c:Tick(0.01)
        assert(state.calls.context == contexts + 1, "native view did not request fresh context when shown")
        assert(state.calls.snapshot == reads, "unchanged native context fetched a replacement snapshot")
        assert(c.root:IsVisible(), "unchanged native capture did not restore the view")

        c:SetLayoutHidden(true)
        state.records[1].after, state.records[2].after = 20, 10
        c:ResetCounts()
        HistoryTick(c, state, "hidden-post-reset")
        assert(
            state.calls.snapshot == reads and state.calls.portrait == portraits,
            "hidden native publication fetched source data or artwork"
        )
        c:NoPresentationWrites()
        contexts = state.calls.context
        c:SetLayoutHidden(false)
        assert(state.calls.snapshot == reads, "show fetched the changed native snapshot synchronously")
        c:Tick(0.01)
        assert(
            state.calls.context == contexts + 1 and state.calls.snapshot == reads + 1,
            "native view did not fetch the changed publication on the next frame"
        )
        assert(c:Row(1):IsShown() and c:Row(1).entry.dmg == 20 and c:Row(2).entry.dmg == 10)
        c:SetSetting("meterEnabled", false)
        assert(
            not c.root:IsVisible() and state.calls.release == 1,
            "disable did not retire the consumer-owned native checkpoint"
        )
        reads, portraits = state.calls.snapshot, state.calls.portrait
        contexts = state.calls.context
        for _ = 1, 6 do
            c:Tick()
        end
        assert(
            state.calls.snapshot == reads and state.calls.context == contexts and state.calls.portrait == portraits,
            "disabled native meter kept a collector running"
        )
    end
end)

Test("native recent warmup displays unavailable rate text while keeping source amounts", function()
    local c, state = View()
    state.context.asOfRunSeconds, state.context.encounter = 0.5, nil
    state.context.counterEpoch = "warmup-epoch"
    state.context.counterRevision = "native-warmup"
    state.context.snapshotId = "native-warmup-snapshot"
    state.recentStatus = "warming_up"
    c:Tick(1.01)
    assert(
        c:Row(1):IsShown() and c:Row(1).value:GetText() == "--",
        "native warmup was replaced with a local DPS calculation"
    )
    c:SetSetting("meterShowDamage", true)
    c:Tick()
    assert(c:Row(1).value:GetText() == "100   --", "native warmup erased valid native damage")
end)

Test("unready publications and invalid reset epochs clear native rows without replay", function()
    local c, state, env = View()
    state.context.snapshotId = "unready-snapshot"
    state.snapshotError = { code = "NOT_READY", message = "waiting", retryable = true, retryAfterSeconds = 0.2 }
    c:Tick()
    assert(not c:Row(1):IsShown(), "unready native publication left the previous source row visible")
    state.snapshotError = nil
    c:Tick()
    assert(c:Row(1):IsShown(), "coherent native publication did not recover the meter")
    env.DFRL.ResetMeterStats()
    state.records[1].after, state.records[2].after = 20, 10
    state.context.asOfRunSeconds, state.context.counterRevision = 21, "post-reset"
    state.context.snapshotId = "post-reset-snapshot"
    c:Tick()
    assert(c:Row(1):IsShown(), "post-checkpoint native amounts were not shown")
    state.context.counterEpoch = "corrected-epoch"
    state.context.snapshotId = "corrected-snapshot"
    c:Tick()
    assert(not c:Row(1):IsShown(), "counter correction replayed pre-checkpoint damage")
    c:Tick()
    assert(not c:Row(1):IsShown(), "a later refresh silently removed the invalid native reset fence")
end)

Test("native meter keeps four views despite damage-taken publications in both Performance Mode states", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = View(function(context, _, boundaries)
            context.settings.performanceMode = performance
            boundaries.AZS_RUN, boundaries.AZS_RUN_UPDATED = { t = 20, taken = 100 }, context.now
            boundaries.AZS_TAKEN = {
                setmetatable({}, {
                    __index = function() error("native meter read removed legacy damage-taken categories") end,
                }),
            }
            boundaries.AZS_TAKEN_UPDATED = context.now
        end)
        assert(not c.controller.events.CHAT_MSG_ADDON, "native meter retained legacy packet intake")
        assert(c.title:GetText() == "Damage Done")
        local expected = { "Healing Done", "Boss Damage", "Party Damage", "Damage Done" }
        for _, title in ipairs(expected) do
            env.AZS_TAKEN_UPDATED = c.now
            c:Cycle()
            assert(c.title:GetText() == title, "published damage taken changed the native meter cycle")
        end
        expected = { "Party Damage", "Boss Damage", "Healing Done", "Damage Done" }
        for _, title in ipairs(expected) do
            c:Cycle("RightButton")
            assert(c.title:GetText() == title, "reverse native cycle left the four supported views")
        end
        for _, query in ipairs(state.queries) do
            assert(query.metric == "damage" or query.metric == "healing", "removed view invented a native metric")
        end
        assert(env.AZS_RUN.taken == 100, "native meter rewrote incoming counters")
    end
end)

Test("item rank upgrades reuse native artwork and hidden lifecycle in both Performance Mode states", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = View(function(context, native)
            context.settings.performanceMode = performance
            native.records = helpers.ItemRanks(3)
        end)
        local first, allocated = c:Row(1), #c.objects
        local identity = first.entry.rowId
        assert(first.name:GetText() == "The Eye of Hakkar 3" and first.entry.dmg == 60)
        assert(first.icon:GetTexture() == "Interface\\Icons\\hakkar-rank-3")
        assert(not env.SurvivorsDragonUiMeterIcon2, "item ranks allocated extra displayed rows")
        c:ResetCounts()
        c:Tick()
        c:NoPresentationWrites()
        assert(#c.objects == allocated, "unchanged item summaries grew the artwork pool")
        c:SetLayoutHidden(true)
        state.records = helpers.ItemRanks(4)
        state.context.counterRevision = "hidden-item-upgrade"
        local snapshots = state.calls.snapshot
        c:ResetCounts()
        for _ = 1, 5 do
            c:Tick()
        end
        assert(state.calls.snapshot == snapshots, "hidden item summaries fetched native data")
        c:NoPresentationWrites()
        c:SetLayoutHidden(false)
        c:Tick()
        assert(
            first.entry.rowId == identity and first.entry.dmg == 100 and first.name:GetText() == "The Eye of Hakkar 4"
        )
        assert(first.icon:GetTexture() == "Interface\\Icons\\hakkar-rank-4" and #c.objects == allocated)
        c:SetSetting("meterEnabled", false)
        snapshots = state.calls.snapshot
        c:ResetCounts()
        c:Tick()
        assert(state.calls.snapshot == snapshots and not c.controller:GetScript("OnUpdate"))
        c:NoPresentationWrites()
    end
end)

Test("native upgraded ranks reuse one displayed ability in both Performance Mode states", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = View(function(context, native)
            context.settings.performanceMode = performance
            native.records = helpers.Ranks(9)
        end)
        local first, allocated = c:Row(1), #c.objects
        local identity = first.entry.rowId
        assert(first.name:GetText() == "Flamestrike" and first.entry.dmg == 450 and first.entry.dps == 9)
        assert(not env.SurvivorsDragonUiMeterIcon2, "rank variants allocated extra visible rows")
        c:ResetCounts()
        c:Tick()
        c:NoPresentationWrites()
        assert(#c.objects == allocated, "unchanged rank groups grew the artwork pool")
        state.records = helpers.Ranks(10)
        state.context.snapshotId, state.context.counterRevision = "visible-rank-ten", "visible-rank-ten"
        c:Tick()
        for _ = 1, 5 do
            c:Tick()
        end
        assert(first.entry.dmg == 550 and first.entry.dps == 11 and first.entry.rowId == identity)
        assert(first.icon:GetTexture() == "Interface\\Icons\\flamestrike-rank-10")
        assert(#c.objects == allocated, "upgrade added a tracker instead of updating its existing row")
        for _, record in ipairs(state.records) do
            record.name = "Flammenstoß"
        end
        state.context.languageCode, state.context.languageRevision = "de", "visible-rank-de"
        state.context.metadataRevision, state.context.snapshotId = "visible-rank-meta-de", "visible-rank-de"
        c:NotifyLocale()
        c:Tick()
        assert(first.name:GetText() == "Flammenstoß" and first.entry.rowId == identity and first.entry.dmg == 550)
        c:SetLayoutHidden(true)
        state.records = helpers.Ranks(11)
        state.context.snapshotId, state.context.counterRevision = "hidden-rank-eleven", "hidden-rank-eleven"
        local snapshots = state.calls.snapshot
        c:ResetCounts()
        for _ = 1, 5 do
            c:Tick()
        end
        assert(state.calls.snapshot == snapshots, "hidden rank groups still fetched native rows")
        c:NoPresentationWrites()
        c:SetLayoutHidden(false)
        c:Tick()
        assert(first.entry.dmg == 660 and first.entry.rowId == identity and #c.objects == allocated)
        c:SetSetting("meterEnabled", false)
        snapshots = state.calls.snapshot
        c:ResetCounts()
        c:Tick()
        assert(state.calls.snapshot == snapshots and not c.controller:GetScript("OnUpdate"))
        c:NoPresentationWrites()
    end
end)
