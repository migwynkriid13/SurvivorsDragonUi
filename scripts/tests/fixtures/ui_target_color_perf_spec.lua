-- CI only: exact production target refresh with native-owned color state.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "target color fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
env.TargetFrame = env.CreateFrame("Frame", nil, env.UIParent)
env.TargetFrameHealthBar = env.CreateFrame("StatusBar", nil, env.TargetFrame)
local bar = env.TargetFrameHealthBar
bar.color = { 1, 0, 0, 1 }
function bar:GetStatusBarColor() return unpack(self.color) end
function bar:SetStatusBarColor(r, g, b)
    context.writes.color = (context.writes.color or 0) + 1
    self.color = { r, g, b, 1 }
end
env.ResizeHealth = function() context.reads.resize = (context.reads.resize or 0) + 1 end
env.healthLabels = { Update = function() context.reads.labels = (context.reads.labels or 0) + 1 end }
env.DFRL.targetHealth = { Refresh = function() context.reads.health = (context.reads.health or 0) + 1 end }
env.UpdateClassification = function(force) context.force = force end
env.UnitIsUnit = function(unit, candidate)
    assert(unit == "target")
    context.reads.alias = (context.reads.alias or 0) + 1
    return (context.player and candidate == "player") or candidate == context.partyAlias
end
local file = assert(io.open("modules/unit/target.lua", "r"))
local source = file:read("*a")
file:close()
local first = assert(string.find(source, "    local function UpdateTarget(forceBorder)", 1, true))
local last = assert(string.find(source, "    HookScript(TargetFrameHealthBar,", first, true))
local colorFirst = assert(string.find(source, "    local setHealthColor =", 1, true))
local colorLast = assert(string.find(source, "    local UpdateBorderTexture,", colorFirst, true))
local body = string.sub(source, colorFirst, colorLast - 1)
    .. string.sub(source, first, last - 1)
    .. "\nreturn UpdateTarget"
local chunk = assert(loadstring(body, "@production-target-refresh"))
setfenv(chunk, env)
local refresh = chunk()
refresh(true)
assert(not context.writes.color and context.reads.labels == 1 and context.reads.health == 1 and context.force == true)
bar.color = { 0.2, 0.8, 0.2, 1 }
refresh(false)
assert(
    context.writes.color == 1 and bar.color[1] == 1 and context.force == false,
    "native color reset was not repaired"
)
context:ResetCounts()
refresh(false)
assert(not context.writes.color and context.reads.labels == 1 and context.reads.health == 1)
context.player = true
refresh(false)
assert(context.writes.color == 1 and bar.color[1] == 0 and bar.color[2] == 1, "friendly target retained enemy red")
context:ResetCounts()
refresh(false)
assert(not context.writes.color and context.reads.alias == 1, "unchanged native player color was repainted")
context.player, context.partyAlias = false, "party2"
refresh(false)
assert(not context.writes.color and context.reads.alias, "native party alias did not preserve friendly green")
context.partyAlias = nil
refresh(false)
assert(context.writes.color == 1 and bar.color[1] == 1, "party retirement retained friendly green")
context:ResetCounts()
bar.color[4] = 0.5
refresh(false)
assert(context.writes.color == 1, "native alpha reset was not repaired")
env.TargetFrame:Hide()
context:ResetCounts()
refresh(true)
assert(not next(context.reads) and not next(context.writes), "hidden target refresh performed presentation work")
bar:SetStatusBarColor(0, 1, 0)
assert(not next(context.reads) and not next(context.writes), "hidden native setter call performed color work")
print("PASS target refresh preserves friendly/party ownership and native resets while skipping unchanged colors")
