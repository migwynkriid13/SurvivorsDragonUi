-- CI only: actual chat frame callback over explicit native boundaries.
assert(_VERSION == "Lua 5.1")
local now, reads, alphaCalls, layouts, panePasses = 10, 0, 0, 0, 0
local selected = { native = {}, visualAlpha = 1 }
function selected.native:GetAlpha() return self.alpha or 1 end
function selected.native:SetAlpha(value)
    alphaCalls = alphaCalls + 1
    self.alpha = value
end
selected.nativeSetAlpha = selected.native.SetAlpha
function selected.native:IsShown() return self.shown ~= false end
function selected.native:Show() self.shown = true end
local env = setmetatable({
    root = { IsVisible = function() return true end },
    states = { selected },
    activeStates = {},
    selected = selected,
    refresh = 0,
    GetTime = function()
        reads = reads + 1
        return now
    end,
    AtBottom = function() return true end,
    Flag = function(value) return value == true or value == 1 end,
    FadeSettings = function() end,
    UpdateIndicator = function() end,
    ReadDimensions = function() layouts = layouts + 1 end,
    PositionInput = function() end,
    RefreshFrames = function() end,
    PositionNative = function(_, sample) assert(sample == now) end,
    Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end,
    SLIDE = 0.35,
    FADE = 0.6,
}, { __index = _G })
env.pairs = function(list)
    if list == env.states then panePasses = panePasses + 1 end
    return pairs(list)
end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local update = chunk()
env.arg1 = 0.01
for _ = 1, 20 do
    update()
end
assert(reads == 0 and alphaCalls == 0 and panePasses == 0, "idle chat read time, visited panes or reapplied opacity")
selected.native.alpha, selected.native.shown = 0.3, false
update()
assert(alphaCalls == 1 and selected.native.alpha == 1 and selected.native.shown, "idle native repair was skipped")
env.arg1 = 0.81
update()
assert(reads == 1 and layouts == 1, "one-second repair did not take a fresh native time sample")
assert(panePasses == 0, "periodic chat repair still traversed inactive panes")
selected.slideStart, selected.revealStart = now, now
selected.pendingLevel = { deadline = now + 0.1 }
env.activeStates[selected] = true
local delivered = 0
function selected.FlushLevel()
    delivered = delivered + 1
    selected.pendingLevel = nil
end
reads, env.arg1 = 0, 0.05
now = 10.05
update()
assert(reads == 1 and selected.visualAlpha > 0 and delivered == 0, "active animation did not share fresh time")
now = 10.4
update()
assert(reads == 2 and delivered == 1 and selected.slideStart == nil, "pending message/final slide sample was skipped")
now = 10.7
update()
assert(selected.revealStart == nil and selected.visualAlpha == 1, "reveal did not complete")
reads = 0
update()
assert(reads == 0 and next(env.activeStates) == nil, "settled effects retained frame work")
print(
    "PASS idle chat skips pane traversal and opacity calls; native repair, animation and pending delivery stay current"
)

-- Exercise scheduling through real AddMessage, wheel, mode and visibility owners.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
for _, performance in ipairs({ false, true }) do
    local current = H.New()
    local native = current.env
    current.settings.performanceMode = performance
    local create = current.Object
    function current:Object(...)
        local object = create(self, ...)
        function object:SetParent(parent) self.parent = parent end
        function object:GetNumPoints() return self.point and 1 or 0 end
        function object:GetPoint() return unpack(self.point or {}) end
        function object:ClearAllPoints() self.point = nil end
        function object:SetPoint(...) self.point = { ... } end
        function object:GetRegions() return end
        function object:EnableMouseWheel() end
        function object:SetResizable() end
        function object:SetSpacing() end
        function object:SetIndentedWordWrap() end
        function object:SetBackdrop() end
        return object
    end
    native.NUM_CHAT_WINDOWS = 2
    native.T.SetChatFont = function(frame)
        local key = frame == native.ChatFrame1 and "selectedFont"
            or frame == native.ChatFrame2 and "inactiveFont"
            or frame == native.ChatFrameEditBox and "inputFont"
        if key then current.reads[key] = (current.reads[key] or 0) + 1 end
    end
    native.DFRL.locale.Bind = function() end
    native.IsShiftKeyDown = function() return false end
    native.DFRL.CleanerChat = {
        PrettifyMessage = function(text)
            if text == "Level" then return text, "level" end
            if text == "Stats" then return text, "level_stats" end
            return text
        end,
    }
    local delivered = {}
    local function NewPane(index)
        local pane = native.CreateFrame("ScrollingMessageFrame", "ChatFrame" .. index, native.UIParent)
        pane:RegisterEvent("UPDATE_CHAT_WINDOWS")
        function pane:SetTimeVisible(value) self.hold = value end
        function pane:SetFadeDuration(value) self.duration = value end
        function pane:SetFading(value) self.fading = value end
        function pane:AtBottom() return not self.scrolled end
        function pane:ScrollUp() self.scrolled = true end
        function pane:ScrollDown() self.scrolled = false end
        function pane:AddMessage(text) table.insert(delivered, { pane = self, text = text }) end
        return pane
    end
    NewPane(1)
    NewPane(2)
    local input = native.CreateFrame("EditBox", "ChatFrameEditBox", native.UIParent)
    function input:GetTextInsets() return unpack(self.insets or {}) end
    function input:SetTextInsets(...) self.insets = { ... } end
    input:Hide()
    current:Load("modules/chat/chat.lua", "Chat")
    local root, pane, other = native.SurvivorsDragonUiChat, native.ChatFrame1, native.ChatFrame2
    local function Tick(elapsed)
        current.now = current.now + elapsed
        current:Call(root, "OnUpdate", elapsed)
    end
    local allocated = #current.objects
    pane:SetAlpha(0)
    other:SetAlpha(1)
    assert(pane:GetAlpha() == 1 and other:GetAlpha() == 0, "native opacity requests bypassed selected-pane ownership")
    pane:AddMessage("Level")
    assert(#delivered == 0, "level message bypassed its original coalescing window")
    Tick(0.1)
    pane:AddMessage("Stats")
    assert(#delivered == 1 and delivered[1].text == "Level: Stats", "active scheduling lost stat coalescing")
    other:AddMessage("Level")
    Tick(0.26)
    assert(#delivered == 2 and delivered[2].pane == other, "inactive pane lost pending delivery")
    pane:AddMessage("Normal")
    Tick(0.1)
    local _, _, _, _, y = pane:GetPoint()
    assert((performance and y == -5) or (not performance and y < -5), "message slide changed with idle scheduling")
    Tick(0.7)
    local footer
    for _, object in ipairs(current.objects) do
        if object.kind == "FontString" and object:GetText() == "Scroll down for latest messages" then
            footer = object:GetParent()
        end
    end
    assert(footer and not footer:IsShown(), "chat did not prepare its hidden history footer")
    local rootVisible = root.IsVisible
    function root:IsVisible()
        current.reads.rootVisible = (current.reads.rootVisible or 0) + 1
        return rootVisible(self)
    end
    current:ResetCounts()
    for _ = 1, 10 do
        Tick(0.01)
    end
    assert((current.writes.SetAlpha or 0) == 0, "settled chat kept writing opacity")
    assert(current.reads.rootVisible == 10, "settled hidden footer repeated the root visibility check")
    pane.scrolled = true
    Tick(0.01)
    assert(footer:IsShown(), "sampled native scrolling did not show the history footer")
    current:ResetCounts()
    Tick(0.01)
    assert(current.reads.rootVisible == 1, "settled visible footer repeated the root visibility check")
    pane.scrolled = false
    Tick(0.01)
    assert(not footer:IsShown(), "sampled native scrolling did not retire the history footer")
    pane.alpha, pane.shown = 0.2, false
    Tick(0.01)
    assert(pane:GetAlpha() == 1 and pane:IsShown(), "native visibility/opacity repair was lost")
    current.now = current.now + 20
    current:Call(root, "OnMouseWheel", 1)
    Tick(0.1)
    assert(pane.fading == false, "wheel navigation stopped holding native history")
    assert((performance and pane:GetAlpha() == 1) or (not performance and pane:GetAlpha() < 1))
    Tick(0.7)
    assert(pane:GetAlpha() == 1, "history reveal did not settle")
    current:Call(root, "OnMouseWheel", -1)
    Tick(0.01)
    assert(pane.fading == true, "returning to the bottom did not restore native expiry")
    pane:AddMessage("Level")
    root:Hide()
    Tick(0.3)
    assert(#delivered == 3, "hidden chat delivered pending text early")
    current:SetSetting("performanceMode", not performance)
    root:Show()
    Tick(0.01)
    assert(#delivered == 4 and delivered[4].text == "Level", "Show/mode change discarded pending delivery")
    Tick(0.7)
    assert(pane:GetAlpha() == 1 and #current.objects == allocated, "mode recovery replayed opacity or allocated views")
    current:ResetCounts()
    pane.width, other.width, input.width = 1, 2, 3
    Tick(1.1)
    assert(pane:GetWidth() == root:GetWidth() - 6, "selected pane lost its original fallback repair latency")
    assert(
        other:GetWidth() == 2 and input:GetWidth() == 3,
        "periodic chat repair touched an inactive pane or hidden input"
    )
    assert(current.reads.selectedFont == 1 and not current.reads.inactiveFont and not current.reads.inputFont)
    current:Event(other, "UPDATE_CHAT_WINDOWS")
    assert(
        other:GetWidth() == root:GetWidth() - 6 and current.reads.inactiveFont == 1,
        "native window event delayed repair"
    )
    input:Show()
    assert(
        input:GetWidth() == root:GetWidth() and current.reads.inputFont == 1,
        "input Show did not repair immediately"
    )
    input.width = 3
    root:Hide()
    root:Show()
    assert(input:GetWidth() == root:GetWidth(), "root Show retained stale visible input geometry")

    local discovered = {}
    native._G = setmetatable({}, {
        __index = function(_, key)
            if string.find(key, "^ChatFrame%d+$") then discovered[key] = (discovered[key] or 0) + 1 end
            return native[key]
        end,
        __newindex = native,
    })
    native.NUM_CHAT_WINDOWS = 4
    local fourth = NewPane(4)
    Tick(1.1)
    assert(fourth:GetParent() == root and discovered.ChatFrame3 == 1 and discovered.ChatFrame4 == 1)
    assert(not discovered.ChatFrame1 and not discovered.ChatFrame2, "chat rediscovered its attached prefix")
    Tick(1.1)
    assert(discovered.ChatFrame3 == 2 and discovered.ChatFrame4 == 1, "chat repeated lookup above a missing slot")
    local third = NewPane(3)
    current:Event(pane, "UPDATE_CHAT_WINDOWS")
    assert(
        third:GetParent() == root and discovered.ChatFrame3 == 3,
        "chat did not attach a late pane on its window event"
    )
    Tick(1.1)
    assert(discovered.ChatFrame3 == 3 and discovered.ChatFrame4 == 1, "chat did not settle after all panes attached")
end
print(
    "PASS real chat retains messages and input while periodic layout repair visits only the selected pane and visible input"
)
