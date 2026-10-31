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
        local setFont = object.SetFont
        function object:SetFont(face, size, flags)
            self.fontAttempts = (self.fontAttempts or 0) + 1
            if context.failFontObject == self and context.failFontSize == size then return false end
            return setFont(self, face, size, flags)
        end
        local setShadowColor, setShadowOffset = object.SetShadowColor, object.SetShadowOffset
        function object:SetShadowColor(...)
            self.shadowColor = { ... }
            setShadowColor(self, ...)
        end
        function object:SetShadowOffset(...)
            self.shadowOffset = { ... }
            setShadowOffset(self, ...)
        end
        function object:GetStringWidth()
            Count("reads", "metrics")
            self.measuredText = self:GetText()
            self.metricReads = (self.metricReads or 0) + 1
            if context.metricMissing then return nil end
            if context.metricOverride ~= nil then return context.metricOverride end
            local _, size = self:GetFont()
            -- Explicit native glyph boundary; production owns all reservation math.
            return string.len(self:GetText()) * 4 * (size or 11) / 11
        end
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
    local register = env.DFRL.layout.Register
    env.DFRL.layout.Register = function(name, frame, anchor, options)
        context.layoutOptions = options
        register(name, frame, anchor)
    end
    context.settings = {
        meterEnabled = true,
        meterRows = 6,
        meterFontSize = 11,
        meterNameFontSize = 11,
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
    env.AZS_GetHealing = function()
        Count("reads", "healing")
        return Totals(context.healing)
    end
    env.AZS_GetBossMeter = function()
        Count("reads", "boss")
        return Totals(context.boss)
    end
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
    context:Load("core/widgets.lua")
    context:Load("modules/ui/meter.lua", "DamageMeter")
    context.controller = context:Controller("CHAT_MSG_ADDON")
    context.root = env.DFRL_DamageMeter
    for _, object in ipairs(context.objects) do
        if object.kind == "Button" and object.parent == context.root then context.header = object end
    end
    for _, object in ipairs(context.objects) do
        if object.kind == "FontString" and object.parent == context.header then context.title = object end
        if object.kind == "FontString" and object.parent == context.root then context.status = object end
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
    function context:Resize(value)
        self.root:SetWidth(value)
        self.layoutOptions.onResize(self.root)
        self:Tick()
    end
    return context
end

local function NoMeterReads(context)
    assert(
        not context.reads.damage and not context.reads.healing and not context.reads.boss and not context.reads.party,
        "navigation read meter getters before its visible deferred reader"
    )
end

Test("deferred navigation skips unpublished boss and party views in both directions", function()
    local context = Meter()
    context.boss, context.party = {}, {}
    context:Tick()
    context:ResetCounts()
    context:Call(context.header, "OnClick", "LeftButton")
    NoMeterReads(context)
    assert(context.title:GetText() == "Damage Done", "click changed the view before deferred selection")
    context:Tick()
    assert(context.title:GetText() == "Healing Done", "the next available view was skipped")
    assert(
        context.reads.damage == 1
            and context.reads.healing == 1
            and context.reads.boss == 1
            and context.reads.party == 1,
        "selection and rolling DPS repeated native getters in one pass"
    )
    context:Cycle()
    assert(context.title:GetText() == "Damage Done", "blank boss/party pages interrupted the cycle")
    context:Cycle("RightButton")
    assert(context.title:GetText() == "Healing Done", "reverse cycling entered an unpublished page")
    context:Cycle("RightButton")
    assert(context.title:GetText() == "Damage Done")
    context:ResetCounts()
    for _ = 1, 6 do
        context:Tick()
    end
    assert(
        not context.reads.healing and not context.reads.boss and not context.reads.party,
        "settled navigation kept probing unused views"
    )
    context.boss = { { name = "Boss Strike", dmg = 200, dps = 20, share = 1, proc = 0 } }
    context:Publish("AZSBOSSDMG")
    context:Cycle()
    assert(context.title:GetText() == "Healing Done")
    context:Cycle()
    assert(context.title:GetText() == "Boss Damage", "a fresh publication did not join the cycle")
    context:Cycle()
    assert(context.title:GetText() == "Damage Done", "unpublished party data became a blank page")
end)

Test("selection reset baselines and rolling observation share one bounded native pass", function()
    local context = Meter()
    context:Party()
    context.env.DFRL.ResetMeterStats()
    context:ResetCounts()
    context:Tick()
    assert(
        context.reads.damage == 1
            and context.reads.healing == 1
            and context.reads.boss == 1
            and context.reads.party == 1,
        "all-view reset baselines reread native getters during rendering"
    )
    context:ResetCounts()
    context:Tick()
    assert(
        context.reads.party == 1 and context.reads.damage == 1,
        "per-pass results leaked into the next native sample"
    )
    assert(not context.reads.healing and not context.reads.boss, "settled rendering retained an all-view scan")
end)

Test("failed rendering releases temporary native pass results before recovery", function()
    local context = Meter()
    context:Tick()
    context.failText = "Healing Done"
    local ok = pcall(function() context:Cycle() end)
    assert(
        not ok and not context.controller:GetScript("OnUpdate"),
        "native text failure did not retire the failed reader"
    )
    context.healing = { { name = "Regeneration", dmg = 300, dps = 30, share = 1, proc = 0 } }
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:ResetCounts()
    context:Tick()
    assert(
        context.reads.healing == 1 and context:Row(1).entry.dmg == 300,
        "failed-pass source data survived into recovery"
    )
end)

Test("rapid queued clicks preserve advancement without a private click log", function()
    local context = Meter()
    context:Tick()
    context:ResetCounts()
    context:Call(context.header, "OnClick", "LeftButton")
    context:Call(context.header, "OnClick", "LeftButton")
    NoMeterReads(context)
    context:Tick()
    assert(context.title:GetText() == "Boss Damage", "two queued clicks collapsed into one view change")
    local waiting = Meter()
    waiting.damage, waiting.boss = {}, {}
    waiting:Call(waiting.header, "OnClick", "LeftButton")
    waiting:Call(waiting.header, "OnClick", "RightButton")
    waiting:Call(waiting.header, "OnClick", "RightButton")
    waiting:Tick()
    assert(waiting.title:GetText() == "Healing Done", "mixed clicks lost the first entry into the available ring")
end)

Test("initial waiting views select available data while received empty views stay selectable", function()
    local context = Meter()
    context.damage, context.boss, context.party = {}, {}, {}
    context:Tick()
    assert(
        context.title:GetText() == "Healing Done" and context:Row(1).active,
        "initial blank view hid an available healing view"
    )
    local empty = Meter()
    empty.healing, empty.boss, empty.party = {}, {}, {}
    empty:Tick()
    empty:Publish("AZSHEAL")
    empty:Cycle()
    assert(empty.title:GetText() == "Healing Done", "received empty data was treated as unpublished")
    assert(
        empty.status:IsShown() and empty.status:GetText() == "No meter entries yet.",
        "received empty view lost its truthful status"
    )
    empty:Cycle()
    assert(empty.title:GetText() == "Damage Done")
    empty.env.AZS_GetHealing = function() return nil end
    empty:Cycle()
    assert(
        empty.title:GetText() == "Healing Done" and empty.status:GetText() == "Meter data is unavailable.",
        "explicit errors were silently skipped"
    )
end)

Test("all waiting views stay bounded and wake on an unselected publication", function()
    local context = Meter()
    context.damage, context.healing, context.boss, context.party = {}, {}, {}, {}
    context:SetSetting("meterShowTotal", true)
    context:SetSetting("meterShowTotalDps", true)
    context:Tick()
    assert(
        context.title:GetText() == "Damage Done" and not context.status:IsShown(),
        "all-waiting state lost its view identity"
    )
    context:ResetCounts()
    for _ = 1, 6 do
        context:Tick()
    end
    assert(
        not context.reads.healing and not context.reads.boss and not context.reads.party,
        "all-waiting state scanned every idle tick"
    )
    context:NoPresentationWrites()
    context:ResetCounts()
    context:Call(context.header, "OnClick", "RightButton")
    context:Tick()
    assert(context.title:GetText() == "Damage Done", "all-waiting navigation invented a selected view")
    assert(
        context.reads.damage == 1
            and context.reads.healing == 1
            and context.reads.boss == 1
            and context.reads.party == 1,
        "all-waiting scan was not bounded to four views"
    )
    context.healing = { { name = "Regeneration", dmg = 100, dps = 10, share = 1, proc = 0 } }
    context:Publish("AZSHEAL")
    context:ResetCounts()
    context:Tick()
    assert(context:Row(1).entry.name == "Regeneration", "unselected fresh data did not recover a waiting meter")
    assert(context.title:GetText() == "Total: 100   HPS: 10", "accepted data did not restore the chosen numeric header")
end)

Test("hidden and off meters defer queued choices and retired data cannot qualify", function()
    local context = Meter()
    context.boss, context.party = {}, {}
    context:Tick()
    context:SetLayoutHidden(true)
    context:ResetCounts()
    context:Call(context.header, "OnClick", "LeftButton")
    context:Tick()
    NoMeterReads(context)
    context:SetLayoutHidden(false)
    context:Tick()
    assert(context.title:GetText() == "Healing Done", "visible recovery lost its queued navigation")
    context:SetSetting("meterEnabled", false)
    context:ResetCounts()
    context:Call(context.header, "OnClick", "LeftButton")
    context:Tick()
    NoMeterReads(context)
    context:SetSetting("meterEnabled", true)
    context:ResetCounts()
    context:Tick()
    NoMeterReads(context)
    context:Call(context.header, "OnClick", "LeftButton")
    context:Tick()
    NoMeterReads(context)
    assert(not context:Row(1).active, "retired nonempty tables qualified without new publications")
    context:Publish("AZSMETER")
    context:Tick()
    assert(context.title:GetText() == "Damage Done" and context:Row(1).active)
    context:Event(context.controller, "CHAT_MSG_ADDON", "AZSZONE")
    context:ResetCounts()
    context:Tick()
    NoMeterReads(context)
    context:Publish("AZSHEAL")
    context:Tick()
    assert(context.title:GetText() == "Healing Done", "fresh data did not recover after zone retirement")
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
    context.healing[1].dps = 1210
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
    assert(row.entry.dps == 1210 and context.healing[1].dps == 1210, "layout changed native values")
    context:ResetCounts()
    context.healing[1].dps = 1240
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
        string.find(values, "100", 1, true) and string.find(values, "100.0%", 1, true),
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
    context:Publish("AZSHEAL")
    context:Tick()
    assert(row.active and #context.objects == allocated, "enabled meter did not reuse its existing row")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    context:ResetCounts()
    context:Tick()
    assert(not context.reads.metrics and not row.active, "world retirement measured or retained rows")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:Publish("AZSHEAL")
    context:Tick()
    assert(row.active and #context.objects == allocated, "fresh native data failed to reuse the retired row")
end)

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
