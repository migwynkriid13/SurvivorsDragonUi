-- CI only: complete production modules over explicit native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "passive cadence fixtures require the CI Lua 5.1 interpreter")

do
    local context = H.New()
    local env = context.env
    local phase, now = "playing", 100
    env.DFRL.navigation = { IsRunPhase = function(value) return value == "playing" or value == "paused" end }
    env.AZS_GetPhase = function() return phase end
    env.AZS_GetRunTime = function()
        context.reads.clock = (context.reads.clock or 0) + 1
        return now
    end
    env.AZS_UNITS, env.AZS_UNITS_UPDATED = {}, 1
    env.AZS_GetGuardians = function()
        context.reads.guardians = (context.reads.guardians or 0) + 1
        return { { id = 7, hp = 50, hpm = 100 } }
    end
    context:Load("modules/ui/guardians.lua", "GuardianRoster")
    local roster = env.DFRL.guardians
    roster.AcceptLairs({
        { index = 1, id = 7, state = "awake", name = "Guardian" },
        { index = 2, id = 0, state = "empty", left = 0 },
    }, 1, 1)
    context:ResetCounts()
    local snapshot = roster.GetSnapshot()
    assert(not context.reads.clock, "a roster without returning lairs sampled a countdown clock")
    assert(snapshot.rows[1].hp == 50 and snapshot.rows[1].healthFraction == 0.5)
    assert(context.reads.guardians == 1, "living guardians lost native health sampling")
    assert(snapshot.rows[2].status == "due" and snapshot.rows[2].remaining == 0)
    roster.AcceptLairs({
        { index = 1, id = 0, state = "empty", left = 20 },
        { index = 2, id = 0, state = "empty", left = 30 },
    }, 2, 2)
    now = 101
    context:ResetCounts()
    snapshot = roster.GetSnapshot(snapshot)
    assert(context.reads.clock == 1, "returning lairs sampled independent native clocks")
    assert(not context.reads.guardians, "empty/returning lairs queried an unused guardian health list")
    assert(snapshot.rows[1].remaining == 19 and snapshot.rows[2].remaining == 29)
    phase = "paused"
    context:ResetCounts()
    snapshot = roster.GetSnapshot(snapshot)
    assert(context.reads.clock == 1 and snapshot.rows[1].remaining == 19, "pause changed native countdown semantics")
    now = nil
    context:ResetCounts()
    snapshot = roster.GetSnapshot(snapshot)
    assert(context.reads.clock == 1 and snapshot.rows[1].remaining == 20 and snapshot.rows[2].remaining == 30)
    now = 100.5
    snapshot = roster.GetSnapshot(snapshot)
    assert(snapshot.rows[1].remaining == 19.5, "missing clock data did not retry on the next snapshot")
    phase = "ready"
    context:ResetCounts()
    snapshot = roster.GetSnapshot(snapshot)
    assert(snapshot.status == "inactive" and #snapshot.rows == 0 and not context.reads.clock)
end
print("PASS guardian roster samples native countdown time only when used and shares missing samples within one pass")

do
    local context = H.New()
    local env = context.env
    context.phase, context.count = "playing", 3
    env.AZS_RUN, env.AZS_RUN_UPDATED = {}, 1
    env.AZS_GetPhase = function()
        context.reads.phase = (context.reads.phase or 0) + 1
        return context.phase
    end
    env.AZS_GetStoredLevels = function()
        context.reads.levels = (context.reads.levels or 0) + 1
        return context.count
    end
    env.AZS_OpenStoredLevels = function() context.opened = true end
    env.AZS_IsHudShown = function(part)
        assert(part == "levels")
        context.reads.hud = (context.reads.hud or 0) + 1
        return context.nativeShown
    end
    env.AZS_SetHudShown = function(part, shown)
        assert(part == "levels")
        context.writes.hud = (context.writes.hud or 0) + 1
        if not context.rejectHud then context.nativeShown = shown end
    end
    env.UnitClass = function(unit)
        assert(unit == "player")
        return "Mage", "MAGE"
    end
    env.tostring = function(value)
        if type(value) == "number" then context.reads.formats = (context.reads.formats or 0) + 1 end
        return tostring(value)
    end
    env.DFRL.locale.Bind = function() end
    env.DFRL.locale.Width = function(_, text) return #text * 7 end
    env.DFRL.layout.IsHidden = function() return context.hidden end
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        function object:SetScale(value) self.scale = value end
        function object:GetEffectiveScale()
            return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        function object:GetStringWidth() return #self:GetText() * 7 end
        function object:RegisterForClicks(value) assert(value == "LeftButtonUp") end
        function object:SetBlendMode(value) assert(value == "ADD") end
        return object
    end
    function env.UIParent:GetEffectiveScale() return 1 end
    context:Load("core/hud.lua")
    context:Load("modules/ui/levels.lua", "StoredLevels")
    local button = env.SurvivorsDragonUiStoredLevels
    local controller = context:Controller("PLAYER_ENTERING_WORLD")
    local label
    for _, object in ipairs(context.objects) do
        if object.kind == "FontString" and object:GetText() == "3" then label = object end
    end
    assert(label and button:IsVisible() and context.nativeShown == false)
    assert(context.reads.hud == 2, "initial takeover did not read back the setter")
    assert(button:GetScript("OnUpdate"), "normal stored-level pulse did not start")
    context:SetSetting("performanceMode", true)
    assert(button:IsVisible() and label:GetText() == "3", "Performance Mode hid the stored-level information")
    assert(not button:GetScript("OnUpdate"), "Performance Mode retained the stored-level pulse")
    for _, object in ipairs(context.objects) do
        if object.kind == "Texture" and (object.texture or ""):find("Glow.blp", 1, true) then
            assert(not object:IsShown(), "Performance Mode retained the gold halo")
        end
    end
    context:ResetCounts()
    context:Call(button, "OnUpdate", 0.5)
    context:NoPresentationWrites()
    context:SetLayoutHidden(true)
    context:SetSetting("performanceMode", false)
    assert(not button:GetScript("OnUpdate"), "hidden mode exit restarted the stored-level pulse")
    context:SetLayoutHidden(false)
    assert(button:GetScript("OnUpdate"), "Show did not restore the configured stored-level pulse")
    local function Tick() context:Call(controller, "OnUpdate", 0.1) end
    context:ResetCounts()
    for _ = 1, 10 do
        Tick()
    end
    assert(context.reads.phase == 10 and context.reads.levels == 10, "native state polling changed")
    assert(context.reads.hud == 10 and not context.writes.hud, "settled ownership repeated its readback")
    assert(not context.reads.formats, "unchanged stored-level counts were formatted repeatedly")
    label.text = "native reset"
    context:ResetCounts()
    Tick()
    assert(label:GetText() == "3" and context.writes.SetText == 1 and not context.reads.formats)
    context.nativeShown = true
    context:ResetCounts()
    Tick()
    assert(context.reads.hud == 2 and context.writes.hud == 1 and context.nativeShown == false)
    context.nativeShown, context.rejectHud = true, true
    Tick()
    assert(not button:IsShown() and label:GetText() == "", "unsuccessful takeover retained a duplicate custom view")
    context.rejectHud = false
    context:ResetCounts()
    Tick()
    assert(
        button:IsVisible() and label:GetText() == "3" and context.reads.formats == 1,
        "takeover retry lost the count"
    )
    context.hidden = true
    context:SetLayoutHidden(true)
    context.count = 4
    context:ResetCounts()
    Tick()
    assert(not context.reads.formats and label:GetText() == "3", "hidden view formatted a new count")
    context.hidden = false
    context:SetLayoutHidden(false)
    Tick()
    assert(label:GetText() == "4" and context.reads.formats == 1, "Show did not present the latest native count")
    context.count, context.rejectHud = 0, true
    Tick()
    assert(not button:IsShown() and context.nativeShown == false, "failed restore showed a stale replacement")
    context.rejectHud = false
    Tick()
    assert(context.nativeShown == true, "a no-op native restore discarded its retry target")
    context.count = 4
    Tick()
    assert(button:IsVisible() and context.nativeShown == false, "restore retry prevented later takeover")
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    assert(not controller:GetScript("OnUpdate"), "stored levels retained their out-of-world updater")
    context:ResetCounts()
    Tick()
    assert(not context.reads.phase and not context.reads.levels and not context.reads.formats)
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    assert(controller:GetScript("OnUpdate"), "stored levels did not rearm on world entry")
end
print(
    "PASS stored levels cache numeric captions, retain actual-state repair and preserve native takeover readback/retry"
)
