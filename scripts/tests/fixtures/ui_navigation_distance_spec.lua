-- CI only: exact production waypoint label helper, no client files or game.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "navigation distance fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local formats = 0
env.DFRL.locale.code = "en"
env.DFRL.locale.Native = function(key, values)
    assert(key == "common.yards", "distance used a different native caption")
    formats = formats + 1
    return env.DFRL.locale.code .. ":" .. tostring(values.n) .. " yd"
end
env.DFRL.locale.Text = function(source)
    assert(source == "On map", "missing distance used a different fallback")
    formats = formats + 1
    return env.DFRL.locale.code .. ":" .. source
end
local chunk = assert(loadfile(assert(arg[1], "missing extracted waypoint distance source")))
setfenv(chunk, env)
local UpdateDistance = chunk()
local tracker = { distanceText = env.UIParent:CreateFontString(nil, "OVERLAY") }
UpdateDistance(tracker, 15.1)
assert(tracker.distanceText:GetText() == "en:15 yd", "distance rounding changed")
context:ResetCounts()
for _, distance in ipairs({ 15.1, 15.2, 15.49, 14.51, 15 }) do
    UpdateDistance(tracker, distance)
end
assert(formats == 1, "unchanged rounded distance rebuilt translated text")
context:NoPresentationWrites()
UpdateDistance(tracker, 15.5)
assert(formats == 2 and tracker.distanceText:GetText() == "en:16 yd", "rounded transition did not update")
env.DFRL.locale.code = "de"
UpdateDistance(tracker, 16.1)
assert(formats == 3 and tracker.distanceText:GetText() == "de:16 yd", "language change retained the old distance")
UpdateDistance(tracker, nil)
assert(formats == 4 and tracker.distanceText:GetText() == "de:On map", "unknown distance lost its caption")
context:ResetCounts()
UpdateDistance(tracker, nil)
assert(formats == 4, "unchanged unknown distance rebuilt its caption")
context:NoPresentationWrites()
UpdateDistance(tracker, 0)
assert(formats == 5 and tracker.distanceText:GetText() == "de:0 yd", "zero distance became an unknown location")
tracker.distanceText.text = "native reset"
context:ResetCounts()
UpdateDistance(tracker, 0.1)
assert(formats == 5 and context.writes.SetText == 1, "actual text reset was hidden by the format cache")
context.failText = "de:1 yd"
local succeeded = pcall(UpdateDistance, tracker, 1)
assert(not succeeded and formats == 6, "injected native label failure did not reach the helper")
UpdateDistance(tracker, 1.1)
assert(formats == 6 and tracker.distanceText:GetText() == "de:1 yd", "failed label assignment did not retry")
print("PASS rounded waypoint captions cache formatting and preserve language, unknown values and setter retries")
