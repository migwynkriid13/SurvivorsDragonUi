-- CI only: production rank/mode styling and effects over explicit native sinks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "timer fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local create = context.Object
function context:Object(...)
    local object = create(self, ...)
    function object:SetBlendMode(mode) self.blendMode = mode end
    function object:SetStatusBarTexture(texture)
        context.writes.fillTexture = (context.writes.fillTexture or 0) + 1
        self.fillTexture = texture
    end
    function object:SetStatusBarColor(...)
        context.writes.fillColor = (context.writes.fillColor or 0) + 1
        self.fillColor = { ... }
    end
    return object
end
env.path = "timer\\"
env.runBar = env.CreateFrame("StatusBar", nil, env.UIParent)
env.runBar:SetHeight(15)
env.performanceMode = true
env.GetTime = function()
    context.reads.clock = (context.reads.clock or 0) + 1
    return context.now
end
env.math = {}
for name, value in pairs(math) do
    env.math[name] = value
end
env.math.sin = function(...)
    context.reads.pulses = (context.reads.pulses or 0) + 1
    return math.sin(...)
end
local chunk = assert(loadfile(assert(arg[1], "missing extracted timer source")))
setfenv(chunk, env)
local source = chunk()
local allocated = #context.objects
source.Appearance(nil, false)
assert(env.runBar.fillTexture == "timer\\FillBlue.blp" and not source.effects.Appearance)
source.Appearance(5, true)
assert(env.runBar.fillTexture == "timer\\FillWhite.blp" and env.runBar.fillColor[1] == 0.72)
assert(#context.objects == allocated, "Performance Mode allocated decoration")
context:ResetCounts()
for _ = 1, 60 do
    source.Appearance(5, true)
    source.Update(960, 960)
end
context:NoPresentationWrites()
assert(not next(context.reads) and not next(context.writes), "static timer retained cosmetic work")
env.performanceMode = false
source.Appearance(0, false)
source.Update(0, 960)
assert(#context.objects == allocated, "empty regular progress allocated unused effects")
source.Update(10, 960)
assert(#context.objects == allocated + 44, "normal progress allocated unused glints")
local glints = { 2, 5, 10, 18, 28 }
for tier = 1, 5 do
    source.Appearance(tier, false)
    context.now = context.now + 0.04
    source.Update(500, 960)
    assert(#context.objects == allocated + 44 + glints[tier], "rank changes rebuilt or overallocated the pool")
    context:ResetCounts()
    source.Appearance(tier, false)
    context:NoPresentationWrites()
end
local prepared = #context.objects
source.Appearance(2, true)
context.now = context.now + 0.04
source.Update(42, 960)
assert(env.runBar.fillColor[1] == 0.2 and env.runBar.fillColor[2] == 0.34, "Endless replaced the Heroic palette")
local points, glow = 0, nil
for index = allocated + 1, prepared do
    local texture = context.objects[index]
    if texture:GetTexture() == "timer\\FillWhite.blp" then glow = texture end
    if texture:IsShown() and texture:GetWidth() <= 8 and texture:GetHeight() <= 5 then points = points + 1 end
end
assert(glow and glow:GetWidth() == 280, "received Endless did not use full decorative width")
assert(points >= 3 and #context.objects == prepared, "Endless glitter lost its reusable pinpoints")
context:ResetCounts()
context.now = context.now + 0.001
source.Update(42, 960)
context:NoPresentationWrites()
assert(not context.reads.pulses, "Endless escaped the shared thirty-Hz throttle")
source.Appearance(2, false)
context.now = context.now + 0.04
source.Update(42, 960)
assert(math.abs(glow:GetWidth() - 280 * 42 / 960) < 1e-9, "regular progress retained full Endless clipping")
source.Appearance(0, true)
context.now = context.now + 0.04
source.Update(0, 960)
assert(
    env.runBar.fillTexture == "timer\\FillBlue.blp" and not glow:IsShown(),
    "normal Endless inherited Heroic red decoration"
)
env.performanceMode = true
source.Hide()
source.Appearance(0, true)
for index = allocated + 1, prepared do
    assert(not context.objects[index]:IsShown(), "Performance Mode retained a cosmetic region")
end
context:ResetCounts()
for _ = 1, 60 do
    source.Appearance(0, true)
    source.Update(42, 960)
end
context:NoPresentationWrites()
assert(not next(context.reads) and not next(context.writes), "Performance Mode retained glitter or foam work")
env.performanceMode = false
source.Appearance(5, false)
context.now = context.now + 0.04
source.Update(42, 960)
assert(#context.objects == prepared and context.reads.pulses, "mode exit rebuilt or failed to restore effects")
source.Appearance(10, false)
assert(source.effects.tier == 5, "higher ranks exceeded the known palette")
source.Appearance(1.5, false)
assert(
    source.effects.tier == 0 and env.runBar.fillTexture == "timer\\FillBlue.blp",
    "invalid rank retained the last Heroic style"
)
source.Hide()
for index = allocated + 1, prepared do
    assert(not context.objects[index]:IsShown(), "retirement retained a decorative region")
end
print(
    "PASS API-driven tier palettes, lazy bounded effects, Endless width/glitter, throttle, retirement and Performance Mode"
)
