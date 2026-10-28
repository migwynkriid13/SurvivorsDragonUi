-- CI only: extracted production visibility transitions over explicit native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local function Load(path, env)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    return chunk()
end

local context = H.New()
local env = context.env
local function Frame() return env.CreateFrame("Frame", nil, env.UIParent) end
env.frame, env.health, env.mana, env.border = Frame(), Frame(), Frame(), Frame()
env.defaultWidth, env.healthWidth, env.manaWidth, env.healthUnderlap = 128, 68, 68, 0.5
env.values = { healthLabels = { SetInsets = function() end } }
env.resizeFullBorder, env.resizeHealthBorder = function() end, function() end
env.fullBorder, env.healthOnlyBorder = {}, {}
for index = 1, 15 do
    env.healthOnlyBorder[index] = env.border:CreateTexture(nil, "BORDER")
    if index <= 3 then env.fullBorder[index] = env.border:CreateTexture(nil, "BORDER") end
end
env.DFRL.layout.IsEditing = function() return false end
local update = Load(assert(arg[1]), env)
context.settings.classResources = true
update()
for _, strip in ipairs(env.healthOnlyBorder) do
    assert(not strip:IsShown(), "inactive party border remained submitted at zero alpha")
end
for _, strip in ipairs(env.fullBorder) do
    assert(strip:IsShown(), "active party border disappeared")
end
context:ResetCounts()
update()
context:NoPresentationWrites()
context.settings.classResources = false
update()
for _, strip in ipairs(env.fullBorder) do
    assert(not strip:IsShown(), "resource border remained shown after disabling resources")
end
for _, strip in ipairs(env.healthOnlyBorder) do
    assert(strip:IsShown(), "health-only border did not restore")
end

env.borderFrame, env.portraitless = Frame(), Frame()
env.RefreshEditRegion, env.SetPortraitOverlap = function() end, function() end
local portraits = Load(assert(arg[2]), env)
context.settings.hidePortraits = true
portraits()
assert(not env.borderFrame:IsShown() and env.portraitless:IsShown(), "portrait border was only alpha masked")
context.settings.hidePortraits = false
portraits()
assert(env.borderFrame:IsShown() and not env.portraitless:IsShown(), "portrait border did not restore")

env.borderStrips = { env.border:CreateTexture(nil, "OVERLAY"), env.border:CreateTexture(nil, "OVERLAY") }
local mini = Load(assert(arg[3]), env)
context.settings.hidePortraits = true
mini()
for _, strip in ipairs(env.borderStrips) do
    assert(not strip:IsShown(), "target-of-target border remained submitted")
end
context.settings.hidePortraits = false
mini()
for _, strip in ipairs(env.borderStrips) do
    assert(strip:IsShown(), "target-of-target border did not restore")
end
print("PASS inactive unit border variants are actually hidden and reused")
