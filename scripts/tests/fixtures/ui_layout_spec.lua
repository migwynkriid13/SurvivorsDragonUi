-- CI only: production Layout with explicit fake native geometry and controls.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "Layout fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
context.settings.layoutShowGrid = false
local function Count(name) context.writes[name] = (context.writes[name] or 0) + 1 end
local function Geometry(object)
    function object:GetScale() return self.scale or 1 end
    function object:GetEffectiveScale() return self:GetScale() end
    function object:GetLeft() return self.left or 0 end
    function object:GetRight() return self:GetLeft() + self:GetWidth() end
    function object:GetTop() return self.top or self:GetHeight() end
    function object:GetBottom() return self:GetTop() - self:GetHeight() end
    function object:GetNumPoints() return self.point and 1 or 0 end
    function object:GetPoint() return unpack(self.point or {}) end
    function object:ClearAllPoints()
        Count("ClearAllPoints")
        self.point = nil
    end
    function object:SetPoint(point, relative, relativePoint, x, y)
        Count("SetPoint")
        self.point = { point, relative, relativePoint, x, y }
        if point == "TOPLEFT" then
            self.left = relative:GetLeft() + (x or 0)
            self.top = relative:GetTop() + (y or 0)
        end
    end
    function object:SetParent(parent) self.parent = parent end
    function object:SetMovable(value) self.movable = value end
    function object:SetUserPlaced(value) self.userPlaced = value end
    function object:StopMovingOrSizing() self.stopped = true end
    function object:RegisterForDrag(button) self.dragButton = button end
    function object:SetBackdrop(backdrop)
        if context.failBackdrop then
            context.failBackdrop = false
            error("injected native handle preparation failure")
        end
        self.backdrop = backdrop
    end
    function object:SetBackdropBorderColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
    function object:EnableMouse(value)
        Count("EnableMouse")
        self.mouse = value
    end
    function object:EnableMouseWheel(value) self.wheel = value end
    return object
end
Geometry(env.UIParent)
env.UIParent.width, env.UIParent.height = 1024, 768
local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent) return Geometry(createFrame(kind, name, parent)) end
env.IsShiftKeyDown = function() return false end
env.DFRL.locale.Bind = function(label) return label end
env.T.CreateEditorButton = function(parent)
    local button = env.CreateFrame("Button", nil, parent)
    button.label = button:CreateFontString(nil, "OVERLAY")
    context.confirm = button
    return button
end
env.T.CreateEditModeSelection = function(handle)
    -- Explicit drawing boundary; the separate retail fixture loads the real art factory.
    handle:SetBackdrop({ edgeFile = "TEST_SELECTION" })
    return function(selected) handle.selected = selected end
end
context:Load("core/layout.lua", "Layout")
local layout = env.DFRL.layout
local controller = context:Controller("PLAYER_LOGOUT")
local function Anchor(x, y)
    return function(frame)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", x, y)
    end
end
local function Handles()
    local result = {}
    for _, object in ipairs(context.objects) do
        if object.parent == env.UIParent and object:GetScript("OnDragStart") then result[#result + 1] = object end
    end
    return result
end
local function Tick() context:Call(controller, "OnUpdate", 0.1) end
local function Group(key, options, hidden)
    local frame = env.CreateFrame("Frame", nil, env.UIParent)
    frame.width, frame.height = 240, 40
    if hidden then frame:Hide() end
    local count = #context.objects
    layout.Register(key, frame, Anchor(60, -80), options)
    assert(#context.objects == count, "registration allocated editor drawing before editing")
    return frame
end

env.SurvivorsDragonUiLayout = { first = { x = 0.1, y = -0.2, hidden = true } }
local first = Group("first", { edgeWidth = true, onHeightDrag = function() end })
local second = Group("second", { onlyWhenShown = true }, true)
layout.Ready()
local registered = #context.objects
Tick()
assert(#context.objects == registered and #Handles() == 0, "gameplay prepared editor handles")
assert(not first:IsShown() and layout.IsHidden("first"), "lazy handles changed saved visibility")
layout.BeginEdit()
assert(#Handles() == 0, "editor entry bypassed the normal preparation refresh")
Tick()
local handles = Handles()
assert(#handles == 1 and handles[1]:IsShown() and handles[1].mouse, "hidden Layout group lost its selectable handle")
local grips = 0
for _, object in ipairs(context.objects) do
    if object.parent == handles[1] and object.dragButton then grips = grips + 1 end
end
assert(grips == 8, "first preparation lost a corner or width/height grip")
assert(layout.Snapshot().first.hidden, "draft lost saved hidden geometry")
local cursorX, cursorY = 200, 200
env.GetCursorPosition = function() return cursorX, cursorY end
local nativeWidth = env.UIParent.GetWidth
local viewportReads = 0
function env.UIParent:GetWidth()
    viewportReads = viewportReads + 1
    return nativeWidth(self)
end
context:Call(controller, "OnUpdate", 0.05)
assert(viewportReads == 0, "settled editor sampled viewport geometry every frame")
context:Call(controller, "OnUpdate", 0.05)
assert(viewportReads == 1, "settled editor lost its ten-Hz refresh")
local initialLeft = first:GetLeft()
context:Call(handles[1], "OnDragStart")
viewportReads = 0
context:Call(controller, "OnUpdate", 0.01)
assert(viewportReads == 1, "stationary drag reread the viewport after the controller sample")
cursorX = cursorX + 20
viewportReads = 0
context:Call(controller, "OnUpdate", 0.01)
assert(viewportReads == 1, "moving drag repeated viewport reads for cursor/position work")
assert(env.T.NearlyEqual(first:GetLeft(), initialLeft + 20), "shared viewport changed drag coordinates")
cursorX = cursorX + 15
context:Call(handles[1], "OnMouseUp")
assert(env.T.NearlyEqual(first:GetLeft(), initialLeft + 35), "release skipped its fresh final cursor sample")
second:Show()
Tick()
assert(#Handles() == 2, "newly eligible conditional group did not prepare")
local editCalls = 0
Group("late", {
    onEdit = function(editing)
        if editing then editCalls = editCalls + 1 end
    end,
})
assert(editCalls == 1, "active editor registration skipped its onEdit callback")
Tick()
assert(#Handles() == 3, "active editor registration did not prepare on refresh")
local prepared = #context.objects
context:Call(context.confirm, "OnClick")
assert(not layout.IsEditing() and env.SurvivorsDragonUiLayout.first.hidden, "Confirm changed hidden geometry")
for _, handle in ipairs(Handles()) do
    assert(not handle:IsShown() and not handle.mouse, "Confirm retained active handle input")
end
layout.BeginEdit()
Tick()
assert(#context.objects == prepared, "reopening allocated another handle pool")
layout.CancelEdit()
local dormant = Group("dormant", { onlyWhenShown = true }, true)
local beforeCleanup = #context.objects
context:Event(controller, "PLAYER_LEAVING_WORLD")
assert(#context.objects == beforeCleanup and not dormant:IsShown(), "cleanup required an unprepared handle")
context:Event(controller, "PLAYER_ENTERING_WORLD")
Tick()
layout.Reset()
assert(
    #context.objects == beforeCleanup and not next(env.SurvivorsDragonUiLayout),
    "reset allocated handles or retained geometry"
)

local broken = env.CreateFrame("Frame", nil, env.UIParent)
broken.width, broken.height = 240, 40
local nativeShow, nativeHide = broken.Show, broken.Hide
local registeredOK = pcall(layout.Register, "broken", broken, function() error("injected anchor failure") end)
assert(
    not registeredOK and broken.Show == nativeShow and broken.Hide == nativeHide,
    "failed registration installed native wrappers"
)
layout.Register("broken", broken, Anchor(90, -90))
Tick()
context.failBackdrop = true
layout.BeginEdit()
local painted, failure = pcall(Tick)
assert(
    not painted and string.find(failure, "injected native handle preparation failure", 1, true),
    "setup error was swallowed"
)
local afterFailure = #context.objects
Tick()
assert(#context.objects == afterFailure, "failed preparation allocated partial handles every editor sample")
for _, handle in ipairs(Handles()) do
    assert(handle.backdrop and handle.mouse, "a partially prepared handle became interactive")
end
context:Event(controller, "PLAYER_LOGOUT")
assert(not layout.IsEditing(), "logout failed with an unprepared handle")
print("PASS Layout defers handle artwork, reuses the pool, preserves drafts and safely retires unprepared groups")
