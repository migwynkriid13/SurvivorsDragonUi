-- CI only: production static/animated timer owners over fake drawing boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "static timer fixtures require the CI Lua 5.1 interpreter")
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
local chunk = assert(loadfile(assert(arg[1], "missing extracted static timer source")))
setfenv(chunk, env)
local source = chunk()
local allocated = #context.objects
source.Appearance(false)
assert(env.runBar.fillTexture == "timer\\FillBlue.blp" and not source.effects.Appearance)
assert(#context.objects == allocated, "static timer prepared the decorative texture pool")
context:ResetCounts()
for _ = 1, 60 do
    source.Appearance(false)
    source.Update(10, 100)
end
context:NoPresentationWrites()
assert(not next(context.reads) and not next(context.writes), "static timer retained animation math or fill writes")
source.Appearance(true)
assert(env.runBar.fillTexture == "timer\\FillWhite.blp" and env.runBar.fillColor[1] == 0.72)
assert(#context.objects == allocated, "static limit state allocated red glints")

env.performanceMode = false
source.Appearance(true)
assert(#context.objects == allocated + 72, "normal mode lost the original decorative texture pool")
source.Update(100, 100)
assert(context.reads.pulses == 28, "normal mode did not restore every original red glint")
local prepared = #context.objects
env.performanceMode = true
source.Hide()
source.effects.staticAtLimit = nil
source.Appearance(false)
for index = allocated + 1, prepared do
    assert(not context.objects[index]:IsShown(), "performance mode retained a decorative timer region")
end
context:ResetCounts()
source.Update(50, 100)
assert(not next(context.reads), "hidden timer effects still sampled UI time")
env.performanceMode = false
source.Appearance(true)
assert(
    context.writes.fillTexture == 1 and context.writes.fillColor == 1,
    "normal mode trusted the stale animated appearance cache after a static paint"
)
assert(env.runBar.fillTexture == "timer\\FillWhite.blp" and #context.objects == prepared)
context.now = context.now + 0.04
source.Update(100, 100)
assert(context.reads.pulses == 28, "normal mode did not resume the retained original glints")

-- Start from visible regular-run decoration, so hiding a never-painted pool
-- cannot satisfy the static-mode assertions by accident.
source.Appearance(false)
context.now = context.now + 0.04
source.Update(50, 100)
local movingStreaks, blueFoam = false, false
for index = allocated + 1, prepared do
    local texture = context.objects[index]
    if texture:IsShown() then
        if texture:GetWidth() > 20 and texture:GetHeight() <= 4 then movingStreaks = true end
        if texture:GetHeight() > 4 then blueFoam = true end
    end
end
assert(movingStreaks and blueFoam, "normal blue timer did not expose both moving streaks and foam")
env.performanceMode = true
source.Hide()
source.effects.staticAtLimit = nil
source.Appearance(false)
assert(env.runBar.fillTexture == "timer\\FillBlue.blp", "static regular timer lost its plain blue fill")
for index = allocated + 1, prepared do
    assert(not context.objects[index]:IsShown(), "active blue foam or streaks survived the static toggle")
end
context:ResetCounts()
for _ = 1, 60 do
    source.Appearance(false)
    source.Update(50, 100)
end
context:NoPresentationWrites()
assert(not next(context.reads) and not next(context.writes), "static regular timer retained cosmetic work")
env.performanceMode = false
source.Appearance(false)
context.now = context.now + 0.04
source.Update(50, 100)
assert(context.reads.pulses and context.reads.pulses > 0, "normal blue timer did not resume its original animation")
assert(#context.objects == prepared, "restoring blue timer effects replaced the retained pool")
print(
    "PASS static timer removes active blue foam/streaks and red glints, skips cosmetic work and restores cached effects"
)
