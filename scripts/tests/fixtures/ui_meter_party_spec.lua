-- CI only: the production meter/session over explicit fake native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "party meter fixtures require the CI Lua 5.1 interpreter")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Meter()
    local context = H.New()
    local env = context.env
    local function Count(kind, name)
        local counts = context[kind]
        counts[name] = (counts[name] or 0) + 1
    end
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        function object:GetEffectiveScale()
            return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        function object:SetScale(scale)
            Count("writes", "SetScale")
            self.scale = scale
        end
        function object:SetMinMaxValues(low, high)
            self.minimum, self.maximum = low, high
        end
        function object:SetValue(value)
            Count("writes", "SetValue")
            self.value = value
        end
        function object:SetStatusBarTexture(texture)
            self.barTexture = texture
            return true
        end
        function object:SetStatusBarColor(...)
            Count("writes", "SetStatusBarColor")
            self.color = { ... }
        end
        function object:RegisterForClicks(...) self.clicks = { ... } end
        function object:EnableMouseWheel(enabled) self.mouseWheel = enabled end
        function object:SetBlendMode(mode) self.blend = mode end
        for _, state in ipairs({ "Normal", "Pushed", "Highlight" }) do
            local key = state
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
    env.DFRL.locale.code = "en"
    env.T.SourceIconFallback = "Interface\\Icons\\INV_Misc_QuestionMark"
    env.T.SetChatShadow = function(label)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
    end
    env.DFRL.layout.IsHidden = function() return not context.layoutMask:IsShown() end
    env.DFRL.layout.Place = function() end
    context.settings = {
        meterEnabled = true,
        meterRows = 6,
        meterFontSize = 11,
        meterDpsWindow = 10,
        meterShowDamage = true,
        meterShowDps = true,
        meterShowPercentage = false,
        meterShowIcons = true,
        meterShowRanks = false,
        meterShowTotal = false,
        meterShowTotalDps = false,
    }
    context.phase = "playing"
    context.units = {
        player = { name = "Me", class = "ROGUE", texture = "Portraits\\Me" },
        party1 = { name = "Friend", class = "MAGE", texture = "Portraits\\Friend" },
    }
    env.PlayerFrame = env.CreateFrame("Frame", "PlayerFrame", env.UIParent)
    env.PlayerFrame.portrait = env.PlayerFrame:CreateTexture("PlayerPortrait", "ARTWORK")
    env.PlayerFrame.portrait:SetTexture(context.units.player.texture)
    for index = 1, 4 do
        local portrait = env.UIParent:CreateTexture("PartyMemberFrame" .. index .. "Portrait", "ARTWORK")
        if index == 1 then portrait:SetTexture(context.units.party1.texture) end
    end
    env.UnitExists = function(unit) return context.units[unit] ~= nil end
    env.UnitName = function(unit)
        Count("reads", "names")
        return context.units[unit].name
    end
    env.UnitClass = function(unit) return "localized", context.units[unit] and context.units[unit].class end
    env.SetPortraitTexture = function(name, unit)
        Count("reads", "portraits")
        if context.failPortrait then return false end
        assert(context.units[unit], "portrait requested for a missing native unit")
        env[name]:SetTexture(context.units[unit].texture)
        return true
    end
    env.SetPortraitToTexture = function(name, texture) env[name]:SetTexture(texture) end
    env.AZS_GetPhase = function() return context.phase end
    env.AZS_RUN, env.AZS_RUN_UPDATED = { t = 10 }, context.now
    context.damage = { { name = "Sinister Strike", dmg = 100, dps = 10, share = 1, proc = 0 } }
    context.healing, context.boss = context.damage, context.damage
    context.party = {
        { name = "Friend", class = "mage", dmg = 200, dps = 20, share = 2 / 3 },
        { name = "Me", class = "rogue", dmg = 100, dps = 10, share = 1 / 3 },
    }
    local function Totals(source)
        local total, rate = 0, 0
        for _, line in ipairs(source) do
            total, rate = total + line.dmg, rate + line.dps
        end
        return source, total, rate
    end
    env.AZS_GetMeter = function()
        Count("reads", "damage")
        local source, total = Totals(context.damage)
        return source, total, total / math.max(1, env.AZS_RUN.t)
    end
    env.AZS_GetHealing = function() return Totals(context.healing) end
    env.AZS_GetBossMeter = function() return Totals(context.boss) end
    env.AZS_GetPartyMeter = function()
        Count("reads", "party")
        return Totals(context.party)
    end
    local stamps = {
        AZSMETER = "AZS_METER_UPDATED",
        AZSHEAL = "AZS_HEALING_UPDATED",
        AZSBOSSDMG = "AZS_BOSSMETER_UPDATED",
        AZSPARTY = "AZS_PARTY_UPDATED",
    }
    for _, name in pairs(stamps) do
        env[name] = context.now
    end
    env.DFRL.sct = {
        GetSourceIcon = function()
            Count("reads", "spells")
            return env.T.SourceIconFallback
        end,
    }
    context:Load("core/hud.lua")
    context:Load("core/meter_rates.lua")
    context:Load("modules/ui/meter.lua", "DamageMeter")
    context.controller = context:Controller("CHAT_MSG_ADDON")
    context.root = env.DFRL_DamageMeter
    for _, object in ipairs(context.objects) do
        if object.kind == "Button" and object.parent == context.root then context.header = object end
    end
    for _, object in ipairs(context.objects) do
        if object.kind == "FontString" and object.parent == context.header then context.title = object end
    end
    function context:Tick()
        self.now = self.now + 0.21
        self:Call(self.controller, "OnUpdate", 0.21)
    end
    function context:Cycle(direction)
        self:Call(self.header, "OnClick", direction or "LeftButton")
        self:Tick()
    end
    function context:Publish(prefix, stamp)
        env[stamps[prefix]] = stamp or self.now
        self:Event(self.controller, "CHAT_MSG_ADDON", prefix)
    end
    function context:WatchCounters(line)
        return setmetatable({}, {
            __index = function(_, key)
                if key == "name" or key == "proc" or key == "share" or key == "class" then
                    Count("reads", "counterFields")
                end
                return line[key]
            end,
        })
    end
    function context:Party()
        self:Tick()
        self:Cycle()
        self:Cycle()
        self:Cycle()
        assert(self.title:GetText() == "Party Damage", "party is not the fourth view")
    end
    function context:Row(index) return env["SurvivorsDragonUiMeterIcon" .. index]:GetParent() end
    return context
end

Test("party is fourth in both header directions and uses real unit portraits", function()
    local context = Meter()
    context:Party()
    local first, second = context:Row(1), context:Row(2)
    assert(first.entry.name == "Friend" and first.entry.dps == 20 and first.entry.dmg == 200)
    assert(first.icon:GetTexture() == "Portraits\\Friend" and second.icon:GetTexture() == "Portraits\\Me")
    assert(first.bar.color[1] == 0.41 and second.bar.color[1] == 1, "native class colors were lost")
    context:Cycle()
    assert(context.title:GetText() == "Damage Done", "party did not cycle back to damage")
    context:Cycle("RightButton")
    assert(context.title:GetText() == "Party Damage", "reverse cycling skipped party")
    context.env.AZS_GetPartyMeter = nil
    context:Cycle()
    context:Cycle()
    context:Cycle()
    context:Cycle()
    assert(context.title:GetText() == "Damage Done", "missing party API did not skip safely")
end)

Test("settled party rows skip presentation and portrait binding; hidden/off/icons-off stay idle", function()
    local context = Meter()
    context:Party()
    local objects = #context.objects
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(#context.objects == objects and not context.reads.portraits and not context.reads.spells)
    assert(not context.writes.SetValue and not context.writes.SetStatusBarColor)
    context:SetSetting("meterShowIcons", false)
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.names and not context.reads.portraits and not context.reads.spells)
    context:SetLayoutHidden(true)
    context:ResetCounts()
    context:Tick()
    context:NoPresentationWrites()
    assert(not context.reads.party and not context.reads.names and not context.reads.portraits)
    context:SetSetting("meterEnabled", false)
    context:ResetCounts()
    context:Tick()
    assert(not context.controller:GetScript("OnUpdate") and not context.controller.events.CHAT_MSG_ADDON)
    assert(not context.reads.party and not context.reads.names and not context.reads.portraits)
end)

Test("unmatched and ambiguous names cannot borrow another party member's portrait", function()
    local context = Meter()
    context:Party()
    context.units.party1.name = "Replacement"
    context:Tick()
    assert(context:Row(1).icon:GetTexture() == context.env.T.SourceIconFallback)
    context.units.party2 = { name = "Friend", class = "MAGE", texture = "Portraits\\NewFriend" }
    context.env.PartyMemberFrame2Portrait:SetTexture("Portraits\\NewFriend")
    context:Tick()
    assert(context:Row(1).icon:GetTexture() == "Portraits\\NewFriend")
    context.units.party3 = context.units.party2
    context:Tick()
    assert(context:Row(1).icon:GetTexture() == context.env.T.SourceIconFallback)
end)

Test("failed native portraits are memoized until source artwork changes", function()
    local context = Meter()
    context.failPortrait = true
    context:Party()
    assert(context:Row(1).icon:GetTexture() == context.env.T.SourceIconFallback)
    context.failPortrait = false
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.portraits, "failed native portrait retried without an identity/artwork change")
    context.units.party1.texture = "Portraits\\ReadyFriend"
    context.env.PartyMemberFrame1Portrait:SetTexture(context.units.party1.texture)
    context:Tick()
    assert(context:Row(1).icon:GetTexture() == "Portraits\\ReadyFriend")
end)

Test("shared Reset includes party counters and preserves class metadata without native writes", function()
    local context = Meter()
    context:Party()
    context.env.DFRL.ResetMeterStats()
    assert(not context:Row(1).active and not context:Row(1).icon:GetTexture(), "reset retained a portrait/row")
    context:Tick()
    assert(not context:Row(1).active, "baseline capture restored pre-reset party damage")
    context.party[1].dmg, context.party[2].dmg = 230, 110
    context.env.AZS_RUN.t = 12
    context:Publish("AZSPARTY")
    context:Tick()
    local entry = context:Row(1).entry
    assert(entry.dmg == 30 and entry.dps == 15 and entry.class == "mage", "party deltas/rates/class changed")
    assert(context.party[1].dmg == 230 and context.party[1].share == 2 / 3 and not context.party[1].order)
    context.party[1].class = "MAGE"
    context:Publish("AZSPARTY")
    context:Tick()
    assert(context:Row(1).entry.class == "MAGE", "unchanged counters hid a class-metadata update")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.party, "retired party tables were accepted without a publication")
    context:Event(context.controller, "CHAT_MSG_ADDON", "AZSPARTY")
    context:Tick()
    assert(context.reads.party == 1 and context:Row(1).entry.dmg == 230)
end)

Test("unchanged meter publications skip counter traversal while native time keeps sampling", function()
    local context = Meter()
    context.damage = { context:WatchCounters(context.damage[1]) }
    context:Tick()
    context:ResetCounts()
    for _ = 1, 6 do
        context.env.AZS_RUN.t = context.env.AZS_RUN.t + 0.21
        context:Tick()
    end
    assert(context.reads.damage == 6, "cached counters stopped the official getter")
    assert(not context.reads.counterFields, "unchanged publications retraversed immutable counter fields")
    assert(context:Row(1).entry.dps == 0, "unchanged counters stopped the rolling native-time window")
    context.env.DFRL.ResetMeterStats()
    context:Tick()
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.counterFields, "settled Reset baselines rescanned unchanged counter metadata")
end)

Test("same-table same-stamp receipts refresh order, class and validation", function()
    local context = Meter()
    context:Party()
    local stamp = context.env.AZS_PARTY_UPDATED
    context.party[1].dmg, context.party[2].dmg = 150, 150
    context.party[1].share, context.party[2].share = 0.5, 0.5
    context.party[1], context.party[2] = context.party[2], context.party[1]
    context.party[1].class = "ROGUE"
    context:Publish("AZSPARTY", stamp)
    context:Tick()
    assert(context:Row(1).entry.name == "Me" and context:Row(1).entry.class == "ROGUE")
    context.party[1].share = 2
    context:Publish("AZSPARTY", stamp)
    context:Tick()
    assert(not context:Row(1).active, "same-stamp receipt bypassed validation")
    context.party[1].share = 0.5
    context:Publish("AZSPARTY", stamp)
    context:Tick()
    assert(context:Row(1).active, "a corrected same-stamp receipt did not recover")
    context.party = {}
    context:Publish("AZSPARTY", stamp)
    context:Tick()
    assert(not context:Row(1).active and not context:Row(2).active, "empty publication retained counter rows")
end)

Test("native healing and boss rates stay live without counter publications", function()
    local context = Meter()
    context.healing = { { name = "Regeneration", dmg = 100, dps = 10, share = 1, proc = 0 } }
    context.boss = { { name = "Sinister Strike", dmg = 100, dps = 10, share = 1, proc = 0 } }
    context:Tick()
    context:Cycle()
    context:SetSetting("meterShowTotalDps", true)
    context.healing[1].dps = 25
    for _ = 1, 5 do
        context:Tick()
    end
    assert(context:Row(1).entry.dps == 25 and context.title:GetText() == "HPS: 25")
    context:Cycle()
    context.boss[1].dps = 40
    for _ = 1, 5 do
        context:Tick()
    end
    assert(context:Row(1).entry.dps == 40 and context.title:GetText() == "DPS: 40")
end)

Test("source and stamp changes invalidate cached counters without a receipt", function()
    local context = Meter()
    context:Party()
    context.party = { { name = "Replacement", class = "priest", dmg = 300, dps = 30, share = 1 } }
    context:Tick()
    assert(context:Row(1).entry.name == "Replacement" and not context:Row(2).active)
    context.party[1].class = "PRIEST"
    context.env.AZS_PARTY_UPDATED = context.now
    context:Tick()
    assert(context:Row(1).entry.class == "PRIEST", "stamp change retained stale counter metadata")
    context.party[1].class = "priest"
    context.env.AZS_GetPartyMeter = function() return context.party, 300, 30 end
    context:Tick()
    assert(context:Row(1).entry.class == "priest", "getter replacement retained stale validation")
end)

Test("publication-cached rolling samples retain gaps, regressions and source retirement", function()
    local context = Meter()
    local model = context.env.T.NewMeterDps(10)
    local source = { { name = "Strike", dmg = 100, dps = 10, share = 1, proc = 0 } }
    assert(model.Observe(10, source, 100, 10, 1))
    assert(model.Observe(11, source, 100, 10, 1) and model.Header(10) == 0)
    source[1].dmg = 200
    assert(model.Observe(12, source, 200, 20, 2) and model.Header(20) == 50)
    assert(model.Observe(15, source, 200, 20, 2) and model.Header(20) == nil)
    assert(model.Observe(16, source, 200, 20, 2) and model.Header(20) == 0)
    assert(model.Observe(8, source, 200, 20, 2) and model.Header(20) == nil)
    assert(model.Observe(9, source, 200, 20, 2) and model.Row("Strike", 0, 20) == 0)
    source = {}
    assert(model.Observe(10, source, 0, 0, 3) and model.Header(0) == nil)
    assert(model.Observe(11, source, 0, 0, 3) and model.Header(0) == 0)
end)

print("PASS " .. passed .. " party meter contracts")
