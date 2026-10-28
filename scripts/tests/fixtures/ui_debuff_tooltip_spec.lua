-- CI only: production tooltip builder with explicit shared-tooltip ownership.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
env.DFRL.locale.code = "en"
local tooltip = env.CreateFrame("GameTooltip", nil, env.UIParent)
env.GameTooltip = tooltip
tooltip.scale = 1
function tooltip:IsOwned(owner) return self.owner == owner end
function tooltip:GetEffectiveScale() return self.scale end
function tooltip:AddLine() context.writes.AddLine = (context.writes.AddLine or 0) + 1 end
local icon = { effect = { name = "Burn", stacks = 2, remaining = 5.8, duration = 10, dispelType = "Magic" } }
tooltip.owner = icon
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local paint = chunk()
paint(icon, true)
assert(icon.tooltipDrawn and tooltip:GetText() == "Burn")
context:ResetCounts()
icon.effect.remaining = 5.1
paint(icon)
context:NoPresentationWrites()
assert(not context.writes.AddLine, "unchanged tooltip appended native lines")
icon.effect.remaining = 5
paint(icon)
assert(context.writes.SetText == 1, "changed displayed second did not refresh")
context:ResetCounts()
icon.effect.stacks = 3
paint(icon)
assert(context.writes.SetText == 1, "changed stacks did not refresh")
context:ResetCounts()
env.DFRL.locale.code = "de"
paint(icon)
assert(context.writes.SetText == 1, "language change retained old content")
context:ResetCounts()
tooltip.scale = 1.5
paint(icon)
assert(context.writes.SetText == 1, "scale change did not invalidate content")
tooltip:Hide()
context:ResetCounts()
icon.effect.remaining = 3
paint(icon)
context:NoPresentationWrites()
assert(not tooltip:IsShown(), "a hidden tooltip was replayed")
tooltip.owner = {}
context:ResetCounts()
paint(icon, true)
context:NoPresentationWrites()
tooltip.owner = icon
paint(icon, true)
assert(tooltip:IsShown() and context.writes.SetText == 1, "re-entry did not rebuild native content")
print("PASS debuff tooltips skip unchanged rebuilds and respect hidden or foreign ownership")
