-- CI only: production snapshot preparation over explicit received-table boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")

local function Point(id) return { id = id, x = id * 10, y = 20, mx = 0.5, my = 0.5 } end
local function Empty(buffer)
    assert(buffer.cleared and buffer.pointCount == 0 and buffer.lairCount == 0)
    for _, pool in ipairs({ buffer.points, buffer.lairRows or {} }) do
        for _, row in ipairs(pool) do
            assert(not next(row), "retired snapshot retained point/lair fields")
        end
    end
    assert(not next(buffer.entries) and not next(buffer.seen))
end

for _, performance in ipairs({ false, true }) do
    local c = H.New()
    local env = c.env
    c.settings.performanceMode = performance
    env.DFRL.guardians = { AcceptLairs = function(rows) c.lairs = rows end }
    local chunk = assert(loadfile(assert(arg[1], "missing waypoint snapshot source")))
    setfenv(chunk, env)
    local api = chunk()
    local cache = { kind = "cache", source = "AZS_CHESTS" }
    local function Publish(tracker, rows)
        env[tracker.source], env[tracker.source .. "_UPDATED"] = rows, 1
        tracker.packetGeneration = (tracker.packetGeneration or 0) + 1
        return api.Read(tracker)
    end
    local native = { Point(1), Point(2) }
    native[1].runId = "old-run"
    local first = assert(Publish(cache, native))
    local firstPoint = first[1]
    assert(firstPoint ~= native[1] and api.Read(cache) == first, "unchanged publication lost its copied identity")
    local second = assert(Publish(cache, { Point(3), Point(4), Point(5) }))
    local secondPoint = second[1]
    assert(second ~= first, "new publication reused the live navigation list")
    local third = assert(Publish(cache, { Point(6) }))
    assert(third == first and third[1] == firstPoint and env.table.getn(third) == 1, "third publication missed reuse")
    assert(third[1].key == "6" and not third[1].runId and not cache.snapshotBuffer.points[2].key)
    local rejected = { Point(7), Point(7) }
    assert(not Publish(cache, rejected), "duplicate candidate was accepted")
    assert(third[1].key == "6" and third[1].x == 60, "rejected candidate changed the accepted destination")
    Empty(cache.stagingSnapshot)
    local recovered = assert(Publish(cache, { Point(8), Point(9), Point(10) }))
    assert(recovered == second and recovered[1] == secondPoint and env.table.getn(recovered) == 3)
    assert(
        native[1].id == 1 and native[1].runId == "old-run" and rejected[1].id == 7,
        "snapshot preparation changed native data"
    )
    api.Clear(cache.snapshotBuffer)
    api.Clear(cache.stagingSnapshot)
    Empty(cache.snapshotBuffer)
    Empty(cache.stagingSnapshot)

    local guardian = { kind = "guardian", source = "AZS_LAIRS", selectedKey = "2:0" }
    local function Lair(index, id, state, left)
        return { index = index, id = id, state = state, name = "Lair " .. index, left = left, x = index, y = 0 }
    end
    local living = assert(Publish(guardian, { Lair(1, 31, "awake"), Lair(2, 0, "empty", 5) }))
    local occupiedPoint = living[1]
    assert(guardian.acceptedMinimapEntries[1] == occupiedPoint and env.table.getn(guardian.acceptedMinimapEntries) == 2)
    assert(env.table.getn(c.lairs) == 2 and not guardian.acceptedRespawn, "mixed lairs became all defeated")
    assert(Publish(guardian, { Lair(1, 0, "empty", 5), Lair(2, 0, "empty", 5) }))
    assert(
        guardian.acceptedRespawn.key == "2:0" and env.table.getn(guardian.acceptedEntries) == 0,
        "respawn tie changed"
    )
    local awake = assert(Publish(guardian, { Lair(1, 32, "awake") }))
    assert(awake == living and awake[1] == occupiedPoint and awake[1].id == 32 and not awake[1].left)
    assert(env.table.getn(guardian.acceptedMinimapEntries) == 1 and env.table.getn(c.lairs) == 1)
    local active = guardian.snapshotBuffer
    env.AZS_LAIRS[1].id = 33
    guardian.packetGeneration = guardian.packetGeneration + 1
    assert(
        api.Read(guardian) ~= awake and guardian.snapshotBuffer ~= active,
        "same-table receipt kept an old list identity"
    )
    api.Clear(guardian.snapshotBuffer)
    api.Clear(guardian.stagingSnapshot)
    Empty(guardian.snapshotBuffer)
    Empty(guardian.stagingSnapshot)
end
print(
    "PASS waypoint buffers retain atomic rejection, native data, list invalidation, pool reuse and retirement in both modes"
)
