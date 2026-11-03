-- CI only: exact production resting icon and portrait-shape helpers.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "player status fixtures require CI Lua 5.1")

local file = assert(io.open("modules/unit/player.lua", "r"))
local source = file:read("*a")
file:close()
assert(not source:find("CreatePulse", 1, true), "retired portrait pulse construction remains")
assert(not source:find("UI-Player-Status.blp", 1, true), "retired portrait pulse artwork remains bound")
assert(not source:find("UIUnitFrameRestingFlipbook", 1, true), "retired resting animation sheet remains bound")

for _, performance in ipairs({ false, true }) do
    local context = H.New()
    local env = context.env
    context.settings.performanceMode = performance
    context.settings.roundPlayerPortrait, context.settings.hidePortraits = false, false
    env.PlayerFrame = env.CreateFrame("Frame", nil, env.UIParent)
    env.tex = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\unitframes\\"
    local resting, reads, borderUpdates = false, 0, 0
    env.IsResting = function()
        reads = reads + 1
        return resting
    end
    env.updateBorder = function(path)
        borderUpdates = borderUpdates + 1
        context.borderPath = path
    end
    env.UpdateHealthWidth = function() end
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        local setCrop = object.SetTexCoord
        function object:SetTexCoord(...)
            setCrop(self, ...)
            self.crop = { ... }
        end
        return object
    end
    local chunk = assert(loadfile(assert(arg[1], "missing extracted player status source")))
    setfenv(chunk, env)
    local status = chunk()
    status.Resting()
    status.Shape()
    local controller = context:Controller("PLAYER_UPDATE_RESTING")
    local texture
    for _, object in ipairs(context.objects) do
        if object.texture == env.tex .. "Resting.blp" then texture = object end
    end
    assert(texture, "static resting icon was removed")
    local indicator, prepared = texture:GetParent(), #context.objects
    assert(not indicator:IsShown(), "inactive resting status showed its icon")
    local function Static()
        local crop = texture.crop
        assert(crop[1] == 0 and crop[2] == 60 / 64 and crop[3] == 0 and crop[4] == 60 / 64)
        for _, object in ipairs(context.objects) do
            assert(not object:GetScript("OnUpdate"), "player status installed an animation worker")
        end
        assert(#context.objects == prepared, "player status prepared additional decoration")
    end
    Static()
    resting = true
    context:Event(controller, "PLAYER_UPDATE_RESTING")
    assert(indicator:IsVisible(), "native resting event failed to show the static icon")
    local previousReads, previousBorders = reads, borderUpdates
    context:ResetCounts()
    for _ = 1, 60 do
        context:Call(indicator, "OnUpdate", 1 / 60)
        context:Call(controller, "OnUpdate", 1 / 60)
    end
    assert(reads == previousReads, "static resting icon kept polling native status")
    context:NoPresentationWrites()
    context:SetSetting("performanceMode", not performance)
    status.Shape()
    assert(borderUpdates == previousBorders, "Performance Mode rebuilt an unchanged static portrait border")
    assert(indicator:IsVisible(), "mode change hid a valid static resting icon")
    context:NoPresentationWrites()
    Static()
    context:SetSetting("hidePortraits", true)
    status.Shape()
    assert(not indicator:IsShown(), "hidden portraits retained their resting icon")
    context:SetSetting("hidePortraits", false)
    status.Shape()
    assert(indicator:IsVisible(), "portrait recovery lost current native resting state")
    env.PlayerFrame:Hide()
    assert(not indicator:IsVisible(), "resting icon escaped parent hiding")
    resting = false
    context:Event(controller, "PLAYER_UPDATE_RESTING")
    env.PlayerFrame:Show()
    assert(not indicator:IsShown(), "owner recovery replayed expired resting status")
    resting = true
    context:Event(controller, "PLAYER_UPDATE_RESTING")
    context:SetSetting("roundPlayerPortrait", true)
    status.Shape()
    assert(context.borderPath == env.tex .. "UI-TargetingFrameDF1.blp")
    assert(indicator:IsVisible(), "round portrait selection lost the static resting icon")
    Static()
end
print("PASS static resting icons retain native visibility and portrait choices without pulse art or animation workers")
