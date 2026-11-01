-- CI only: production shared skin and refresh with explicit native color state.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "tooltip style fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local frame = env.CreateFrame("GameTooltip", nil, env.UIParent)
function frame:SetBackdrop(value)
    context.writes.backdrop = (context.writes.backdrop or 0) + 1
    self.backdrop = value
end
function frame:GetBackdropColor() return unpack(self.background or {}) end
function frame:GetBackdropBorderColor() return unpack(self.border or {}) end
function frame:SetBackdropColor(...)
    context.writes.background = (context.writes.background or 0) + 1
    self.background = { ... }
end
function frame:SetBackdropBorderColor(...)
    context.writes.border = (context.writes.border or 0) + 1
    if context.failBorder then
        context.failBorder = false
        return
    end
    self.border = { ... }
end
context:Load("core/tooltips.lua")
local style = env.T.StyleHoverCard
style(frame)
assert(context.writes.backdrop == 1 and context.writes.background == 1 and context.writes.border == 1)
context:ResetCounts()
style(frame)
assert(not next(context.writes), "unchanged tooltip skin repeated native color writes")
frame.background, frame.border = { 0, 0, 0, 0 }, { 1, 0, 0, 0.5 }
style(frame)
assert(context.writes.background == 1 and context.writes.border == 1 and not context.writes.backdrop)
context.failBorder = true
style(frame, 0.2, 0.8, 0.2)
context:ResetCounts()
style(frame, 0.2, 0.8, 0.2)
assert(context.writes.border == 1, "failed native border write prevented retry")
context:ResetCounts()
style(frame, 0.2, 0.8, 0.2)
assert(not next(context.writes))
frame.GetBackdropColor, frame.GetBackdropBorderColor = false, false
style(frame)
context:ResetCounts()
style(frame)
assert(context.writes.background == 1 and context.writes.border == 1, "missing native getters lost legacy repair")
frame.GetBackdropColor = function(self) return unpack(self.background) end
frame.GetBackdropBorderColor = function(self) return unpack(self.border) end

local file = assert(io.open("core/tooltips.lua", "r"))
local source = file:read("*a")
file:close()
local constantsStart = assert(string.find(source, "local BACKDROP =", 1, true))
local constantsEnd = assert(string.find(source, "function DFRL.tools.StyleHoverCard", constantsStart, true))
local refreshStart = assert(string.find(source, "    local function Exists(unit)", constantsEnd, true))
local refreshEnd = assert(string.find(source, "    local function Clear(", refreshStart, true))
local body = string.sub(source, constantsStart, constantsEnd - 1)
    .. string.sub(source, refreshStart, refreshEnd - 1)
    .. "\nreturn Refresh"
env.tooltip, env.inWorld, env.currentUnit = frame, true, "target"
env.bar = env.CreateFrame("StatusBar", nil, env.UIParent)
env.GameTooltipTextLeft1 = env.CreateFrame("FontString", nil, frame)
env.UnitIsPlayer = function(unit)
    context.reads.player = (context.reads.player or 0) + 1
    return unit == "target"
end
env.UnitClass = function() return "Mage", "MAGE" end
env.RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.8, b = 0.94 } }
local chunk = assert(loadstring(body, "@production-tooltip-refresh"))
setfenv(chunk, env)
local refresh = chunk()
refresh()
context:ResetCounts()
refresh()
assert(not next(context.writes), "unchanged tooltip refresh repeated style/title/hidden-bar writes")
assert(context.reads.player == 1, "tooltip refresh sampled the same player identity twice")
env.GameTooltipTextLeft1.textColor = { 1, 1, 1, 0.5 }
env.bar:Show()
context:ResetCounts()
refresh()
assert(context.writes.SetTextColor == 1 and context.writes.Hide == 1)
assert(not context.writes.background and not context.writes.border, "native label reset repainted unchanged backdrop")
frame:Hide()
context:ResetCounts()
refresh()
assert(not next(context.writes), "hidden tooltip refresh wrote native styling")
print("PASS tooltip styling skips unchanged native colors while repairing resets and retrying failures")

local function HoverFixture(performance)
    local state = H.New()
    local native = state.env
    state.settings.performanceMode = performance
    local function Count(name) state.writes[name] = (state.writes[name] or 0) + 1 end
    local function Geometry(object)
        function object:GetScale() return self.scale or 1 end
        function object:GetEffectiveScale()
            return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        function object:SetScale(value)
            Count("SetScale")
            self.scale = value
        end
        function object:GetLeft() return 0 end
        function object:GetBottom() return 0 end
        function object:GetNumPoints() return self.point and 1 or 0 end
        function object:GetPoint() return unpack(self.point or {}) end
        function object:ClearAllPoints()
            Count("ClearAllPoints")
            self.point = nil
        end
        function object:SetPoint(...)
            Count("SetPoint")
            self.point = { ... }
        end
        function object:SetBackdrop(value)
            Count("SetBackdrop")
            self.backdrop = value
        end
        function object:GetBackdropColor() return unpack(self.background or {}) end
        function object:GetBackdropBorderColor() return unpack(self.border or {}) end
        function object:SetBackdropColor(...)
            Count("SetBackdropColor")
            self.background = { ... }
        end
        function object:SetBackdropBorderColor(...)
            Count("SetBackdropBorderColor")
            self.border = { ... }
        end
        function object:SetClampedToScreen(value) self.clamped = value end
        return object
    end
    Geometry(native.UIParent)
    local create = native.CreateFrame
    native.CreateFrame = function(kind, name, parent) return Geometry(create(kind, name, parent)) end
    native.WorldFrame = native.CreateFrame("Frame", "WorldFrame", native.UIParent)
    local tip = native.CreateFrame("GameTooltip", "GameTooltip", native.UIParent)
    tip.scale = 0.9
    tip:Hide()
    function tip:IsOwned(owner)
        state.reads.owner = (state.reads.owner or 0) + 1
        return self.owner == owner and 1 or nil
    end
    function tip:SetOwner(owner, anchor)
        self:Hide()
        self.owner, self.nativeAnchor = owner, anchor
        state:Call(self, "OnTooltipCleared")
        return "native owner result"
    end
    function tip:Build(text)
        state:Call(self, "OnTooltipCleared")
        self.text = text
        self:Show()
    end
    function tip:SetAction(slot)
        assert(slot == 12, "native ability slot changed")
        self:Build(state.enhanced and "Ability: cooldown and targets" or "Ability name")
        return 1
    end
    function tip:SetInventoryItem(unit, slot)
        assert(unit == "player" and slot == 16, "native equipment identity changed")
        self:Build("Native item effects")
        return 1, nil, 3
    end
    function tip:SetSpell(slot, book)
        assert(slot == 1 and book == "spell", "native spellbook identity changed")
        self:Build("Native spellbook details")
    end
    function tip:FadeOut() state.fades = (state.fades or 0) + 1 end
    native.SetCVar = function() error("SDUI changed a native tooltip preference") end
    native.GetCursorPosition = function() return 300, 200 end
    native.DFRL.layout.Register = function(key, root, anchor, options)
        assert(key == "tooltip")
        state.layoutFrame, state.options = root, options
        state.layoutMask = native.CreateFrame("Frame", nil, native.UIParent)
        root.parent = state.layoutMask
        anchor(root)
    end
    state.action = native.CreateFrame("Button", nil, native.UIParent)
    state.equipment = native.CreateFrame("Button", nil, native.UIParent)
    state.bag = native.CreateFrame("Button", nil, native.UIParent)
    native.DFRL.actionButtons = { state.action }
    native.DFRL.characterItemButtons = { state.equipment }
    state.enhanced = true
    state:Load("core/tooltips.lua", "Tooltips")
    state.tooltip = tip
    function state:Hover(owner, text)
        assert(tip:SetOwner(owner, "ANCHOR_RIGHT") == "native owner result")
        tip:Build(text or "Native world hover")
    end
    function state:Tick() self:Call(tip, "OnUpdate", 0.2) end
    return state, native, tip
end

for _, performance in ipairs({ false, true }) do
    local state, native, tip = HoverFixture(performance)
    local count = #state.objects
    state.layoutFrame:SetScale(0.36)
    state:Hover(native.UIParent)
    assert(tip:IsShown() and tip:GetScale() == 0.36, "world hover lost Layout scale")
    state:SetLayoutHidden(true)
    assert(not tip:IsShown(), "hiding Tooltip retained the world hover")
    state:Hover(native.WorldFrame)
    assert(not tip:IsShown(), "hidden Tooltip allowed a fresh world hover")
    state:Hover(state.action)
    assert(tip:SetAction(12) == 1 and tip:IsShown(), "hidden Tooltip suppressed native ability details")
    assert(tip.text == "Ability: cooldown and targets" and tip:GetScale() == 0.9)
    assert(tip.point[2] == state.action, "ability tooltip lost icon placement")
    state:ResetCounts()
    state:Tick()
    state:Tick()
    assert(not next(state.writes), "unchanged ability hover repeated presentation writes")
    state:SetLayoutHidden(false)
    state:SetLayoutHidden(true)
    state.layoutFrame:SetScale(2.7)
    state.options.onResize()
    state.options.onReset()
    assert(tip:IsShown() and tip:GetScale() == 0.9, "Tooltip preview/reset changed ability visibility or scale")
    state.enhanced = false
    tip:SetAction(12)
    assert(tip.text == "Ability name", "SDUI overrode disabled native Enhanced Tooltips")
    state.enhanced = true
    tip:SetAction(12)
    assert(tip.text == "Ability: cooldown and targets", "native Enhanced Tooltips no longer controls content")

    state:Hover(state.equipment)
    local present, repair, cost = tip:SetInventoryItem("player", 16)
    assert(present == 1 and repair == nil and cost == 3, "native item returns changed")
    assert(tip:IsShown() and tip:GetScale() == 0.9 and tip.point[2] == state.equipment)
    state:Hover(state.bag, "Native bag item")
    assert(tip:IsShown() and tip:GetScale() == 0.9, "content clear lost an unregistered UI owner")
    state:Tick()
    tip:SetSpell(1, "spell")
    assert(tip:IsShown() and tip.text == "Native spellbook details")
    state:SetSetting("tooltipAtCursor", true)
    assert(tip:IsShown() and tip.point[1] == "BOTTOMLEFT" and tip:GetScale() == 0.9)
    state:SetSetting("tooltipAtCursor", false)

    -- Native owner replacement must retire the UI exemption, even without a
    -- Lua SetOwner call. World hovers may never borrow a previous icon owner.
    tip.owner = native.UIParent
    state:Tick()
    assert(not tip:IsShown(), "replaced UI owner leaked an ability exemption into a world hover")
    tip.owner = state.action
    tip:SetAction(12)
    assert(tip:IsShown() and tip.point[2] == state.action, "unobserved native action owner was not recovered")
    state.action:Hide()
    state:Tick()
    assert(not tip:IsShown(), "hidden ability owner retained its tooltip")
    state.action:Show()
    state:SetLayoutHidden(false)
    assert(not tip:IsShown(), "unhiding Tooltip replayed retired content")
    state:Hover(native.UIParent)
    assert(tip:IsShown() and tip:GetScale() == 2.7, "returning to a world hover lost the current Layout scale")
    state:Hover(state.action)
    state.options.onEdit(true)
    assert(not tip:IsShown(), "Layout editing retained a tooltip over its controls")
    tip:SetAction(12)
    assert(not tip:IsShown(), "native ability tooltip bypassed editor suppression")
    state.options.onEdit(false)
    state:Hover(state.action)
    tip:FadeOut()
    assert(not tip:IsShown() and not state.fades, "hover dismissal no longer closes immediately")
    state:Hover(state.action)
    local events = state:Controller("PLAYER_LOGOUT")
    state:Event(events, "PLAYER_LEAVING_WORLD")
    assert(not tip:IsShown(), "world retirement retained an ability tooltip")
    state:ResetCounts()
    state:Tick()
    assert(not next(state.writes), "hidden retired tooltip performed idle presentation work")
    state:Event(events, "PLAYER_ENTERING_WORLD")
    assert(not tip:IsShown(), "world entry replayed retired tooltip content")
    state:Hover(state.action)
    assert(tip:IsShown() and tip:GetScale() == 0.9, "fresh ability hover did not recover")
    assert(#state.objects == count, "hover transitions allocated another frame or region")
end
print("PASS Tooltip hide/scale preserves native ability/item hovers and settings in both Performance Mode states")
