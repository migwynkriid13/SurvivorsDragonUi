-- CI only: the full waypoint controller over explicit native party/lair boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "party waypoint fixtures require CI Lua 5.1")
local c = H.New()
local env = c.env
local phase, unitReads, positionReads = "playing", 0, 0
env.AZS_GetPhase = function() return phase end
local minimapVisible = true
env.Minimap = env.CreateFrame("Frame", nil, env.UIParent)
env.Minimap.IsVisible = function() return minimapVisible end
env.Minimap.GetZoom = function() return 0 end
env.GetCVar = function(key)
    if key == "minimapZoom" then return "0" end
    if key == "minimapInsideZoom" then return "1" end
    error("unexpected CVar read: " .. tostring(key))
end
env.AZS_CHESTS = { { id = 1, x = 10, y = 20, mx = 0.51, my = 0.5 } }
env.AZS_CHESTS_UPDATED = 1
local members, registered, bound, navigationPoints, anchors = {}, {}, {}, {}, {}
local hiddenWaypoints = {}
env.DFRL.layout.IsHidden = function(key) return hiddenWaypoints[key] == true end
local function Member(name, x, y) return { name = name, mx = x, my = y, exists = 1, connected = 1, dead = 1, ghost = 0 } end
local function Field(unit, key)
    unitReads = unitReads + 1
    return members[unit] and members[unit][key]
end
env.UnitExists = function(unit) return Field(unit, "exists") end
env.UnitIsConnected = function(unit) return Field(unit, "connected") end
env.UnitIsDead = function(unit) return Field(unit, "dead") end
env.UnitIsGhost = function(unit) return Field(unit, "ghost") end
env.UnitName = function(unit) return Field(unit, "name") end
env.DFRL.actionBarDefaults =
    { bottom = 20, height = 30, topInset = 0, jewelryTopInset = 40, width = 500, sideInset = 0 }
env.DFRL.xpBarDefaults = { top = 10, height = 8, borderHeight = 0 }
env.DFRL.locale.Bind = function(label) bound[label] = true end
env.DFRL.locale.code = "en"
env.DFRL.locale.Native = function(_, fields) return tostring(fields.n) .. " yards" end
env.DFRL.layout.Register = function(key, frame, anchor)
    registered[key] = frame
    anchors[key] = anchor
    anchor()
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
local swapDuringRead, missingPosition, missingDelta
local playerX, playerY, lastGuidePoint = 0.5, 0.5, nil
local function Delta(point)
    c.reads.delta = (c.reads.delta or 0) + 1
    if missingDelta then return end
    local east, north = (point.mx - playerX) * 1000, (playerY - point.my) * 1000
    return east, north, math.sqrt(east * east + north * north), true
end
env.DFRL.navigation = {
    Phase = function() return phase end,
    IsRunPhase = function(value) return value == "playing" or value == "paused" end,
    UnitMapPosition = function(unit)
        positionReads = positionReads + 1
        local member = members[unit]
        if swapDuringRead then
            members[unit] = Member("Replacement", 0.9, 0.9)
            swapDuringRead = false
        end
        if member and not missingPosition then return member.mx, member.my, "current:1:1" end
    end,
    GuideDelta = function(point)
        lastGuidePoint = point
        return Delta(point)
    end,
    Delta = Delta,
    Heading = function() return 0 end,
    SetPoints = function(key, points) navigationPoints[key] = points end,
    Reset = function() end,
    WithSample = function(callback) callback() end,
    UpdateMinimapPlayer = function() end,
    StyleMinimap = function() end,
    MinimapLevel = function() return 12 end,
    MinimapSize = function() return 100, 100 end,
}
c:Load("core/hud.lua")
c:Load("core/display.lua", "Display")
c:Load("modules/ui/guardians.lua", "GuardianRoster")
c:Load("modules/map/waypoints.lua", "Waypoints")
local display = env.DFRL.display
local hud, reader = env.DFRL_PartyWaypoint, env.DFRL_CacheWaypointReader
assert(registered.partyWaypoint == hud, "fallen ally bypassed shared Layout registration")
local jewelryTop = env.DFRL.actionBarDefaults.bottom
    + env.DFRL.actionBarDefaults.height
    + env.DFRL.actionBarDefaults.jewelryTopInset
assert(
    hud.point[4] == 0 and hud.point[5] - hud:GetHeight() / 2 == jewelryTop + 8,
    "fallen ally default overlaps jewelry"
)
assert(
    registered.cacheWaypoint.point[5] == 28 and registered.guardianWaypoint.point[5] == 28,
    "moving the ally default changed cache/guardian anchors"
)
local title, distance, marker, pointer
for _, object in ipairs(c.objects) do
    if object.parent == hud then
        if object.kind == "FontString" then
            if object.font[2] == 13 then
                title = object
            else
                distance = object
            end
        elseif object.kind == "Texture" then
            if string.find(object.texture, "FallenAlly.blp", 1, true) then
                marker = object
            else
                pointer = object
            end
        end
    end
end
assert(marker and pointer and title and distance, "selected glyph or shared guide content is missing")
assert(not bound[title], "native member names were bound to caption translation")
local function Tick(elapsed) c:Call(reader, "OnUpdate", elapsed or 0.1) end
hud:SetPoint("CENTER", env.UIParent, "CENTER", 133, -77)
Tick()
hud:Hide()
hud:Show()
assert(
    hud.point[3] == "CENTER" and hud.point[4] == 133 and hud.point[5] == -77,
    "guide refresh/show overwrote custom placement"
)
hud:Hide()
anchors.partyWaypoint()
local function PinCount(art)
    local count = 0
    local texture = env.DFRL:GetInfoOrCons("tex") .. "waypoint\\" .. art
    for _, object in ipairs(c.objects) do
        if
            object.kind == "Texture"
            and object.texture == texture
            and object.parent.parent == env.Minimap
            and object.parent:IsShown()
        then
            count = count + 1
        end
    end
    return count
end
assert(display.Get("partyGuidance") and not display.Get("mirrorPartyWaypoint"))
assert(display.Copy({ partyGuidance = 0, mirrorPartyWaypoint = 1 }).partyGuidance)
assert(not display.Copy({ mirrorPartyWaypoint = 1 }).mirrorPartyWaypoint)
Tick()
assert(not hud:IsShown(), "an empty party created a destination")
assert(PinCount("Chest.blp") == 1, "the full visible-minimap controller lost cache placement")
members.party1, members.party2 = Member("Far ally", 0.8, 0.8), Member("Near ally", 0.55, 0.5)
Tick()
assert(hud:IsShown() and title:GetText() == "Near ally" and distance:GetText() == "50 yards")
assert(PinCount("FallenAlly.blp") == 2, "the full controller did not place both fallen-ally pins")
for _, hidden in ipairs({ false, 0 }) do
    minimapVisible = hidden
    Tick()
    assert(PinCount("Chest.blp") == 0 and PinCount("FallenAlly.blp") == 0, "hidden native minimap retained pins")
    assert(hud:IsShown(), "minimap visibility hid the independent guidance HUD")
    minimapVisible = 1
    Tick()
    assert(
        PinCount("Chest.blp") == 1 and PinCount("FallenAlly.blp") == 2,
        "numeric native visibility did not restore pins"
    )
end
minimapVisible = nil
Tick()
assert(PinCount("FallenAlly.blp") == 0, "nil native visibility retained pins")
minimapVisible = true
Tick()
assert(PinCount("FallenAlly.blp") == 2 and env.Shown == nil, "visible minimap relied on an injected global helper")
members.party1.mx, members.party1.my = 0.501, 0.5
Tick()
assert(title:GetText() == "Near ally", "distance changes replaced a still-valid selection")
members.party2.dead = 0
Tick()
assert(title:GetText() == "Far ally", "revival did not choose the remaining fallen ally")
members.party1.connected = 0
Tick()
assert(not hud:IsShown() and not pointer:IsShown(), "disconnection left stale guidance")
members.party1.connected, members.party1.ghost = true, true
Tick()
assert(not hud:IsShown(), "a moving ghost was used as its corpse position")
members.party1.ghost, members.party1.dead = false, true
missingPosition = true
Tick()
assert(not hud:IsShown(), "missing live coordinates reused a last-known location")
missingPosition = false
swapDuringRead = true
Tick()
assert(not hud:IsShown(), "a roster-slot replacement inherited another member's coordinates")
Tick()
assert(title:GetText() == "Replacement" and hud:IsShown())
members.party1.name = "Cache"
Tick()
assert(title:GetText() == "Cache", "a native member name was treated as a localized caption")

display.BeginEdit()
display.Set("partyGuidance", false)
unitReads, positionReads = 0, 0
for _ = 1, 20 do
    Tick()
end
assert(not hud:IsShown() and unitReads == 0 and positionReads == 0, "disabled guidance still sampled the party")
assert(not env.SurvivorsDragonUiDisplay, "display preview saved before Confirm")
display.FinishEdit(false)
assert(not hud:IsShown(), "Cancel replayed stale party coordinates synchronously")
Tick()
assert(hud:IsShown(), "Cancel did not restore a fresh native destination")
display.BeginEdit()
display.Set("mirrorPartyWaypoint", true)
display.Set("performanceMode", true)
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.mirrorPartyWaypoint, "mirror choice was not confirmed")
Tick()
local allocations, writes = #c.objects, c.writes.SetText
for _ = 1, 20 do
    Tick()
end
assert(
    #c.objects == allocations and c.writes.SetText == writes,
    "stationary guidance allocated or rewrote unchanged labels"
)
assert(hud:IsShown() and marker:IsShown(), "Performance Mode removed native guidance")
display.BeginEdit()
display.Load({ partyGuidance = false, mirrorPartyWaypoint = false })
Tick()
assert(not hud:IsShown(), "profile preview did not hide party guidance")
display.FinishEdit(false)
Tick()
assert(hud:IsShown() and display.Get("mirrorPartyWaypoint"), "profile Cancel lost confirmed choices")

phase = "ready"
Tick()
assert(not hud:IsShown(), "inactive phase retained a fallen ally")
phase = "playing"
Tick()
c:Event(reader, "PLAYER_LEAVING_WORLD")
assert(not hud:IsShown(), "world cleanup retained guidance")
members = {}
c:Event(reader, "PLAYER_ENTERING_WORLD")
Tick()
assert(not hud:IsShown(), "world entry replayed a retired roster")
members.party1 = Member("Returned ally", 0.6, 0.5)
Tick()
env.UnitIsDead = function() error("native API unavailable") end
Tick()
assert(not hud:IsShown(), "a failed native state getter retained a destination")
env.UnitIsDead = nil
Tick()
assert(not hud:IsShown(), "an absent native getter invented a dead member")
display.Reset()
assert(display.Get("partyGuidance") and not display.Get("mirrorPartyWaypoint"), "full reset lost defaults")
print(
    "PASS fallen-ally guidance uses fresh native death/position, shared selection/Layout, transactional settings and bounded idle work"
)

-- Exercise the same full controller's guardian fallback independently of the
-- optional defeated minimap icons and their separate timer presentation.
minimapVisible = false
local guardianHud = registered.guardianWaypoint
local guardianDistance
for _, object in ipairs(c.objects) do
    if object.parent == guardianHud and object.kind == "FontString" and object.font[2] == 15 then
        guardianDistance = object
    end
end
assert(guardianDistance, "guardian guide lost its existing distance label")
local lairStamp = 0
local function Lair(index, left, mx, state, id)
    return { index = index, id = id or 0, state = state or "empty", left = left, x = index, y = 0, mx = mx, my = 0.5 }
end
local function PublishLairs(lairs)
    lairStamp = lairStamp + 1
    env.AZS_LAIRS, env.AZS_LAIRS_UPDATED = lairs, lairStamp
    c:Event(reader, "CHAT_MSG_ADDON", "AZSLAIRS")
    Tick()
end
local near, soon = Lair(1, 40, 0.51), Lair(2, 5, 0.8)
assert(not display.Get("guardianRespawnGuidance"), "respawn guidance must default off")
assert(
    not display.Copy({ guardianRespawnGuidance = "true" }).guardianRespawnGuidance,
    "invalid respawn guidance did not use its default"
)
PublishLairs({ near, soon })
assert(not guardianHud:IsShown(), "default-off respawn guidance changed living-only behavior")
display.BeginEdit()
display.Set("guardianRespawnGuidance", true)
assert(guardianHud:IsShown() and guardianDistance:GetText() == "300 yards", "preview needed a new lair packet")
assert(not env.SurvivorsDragonUiDisplay, "respawn guidance preview saved early")
display.FinishEdit(false)
assert(not guardianHud:IsShown(), "Cancel retained respawn guidance")
display.BeginEdit()
display.Set("guardianRespawnGuidance", true)
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.guardianRespawnGuidance, "Confirm lost the respawn guidance choice")
display.BeginEdit()
display.Set("guardianRespawnGuidance", false)
assert(not guardianHud:IsShown(), "turning respawn guidance off retained its target")
display.Load({ guardianRespawnGuidance = true })
assert(guardianHud:IsShown(), "profile preview did not restore cached respawn guidance")
display.Load({ guardianRespawnGuidance = false })
assert(not guardianHud:IsShown(), "profile preview did not disable respawn guidance")
display.FinishEdit(false)
assert(guardianHud:IsShown(), "profile Cancel lost confirmed respawn guidance")
PublishLairs({ Lair(3, nil, 0.56, "asleep", 7), soon })
assert(guardianHud:IsShown() and guardianDistance:GetText() == "60 yards", "respawn displaced a living guardian")
PublishLairs({ near, soon, Lair(3, nil, 0.501) })
assert(guardianHud:IsShown() and guardianDistance:GetText() == "300 yards", "fallback chose distance over respawn time")
assert(
    #navigationPoints.AZS_LAIRS == 3 and navigationPoints.AZS_LAIRS[2].key == "2:0",
    "accepted empty-lair coordinate pairs were unavailable to native navigation calibration"
)
assert(env.DFRL.guardians.GetSnapshot().counts.living == 0, "guidance invented a living guardian")
minimapVisible = true
Tick()
assert(
    PinCount("GuardianFloating.blp") == 0
        and not display.Get("keepDefeatedGuardianIcons")
        and not display.Get("guardianMinimapTimers"),
    "respawn guidance enabled defeated minimap icons or timers"
)
near.left = 5
PublishLairs({ near, soon })
assert(guardianDistance:GetText() == "300 yards", "equal timers replaced the current lair")
near.left = 0
PublishLairs({ near, soon })
assert(guardianDistance:GetText() == "10 yards", "a newly earlier or due lair did not replace the old selection")
phase = "paused"
Tick()
assert(guardianHud:IsShown() and guardianDistance:GetText() == "10 yards", "pause discarded native respawn guidance")
phase = "playing"
display.BeginEdit()
for _, performance in ipairs({ false, true }) do
    display.Set("performanceMode", performance)
    assert(display.Get("performanceMode") == performance, "fixture did not preview the requested performance mode")
    Tick()
    local prepared = #c.objects
    c:ResetCounts()
    for _ = 1, 20 do
        Tick()
    end
    c:NoPresentationWrites()
    assert(#c.objects == prepared and guardianHud:IsShown(), "settled respawn guidance rebuilt its view")
end
display.BeginEdit()
display.Set("guardianGuidance", false)
PublishLairs({ soon })
assert(not guardianHud:IsShown(), "disabled guardian guidance retained its respawn HUD")
display.FinishEdit(false)
Tick()
assert(guardianHud:IsShown() and guardianDistance:GetText() == "300 yards", "Cancel lost the current respawn selection")
local mask = env.CreateFrame("Frame", nil, env.UIParent)
guardianHud.parent = mask
mask:Hide()
PublishLairs({ near })
c:ResetCounts()
Tick()
c:NoPresentationWrites()
mask:Show()
Tick()
assert(guardianDistance:GetText() == "10 yards", "hidden guidance failed to resume from the current lair")
PublishLairs({ Lair(1, nil, 0.51), Lair(2, -1, 0.8), Lair(3, math.huge, 0.55) })
assert(not guardianHud:IsShown(), "unknown, negative or nonfinite timers invented a respawn target")
local unavailable = Lair(1, 0, 0.51)
unavailable.x = nil
PublishLairs({ unavailable })
assert(not guardianHud:IsShown(), "missing lair coordinates reused an old destination")
PublishLairs({ near, Lair(3, nil, 0.56, "awake", 0) })
assert(not guardianHud:IsShown(), "an invalid occupied lair was treated as all guardians defeated")
minimapVisible = false
PublishLairs({ near, Lair(3, nil, 0.56, "awake", 8) })
assert(guardianDistance:GetText() == "60 yards", "a returned guardian did not take priority over the fallback")
PublishLairs({ soon })
phase = "ready"
Tick()
assert(not guardianHud:IsShown() and navigationPoints.AZS_LAIRS == nil, "run retirement retained a respawn target")
phase = "playing"
Tick()
assert(not guardianHud:IsShown(), "a new run replayed the retired lair snapshot")
PublishLairs({ near })
assert(guardianHud:IsShown(), "a fresh lair publication did not restore guidance")
c:Event(reader, "PLAYER_LEAVING_WORLD")
assert(not guardianHud:IsShown(), "world cleanup retained respawn guidance")
c:Event(reader, "PLAYER_ENTERING_WORLD")
Tick()
assert(not guardianHud:IsShown(), "world entry replayed the retired respawn destination")
display.Reset()
assert(not display.Get("guardianRespawnGuidance"), "full reset did not restore respawn guidance off")
print(
    "PASS guardian guidance selects the earliest native respawn only after every guardian is defeated, with shared idle and cleanup lifecycles"
)

-- Observe only the native guide boundary: selection remains private to the
-- production controller, and the fixture does not reproduce its algorithm.
local cacheHud = registered.cacheWaypoint
local cacheStamp = 0
local function Cache(id, mx) return { id = id, x = id, y = 0, mx = mx, my = 0.5 } end
local function PublishCaches(entries)
    cacheStamp = cacheStamp + 1
    env.AZS_CHESTS, env.AZS_CHESTS_UPDATED = entries, cacheStamp
    c:Event(reader, "CHAT_MSG_ADDON", "AZSCHESTS")
    Tick()
end
display.BeginEdit()
display.Set("guardianGuidance", false)
display.Set("partyGuidance", false)
minimapVisible = false
playerX, playerY = 0.5, 0.5
PublishCaches({ Cache(11, 0.75), Cache(12, 0.9) })
assert(lastGuidePoint.key == "11", "initial cache choice was not nearest")
PublishCaches({ Cache(11, 0.75), Cache(12, 0.9), Cache(13, 0.55) })
assert(lastGuidePoint.key == "13", "a closer arriving cache did not replace the old destination")
display.Set("performanceMode", true)
playerX = 0.88
Tick()
assert(lastGuidePoint.key == "12", "Performance Mode movement did not update the nearest cache")
display.Set("performanceMode", false)
Tick()
assert(lastGuidePoint.key == "12", "normal mode replayed an older selected cache")
playerX = 0.5
PublishCaches({ Cache(22, 0.625) })
PublishCaches({ Cache(21, 0.375), Cache(22, 0.625) })
assert(lastGuidePoint.key == "22", "equal distances changed selection to the first list entry")
PublishCaches({ Cache(22, 0.625), Cache(21, 0.375) })
assert(lastGuidePoint.key == "22", "equal-distance array reordering changed selection")
playerX = 0.625
Tick()
assert(lastGuidePoint.key == "22", "zero distance failed to retain the nearest cache")
PublishCaches({ Cache(21, 0.375) })
assert(lastGuidePoint.key == "21", "a retired cache identity remained selected")

playerX, missingDelta = 0.5, true
PublishCaches({ Cache(31, 0.625), Cache(32, 0.51) })
assert(cacheHud:IsShown() and lastGuidePoint.key == "31", "unavailable geometry lost the provisional first destination")
missingDelta = false
Tick()
assert(lastGuidePoint.key == "32", "ready geometry did not replace the provisional destination")
missingDelta = true
PublishCaches({ Cache(34, 0.99), Cache(32, 0.51), Cache(31, 0.625) })
assert(lastGuidePoint.key == "32", "missing geometry discarded the current available destination")
playerX, missingDelta = 0.98, false
Tick()
assert(lastGuidePoint.key == "34", "position recovery retained an obsolete nearest choice")

display.Set("cacheGuidance", false)
c:ResetCounts()
PublishCaches({ Cache(41, 0.99), Cache(42, 0.5) })
assert(not c.reads.delta and not cacheHud:IsShown(), "disabled guidance still scored native distances")
display.Set("cacheGuidance", true)
assert(cacheHud:IsShown() and lastGuidePoint.key == "41", "enable replayed a deferred stale destination")
hiddenWaypoints.cacheWaypoint = true
cacheHud:Hide()
Tick()
c:ResetCounts()
PublishCaches({ Cache(51, 0.875), Cache(52, 0.1) })
assert(not c.reads.delta, "Layout-hidden guidance still scored native distances")
c:ResetCounts()
Tick()
c:NoPresentationWrites()
hiddenWaypoints.cacheWaypoint = false
cacheHud:Show()
Tick(0.01)
assert(lastGuidePoint.key == "51", "shown guidance painted a stale destination before its next reader pass")
env.UIParent:Hide()
Tick()
c:ResetCounts()
PublishCaches({ Cache(53, 0.9375), Cache(54, 0.1) })
assert(not c.reads.delta, "hidden UIParent still scored waypoint distances")
c:ResetCounts()
Tick()
c:NoPresentationWrites()
env.UIParent:Show()
Tick()
assert(lastGuidePoint.key == "53", "UIParent recovery replayed the previous selection")
local prepared = #c.objects
c:ResetCounts()
for _ = 1, 20 do
    Tick()
end
c:NoPresentationWrites()
assert(#c.objects == prepared, "nearest refresh allocated additional drawing objects")
PublishCaches({ { id = 55, y = 0, mx = 0.6, my = 0.5 } })
assert(
    not cacheHud:IsShown() and navigationPoints.AZS_CHESTS == nil,
    "invalid native cache coordinates retained guidance"
)
PublishCaches({})
assert(not cacheHud:IsShown(), "empty cache publication invented a nearest destination")
PublishCaches({ Cache(61, 0.75) })
phase = "ready"
Tick()
assert(not cacheHud:IsShown(), "inactive phase retained the nearest cache")
phase = "playing"
Tick()
assert(not cacheHud:IsShown(), "a new run reused the retired nearest-cache publication")
PublishCaches({ Cache(62, 0.625) })
assert(cacheHud:IsShown() and lastGuidePoint.key == "62", "fresh cache data did not recover after retirement")

display.Set("cacheGuidance", false)
display.Set("guardianGuidance", true)
display.Set("guardianRespawnGuidance", false)
playerX = 0.5
PublishLairs({ Lair(20, nil, 0.75, "awake", 11) })
assert(lastGuidePoint.key == "20:11", "initial living guardian did not acquire guidance")
PublishLairs({ Lair(20, nil, 0.75, "awake", 11), Lair(21, nil, 0.51, "asleep", 12) })
assert(lastGuidePoint.key == "21:12", "a closer living guardian did not replace the old destination")
playerX = 0.74
Tick()
assert(lastGuidePoint.key == "20:11", "player movement did not update the nearest living guardian")
playerX = 0.5
PublishLairs({ Lair(22, nil, 0.375, "awake", 13), Lair(20, nil, 0.625, "awake", 11) })
assert(lastGuidePoint.key == "20:11", "equal guardian distances discarded the current identity")
PublishLairs({ Lair(20, nil, 0.625), Lair(22, nil, 0.375, "awake", 13) })
assert(lastGuidePoint.key == "22:13", "an empty lair kept the retired guardian selected")
display.Set("guardianGuidance", false)
c:ResetCounts()
Tick()
assert(not c.reads.delta, "disabled living-guardian guidance still scored distances")
display.FinishEdit(false)
print("PASS nearest cache/living-guardian guidance retains ties, native readiness, hidden idleness and retirement")
