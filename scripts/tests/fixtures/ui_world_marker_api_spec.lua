-- CI only: full production marker boundary with separate post-camera frames.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local function Scene(performance)
    local c = H.New()
    local env = c.env
    c:Load("core/display.lua", "Display")
    env.DFRL.display.BeginEdit()
    env.DFRL.display.Set("performanceMode", performance)
    env.WorldFrame = env.CreateFrame("Frame", "WorldFrame", env.UIParent)
    local native =
        { handlers = {}, entries = {}, calls = 0, registers = 0, unregisters = 0, catalog = "catalog", world = "world" }
    local position = { mapId = 0, runId = "run", spaceId = "instance" }
    c.native, c.position = native, position
    native.foreign = function() end
    native.handlers[native.foreign] = true
    env.AZS_GetWorldAnchorCapabilities = function()
        return {
            apiVersion = 1,
            frameHandler = true,
            kinds = {
                cache = true,
                guardian = true,
                boss = true,
                finalBoss = true,
                downedPartyMember = true,
            },
            attachments = { overhead = true },
            maxEntriesPerRead = 2,
            maxAnchorsPerRead = 1,
        }
    end
    env.AZS_RegisterWorldAnchorFrameHandler = function(handler)
        native.registers = native.registers + 1
        native.handlers[handler] = true
        if native.registerFault then return false end
        return true
    end
    env.AZS_UnregisterWorldAnchorFrameHandler = function(handler)
        native.unregisters = native.unregisters + 1
        if native.releaseFault then return false end
        native.handlers[handler] = nil
        return true
    end
    env.AZS_GetWorldAnchors = function(query, cursor, limit)
        native.calls = native.calls + 1
        assert(limit == 2, "discovery exceeded provider limit")
        local kinds, entries = {}, {}
        for _, kind in ipairs(query.kinds) do
            kinds[kind] = true
        end
        for _, entry in ipairs(native.entries) do
            if kinds[entry.kind] then table.insert(entries, entry) end
        end
        local first = tonumber(cursor) or 1
        local page = {
            apiVersion = 1,
            catalogId = native.catalog,
            worldId = native.world,
            mapId = position.mapId,
            spaceId = position.spaceId,
            runId = position.runId,
            entries = {},
        }
        for index = first, math.min(first + limit - 1, #entries) do
            table.insert(page.entries, entries[index])
        end
        page.hasMore = first + limit <= #entries
        page.nextCursor = page.hasMore and tostring(first + limit) or nil
        if native.pageFault then native.pageFault(page) end
        return page
    end
    env.AZS_ProjectWorldAnchors = function(requests)
        assert(native.inFrame and #requests == 1, "projection escaped post-camera phase or batching")
        local id = requests[1].anchorId
        local source
        for _, entry in ipairs(native.entries) do
            if entry.anchorId == id then source = entry end
        end
        local entry = {
            anchorId = id,
            attachment = "overhead",
            state = source and source.projectState or "expired",
            entityState = source and source.state,
        }
        if entry.state == "onScreen" then
            entry.x, entry.y = source.x or 100, source.y or 200
            entry.cameraDistance, entry.cameraDepth, entry.uiUnitsPerYard = 20, 20, 16
            entry.occlusion = source.occlusion or "notTested"
        end
        local batch = {
            apiVersion = 1,
            worldId = native.world,
            cameraSampleId = "camera",
            clockSeconds = c.now,
            frameCurrent = native.frameCurrent ~= false,
            entries = { entry },
        }
        if native.projectFault then native.projectFault(batch) end
        return batch
    end
    c:Load("core/world_marker_api.lua")
    c.api = env.T.NewWorldMarkerApi({
        WorldPosition = function() return position end,
        Phase = function() return "playing" end,
        IsRunPhase = function() return true end,
    })
    function c:Service() self.api.Service(true) end
    function c:Frame()
        native.inFrame = true
        for handler in pairs(native.handlers) do
            handler()
        end
        native.inFrame = false
    end
    function c:Markers()
        local result = {}
        for _, object in ipairs(self.objects) do
            if object.icon and object:GetParent() == env.WorldFrame and object:IsVisible() then
                table.insert(result, object)
            end
        end
        return result
    end
    return c
end
local function Record(id, kind)
    return {
        anchorId = id,
        kind = kind,
        state = kind == "cache" and "available" or (kind == "downedPartyMember" and "downed" or "alive"),
        anchorStatus = "ready",
        attachments = { overhead = true },
        projectState = "onScreen",
    }
end
for _, performance in ipairs({ false, true }) do
    local c = Scene(performance)
    local native, display = c.native, c.env.DFRL.display
    assert(display.Get("worldCacheIcons") and display.Get("worldPartyIcons") and not display.Get("worldBossIcons"))
    native.entries = { Record("cache", "cache"), Record("ally", "downedPartyMember"), Record("boss", "boss") }
    c:Service()
    assert(#c:Markers() == 0, "ordinary controller placed a world marker")
    c:Frame()
    assert(#c:Markers() == 2 and native.registers == 1 and native.handlers[native.foreign])
    local objects = #c.objects
    c:ResetCounts()
    c:Frame()
    assert(
        not c.writes.SetPoint and not c.writes.SetTexture and not c.writes.Show and not c.writes.Hide,
        "unchanged projection rewrote static presentation"
    )
    native.entries[1].x = 300
    c:Frame()
    assert(c.writes.SetPoint, "camera movement did not move a marker")
    native.entries[1].projectState = "behindCamera"
    c:Frame()
    assert(#c:Markers() == 1, "behind-camera icon remained visible")
    native.entries[1].projectState = "onScreen"
    native.entries[1].occlusion = "occluded"
    c:Frame()
    assert(#c:Markers() == 1, "explicitly occluded icon remained visible")
    native.entries[1].occlusion = nil
    display.Set("worldBossIcons", true)
    c:Service()
    c:Frame()
    assert(#c:Markers() == 0, "partial catalog was committed")
    c:Service()
    c:Frame()
    assert(#c:Markers() == 3, "completed pagination omitted a boss")
    native.frameCurrent = false
    c:Frame()
    assert(#c:Markers() == 0, "early camera sample was drawn")
    native.frameCurrent = true
    c:Service()
    c.now = c.now + 1
    c:Service()
    c:Service()
    c:Frame()
    native.projectFault = function(batch)
        if batch.entries[1].anchorId == "ally" then batch.entries[1].x = 0 / 0 end
    end
    c:Frame()
    assert(#c:Markers() == 0, "malformed later batch left partial world icons")
    native.projectFault = nil
    native.entries = {}
    c:Service()
    c:Frame()
    assert(#c:Markers() == 0, "collection/revival retained old markers")
    native.entries = { Record("next-cache", "cache") }
    c.now = c.now + 1
    c:Service()
    c:Frame()
    assert(#c:Markers() == 1 and #c.objects <= objects + 2, "marker pool did not reuse retired frames")
    local retired
    for handler in pairs(native.handlers) do
        if handler ~= native.foreign then retired = handler end
    end
    native.releaseFault = true
    c.api.Reset()
    retired()
    assert(#c:Markers() == 0 and native.handlers[native.foreign], "retired callback or cleanup touched foreign state")
    local registrations = native.registers
    c:Service()
    assert(native.registers == registrations, "failed release registered a duplicate callback")
    native.releaseFault = false
    c.now = c.now + 1
    c:Service()
    c:Frame()
    assert(#c:Markers() == 1, "pending cleanup did not recover")
    retired()
    assert(native.handlers[native.foreign], "old callback stole a foreign owner")
    display.Set("worldCacheIcons", false)
    display.Set("worldBossIcons", false)
    display.Set("worldPartyIcons", false)
    c:Service()
    local reads = native.calls
    c:Service()
    c:Frame()
    assert(native.calls == reads and #c:Markers() == 0, "disabled markers retained discovery or drawings")
    c.api.Reset()
end
local old = Scene(false)
old.env.AZS_GetWorldAnchorCapabilities = nil
old:Service()
assert(old.native.registers == 0 and #old:Markers() == 0, "older provider invented world markers")
local partial = Scene(false)
partial.native.registerFault = true
partial:Service()
assert(partial.native.unregisters > 0, "partial registration was not released")
partial.native.registerFault = false
partial.now = partial.now + 1
partial:Service()
assert(partial.native.registers == 2, "partial registration did not recover")
partial.api.Reset()
print("world marker native boundary cases passed")
