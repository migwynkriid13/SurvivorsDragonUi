-- CI only: released world-anchor v1 contract, with separate post-camera frames.
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
        stream = "stream",
        frame = 0,
        queryKinds = {},
    }
    local position = { mapId = 0, runId = "run", spaceId = "instance" }
    c.native, c.position = native, position
    native.foreign = function() end
    native.handlers[native.foreign] = true
    env.AZS_GetWorldAnchorCapabilities = function()
        native.capabilityReads = (native.capabilityReads or 0) + 1
        local attachments = {}
        if native.position ~= false then table.insert(attachments, "position") end
        if native.overhead ~= false then table.insert(attachments, "overhead") end
        local caps = {
            apiVersion = 1,
            frameProjection = true,
            frameHandler = true,
            kinds = {
                "cache",
                "guardian",
                "boss",
                "finalBoss",
                "downedPartyMember",
                "enemy",
                "elite",
                "guardianLair",
            },
            attachments = attachments,
            maxEntriesPerCall = native.pageLimit or 2,
            maxProjectionsPerCall = 1,
            playerDistanceMetrics = true,
            worldOffsets = native.worldOffsets ~= false,
            occlusion = false,
            fallenRetentionSeconds = 60,
            fallenCapacity = 4096,
            livingCapacity = 4096,
        }
        native.capabilitySnapshot = caps
        return caps
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
        local kinds, states, entries = {}, {}, {}
        for _, kind in ipairs(query.kinds) do
            kinds[kind], native.queryKinds[kind] = true, true
        end
        for _, state in ipairs(query.states) do
            assert(state == "present" or state == "alive" or state == "downed", "query used a draft state")
            states[state] = true
        end
        native.lastKinds = kinds
        for _, entry in ipairs(native.entries) do
            if kinds[entry.kind] and states[entry.state] then table.insert(entries, entry) end
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
            streamId = native.stream,
            clockSeconds = c.now,
            overflowed = native.overflowed == true,
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
        if native.projectionError then return nil, { code = native.projectionError } end
        local id, attachment = requests[1].anchorId, requests[1].attachment
        for key in pairs(requests[1]) do
            assert(key == "anchorId" or key == "attachment" or key == "offset", "marker requested unsupported options")
        end
        local source
        for _, entry in ipairs(native.entries) do
            if entry.anchorId == id then source = entry end
        end
        local entry = {
            anchorId = id,
            attachment = attachment,
            state = source and source.projectState or "expired",
            reason = not source and "collected" or nil,
        }
        if source then
            local expected = (source.kind == "cache" or source.kind == "downedPartyMember") and "position" or "overhead"
            assert(attachment == expected, "consumer requested an unsupported entity attachment")
            local offset = requests[1].offset
            if source.kind == "cache" or source.kind == "downedPartyMember" then
                assert(native.worldOffsets ~= false, "position icon requested unadvertised world offsets")
                assert(type(offset) == "table" and offset.z == 5 and offset.x == nil and offset.y == nil)
                for axis in pairs(offset) do
                    assert(axis == "z", "position icon shifted along another world axis")
                end
                if native.positionOffset then
                    assert(offset == native.positionOffset, "cache and ally offsets were not shared across frames")
                end
                native.positionOffset = offset
            else
                assert(offset == nil, "shared request slot leaked position-icon height to an encounter")
            end
            local supported = false
            for _, offered in ipairs(source.attachments) do
                if offered == attachment then supported = true end
            end
            if not supported then
                entry.state, entry.reason = "unavailable", "unsupportedAttachment"
            end
        end
        if entry.state ~= "expired" and entry.state ~= "unknownAnchor" and entry.state ~= "worldChanged" then
            entry.entityState = source and source.state
        end
        if entry.state == "onScreen" then
            entry.x, entry.y = source.x or 100, source.y or 200
            if requests[1].offset then entry.y = entry.y + requests[1].offset.z * (native.heightProjection or 16) end
            entry.cameraDistance, entry.cameraDepth, entry.uiUnitsPerYard = 20, 20, 16
            entry.playerDistance = 20
        end
        local batch = {
            apiVersion = 1,
            worldId = native.world,
            streamId = native.stream,
            cameraSampleId = "camera:" .. native.frame,
            clockSeconds = c.now,
            frameCurrent = native.frameCurrent ~= false,
            entries = { entry },
        }
        if native.projectFault then native.projectFault(batch) end
        return batch
    end
    local getDisplay = env.DFRL.display.Get
    env.DFRL.display.Get = function(key)
        native.optionReads = (native.optionReads or 0) + 1
        return getDisplay(key)
    end
    c:Load("core/world_marker_api.lua")
    c.api = env.T.NewWorldMarkerApi({
        WorldPosition = function()
            assert(native.inService, "marker projection repeated the native player-position getter")
            native.positionReads = (native.positionReads or 0) + 1
            return position
        end,
        Phase = function()
            assert(native.inService, "marker callback repeated the native phase getter")
            native.phaseReads = (native.phaseReads or 0) + 1
            return "playing"
        end,
        HasParty = function() return native.partyPresent ~= false end,
        NeedsPartyMarker = function() return native.downedPresent ~= false end,
        IsRunPhase = function() return true end,
    })
    env.DFRL.display.Listen(c.api.UpdateOptions)
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
        state = kind == "cache" and "present" or (kind == "downedPartyMember" and "downed" or "alive"),
        attachments = (kind == "cache" or kind == "downedPartyMember") and { "position" } or { "position", "overhead" },
        positionAvailable = true,
        x = 100,
        y = 200,
        z = 0,
        mapId = 0,
        spaceId = "instance",
        runId = "run",
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
        not c.writes.SetPoint
            and not c.writes.SetTexture
            and not c.writes.Show
            and not c.writes.Hide
            and not c.writes.SetWidth
            and not c.writes.SetHeight,
        "unchanged projection rewrote static presentation"
    )
    native.entries[1].x = 300
    c:Frame()
    assert(c.writes.SetPoint, "camera movement did not move a marker")
    native.entries[1].projectState = "behindCamera"
    c:Frame()
    assert(#c:Markers() == 1, "behind-camera icon remained visible")
    native.entries[1].projectState = "onScreen"
    native.entries[1].projectState = "unavailable"
    c:Frame()
    assert(#c:Markers() == 1, "unavailable icon remained visible")
    native.entries[1].projectState = "onScreen"
    local visibleBefore = #c:Markers()
    display.Set("worldBossIcons", true)
    local discoveryReads = native.calls
    c:Service()
    assert(
        native.calls - discoveryReads == 2 and #c:Markers() == visibleBefore,
        "catalog did not complete inside one frame while retaining existing markers"
    )
    c:Frame()
    assert(#c:Markers() == 3, "same-frame pagination omitted a boss")
    for _, marker in ipairs(c:Markers()) do
        local raised = marker.kind == "cache" or marker.kind == "downedPartyMember"
        local expectedY = raised and 280 or 206
        local expectedSize = raised and 22.4 or 32
        assert(marker.point[5] == expectedY, "marker ignored native world offset or used incorrect screen padding")
        assert(marker:GetWidth() == expectedSize and marker:GetHeight() == expectedSize, "incorrect world-icon size")
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
-- Cache/ally height is projected by the provider, and mixed-kind pool reuse must
-- restore each icon's geometry without adding repeated size writes or queries.
for _, performance in ipairs({ false, true }) do
    local c = Scene(performance)
    local native = c.native
    native.entries = { Record("small-cache", "cache") }
    c:Service()
    c:Frame()
    local marker = c:Markers()[1]
    assert(marker:GetWidth() == 22.4 and marker:GetHeight() == 22.4 and marker.point[5] == 280)
    local objects, calls, capabilities = #c.objects, native.calls, native.capabilityReads
    c:ResetCounts()
    c:Frame()
    assert(not c.writes.SetWidth and not c.writes.SetHeight and not c.writes.SetPoint, "settled cache rewrote geometry")
    native.heightProjection = 8
    c:Frame()
    assert(marker.point[5] == 240 and marker:GetWidth() == 22.4, "cache height substituted a fixed screen gap")
    assert(native.calls == calls and native.capabilityReads == capabilities, "cache height added metadata queries")
    native.entries = { Record("pooled-ally", "downedPartyMember") }
    c:Service(0.21)
    c:ResetCounts()
    c:Frame()
    assert(
        c:Markers()[1] == marker and marker:GetWidth() == 22.4 and marker:GetHeight() == 22.4 and marker.point[5] == 240,
        "fallen ally failed to match cache size and world height"
    )
    assert(not c.writes.SetWidth and not c.writes.SetHeight, "same-size cache/ally reuse rewrote dimensions")
    native.entries = { Record("pooled-boss", "boss") }
    c.env.DFRL.display.Set("worldBossIcons", true)
    c:Service(0.21)
    c:Frame()
    assert(c:Markers()[1] == marker and marker:GetWidth() == 32 and marker.point[5] == 206)
    native.entries = { Record("pooled-cache", "cache") }
    c:Service(0.21)
    c:Frame()
    assert(
        c:Markers()[1] == marker and marker:GetWidth() == 22.4 and marker:GetHeight() == 22.4 and marker.point[5] == 240,
        "mixed-kind pool failed to restore the smaller raised cache"
    )
    assert(#c.objects == objects and native.registers == 1, "cache styling rebuilt the pool or native owner")
    c.api.Reset()

    local unsupported = Scene(performance)
    unsupported.native.worldOffsets = false
    unsupported.env.DFRL.display.Set("worldBossIcons", true)
    unsupported.native.entries = {
        Record("no-height", "cache"),
        Record("ally", "downedPartyMember"),
        Record("boss", "boss"),
    }
    unsupported:Service()
    unsupported:Frame()
    assert(
        #unsupported:Markers() == 1
            and not unsupported.native.queryKinds.cache
            and not unsupported.native.queryKinds.downedPartyMember
            and unsupported.native.queryKinds.boss,
        "unadvertised offsets drew misplaced cache/ally icons or hid encounter icons"
    )
    unsupported.api.Reset()
end
-- Camera-frame affordability changes gate caches without discovery or rebinding.
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
    native.entries[1].attachments = {}
    c:Frame()
    assert(#c:Markers() == 2, "unsupported attachment reused stale screen coordinates")
    native.entries[1].attachments = { "position" }
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
-- Released contract: list capabilities/attachments, present caches, no catalog
-- anchorStatus, and explicit stream/overflow/terminal-handle fences.
for _, performance in ipairs({ false, true }) do
    local released = Scene(performance)
    local rn = released.native
    rn.entries = { Record("old-cache", "cache"), Record("old-ally", "downedPartyMember") }
    assert(rn.entries[1].anchorStatus == nil and rn.entries[1].state == "present")
    released:Service()
    released:Frame()
    assert(#released:Markers() == 2, "released catalog without draft readiness fields failed to draw")
    assert(rn.capabilitySnapshot.maxEntriesPerRead == nil and rn.capabilitySnapshot.maxAnchorsPerRead == nil)
    local objects, registrations, projections = #released.objects, rn.registers, rn.projections
    rn.discoveryFault = function() return "STREAM_CHANGED" end
    released:Service(0.21)
    assert(#released:Markers() == 0, "discovery STREAM_CHANGED retained old markers")
    released:Frame()
    assert(rn.projections == projections and rn.registers == registrations and rn.unregisters == 0)
    rn.discoveryFault = nil
    rn.stream = "next-stream"
    rn.entries = { Record("new-cache", "cache"), Record("new-ally", "downedPartyMember") }
    released:Service(0.11)
    released:Frame()
    assert(#released:Markers() == 2 and #released.objects == objects and rn.registers == registrations)
    rn.projectFault = function(batch) batch.streamId = "another-stream" end
    released:Frame()
    assert(#released:Markers() == 0, "projection stream change reused old-world presentation")
    projections = rn.projections
    released:Frame()
    assert(rn.projections == projections, "retired stream kept projecting old handles")
    rn.projectFault = nil
    released:Service()
    released:Frame()
    assert(#released:Markers() == 2 and #released.objects == objects and rn.registers == registrations)
    rn.projectionError = "STREAM_CHANGED"
    released:Frame()
    assert(#released:Markers() == 0, "projection STREAM_CHANGED error retained old markers")
    rn.projectionError = nil
    released:Service()
    released:Frame()
    assert(#released:Markers() == 2 and rn.unregisters == 0 and rn.handlers[rn.foreign])
    released.api.Reset()

    local pages = Scene(performance)
    local pn = pages.native
    pn.entries = { Record("kept", "cache") }
    pages:Service()
    pages:Frame()
    objects = #pages.objects
    pages.env.DFRL.display.Set("worldBossIcons", true)
    pn.entries[2], pn.entries[3] = Record("partial-ally", "downedPartyMember"), Record("partial-boss", "boss")
    pn.pageFault = function(page, cursor)
        if cursor then page.streamId = "changed-mid-page" end
    end
    pages:Service(0.21)
    pages:Frame()
    assert(#pages:Markers() == 0 and #pages.objects == objects and pn.registers == 1, "mixed streams published a page")
    pn.pageFault = nil
    pages:Service(0.11)
    pages:Frame()
    assert(#pages:Markers() == 3, "complete released catalog failed after mixed-stream rejection")
    pn.overflowed = true
    pn.entries[4] = Record("overflow-cache", "cache")
    objects = #pages.objects
    pages:Service(0.21)
    pages:Frame()
    assert(#pages:Markers() == 3 and #pages.objects == objects, "overflowed catalog published incomplete replacement")
    pn.overflowed = false
    pages:Service(0.51)
    pages:Frame()
    assert(#pages:Markers() == 4, "complete catalog failed to recover after overflow")
    pn.pageFault = function(page) page.clockSeconds = nil end
    pages:Service(0.21)
    pages:Frame()
    assert(#pages:Markers() == 4, "malformed catalog header discarded accepted handles")
    pn.pageFault = nil
    pages.api.Reset()

    for _, terminal in ipairs({ "expired", "unknownAnchor" }) do
        local retired = Scene(performance)
        local tn = retired.native
        tn.entries = { Record("terminal", "cache") }
        retired:Service()
        retired:Frame()
        tn.entries[1].projectState = terminal
        retired:Frame()
        assert(#retired:Markers() == 0, "terminal projection remained visible")
        projections = tn.projections
        for _ = 1, 60 do
            retired:Frame()
        end
        assert(tn.projections == projections, "terminal handle flooded unnecessary frame projections")
        retired.api.Reset()
    end
    for _, fault in ipairs({
        function(caps) caps.frameProjection = false end,
        function(caps) caps.kinds = { cache = true } end,
        function(caps) caps.attachments = { position = true } end,
    }) do
        local unsupported = Scene(performance)
        local getter = unsupported.env.AZS_GetWorldAnchorCapabilities
        unsupported.env.AZS_GetWorldAnchorCapabilities = function()
            local caps = getter()
            fault(caps)
            return caps
        end
        unsupported:Service()
        assert(
            unsupported.native.registers == 0 and unsupported.native.calls == 0,
            "incomplete or draft capability shape activated the released consumer"
        )
        unsupported.api.Reset()
    end
end
-- Request budgets: disabled/hidden/no-demand consumers stay quiet; camera frames
-- project only eligible cached handles and never repeat phase/position/capability reads.
for _, performance in ipairs({ false, true }) do
    local quiet = Scene(performance)
    local qn, qd = quiet.native, quiet.env.DFRL.display
    qn.partyPresent = false
    qd.Set("worldCacheAffordableOnly", true)
    quiet.env.AZS_RUN, quiet.env.AZS_RUN_UPDATED = { gold = 0, chest = 10 }, 1
    qn.entries = { Record("cache", "cache") }
    for _ = 1, 40 do
        quiet:Service(0.1)
        quiet:Frame()
    end
    assert(
        qn.calls == 0 and not qn.capabilityReads and not qn.positionReads and not qn.phaseReads and qn.registers == 0,
        "unaffordable solo markers retained native requests"
    )
    quiet.env.AZS_RUN.gold = 10
    quiet:Service()
    quiet:Frame()
    assert(#quiet:Markers() == 1 and qn.calls == 1 and qn.capabilityReads == 1 and qn.registers == 1)
    local objects, calls, positions, phases, capabilities =
        #quiet.objects, qn.calls, qn.positionReads, qn.phaseReads, qn.capabilityReads
    local optionReads = qn.optionReads
    for _ = 1, 60 do
        quiet:Frame()
    end
    assert(qn.optionReads == optionReads, "marker frames re-read saved options")
    assert(
        qn.calls == calls
            and qn.positionReads == positions
            and qn.phaseReads == phases
            and qn.capabilityReads == capabilities,
        "camera frames repeated metadata/discovery reads"
    )
    quiet:Service(0.05)
    assert(qn.calls == calls and qn.positionReads == positions, "gated discovery still read player position")
    quiet.env.AZS_RUN.gold = 0
    quiet:Service()
    calls, positions, phases = qn.calls, qn.positionReads, qn.phaseReads
    optionReads = qn.optionReads
    for _ = 1, 20 do
        quiet:Service(0.1)
        quiet:Frame()
    end
    assert(qn.optionReads == optionReads, "quiet marker controller re-read saved options")
    assert(
        qn.calls == calls
            and qn.positionReads == positions
            and qn.phaseReads == phases
            and qn.registers == 1
            and qn.unregisters == 0,
        "hidden affordable-only cache lost its quiet cached owner"
    )
    quiet.env.AZS_RUN.gold = 10
    quiet:Service()
    quiet:Frame()
    assert(
        #quiet:Markers() == 1 and #quiet.objects == objects and qn.registers == 1 and qn.capabilityReads == capabilities,
        "affordability recovery rebuilt cached metadata/markers"
    )
    qd.Set("worldCacheIcons", false)
    qd.Set("worldBossIcons", false)
    qd.Set("worldPartyIcons", false)
    quiet:Service()
    calls, positions, phases, capabilities = qn.calls, qn.positionReads, qn.phaseReads, qn.capabilityReads
    for _ = 1, 20 do
        quiet:Service(0.1)
        quiet:Frame()
    end
    assert(
        qn.calls == calls
            and qn.positionReads == positions
            and qn.phaseReads == phases
            and qn.capabilityReads == capabilities,
        "disabled markers retained native requests"
    )
    quiet.api.Reset()

    local alive = Scene(performance)
    alive.native.downedPresent = false
    alive.env.DFRL.display.Set("worldCacheIcons", false)
    for _ = 1, 20 do
        alive:Service(0.1)
        alive:Frame()
    end
    assert(
        alive.native.calls == 0 and not alive.native.capabilityReads and not alive.native.positionReads,
        "known empty downed feed retained duplicate world discovery"
    )
    alive.native.downedPresent = true
    alive.native.entries = { Record("new-ally", "downedPartyMember") }
    alive:Service()
    alive:Frame()
    assert(#alive:Markers() == 1 and alive.native.calls == 1, "new downed presence failed to wake marker demand")
    alive.api.Reset()

    local hidden = Scene(performance)
    hidden.env.WorldFrame.parent = nil -- Native WorldFrame need not inherit UIParent hiding.
    hidden.env.UIParent:Hide()
    for _ = 1, 20 do
        hidden:Service(0.1)
        hidden:Frame()
    end
    assert(
        hidden.native.calls == 0
            and not hidden.native.capabilityReads
            and not hidden.native.positionReads
            and hidden.native.registers == 0,
        "hidden UIParent retained world-marker reads"
    )
    hidden.env.UIParent:Show()
    hidden.native.entries = { Record("visible-cache", "cache") }
    hidden:Service()
    hidden:Frame()
    assert(#hidden:Markers() == 1)
    hidden.env.UIParent:Hide()
    local projections = hidden.native.projections
    for _ = 1, 60 do
        hidden:Frame() -- A hidden UIParent may also stop the shared controller.
    end
    assert(hidden.native.projections == projections and #hidden:Markers() == 0, "hidden root retained frame requests")
    hidden:Service()
    assert(hidden.native.unregisters == 1, "shared service did not release hidden marker ownership")
    hidden.api.Reset()

    local split = Scene(performance)
    local sn, sd = split.native, split.env.DFRL.display
    sd.Set("worldCacheAffordableOnly", true)
    split.env.AZS_RUN, split.env.AZS_RUN_UPDATED = { gold = 0, chest = 10 }, 1
    sn.entries = { Record("cache", "cache"), Record("ally", "downedPartyMember") }
    split:Service()
    split:Frame()
    assert(
        #split:Markers() == 1 and not sn.lastKinds.cache and sn.lastKinds.downedPartyMember,
        "unaffordable caches remained in another kind's discovery request"
    )
    split.env.AZS_RUN.gold = 10
    split:Service(0.21)
    split:Frame()
    assert(#split:Markers() == 2 and sn.lastKinds.cache)
    objects = #split.objects
    split.env.AZS_RUN.gold = 0
    split:Service(0.21)
    split:Frame()
    assert(
        #split:Markers() == 1 and not sn.lastKinds.cache and sn.registers == 1,
        "per-kind suspension retained cache reads or rebound the callback"
    )
    split.env.AZS_RUN.gold = 10
    split:Service(0.21)
    split:Frame()
    assert(
        #split:Markers() == 2 and #split.objects == objects and sn.capabilityReads == 1,
        "per-kind discovery discarded the dormant cache pool"
    )
    sn.partyPresent = false
    split:Service(0.21)
    split:Frame()
    assert(
        #split:Markers() == 1 and sn.lastKinds.cache and not sn.lastKinds.downedPartyMember,
        "no-party world icons remained in discovery/projection"
    )
    split.api.Reset()

    local empty = Scene(performance)
    empty.native.partyPresent = false
    empty:Service()
    local en = empty.native
    calls, positions, phases, capabilities = en.calls, en.positionReads, en.phaseReads, en.capabilityReads
    for _ = 1, 60 do
        empty:Frame()
    end
    assert(
        en.calls == calls
            and en.positionReads == positions
            and en.phaseReads == phases
            and en.capabilityReads == capabilities
            and not en.projections,
        "empty catalog retained frame API work"
    )
    empty.api.Reset()
    empty:Service()
    assert(en.capabilityReads == capabilities, "same-provider capability cache was not reused")
    en.capabilitySnapshot.kinds[1] = "unrecognizedKind"
    empty.api.Reset()
    empty:Service()
    assert(en.calls == calls + 2, "returned capability table mutated the copied cache")
    empty.now = empty.now + 31
    empty.api.Reset()
    empty:Service()
    assert(en.capabilityReads == capabilities + 1, "capability cache failed to refresh at a later activation")
    empty.api.Reset()

    local retry = Scene(performance)
    retry.native.entries = { Record("cache", "cache") }
    retry:Service()
    retry:Frame()
    local rn = retry.native
    calls = rn.calls
    rn.discoveryFault = function() return "NOT_READY" end
    for _ = 1, 50 do
        retry:Service(0.1)
        retry:Frame()
    end
    assert(
        rn.calls - calls >= 3
            and rn.calls - calls <= 7
            and #retry:Markers() == 1
            and rn.registers == 1
            and rn.unregisters == 0,
        "persistent discovery failure flooded requests or lost cached handles"
    )
    rn.discoveryFault = nil
    retry:Service(8.1)
    retry:Frame()
    assert(#retry:Markers() == 1)
    rn.discoveryFault = function() return "NOT_READY" end
    retry:Service(0.21)
    calls = rn.calls
    retry:Service(0.11)
    assert(rn.calls == calls + 1, "successful discovery did not restore the short first retry")
    rn.releaseFault = true
    retry.env.DFRL.display.Set("worldCacheIcons", false)
    retry.env.DFRL.display.Set("worldBossIcons", false)
    retry.env.DFRL.display.Set("worldPartyIcons", false)
    local releases = rn.unregisters
    retry:Service()
    for _ = 1, 4 do
        retry:Service(0.1)
        retry:Frame()
    end
    assert(rn.unregisters == releases + 1, "failed callback release retried at controller speed")
    rn.releaseFault = false
    retry:Service(0.51)
    assert(rn.unregisters == releases + 2 and rn.handlers[rn.foreign], "throttled callback release failed to recover")
    retry.api.Reset()

    local unavailable = Scene(performance)
    unavailable.env.AZS_GetWorldAnchorCapabilities = function()
        unavailable.native.capabilityReads = (unavailable.native.capabilityReads or 0) + 1
        return nil, { code = "NOT_READY" }
    end
    for _ = 1, 100 do
        unavailable:Service(0.1)
        unavailable:Frame()
    end
    assert(
        unavailable.native.capabilityReads >= 3
            and unavailable.native.capabilityReads <= 6
            and unavailable.native.calls == 0
            and not unavailable.native.positionReads
            and unavailable.native.registers == 0,
        "unavailable capabilities flooded reads or started gameplay work"
    )
    unavailable.api.Reset()
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
