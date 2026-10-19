-- Run with stock Lua 5.0: lua tests/layout_geometry.lua /path/to/addon
-- Optional second argument: a baseline core/layout.lua to demonstrate failures.
-- Geometry adapter for the mixed native size contract, calibrated against:
-- https://github.com/samwhosung/benilla/blob/adbfedc3660d/crates/benilla-ui/src/script/object/layout_methods.rs
-- https://github.com/samwhosung/benilla/blob/adbfedc3660d/crates/benilla-ui/src/script/tests/screen_units.rs
-- Authored dimensions are local; zero-authored dimensions expose scaled spans.
-- Edges divide out effective scale. This models those geometric rules, not
-- GPU rendering, native UI state or the client's intermediate float rounding.

local root = arg[1] or "."
if string.sub(root, -1) ~= "/" then root = root .. "/" end
local globals = getfenv(0)
globals._G = nil
local all, controls, modules = {}, {}, {}
local passed, failed = 0, 0
local function equal(actual, expected, name)
    if type(actual) == "number" and type(expected) == "number" and math.abs(actual - expected) < 0.00001 then
        passed = passed + 1
        return
    end
    if actual ~= expected then
        failed = failed + 1
        print("FAIL " .. name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        return
    end
    passed = passed + 1
end
local function invoke(object, script, argument)
    local oldThis, oldArg = this, arg1
    this, arg1 = object, argument
    if object.scripts[script] then object.scripts[script]() end
    this, arg1 = oldThis, oldArg
end
local methods = {}
local screenWidth, screenHeight = 1365.3333333333333, 768
local SCREEN = { name = "SCREEN", scale = 1 }
local function widget(kind, name, parent)
    local object = {
        kind = kind,
        name = name,
        parent = parent,
        width = 0,
        height = 0,
        scale = 1,
        shown = true,
        scripts = {},
        points = {},
        level = 0,
        text = "",
    }
    setmetatable(object, { __index = methods })
    table.insert(all, object)
    if name then globals[name] = object end
    return object
end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetScale(value) self.scale = value end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:GetName() return self.name end
function methods:SetParent(value) self.parent = value end
function methods:GetParent() return self.parent end
function methods:SetPoint(point, relative, relativePoint, x, y)
    relative = relative or self.parent or SCREEN
    relativePoint = relativePoint or point
    local anchor = { point, relative, relativePoint, x or 0, y or 0 }
    for index, old in ipairs(self.points) do
        if old[1] == point then
            self.points[index] = anchor
            return
        end
    end
    table.insert(self.points, anchor)
end
function methods:GetPoint(index) return unpack(self.points[index or 1]) end
function methods:GetNumPoints() return table.getn(self.points) end
function methods:ClearAllPoints() self.points = {} end
local function factor(point, horizontal)
    if horizontal then
        if string.find(point, "LEFT") then
            return 0
        elseif string.find(point, "RIGHT") then
            return 1
        else
            return 0.5
        end
    else
        if string.find(point, "BOTTOM") then
            return 0
        elseif string.find(point, "TOP") then
            return 1
        else
            return 0.5
        end
    end
end
local rect
local function axis(object, horizontal)
    if object == SCREEN or object == UIParent then return 0, horizontal and screenWidth or screenHeight end
    local scale = object:GetEffectiveScale()
    local near, span = nil, (horizontal and object.width or object.height) * scale
    local firstFactor, firstPosition
    for _, anchor in ipairs(object.points) do
        local relative = anchor[2]
        local left, bottom, width, height = rect(relative)
        local target = (horizontal and left or bottom)
            + factor(anchor[3], horizontal) * (horizontal and width or height)
            + (horizontal and anchor[4] or anchor[5]) * scale
        local ownFactor = factor(anchor[1], horizontal)
        if firstFactor and ownFactor ~= firstFactor then
            span = (target - firstPosition) / (ownFactor - firstFactor)
            break
        end
        if not firstFactor then
            firstFactor, firstPosition = ownFactor, target
        end
    end
    if firstFactor then near = firstPosition - firstFactor * span end
    return near, span
end
rect = function(object)
    local left, width = axis(object, true)
    local bottom, height = axis(object, false)
    return left, bottom, width, height
end
function methods:GetWidth()
    if self.width ~= 0 then return self.width end
    local _, span = axis(self, true)
    return span
end
function methods:GetHeight()
    if self.height ~= 0 then return self.height end
    local _, span = axis(self, false)
    return span
end
function methods:GetLeft()
    local x = axis(self, true)
    return x and x / self:GetEffectiveScale()
end
function methods:GetRight()
    local x, w = axis(self, true)
    return x and (x + w) / self:GetEffectiveScale()
end
function methods:GetTop()
    local y, h = axis(self, false)
    return y and (y + h) / self:GetEffectiveScale()
end
function methods:GetBottom()
    local y = axis(self, false)
    return y and y / self:GetEffectiveScale()
end
function methods:SetScript(script, callback) self.scripts[script] = callback end
function methods:GetScript(script) return self.scripts[script] end
function methods:Show()
    if not self.shown then
        self.shown = true
        invoke(self, "OnShow")
    end
end
function methods:Hide()
    if self.shown then
        self.shown = false
        invoke(self, "OnHide")
    end
end
function methods:IsShown() return self.shown end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:CreateTexture(name, layer) return widget("Texture", name, self) end
function methods:CreateFontString(name, layer) return widget("FontString", name, self) end
function methods:SetText(text)
    self.text = text
    invoke(self, "OnTextChanged")
end
function methods:GetText() return self.text end
function methods:SetChecked(value) self.checked = value end
function methods:SetAllPoints(parent)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
end
function methods:ClearFocus() invoke(self, "OnEditFocusLost") end
function methods:SetFocus() invoke(self, "OnEditFocusGained") end
function methods:SetMovable(value) self.movable = value end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:SetUserPlaced(value) self.userPlaced = value end
function methods:EnableMouse(value) self.mouse = value end
function methods:EnableMouseWheel(value) self.mouseWheel = value end
for _, name in ipairs({
    "SetFrameStrata",
    "RegisterForDrag",
    "SetBackdrop",
    "SetBackdropBorderColor",
    "SetTextColor",
    "SetShadowColor",
    "SetShadowOffset",
    "SetTexture",
    "SetVertexColor",
    "RegisterEvent",
}) do
    methods[name] = function() end
end
function CreateFrame(kind, name, parent) return widget(kind, name, parent) end
UIParent = CreateFrame("Frame", "UIParent")
UIParent.scale = 0.9
local cursorX, cursorY = 0, 0
function GetCursorPosition() return cursorX, cursorY end
-- Verify the mixed native contract against the upstream screen_units fixture:
-- a SetWidth value is local; a 0-width anchor-derived child reports scaled span.
local calibrationA = CreateFrame("Frame", nil)
calibrationA:SetScale(0.9)
calibrationA:SetWidth(300)
calibrationA:SetHeight(200)
calibrationA:SetPoint("TOPLEFT", nil, "TOPLEFT", 100.5, -37.25)
local calibrationB = CreateFrame("Frame", nil, calibrationA)
calibrationB:SetPoint("TOPRIGHT", calibrationA, "BOTTOMRIGHT", -12.3, 4.7)
calibrationB:SetPoint("BOTTOMLEFT", calibrationA, "BOTTOMLEFT", 7, -40)
equal(calibrationA:GetWidth(), 300, "native authored width stays local")
equal(calibrationB:GetWidth(), 252.63, "native 0-width resolves scaled anchor span")
equal(calibrationB:GetRight() - calibrationB:GetLeft(), 280.7, "native edges divide by owner scale")
equal(UIParent:GetWidth(), screenWidth, "UIParent 0-width getter reports screen span")
equal(UIParent:GetRight() - UIParent:GetLeft(), screenWidth / 0.9, "UIParent edges expose local viewport width")
DFRL = { env = {}, tools = {} }
setmetatable(DFRL.env, { __index = globals })
function DFRL:GetEnv()
    self.env._G = globals
    self.env.T = self.tools
    return self.env
end
function DFRL:NewMod(name, priority, initialize) modules[name] = initialize end
DFRL.locale = { Bind = function() end, Text = function(text) return text end }
dofile(root .. "core/tools.lua")
local tools = DFRL.tools
function tools.SetFont() end
function tools.CreateEditorButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button.caption = text
    button.width = width
    button.height = height
    table.insert(controls, button)
    return button
end
function tools.CreateEditorInput(parent, width, height)
    local input = CreateFrame("EditBox", nil, parent)
    input.width = width
    input.height = height
    table.insert(controls, input)
    return input
end
function tools.CreateEditorToggle(parent, text, description, width, callback)
    local button = tools.CreateEditorButton(parent, text, width, 44)
    button.toggle = callback
    return button
end
dofile(root .. "core/display.lua")
setfenv(modules.Display, DFRL:GetEnv())
modules.Display()
dofile(arg[2] or (root .. "core/layout.lua"))
setfenv(modules.Layout, DFRL:GetEnv())
modules.Layout()
local layout = DFRL.layout
local subject = CreateFrame("Frame", "Subject", UIParent)
subject:SetWidth(300)
subject:SetHeight(36)
local region = CreateFrame("Frame", "ActionMoveRegion", subject)
region:SetPoint("TOPLEFT", subject, "TOPLEFT", -6, 14)
region:SetPoint("BOTTOMRIGHT", subject, "BOTTOMRIGHT", 6, 0)
layout.Register("actionBar", subject, function(frame)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 55)
end, { region = region })
local chatOwner = CreateFrame("Frame", "ChatOwner", UIParent)
chatOwner:SetWidth(520)
chatOwner:SetHeight(340)
chatOwner:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 40)
local chatRegion = CreateFrame("Frame", "ChatMoveRegion", chatOwner)
chatRegion:SetPoint("TOPLEFT", chatOwner, "TOPLEFT", -1, 0)
chatRegion:SetPoint("BOTTOMRIGHT", chatOwner, "BOTTOMRIGHT", 0, -32)
layout.Register("chat", chatOwner, nil, { region = chatRegion, resize = "dimensions" })
SurvivorsDragonUiLayout = { actionBar = { x = 0.25, y = -0.25, scale = 1 } }
layout.Ready()
local legacyLeft, legacyBottom, legacyWidth, legacyHeight = rect(subject)
equal(legacyLeft, 0.25 * screenWidth * UIParent.scale, "confirmed legacy normalized x retains physical position")
equal(
    legacyBottom + legacyHeight,
    screenHeight - 0.25 * screenHeight * UIParent.scale,
    "confirmed legacy normalized y retains physical position"
)
local controller
for _, object in ipairs(all) do
    if object:GetScript("OnUpdate") and object:GetScript("OnEvent") then controller = object end
end
local function tick() invoke(controller, "OnUpdate", 0.1) end
local function actualCenter(frame)
    local left, bottom, width, height = rect(frame)
    return (left + width / 2 - screenWidth / 2) / UIParent.scale,
        (bottom + height / 2 - screenHeight / 2) / UIParent.scale
end
local function physicalWidth(frame)
    local _, _, width = rect(frame)
    return width
end
layout.BeginEdit()
tick()
local handle, chatHandle
for _, object in ipairs(all) do
    local anchor = object.points[1]
    if object.parent == UIParent and object:GetScript("OnDragStart") and anchor then
        if anchor[2] == region then
            handle = object
        elseif anchor[2] == chatRegion then
            chatHandle = object
        end
    end
end
local expected = physicalWidth(region)
local actual = physicalWidth(handle)
print("handle regionphysical=" .. expected .. " handlephysical=" .. actual .. " ratio=" .. actual / expected)
equal(actual, expected, "anchor-derived region handle has identical visible width")
local chatActual, chatExpected = physicalWidth(chatHandle), physicalWidth(chatRegion)
equal(chatExpected, 521 * UIParent.scale, "native chat move region preserves authored width plus 1")
local _, _, _, chatRegionHeight = rect(chatRegion)
equal(chatRegionHeight, 372 * UIParent.scale, "native chat move region preserves 32 unit footer")
equal(chatActual, chatExpected, "chat anchored move region handle has identical visible width")
local input = CreateFrame("EditBox", "NativeInput", UIParent)
input:SetWidth(520)
input:SetHeight(28)
input:SetPoint("TOPLEFT", chatOwner, "BOTTOMLEFT", -1, -1)
equal(physicalWidth(input), physicalWidth(chatOwner), "native input parent UIParent matches chat effective scale")
local panel = CreateFrame("Frame", nil, UIParent)
layout.CreateControls(panel, 400, function() end)
local inputs = {}
local apply, confirm
for _, object in ipairs(controls) do
    if object.kind == "EditBox" then
        table.insert(inputs, object)
    elseif object.caption == "Apply position / size" then
        apply = object
    elseif object.caption == "Confirm" then
        confirm = object
    end
end
local function enter(x, y, size)
    inputs[1]:SetText(x)
    inputs[2]:SetText(y)
    inputs[3]:SetText(size)
end
for _, scenario in ipairs({
    { 1365.3333333333, 768, 0.9 },
    { 1365.3333333333, 768, 0.8 },
    { 1920, 1080, 0.65 },
    { 2730.6666666667, 1536, 1 },
}) do
    screenWidth, screenHeight, UIParent.scale = scenario[1], scenario[2], scenario[3]
    tick()
    for _, groupScale in ipairs({ 0.4, 1, 1.5, 3 }) do
        enter("-120.25", "80.5", tostring(groupScale * 100))
        invoke(apply, "OnClick")
        local x, y = actualCenter(subject)
        local label = "UI=" .. UIParent.scale .. " group=" .. groupScale
        equal(x, -120.25, "numeric actual center x " .. label)
        equal(y, 80.5, "numeric actual center y " .. label)
        tick()
        equal(physicalWidth(handle), physicalWidth(region), "resized anchor region handle " .. label)
    end
end
-- A diagonal 10% outward drag preserves the opposite corner and grows artwork 10%.
local bottomRightGrip
for _, object in ipairs(all) do
    local anchor = object.points[1]
    if object.parent == handle and anchor and anchor[3] == "BOTTOMRIGHT" and object:GetScript("OnDragStart") then
        bottomRightGrip = object
    end
end
screenWidth, screenHeight, UIParent.scale = 1365.3333333333, 768, 0.9
tick()
enter("0", "0", "150")
invoke(apply, "OnClick")
tick()
local oldLeft, oldBottom, oldWidth, oldHeight = rect(subject)
local oldTop = oldBottom + oldHeight
cursorX, cursorY = oldLeft + oldWidth, oldBottom
invoke(bottomRightGrip, "OnDragStart")
cursorX, cursorY = cursorX + oldWidth * 0.1, cursorY - oldHeight * 0.1
tick()
invoke(bottomRightGrip, "OnDragStop")
local dragLeft, dragBottom, dragWidth, dragHeight = rect(subject)
equal(dragLeft, oldLeft, "uniform corner resize preserves opposite left")
equal(dragBottom + dragHeight, oldTop, "uniform corner resize preserves opposite top")
equal(dragWidth, oldWidth * 1.1, "uniform corner resize grows physical width 10 percent")
equal(dragHeight, oldHeight * 1.1, "uniform corner resize grows physical height 10 percent")
-- Dimension-based chat resizing preserves the opposite top-left corner.
local chatBottomRightGrip
for _, object in ipairs(all) do
    local anchor = object.points[1]
    if object.parent == chatHandle and anchor and anchor[3] == "BOTTOMRIGHT" and object:GetScript("OnDragStart") then
        chatBottomRightGrip = object
    end
end
local chatLeft, chatBottom, chatWidth, chatHeight = rect(chatOwner)
local chatTop = chatBottom + chatHeight
cursorX, cursorY = chatLeft + chatWidth, chatBottom
invoke(chatBottomRightGrip, "OnDragStart")
cursorX, cursorY = cursorX + 72 * UIParent.scale, cursorY - 34 * UIParent.scale
tick()
invoke(chatBottomRightGrip, "OnDragStop")
local resizedLeft, resizedBottom, resizedWidth, resizedHeight = rect(chatOwner)
equal(resizedLeft, chatLeft, "chat dimension resize preserves opposite left")
equal(resizedBottom + resizedHeight, chatTop, "chat dimension resize preserves opposite top")
equal(resizedWidth, chatWidth + 72 * UIParent.scale, "chat dimension resize adds72 local width")
equal(resizedHeight, chatHeight + 34 * UIParent.scale, "chat dimension resize adds34 local height")
invoke(handle, "OnClick")
invoke(confirm, "OnClick")
local saved = SurvivorsDragonUiLayout.actionBar
local beforeX, beforeY = actualCenter(subject)
layout.BeginEdit()
enter("12", "34", "50")
invoke(apply, "OnClick")
layout.CancelEdit()
local restoredX, restoredY = actualCenter(subject)
equal(restoredX, beforeX, "cancel returns actual center x")
equal(restoredY, beforeY, "cancel returns actual center y")
equal(SurvivorsDragonUiLayout.actionBar, saved, "cancel leaves confirmed normalized coordinates")
layout.Reset()
local x, y = actualCenter(subject)
equal(x, 0, "reset actual center x")
equal(y, 55 + 36 / 2 - screenHeight / UIParent.scale / 2, "reset bottom anchor actual center y")
print("native geometry passed=" .. passed .. " failed=" .. failed)
if failed > 0 then os.exit(1) end
