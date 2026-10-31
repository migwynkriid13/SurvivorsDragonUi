-- CI only: the full production meter using native v1 snapshots and retained artwork.
local helpers = assert(loadfile("scripts/tests/fixtures/ui_native_meter_api_spec.lua"))("helpers")
assert(_VERSION == "Lua 5.1", "native meter view fixtures require CI Lua 5.1")

local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    print("PASS " .. name)
end

local function View()
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
    c:Load("core/hud.lua")
    c:Load("core/meter_rates.lua")
    c:Load("core/widgets.lua")
    c:Load("modules/ui/meter.lua", "DamageMeter")
    c.root, c.controller = env.DFRL_DamageMeter, c:Controller("PLAYER_ENTERING_WORLD")
    for _, object in ipairs(c.objects) do
        if object.kind == "Button" and object.parent == c.root then c.header = object end
    end
    function c:Tick(elapsed)
        local step = elapsed or 0.21
        self.now = self.now + step
        self:Call(self.controller, "OnUpdate", step)
    end
    function c:Cycle()
        self:Call(self.header, "OnClick", "LeftButton")
        self:Tick()
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
    for index, language in ipairs(helpers.languages) do
        state.context.languageCode, state.context.languageRevision = language, "language-" .. index
        state.context.metadataRevision = "metadata-" .. index
        state.records[1].name, state.records[2].name = helpers.labels[index], "123"
        c.env.DFRL.locale.code = language
        c:NotifyLocale()
        c:Tick()
        assert(c:Row(1).name:GetText() == helpers.labels[index], "production view rewrote a native localized ability")
        assert(c:Row(2).name:GetText() == "123", "production view coerced a numeric-looking ability name")
    end
end)

Test("native X captures at the click and language changes preserve its exact session", function()
    local c, state, env = View()
    env.DFRL.ResetMeterStats()
    assert(state.calls.create == 1, "production X deferred native checkpoint capture")
    assert(not c:Row(1):IsShown(), "production X left pre-reset rows visible")
    state.records[1].after, state.records[2].after = 20, 10
    state.context.asOfRunSeconds, state.context.counterRevision = 21, "counter-after-X"
    c:SetSetting("meterShowDamage", true)
    c:SetSetting("meterShowDps", false)
    c:Tick()
    assert(
        c:Row(1).value:GetText() == "20" and c:Row(2).value:GetText() == "10",
        "X did not use native post-checkpoint amounts"
    )
    state.context.languageCode, state.context.languageRevision = "ru", "language-ru"
    state.context.metadataRevision, state.records[1].name = "metadata-ru", "Укус"
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
    state.context.counterRevision = "party-counter"
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
    state.context.counterRevision = "party-pending"
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
    c:Tick()
    assert(c:Row(1):IsShown(), "post-checkpoint native amounts were not shown")
    state.context.counterEpoch = "corrected-epoch"
    c:Tick()
    assert(not c:Row(1):IsShown(), "counter correction replayed pre-checkpoint damage")
    c:Tick()
    assert(not c:Row(1):IsShown(), "a later refresh silently removed the invalid native reset fence")
end)
