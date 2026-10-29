-- CI only: production navigation with explicit native map/projection boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "projection cache fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local phase, browsing, mapName, continent, mapZone = "playing", false, "CurrentZone", 1, 1
local playerX, playerY, offset, missing, fail = 0.5, 0.5, 0.5, false, false
local reads, lastMap = 0, nil
env.AZS_ZONE, env.AZS_ZONE_UPDATED = { zone = "CurrentZone", map = 1 }, 2
env.AZS_RUN, env.AZS_RUN_UPDATED = { px = 0, py = 0, pf = 0.25 }, 12
env.AZS_GetPhase = function() return phase end
env.GetRealZoneText = function() return "CurrentZone" end
env.GetMapInfo = function() return mapName, 1000, 500 end
env.GetCurrentMapContinent = function() return continent end
env.GetCurrentMapZone = function() return mapZone end
env.GetPlayerMapPosition = function() return playerX, playerY end
env.SetMapToCurrentZone = function() mapName = "CurrentZone" end
env.WorldMapFrame = { IsShown = function() return browsing end }
local function Project(map, x, y)
    reads, lastMap = reads + 1, map
    if fail then error("injected native projection failure") end
    if missing then return 0, 0 end
    return offset - y / 1000, offset - x / 500
end
env.GetWorldLocMapPosition = Project
context:Load("modules/map/navigation.lua", "Navigation")
local nav = env.DFRL.navigation
local point = { x = 100, y = -100, mx = 0.6, my = 0.3 }
nav.SetPoints("AZS_CHESTS", { point })
nav.Position()
nav.BeginSample()
local east, north, distance, metric = nav.GuideDelta(point)
assert(math.abs(east - 100) < 0.000001 and math.abs(north - 100) < 0.000001)
assert(metric and distance > 141 and distance < 142)
assert(reads == 3, "accepted base projection was repeated during native metric calibration")
local copy = { x = point.x, y = point.y, mx = point.mx, my = point.my }
reads = 0
for _ = 1, 20 do
    assert(nav.GuideDelta(copy) == east, "equal accepted coordinates changed projected placement")
end
assert(reads == 0, "same-pass HUD/pin copies repeated their successful native projection")
nav.EndSample()

reads, playerX = 0, 0.55
nav.BeginSample()
assert(math.abs(nav.GuideDelta(point) - 50) < 0.000001, "next-frame player movement was cached")
assert(reads == 1, "projection success escaped its synchronous callback")
nav.EndSample()
-- The engine can replace its projection catalog/direct-area while the visible
-- filename and Lua getter identity stay the same. A new pass must query again.
reads, offset = 0, 0.6
nav.BeginSample()
assert(math.abs(nav.GuideDelta(point) - 150) < 0.000001 and reads == 1, "invisible native projection change went stale")
nav.EndSample()
offset, playerX = 0.5, 0.5

nav.BeginSample()
nav.GuideDelta(point)
reads = 0
local original = env.GetWorldLocMapPosition
env.GetWorldLocMapPosition = function(map, x, y) return original(map, x, y) end
nav.GuideDelta(copy)
assert(reads == 1, "same-pass getter replacement reused an old native result")
reads = 0
env.AZS_ZONE.map = 2
nav.GuideDelta(point)
assert(reads == 1 and lastMap == 2, "changed destination map reused an old native result")
nav.EndSample()
env.AZS_ZONE.map = 1

-- Missing/failed results are never memoized, even inside a callback. Official
-- fallback coordinates remain available while native projection recovers.
for _, kind in ipairs({ "missing", "failure" }) do
    nav.BeginSample()
    missing, fail = kind == "missing", kind == "failure"
    reads = 0
    assert(nav.GuideDelta(point) ~= nil and reads == 1, "missing projection discarded official coordinates")
    missing, fail = false, false
    nav.GuideDelta(point)
    assert(reads == 2, "same-pass native readiness/failure retry was suppressed")
    nav.GuideDelta(copy)
    assert(reads == 2, "recovered projection was not shared")
    nav.EndSample()
end

-- Keys are exact Lua numbers; close coordinates that stringify alike must
-- remain separate. In-place changes outside the accepted index stay uncached.
local nearby = { x = 100 + 0.000000000001, y = -100, mx = 0.6, my = 0.3 }
assert(nearby.x ~= point.x and tostring(nearby.x) == tostring(point.x), "fixture needs distinct same-caption numbers")
nav.SetPoints("AZS_CHESTS", { point, nearby })
nav.BeginSample()
reads = 0
nav.GuideDelta(point)
nav.GuideDelta(nearby)
assert(reads == 2, "distinct numeric destination coordinates collided")
nav.GuideDelta({ x = nearby.x, y = nearby.y })
assert(reads == 2, "exact numeric aliases did not share projection")
nearby.y = -90
nav.GuideDelta(nearby)
assert(reads == 3, "in-place coordinate change retained an old result")
nav.EndSample()

-- Retired point data must not build an unbounded cache of arbitrary callers.
nav.SetPoints("AZS_CHESTS", nil)
nav.BeginSample()
reads = 0
nav.GuideDelta(point)
nav.GuideDelta(point)
assert(reads == 2, "retired destination retained a projection record")
nav.EndSample()
nav.SetPoints("AZS_CHESTS", { point })
nav.BeginSample()
nav.GuideDelta(point)
nav.Reset()
reads = 0
nav.GuideDelta(point)
assert(reads >= 1, "calibration/world reset retained a successful projection")
nav.EndSample()

browsing, mapName = true, "AnotherZone"
nav.BeginSample()
reads = 0
local worldEast, worldNorth, _, worldMetric, stamp = nav.GuideDelta(point)
assert(worldEast == 100 and worldNorth == 100 and worldMetric and stamp == 12)
assert(reads == 0, "browsing a foreign map projected onto the wrong sheet")
nav.EndSample()
browsing, mapName, continent, mapZone = false, "CurrentZone", -1, 0
nav.BeginSample()
nav.GuideDelta(point)
nav.EndSample()
reads, offset = 0, 0.55
nav.BeginSample()
nav.GuideDelta(point)
assert(reads == 1, "same-label direct-area change was cached across callbacks")
nav.EndSample()

phase = "dead"
nav.Reset()
nav.BeginSample()
reads = 0
assert(nav.GuideDelta(point) == nil and reads == 0, "retired phase reused projection")
nav.EndSample()
phase, mapName, offset = "playing", "CurrentZone", 0.5
local ok, message = pcall(nav.WithSample, function()
    nav.GuideDelta(point)
    error("injected callback failure")
end)
assert(not ok and string.find(message, "injected callback failure", 1, true))
reads = 0
nav.GuideDelta(point)
nav.GuideDelta(point)
assert(reads == 2, "failed callback left ordinary callers memoized")

-- Remote native map UVs require the same confirmed current sheet as the
-- player, even with a world projector present. They never gain world XY.
phase, browsing, mapName, continent, mapZone = "playing", false, "CurrentZone", 1, 1
playerX, playerY = 0.5, 0.5
local partyX, partyY, partyReads = 0.6, 0.4, 0
env.GetPlayerMapPosition = function(unit)
    if unit == "player" then return playerX, playerY end
    assert(unit == "party1", "unexpected native party token")
    partyReads = partyReads + 1
    return partyX, partyY
end
nav.Reset()
nav.SetPoints("AZS_CHESTS", { point })
local remote
nav.WithSample(function()
    local x, y, selection = nav.UnitMapPosition("party1")
    assert(x == partyX and y == partyY and type(selection) == "string")
    remote = { mx = x, my = y, mapSelection = selection }
    local e, n, _, calibrated = nav.GuideDelta(remote)
    assert(calibrated and math.abs(e - 100) < 0.000001 and math.abs(n - 50) < 0.000001)
end)
for _, invalid in ipairs({ { 0, 0 }, { -0.1, 0.5 }, { 1.1, 0.5 }, { 0.5, math.huge }, { 0 / 0, 0.5 } }) do
    partyX, partyY = unpack(invalid)
    assert(nav.UnitMapPosition("party1") == nil, "invalid native party UV became a destination")
end
partyX, partyY = 0.6, 0.4
browsing, mapName, partyReads = true, "AnotherZone", 0
assert(nav.UnitMapPosition("party1") == nil and partyReads == 0, "foreign map lent its UVs to a party member")
assert(nav.GuideDelta(remote) == nil, "retired map-only destination borrowed world fallback coordinates")
browsing, mapName, continent, mapZone = false, "CurrentZone", -1, 0
assert(nav.UnitMapPosition("party1") ~= nil)
assert(nav.GuideDelta(remote) == nil, "same-label different-area selection retained a remote UV")
playerX, playerY, partyReads = 0, 0, 0
assert(nav.UnitMapPosition("party1") == nil and partyReads == 0, "missing player position used remote UVs")
playerX, playerY = 0.5, 0.5
env.GetPlayerMapPosition = function() error("native map getter unavailable") end
assert(nav.UnitMapPosition("party1") == nil, "a failed map read became a party destination")
assert(remote.x == nil and remote.y == nil, "map-only party data invented world coordinates")
print(
    "PASS exact accepted destination projections share only successful same-pass reads with fresh movement and lifecycle retry"
)
