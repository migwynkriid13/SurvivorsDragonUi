-- CI only: authoritative positions without map UVs, targeting or ghost inference.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local c = H.New()
local env = c.env
local position = {
    apiVersion = 1,
    mapId = 0,
    spaceId = "instance",
    runId = "run",
    sampleId = "frame",
    x = 0,
    y = 0,
    z = 0,
    facing = 0,
}
env.AZS_GetPhase = function() return "playing" end
env.AZS_GetMeterCapabilities = function() return { apiVersion = 1, features = { liveInstancePosition = true } } end
env.AZS_GetPlayerPosition = function() return position end
env.GetPlayerMapPosition = function() error("downed world guidance requested map UVs") end
c:Load("modules/map/navigation.lua", "Navigation")
local nav = env.DFRL.navigation
local value, supported = nav.DownedPartySnapshot()
assert(value == nil and supported == false, "missing getter disabled legacy fallback")
local members
env.AZS_GetDownedPartyMembers = function() return members end
local function Member(id, x, y)
    return {
        id = id,
        name = "Same caption",
        positionAvailable = true,
        x = x,
        y = y,
        z = 0,
        mapId = 0,
        spaceId = "instance",
        runId = "run",
    }
end
members = { Member("member-one", 0, 0), Member("member-two", 30, -40) }
value, supported = nav.DownedPartySnapshot()
assert(supported and #value == 2 and value[1].key ~= value[2].key, "names became native identities")
assert(nav.IsCurrentDestination(value[1]) and select(3, nav.Delta(value[1])) == 0, "valid zero position rejected")
assert(select(3, nav.GuideDelta(value[2])) == 50, "instance guidance lost native yard geometry")
members[2].x = 90
assert(value[2].x == 30, "consumer retained a native member table")
position.y = 10
assert(nav.Delta(value[2]) == 50, "observer movement did not update direction")
position.y = 0
for _, field in ipairs({ "mapId", "spaceId", "runId" }) do
    members = { Member("member", 10, 10) }
    members[1][field] = field == "mapId" and 2 or "another"
    assert(#nav.DownedPartySnapshot() == 0, "mismatched " .. field .. " was used")
end
members = { { id = "unavailable", name = "Downed", positionAvailable = false } }
value, supported = nav.DownedPartySnapshot()
assert(supported and #value == 0, "unavailable member acquired a guessed location")
members = { Member("member", 1, 1), Member("member", 2, 2) }
assert(nav.DownedPartySnapshot() == nil, "duplicate native IDs accepted")
c.now = c.now + 8.1
members = { [2] = Member("member", 1, 1) }
assert(nav.DownedPartySnapshot() == nil, "sparse native list accepted")
c.now = c.now + 8.1
members = { Member("member", 1, 1) }
members[1].z = 0 / 0
assert(nav.DownedPartySnapshot() == nil, "nonfinite coordinate accepted")
c.now = c.now + 8.1
members = { Member("member", 1, 1) }
members[1].runId, position.runId = nil, nil
value = nav.DownedPartySnapshot()
assert(#value == 1 and nav.IsCurrentDestination(value[1]), "matching optional run IDs rejected")
env.AZS_GetDownedPartyMembers = function() error("temporarily unavailable") end
value, supported = nav.DownedPartySnapshot()
assert(value == nil and supported, "native failure enabled map fallback")
env.AZS_GetDownedPartyMembers = function() return {} end
assert(#nav.DownedPartySnapshot() == 0, "revival/departure retained a destination")
-- Coarse native roster and presentation demand avoid unnecessary new API reads.
local rosterReads, downedReads, playerReads = 0, 0, 0
local roster = 0
env.GetNumPartyMembers = function()
    rosterReads = rosterReads + 1
    return roster
end
env.AZS_GetDownedPartyMembers = function()
    downedReads = downedReads + 1
    return members
end
env.AZS_GetPlayerPosition = function()
    playerReads = playerReads + 1
    return position
end
members = { Member("unused", 1, 1) }
for _ = 1, 20 do
    assert(#nav.DownedPartySnapshot() == 0)
end
assert(downedReads == 0 and playerReads == 0, "solo guidance queried downed members or player position")
nav.WithSample(function()
    local before = rosterReads
    for _ = 1, 10 do
        assert(not nav.HasParty())
        nav.DownedPartySnapshot()
    end
    assert(rosterReads == before + 1, "one controller pass repeated native roster reads")
end)
roster = 1
members = {}
nav.WithSample(function()
    assert(nav.HasParty())
    assert(#nav.DownedPartySnapshot() == 0)
    assert(not nav.NeedsPartyMarker(), "same-pass empty native feed did not suppress duplicate world discovery")
end)
assert(nav.NeedsPartyMarker(), "downed presence escaped its validated reader pass")
assert(downedReads == 1 and playerReads == 0, "empty downed snapshot queried player position")
members = { { id = "unavailable", name = "Downed", positionAvailable = false } }
assert(#nav.DownedPartySnapshot() == 0 and playerReads == 0, "unavailable downed locations queried player position")
position.runId = "run"
members = { Member("needed", 1, 1) }
assert(#nav.DownedPartySnapshot() == 1 and playerReads == 1, "returning party did not read a fresh native location")
roster = "unknown"
local before = downedReads
assert(
    #nav.DownedPartySnapshot() == 1 and downedReads == before + 1,
    "unknown roster incorrectly suppressed authoritative API"
)
-- Persistent native failure hides stale positions and backs off, then a valid
-- read restores normal response time without affecting the legacy boundary.
roster = 1
local attempts, failing = 0, true
env.AZS_GetDownedPartyMembers = function()
    attempts = attempts + 1
    if failing then return nil, { code = "NOT_READY" } end
    return members
end
before = playerReads
for _ = 1, 100 do
    c.now = c.now + 0.1
    value, supported = nav.DownedPartySnapshot()
    assert(value == nil and supported, "native retry used stale positions or enabled legacy fallback")
end
assert(attempts >= 3 and attempts <= 6 and playerReads == before, "downed API failure flooded native requests")
failing = false
c.now = c.now + 8.1
assert(#nav.DownedPartySnapshot() == 1, "downed API retry failed to recover fresh data")
failing = true
assert(nav.DownedPartySnapshot() == nil)
before = attempts
c.now = c.now + 0.51
assert(nav.DownedPartySnapshot() == nil and attempts == before + 1, "successful downed read retained long backoff")
nav.Reset()
failing = false
assert(#nav.DownedPartySnapshot() == 1, "world reset retained a failed downed-read delay")
nav.Reset()
print("downed-party native position cases passed")
