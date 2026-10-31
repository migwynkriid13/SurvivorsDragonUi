-- CI only: the full production meter using native v1 snapshots and retained artwork.
local helpers = assert(loadfile("scripts/tests/fixtures/ui_native_meter_api_spec.lua"))("helpers")
assert(_VERSION == "Lua 5.1", "native meter view fixtures require CI Lua 5.1")
local helperMode = ...

local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    print("PASS " .. name)
end

local function View(options)
    local c, state, _, env = helpers.New()
    local function Count(name) c.reads[name] = (c.reads[name] or 0) + 1 end
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        local setFont, setColor, setOffset = object.SetFont, object.SetShadowColor, object.SetShadowOffset
        function object:SetFont(face, size, flags)
            self.fontAttempts = (self.fontAttempts or 0) + 1
            if c.failFontObject == self and c.failFontSize == size then return false end
            return setFont(self, face, size, flags)
        end
        function object:SetShadowColor(...)
            self.shadowColor = { ... }
            setColor(self, ...)
        end
        function object:SetShadowOffset(...)
            self.shadowOffset = { ... }
            setOffset(self, ...)
        end
        function object:GetStringWidth()
            Count("metrics")
            self.measuredText = self:GetText()
            if c.metricMissing then return nil end
            if c.metricOverride ~= nil then return c.metricOverride end
            local _, size = self:GetFont()
            return string.len(self:GetText()) * 4 * (size or 11) / 11
        end
        function object:GetEffectiveScale()
            return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        function object:SetScale(value) self.scale = value end
        function object:SetMinMaxValues(low, high)
            self.minimum, self.maximum = low, high
        end
        function object:SetValue(value) self.value = value end
        function object:SetStatusBarTexture(path)
            self.barTexture = path
            return true
        end
        function object:SetStatusBarColor(...) self.color = { ... } end
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
    local register = env.DFRL.layout.Register
    env.DFRL.layout.Register = function(name, frame, anchor, settings)
        c.layoutOptions = settings
        register(name, frame, anchor)
    end
    env.UnitClass = function(unit)
        assert(unit == "player", "native meter read the current party roster for historical class metadata")
        return "Hunter", "HUNTER"
    end
    local function Forbidden()
        state.calls.legacy = (state.calls.legacy or 0) + 1
        error("native meter used a removed counter, roster, phase or artwork fallback")
    end
    for _, name in ipairs({
        "AZS_GetMeter",
        "AZS_GetHealing",
        "AZS_GetBossMeter",
        "AZS_GetPartyMeter",
        "AZS_GetRunTime",
        "AZS_GetPhase",
        "UnitExists",
        "UnitName",
        "SetPortraitTexture",
    }) do
        env[name] = Forbidden
    end
    env.DFRL.sct = { GetSourceIcon = Forbidden }
    env.SetPortraitToTexture = function(name, path)
        local texture = assert(env[name], "native circle binding used an unknown texture name")
        texture:SetTexture(path)
    end
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
    if options and options.configure then options.configure(c, state, env) end
    c:Load("core/hud.lua")
    c:Load("core/widgets.lua")
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
        local step = elapsed or 0.21
        self.now = self.now + step
        self:Call(self.controller, "OnUpdate", step)
    end
    function c:Cycle(direction)
        self:Call(self.header, "OnClick", direction or "LeftButton")
        self:Tick()
    end
    function c:Row(index) return assert(env["SurvivorsDragonUiMeterIcon" .. index]):GetParent() end
    function c:Resize(width)
        self.root:SetWidth(width)
        self.layoutOptions.onResize(self.root)
        self:Tick()
    end
    if not options or options.start ~= false then c:Tick() end
    return c, state, env
end

if helperMode == "helpers" then return { New = View, Error = helpers.Error } end

Test("missing or partial native APIs retain the game HUD and never use legacy fallbacks", function()
    for _, missing in ipairs({ "AZS_GetMeterCapabilities", "AZS_GetMeterSnapshot", "AZS_SetMeterPortrait" }) do
        local restore
        local c, state, env = View({
            configure = function(_, _, globals)
                restore, globals[missing] = globals[missing], nil
            end,
        })
        assert(not c.root:IsVisible() and c.nativeShown, "incomplete API suppressed the game meter")
        assert(not state.calls.snapshot and not state.calls.legacy, "incomplete API used a removed fallback")
        env[missing] = restore
        c:Tick()
        assert(c.root:IsVisible() and not c.nativeShown, "complete native API did not recover its custom view")
        local getContext = env.AZS_GetMeterContext
        env.AZS_GetMeterContext = nil
        c:Tick()
        assert(not c.root:IsVisible() and c.nativeShown, "lost native context did not restore the game HUD")
        assert(not state.calls.legacy, "API loss queried old counters, roster names or spell artwork")
        env.AZS_GetMeterContext = getContext
    end
end)

Test("hidden endpoint loss releases a warmed native meter until visible recovery", function()
    for _, missing in ipairs({ "AZS_GetMeterSnapshot", "AZS_SetMeterPortrait" }) do
        local c, state, env = View()
        assert(c.root:IsVisible() and not c.nativeShown)
        c:SetLayoutHidden(true)
        local snapshots, endpoint = state.calls.snapshot, env[missing]
        env[missing] = nil
        c:Tick()
        assert(state.calls.snapshot == snapshots, "hidden endpoint loss collected source snapshots")
        assert(c.nativeShown and not c:Row(1).active, "cached capabilities retained an incomplete takeover")
        env[missing] = endpoint
        c:SetLayoutHidden(false)
        c:Tick()
        assert(state.calls.snapshot > snapshots and c:Row(1).active and not c.nativeShown)
        assert(not state.calls.legacy, "native endpoint recovery used a removed fallback")
    end
end)

Test("disabled native meter reads nothing and enabling needs no legacy publication", function()
    local c, state = View({ configure = function(context) context.settings.meterEnabled = false end })
    assert(next(state.calls) == nil and c.nativeShown, "disabled initialization read the native API")
    c:Tick()
    assert(next(state.calls) == nil, "disabled meter retained an API collector")
    c:SetSetting("meterEnabled", true)
    c:Tick()
    assert(c.root:IsVisible() and state.calls.snapshot and not c.nativeShown)
    assert(not c.controller.events.CHAT_MSG_ADDON and not state.calls.legacy)
    c:SetSetting("meterEnabled", false)
    local contexts, snapshots = state.calls.context, state.calls.snapshot
    for _ = 1, 6 do
        c:Tick()
    end
    assert(state.calls.context == contexts and state.calls.snapshot == snapshots and c.nativeShown)
end)

Test("native context readiness honors retry delay and recovers without old meter data", function()
    local c, state = View({
        configure = function(_, native)
            native.contextError = { code = "NOT_READY", message = "waiting", retryable = true, retryAfterSeconds = 1 }
        end,
    })
    assert(not c.root:IsVisible() and c.nativeShown and not state.calls.snapshot)
    local contexts = state.calls.context
    c:Tick()
    c:Tick()
    assert(state.calls.context == contexts, "unready context ignored the native retry delay")
    state.contextError = nil
    c:Tick(1.01)
    assert(c.root:IsVisible() and c:Row(1).active and not c.nativeShown)
    assert(not state.calls.legacy, "readiness recovery used legacy counters")
end)

Test("initial Layout hiding defers even dirty native snapshots until Show", function()
    local c, state = View({
        configure = function(context, _, env)
            local register = env.DFRL.layout.Register
            env.DFRL.layout.Register = function(...)
                register(...)
                context.layoutMask:Hide()
            end
        end,
    })
    assert(state.calls.context and not state.calls.snapshot and not state.calls.portrait)
    assert(c.nativeShown, "unprepared hidden replacement captured the game meter")
    c:SetLayoutHidden(false)
    c:Tick()
    assert(state.calls.snapshot and c:Row(1).active and not c.nativeShown)
end)

Test("native IDs keep different rates for equal source names and bypass guessed artwork", function()
    local c = View()
    assert(c.root:IsVisible(), "native meter did not become ready without legacy publication packets")
    local first, second = c:Row(1), c:Row(2)
    assert(first.name:GetText() == "Same name" and second.name:GetText() == "Same name")
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
        assert(c:Row(1).name:GetText() == helpers.labels[index], "production view rewrote a native localized ability")
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
    assert(row.name:GetText() == "Updated native ability", "metadata-only publication retained the old ability label")
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
        c:Row(1).name:GetText() == "Укус" and c:Row(1).value:GetText() == "20",
        "language change rebased native reset counters"
    )
    state.createError = { code = "NOT_READY", message = "waiting", retryable = true, retryAfterSeconds = 0.2 }
    env.DFRL.ResetMeterStats()
    assert(c:Row(1):IsShown() and c:Row(1).value:GetText() == "20", "failed native X erased its prior valid session")
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
    c:Tick()
    c:Tick()
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

Test("hidden and disabled native meter does not poll source snapshots or paint rows", function()
    local c, state, env = View()
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
    c:SetLayoutHidden(false)
    c:Tick()
    assert(state.calls.snapshot > reads, "native view did not request current state when shown")
    c:SetSetting("meterEnabled", false)
    assert(
        not c.root:IsVisible() and state.calls.release == 1,
        "disable did not retire the consumer-owned native checkpoint"
    )
    reads, portraits = state.calls.snapshot, state.calls.portrait
    local contexts = state.calls.context
    for _ = 1, 6 do
        c:Tick()
    end
    assert(
        state.calls.snapshot == reads and state.calls.context == contexts and state.calls.portrait == portraits,
        "disabled native meter kept a collector running"
    )
end)

Test("a hidden native run change releases takeover until fresh visible rows are accepted", function()
    local c, state = View()
    assert(c.root:IsVisible() and c:Row(1).active and not c.nativeShown)
    c:SetLayoutHidden(true)
    local snapshots = state.calls.snapshot
    state.context.runId, state.context.counterEpoch = "run-2", "epoch-run-2"
    state.context.snapshotId, state.context.counterRevision = "snapshot-run-2", "counter-run-2"
    state.context.metadataRevision, state.context.encounter = "metadata-run-2", nil
    state.records = { { id = "new-source", rowId = "new-leaf", name = "New run ability", amount = 80, recent = 40 } }
    c:Tick()
    assert(state.calls.snapshot == snapshots, "hidden run retirement collected new source snapshots")
    assert(c.nativeShown and not c:Row(1).active, "old-run readiness kept the native meter suppressed")
    c:SetLayoutHidden(false)
    c:Tick()
    assert(state.calls.snapshot > snapshots and c:Row(1).active and not c.nativeShown)
    assert(
        c:Row(1).entry.rowId == "group-new-leaf" and c:Row(1).name:GetText() == "New run ability",
        "visible takeover accepted a retired run's rows"
    )
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
