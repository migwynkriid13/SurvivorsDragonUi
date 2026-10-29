-- CI only: actual waypoint interpolation and frame update over native samples.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")
local context = H.New()
local env = context.env
local east, north, distance, stamp, facing = 3, 4, 5, 10, 0
local phase, enabled = "playing", true
local atanReads, wraps = 0, 0
env.math = {}
for key, value in pairs(math) do
    env.math[key] = value
end
env.math.atan2 = function(y, x)
    atanReads = atanReads + 1
    return math.atan2(y, x)
end
env.math.floor = function(value)
    wraps = wraps + 1
    return math.floor(value)
end
env.navigation = {
    GuideDelta = function() return east, north, distance, true, stamp end,
    Heading = function() return facing, stamp end,
    Phase = function() return phase end,
}
env.DFRL.display.Get = function() return enabled end
env.UpdateDistance = function(tracker, value) tracker.distance = value end
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local update = chunk()
local tracker = {
    displayKey = "cacheGuidance",
    hud = env.CreateFrame("Frame", nil, env.UIParent),
    pointer = env.UIParent:CreateTexture(nil, "OVERLAY"),
    selected = { key = "cache", x = 1, y = 2 },
}
update(tracker, 0.01)
assert(atanReads == 1 and tracker.distance == 5 and tracker.pointer:IsShown())
atanReads, wraps = 0, 0
context:ResetCounts()
for _ = 1, 60 do
    update(tracker, 1 / 60)
end
assert(atanReads == 0 and wraps == 0, "settled waypoint recomputed bearing/wrapped settled angles")
context:NoPresentationWrites()
east, north, distance, facing, stamp = 4, 3, 6, 0.2, 10.1
update(tracker, 0.05)
assert(atanReads == 1 and tracker.distance > 5 and tracker.distance < 6, "fresh movement did not retain interpolation")
update(tracker, 0.1)
assert(tracker.distance == 6, "interpolation did not finish at its native sample")
local expected = math.atan2(4, 3) + 0.2
assert(math.abs(tracker.pointerAngle - expected) < 0.0000001, "bearing or heading equation changed")
atanReads, wraps = 0, 0
update(tracker, 0.01)
assert(atanReads == 0 and wraps == 0, "settled new sample repeated interpolation math")
phase, distance, stamp = "paused", 8, 10.2
update(tracker, 0.05)
assert(tracker.distance == 8, "paused source was extrapolated")
phase, distance, stamp = "playing", 7, 9
update(tracker, 0.05)
assert(tracker.distance == 7, "regressed native time reused prior interpolation")
tracker.hud:Hide()
context:ResetCounts()
update(tracker, 0.01)
assert(tracker.presentation == nil, "hidden guide retained interpolation state")
assert(not tracker.pointer:IsShown(), "hidden guide retained its arrow's shown state")
context:ResetCounts()
update(tracker, 0.01)
context:NoPresentationWrites()
enabled = false
update(tracker, 0.01)
assert(not tracker.hud:IsShown() and not tracker.pointer:IsShown(), "disabled guide retained visible content")
enabled = true
update(tracker, 0.01)
assert(tracker.hud:IsShown() and tracker.pointer:IsShown(), "restored guide did not show its current arrow")
tracker.selected = nil
update(tracker, 0.01)
assert(
    not tracker.hud:IsShown() and not tracker.pointer:IsShown() and tracker.presentation == nil,
    "an unavailable destination retained guidance or interpolation"
)
context:ResetCounts()
update(tracker, 0.01)
context:NoPresentationWrites()
print("PASS settled waypoint math skips while movement, heading, pauses, regressions and hidden retirement remain")
