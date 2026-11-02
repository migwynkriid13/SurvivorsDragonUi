-- CI only: full production marker boundary with separate post-camera frames.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local function Scene(performance)
    local c = H.New()
    local env = c.env
    local object = c.Object
    function c:Object(...)
        local frame = object(self, ...)
        local setPoint = frame.SetPoint
        function frame:SetPoint(...)
            setPoint(self, ...)
            self.point = { ... }
        end
        return frame
    end
    c:Load("core/display.lua", "Display")
    env.DFRL.display.BeginEdit()
    env.DFRL.display.Set("performanceMode", performance)
    env.WorldFrame = env.CreateFrame("Frame", "WorldFrame", env.UIParent)
    local native = {
        handlers = {},
        entries = {},
        calls = 0,
        registers = 0,
        unregisters = 0,
        catalog = "catalog",
        world = "world",
        frame = 0,
        queryKinds = {},
    }
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
            attachments = { position = native.position ~= false, overhead = native.overhead ~= false },
            maxEntriesPerRead = native.pageLimit or 2,
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
        assert(native.inService, "discovery escaped the existing controller")
        assert(limit == (native.pageLimit or 2), "discovery exceeded provider limit")
        if native.discoveryFault then
            local failure = native.discoveryFault(cursor)
            if failure then return nil, { code = failure } end
        end
        local kinds, entries = {}, {}
        for _, kind in ipairs(query.kinds) do
            kinds[kind], native.queryKinds[kind] = true, true
        end
        for _, entry in ipairs(native.entries) do
            if kinds[entry.kind] then table.insert(entries, entry) end
        end
        local first = 1
        if cursor then
            local frame, index = string.match(cursor, "^(%d+):(%d+)$")
            if tonumber(frame) ~= native.frame then return nil, { code = "CATALOG_CHANGED" } end
            first = tonumber(index)
            if not first then return nil, { code = "CATALOG_CHANGED" } end
        end
        local page = {
            apiVersion = 1,
            catalogId = native.catalog .. ":" .. native.frame,
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
        page.nextCursor = page.hasMore and (native.frame .. ":" .. (first + limit)) or nil
        if native.pageFault then native.pageFault(page, cursor) end
        return page
    end
    env.AZS_ProjectWorldAnchors = function(requests)
        native.projections = (native.projections or 0) + 1
        assert(native.inFrame and #requests == 1, "projection escaped post-camera phase or batching")
        local id, attachment = requests[1].anchorId, requests[1].attachment
        for key in pairs(requests[1]) do
            assert(key == "anchorId" or key == "attachment", "marker requested optional world offsets/occlusion")
        end
        local source
        for _, entry in ipairs(native.entries) do
            if entry.anchorId == id then source = entry end
        end
        local entry = {
            anchorId = id,
            attachment = attachment,
            state = source and source.projectState or "expired",
            entityState = source and source.state,
        }
        if source then
            local expected = (source.kind == "cache" or source.kind == "downedPartyMember") and "position" or "overhead"
            assert(attachment == expected, "consumer requested an unsupported entity attachment")
            if source.attachments[attachment] ~= true then
                entry.state, entry.reason = "unavailable", "unsupportedAttachment"
            end
        end
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
    function c:Service(elapsed)
        if elapsed then
            self.now = self.now + elapsed
            native.frame = native.frame + 1
        end
        native.inService = true
        self.api.Service(true)
        native.inService = false
    end
    function c:Frame()
        native.frame = native.frame + 1
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
        attachments = { position = true, overhead = kind ~= "cache" and kind ~= "downedPartyMember" },
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
    local discoveryReads = native.calls
    c:Service()
    assert(
        native.calls - discoveryReads == 2 and #c:Markers() == 0,
        "catalog did not complete inside one service frame"
    )
    c:Frame()
    assert(#c:Markers() == 3, "same-frame pagination omitted a boss")
    for _, marker in ipairs(c:Markers()) do
        local padding = marker.kind == "boss" and 6 or 22
        assert(marker.point[5] == 200 + padding, "marker used a guessed world height or incorrect screen spacing")
    end
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
-- Affordability changes gate only world caches, without re-discovery or rebinding.
for _, performance in ipairs({ false, true }) do
    local c = Scene(performance)
    local env, native = c.env, c.native
    local display = env.DFRL.display
    assert(not display.Get("worldCacheAffordableOnly"), "affordable-only changed the default cache visibility")
    native.entries = { Record("cache", "cache"), Record("ally", "downedPartyMember") }
    c:Service()
    c:Frame()
    assert(#c:Markers() == 2, "default cache icons require affordability data")
    local registrations, calls, objects = native.registers, native.calls, #c.objects
    display.Set("worldCacheAffordableOnly", true)
    local function Check(run, stamp, expected, projected)
        env.AZS_RUN, env.AZS_RUN_UPDATED = run, stamp
        local before = native.projections or 0
        c:Frame()
        assert(#c:Markers() == expected, "incorrect affordability visibility")
        assert((native.projections or 0) - before == projected, "hidden cache still requested projection")
        assert(
            native.registers == registrations and native.calls == calls,
            "affordability rebound or rediscovered anchors"
        )
        assert(#c.objects == objects, "affordability allocated another marker")
    end
    Check({ gold = 9, chest = 10 }, 1, 1, 1)
    Check({ gold = 10, chest = 10 }, 1, 2, 2)
    c:ResetCounts()
    Check({ gold = 10, chest = 10 }, 1, 2, 2)
    assert(
        not c.writes.SetPoint and not c.writes.SetTexture and not c.writes.Show and not c.writes.Hide,
        "unchanged affordability repainted world icons"
    )
    Check({ gold = 10, chest = 11 }, 1, 1, 1)
    Check({ gold = 20, chest = 11 }, 1, 2, 2)
    Check({ gold = 5, chest = 11 }, 1, 1, 1)
    Check({ gold = 0, chest = 0 }, 1, 2, 2)
    Check({ gold = 1.5, chest = 1.5 }, 1, 2, 2)
    Check({ gold = 1.49, chest = 1.5 }, 1, 1, 1)
    Check(nil, 1, 1, 1)
    Check({}, 1, 1, 1)
    Check({ gold = 10, chest = 1 }, nil, 1, 1)
    Check({ gold = 10, chest = 1 }, 0 / 0, 1, 1)
    for _, invalid in ipairs({ -1, "10", 0 / 0, math.huge }) do
        Check({ gold = invalid, chest = 1 }, 1, 1, 1)
        Check({ gold = 10, chest = invalid }, 1, 1, 1)
    end
    display.Set("worldCacheAffordableOnly", false)
    Check(nil, nil, 2, 2)
    display.Set("worldCacheAffordableOnly", true)
    native.entries = { Record("cache", "cache") }
    c:Service(0.21)
    local projections = native.projections or 0
    c:Frame()
    assert(
        #c:Markers() == 0 and (native.projections or 0) == projections,
        "all-unaffordable caches retained native projections"
    )
    c.api.Reset()
end
-- Provider notes: per-kind attachments, same-frame cursors and stable handles.
for _, performance in ipairs({ false, true }) do
    local c = Scene(performance)
    local native, display = c.native, c.env.DFRL.display
    display.Set("worldBossIcons", true)
    native.entries = { Record("cache", "cache"), Record("ally", "downedPartyMember") }
    c:Service()
    c:Frame()
    local registrations, releases, objects = native.registers, native.unregisters, #c.objects
    native.entries[3] = Record("new-boss", "boss")
    native.discoveryFault = function(cursor)
        if cursor then return "CATALOG_CHANGED" end
    end
    local reads = native.calls
    c:Service(0.21)
    assert(native.calls == reads + 2, "multi-page discovery yielded across frames")
    c:Frame()
    assert(#c:Markers() == 2, "catalog refresh failure discarded valid handles or published partial additions")
    assert(native.registers == registrations and native.unregisters == releases and #c.objects == objects)
    reads = native.calls
    c:Service()
    assert(native.calls == reads, "catalog retry ran repeatedly in the same frame")
    native.discoveryFault = nil
    c:Service(0.11)
    assert(#c:Markers() == 2, "discovery painted outside the post-camera callback")
    c:Frame()
    assert(#c:Markers() == 3, "catalog retry did not publish a complete replacement")
    objects = #c.objects
    for _, code in ipairs({ "NOT_READY", "CATALOG_CHANGED", "UNKNOWN" }) do
        native.discoveryFault = function() return code end
        c:Service(0.6)
        c:Frame()
        assert(#c:Markers() == 3 and #c.objects == objects, "temporary discovery failure lost reusable markers")
        assert(
            native.registers == registrations and native.unregisters == releases,
            "temporary discovery failure rebound handler"
        )
        reads = native.calls
        c:Service()
        assert(native.calls == reads, "failed discovery ignored its retry gate")
        native.discoveryFault = nil
        c:Service(code == "UNKNOWN" and 0.51 or 0.11)
        c:Frame()
        assert(#c:Markers() == 3, "stable handles failed to recover after discovery retry")
    end
    reads = native.calls
    for _ = 1, 12 do
        c:Frame()
    end
    c:Service()
    assert(native.calls == reads and #c:Markers() == 3, "per-frame camera projection re-read the catalog")
    c:Service(0.21)
    c:Frame()
    assert(native.calls == reads + 2 and #c.objects == objects, "periodic discovery did not retain pooled handles")
    native.pageFault = function(page, cursor)
        if cursor then
            page.hasMore, page.nextCursor = true, cursor
        end
    end
    c:Service(0.21)
    c:Frame()
    assert(#c:Markers() == 3, "cyclic cursor discarded valid handles")
    native.pageFault = nil
    c:Service(0.51)
    for _, fault in ipairs({
        function(page) page.entries = { [2] = page.entries[1] } end,
        function(page)
            if page.entries[2] then page.entries[2] = page.entries[1] end
        end,
        function(page, cursor)
            if cursor then page.catalogId = "changed-within-frame" end
        end,
    }) do
        native.pageFault = fault
        reads = native.calls
        c:Service(0.51)
        c:Frame()
        assert(native.calls > reads and #c:Markers() == 3, "malformed/changed catalog lost accepted handles")
        assert(
            native.registers == registrations and native.unregisters == releases and #c.objects == objects,
            "rejected catalog changed marker ownership or pooling"
        )
        native.pageFault = nil
        c:Service(0.51)
        c:Frame()
        assert(#c:Markers() == 3, "complete catalog did not recover after rejected refresh")
    end
    native.entries[1].attachments.position = false
    c:Frame()
    assert(#c:Markers() == 2, "unsupported attachment reused stale screen coordinates")
    native.entries[1].attachments.position = true
    c:Frame()
    assert(#c:Markers() == 3, "unavailable attachment did not recover without rebinding")
    native.entries = {}
    c:Service(0.21)
    c:Frame()
    assert(#c:Markers() == 0, "complete empty catalog failed to retire handles")
    c.api.Reset()

    local positions = Scene(performance)
    positions.native.overhead = false
    positions.env.DFRL.display.Set("worldBossIcons", true)
    positions.native.entries = { Record("cache", "cache"), Record("ally", "downedPartyMember"), Record("boss", "boss") }
    positions:Service()
    positions:Frame()
    assert(
        #positions:Markers() == 2 and not positions.native.queryKinds.boss,
        "position-only capability unnecessarily required unit overhead"
    )
    positions.api.Reset()
    local units = Scene(performance)
    units.native.position = false
    units.env.DFRL.display.Set("worldBossIcons", true)
    units.native.entries = { Record("cache", "cache"), Record("ally", "downedPartyMember"), Record("boss", "boss") }
    units:Service()
    units:Frame()
    assert(
        #units:Markers() == 1 and not units.native.queryKinds.cache and not units.native.queryKinds.downedPartyMember,
        "unit-only overhead capability invented cache or ally attachments"
    )
    units.api.Reset()

    local delayed = Scene(performance)
    delayed.env.DFRL.display.Set("worldBossIcons", true)
    delayed.native.entries = { Record("stable-enemy-handle", "enemy") }
    local firstFrame = delayed.native.frame
    delayed.native.discoveryFault = function()
        if delayed.native.frame == firstFrame then return "NOT_READY" end
    end
    delayed:Service()
    assert(delayed.native.registers == 1 and delayed.native.unregisters == 0, "first-read warmup released the callback")
    delayed:Frame()
    delayed:Service(0.11)
    delayed:Frame()
    assert(
        #delayed:Markers() == 0 and not delayed.native.queryKinds.enemy,
        "unknown enemy kind became a guessed guardian"
    )
    delayed.native.entries[1].kind = "guardian"
    delayed:Service(0.21)
    delayed:Frame()
    assert(
        #delayed:Markers() == 1
            and delayed.native.entries[1].anchorId == "stable-enemy-handle"
            and delayed.native.registers == 1,
        "delayed guardian metadata lost its stable handle"
    )
    delayed.api.Reset()
end
-- A bounded frame pass cannot publish the first 256 records of a larger catalog.
local bounded = Scene(false)
bounded.native.pageLimit = 1
bounded.native.entries = { Record("retained-cache", "cache") }
bounded:Service()
bounded:Frame()
for index = 2, 257 do
    bounded.native.entries[index] = Record("cache-" .. index, "cache")
end
local boundedReads = bounded.native.calls
bounded:Service(0.21)
bounded:Frame()
assert(
    bounded.native.calls - boundedReads == 256 and #bounded:Markers() == 1,
    "oversized catalog exceeded its frame budget or published a partial replacement"
)
bounded.api.Reset()
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
