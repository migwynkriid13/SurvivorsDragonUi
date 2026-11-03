-- CI only: production jewelry refresh/retirement over explicit native boundaries.
assert(_VERSION == "Lua 5.1", "jewelry visibility fixtures require CI Lua 5.1")

local function Run(performanceMode)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.performanceMode = performanceMode
    local writes = { show = 0, hide = 0 }
    local methods = {}
    local function Region() return setmetatable({ shown = false }, { __index = methods }) end
    function methods:Show()
        writes.show = writes.show + 1
        self.shown = true
    end
    function methods:Hide()
        writes.hide = writes.hide + 1
        self.shown = false
    end
    local enabled, visible, player, docked = true, true, true, true
    local textures, reads, qualityReads = {}, 0, 0
    local rarityUpdates, retirements = 0, 0
    env.slots = {}
    for index = 1, 5 do
        textures[index] = "native:item:" .. index
        env.slots[index] = {
            id = index,
            placeholder = Region(),
            placeholderShown = false,
            carvingPending = true,
        }
    end
    env.inWorld, env.attached, env.shownWanted, env.wantedDocked, env.cleared = true, true, true, true, false
    env.DFRL = {
        display = {
            Get = function(key)
                assert(key == "equippedJewelry")
                return enabled
            end,
        },
    }
    env.hud = { Show = function() end, Hide = function() end, IsVisible = function() return visible end }
    env.detached = { Show = function() end, Hide = function() end }
    env.Docked = function() return docked end
    env.CanPaint = function() return visible end
    env.UnitExists = function(unit)
        assert(unit == "player")
        return player
    end
    env.ResolveSlots = function() return true end
    env.GetInventoryItemTexture = function(unit, id)
        assert(unit == "player")
        reads = reads + 1
        if textures[id] == "throw" then error("native inventory pending") end
        return textures[id]
    end
    env.SetIcon = function(slot, texture)
        slot.texture, slot.artTexture, env.iconsDirty = texture, texture, true
    end
    env.UpdateQuality = function() qualityReads = qualityReads + 1 end
    env.SetQuality = function() retirements = retirements + 1 end
    env.UpdateRarity = function(slot)
        rarityUpdates = rarityUpdates + 1
        slot.carvingPending = false
    end
    env.HideTooltip = function() end
    -- Icon geometry, actual rarity and tooltip rendering have separate production fixtures.
    env.iconGroups, env.iconByTexture, env.iconPool, env.iconParts, env.iconsDirty = {}, {}, {}, {}, false
    local chunk = assert(loadfile(arg[1]))
    setfenv(chunk, env)
    local api = chunk()

    for _ = 1, 10 do
        api.Refresh()
    end
    assert(reads == 50 and qualityReads == 50, "native reads lost their refresh cadence")
    assert(rarityUpdates == 5, "unchanged occupied slots repeated rarity preparation")
    assert(writes.show == 0 and writes.hide == 0, "occupied slots repeated visibility writes")
    for index = 1, 5 do
        textures[index] = nil
    end
    api.Refresh()
    assert(writes.show == 5 and writes.hide == 0, "empty slots did not reveal their original placeholders once")
    for _ = 1, 10 do
        api.Refresh()
    end
    assert(writes.show == 5 and writes.hide == 0 and reads == 105, "settled empty slots toggled or stopped retrying")
    assert(qualityReads == 50, "empty slots read unavailable item metadata")
    assert(retirements == 5 and rarityUpdates == 10, "settled empty slots repeated retirement or rarity work")

    local slot = env.slots[1]
    textures[1] = "throw"
    api.Refresh()
    api.Refresh()
    assert(not slot.placeholder.shown and writes.hide == 1, "failed inventory kept stale placeholder art")
    textures[1] = ""
    api.Refresh()
    api.Refresh()
    assert(slot.placeholder.shown and writes.show == 6, "late empty inventory did not recover once")
    textures[1] = 12
    api.Refresh()
    api.Refresh()
    assert(not slot.placeholder.shown and writes.hide == 2, "malformed inventory kept placeholder art")

    textures[1] = "native:returned"
    api.Refresh()
    assert(slot.texture == "native:returned" and not slot.placeholder.shown)
    local shows, hides = writes.show, writes.hide
    textures[1] = nil
    api.Refresh()
    api.Refresh()
    assert(slot.placeholder.shown and not slot.texture)
    assert(writes.show == shows + 1 and writes.hide == hides, "item removal repeated placeholder transitions")

    visible, textures[1] = false, "native:hidden-change"
    local beforeReads = reads
    shows, hides = writes.show, writes.hide
    api.Refresh()
    assert(reads == beforeReads and writes.show == shows and writes.hide == hides)
    visible = true
    api.Refresh()
    assert(reads == beforeReads + 5 and not slot.placeholder.shown, "hidden recovery retained stale placeholder state")

    slot.carvingQuality = 4
    visible, docked = false, false
    local beforeRarity = rarityUpdates
    api.Refresh()
    assert(slot.carvingPending and rarityUpdates == beforeRarity, "docking change painted while hidden")
    visible = true
    api.Refresh()
    assert(not slot.carvingPending and rarityUpdates == beforeRarity + 1, "docking change did not repaint on recovery")

    for _, boundary in ipairs({ "player", "world", "disabled" }) do
        if boundary == "player" then player = false end
        if boundary == "world" then env.inWorld = false end
        if boundary == "disabled" then enabled = false end
        api.Refresh()
        hides = writes.hide
        api.Refresh()
        for _, entry in ipairs(env.slots) do
            assert(not entry.placeholder.shown and not entry.placeholderShown and not entry.texture)
        end
        assert(writes.hide == hides, "retired jewelry repeated visibility writes")
        player, env.inWorld, enabled = true, true, true
        api.Refresh()
        assert(
            not slot.placeholder.shown and env.slots[2].placeholder.shown,
            "retired jewelry did not recover native equipment"
        )
    end
end

Run(false)
Run(true)
print("PASS jewelry changes visibility once across occupied/empty/pending inventory in both modes")
print("PASS jewelry defers hidden work and recovers native equipment after retirement")
