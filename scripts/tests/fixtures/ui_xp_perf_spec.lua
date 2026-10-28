-- CI only: exact production XP glow with separate native geometry/alpha counters.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
env.bar = env.CreateFrame("StatusBar", nil, env.UIParent)
env.gain, env.spark = env.bar:CreateTexture(nil, "ARTWORK"), env.bar:CreateTexture(nil, "ARTWORK")
env.width, env.gainStart, env.displayed = 100, 0.2, 0.6
env.T.GetLocalSize = function(frame)
    assert(frame == env.bar)
    return env.width
end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local paint = chunk()
paint(1)
context:ResetCounts()
paint(0.8)
assert(context.writes.SetAlpha == 2, "fade did not retain both authored alpha updates")
for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetWidth", "SetTexCoord", "Show", "Hide" }) do
    assert(not context.writes[name], "stationary XP fade rewrote " .. name)
end
context:ResetCounts()
paint(0.8)
context:NoPresentationWrites()
env.width = 150
paint(0.6)
assert(context.writes.SetPoint == 2 and context.writes.SetWidth == 1, "bar resize retained old glow geometry")
context:ResetCounts()
env.displayed = 1
paint(0.5)
assert(context.writes.SetTexCoord == 1 and env.spark.drawnWidth == 6, "spark end clipping changed")
paint(0)
assert(not env.gain:IsShown() and not env.spark:IsShown(), "final fade retained visible effect regions")
context:ResetCounts()
paint(0)
context:NoPresentationWrites()
paint(0.5)
assert(env.gain:IsShown() and env.spark:IsShown(), "pooled effects did not restore")
print("PASS XP fades change alpha alone and retain resize, clipping and final-hide behavior")
