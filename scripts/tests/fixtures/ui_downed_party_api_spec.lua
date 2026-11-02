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
members = { [2] = Member("member", 1, 1) }
assert(nav.DownedPartySnapshot() == nil, "sparse native list accepted")
members = { Member("member", 1, 1) }
members[1].z = 0 / 0
assert(nav.DownedPartySnapshot() == nil, "nonfinite coordinate accepted")
members = { Member("member", 1, 1) }
members[1].runId, position.runId = nil, nil
value = nav.DownedPartySnapshot()
assert(#value == 1 and nav.IsCurrentDestination(value[1]), "matching optional run IDs rejected")
env.AZS_GetDownedPartyMembers = function() error("temporarily unavailable") end
value, supported = nav.DownedPartySnapshot()
assert(value == nil and supported, "native failure enabled map fallback")
env.AZS_GetDownedPartyMembers = function() return {} end
assert(#nav.DownedPartySnapshot() == 0, "revival/departure retained a destination")
print("downed-party native position cases passed")
