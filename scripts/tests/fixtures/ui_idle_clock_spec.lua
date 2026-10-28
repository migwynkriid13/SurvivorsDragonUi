-- CI only: production minimap clock lifecycle over explicit frame/date boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")
local context = H.New()
local env = context.env
local frame = env.CreateFrame("Frame", nil, env.UIParent)
local label = frame:CreateFontString(nil, "OVERLAY")
local reads, value = 0, "12:34"
env.date = function(format)
    assert(format == "%H:%M")
    reads = reads + 1
    return value
end
env.GetTime = function() error("the minimap clock polled native UI time per frame") end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
chunk()(frame, label)
assert(reads == 1 and label:GetText() == "12:34")
context:ResetCounts()
for _ = 1, 40 do
    context:Call(frame, "OnUpdate", 0.1)
end
assert(reads == 1, "clock sampled before its five-second interval")
context:NoPresentationWrites()
context:Call(frame, "OnUpdate", 1.1)
assert(reads == 2 and not context.writes.SetText, "unchanged minute was repainted")
frame:Hide()
assert(frame:GetScript("OnUpdate") == nil, "hidden clock retained its callback")
value = "12:35"
context:Call(frame, "OnUpdate", 20)
assert(reads == 2, "hidden clock sampled local time")
frame:Show()
assert(label:GetText() == "12:35" and reads == 3 and frame:GetScript("OnUpdate"))
context:Call(frame, "OnUpdate", 4.9)
assert(reads == 3, "Show retained a pre-hide deadline")
context:Call(frame, "OnUpdate", 0.2)
assert(reads == 4)
print(
    "PASS minimap clock detaches while hidden, resumes immediately and uses frame elapsed without native time polling"
)
