-- CI only: production minimap player arrow over legacy native heading packets.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "minimap arrow fixtures require CI Lua 5.1")
local c = H.New()
local env = c.env
local create = c.Object
function c:Object(...)
    local object = create(self, ...)
    function object:GetFrameStrata() return self.strata or "MEDIUM" end
    return object
end
env.AZS_GetPhase = function() return "playing" end
env.AZS_RUN, env.AZS_RUN_UPDATED = { px = 100, py = 100, pf = 0 }, 10
env.AZS_ZONE, env.AZS_ZONE_UPDATED = { zone = "CurrentZone", map = 0 }, 1
env.Minimap = env.CreateFrame("Frame", nil, env.UIParent)
env.Minimap:SetWidth(140.8)
env.Minimap:SetHeight(140.8)
env.Minimap.GetLeft = function() return 0 end
env.Minimap.GetRight = function() return 140.8 end
env.Minimap.GetBottom = function() return 0 end
env.Minimap.GetTop = function() return 140.8 end
c:Load("modules/map/navigation.lua", "Navigation")
local nav = env.DFRL.navigation

local function Arrow()
    for _, object in ipairs(c.objects) do
        if object.texture == "Interface\\Minimap\\MinimapArrow" then return object end
    end
end

nav.UpdateMinimapPlayer(true)
local arrow = Arrow()
assert(arrow and arrow.rotationStep == 0, "the minimap arrow did not take its first rotation step")
c:ResetCounts()
for step = 1, 60 do
    env.AZS_RUN.pf, env.AZS_RUN_UPDATED = step * 0.01, 10 + step
    nav.UpdateMinimapPlayer(true)
end
local writes = c.writes.SetTexCoord or 0
assert(writes >= 1 and writes <= 14, "continuous turning wrote more arrow UV sets than its rotation steps")
assert((c.writes.SetPoint or 0) >= 60, "the arrow offset stopped following native facing")
c:ResetCounts()
nav.UpdateMinimapPlayer(true)
assert((c.writes.SetTexCoord or 0) == 0, "an unchanged heading rewrote the arrow UVs")
print("PASS Minimap player arrow follows native facing with bounded rotation steps")
