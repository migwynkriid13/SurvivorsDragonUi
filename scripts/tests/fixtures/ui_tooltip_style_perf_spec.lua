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
local refreshEnd = assert(string.find(source, "    local function Clear()", refreshStart, true))
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
