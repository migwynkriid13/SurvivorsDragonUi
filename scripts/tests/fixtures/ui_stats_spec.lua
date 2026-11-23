-- CI only: the production Stats HUD, with explicit native publication boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "Stats fixtures require CI Lua 5.1")

for _, performance in ipairs({ false, true }) do
    local context = H.New()
    local env, phase, hidden = context.env, "playing", false
    local object = context.Object
    function context:Object(kind, name, parent)
        local result = object(self, kind, name, parent)
        function result:SetScale(value) self.scale = value end
        function result:GetScale() return self.scale or 1 end
        function result:GetEffectiveScale()
            return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        if kind == "Texture" then
            function result:SetBlendMode(value) self.blend = value end
        elseif kind == "FontString" then
            function result:GetStringWidth()
                context.reads.metrics = (context.reads.metrics or 0) + 1
                local _, size = self:GetFont()
                return string.len(self:GetText()) * (size or 11) * 0.5
            end
        end
        return result
    end
    -- UIParent predates the explicit scale boundary above.
    function env.UIParent:GetEffectiveScale() return 1 end
    env.DFRL.locale.code = "en"
    env.DFRL.locale.Native = function(key, bindings)
        assert(key == "common.yards")
        return bindings and bindings.n .. " yd" or "{n} yd"
    end
    local layout, visibility, edit, resize = env.DFRL.layout
    layout.IsHidden = function() return hidden end
    local register = layout.Register
    layout.Register = function(key, frame, anchor, options)
        assert(key == "survivorStats" and options.edgeWidth)
        edit, resize = options.onEdit, options.onResize
        register(key, frame, anchor, options)
    end
    local listen = layout.ListenVisibility
    layout.ListenVisibility = function(key, callback)
        visibility = callback
        listen(key, callback)
    end
    env.AZS_GetPhase = function()
        context.reads.phase = (context.reads.phase or 0) + 1
        return phase
    end
    env.AZS_RUN = setmetatable({ t = 10 }, {
        __index = function(_, key)
            assert(key ~= "gold" and key ~= "kills" and key ~= "chest", "Stats read a tally field")
        end,
    })
    env.AZS_RUN_UPDATED, env.AZS_ZONE_UPDATED = 100, 90
    local values = {
        dmg = 6.33,
        cd = 0.306,
        crit = 0.957,
        cm = 6.63,
        hp = 603,
        arm = 0.327,
        reg = 5.2,
        lch = 0.014,
        heal = 0,
        area = 1.504,
        echo = 0.263,
        spd = 1.592,
        xp = 1,
        luck = 0.24,
    }
    env.AZS_STATS = setmetatable({}, {
        __index = function(_, key)
            assert(key ~= "gold", "Stats read the excluded gold modifier")
            context.reads.stats = (context.reads.stats or 0) + 1
            return values[key]
        end,
        __newindex = function() error("Stats mutated the native snapshot") end,
    })
    context:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    context:Load("modules/ui/stats.lua", "Stats")
    local reader = context:Controller("PLAYER_ENTERING_WORLD")
    local panel = assert(env.SurvivorsDragonUiStats)
    local function Tick()
        context.now = context.now + 0.1
        context:Call(reader, "OnUpdate", 0.1)
    end
    local function Packet(prefix) context:Event(reader, "CHAT_MSG_ADDON", prefix or "AZS") end
    local function Has(text)
        for _, region in ipairs(context.objects) do
            if region.kind == "FontString" and region:IsVisible() and region:GetText() == text then return true end
        end
        return false
    end
    local function NoDrawing()
        for _, name in ipairs({
            "SetText",
            "SetTexture",
            "SetFont",
            "SetPoint",
            "SetWidth",
            "SetHeight",
            "Show",
            "Hide",
        }) do
            assert((context.writes[name] or 0) == 0, name .. " repainted settled Stats")
        end
    end

    Tick()
    assert(not context.reads.phase and not context.reads.stats and not panel:IsShown(), "default-off Stats did work")
    for _, region in ipairs(context.objects) do
        assert(region.kind ~= "Texture" and region.kind ~= "FontString", "off Stats prepared artwork")
    end
    assert(not display.Copy({ statsWindow = "true" }).statsWindow)
    assert(display.Copy({ statsFontSize = 100 }).statsFontSize == 18)
    assert(display.Copy({ statsRowHeight = 1 }).statsRowHeight == 12)
    assert(display.Copy({ statsShowGold = true }).statsShowGold == nil)
    display.BeginEdit()
    display.Set("performanceMode", performance)
    display.Set("statsWindow", true)
    Tick()
    assert(panel:IsShown() and not env.SurvivorsDragonUiDisplay, "Stats preview saved too early")
    assert(Has("Stats") and Has("Offense") and Has("+533%") and Has("95.7%") and Has("663%"))
    assert(Has("+50.4%") and Has("5.2") and Has("+0%"), "native formatting or zero values changed")
    assert(not Has("Gold") and not Has("Kills") and not Has("Cache"), "Stats restored a counter")
    assert(not reader:GetScript("OnUpdate"), "settled Stats retained an idle updater")
    local allocated = #context.objects
    context:ResetCounts()
    Packet("AZSRUN")
    Tick()
    NoDrawing()
    assert(#context.objects == allocated, "unchanged native data grew the pool")
    -- Native providers can reuse a table across publications.
    values.dmg = 7.33
    Packet()
    assert(not Has("+633%"), "Stats read inside the native parser event")
    Tick()
    assert(Has("+633%"), "a reused native table hid changed values")
    values.arm = nil
    Packet()
    Tick()
    assert(not Has("Armor"), "an unavailable field retained an old value")
    values.arm = 0.4
    Packet()
    Tick()
    assert(Has("Armor") and Has("40%"), "an unavailable field did not recover")
    values.crit = math.huge
    Packet()
    Tick()
    assert(not Has("Crit Chance"), "a nonfinite field was displayed")
    values.crit = 0.957
    Packet()
    Tick()
    local reused = #context.objects
    display.Set("statsShowDamage", false)
    Tick()
    assert(not Has("Damage"))
    display.Set("statsShowDamage", true)
    Tick()
    assert(Has("Damage") and #context.objects == reused, "stat visibility replaced pooled rows")
    panel:SetWidth(300)
    resize(panel, 300)
    Tick()
    assert(Has("+633%") and #context.objects == reused, "resizing lost values or grew the pool")
    values.pick = 12.5
    display.Set("statsShowPickup", true)
    Tick()
    assert(Has("12.5 yd"), "pickup range did not format the native yard template")
    hidden = true
    visibility(false)
    context:SetLayoutHidden(true)
    assert(not reader.events.CHAT_MSG_ADDON and not reader:GetScript("OnUpdate"))
    context:ResetCounts()
    Tick()
    assert(not context.reads.phase and not context.reads.stats, "Layout-hidden Stats collected data")
    NoDrawing()
    values.hp = 900
    hidden = false
    context:SetLayoutHidden(false)
    visibility(true)
    Tick()
    assert(Has("900"), "unhiding replayed a hidden-time value")
    phase = "choosing"
    Packet("AZSRUN")
    Tick()
    assert(panel:IsShown() and Has("900"), "Stats disappeared during native level-up/jewelry choices")
    local choicePool = #context.objects
    context:ResetCounts()
    Packet("AZSRUN")
    Tick()
    NoDrawing()
    assert(not reader:GetScript("OnUpdate"), "settled upgrade Stats kept an idle updater")
    values.hp = 1000
    Packet()
    assert(Has("900"), "an upgrade publication read stats before native parsing completed")
    Tick()
    assert(panel:IsShown() and Has("1,000"), "Stats did not update while upgrades were open")
    display.Set("statsWindow", false)
    Tick()
    assert(not panel:IsShown() and not reader.events.CHAT_MSG_ADDON, "upgrades forced disabled Stats to stay active")
    display.Set("statsWindow", true)
    Tick()
    assert(panel:IsShown() and Has("1,000") and #context.objects == choicePool, "upgrade recovery replaced Stats rows")
    phase = "paused"
    Packet("AZSRUN")
    Tick()
    assert(panel:IsShown() and Has("1,000"), "paused native values failed to recover")
    phase = "ready"
    Packet("AZSRUN")
    Tick()
    assert(not panel:IsShown())
    phase = "playing"
    Packet("AZSRUN")
    Tick()
    assert(not panel:IsShown(), "a retired table seeded another run without a stats publication")
    Packet()
    Tick()
    assert(panel:IsShown(), "fresh stats did not admit a reused publication table")
    display.FinishEdit(false)
    assert(not panel:IsShown() and not reader:GetScript("OnUpdate"), "Cancel retained the stats preview")
    display.BeginEdit()
    display.Set("statsWindow", true)
    display.FinishEdit(true)
    Tick()
    assert(panel:IsShown() and env.SurvivorsDragonUiDisplay.statsWindow, "Confirm lost the Stats choice")
    context:Event(reader, "PLAYER_LEAVING_WORLD")
    assert(not panel:IsShown() and not reader.events.CHAT_MSG_ADDON and not reader:GetScript("OnUpdate"))
    context:Event(reader, "PLAYER_ENTERING_WORLD")
    Tick()
    assert(not panel:IsShown(), "world entry reused a retired stats publication")
    Packet()
    Tick()
    assert(panel:IsShown())
    phase = "ready"
    edit(true)
    Tick()
    assert(panel:IsShown() and Has("--"), "Layout editing lost the stat placeholders")
    edit(false)
    Tick()
    assert(not panel:IsShown())
    display.Reset()
    assert(not display.Get("statsWindow") and not reader:GetScript("OnUpdate"), "reset did not restore default-off")
end

print("Stats publication, settings, visibility and pooled drawing cases passed")
