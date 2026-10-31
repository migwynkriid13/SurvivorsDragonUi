-- CI only: production navigation/controller against explicit live native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "live position fixtures require CI Lua 5.1")
local c = H.New()
local env = c.env
local phase, advertised, capFailure, positionFailure = "playing", false, nil, nil
local capReads, positionReads, mapReads = 0, 0, 0
local function Position()
    return {
        apiVersion = 1,
        mapId = 0,
        spaceId = "instance:1",
        sampleId = "frame:1",
        runId = "run:1",
        x = 0,
        y = 0,
        z = 0,
        facing = 0,
    }
end
local position = Position()
env.AZS_GetPhase = function() return phase end
env.AZS_RUN, env.AZS_RUN_UPDATED = { px = 100, py = 100, pf = 1 }, 10
env.AZS_ZONE, env.AZS_ZONE_UPDATED = { zone = "CurrentZone", map = 0 }, 1
env.AZS_GetMeterCapabilities = function()
    capReads = capReads + 1
    if type(capFailure) == "table" then return nil, capFailure end
    if capFailure then error(capFailure) end
    return { apiVersion = 1, features = { liveInstancePosition = advertised } }, nil
end
env.AZS_GetPlayerPosition = function()
    positionReads = positionReads + 1
    if type(positionFailure) == "table" then return nil, positionFailure end
    if positionFailure == "throw" then error("native position failed") end
    if positionFailure then return nil, { code = positionFailure } end
    return position, nil
end
local function Point(x, y)
    return { x = x or 20, y = y or -30, mx = 0.53, my = 0.46, runId = "run:1", mapId = 0, spaceId = "instance:1" }
end
local point = Point()
c:Load("modules/map/navigation.lua", "Navigation")
local nav = env.DFRL.navigation
local function Near(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001, message)
end

-- Explicitly unadvertised clients keep the original packet fallback.
Near(nav.Delta(point), 130, "an unadvertised API changed legacy navigation")
assert(positionReads == 0, "unadvertised live position getter was called")
advertised = true
capReads, positionReads = 0, 0
nav.WithSample(function()
    for _ = 1, 10 do
        local east, north, distance, metric, stamp = nav.GuideDelta(point)
        assert(east == 30 and north == 20 and metric and distance > 36 and distance < 37 and stamp == nil)
        assert(nav.Delta(point) == 30 and nav.Heading() == 0 and nav.IsCurrentDestination(point))
    end
    position.x, position.y = 8, 4
    assert(select(2, nav.GuideDelta(point)) == 20, "a shared callback retained a mutable native position table")
end)
assert(capReads == 1 and positionReads == 1, "guides and pins repeated live native reads in one callback")
nav.WithSample(function()
    local east, north, _, metric, stamp = nav.GuideDelta(point)
    assert(
        east == 34 and north == 12 and metric and stamp == nil,
        "next-frame instance movement used an old packet/sample"
    )
end)
assert(positionReads == 2, "next callback did not read the current native frame")
position = Position()
assert(nav.Delta(Point(0, 0)) == 0 and nav.Heading() == 0, "valid zero coordinates/map/facing were rejected")

for _, field in ipairs({ "runId", "mapId", "spaceId" }) do
    local wrong = Point()
    wrong[field] = field == "mapId" and 1 or "another"
    assert(
        nav.GuideDelta(wrong) == nil and not nav.IsCurrentDestination(wrong),
        field .. " mismatch borrowed legacy coordinates"
    )
    wrong[field] = nil
    assert(nav.Delta(wrong) == nil, "untagged live destination used old packet coordinates")
end
for _, failure in ipairs({ "NOT_READY", "NO_WORLD", "NO_PLAYER", "INTERNAL_ERROR", "throw" }) do
    positionFailure = failure
    positionReads = 0
    nav.WithSample(function()
        assert(nav.GuideDelta(point) == nil and nav.Delta(point) == nil and nav.Heading() == nil)
        assert(not nav.IsCurrentDestination(point), "native readiness failure kept a visible destination")
    end)
    assert(positionReads == 1, "failed native sample was repeatedly polled in one callback")
    positionFailure = nil
    assert(nav.GuideDelta(point) == 30, "native availability did not retry after the failed callback")
end
for _, invalid in ipairs({
    { "apiVersion", 2 },
    { "mapId", -1 },
    { "mapId", 0.5 },
    { "mapId", "0" },
    { "spaceId", "" },
    { "sampleId", "" },
    { "runId", 1 },
    { "x", math.huge },
    { "y", 0 / 0 },
    { "z", "0" },
    { "facing", -0.1 },
    { "facing", math.pi * 2 },
}) do
    position = Position()
    position[invalid[1]] = invalid[2]
    assert(nav.GuideDelta(point) == nil and nav.Heading() == nil, "malformed native position admitted: " .. invalid[1])
end
position = Position()
position.runId = nil
assert(nav.Delta(point) == nil, "outside-run position was joined to a retained run destination")
position = Position()
advertised = false
nav.Reset()
assert(nav.Delta(point) == nil and nav.Heading() == nil, "advertised API disappearance revived stale legacy packets")
advertised, capFailure = true, "capabilities unavailable"
assert(nav.Delta(point) == nil, "unreadable capabilities revived legacy navigation")
capFailure = nil
assert(nav.Delta(point) == 30, "capabilities recovery failed to restore live navigation")
local nativeGetter, capabilityGetter = env.AZS_GetPlayerPosition, env.AZS_GetMeterCapabilities
env.AZS_GetPlayerPosition = nil
assert(nav.Delta(point) == nil and nav.Heading() == nil, "missing advertised position getter used legacy data")
env.AZS_GetPlayerPosition, env.AZS_GetMeterCapabilities = nativeGetter, nil
assert(nav.Delta(point) == nil, "missing previously advertised capabilities revived legacy data")
env.AZS_GetMeterCapabilities = capabilityGetter
local callbackOK = pcall(nav.WithSample, function()
    nav.GuideDelta(point)
    error("injected callback failure")
end)
assert(not callbackOK, "fixture did not reach its callback failure")
position.y = 3
assert(nav.GuideDelta(point) == 33, "failed callback left a live native sample cached outside its pass")
position = Position()

-- Only typed retryable failures retain an error deadline. Successful positions
-- remain live every callback; a deadline never lends an older position.
local retryError = { code = "NOT_READY", message = "Position is pending.", retryable = true, retryAfterSeconds = 0.5 }
positionFailure = retryError
nav.WithSample(function() assert(nav.GuideDelta(point) == nil) end)
positionFailure, positionReads = nil, 0
c.now = c.now + 0.25
nav.WithSample(
    function() assert(nav.GuideDelta(point) == nil and nav.Heading() == nil and not nav.IsCurrentDestination(point)) end
)
assert(positionReads == 0, "typed position failure retried before retryAfterSeconds")
c.now = c.now + 0.25
nav.WithSample(function() assert(nav.GuideDelta(point) == 30) end)
assert(positionReads == 1, "position retry did not resume at its native error deadline")
capFailure = retryError
nav.WithSample(function() assert(nav.Delta(point) == nil) end)
capFailure, capReads, positionReads = nil, 0, 0
c.now = c.now + 0.25
nav.WithSample(function() assert(nav.GuideDelta(point) == nil and nav.Heading() == nil) end)
assert(capReads == 0 and positionReads == 0, "capability backoff polled native state or reused a stale position")
c.now = c.now + 0.25
nav.WithSample(function() assert(nav.GuideDelta(point) == 30) end)
assert(capReads == 1 and positionReads == 1, "capability deadline did not resume fresh native positions")
positionFailure = retryError
nav.WithSample(function() assert(nav.Delta(point) == nil) end)
positionFailure = nil
c.now = c.now - 1
nav.WithSample(function() assert(nav.GuideDelta(point) == 30) end)
positionFailure = retryError
nav.WithSample(function() assert(nav.Delta(point) == nil) end)
positionFailure = nil
nav.Reset()
nav.WithSample(function() assert(nav.GuideDelta(point) == 30) end)

-- Map-only party coordinates keep their native current-sheet path even while
-- the unrelated live world-position getter is temporarily unavailable.
env.GetRealZoneText = function() return "CurrentZone" end
env.GetMapInfo = function() return "CurrentZone", 1000, 500 end
env.GetCurrentMapContinent = function() return 1 end
env.GetCurrentMapZone = function() return 1 end
env.SetMapToCurrentZone = function() end
env.GetPlayerMapPosition = function(unit)
    mapReads = mapReads + 1
    if unit == "player" then return 0.5, 0.5 end
    return 0.6, 0.4
end
env.GetWorldLocMapPosition = function(_, x, y) return 0.5 - y / 1000, 0.5 - x / 500 end
env.WorldMapFrame = { IsShown = function() return false end }
nav.SetPoints("AZS_CHESTS", { point })
positionFailure = "NOT_READY"
nav.WithSample(function()
    local mx, my, selection = nav.UnitMapPosition("party1")
    local remote = { mx = mx, my = my, mapSelection = selection }
    local east, north, _, metric = nav.GuideDelta(remote)
    Near(east, 100, "live API readiness broke party map offsets")
    Near(north, 50, "party map geometry changed")
    assert(metric and nav.IsCurrentDestination(remote), "a map-only party destination acquired world tags")
end)
positionFailure = nil
phase = "dead"
positionReads = 0
nav.WithSample(function() assert(nav.Delta(point) == nil and nav.GuideDelta(point) == nil) end)
assert(positionReads == 0, "inactive navigation kept reading live world positions")
phase = "playing"

-- Exercise accepted destination copies and guide/pin visibility through the
-- full production waypoint controller, in both existing Performance states.
env.Minimap = env.CreateFrame("Frame", nil, env.UIParent)
env.Minimap:SetWidth(300)
env.Minimap:SetHeight(300)
-- The shared size reader measures native edges before authored dimensions.
-- These are explicit local native bounds, independent of world/map geometry.
env.Minimap.GetLeft = function() return 0 end
env.Minimap.GetRight = function() return 300 end
env.Minimap.GetBottom = function() return 0 end
env.Minimap.GetTop = function() return 300 end
env.Minimap.GetZoom = function() return 0 end
env.Minimap.SetPlayerModel = function() end
env.GetCVar = function(key)
    if key == "minimapZoom" then return "1" end
    if key == "minimapInsideZoom" then return "0" end
    error("unexpected CVar read: " .. tostring(key))
end
env.DFRL.actionBarDefaults =
    { bottom = 20, height = 30, topInset = 0, jewelryTopInset = 40, width = 500, sideInset = 0 }
env.DFRL.xpBarDefaults = { top = 10, height = 8, borderHeight = 0 }
env.DFRL.locale.code = "en"
env.DFRL.locale.Bind = function() end
env.DFRL.locale.Native = function(_, values) return tostring(values.n) .. " yards" end
env.DFRL.layout.IsHidden = function() return false end
env.DFRL.layout.Register = function(_, _, anchor) anchor() end
local registeredPins = {}
env.T.RegisterTooltipIcon = function(pin, icon, side)
    assert(pin:GetParent() == env.Minimap and icon == nil and side == "cursor", "unexpected guardian tooltip boundary")
    registeredPins[pin] = true
end
-- Observe the actual copied lists at the existing public navigation boundary.
local accepted, setPoints = {}, nav.SetPoints
function nav.SetPoints(key, list)
    accepted[key] = list
    return setPoints(key, list)
end
local createObject = c.Object
function c:Object(...)
    local object = createObject(self, ...)
    local setPoint = object.SetPoint
    function object:SetPoint(...)
        setPoint(self, ...)
        self.point = { ... }
    end
    return object
end
point.id = 1
local lair = Point(40, -50)
lair.index, lair.id, lair.state = 1, 3, "asleep"
env.AZS_CHESTS, env.AZS_CHESTS_UPDATED = { point }, 1
env.AZS_LAIRS, env.AZS_LAIRS_UPDATED = { lair }, 1
c:Load("core/hud.lua")
c:Load("core/widgets.lua")
c:Load("core/display.lua", "Display")
c:Load("modules/map/waypoints.lua", "Waypoints")
local display, reader = env.DFRL.display, env.DFRL_CacheWaypointReader
display.BeginEdit()
display.Set("partyGuidance", false)
local function Tick() c:Call(reader, "OnUpdate", 0.1) end
local function Pin(key)
    for _, object in ipairs(c.objects) do
        if object.parent == env.Minimap and object.entryKey == key and object:IsShown() then return object end
    end
end
local function Visible()
    return env.DFRL_CacheWaypoint:IsShown() and env.DFRL_GuardianWaypoint:IsShown() and Pin("1") and Pin("1:3")
end
local function AcceptedTags(source, original)
    local copy = accepted[source] and accepted[source][1]
    assert(copy and copy ~= original, "destination publication was missing or retained the native table")
    assert(
        copy.runId == original.runId and copy.mapId == original.mapId and copy.spaceId == original.spaceId,
        "accepted native coordinate tags were lost in destination copies"
    )
end
local function AssertVisible()
    assert(env.DFRL_CacheWaypoint:IsShown(), "accepted cache destination did not show its guide")
    assert(env.DFRL_GuardianWaypoint:IsShown(), "accepted guardian destination did not show its guide")
    assert(Pin("1"), "accepted cache destination did not project onto the native minimap bounds")
    local pin = assert(Pin("1:3"), "accepted guardian destination did not project onto the native minimap bounds")
    assert(registeredPins[pin] and pin.art and pin.check, "guardian pin skipped its shared artwork/tooltip owners")
end
for _, performance in ipairs({ false, true }) do
    display.Set("performanceMode", performance)
    position = Position()
    Tick()
    AcceptedTags("AZS_CHESTS", point)
    AcceptedTags("AZS_LAIRS", lair)
    AssertVisible()
    position.x, position.y = 8, 4
    capReads, positionReads, mapReads = 0, 0, 0
    Tick()
    Near(Pin("1").point[4], 34, "cache pin did not use live instance movement immediately")
    Near(Pin("1:3").point[5], 32, "guardian pin used sampled or cosmetic movement")
    assert(
        capReads == 1 and positionReads == 1 and mapReads == 0,
        "full guide/pin pass repeated native reads or used map fallback"
    )
    positionFailure = "NOT_READY"
    Tick()
    assert(
        not env.DFRL_CacheWaypoint:IsShown()
            and not env.DFRL_GuardianWaypoint:IsShown()
            and not Pin("1")
            and not Pin("1:3")
    )
    positionFailure = nil
    Tick()
    assert(Visible(), "transient native unavailability retired accepted destinations")
    position.spaceId = "instance:2"
    Tick()
    assert(not Visible() and not Pin("1") and not Pin("1:3"), "old-space destinations remained projected")
    position.spaceId = "instance:1"
    Tick()
    assert(Visible(), "matching coordinate-space recovery failed")
end
display.Set("keepDefeatedGuardianIcons", true)
local empty = Point(40, -50)
empty.index, empty.id, empty.state = 1, 0, "empty"
env.AZS_LAIRS, env.AZS_LAIRS_UPDATED = { empty }, 2
c:Event(reader, "CHAT_MSG_ADDON", "AZSLAIRS")
Tick()
assert(Pin("1:0"), "accepted empty-lair copies lost native coordinate-space tags")
env.AZS_LAIRS, env.AZS_LAIRS_UPDATED = { lair }, 3
c:Event(reader, "CHAT_MSG_ADDON", "AZSLAIRS")
Tick()
assert(Visible(), "a fresh living lair did not replace its defeated native pin")
env.UIParent:Hide()
Tick()
positionReads = 0
c:ResetCounts()
Tick()
assert(positionReads == 0, "hidden guides/minimap kept live-position work")
c:NoPresentationWrites()
env.UIParent:Show()
Tick()
assert(Visible(), "shown views did not resume fresh live positions")
c:Event(reader, "PLAYER_LEAVING_WORLD")
assert(
    not Pin("1") and not Pin("1:3") and not env.DFRL_CacheWaypoint:IsShown(),
    "world cleanup retained live pins/guidance"
)
print(
    "PASS live native instance positions use exact coordinate tags, per-pass reads, immediate presentation and owned cleanup"
)
