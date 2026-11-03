-- CI only: real portrait/display owners with explicit native model boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "3D portrait fixtures require CI Lua 5.1")

local function Fixture(settings, configure)
    local c = H.New()
    local env = c.env
    local state = {
        attempts = 0,
        binds = 0,
        clears = 0,
        exists = { player = true, target = true, targettarget = true },
        identities = { player = "player", target = "target:1", targettarget = "targettarget:1" },
    }
    local create = c.Object
    function c:Object(kind, name, parent)
        local object = create(self, kind, name, parent)
        function object:SetParent(value) self.parent = value end
        if kind == "PlayerModel" then
            if not state.unsupported then
                function object:SetUnit(unit)
                    state.binds = state.binds + 1
                    if state.failBind then error("injected native model copy failure") end
                    self.unit, self.identity = unit, state.identities[unit]
                end
            end
            function object:ClearModel()
                state.clears = state.clears + 1
                self.unit, self.identity = nil, nil
            end
            function object:SetCamera(value) self.camera = value end
        end
        return object
    end
    local createFrame = env.CreateFrame
    env.CreateFrame = function(kind, name, parent)
        if kind == "PlayerModel" then
            state.attempts = state.attempts + 1
            if state.failCreate then error("injected native model allocation failure") end
        end
        return createFrame(kind, name, parent)
    end
    env.UnitExists = function(unit) return state.exists[unit] end
    env.UnitIsUnit = function(left, right) return left == right end
    env.T.GetLocalSize = function(frame) return frame:GetWidth(), frame:GetHeight() end
    env.ReloadUI = function() state.reloaded = true end
    c.owners = {}
    for _, entry in ipairs({
        { "player", "PlayerFrame" },
        { "target", "TargetFrame" },
        { "targettarget", "TargetofTargetFrame" },
    }) do
        local owner = env.CreateFrame("Frame", entry[2], env.UIParent)
        local portrait = owner:CreateTexture(nil, "ARTWORK")
        portrait:SetWidth(58)
        portrait:SetHeight(58)
        owner.portrait = portrait
        c.owners[entry[1]] = owner
    end
    env.TargetofTargetPortrait = env.TargetofTargetFrame.portrait
    env.PlayerFrameTexture = env.PlayerFrame:CreateTexture(nil, "OVERLAY")
    env.SurvivorsDragonUiDisplay = settings
    if configure then configure(c, state, env) end
    c:Load("core/display.lua", "Display")
    c:Load("modules/unit/portraits.lua", "AnimatedPortraits")
    c.events = c:Controller("UNIT_PORTRAIT_UPDATE")
    function c:Choose(key, value)
        env.DFRL.display.BeginEdit()
        env.DFRL.display.Set(key, value)
    end
    function c:Models()
        local models = {}
        for _, object in ipairs(self.objects) do
            if object.kind == "PlayerModel" then table.insert(models, object) end
        end
        return models
    end
    function c:Backings()
        local count = 0
        for _, object in ipairs(self.objects) do
            if object.kind == "Texture" and object.parent and object.parent.kind == "PlayerModel" then
                count = count + 1
            end
        end
        return count
    end
    function c:Stills(alpha)
        for _, owner in pairs(self.owners) do
            assert(owner.portrait:GetAlpha() == alpha, "native still fallback has the wrong visibility")
        end
    end
    return c, state, env
end

do
    local c, state, env = Fixture()
    local allocated = #c.objects
    for _ = 1, 10 do
        c:Event(c.events, "UNIT_PORTRAIT_UPDATE", "player")
        c:Event(c.events, "UNIT_INVENTORY_CHANGED", "target")
        c:Event(c.events, "PLAYER_TARGET_CHANGED")
        env.TargetFrame:Hide()
        env.TargetFrame:Show()
    end
    assert(state.attempts == 0 and #c:Models() == 0 and c:Backings() == 0)
    assert(#c.objects == allocated and env.PlayerFrameTexture:GetParent() == env.PlayerFrame)
    c:Stills(1)
    c:Choose("playerPortrait3D", true)
    local models = c:Models()
    assert(#models == 3 and c:Backings() == 66 and state.binds == 3)
    assert(env.SurvivorsDragonUiDisplay == nil, "3D preview saved before Confirm")
    allocated = #c.objects
    for _, model in ipairs(models) do
        assert(model:IsVisible() and model.camera == 0 and model:GetParent().sduiPortraitModel == model)
        assert(math.abs(model:GetWidth() - 56 / math.sqrt(2)) < 0.000001)
        c:Call(model, "OnUpdateModel")
    end
    c:Stills(0)
    local binds = state.binds
    c:Choose("showPlayerName", false)
    assert(state.binds == binds and #c.objects == allocated, "unrelated settings rebound native copies")
    env.DFRL.display.FinishEdit(false)
    c:Stills(1)
    for _, model in ipairs(models) do
        assert(not model:IsShown() and model.unit == nil)
        c:Call(model, "OnUpdateModel")
    end
    c:Stills(1)
    c:Choose("playerPortrait3D", true)
    assert(#c.objects == allocated and state.attempts == 3, "reenabling allocated replacement models")
    c:Choose("hidePortraits", true)
    c:Stills(0)
    c:Choose("hidePortraits", false)
    c:Stills(1)
    c:Choose("performanceMode", true)
    for _, model in ipairs(models) do
        assert(not model:IsShown())
        c:Call(model, "OnUpdateModel")
    end
    c:Stills(1)
    c:Choose("performanceMode", false)
    assert(state.attempts == 3 and #c.objects == allocated)
    state.identities.target = "target:2"
    c:Event(c.events, "UNIT_PORTRAIT_UPDATE", "target")
    assert(env.TargetFrame.sduiPortraitModel.identity == "target:2", "reused model retained the old target")
    env.DFRL.display.FinishEdit(true)
    assert(env.SurvivorsDragonUiDisplay.playerPortrait3D, "Confirm lost the selected portrait mode")
    env.DFRL.display.BeginEdit()
    env.DFRL.display.Load({ playerPortrait3D = false })
    for _, model in ipairs(models) do
        assert(not model:IsShown(), "profile preview retained an unwanted model")
    end
    env.DFRL.display.FinishEdit(false)
    assert(env.PlayerFrame.sduiPortraitModel:IsVisible(), "profile Cancel lost the confirmed 3D choice")
    env.DFRL.display.Reset()
    c:Stills(1)
    for _, model in ipairs(models) do
        assert(not model:IsShown(), "reset retained 3D presentation")
    end
    c:Choose("playerPortrait3D", true)
    assert(state.attempts == 3 and #c.objects == allocated, "display transactions duplicated native models")
    c:Event(c.events, "PLAYER_LEAVING_WORLD")
    c:Stills(1)
    for _, model in ipairs(models) do
        assert(not model:IsShown() and model.unit == nil)
    end
    c:Event(c.events, "PLAYER_ENTERING_WORLD")
    assert(state.attempts == 3 and #c.objects == allocated)
    env.ReloadUI()
    assert(state.reloaded)
    c:Stills(1)
    for _, model in ipairs(models) do
        assert(not model:IsShown() and model.unit == nil)
    end
end

for _, suppressed in ipairs({ "performanceMode", "hidePortraits" }) do
    local c, state = Fixture({ playerPortrait3D = true, [suppressed] = true })
    assert(state.attempts == 0 and c:Backings() == 0, "suppressed saved choice prepared native models")
    c:Choose(suppressed, false)
    assert(state.attempts == 3 and c:Backings() == 66)
end

for _, unavailable in ipairs({ "hidden", "absent" }) do
    local c, state, env = Fixture({ playerPortrait3D = true }, function(c, state)
        if unavailable == "hidden" then
            c.owners.target:Hide()
            c.owners.targettarget:Hide()
        else
            state.exists.target, state.exists.targettarget = false, false
        end
    end)
    assert(state.attempts == 1 and c:Backings() == 22, "unavailable units prepared unused models")
    state.exists.target = true
    env.TargetFrame:Show()
    c:Event(c.events, "PLAYER_TARGET_CHANGED")
    assert(state.attempts == 2 and env.TargetFrame.sduiPortraitModel:IsVisible())
    state.exists.targettarget = true
    env.TargetofTargetFrame:Show()
    c:Event(c.events, "UNIT_TARGET", "target")
    assert(state.attempts == 3 and c:Backings() == 66)
end

do
    local c, state = Fixture({ playerPortrait3D = true }, function(_, state) state.exists.player = false end)
    assert(state.attempts == 0 and c:Backings() == 0, "out-of-world portraits prepared native models")
    state.exists.player = true
    c:Event(c.events, "PLAYER_ENTERING_WORLD")
    assert(state.attempts == 3 and c:Backings() == 66)
end

do
    local c, state, env = Fixture(nil, function(c, _, env)
        local border = env.CreateFrame("Frame", nil, c.owners.player)
        border:SetFrameLevel(6)
        c.owners.player.portrait:SetParent(border)
        env.PlayerFrameTexture:SetParent(border)
    end)
    local border = env.PlayerFrameTexture:GetParent()
    c:Choose("playerPortrait3D", true)
    assert(env.PlayerFrame.sduiPortraitModel:GetFrameLevel() == 6)
    assert(env.PlayerFrameTexture:GetParent() == border, "lazy creation moved prepared gold artwork")
    assert(state.attempts == 3)
end

for _, fault in ipairs({ "failCreate", "unsupported", "failBind" }) do
    local c, state = Fixture(nil, function(_, state) state[fault] = true end)
    assert(state.attempts == 0, "disabled portraits touched a failing native boundary")
    c:Choose("playerPortrait3D", true)
    local allocated = #c.objects
    assert(state.attempts == 3)
    c:Stills(1)
    for _, model in ipairs(c:Models()) do
        assert(not model:IsShown())
        c:Call(model, "OnUpdateModel")
    end
    c:Stills(1)
    c:Choose("playerPortrait3D", false)
    c:Choose("playerPortrait3D", true)
    c:Event(c.events, "PLAYER_ENTERING_WORLD")
    assert(state.attempts == 3 and #c.objects == allocated, "failed preparation kept allocating native models")
    c:Stills(1)
end

print(
    "PASS 3D portraits prepare only eligible first use and retain native fallback, pooling, settings and world cleanup"
)
