-- CI only: exact production XP glow with separate native geometry/alpha counters.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
env.bar = env.CreateFrame("StatusBar", nil, env.UIParent)
env.sparkClip = env.CreateFrame("ScrollFrame", nil, env.bar)
local canvas = env.CreateFrame("Frame", nil, env.sparkClip)
env.gain, env.spark = canvas:CreateTexture(nil, "ARTWORK"), canvas:CreateTexture(nil, "ARTWORK")
env.spark:SetWidth(12)
env.width, env.gainStart, env.displayed = 100, 0.2, 0.6
function env.bar:GetLeft()
    if not context.unresolvedEdges then return 20 end
end
function env.bar:GetRight()
    if not context.unresolvedEdges then return 20 + env.width end
end
function env.bar:GetWidth()
    context.reads.width = (context.reads.width or 0) + 1
    return env.width
end
function env.bar:GetBottom() error("XP glow sampled an unused vertical edge") end
env.bar.GetTop, env.bar.GetHeight = env.bar.GetBottom, env.bar.GetBottom
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local paint = chunk()
paint(1)
context:ResetCounts()
paint(0.8)
assert(context.writes.SetAlpha == 2, "fade did not retain both authored alpha updates")
assert(not context.reads.width, "resolved XP glow did not use local horizontal edges")
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
assert(
    env.spark.drawnLeft == env.width - 6 and env.spark:GetWidth() == 12,
    "spark end clipping changed its source quad"
)
assert(not context.writes.SetTexCoord, "spark end clipping rewrote source UVs")
paint(0)
assert(not env.gain:IsShown() and not env.sparkClip:IsShown(), "final fade retained visible effect regions")
context:ResetCounts()
paint(0)
context:NoPresentationWrites()
paint(0.5)
assert(env.gain:IsShown() and env.spark:IsVisible(), "pooled effects did not restore")
context.unresolvedEdges = true
context:ResetCounts()
paint(0.5)
assert(context.reads.width == 1, "unresolved XP edges did not fall back to native width")
context:NoPresentationWrites()
print("PASS XP fades change alpha alone and retain resize, clipping and final-hide behavior")
