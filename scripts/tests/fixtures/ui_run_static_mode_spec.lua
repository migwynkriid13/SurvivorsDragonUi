-- CI only: production rank/mode styling and effects over explicit native sinks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "timer fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local create = context.Object
local textures, viewports = {}, {}
function context:Object(...)
    local object = create(self, ...)
    if object.kind == "ScrollFrame" then
        table.insert(viewports, object)
        function object:SetScrollChild(child) self.child = child end
    elseif object.kind == "Texture" then
        table.insert(textures, object)
        object.geometryWrites = {}
        for _, key in ipairs({ "SetWidth", "SetPoint", "SetTexCoord", "ClearAllPoints" }) do
            local method, original = key, object[key]
            object[method] = function(self, ...)
                self.geometryWrites[method] = (self.geometryWrites[method] or 0) + 1
                original(self, ...)
            end
        end
    end
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
local nearlyEqual = env.T.NearlyEqual
env.T.NearlyEqual = function(a, b)
    context.reads.geometry = (context.reads.geometry or 0) + 1
    return nearlyEqual(a, b)
end
local chunk = assert(loadfile(assert(arg[1], "missing extracted timer source")))
setfenv(chunk, env)
local source = chunk()
local allocated = #textures
source.Appearance(nil, false)
assert(env.runBar.fillTexture == "timer\\FillBlue.blp" and not source.effects.Appearance)
source.Appearance(5, true)
assert(env.runBar.fillTexture == "timer\\FillWhite.blp" and env.runBar.fillColor[1] == 0.72)
assert(#textures == allocated and #viewports == 0, "Performance Mode allocated decoration")
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
assert(#textures == allocated and #viewports == 0, "empty regular progress allocated unused effects")
source.Update(10, 960)
assert(#textures == allocated + 44 and #viewports == 2, "normal progress allocated unexpected effects")
local fillClip, foamClip = viewports[1], viewports[2]
assert(fillClip.child and foamClip.child and fillClip:IsShown() and foamClip:IsShown())
assert(
    fillClip:GetFrameLevel() == env.runBar:GetFrameLevel() and foamClip:GetFrameLevel() == env.runBar:GetFrameLevel()
)
assert(fillClip:GetHeight() == 15 and foamClip:GetHeight() == 15)
assert(math.abs(fillClip:GetWidth() - 280 * 10 / 960) < 1e-9)
assert(math.abs(foamClip:GetWidth() - fillClip:GetWidth() - 6) < 1e-9)
local glints = { 2, 5, 10, 18, 28 }
for tier = 1, 5 do
    source.Appearance(tier, false)
    context.now = context.now + 0.04
    source.Update(500, 960)
    assert(#textures == allocated + 44 + glints[tier], "rank changes rebuilt or overallocated the pool")
    context:ResetCounts()
    source.Appearance(tier, false)
    context:NoPresentationWrites()
end
local prepared = #textures
source.Appearance(2, true)
context.now = context.now + 0.04
source.Update(42, 960)
assert(env.runBar.fillColor[1] == 0.2 and env.runBar.fillColor[2] == 0.34, "Endless replaced the Heroic palette")
local points, glow = 0, nil
for index = allocated + 1, prepared do
    local texture = textures[index]
    if texture:GetTexture() == "timer\\FillWhite.blp" then glow = texture end
    if texture:IsShown() and texture:GetWidth() <= 8 and texture:GetHeight() <= 5 then points = points + 1 end
end
assert(glow and glow:GetWidth() == 280, "received Endless did not use full decorative width")
assert(fillClip:GetWidth() == 280 and foamClip:GetWidth() == 280, "Endless foam escaped the pill")
assert(points >= 3 and #textures == prepared, "Endless glitter lost its reusable pinpoints")
context:ResetCounts()
context.now = context.now + 0.001
source.Update(42, 960)
context:NoPresentationWrites()
assert(not context.reads.geometry and not context.reads.pulses, "settled Endless repeated geometry or painted early")
source.Appearance(2, false)
context.now = context.now + 0.04
source.Update(42, 960)
assert(math.abs(glow:GetWidth() - 280 * 42 / 960) < 1e-9, "regular progress retained full Endless clipping")
context:ResetCounts()
env.runBar.layoutWidth = 300
context.now = context.now + 0.001
source.Update(42, 960)
assert(math.abs(glow:GetWidth() - 300 * 42 / 960) < 1e-9 and context.reads.pulses, "resize missed immediate clipping")
source.Appearance(0, true)
context.now = context.now + 0.04
source.Update(0, 960)
assert(
    env.runBar.fillTexture == "timer\\FillBlue.blp" and not glow:IsShown(),
    "normal Endless inherited Heroic red decoration"
)
env.performanceMode = true
source.Hide()
assert(not fillClip:IsShown() and not foamClip:IsShown(), "Performance Mode retained a clip viewport")
source.Appearance(0, true)
for index = allocated + 1, prepared do
    assert(not textures[index]:IsShown(), "Performance Mode retained a cosmetic region")
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
assert(#textures == prepared and context.reads.pulses, "mode exit rebuilt or failed to restore effects")
source.Appearance(10, false)
assert(source.effects.tier == 5, "higher ranks exceeded the known palette")
source.Appearance(1.5, false)
assert(
    source.effects.tier == 0 and env.runBar.fillTexture == "timer\\FillBlue.blp",
    "invalid rank retained the last Heroic style"
)
source.Hide()
for index = allocated + 1, prepared do
    assert(not textures[index]:IsShown(), "retirement retained a decorative region")
end
print(
    "PASS API-driven tier palettes, lazy bounded effects, Endless width/glitter, throttle, retirement and Performance Mode"
)

env.runBar.layoutWidth = 280
source.Appearance(5, false)
source.Update(940, 960)
local edge = textures[allocated + 45]
local interior = textures[allocated + 46]
assert(edge:GetWidth() == 14 and interior:GetWidth() == 14, "glints changed source width before native clipping")
assert(edge:GetParent() == fillClip.child and interior:GetParent() == fillClip.child)
assert(not edge.geometryWrites.SetTexCoord and not interior.geometryWrites.SetTexCoord, "glints set a dynamic crop")
edge.geometryWrites, interior.geometryWrites = {}, {}
context:ResetCounts()
context.now = context.now + 0.1
source.Update(942, 960, true)
context:NoPresentationWrites()
assert(not context.reads.pulses, "an advancing native fill forced an already-due cosmetic paint")
context.now = context.now + 0.001
source.Update(942, 960)
assert(context.reads.pulses and math.abs(glow:GetWidth() - 280 * 942 / 960) < 1e-9)
assert(math.abs(fillClip:GetWidth() - 280 * 942 / 960) < 1e-9)
assert(foamClip:GetWidth() == 280, "foam escaped the pill near completion")
assert(edge.geometryWrites.SetPoint == 1 and not edge.geometryWrites.SetWidth and not edge.geometryWrites.SetTexCoord)
assert(
    interior.geometryWrites.SetPoint == 1
        and not interior.geometryWrites.SetWidth
        and not interior.geometryWrites.SetTexCoord
        and not context.writes.SetTexCoord
        and not context.writes.ClearAllPoints,
    "an unclipped glint rebuilt its dimensions, crop or anchor list"
)
context:ResetCounts()
context.now = context.now + 0.04
source.Update(942, 960)
context:NoPresentationWrites()
assert(not context.reads.pulses, "the settled effect exceeded its 20 Hz cap")
source.Update(920, 960)
assert(context.reads.pulses and math.abs(glow:GetWidth() - 280 * 920 / 960) < 1e-9, "shrink missed immediate clipping")
context:ResetCounts()
source.Update(960, 960)
assert(context.reads.pulses and glow:GetWidth() == 280, "completion did not immediately paint the exact limit")
assert(fillClip:GetWidth() == 280 and foamClip:GetWidth() == 280)
assert(not context.writes.SetTexCoord, "completion reintroduced a material crop")
assert(#textures == prepared, "progress and correction rebuilt the effect pool")
print("PASS progress growth defers cosmetic writes, clips corrections immediately and reuses settled glint geometry")
