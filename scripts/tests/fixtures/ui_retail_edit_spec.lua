-- CI only: production retail magnetism and selection art, with fake native data.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "retail edit fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
context:Load("core/layout_snap.lua")
context:Load("core/editor.lua")
local start = {
    snapReady = true,
    offsetX = 0,
    offsetY = 0,
    rect = { width = 100, height = 40 },
    targets = { { key = "screen", rect = { left = 0, top = 0, width = 1024, height = 768 } } },
    targetCount = 1,
}
local snap = env.T.RetailSnap
local result = snap(start, 7, -200, false, 32, 1)
assert(
    result.dx == -7 and result.dy == 0 and result.guideX == 0,
    "screen edge did not capture at eight physical pixels"
)
assert(snap(start, 9, -200, false, 32, 1).guideX == nil, "a distant screen edge captured")
assert(snap(start, 7, -200, false, 32, 2).guideX == nil, "magnetism ignored effective UI scale")
result = snap(start, 11, -201, true, 32, 1)
assert(result.dx == 3 and result.dy == -3, "grid did not consider the selection center on both axes")
start.targets[2] = { key = "other", rect = { left = 250, top = -200, width = 80, height = 80 } }
start.targetCount = 2
result = snap(start, 143, -210, false, 32, 1)
assert(
    result.dx == 7 and result.dy == 0 and result.target == "other",
    "adjacent frame edge did not capture independently of grid"
)
result = snap(start, 143, -207, false, 32, 1)
assert(result.dx == 7 and result.dy == 7, "retail corner priority was lost")
local reused = result
assert(snap(start, 143, -213, false, 32, 1) == reused, "magnetism replaced its result pool")
assert(reused.dx == 7 and reused.dy == 0, "an out-of-range corner captured the second axis")
start.targetCount = 1
assert(snap(start, 143, -213, false, 32, 1).target == nil, "a retired target remained magnetic")
start.snapReady = false
assert(snap(start, 143, -213, true, 32, 1).guideX == nil, "unready geometry produced a preview")

local handle = env.CreateFrame("Frame", nil, env.UIParent)
local setSelected = env.T.CreateEditModeSelection(handle)
local allocated = #context.objects
setSelected(false)
context:ResetCounts()
setSelected(false)
context:NoPresentationWrites()
setSelected(true)
assert(
    context.writes.SetTexCoord == 9 and #context.objects == allocated,
    "selection did not reuse the nine retail regions"
)
context:ResetCounts()
setSelected(true)
context:NoPresentationWrites()
print("PASS retail physical magnetism, release candidates, corners, grid independence, retirement and static art reuse")
