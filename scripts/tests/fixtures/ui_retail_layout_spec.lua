-- CI only: real Layout/Display transactions with explicit native editor boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
local createObject = context.Object
function context:Object(...)
    local object = createObject(self, ...)
    if object.kind == "FontString" then
        -- Retain native write accounting while exposing label anchors to the
        -- same paired-option geometry assertions used for frame controls.
        local setPoint, clearPoints = object.SetPoint, object.ClearAllPoints
        function object:SetPoint(...)
            setPoint(self, ...)
            self.point = { ... }
        end
        function object:ClearAllPoints()
            clearPoints(self)
            self.point = nil
        end
    end
    return object
end
assert(_VERSION == "Lua 5.1", "retail Layout fixtures require CI Lua 5.1")
local function Geometry(object)
    -- Native dimensions are independent of Lua fields such as the numeric
    -- form's width/height input boxes.
    local width, height = object:GetWidth(), object:GetHeight()
    local nativeShow, nativeVisible = object.Show, object.IsVisible
    object.strata = object.parent and object.parent:GetFrameStrata() or "MEDIUM"
    object.level = object.parent and object.parent:GetFrameLevel() + 1 or 0
    function object:GetFrameStrata() return self.strata end
    function object:GetChildren()
        local children = {}
        for _, child in ipairs(context.objects) do
            if child.parent == self and child.kind ~= "Texture" and child.kind ~= "FontString" then
                children[#children + 1] = child
            end
        end
        return unpack(children)
    end
    function object:SetFrameStrata(strata)
        if self.strata == strata then return end
        context.writes.SetFrameStrata = (context.writes.SetFrameStrata or 0) + 1
        self.strata = strata
        for _, child in ipairs({ self:GetChildren() }) do
            child:SetFrameStrata(strata)
        end
    end
    function object:IsVisible() return not self.needsParentShow and nativeVisible(self) end
    function object:Show()
        self.needsParentShow = nil
        nativeShow(self)
    end
    function object:GetWidth() return width end
    function object:GetHeight() return height end
    function object:SetWidth(value)
        assert(type(value) == "number", "native width must be numeric")
        context.writes.SetWidth = (context.writes.SetWidth or 0) + 1
        width = value
    end
    function object:SetHeight(value)
        assert(type(value) == "number", "native height must be numeric")
        context.writes.SetHeight = (context.writes.SetHeight or 0) + 1
        height = value
    end
    function object:GetScale() return self.scale or 1 end
    function object:SetScale(value)
        assert(type(value) == "number" and value > 0, "native scale must be positive")
        context.writes.SetScale = (context.writes.SetScale or 0) + 1
        self.scale = value
    end
    function object:GetEffectiveScale() return self:GetScale() end
    function object:GetLeft()
        local point = self.point
        if point and point[1] == "TOPLEFT" and point[3] == "TOPLEFT" then
            local relative = point[2]
            return relative:GetLeft() * relative:GetEffectiveScale() / self:GetEffectiveScale() + (point[4] or 0)
        end
        return self.left or 0
    end
    function object:GetRight() return self:GetLeft() + self:GetWidth() end
    function object:GetTop()
        local point = self.point
        if point and point[1] == "TOPLEFT" and point[3] == "TOPLEFT" then
            local relative = point[2]
            return relative:GetTop() * relative:GetEffectiveScale() / self:GetEffectiveScale() + (point[5] or 0)
        end
        return self.top or self:GetHeight()
    end
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
        if self.parent == parent then return end
        local wasVisible = self:IsVisible()
        self.parent = parent
        -- Legacy reparenting changes this root's layer only. An effectively
        -- hidden frame also needs Show before its visibility catches up.
        self:SetFrameStrata(parent:GetFrameStrata())
        self:SetFrameLevel(parent:GetFrameLevel() + 1)
        self.needsParentShow = not wasVisible
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
        context.writes.SetSliderRange = (context.writes.SetSliderRange or 0) + 1
        -- Native range changes may synchronously clamp/fire the existing value.
        self:SetValue(math.max(low, math.min(high, self:GetValue())))
    end
    function object:SetValueStep(step) self.step = step end
    function object:GetValue() return self.value or 0 end
    function object:SetValue(value)
        context.writes.SetSliderValue = (context.writes.SetSliderValue or 0) + 1
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
local function AssertLayers(frame, parent)
    assert(frame:GetFrameStrata() == parent:GetFrameStrata(), "numeric form retained another window's strata")
    assert(frame:GetFrameLevel() == parent:GetFrameLevel() + 1, "numeric control was painted below its parent")
    for _, child in ipairs({ frame:GetChildren() }) do
        AssertLayers(child, frame)
    end
end
Geometry(env.UIParent)
env.UIParent:SetWidth(1024)
env.UIParent:SetHeight(768)
local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent, template)
    local frame = Geometry(createFrame(kind, name, parent))
    if template == "OptionsSliderTemplate" then
        for _, suffix in ipairs({ "Low", "High", "Text" }) do
            env[name .. suffix] = frame:CreateFontString(nil, "OVERLAY")
        end
    end
    return frame
end
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
    button.label:SetWidth(width - 36)
    function button.label:GetStringWidth() return self.naturalWidth or 100 end
    button.editorCheckbox = button:CreateTexture(nil, "ARTWORK")
    button.editorDivider = button:CreateTexture(nil, "ARTWORK")
    if description then
        button.description = button:CreateFontString(nil, "OVERLAY")
        button.description:SetWidth(width - 36)
        button.description:SetText(description)
    end
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
env.ReloadUI = function() context.reloads = (context.reloads or 0) + 1 end
context:Load("core/layout.lua", "Layout")
local layout, display = env.DFRL.layout, env.DFRL.display
local controller = context:Controller("PLAYER_LOGOUT")
local settingsWindow
local frame = env.CreateFrame("Frame", nil, env.UIParent)
frame:SetWidth(100)
frame:SetHeight(40)
layout.Register("playerFrame", frame, function(owner)
    owner:ClearAllPoints()
    owner:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 60, -80)
end, {
    edgeWidth = true,
    minWidth = 40,
    maxWidth = 900,
    onEdit = function(active, save)
        if active then
            display.BeginEdit()
        else
            display.FinishEdit(save)
            if settingsWindow then settingsWindow:Hide() end
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
local numericForm = context.inputs[1]:GetParent()
AssertLayers(numericForm, numericForm:GetParent())
local widthSlider = numericForm.widthSlider
assert(
    widthSlider == env.SurvivorsDragonUiLayoutWidth
        and widthSlider:IsVisible()
        and widthSlider.minimum == 40
        and widthSlider.maximum == 900
        and widthSlider.step == 1
        and widthSlider:GetValue() == 100,
    "selected width group did not prepare its bounded slider"
)
assert(
    frame:GetWidth() == 100 and not env.SurvivorsDragonUiLayout.playerFrame,
    "programmatic slider preparation resized the selected frame"
)
local centerX, centerY = numericForm.x:GetText(), numericForm.y:GetText()
widthSlider:SetValue(220)
assert(
    frame:GetWidth() == 220
        and frame:GetHeight() == 40
        and frame:GetScale() == 1
        and numericForm.x:GetText() == centerX
        and numericForm.y:GetText() == centerY
        and widthSlider.valueLabel:GetText() == "220.00"
        and not env.SurvivorsDragonUiLayout.playerFrame,
    "width preview changed center, height, scale or committed before Save"
)
widthSlider:SetValue(100)
Tick()
context:ResetCounts()
Tick()
Tick()
assert(
    not context.writes.SetSliderRange and not context.writes.SetSliderValue,
    "settled width slider rewrote native range/value"
)
context:NoPresentationWrites()
widthSlider:SetValue(100)
context:NoPresentationWrites()
-- An existing side grip changes width without changing scale. The shared
-- controller must notice that width rather than retaining a scale-only cache.
frame:SetWidth(150)
Tick()
assert(
    widthSlider:GetValue() == 150 and widthSlider.valueLabel:GetText() == "150.00",
    "existing width adjustment did not refresh the selected slider"
)
frame:SetWidth(100)
Tick()
assert(
    numericForm.width == context.inputs[3]
        and numericForm.height == context.inputs[4]
        and numericForm:GetWidth() == 400
        and type(numericForm:GetHeight()) == "number",
    "numeric input fields replaced the mock's native dimensions"
)
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
    frame:GetLeft() == 60 and frame:GetWidth() == 100 and display.Get("layoutShowGrid"),
    "Cancel did not restore geometry and display preferences"
)
assert(not manager:IsShown() and not handle:IsShown(), "Cancel retained editor input")

layout.BeginEdit(true)
Tick()
context:Call(handle, "OnMouseDown", "LeftButton")
context.inputs[3]:SetText("invalid")
widthSlider:SetValue(300)
assert(
    frame:GetWidth() == 100
        and widthSlider:GetValue() == 100
        and context.inputs[3]:GetText() == "invalid"
        and numericForm.dirty,
    "slider overwrote invalid numeric input or accepted a width through failed validation"
)
context:Call(context.confirm, "OnClick")
assert(layout.IsEditing() and manager:IsShown(), "invalid numeric input closed the edit session")
context.inputs[3]:SetText("125")
widthSlider:SetValue(210)
assert(
    frame:GetScale() == 1.25 and frame:GetHeight() == 40,
    "slider failed to apply valid pending scale or changed height"
)
display.Set("layoutSnapEnabled", false)
context:Call(context.confirm, "OnClick")
assert(
    not layout.IsEditing()
        and env.SurvivorsDragonUiDisplay.layoutSnapEnabled == false
        and env.SurvivorsDragonUiLayout.playerFrame.width == 210
        and env.SurvivorsDragonUiLayout.playerFrame.scale == 1.25,
    "Save and close did not confirm the shared transaction"
)

settingsWindow = env.CreateFrame("Frame", "SurvivorsDragonUiSettingsFixture", env.UIParent)
settingsWindow:Hide()
local home = env.CreateFrame("Frame", nil, settingsWindow)
layout.RegisterEditorWindow(settingsWindow)
local specialCount = #env.UISpecialFrames
layout.RegisterEditorWindow(settingsWindow)
assert(#env.UISpecialFrames == specialCount, "Escape registration was duplicated")
layout.SetEditorVisibilityHandler(function(shown)
    if shown then
        layout.CreateControls(home, 660, function() end)
        settingsWindow:Show()
    else
        settingsWindow:Hide()
    end
end)
layout.BeginEdit(true)
Tick()
context:Call(handle, "OnMouseDown", "LeftButton")
local form = context.inputs[1]:GetParent()
assert(
    form.visibility:GetWidth() == 400 and not form.grid:IsShown(),
    "moving popup retained half-width or visible grid options"
)
layout.BeginEdit()
Tick()
assert(
    form:GetParent() == home and #context.inputs == 4,
    "switching to settings duplicated or stranded the numeric form"
)
assert(form.widthSlider == widthSlider and widthSlider:IsVisible(), "mode switch replaced or hid the width slider")
centerX, centerY = form.x:GetText(), form.y:GetText()
widthSlider:SetValue(360)
assert(
    frame:GetWidth() == 360
        and frame:GetScale() == 1.25
        and frame:GetHeight() == 40
        and form.x:GetText() == centerX
        and form.y:GetText() == centerY,
    "full-editor width preview changed center, scale or height"
)
widthSlider:SetValue(210)
AssertLayers(form, home)
assert(not form:GetScript("OnUpdate"), "numeric form retained a separate polling callback")
assert(
    form.visibility:GetWidth() == 194 and form.grid:GetWidth() == 194 and form.grid:IsShown(),
    "full editor did not restore paired options"
)
assert(
    form.visibility.point[5] == -228 and form.grid.point[5] == -228 and form.grid.point[4] == 206,
    "Hide frame and Show grid do not share one row"
)
assert(form.apply.point[5] == -300 and form.status.point[5] == -338, "width slider overlaps the paired options")
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
assert(
    form.visibility:GetWidth() == 400 and not form.grid:IsShown(),
    "returning to moving mode lost full-width Hide frame"
)
local popup = form:GetParent()
assert(
    form:IsVisible()
        and form.label:IsVisible()
        and form.x:IsVisible()
        and form.visibility:IsVisible()
        and form.apply:IsVisible(),
    "hidden settings form reopened as an empty moving popup"
)
AssertLayers(form, popup)
context:ResetCounts()
layout.CreateControls(popup, 400)
assert(
    not context.writes.SetFrameLevel and not context.writes.SetFrameStrata and not context.writes.Show,
    "unchanged popup reapplied its drawing layers or visibility"
)
local prepared = #context.objects
form.visibility.label.naturalWidth = 500
context:NotifyLocale()
assert(form:GetHeight() == 374 and popup:GetHeight() == 404, "wrapped popup captions overflow the panel")
assert(
    popup.point[5] >= -768 + popup:GetHeight() + 12 and popup.point[5] <= -24,
    "resized popup was not clamped through the existing placement lifecycle"
)
assert(#context.objects == prepared and form:GetParent() == popup, "wrapped caption rebuilt the popup or inputs")
context:ResetCounts()
context:NotifyLocale()
context:NoPresentationWrites()
form.visibility.label.naturalWidth = 100
context:NotifyLocale()
assert(form:GetHeight() == 362 and popup:GetHeight() == 392, "popup did not recover its width-control height")
for _, object in ipairs(context.objects) do
    if object.parent == handle and object.dragButton then assert(not object:IsShown() and not object.mouse) end
end
context:Event(controller, "PLAYER_LEAVING_WORLD")
assert(not layout.IsEditing() and not manager:IsShown() and not handle:IsShown(), "world cleanup retained editor input")
context:Event(controller, "PLAYER_ENTERING_WORLD")
Tick()
layout.ToggleEdit()
assert(layout.IsEditing() and settingsWindow:IsShown(), "launcher toggle did not open the editor")
display.Set("layoutSnapEnabled", true)
layout.ToggleEdit()
assert(
    not layout.IsEditing() and not settingsWindow:IsShown() and display.Get("layoutSnapEnabled") == false,
    "launcher toggle failed to close and discard the draft"
)
layout.ToggleEdit()
display.Set("layoutSnapEnabled", true)
-- Native Escape hides the registered UISpecialFrames window.
settingsWindow:Hide()
assert(
    not layout.IsEditing() and display.Get("layoutSnapEnabled") == false,
    "Escape hide did not retire the edit session"
)
layout.ToggleEdit()
display.Set("layoutSnapEnabled", true)
context.inputs[1]:SetText("invalid")
context:Call(context.inputs[1], "OnEscapePressed")
assert(
    not layout.IsEditing() and not settingsWindow:IsShown() and display.Get("layoutSnapEnabled") == false,
    "focused invalid Layout input blocked Escape cancellation"
)
layout.ToggleEdit()
display.Set("layoutSnapEnabled", true)
layout.BeginEdit(true)
assert(
    layout.IsEditing() and display.Get("layoutSnapEnabled") == true,
    "mode switch discarded the draft on window hide"
)
layout.CancelEdit()
-- Exercise selection-specific controls through the production handles, without
-- publishing a runtime test hook or a second maintained list of Layout groups.
local function SelectGroup(key, options)
    local owner = env.CreateFrame("Frame", nil, env.UIParent)
    owner:SetWidth(240)
    owner:SetHeight(120)
    local known = {}
    for _, object in ipairs(context.objects) do
        if object.SetEditorSelection then known[object] = true end
    end
    layout.Register(key, owner, function(root)
        root:ClearAllPoints()
        root:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 300, -240)
    end, options)
    if not layout.IsEditing() then layout.BeginEdit(true) end
    Tick()
    local selection
    for _, object in ipairs(context.objects) do
        if object.SetEditorSelection and not known[object] then selection = object end
    end
    assert(selection, "new group did not prepare a selectable handle")
    context:Call(selection, "OnMouseDown", "LeftButton")
    return owner, selection
end
local chat, chatSelection = SelectGroup("chat", {
    resize = "dimensions",
    edgeHandles = true,
    minWidth = 240,
    maxWidth = 2400,
    minHeight = 120,
    maxHeight = 1600,
})
assert(
    widthSlider.minimum == 240 and widthSlider.maximum == 2400 and chat:GetWidth() == 240,
    "new range synchronisation changed the newly selected group"
)
widthSlider:SetValue(480)
assert(
    chat:GetWidth() == 480 and chat:GetHeight() == 120 and form.width:GetText() == "480.00",
    "Chat width preview resized height or failed to update numeric dimensions"
)
widthSlider:SetValue(3000)
assert(chat:GetWidth() == 2400 and widthSlider:GetValue() == 2400, "width preview exceeded the existing maximum")
local naturalWidth = 240
local revive = SelectGroup("revive", {
    edgeWidth = true,
    minWidth = 160,
    maxWidth = 1200,
    defaultWidth = function() return naturalWidth end,
})
assert(not layout.Snapshot().revive.width, "viewing the slider opted an automatic view into explicit width")
widthSlider:SetValue(360)
assert(layout.Snapshot().revive.width == 360, "caption-fitted view did not retain its chosen width")
naturalWidth = 280
layout.Place("revive")
assert(revive:GetWidth() == 360, "natural caption changes replaced the slider width")
local profile = layout.Snapshot()
profile.revive.width = 420
layout.Load(profile)
assert(revive:GetWidth() == 420 and widthSlider:GetValue() == 420, "profile load did not refresh selected width")
local ordinary, ordinarySelection = SelectGroup("minimap", {})
assert(
    not widthSlider:IsShown() and form.visibility.point[5] == -156,
    "fixed-width group retained the slider or its reserved space"
)
context:Call(chatSelection, "OnMouseDown", "LeftButton")
assert(
    form.widthSlider == widthSlider and widthSlider:IsVisible() and widthSlider:GetValue() == 2400,
    "returning to a width group rebuilt the slider or retained another group's value"
)
context:Call(ordinarySelection, "OnMouseDown", "LeftButton")
widthSlider:SetValue(500)
assert(ordinary:GetWidth() == 240, "hidden width control changed an unsupported group")
layout.CancelEdit()
assert(chat:GetWidth() == 240 and revive:GetWidth() == 280, "Cancel retained width previews or lost automatic sizing")
layout.BeginEdit(true)
context:Call(chatSelection, "OnMouseDown", "LeftButton")
widthSlider:SetValue(600)
context:Event(controller, "PLAYER_LEAVING_WORLD")
assert(chat:GetWidth() == 240 and not widthSlider:IsVisible(), "world discard retained the width preview or input")
context:Event(controller, "PLAYER_ENTERING_WORLD")
Tick()
layout.BeginEdit(true)
context:Call(chatSelection, "OnMouseDown", "LeftButton")
widthSlider:SetValue(700)
layout.Reset()
assert(chat:GetWidth() == 240 and not env.SurvivorsDragonUiLayout.chat, "full reset retained a slider width")
context:Event(controller, "PLAYER_LOGOUT")
local function ProfileCommitLifecycle()
    local function Copy(value)
        if type(value) ~= "table" then return value end
        local copy = {}
        for key, entry in pairs(value) do
            copy[key] = Copy(entry)
        end
        return copy
    end
    -- Font/SCT owners are explicit boundaries here; their own production
    -- fixtures cover fonts, native preference handoff and preview cleanup.
    env.DFRL.runFont = {
        Copy = Copy,
        Snapshot = function() return Copy(context.fontDraft) end,
        Load = function(value) context.fontDraft = Copy(value) end,
    }
    env.DFRL.sct = {
        NormalizeMode = function(value)
            return (value == "on" or value == "off" or value == "default") and value or "on"
        end,
        GetMode = function() return context.sctDraft end,
        SetMode = function(value) context.sctDraft = value end,
    }
    local owner = env.CreateFrame("Frame", nil, env.UIParent)
    owner:SetWidth(80)
    owner:SetHeight(20)
    layout.Register("profileOwner", owner, function(root)
        root:ClearAllPoints()
        root:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 30, -60)
    end, {
        onEdit = function(active, save)
            if active then
                context.fontDraft = Copy(env.SurvivorsDragonUiRunFont or { face = "DEFAULT", size = 14 })
                context.sctDraft = env.DFRL.sct.NormalizeMode(env.SurvivorsDragonUiSctMode)
            else
                if save then
                    context.profileCommits = (context.profileCommits or 0) + 1
                    env.SurvivorsDragonUiRunFont = Copy(context.fontDraft)
                    env.SurvivorsDragonUiSctMode = context.sctDraft
                end
                context.fontDraft, context.sctDraft = nil, nil
            end
        end,
        -- The production runTimer registration owns the full-reset handoff
        -- to Display. Keep that boundary explicit with the fake font owner.
        onReset = function()
            context.profileFontResets = (context.profileFontResets or 0) + 1
            env.SurvivorsDragonUiRunFont = nil
            display.Reset()
            context.fontDraft = nil
        end,
    })
    context:Load("core/profiles.lua", "Profiles")
    local profiles = env.DFRL.profiles
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    Tick()
    layout.BeginEdit()
    context:Call(chatSelection, "OnMouseDown", "LeftButton")
    widthSlider:SetValue(555)
    form.x:SetText("120,5")
    form.y:SetText("-33")
    display.Set("uiFont", "arial")
    display.Set("uiFontOutline", "")
    display.Set("uiFontShadow", false)
    display.Set("xpShowText", true)
    display.Set("performanceMode", true)
    context.fontDraft.size, context.sctDraft = 17, "on"
    local name = "Handheld Ω"
    assert(profiles.Save(name, false), "profile save rejected valid pending coordinates")
    assert(not layout.IsEditing() and not settingsWindow:IsShown() and context.profileCommits == 1)
    local saved = env.SurvivorsDragonUiProfiles[name]
    assert(saved.layout.chat.width == 555 and env.SurvivorsDragonUiLayout.chat.width == 555)
    assert(saved.display.uiFont == "arial" and env.SurvivorsDragonUiDisplay.uiFont == "arial")
    assert(saved.display.uiFontOutline == "" and not saved.display.uiFontShadow, "profile lost None or shadow-off")
    assert(
        env.SurvivorsDragonUiDisplay.uiFontOutline == "" and not env.SurvivorsDragonUiDisplay.uiFontShadow,
        "profile save skipped confirmed global font styling"
    )
    assert(saved.display.xpShowText and saved.display.performanceMode)
    assert(saved.runFont.size == 17 and env.SurvivorsDragonUiRunFont.size == 17)
    assert(saved.sctMode == "on" and env.SurvivorsDragonUiSctMode == "on")
    assert(saved.layout ~= env.SurvivorsDragonUiLayout and saved.display ~= env.SurvivorsDragonUiDisplay)
    assert(saved.runFont ~= env.SurvivorsDragonUiRunFont, "profile aliases active font settings")
    assert(not layout.ConfirmEdit() and context.profileCommits == 1, "closed editor committed twice")
    layout.BeginEdit()
    display.Set("uiFontOutline", "THICKOUTLINE")
    display.Set("uiFontShadow", true)
    env.ReloadUI()
    assert(
        context.reloads == 1 and env.SurvivorsDragonUiProfiles[name] == saved,
        "reload discard removed a saved profile"
    )
    assert(display.Get("uiFontOutline") == "" and not display.Get("uiFontShadow"), "reload retained draft font styling")
    layout.BeginEdit()
    display.Set("uiFontOutline", "THICKOUTLINE")
    display.Set("uiFontShadow", true)
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    Tick()
    assert(env.SurvivorsDragonUiProfiles[name] == saved and env.SurvivorsDragonUiLayout.chat.width == 555)
    assert(
        display.Get("uiFontOutline") == "" and not display.Get("uiFontShadow"),
        "world cleanup retained draft font styling"
    )

    layout.BeginEdit()
    context:Call(chatSelection, "OnMouseDown", "LeftButton")
    assert(form.x:GetText() == "120.50" and form.y:GetText() == "-33.00", "save lost pending numeric positions")
    form.x:SetText("invalid")
    assert(not profiles.Save(name, true) and layout.IsEditing(), "invalid overwrite closed the editor")
    assert(not profiles.Save("Blocked", false) and not env.SurvivorsDragonUiProfiles.Blocked)
    assert(
        env.SurvivorsDragonUiProfiles[name] == saved and context.profileCommits == 1,
        "invalid save altered committed state"
    )
    form.x:SetText("75")
    widthSlider:SetValue(730)
    display.Set("uiFont", "morpheus")
    display.Set("uiFontOutline", "THICKOUTLINE")
    display.Set("uiFontShadow", true)
    display.Set("performanceMode", false)
    context.fontDraft.size = 19
    assert(profiles.Save(name, true), "valid overwrite failed after correcting coordinates")
    saved = env.SurvivorsDragonUiProfiles[name]
    assert(not layout.IsEditing() and context.profileCommits == 2 and saved.layout.chat.width == 730)
    assert(saved.display.uiFont == "morpheus" and not saved.display.performanceMode and saved.runFont.size == 19)
    assert(
        saved.display.uiFontOutline == "THICKOUTLINE" and saved.display.uiFontShadow,
        "overwrite lost global font styling"
    )
    layout.BeginEdit()
    display.Set("uiFont", "skurri")
    display.Set("uiFontOutline", "")
    display.Set("uiFontShadow", false)
    assert(not profiles.Save(name, false) and not profiles.Save("", false), "invalid names saved")
    assert(layout.IsEditing() and env.SurvivorsDragonUiProfiles[name] == saved)
    assert(profiles.Load(name) and layout.IsEditing(), "load stopped being a preview")
    assert(
        display.Get("uiFontOutline") == "THICKOUTLINE" and display.Get("uiFontShadow"),
        "profile load did not preview its global font styling"
    )
    display.Set("uiFontOutline", "")
    display.Set("uiFontShadow", false)
    assert(profiles.Delete(name) and env.SurvivorsDragonUiProfiles[name] == saved, "delete committed before Confirm")
    layout.CancelEdit()
    assert(env.SurvivorsDragonUiDisplay.uiFont == "morpheus" and env.SurvivorsDragonUiProfiles[name] == saved)
    assert(
        display.Get("uiFontOutline") == "THICKOUTLINE" and display.Get("uiFontShadow"),
        "Cancel retained draft global font styling"
    )

    -- Model the client's persistence boundary using only copied confirmed
    -- globals in fresh Display/Profiles owners, with no client or disk access.
    local fresh = H.New()
    fresh.env.SurvivorsDragonUiProfiles = Copy(env.SurvivorsDragonUiProfiles)
    fresh.env.SurvivorsDragonUiDisplay = Copy(env.SurvivorsDragonUiDisplay)
    fresh.env.SurvivorsDragonUiLayout = Copy(env.SurvivorsDragonUiLayout)
    fresh.env.SurvivorsDragonUiRunFont = Copy(env.SurvivorsDragonUiRunFont)
    fresh.env.SurvivorsDragonUiSctMode = env.SurvivorsDragonUiSctMode
    fresh.env.DFRL.layout.Copy = layout.Copy
    fresh.env.DFRL.layout.Load = function(value) fresh.restoredLayout = layout.Copy(value) end
    fresh.env.DFRL.runFont = { Copy = Copy, Load = function(value) fresh.restoredFont = Copy(value) end }
    fresh.env.DFRL.sct =
        { NormalizeMode = env.DFRL.sct.NormalizeMode, SetMode = function(value) fresh.restoredSct = value end }
    fresh:Load("core/display.lua", "Display")
    fresh:Load("core/profiles.lua", "Profiles")
    local restoredDisplay, restoredProfiles = fresh.env.DFRL.display, fresh.env.DFRL.profiles
    assert(fresh.env.SurvivorsDragonUiLayout.chat.width == 730 and restoredDisplay.Get("uiFont") == "morpheus")
    assert(
        restoredDisplay.Get("uiFontOutline") == "THICKOUTLINE" and restoredDisplay.Get("uiFontShadow"),
        "fresh owners lost confirmed global font styling"
    )
    assert(restoredProfiles.List()[1] == name, "fresh owners lost the confirmed profile")
    restoredDisplay.BeginEdit()
    restoredProfiles.BeginEdit()
    assert(restoredProfiles.Load(name) and restoredDisplay.Get("uiFont") == "morpheus")
    assert(restoredDisplay.Get("uiFontOutline") == "THICKOUTLINE" and restoredDisplay.Get("uiFontShadow"))
    assert(fresh.restoredLayout.chat.width == 730 and fresh.restoredFont.size == 19 and fresh.restoredSct == "on")
    layout.Reset()
    assert(context.profileFontResets == 1, "Layout reset skipped the registered font-owner handoff")
    assert(
        display.Get("uiFontOutline") == "OUTLINE" and display.Get("uiFontShadow"),
        "full reset lost font-style defaults"
    )
    assert(not env.SurvivorsDragonUiRunFont and not context.fontDraft, "full reset retained timer-font preferences")
    assert(env.SurvivorsDragonUiSctMode == "on", "full reset changed the confirmed scalar SCT mode")
    assert(env.SurvivorsDragonUiProfiles[name] == saved, "Addon defaults erased a saved profile")
    assert(
        saved.display.uiFontOutline == "THICKOUTLINE" and saved.display.uiFontShadow,
        "reset changed the saved profile"
    )
end
ProfileCommitLifecycle()
print(
    "PASS retail manager, shared width slider, center/scale/height, pending validation, profiles, reset, hidden idle, Save/Cancel and world cleanup"
)
