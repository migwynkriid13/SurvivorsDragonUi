-- CI only: production resource/display owners over explicit fake native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "class-resource fixtures require CI Lua 5.1")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Resources(performance, hidden)
    local context = H.New()
    local env = context.env
    env.SurvivorsDragonUiDisplay = {
        classResources = true,
        hideSoulShards = hidden == true,
        performanceMode = performance,
    }
    context:Load("core/display.lua", "Display")
    local create = context.Object
    function context:Object(kind, name, parent)
        local object = create(self, kind, name, parent)
        local function Write(method) context.writes[method] = (context.writes[method] or 0) + 1 end
        function object:SetStatusBarTexture(path)
            Write("SetStatusBarTexture")
            self.statusTexture = path
        end
        function object:SetMinMaxValues(low, high)
            Write("SetMinMaxValues")
            self.minimum, self.maximum = low, high
        end
        function object:GetMinMaxValues() return self.minimum, self.maximum end
        function object:SetValue(value)
            Write("SetValue")
            self.value = value
        end
        function object:GetValue() return self.value end
        function object:SetStatusBarColor(...)
            Write("SetStatusBarColor")
            self.color = { ... }
        end
        return object
    end
    context.primary, context.phase = 80, "playing"
    env.UnitPowerType = function() return 0 end
    env.UnitMana = function() return context.primary end
    env.UnitManaMax = function() return 100 end
    env.AZS_GetPhase = function() return context.phase end
    env.DFRL.navigation = {
        IsRunPhase = function(phase)
            return phase == "playing" or phase == "paused" or phase == "choosing" or phase == "victory"
        end,
    }
    env.DFRL.playerResources = {
        SetPrimary = function(value, maximum, power) context.primaryValues = { value, maximum, power } end,
        SetAbsorb = function(value, health, maximum) context.absorbValues = { value, health, maximum } end,
    }
    env.AZS_RUN, env.AZS_RUN_UPDATED = { proc = "soul_fire", pv = 4, pm = 5 }, context.now
    local player = env.CreateFrame("Frame", "PlayerFrame", env.UIParent)
    context:Load("modules/unit/resources.lua", "Class resources")
    local row = env.SurvivorsDragonUiClassResources
    local controller = context:Controller("CHAT_MSG_ADDON")
    local meter, label, sockets = nil, nil, {}
    for _, object in ipairs(context.objects) do
        if object.parent == row then
            if object.kind == "StatusBar" then meter = object end
            if object.kind == "Texture" then table.insert(sockets, object) end
        end
    end
    for _, object in ipairs(context.objects) do
        if object.parent == meter and object.kind == "FontString" then label = object end
    end
    assert(meter and label and table.getn(sockets) == 10, "resource fixture did not discover the existing view")
    function context:SocketCount()
        local count = 0
        for _, texture in ipairs(sockets) do
            if texture:IsVisible() then count = count + 1 end
        end
        return count
    end
    function context:Primary(value)
        assert(self.primaryValues[1] == value, "shard visibility changed the primary power value")
        assert(self.primaryValues[2] == 100 and self.primaryValues[3] == 0, "primary range/type changed")
    end
    function context:Publish(proc, value, maximum)
        self:Event(controller, "CHAT_MSG_ADDON", "AZSRUN")
        self.now = self.now + 0.1
        env.AZS_RUN, env.AZS_RUN_UPDATED = { proc = proc, pv = value, pm = maximum }, self.now
        self:Call(controller, "OnUpdate", 0.01)
    end
    return context, env.DFRL.display, player, row, meter, label, controller, sockets
end

Test("shard preview, Cancel, Confirm, reset and profile normalization retain primary power in both modes", function()
    for _, performance in ipairs({ false, true }) do
        local context, display, _, row = Resources(performance)
        local env = context.env
        assert(context:SocketCount() == 9, "default shard artwork changed")
        context:Primary(80)
        local allocated = table.getn(context.objects)
        assert(display.Copy({}).hideSoulShards == false, "older profiles did not default to visible shards")
        assert(display.Copy({ hideSoulShards = "true" }).hideSoulShards == false, "invalid choice was accepted")
        assert(display.Copy({ hideSoulShards = true }).hideSoulShards, "profile copy lost the hide choice")
        display.BeginEdit()
        display.Set("hideSoulShards", true)
        assert(not row:IsShown() and context:SocketCount() == 0, "preview retained filled or empty shards")
        assert(not env.SurvivorsDragonUiDisplay.hideSoulShards, "preview saved early")
        context:Primary(80)
        display.FinishEdit(false)
        assert(context:SocketCount() == 9, "Cancel did not restore shards immediately")
        display.BeginEdit()
        display.Set("hideSoulShards", true)
        display.FinishEdit(true)
        assert(env.SurvivorsDragonUiDisplay.hideSoulShards and not row:IsShown(), "Confirm lost shard hiding")
        context.primary = 60
        context:Publish("soul_fire", 3, 5)
        context:Primary(60)
        assert(context:SocketCount() == 0, "a new resource value restored hidden shards")
        display.Reset()
        assert(not display.Get("hideSoulShards") and not display.Get("classResources"), "reset lost defaults")
        display.BeginEdit()
        display.Set("classResources", true)
        assert(context:SocketCount() == 8, "reset did not recover the current three-shard state")
        assert(table.getn(context.objects) == allocated, "visibility changes reallocated the resource view")
    end
end)

Test("hidden shards stay unbound and idle, and hidden-player changes recover on Show", function()
    for _, performance in ipairs({ false, true }) do
        local context, display, player, row, _, _, controller, sockets = Resources(performance, true)
        for _, texture in ipairs(sockets) do
            assert(not texture:GetTexture(), "disabled shards bound artwork on first load")
        end
        context:Primary(80)
        context:ResetCounts()
        context:Call(controller, "OnUpdate", 0.1)
        context:NoPresentationWrites()
        player:Hide()
        display.BeginEdit()
        context:ResetCounts()
        display.Set("hideSoulShards", false)
        context:NoPresentationWrites()
        assert(not row:IsShown(), "hidden player prepared the shard row")
        player:Show()
        assert(context:SocketCount() == 9, "Show did not recover the current shard choice")
        context:ResetCounts()
        context:Call(controller, "OnUpdate", 0.1)
        context:NoPresentationWrites()
    end
end)

Test("shard hiding preserves Rogue points, Lightwell and numeric fallbacks", function()
    for _, performance in ipairs({ false, true }) do
        local context, _, _, row, meter, label = Resources(performance, true)
        context:Publish("seal_fate", 4, 5)
        assert(context:SocketCount() == 9 and not meter:IsShown(), "shard hiding removed Rogue points")
        for _, entry in ipairs({
            { "lightwell", 3, 10, "3 / 10" },
            { "soul_fire", 4, 6, "4 / 6" },
            { "soul_fire", 3, 4.5, "3 / 4.5" },
        }) do
            context:Publish(entry[1], entry[2], entry[3])
            assert(row:IsShown() and meter:IsShown() and context:SocketCount() == 0, "numeric meter was hidden")
            assert(label:GetText() == entry[4] and meter:GetValue() == entry[2], "numeric values changed")
        end
        context:Publish("soul_fire", 0, 5)
        assert(not row:IsShown() and context:SocketCount() == 0, "empty shard sockets remained visible")
        context:Primary(80)
    end
end)

print("PASS " .. passed .. " class-resource lifecycle scenarios")
