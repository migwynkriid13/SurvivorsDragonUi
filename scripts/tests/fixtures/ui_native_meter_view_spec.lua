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
    local create = c.Object
    function c:Object(...)
        local object = create(self, ...)
        function object:GetStringWidth() return string.len(self:GetText()) * 4 end
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
    function c:PublishTaken(stamp)
        env.AZS_TAKEN_UPDATED = stamp or self.now
        self:Event(self.controller, "CHAT_MSG_ADDON", "AZSTAKEN")
    end
    function c:Row(index) return assert(env["SurvivorsDragonUiMeterIcon" .. index]):GetParent() end
    c:Tick()
    return c, state, env
end

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

local function TakenView(performance)
    local c, state, env = View(function(context, _, boundaries)
        context.settings.performanceMode = performance == true
        boundaries.AZS_RUN, boundaries.AZS_RUN_UPDATED = { t = 20, taken = 100 }, context.now
        boundaries.AZS_TAKEN = { { source = "boss spell", dmg = 100 } }
        boundaries.AZS_TAKEN_UPDATED = context.now
        boundaries.ReloadUI = function() context.reloaded = true end
        local snapshot = boundaries.AZS_GetMeterSnapshot
        boundaries.AZS_GetMeterSnapshot = function(query)
            assert(
                query.metric == "damage" or query.metric == "healing",
                "Taken invented an unsupported native-v1 metric"
            )
            return snapshot(query)
        end
    end)
    c:Cycle("RightButton")
    assert(c.title:GetText() == "Damage Taken" and c:Row(1).entry.name == "Boss spells")
    return c, state, env
end

Test("native four-view clients retain their original cycle when Taken is absent", function()
    local c, state, env = View()
    assert(env.AZS_TAKEN == nil)
    local expected = { "Healing Done", "Boss Damage", "Party Damage", "Damage Done" }
    for _, title in ipairs(expected) do
        c:Cycle()
        assert(c.title:GetText() == title, "absent Taken changed the existing native-v1 cycle")
    end
    c:Cycle("RightButton")
    assert(c.title:GetText() == "Party Damage", "absent Taken introduced a blank reverse page")
    for _, query in ipairs(state.queries) do
        assert(query.metric == "damage" or query.metric == "healing")
    end
end)

Test("Taken uses official category packets alongside the unchanged native four views", function()
    local c, state, env = TakenView()
    assert(c.controller.events.CHAT_MSG_ADDON, "native-v1 selection detached Taken publication delivery")
    assert(c:Row(1).entry.dmg == 100 and c:Row(1).entry.dps == 5)
    assert(c:Row(1).icon:GetTexture() == env.T.SourceIconFallback, "Taken used retained hero or guessed spell art")
    local snapshots = state.calls.snapshot
    env.AZS_TAKEN[1].dmg, env.AZS_RUN.taken = 130, 130
    c:PublishTaken(env.AZS_TAKEN_UPDATED)
    c:Tick()
    assert(c:Row(1).entry.dmg == 130, "same-stamp Taken packet was ignored with v1 available")
    assert(state.calls.snapshot == snapshots, "selected Taken queried an outgoing v1 snapshot")
    c:Cycle()
    assert(c.title:GetText() == "Damage Done" and c:Row(1).entry.rowId, "Taken replaced native outgoing data")
    c:Cycle()
    assert(c.title:GetText() == "Healing Done" and c:Row(1).entry.rowId)
    c:Cycle()
    assert(c.title:GetText() == "Boss Damage" and c:Row(1).entry.rowId)
    c:Cycle()
    assert(c.title:GetText() == "Party Damage" and c:Row(1).entry.portraitRunId == state.context.runId)
    c:Cycle()
    assert(c.title:GetText() == "Damage Taken" and not c:Row(1).entry.rowId)
end)

Test("native checkpoint Reset and Taken share success while failure preserves both sessions", function()
    local c, state, env = TakenView()
    env.DFRL.ResetMeterStats()
    assert(state.calls.create == 1 and not c:Row(1).active)
    c:Tick()
    assert(not c:Row(1).active, "native checkpoint Reset replayed pre-reset Taken")
    state.context.asOfRunSeconds = 22
    state.context.snapshotId, state.context.counterRevision = "taken-after-X", "taken-after-X"
    env.AZS_TAKEN[1].dmg, env.AZS_RUN.taken, env.AZS_RUN.t = 130, 130, 22
    c:PublishTaken()
    c:Tick()
    assert(c:Row(1).entry.dmg == 30 and c:Row(1).entry.dps == 15, "Taken did not retain its shared X baseline")
    state.createError = { code = "NOT_READY", message = "waiting", retryable = true, retryAfterSeconds = 0.2 }
    env.DFRL.ResetMeterStats()
    assert(c:Row(1).active and c:Row(1).entry.dmg == 30, "failed native X cleared the previous Taken session")
    state.context.asOfRunSeconds = 24
    env.AZS_TAKEN[1].dmg, env.AZS_RUN.taken, env.AZS_RUN.t = 140, 140, 24
    c:PublishTaken()
    c:Tick()
    assert(c:Row(1).entry.dmg == 40, "failed checkpoint capture silently rebased Taken")
    state.records[1].after, state.records[2].after = 20, 10
    c:Cycle()
    assert(c:Row(1).entry.dmg == 20, "Taken Reset discarded the still-active native checkpoint")
    assert(state.queries[table.getn(state.queries)].checkpointId == "checkpoint-1")
end)

Test("native run and epoch retirement block old Taken until a fresh packet", function()
    local c, state, env = TakenView()
    state.context.counterEpoch, state.context.snapshotId = "new-taken-epoch", "new-taken-epoch"
    c:Tick()
    assert(c.title:GetText() ~= "Damage Taken", "new native epoch accepted stale Taken")
    c:PublishTaken()
    c:Cycle("RightButton")
    assert(c.title:GetText() == "Damage Taken" and c:Row(1).entry.dmg == 100)
    state.context.runId, state.context.snapshotId = "new-taken-run", "new-taken-run"
    c:Tick()
    assert(c.title:GetText() ~= "Damage Taken", "new native run accepted the last run's Taken categories")
    c:PublishTaken()
    c:Cycle("RightButton")
    assert(c.title:GetText() == "Damage Taken")
    c:Event(c.controller, "PLAYER_LEAVING_WORLD")
    c:Event(c.controller, "PLAYER_ENTERING_WORLD")
    c:Tick()
    assert(c.title:GetText() ~= "Damage Taken", "native world entry replayed old Taken")
    assert(env.AZS_TAKEN[1].dmg == 100, "Taken retirement altered native category counters")
end)

Test("mixed meter reload releases its checkpoint and Taken listener together", function()
    local c, state, env = TakenView()
    env.DFRL.ResetMeterStats()
    c:Tick()
    env.ReloadUI()
    assert(c.reloaded and state.calls.release == 1 and not c:Row(1).active)
    assert(not c.controller:GetScript("OnUpdate") and not c.controller.events.CHAT_MSG_ADDON)
    assert(env.AZS_TAKEN[1].dmg == 100 and env.AZS_RUN.taken == 100)
end)

Test("mixed native and Taken hidden views defer category work in both Performance Mode states", function()
    for _, performance in ipairs({ false, true }) do
        local c, state, env = TakenView(performance)
        local allocated = #c.objects
        c:SetLayoutHidden(true)
        env.AZS_TAKEN = {
            setmetatable({}, {
                __index = function(_, key)
                    if key == "source" or key == "dmg" then state.takenReads = (state.takenReads or 0) + 1 end
                    return key == "source" and "boss spell" or key == "dmg" and 150 or nil
                end,
            }),
        }
        env.AZS_RUN.taken = 150
        c:PublishTaken()
        local snapshots = state.calls.snapshot
        c:ResetCounts()
        for _ = 1, 6 do
            c:Tick()
        end
        assert(not state.takenReads and state.calls.snapshot == snapshots, "hidden Taken read category or v1 rows")
        c:NoPresentationWrites()
        c:SetLayoutHidden(false)
        c:Tick()
        assert(c:Row(1).entry.dmg == 150 and #c.objects == allocated, "Taken Show failed to refresh its existing pool")
        local reads = state.takenReads
        c:SetSetting("meterEnabled", false)
        c:ResetCounts()
        for _ = 1, 6 do
            c:Tick()
        end
        assert(state.takenReads == reads and not c.controller:GetScript("OnUpdate"))
        assert(not c.controller.events.CHAT_MSG_ADDON, "disabled mixed meter retained Taken intake")
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
