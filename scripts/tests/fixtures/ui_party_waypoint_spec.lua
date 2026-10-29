-- CI only: the full waypoint controller over explicit native party boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "party waypoint fixtures require CI Lua 5.1")
local c = H.New()
local env = c.env
local phase, unitReads, positionReads = "playing", 0, 0
local members, registered, bound = {}, {}, {}
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
env.DFRL.actionBarDefaults = { bottom = 20, height = 30, topInset = 0, width = 500, sideInset = 0 }
env.DFRL.xpBarDefaults = { top = 10, height = 8, borderHeight = 0 }
env.DFRL.locale.Bind = function(label) bound[label] = true end
env.DFRL.locale.code = "en"
env.DFRL.locale.Native = function(_, fields) return tostring(fields.n) .. " yards" end
env.DFRL.layout.Register = function(key, frame, anchor)
    registered[key] = frame
    anchor()
end
local swapDuringRead, missingPosition
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
        local east, north = (point.mx - 0.5) * 1000, (0.5 - point.my) * 1000
        return east, north, math.sqrt(east * east + north * north), true
    end,
    Delta = function(point) return env.DFRL.navigation.GuideDelta(point) end,
    Heading = function() return 0 end,
    SetPoints = function() end,
    Reset = function() end,
    WithSample = function(callback) callback() end,
    UpdateMinimapPlayer = function() end,
}
c:Load("core/hud.lua")
c:Load("core/display.lua", "Display")
c:Load("modules/map/waypoints.lua", "Waypoints")
local display = env.DFRL.display
local hud, reader = env.DFRL_PartyWaypoint, env.DFRL_CacheWaypointReader
assert(registered.partyWaypoint == hud, "fallen ally bypassed shared Layout registration")
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
assert(display.Get("partyGuidance") and not display.Get("mirrorPartyWaypoint"))
assert(display.Copy({ partyGuidance = 0, mirrorPartyWaypoint = 1 }).partyGuidance)
assert(not display.Copy({ mirrorPartyWaypoint = 1 }).mirrorPartyWaypoint)
Tick()
assert(not hud:IsShown(), "an empty party created a destination")
members.party1, members.party2 = Member("Far ally", 0.8, 0.8), Member("Near ally", 0.55, 0.5)
Tick()
assert(hud:IsShown() and title:GetText() == "Near ally" and distance:GetText() == "50 yards")
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
