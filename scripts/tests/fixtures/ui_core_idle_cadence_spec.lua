-- CI only: production controllers over explicit native health/geometry inputs.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "idle cadence fixtures require CI Lua 5.1")

local function Warning()
    local context = H.New()
    local env = context.env
    context.health, context.maximum, context.dead = 100, 100, false
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        function object:SetGradientAlpha(...)
            context.writes.gradient = (context.writes.gradient or 0) + 1
            self.gradient = { ... }
        end
        return object
    end
    env.SetCVar = function(name, value) assert(name == "CameraDistanceMaxFactor" and value == 3) end
    env.UnitHealthMax = function(unit)
        assert(unit == "player")
        context.reads.maximum = (context.reads.maximum or 0) + 1
        return context.maximum
    end
    env.UnitHealth = function(unit)
        assert(unit == "player")
        context.reads.health = (context.reads.health or 0) + 1
        return context.health
    end
    env.UnitIsDeadOrGhost = function(unit)
        assert(unit == "player")
        context.reads.dead = (context.reads.dead or 0) + 1
        return context.dead
    end
    context:Load("modules/ui/ui.lua", "Ui")
    context.controller = context:Controller("UNIT_MAXHEALTH")
    context.warning = env.DFRL_LowHpWarnFrame
    for _, object in ipairs(context.objects) do
        if object.parent == context.warning and object.kind == "Texture" then
            context.top = object
            break
        end
    end
    assert(context.top, "missing production warning edge")
    function context:Tick(delta) self:Call(self.controller, "OnUpdate", delta) end
    return context
end

do
    local context = Warning()
    assert(not context.controller:GetScript("OnUpdate") and not context.warning:IsShown())
    context:ResetCounts()
    context:Tick(10)
    context:Event(context.controller, "UNIT_HEALTH", "target")
    assert(not next(context.reads) and not next(context.writes), "healthy/foreign-unit warning kept idle work")
    context.health = 35
    context:Event(context.controller, "UNIT_HEALTH", "player")
    assert(context.controller:GetScript("OnUpdate") and not context.warning:IsShown())
    context:ResetCounts()
    context:Tick(0.02)
    assert(not context.writes.gradient, "warning painted before its existing50ms step")
    context:Tick(0.03)
    local firstAlpha = 0.7 * 0.55 * (0.3 + 0.7 * (math.sin(0.225) + 1) / 2)
    assert(context.writes.gradient == 4 and math.abs(context.top.gradient[9] - firstAlpha) < 1e-12)
    assert(not next(context.reads), "warning animation repeated native health/death reads")
    context.health = 28
    context:Event(context.controller, "UNIT_HEALTH", "player")
    context:ResetCounts()
    context:Tick(0.05)
    local nextAlpha = 0.7 * 0.64 * (0.3 + 0.7 * (math.sin(0.485) + 1) / 2)
    assert(context.writes.gradient == 4 and math.abs(context.top.gradient[9] - nextAlpha) < 1e-12)
    assert(not next(context.reads), "changed warning intensity introduced animation polling")
    context.health = 71
    context:Event(context.controller, "UNIT_HEALTH", "player")
    assert(not context.warning:IsShown() and not context.controller:GetScript("OnUpdate"))
    context.health, context.dead = 35, true
    context:Event(context.controller, "PLAYER_DEAD")
    assert(not context.controller:GetScript("OnUpdate"), "dead player armed the warning")
    context.dead = false
    context:Event(context.controller, "PLAYER_ALIVE")
    context:Tick(0.05)
    assert(math.abs(context.top.gradient[9] - firstAlpha) < 1e-12, "warning retirement did not reset pulse phase")
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(not context.warning:IsShown() and not context.controller:GetScript("OnUpdate"))
    context:ResetCounts()
    context:Event(context.controller, "UNIT_HEALTH", "player")
    context:Tick(10)
    assert(not next(context.reads) and not next(context.writes), "retired warning continued work")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    assert(context.controller:GetScript("OnUpdate"), "world entry did not reread current native health")
    context:Tick(0.05)
    assert(math.abs(context.top.gradient[9] - firstAlpha) < 1e-12)
    context.health, context.maximum = 100, 100
    context:Event(context.controller, "UNIT_MAXHEALTH", "player")
    assert(not context.controller:GetScript("OnUpdate"))
    context.maximum = 200
    context:Event(context.controller, "UNIT_MAXHEALTH", "player")
    assert(context.controller:GetScript("OnUpdate"), "maximum-health change did not activate warning")
    context.health, context.maximum = 70, 100
    context:Event(context.controller, "UNIT_HEALTH", "player")
    assert(context.controller:GetScript("OnUpdate"), "exact70percent threshold changed")
    context.maximum = 0
    context:Event(context.controller, "UNIT_MAXHEALTH", "player")
    assert(not context.controller:GetScript("OnUpdate"), "unavailable maximum invented low health")
    context:Event(context.controller, "PLAYER_LOGOUT")
    assert(not context.controller:GetScript("OnUpdate"))
end
print("PASS low-health warning uses native events and only animates eligible warnings at its existing20Hz")

do
    local context = Warning()
    context.health = 35
    context:Event(context.controller, "UNIT_HEALTH", "player")
    context:Tick(0.05)
    context:SetSetting("performanceMode", true)
    assert(
        context.warning:IsShown() and not context.controller:GetScript("OnUpdate"),
        "Performance Mode lost static low-health feedback or retained pulse work"
    )
    assert(math.abs(context.top.gradient[9] - 0.7 * 0.55) < 1e-12, "static warning changed native health intensity")
    context:ResetCounts()
    context:Tick(10)
    context:NoPresentationWrites()
    assert(not next(context.reads), "static low-health warning polled native health")
    context.health = 28
    context:Event(context.controller, "UNIT_HEALTH", "player")
    assert(math.abs(context.top.gradient[9] - 0.7 * 0.64) < 1e-12, "static warning ignored a new native health value")
    assert(not context.controller:GetScript("OnUpdate"), "static health update restarted warning animation")
    context:SetSetting("performanceMode", false)
    assert(context.controller:GetScript("OnUpdate"), "normal warning pulse did not resume")
    context:SetSetting("performanceMode", true)
    context.health = 100
    context:Event(context.controller, "UNIT_HEALTH", "player")
    assert(
        not context.warning:IsShown() and not context.controller:GetScript("OnUpdate"),
        "healthy native state retained a static warning"
    )
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    context:ResetCounts()
    context:Tick(10)
    assert(not next(context.reads) and not next(context.writes), "static warning survived world retirement")
end
print("PASS Performance Mode keeps event-driven static low-health feedback and restores normal pulse eligibility")

local function Language(settled)
    local context = H.New()
    local env = context.env
    env.AZS_GetPhase = function()
        context.reads.phase = (context.reads.phase or 0) + 1
        return "playing"
    end
    env.AZS_ZONE = settled and { zone = "test", zsub = "French" } or {}
    context:Load("core/localization.lua")
    env.DFRL.locale.data.en = { ui = {}, native = { ["zone.test.subtitle"] = "English" } }
    env.DFRL.locale.data.fr = { ui = {}, native = { ["zone.test.subtitle"] = "French" } }
    context.modules.Language()
    context.controller = context:Controller("CHAT_MSG_ADDON")
    return context
end

do
    local context = Language(false)
    assert(context.controller:GetScript("OnUpdate"))
    context:ResetCounts()
    context:Call(context.controller, "OnUpdate", 0.1)
    assert(not context.reads.phase, "pending language sampled before200ms")
    context:Call(context.controller, "OnUpdate", 0.1)
    assert(context.reads.phase == 1 and context.controller:GetScript("OnUpdate"))
    context.env.AZS_ZONE = { zone = "test", zsub = "French" }
    context:Event(context.controller, "CHAT_MSG_ADDON", "AZSZONE")
    context:Call(context.controller, "OnUpdate", 0.2)
    assert(context.env.DFRL.locale.code == "fr" and not context.controller:GetScript("OnUpdate"))
    context:ResetCounts()
    context:Call(context.controller, "OnUpdate", 10)
    assert(not next(context.reads) and not next(context.writes), "settled language retained idle callbacks")
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    assert(context.controller:GetScript("OnUpdate"))
    context:Event(context.controller, "PLAYER_LEAVING_WORLD")
    assert(not context.controller:GetScript("OnUpdate"))
    context:Event(context.controller, "CHAT_MSG_ADDON", "AZSZONE")
    assert(context.controller:GetScript("OnUpdate"), "zone receipt did not rearm existing discovery")
    context:Event(context.controller, "PLAYER_LOGOUT")
    assert(not context.controller:GetScript("OnUpdate"))
    context = Language(true)
    assert(context.env.DFRL.locale.code == "fr" and not context.controller:GetScript("OnUpdate"))
end
print("PASS language discovery detaches once settled and rearms through existing native events")

local function Layout()
    local context = H.New()
    local env = context.env
    context.settings.layoutShowGrid = false
    local function Geometry(object)
        local getWidth, getHeight = object.GetWidth, object.GetHeight
        function object:GetWidth()
            if self == env.UIParent then context.reads.viewport = (context.reads.viewport or 0) + 1 end
            return getWidth(self)
        end
        function object:GetHeight() return getHeight(self) end
        function object:GetScale() return self.scale or 1 end
        function object:GetEffectiveScale() return self:GetScale() end
        function object:GetLeft()
            if self.unready then return nil end
            return self.left or 0
        end
        function object:GetRight() return (self:GetLeft() or 0) + self:GetWidth() end
        function object:GetTop() return self.top or self:GetHeight() end
        function object:GetBottom() return self:GetTop() - self:GetHeight() end
        function object:GetNumPoints() return self.point and 1 or 0 end
        function object:GetPoint() return unpack(self.point or {}) end
        function object:ClearAllPoints() self.point = nil end
        function object:SetPoint(point, relative, relativePoint, x, y)
            self.point = { point, relative, relativePoint, x, y }
            if point == "TOPLEFT" then
                self.left = (relative:GetLeft() or 0) + (x or 0)
                self.top = relative:GetTop() + (y or 0)
            end
        end
        function object:SetParent(parent) self.parent = parent end
        function object:SetMovable(value) self.movable = value end
        function object:SetUserPlaced(value) self.userPlaced = value end
        function object:StopMovingOrSizing() self.stopped = true end
        function object:RegisterForDrag(button) self.dragButton = button end
        function object:SetBackdrop(value) self.backdrop = value end
        function object:SetBackdropBorderColor(...) self.border = { ... } end
        function object:EnableMouseWheel(value) self.wheel = value end
        return object
    end
    Geometry(env.UIParent)
    env.UIParent.width, env.UIParent.height, env.UIParent.top = 1024, 768, 768
    local createFrame = env.CreateFrame
    env.CreateFrame = function(kind, name, parent) return Geometry(createFrame(kind, name, parent)) end
    env.IsShiftKeyDown = function() return false end
    env.GetCursorPosition = function() return context.cursorX or 200, context.cursorY or 300 end
    env.DFRL.locale.Bind = function(label) return label end
    env.T.CreateEditorButton = function(parent)
        local button = env.CreateFrame("Button", nil, parent)
        button.label = button:CreateFontString(nil, "OVERLAY")
        return button
    end
    env.T.CreateEditModeSelection = function(handle)
        -- Artwork and the moving-mode manager have separate production mocks.
        return function(selected) handle.selected = selected end
    end
    context:Load("core/layout.lua", "Layout")
    context.controller = context:Controller("PLAYER_LOGOUT")
    function context:Tick(delta) self:Call(self.controller, "OnUpdate", delta) end
    return context, env.DFRL.layout
end

do
    local context, layout = Layout()
    context:ResetCounts()
    context:Tick(0.001)
    assert(not context.reads.viewport, "unready Layout sampled native viewport")
    layout.Ready()
    context:Tick(0.001)
    assert(context.reads.viewport, "first ready frame skipped viewport recovery")
    context:ResetCounts()
    for _ = 1, 5 do
        context:Tick(0.01)
    end
    assert(not context.reads.viewport, "idle Layout sampled viewport every rendered frame")
    context:Tick(0.05)
    assert(context.reads.viewport == 1, "idle viewport sample lost its100ms cadence")
    context:ResetCounts()
    context:Event(context.controller, "PLAYER_ENTERING_WORLD")
    context:Tick(0.001)
    assert(context.reads.viewport, "world restore waited for idle sampling")
    -- Exercise full-editor cadence without preparing the separate moving UI.
    layout.BeginEdit()
    context:ResetCounts()
    context:Tick(0.001)
    assert(context.reads.viewport == 1, "dirty editor did not sample viewport immediately")
    context:ResetCounts()
    for _ = 1, 4 do
        context:Tick(0.001)
    end
    assert(not context.reads.viewport, "settled editing retained frame-cadence viewport reads")
    context:Tick(0.09)
    assert(not context.reads.viewport, "settled editor refreshed before100ms")
    context:Tick(0.01)
    assert(context.reads.viewport == 1, "settled editor lost its100ms refresh")
    layout.CancelEdit()

    local frame = context.env.CreateFrame("Frame", nil, context.env.UIParent)
    frame.unready, frame.width, frame.height = true, 240, 40
    layout.Register(
        "test",
        frame,
        function(owner) owner:SetPoint("TOPLEFT", context.env.UIParent, "TOPLEFT", 60, -80) end
    )
    context:ResetCounts()
    context:Tick(0.001)
    context:Tick(0.001)
    assert(context.reads.viewport >= 2, "unresolved default placement was throttled")
    frame.unready = false
    context:Tick(0.001)
    layout.BeginEdit()
    context:Tick(0.001)
    local handle
    for _, object in ipairs(context.objects) do
        if object.parent == context.env.UIParent and object:GetScript("OnDragStart") then handle = object end
    end
    assert(handle, "missing production Layout move handle")
    context:Call(handle, "OnDragStart")
    context.cursorX = 205
    context:ResetCounts()
    context:Tick(0.001)
    assert(context.reads.viewport == 1, "active drag did not share its fresh frame viewport sample")
    assert(math.abs(frame.left - 65) < 1e-9, "active drag waited for idle sampling")
    context.cursorX = 209
    context:Call(handle, "OnDragStop")
    assert(math.abs(frame.left - 69) < 1e-9 and frame.stopped, "drag release lost its final native cursor sample")
    assert(math.abs(layout.Snapshot().test.x - 69 / 1024) < 1e-9)
    context:Event(context.controller, "PLAYER_LOGOUT")
    assert(not layout.IsEditing())
end
print("PASS Layout bounds idle viewport sampling while preserving readiness, editing and final drag samples")
