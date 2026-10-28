-- CI only: production minimap choice/lifecycle with explicit frame/date boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")
local context = H.New()
local env = context.env
context:Load("core/display.lua", "Display")
local display = env.DFRL.display
local panel = env.CreateFrame("Frame", nil, env.UIParent)
local frame = env.CreateFrame("Frame", nil, panel)
local label = frame:CreateFontString(nil, "OVERLAY")
local zoneButton = env.CreateFrame("Button", nil, panel)
local zoneText = zoneButton:CreateFontString(nil, "OVERLAY")
function zoneButton:SetPoint(...) self.point = { ... } end
function zoneText:SetJustifyH(value) self.justify = value end
local reads, value = 0, "12:34"
env.date = function(format)
    assert(format == "%H:%M")
    reads = reads + 1
    return value
end
env.GetTime = function() error("the minimap clock polled native UI time per frame") end
env.GameTooltip = {
    IsOwned = function(_, owner) return owner == frame end,
    Hide = function() context.tooltipHides = (context.tooltipHides or 0) + 1 end,
}
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
chunk()(frame, label, zoneButton, zoneText, panel)
assert(display.Get("minimapShowClock") == false, "clock must default off")
assert(display.Copy({ minimapShowClock = "true" }).minimapShowClock == false, "invalid clock choice must default off")
assert(
    reads == 0 and not frame:IsShown() and frame:GetScript("OnUpdate") == nil,
    "default-off clock started its worker"
)
assert(zoneButton.point[1] == "CENTER" and zoneButton.point[2] == panel and zoneText.justify == "CENTER")
for _ = 1, 100 do
    context:Call(frame, "OnUpdate", 1)
end
assert(reads == 0, "disabled clock sampled time")

display.BeginEdit()
display.Set("minimapShowClock", true)
assert(reads == 1 and label:GetText() == "12:34" and frame:IsVisible())
assert(not env.SurvivorsDragonUiDisplay, "clock preview saved early")
assert(zoneButton.point[1] == "LEFT" and zoneText.justify == "LEFT")
context:ResetCounts()
for _ = 1, 40 do
    context:Call(frame, "OnUpdate", 0.1)
end
assert(reads == 1, "clock sampled before its five-second interval")
context:NoPresentationWrites()
context:Call(frame, "OnUpdate", 1.1)
assert(reads == 2 and not context.writes.SetText, "unchanged minute was repainted")
panel:Hide()
assert(frame:GetScript("OnUpdate") == nil, "hidden minimap retained the clock callback")
value = "12:35"
context:Call(frame, "OnUpdate", 20)
assert(reads == 2, "hidden clock sampled local time")
panel:Show()
assert(label:GetText() == "12:35" and reads == 3 and frame:GetScript("OnUpdate"))
context:Call(frame, "OnUpdate", 4.9)
assert(reads == 3, "Show retained a pre-hide deadline")
context:Call(frame, "OnUpdate", 0.2)
assert(reads == 4)

display.FinishEdit(false)
assert(not display.Get("minimapShowClock") and not frame:IsShown() and not frame:GetScript("OnUpdate"))
assert(zoneButton.point[1] == "CENTER" and zoneText.justify == "CENTER", "Cancel lost centered zone text")
display.BeginEdit()
display.Set("minimapShowClock", true)
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.minimapShowClock, "Confirm lost the clock choice")
local previousReads = reads
display.BeginEdit()
display.Load({ minimapShowClock = false })
assert(not frame:IsShown() and not frame:GetScript("OnUpdate"), "profile preview left clock work running")
display.FinishEdit(false)
assert(display.Get("minimapShowClock") and frame:GetScript("OnUpdate") and reads == previousReads + 1)
display.Reset()
assert(not display.Get("minimapShowClock") and not frame:IsShown() and not frame:GetScript("OnUpdate"))
assert(zoneText.justify == "CENTER", "reset did not restore centered zone text")
print("PASS default-off minimap clock, centered zone, preview/discard/Confirm/profile/reset and hidden recovery")
