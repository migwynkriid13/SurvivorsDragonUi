-- CI only: the production pet controller over explicit fake native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "pet/totem fixtures require the CI Lua 5.1 interpreter")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Pets()
    local context = H.New()
    local env = context.env
    local function Read(name) context.reads[name] = (context.reads[name] or 0) + 1 end
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        function object:SetScale(value)
            self.context.writes.SetScale = (self.context.writes.SetScale or 0) + 1
            self.scale = value
        end
        function object:GetEffectiveScale()
            return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        return object
    end
    function env.UIParent:GetEffectiveScale() return 1 end
    env.DFRL.layout.IsHidden = function() return not context.layoutMask:IsShown() end
    env.DFRL.layout.Place = function() end
    local listenVisibility = env.DFRL.layout.ListenVisibility
    env.DFRL.layout.ListenVisibility = function(name, callback)
        context.visibilityChanged = callback
        listenVisibility(name, callback)
    end
    local setLayoutHidden = context.SetLayoutHidden
    function context:SetLayoutHidden(hidden)
        setLayoutHidden(self, hidden)
        if self.visibilityChanged then self.visibilityChanged(not hidden) end
    end
    local register = env.DFRL.layout.Register
    env.DFRL.layout.Register = function(name, frame, anchor, options)
        assert(name == "petFrames", "totems created another Layout group")
        context.reset = options.onReset
        register(name, frame, anchor)
    end
    env.DFRL.navigation = {
        IsRunPhase = function(phase) return phase == "playing" or phase == "paused" or phase == "choosing" end,
    }
    context.settings =
        { petRows = 6, petSpacing = 4, hidePetNames = false, hidePetCounts = false, hidePetTimers = true }
    context.phase, context.runTime, context.learned = "playing", 10, {}
    env.DFRL.sct = {
        LearnSummonIcon = function(name, icon)
            context.learned[name] = icon
            Read("learn")
        end,
    }
    env.SetPortraitToTexture = function(name, texture)
        Read("portrait")
        env[name]:SetTexture(texture)
    end
    env.AZS_GetPhase = function()
        Read("phase")
        return context.phase
    end
    env.AZS_GetRunTime = function()
        Read("clock")
        return context.runTime
    end
    local function Snapshot(name, source)
        Read(name)
        assert(source and type(source) == "table", "getter read before a valid publication")
        local list = {}
        for _, row in ipairs(source) do
            local copy = {}
            for key, value in pairs(row) do
                copy[key] = value
            end
            if row.ends then copy.remaining = math.max(0, row.ends - (context.runTime or 0)) end
            table.insert(list, copy)
        end
        return list
    end
    env.AZS_GetSummons = function() return Snapshot("pets", env.AZS_PETS) end
    env.AZS_GetTotems = function() return Snapshot("totems", env.AZS_TOTEMS) end
    env.ReloadUI = function() context.reloaded = true end
    function context:Publish(prefix, rows)
        local packet = prefix == "AZSPETS" and "AZS_PETS" or "AZS_TOTEMS"
        self.env[packet], self.env[packet .. "_UPDATED"] = rows, self.now
        self:Event(self.controller, "CHAT_MSG_ADDON", prefix)
    end
    function context:Tick() self:Call(self.controller, "OnUpdate", 0.1) end
    function context:Rows()
        local rows = {}
        for _, object in ipairs(self.objects) do
            if object.kind == "Frame" and object.parent == self.layoutFrame then table.insert(rows, object) end
        end
        return rows
    end
    function context:Labels(index)
        local row = self:Rows()[index]
        local labels, count = {}, nil
        assert(row, "missing pooled pet row")
        for _, object in ipairs(self.objects) do
            if object.kind == "FontString" then
                if object.parent == row then
                    table.insert(labels, object)
                elseif object.parent and object.parent.parent == row then
                    count = object
                end
            end
        end
        return labels[1]:GetText(), labels[2]:GetText(), count:GetText()
    end
    context:Load("core/widgets.lua")
    context:Load("modules/unit/pets.lua", "PetFrames")
    context.controller = context:Controller("CHAT_MSG_ADDON")
    return context
end

local function Summon(id, key, name, remaining, permanent)
    return {
        id = id,
        key = key,
        name = name,
        icon = "Interface\\Icons\\" .. key,
        remaining = remaining,
        permanent = permanent,
    }
end
local function Totem(key, count, ends)
    return {
        key = key,
        spell = 3599,
        name = "Localized " .. key,
        icon = "Interface\\Icons\\" .. key,
        count = count,
        cap = 40,
        duration = 16.8,
        ends = ends or 30,
    }
end

Test("totems share the pet renderer while preserving summon grouping and source metadata", function()
    local c = Pets()
    local pets = { Summon(1, "wolf", "Wolf", nil, true), Summon(2, "wolf", "Wolf", 12) }
    local totems = { Totem("searing_totem", 3), Totem("magma_totem", 1) }
    c:Publish("AZSPETS", pets)
    c:Publish("AZSTOTEMS", totems)
    assert(not c.reads.pets and not c.reads.totems, "packet handler read before native parsing completed")
    c:Tick()
    assert(#c:Rows() == 3, "totem counts were expanded into fictional individual rows")
    local name, timer, count = c:Labels(1)
    assert(name == "Wolf" and timer == "" and count == "x2", "existing mixed summon group changed")
    name, timer, count = c:Labels(2)
    assert(name == "Localized searing_totem" and timer == "" and count == "x3", "totem presentation differs from pets")
    name, timer, count = c:Labels(3)
    assert(name == "Localized magma_totem" and timer == "" and count == "", "single totem acquired a different badge")
    assert(c.learned.Wolf == "Interface\\Icons\\Ability_Hunter_Pet_Wolf", "Hunter family portrait changed")
    assert(c.learned[totems[1].name] == totems[1].icon, "totem metadata missed the shared source resolver")
    assert(totems[1].remaining == nil and pets[1].count == nil, "controller changed native snapshots")
    c:ResetCounts()
    c:Tick()
    c:NoPresentationWrites()
    assert(
        not c.reads.pets and not c.reads.totems and not c.reads.clock and not c.reads.learn,
        "static groups repeated native work"
    )
end)

Test("totem keys remain separate from pet keys and accept future published kinds", function()
    local c = Pets()
    c:Publish("AZSPETS", { Summon(1, "future_totem", "Shared name", nil, true) })
    local totem = Totem("future_totem", 5)
    totem.name, totem.cap, totem.icon = "Shared name", 70, "Interface\\Icons\\PublishedFutureArt"
    c:Publish("AZSTOTEMS", { totem })
    c:Tick()
    assert(#c:Rows() == 2, "independent feeds were merged by key or name")
    local labels = { c:Labels(2) }
    assert(labels[3] == "x5", "new valid native kind or cap was rejected")
    assert(c.env.SurvivorsDragonUiPetPortrait2:GetTexture() == totem.icon, "published art was replaced")
end)

Test("countdowns wait for native run time, respect pauses and keep zero-time native counts", function()
    local c = Pets()
    c:SetSetting("hidePetTimers", false)
    c.runTime = nil
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 3, 20) })
    c:Tick()
    local _, timer, count = c:Labels(1)
    assert(timer == "--:--" and count == "x3", "pre-run zero fallback became a real timer")
    c.runTime = 10.2
    c:Tick()
    _, timer = c:Labels(1)
    assert(timer == "0:10", "native remaining seconds did not round up")
    c.phase, c.now = "paused", 500
    c:ResetCounts()
    c:Tick()
    c:NoPresentationWrites()
    _, timer = c:Labels(1)
    assert(timer == "0:10" and not c.reads.learn, "pause used a UI clock or relearned metadata")
    c.phase, c.runTime = "choosing", 11
    c:Tick()
    _, timer = c:Labels(1)
    assert(not c.layoutFrame:IsShown() and timer == "0:10", "card choice painted or discarded retained timing")
    c.phase, c.runTime = "playing", 25
    c:Tick()
    _, timer, count = c:Labels(1)
    assert(timer == "0:00" and count == "x3", "expired countdown manufactured a native removal")
    c:Publish("AZSTOTEMS", {})
    c:Tick()
    assert(not c.layoutFrame:IsShown(), "empty native snapshot retained a visible totem")
end)

Test("totem clocks are sampled once only when a usable countdown is received", function()
    for _, performance in ipairs({ false, true }) do
        local c = Pets()
        c:SetSetting("performanceMode", performance)
        c:SetSetting("hidePetTimers", false)
        c:Publish("AZSTOTEMS", {})
        c:Tick()
        assert(c.reads.phase == 1 and c.reads.totems == 1 and not c.reads.clock, "empty feed read the native clock")

        local absent, invalid = Totem("absent_totem", 2), Totem("invalid_totem", 1)
        absent.ends, invalid.ends, invalid.remaining = nil, nil, math.huge
        local list = { absent, invalid }
        c:Publish("AZSTOTEMS", list)
        c:ResetCounts()
        c:Tick()
        local _, timer, count = c:Labels(1)
        assert(timer == "--:--" and count == "x2" and select(2, c:Labels(2)) == "--:--")
        assert(c.reads.phase == 1 and c.reads.totems == 1 and not c.reads.clock, "unusable timers read the clock")

        local zero = Totem("zero_totem", 3)
        zero.ends, zero.remaining = nil, 0
        table.insert(list, zero)
        table.insert(list, Totem("active_totem", 1, 20))
        c.runTime = nil
        c:ResetCounts()
        c:Tick()
        assert(c.reads.clock == 1 and select(2, c:Labels(3)) == "--:--" and select(2, c:Labels(4)) == "--:--")
        c.runTime = 10
        c:ResetCounts()
        c:Tick()
        assert(c.reads.clock == 1 and select(2, c:Labels(3)) == "0:00" and select(2, c:Labels(4)) == "0:10")
    end
end)

Test("upgrade cards hide whole pet groups without retiring their roster or allocating hidden artwork", function()
    for _, performance in ipairs({ false, true }) do
        local c = Pets()
        c:SetSetting("performanceMode", performance)
        c:SetSetting("hidePetTimers", false)
        c:Publish("AZSPETS", { Summon(1, "imp", "Imp", nil, true) })
        c:Publish("AZSTOTEMS", { Totem("searing_totem", 2, 30) })
        c:Tick()
        local allocated = #c.objects
        local portrait = c.env.SurvivorsDragonUiPetPortrait2:GetTexture()
        c.phase = "choosing"
        c:ResetCounts()
        c:Tick()
        assert(not c.layoutFrame:IsShown() and not c:Rows()[1]:IsVisible() and not c:Rows()[2]:IsVisible())
        c.layoutFrame:Show()
        assert(not c.layoutFrame:IsShown(), "another Show bypassed the active card-choice hide")
        assert(c.env.SurvivorsDragonUiPetPortrait2:GetTexture() == portrait)
        assert(not c.reads.pets and not c.reads.totems and not c.reads.clock)
        c:Publish("AZSTOTEMS", { Totem("searing_totem", 4, 30) })
        c:ResetCounts()
        for _ = 1, 3 do
            c:Tick()
        end
        c:NoPresentationWrites()
        assert(#c.objects == allocated and not c.reads.totems and not c.reads.clock and not c.reads.learn)
        c.phase, c.runTime = "playing", 12
        c:Tick()
        local _, timer, count = c:Labels(2)
        assert(c.layoutFrame:IsVisible() and c:Labels(1) == "Imp" and timer == "0:18" and count == "x4")
        assert(#c.objects == allocated, "return from cards replaced the pet row pool")
        c.phase = "choosing"
        c:Tick()
        c:Event(c.controller, "PLAYER_LEAVING_WORLD")
        c.phase = "playing"
        c:Event(c.controller, "PLAYER_ENTERING_WORLD")
        c:Tick()
        assert(not c.layoutFrame:IsShown(), "world retirement replayed a choice-hidden roster")
    end
end)

Test("missing totem support preserves pets and totems work without the pet getter", function()
    local c = Pets()
    c.env.AZS_GetTotems = nil
    c:Publish("AZSPETS", { Summon(1, "imp", "Imp", nil, true) })
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 2) })
    c:Tick()
    assert(c:Labels(1) == "Imp" and #c:Rows() == 1, "missing optional totem getter hid pets")
    c.env.AZS_GetSummons = nil
    c.env.AZS_GetTotems = function() return { Totem("searing_totem", 2) } end
    c:Tick()
    assert(c:Labels(1) == "Localized searing_totem", "totems depended on the separate pet API")
end)

Test("invalid snapshots clear only their own feed and require current receipt stamps", function()
    local c = Pets()
    c:Publish("AZSPETS", { Summon(1, "imp", "Imp", nil, true) })
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 2) })
    c.env.AZS_TOTEMS_UPDATED = nil
    c:Tick()
    assert(#c:Rows() == 1 and not c.reads.totems, "totems were admitted without a receipt stamp")
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 2) })
    c:Tick()
    local duplicate = Totem("searing_totem", 2)
    c:Publish("AZSTOTEMS", { duplicate, duplicate })
    c:Tick()
    assert(c:Labels(1) == "Imp" and not c:Rows()[2]:IsShown(), "invalid totem snapshot hid pets or kept partial rows")
    for _, count in ipairs({ 0, -1, 1.5, 41, math.huge }) do
        c:Publish("AZSTOTEMS", { Totem("searing_totem", count) })
        c:Tick()
        assert(c:Labels(1) == "Imp" and not c:Rows()[2]:IsShown(), "invalid count was accepted")
    end
    c:Publish("AZSTOTEMS", { Totem("magma_totem", 2) })
    c:Publish("AZSPETS", { Summon(1, "imp", "Imp", nil, true), Summon(1, "imp", "Imp", nil, true) })
    c:Tick()
    assert(c:Labels(1) == "Localized magma_totem" and not c:Rows()[2]:IsShown(), "invalid pets hid valid totems")
end)

Test("hidden groups accept data without allocating rows and resume current native timing", function()
    local c = Pets()
    c:SetSetting("hidePetTimers", false)
    c:SetLayoutHidden(true)
    local objects = #c.objects
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 3, 30) })
    c:Tick()
    assert(
        #c.objects == objects and #c:Rows() == 0 and not c.reads.clock,
        "hidden data created artwork or sampled the clock"
    )
    c:ResetCounts()
    c:Tick()
    c:NoPresentationWrites()
    assert(
        not c.controller:GetScript("OnUpdate") and not c.reads.phase and not c.reads.totems and not c.reads.clock,
        "hidden groups retained idle phase/countdown polling"
    )
    c.runTime = 27
    c:SetLayoutHidden(false)
    c:Tick()
    local name, timer, count = c:Labels(1)
    assert(name == "Localized searing_totem" and timer == "0:03" and count == "x3", "unhide replayed stale timing")
end)

Test("hidden receipt work learns current SCT icons once and returns to sleep", function()
    for _, performance in ipairs({ false, true }) do
        local c = Pets()
        c:SetSetting("performanceMode", performance)
        c:SetLayoutHidden(true)
        assert(not c.controller:GetScript("OnUpdate"), "hidden empty group kept its worker")
        local allocated = #c.objects
        c:Publish("AZSPETS", { Summon(1, "imp", "Imp", nil, true) })
        assert(c.controller:GetScript("OnUpdate") and not c.reads.pets, "receipt missed its deferred handoff")
        c:Tick()
        assert(c.learned.Imp and not c.controller:GetScript("OnUpdate"), "icon learning did not settle")
        assert(#c.objects == allocated, "hidden metadata allocated presentation")
        c:ResetCounts()
        c:Tick()
        c:NoPresentationWrites()
        assert(not next(c.reads), "sleeping metadata performed native work")
        c.env.AZS_PETS[1].name = "Localized Imp"
        c:NotifyLocale()
        c:Tick()
        assert(c.learned["Localized Imp"] and not c.controller:GetScript("OnUpdate"), "language metadata stayed stale")
        c:ResetCounts()
        c.phase = "choosing"
        c:Publish("AZSTOTEMS", { Totem("searing_totem", 2) })
        c:Tick()
        assert(not c.reads.totems and not c.controller:GetScript("OnUpdate"), "choice cards polled hidden data")
        c.phase = "playing"
        c:Event(c.controller, "CHAT_MSG_ADDON", "AZSRUN")
        c:Tick()
        assert(c.learned["Localized searing_totem"], "resume lost deferred icon learning")
        assert(not c.controller:GetScript("OnUpdate"), "resumed hidden metadata left an idle updater")
        c:SetLayoutHidden(false)
        c:Tick()
        assert(#c:Rows() == 2 and c.layoutFrame:IsVisible(), "show did not recover current native rows")
    end
end)

Test("shared pet settings reflow cached groups without extra getters or portrait binds", function()
    local c = Pets()
    c:Publish("AZSPETS", { Summon(1, "imp", "Imp", nil, true) })
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 2), Totem("magma_totem", 1) })
    c:Tick()
    local objects = #c.objects
    c:ResetCounts()
    c:SetSetting("petRows", 1)
    c:SetSetting("petSpacing", 12)
    c:SetSetting("hidePetNames", true)
    c:SetSetting("hidePetCounts", true)
    c:Tick()
    local name, _, count = c:Labels(2)
    assert(name == "" and count == "" and c.layoutFrame:GetWidth() == 171, "totems ignored shared pet controls")
    assert(
        not c.reads.totems and not c.reads.pets and not c.reads.portrait and #c.objects == objects,
        "settings rebuilt cached native data/artwork"
    )
    c:SetSetting("hidePetNames", false)
    c:SetSetting("hidePetCounts", false)
    c:Tick()
    name, _, count = c:Labels(2)
    assert(name == "Localized searing_totem" and count == "x2", "discarded display choices lost native data")
end)

Test("retirement gates both feeds and a fresh same-table same-stamp receipt reopens only its feed", function()
    local c = Pets()
    c:Publish("AZSPETS", { Summon(1, "imp", "Imp", nil, true) })
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 2) })
    c:Tick()
    c:Event(c.controller, "CHAT_MSG_ADDON", "AZSZONE")
    c:ResetCounts()
    c:Tick()
    assert(
        not c.layoutFrame:IsShown() and not c.reads.pets and not c.reads.totems,
        "zone replay admitted retired tables"
    )
    c:Event(c.controller, "CHAT_MSG_ADDON", "AZSTOTEMS")
    assert(not c.reads.totems, "receipt read synchronously")
    c:Tick()
    assert(
        c:Labels(1) == "Localized searing_totem" and not c:Rows()[2]:IsShown(),
        "fresh totem receipt reactivated retired pets"
    )
    c.phase = "menu"
    c:ResetCounts()
    c:Tick()
    assert(
        not c.layoutFrame:IsShown() and not c.reads.totems and not c.reads.pets,
        "inactive phase inspected roster data"
    )
    c.phase = "playing"
    c:Tick()
    assert(not c.layoutFrame:IsShown(), "phase transition replayed a retired snapshot")
end)

Test("world, reload and reset cleanup preserve the passive pool without stale replay", function()
    local c = Pets()
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 2) })
    c:Tick()
    local objects = #c.objects
    c.reset()
    assert(not c.layoutFrame:IsShown(), "reset retained visible totems")
    c:Tick()
    assert(c.layoutFrame:IsShown() and #c.objects == objects, "reset did not reuse the pool with current data")
    c:Event(c.controller, "PLAYER_LEAVING_WORLD")
    assert(not c.controller:GetScript("OnUpdate") and not c.layoutFrame:IsShown(), "world leave retained active work")
    assert(c.env.SurvivorsDragonUiPetPortrait1:GetTexture() == nil, "retirement retained portrait references")
    c:Event(c.controller, "PLAYER_ENTERING_WORLD")
    c:Tick()
    assert(not c.layoutFrame:IsShown(), "world entry replayed the old snapshot")
    c:Publish("AZSTOTEMS", { Totem("searing_totem", 3) })
    c:Tick()
    assert(#c.objects == objects, "re-entry allocated a second row pool")
    c.env.ReloadUI()
    assert(
        c.reloaded and not c.controller:GetScript("OnUpdate") and not c.layoutFrame:IsShown(),
        "reload missed shared cleanup"
    )
end)

Test("timer-only samples retain native reads without reentering layout or icon preparation", function()
    for _, performance in ipairs({ false, true }) do
        local c = Pets()
        c:SetSetting("performanceMode", performance)
        c:SetSetting("hidePetTimers", false)
        local get = c.env.DFRL.display.Get
        c.env.DFRL.display.Get = function(key)
            if key == "petRows" or key == "petSpacing" then c.reads.layout = (c.reads.layout or 0) + 1 end
            return get(key)
        end
        local circle = c.env.T.NewCircularIcon
        c.env.T.NewCircularIcon = function(...)
            local image = circle(...)
            local bind = image.Bind
            image.Bind = function(...)
                c.reads.binds = (c.reads.binds or 0) + 1
                return bind(...)
            end
            return image
        end
        local summon = Summon(1, "imp", "Imp", 12)
        summon.ends = 22
        local totem = Totem("searing_totem", 3, 30)
        c:Publish("AZSPETS", { summon })
        c:Publish("AZSTOTEMS", { totem })
        c:Tick()
        local objects, width, height = #c.objects, c.layoutFrame:GetWidth(), c.layoutFrame:GetHeight()
        c:ResetCounts()
        for index = 1, 10 do
            c.runTime = 10 + index / 10
            c:Tick()
        end
        assert(c.reads.pets == 10 and c.reads.totems == 10 and c.reads.clock == 10, "timer sampling slowed")
        assert(not c.reads.layout and not c.reads.binds and #c.objects == objects, "countdowns repeated static work")
        local _, petTimer = c:Labels(1)
        local _, totemTimer, count = c:Labels(2)
        assert(petTimer == "0:11" and totemTimer == "0:19" and count == "x3", "native countdowns changed")
        c.phase = "paused"
        c:ResetCounts()
        c:Tick()
        c:NoPresentationWrites()
        assert(not c.reads.layout and not c.reads.binds, "paused countdowns repeated static work")

        -- A getter can change metadata or group count without a new receipt.
        totem.name, totem.icon, totem.count = "Fresh native name", "Interface\\Icons\\FreshTotem", 4
        c:Tick()
        local name
        name, _, count = c:Labels(2)
        assert(name == totem.name and count == "x4", "same-sized native metadata stayed stale")
        assert(c.env.SurvivorsDragonUiPetPortrait2:GetTexture() == totem.icon, "changed art did not bind")
        table.insert(c.env.AZS_TOTEMS, Totem("magma_totem", 2))
        c:Tick()
        assert(#c:Rows() == 3 and c:Rows()[3]:IsShown(), "unannounced group growth missed layout")
        table.remove(c.env.AZS_TOTEMS, 2)
        c:Tick()
        assert(not c:Rows()[3]:IsShown() and c.layoutFrame:GetHeight() == height, "group shrink retained a row")
        c.layoutFrame:SetWidth(width + 20)
        c.layoutFrame:SetHeight(height + 20)
        c:Tick()
        assert(c.layoutFrame:GetWidth() == width and c.layoutFrame:GetHeight() == height, "bounds stopped recovering")
        c:ResetCounts()
        c.layoutFrame:SetScale(1.25)
        c:Tick()
        assert(c.reads.binds == 2, "scale changes skipped icon recovery")
    end
end)

Test("failed static pet artwork keeps its original retries and settles after recovery", function()
    for _, performance in ipairs({ false, true }) do
        local c = Pets()
        c:SetSetting("performanceMode", performance)
        local icon = "Interface\\Icons\\RetryTotem"
        local totem = Totem("retry_totem", 2)
        totem.icon = icon
        c.failTexture = icon
        c:Publish("AZSTOTEMS", { totem })
        c:Tick()
        local objects = #c.objects
        c:ResetCounts()
        c:Tick()
        assert((c.writes.SetTexture or 0) > 0 and #c.objects == objects, "failed static art stopped retrying")
        assert(not c.reads.totems and not c.reads.clock, "art retry repeated native timer reads")
        c.failTexture = nil
        c:Tick()
        local visible = false
        for _, object in ipairs(c.objects) do
            if object.kind == "Texture" and object:GetTexture() == icon and object:IsVisible() then visible = true end
        end
        assert(visible and #c.objects == objects, "static artwork did not recover through the original pool")
        c:ResetCounts()
        c:Tick()
        c:NoPresentationWrites()
    end
end)

print("PASS pet/totem UI contracts: " .. passed)
