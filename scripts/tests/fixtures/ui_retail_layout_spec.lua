-- CI only: real Layout/Display transactions with explicit native editor boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
assert(_VERSION == "Lua 5.1", "retail Layout fixtures require CI Lua 5.1")
local function Geometry(object)
    function object:GetScale() return self.scale or 1 end
    function object:GetEffectiveScale() return self:GetScale() end
    function object:GetLeft() return self.left or 0 end
    function object:GetRight() return self:GetLeft() + self:GetWidth() end
    function object:GetTop() return self.top or self:GetHeight() end
    function object:GetBottom() return self:GetTop() - self:GetHeight() end
    function object:GetNumPoints() return self.point and 1 or 0 end
    function object:GetPoint() return unpack(self.point or {}) end
    function object:ClearAllPoints() self.point = nil end
    function object:SetPoint(point, relative, relativePoint, x, y)
        self.point = { point, relative, relativePoint, x, y }
        if point == "TOPLEFT" then
            self.left = relative:GetLeft() + (x or 0)
            self.top = relative:GetTop() + (y or 0)
        end
    end
    function object:SetParent(parent)
        self.parent = parent
        context:Visibility()
    end
    function object:SetMovable(value) self.movable = value end
    function object:SetUserPlaced(value) self.userPlaced = value end
    function object:SetClampedToScreen(value) self.clamped = value end
    function object:StopMovingOrSizing() self.moving = false end
    function object:StartMoving() self.moving = true end
    function object:RegisterForDrag(button) self.dragButton = button end
    function object:EnableMouse(value) self.mouse = value end
    function object:EnableMouseWheel(value) self.wheel = value end
    function object:EnableKeyboard(value) self.keyboard = value end
    function object:SetMinMaxValues(low, high)
        self.minimum, self.maximum = low, high
    end
    function object:SetValueStep(step) self.step = step end
    function object:GetValue() return self.value or 0 end
    function object:SetValue(value)
        self.value = value
        context:Call(self, "OnValueChanged", value)
    end
    function object:ClearFocus()
        if self.focused then
            self.focused = false
            context:Call(self, "OnEditFocusLost")
        end
    end
    function object:SetFocus()
        self.focused = true
        context:Call(self, "OnEditFocusGained")
    end
    return object
end
Geometry(env.UIParent)
env.UIParent.width, env.UIParent.height = 1024, 768
local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent) return Geometry(createFrame(kind, name, parent)) end
env.DFRL.locale.Bind = function(label) return label end
context.cursorX, context.cursorY = 200, 600
env.GetCursorPosition = function() return context.cursorX, context.cursorY end
env.IsShiftKeyDown = function() return context.shift or false end
context:Load("core/editor.lua")
-- Drawing is separately covered by ui_retail_edit_spec; these boundaries expose
-- only native input, focus and dimensions to the production Layout owner.
env.T.CreateEditorPanel = function(parent, width, height, name)
    local frame = env.CreateFrame("Frame", name, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    return frame
end
env.T.CreateEditorButton = function(parent, text, width, height)
    local button = env.CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetText(text)
    if text == "Confirm" then context.confirm = button end
    return button
end
env.T.CreateEditorToggle = function(parent, text, description, width, callback)
    local button = env.T.CreateEditorButton(parent, text, width, 44)
    function button:SetChecked(value) self.editorChecked = value end
    button:SetScript("OnClick", function()
        button:SetChecked(not button.editorChecked)
        callback(button.editorChecked)
    end)
    return button
end
context.inputs = {}
env.T.CreateEditorInput = function(parent, width, height)
    local input = env.CreateFrame("EditBox", nil, parent)
    input:SetWidth(width)
    input:SetHeight(height)
    local setText = input.SetText
    function input:SetText(value)
        setText(self, value)
        context:Call(self, "OnTextChanged")
    end
    context.inputs[#context.inputs + 1] = input
    return input
end
context:Load("core/display.lua", "Display")
context:Load("core/layout_snap.lua")
context:Load("core/layout.lua", "Layout")
local layout, display = env.DFRL.layout, env.DFRL.display
local controller = context:Controller("PLAYER_LOGOUT")
local frame = env.CreateFrame("Frame", nil, env.UIParent)
frame.width, frame.height = 100, 40
layout.Register("playerFrame", frame, function(owner)
    owner:ClearAllPoints()
    owner:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 60, -80)
end, {
    edgeWidth = true,
    onEdit = function(active, save)
        if active then
            display.BeginEdit()
        else
            display.FinishEdit(save)
        end
    end,
})
layout.Ready()
local function Tick() context:Call(controller, "OnUpdate", 0.1) end
Tick()
assert(not env.SurvivorsDragonUiEditMode, "gameplay prepared the manager")
layout.BeginEdit(true)
Tick()
local manager = env.SurvivorsDragonUiEditMode
assert(manager:IsShown() and not manager.keyboard and context.confirm.label:GetText() == "Save and close")
local handle
for _, object in ipairs(context.objects) do
    if object.SetEditorSelection then handle = object end
end
assert(handle and handle:IsShown(), "retail mode did not prepare its selection")
for _, object in ipairs(context.objects) do
    assert(not (object.parent == handle and object.dragButton), "retail mode allocated resize grips")
end
context:Call(handle, "OnMouseDown", "LeftButton")
assert(#context.inputs == 4 and manager.keyboard, "selected frame did not reuse one numeric form and keyboard owner")
local left, top = frame:GetLeft(), frame:GetTop()
context:Call(manager, "OnKeyDown", "RIGHT")
assert(frame:GetLeft() == left + 1, "arrow-key nudge lost its one-unit step")
context.shift = true
context:Call(manager, "OnKeyDown", "UP")
assert(frame:GetTop() == top + 10, "Shift-arrow nudge lost its ten-unit step")
context.shift = false
context.inputs[1]:SetFocus()
left = frame:GetLeft()
context:Call(manager, "OnKeyDown", "RIGHT")
assert(frame:GetLeft() == left, "nudging stole keyboard input from the numeric editor")
context.inputs[1]:ClearFocus()
env.ChatFrameEditBox = env.CreateFrame("EditBox", nil, env.UIParent)
context:Call(manager, "OnKeyDown", "RIGHT")
assert(frame:GetLeft() == left, "nudging stole keyboard input from native chat")
env.ChatFrameEditBox:Hide()

display.Set("layoutShowGrid", false)
left, top = frame:GetLeft(), frame:GetTop() - env.UIParent:GetHeight()
context:Call(handle, "OnDragStart")
context.cursorX, context.cursorY = context.cursorX + 7 - left, context.cursorY - 200 - top
Tick()
assert(frame:GetLeft() == 7, "magnetism pulled the pointer before release")
context:Call(handle, "OnMouseUp")
assert(frame:GetLeft() == 0, "release did not apply screen magnetism with the grid hidden")
assert(not env.SurvivorsDragonUiLayout.playerFrame, "drag saved geometry before confirmation")
layout.CancelEdit()
assert(
    frame:GetLeft() == 60 and display.Get("layoutShowGrid"),
    "Cancel did not restore geometry and display preferences"
)
assert(not manager:IsShown() and not handle:IsShown(), "Cancel retained editor input")

layout.BeginEdit(true)
Tick()
context:Call(handle, "OnMouseDown", "LeftButton")
context.inputs[3]:SetText("invalid")
context:Call(context.confirm, "OnClick")
assert(layout.IsEditing() and manager:IsShown(), "invalid numeric input closed the edit session")
context.inputs[3]:SetText("100")
display.Set("layoutSnapEnabled", false)
context:Call(context.confirm, "OnClick")
assert(
    not layout.IsEditing() and env.SurvivorsDragonUiDisplay.layoutSnapEnabled == false,
    "Save and close did not confirm the shared transaction"
)

local home = env.CreateFrame("Frame", nil, env.UIParent)
layout.SetEditorVisibilityHandler(function(shown)
    if shown then layout.CreateControls(home, 660, function() end) end
end)
layout.BeginEdit(true)
Tick()
context:Call(handle, "OnMouseDown", "LeftButton")
local form = context.inputs[1]:GetParent()
layout.BeginEdit()
Tick()
assert(
    form:GetParent() == home and #context.inputs == 4,
    "switching to settings duplicated or stranded the numeric form"
)
assert(not form:GetScript("OnUpdate"), "numeric form retained a separate polling callback")
context.inputs[1]:SetText("37")
layout.SetHandlesVisible(false)
home:Hide()
for _, object in ipairs(context.objects) do
    if object.SetEditorSelection or object.lines or object.guides then
        assert(not object:IsShown(), "another settings category retained editing artwork")
    end
end
context:ResetCounts()
Tick()
Tick()
context:NoPresentationWrites()
layout.SetHandlesVisible(true)
home:Show()
Tick()
assert(handle:IsShown() and context.inputs[1]:GetText() == "37", "Layout return lost its selection or pending input")
layout.BeginEdit(true)
Tick()
for _, object in ipairs(context.objects) do
    if object.parent == handle and object.dragButton then assert(not object:IsShown() and not object.mouse) end
end
context:Event(controller, "PLAYER_LEAVING_WORLD")
assert(not layout.IsEditing() and not manager:IsShown() and not handle:IsShown(), "world cleanup retained editor input")
print(
    "PASS retail manager, one shared form, input/focus, release snapping, Save/Cancel, category-hidden idle, mode switch and world cleanup"
)
