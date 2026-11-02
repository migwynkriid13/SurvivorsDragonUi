-- CI only: exact production cache/reader functions over fake native tooltip boundaries.
assert(_VERSION == "Lua 5.1", "jewelry cache fixtures require CI Lua 5.1")
local env = setmetatable({}, { __index = _G })
env._G = env
env.DFRL = { locale = { code = "en" } }
env.SCANNER_NAME = "PrivateJewelryScanner"
env.scannerParent = {}
env.slots = { { id = 11 }, { id = 12 } }
local link, description, scans, hasItem = "item:first", "Equip: +12% chance", 0, true
local order = {}
local function Note(value) table.insert(order, value) end
local scanner = {}
function scanner:SetOwner(parent, anchor)
    assert(parent == env.scannerParent and anchor == "ANCHOR_NONE", "reader used another tooltip owner")
    Note("owner")
end
function scanner:ClearLines() Note("clear") end
function scanner:SetInventoryItem(unit, slot)
    assert(unit == "player" and (slot == 11 or slot == 12))
    Note("inventory")
    scans = scans + 1
    if hasItem == "throw" then error("native item pending") end
    return hasItem
end
function scanner:NumLines() return 2 end
function scanner:Hide() Note("hide") end
env.PrivateJewelryScannerTextLeft2 = { GetText = function() return description end }
env.GetScanner = function() return scanner end
env.GetInventoryItemLink = function()
    if link == "throw" then error("link pending") end
    return link
end
-- Effect formatting has separate production-template coverage; this boundary
-- exposes a complete native effect or unavailable rows to the real cache.
env.EffectDescription = function(text) return text and string.match(text, "^Equip: (.+)$") end
env.SetQuality = function(slot) slot.quality = nil end
env.HideTooltip = function(slot) slot.hidden = true end
for _, slot in ipairs(env.slots) do
    slot.placeholder = { Hide = function() end }
    slot.cooldown = { Hide = function() end }
end
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
local api = chunk()
local slot = env.slots[1]
assert(api.ReadEffects(slot) == "+12% chance" and scans == 1)
assert(table.concat(order, ",") == "owner,clear,inventory,hide", "fresh scan changed native ownership order")
for _ = 1, 5 do
    assert(api.ReadEffects(slot) == "+12% chance")
end
assert(scans == 1, "unchanged successful description rebuilt native tooltip")
link, description = "item:second", "Equip: +37% chance"
assert(api.ReadEffects(slot) == "+37% chance" and scans == 2, "same-icon item replacement retained old text")
description = "Equip: +41% chance"
api.InvalidateEffects()
assert(api.ReadEffects(slot) == "+41% chance" and scans == 3, "inventory invalidation reused old text")
env.DFRL.locale.code, description = "fr", "Equip: +53% chance"
assert(api.ReadEffects(slot) == "+53% chance" and scans == 4, "language invalidation reused old text")
assert(api.ReadEffects(env.slots[2]) == "+53% chance" and scans == 5, "cache crossed inventory slots")
api.ClearSlot(slot)
assert(not slot.effectLink and not slot.effectDescription and slot.hidden, "slot retirement retained cache")
assert(api.ReadEffects(slot) == "+53% chance" and scans == 6)
link, description, hasItem = "item:pending", nil, false
assert(api.ReadEffects(slot) == nil and not slot.effectDescription)
hasItem = true
assert(api.ReadEffects(slot) == nil and not slot.effectDescription, "empty native rows were cached forever")
description = "Equip: ready later"
assert(api.ReadEffects(slot) == "ready later", "pending metadata did not recover")
link, hasItem = "item:failure", "throw"
assert(api.ReadEffects(slot) == nil and not slot.effectDescription, "failed scan reused preceding item")
hasItem, description = true, "Equip: recovered"
assert(api.ReadEffects(slot) == "recovered")
for _, missing in ipairs({ "throw", false }) do
    if missing == false then
        link = nil
    else
        link = missing
    end
    description = "Equip: uncached first"
    assert(api.ReadEffects(slot) == "uncached first")
    description = "Equip: uncached next"
    assert(api.ReadEffects(slot) == "uncached next" and not slot.effectDescription, "invalid link froze presentation")
end
api.InvalidateEffects()
for _, entry in ipairs(env.slots) do
    assert(not entry.effectLink and not entry.effectLanguage and not entry.effectDescription)
end
-- The real compositor receives authored parts and native texture objects.
-- Changing equipment must reuse its groups/regions without changing those parts.
env.iconGroups, env.iconByTexture, env.iconPool = {}, {}, {}
env.iconParts = {
    { left = 3, top = 2, width = 26, firstU = 0.1, lastU = 0.9, firstV = 0.1, lastV = 0.2 },
    { left = 1, top = 4, width = 30, firstU = 0.05, lastU = 0.95, firstV = 0.2, lastV = 0.3 },
}
local textureWrites, regions = 0, {}
local methods = {}
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown end
function methods:SetTexture(value)
    textureWrites = textureWrites + 1
    self.texture = value
end
function methods:ClearAllPoints() self.point = nil end
function methods:SetPoint(...) self.point = { ... } end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetTexCoord(...) self.uv = { ... } end
env.artwork = {
    CreateTexture = function()
        local region = setmetatable({}, { __index = methods })
        table.insert(regions, region)
        return region
    end,
}
for index, entry in ipairs(env.slots) do
    entry.button, entry.artTexture = {}, "icon:" .. index
end
env.iconsDirty = true
api.PaintIcons()
assert(#regions == 4 and #env.iconGroups == 2, "compositor did not allocate only its required parts")
local groups = { env.iconGroups[1], env.iconGroups[2] }
local function CheckParts()
    for _, region in ipairs(regions) do
        if region:IsShown() then
            local part, entry = region.jewelryPart, region.jewelrySlot
            assert(region.texture == entry.artTexture and region.point[2] == entry.button)
            assert(region.width == part.width and region.height == 2)
            assert(region.uv[1] == part.firstU and region.uv[2] == part.lastU)
            assert(region.uv[3] == part.firstV and region.uv[4] == part.lastV)
        end
    end
end
CheckParts()
textureWrites = 0
api.PaintIcons()
assert(textureWrites == 0 and #regions == 4, "settled icons repeated native work")
env.slots[1].artTexture, env.slots[2].artTexture = "shared:icon", "shared:icon"
env.iconsDirty = true
api.PaintIcons()
CheckParts()
assert(#regions == 4 and env.iconGroups[1] == groups[1] and env.iconGroups[2] == groups[2])
assert(env.iconGroups[2].texture == nil and env.iconGroups[2].slots[1] == nil, "unused group retained old art/slot")
for _, entry in ipairs(env.slots) do
    entry.artTexture = nil
end
env.iconsDirty = true
api.PaintIcons()
for _, region in ipairs(regions) do
    assert(
        not region:IsShown() and not region.texture and not region.jewelrySlot,
        "retired icon retained drawing state"
    )
end
env.slots[1].artTexture, env.slots[2].artTexture = "new:one", "new:two"
env.iconsDirty = true
api.PaintIcons()
CheckParts()
assert(
    #regions == 4 and env.iconGroups[1] == groups[1] and env.iconGroups[2] == groups[2],
    "equipment churn grew pools"
)
print("PASS jewelry description cache preserves identity, language, retirement, native ownership and retries")
print("PASS jewelry compositor retains authored parts, grouped order, lazy regions and reusable scratch groups")
