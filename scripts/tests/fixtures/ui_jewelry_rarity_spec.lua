-- CI only: exact production rarity helpers over fake native boundaries.
assert(_VERSION == "Lua 5.1", "jewelry rarity fixtures require CI Lua 5.1")
local env = setmetatable({}, { __index = _G })
env._G = env
env.SHARED_CARVING, env.GEMMED_CARVING = "Frame.blp", "GemmedRunecarver.blp"
env.ATTACHED_CARVING = "AttachedRunecarver.blp"
local visible, unavailable = true, nil
local writes = { texture = 0, uv = 0, visibility = 0 }
local methods = {}
function methods:SetTexture(path)
    writes.texture = writes.texture + 1
    if path == unavailable then return false end
    self.texture = path
end
function methods:GetTexture() return self.texture end
function methods:SetTexCoord(...)
    writes.uv = writes.uv + 1
    self.uv = { ... }
end
function methods:Show()
    writes.visibility = writes.visibility + 1
    self.shown = true
end
function methods:Hide()
    writes.visibility = writes.visibility + 1
    self.shown = false
end
function methods:IsShown() return self.shown end
local function Region() return setmetatable({}, { __index = methods }) end
env.T = {
    TextureAssigned = function(loaded, assigned, wanted) return loaded ~= false and assigned == wanted end,
}
env.hud = { IsVisible = function() return visible end }
env.HideTooltip = function() end
env.overlay = { CreateTexture = function() error("rarity must reuse the housing region") end }
local slot = { id = 1, carving = Region(), carvingPending = true, placeholderShown = false }
local quality, red, green, blue = nil, 0.12, 1, 0
env.GetInventoryItemQuality = function(unit, id)
    assert(unit == "player" and id == 1)
    return quality
end
env.GetItemQualityColor = function(value)
    assert(value == quality)
    return red, green, blue
end
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
local api = chunk()

local function Housing(path, left, row)
    local region = slot.carving
    assert(region.shown and region.texture == path)
    assert(region.uv[1] == left / 512 and region.uv[2] == (left + 128) / 512)
    local top, bottom = 0, 1
    if row then
        top, bottom = row / 2, (row + 1) / 2
    end
    assert(region.uv[3] == top and region.uv[4] == bottom)
end
api.Clear(slot)
Housing(env.SHARED_CARVING, 256)
slot.texture, slot.empty = "native:item", nil
local bindings, crops = writes.texture, writes.uv
for rank = 0, 1 do
    quality = rank
    api.Quality(slot)
    api.Update(slot)
    Housing(env.SHARED_CARVING, 384)
    assert(slot.quality == rank and slot.qualityR == red, "silver artwork lost native tooltip metadata")
end
assert(writes.texture == bindings and writes.uv == crops + 1, "poor and common should share one silver crop")
quality = 6
api.Quality(slot)
api.Update(slot)
Housing(env.SHARED_CARVING, 256)
assert(slot.quality == 6 and slot.qualityR == red, "neutral artwork lost native tooltip metadata")
bindings, crops = writes.texture, writes.uv
for rank = 2, 5 do
    quality = rank
    api.Quality(slot)
    api.Update(slot)
    Housing(env.GEMMED_CARVING, (rank - 2) * 128)
    assert(slot.qualityR == red and slot.qualityG == green and slot.qualityB == blue)
end
assert(writes.texture == bindings + 1 and writes.uv == crops + 4, "gemmed qualities did not reuse one atlas")
bindings, crops = writes.texture, writes.uv
for _, mode in ipairs({ "performanceMode", "editing" }) do
    env[mode] = true
    api.Update(slot)
    Housing(env.GEMMED_CARVING, 384)
    env[mode] = false
    api.Update(slot)
end
assert(writes.texture == bindings and writes.uv == crops, "settled slots repeated bindings or crops")

env.wantedDocked, unavailable = true, env.ATTACHED_CARVING
api.Update(slot)
assert(slot.carvingPending, "failed attached artwork must retry")
Housing(env.SHARED_CARVING, 256)
unavailable = nil
api.Update(slot)
Housing(env.ATTACHED_CARVING, 0, 1)
assert(not slot.carvingPending)
bindings, crops = writes.texture, writes.uv
for rank = 1, 5 do
    quality = rank
    api.Quality(slot)
    api.Update(slot)
    Housing(env.ATTACHED_CARVING, math.mod(rank - 1, 4) * 128, rank == 5 and 1 or 0)
end
assert(writes.texture == bindings and writes.uv == crops + 5, "attached crops did not reuse one atlas")
env.wantedDocked = false
api.Update(slot)
Housing(env.GEMMED_CARVING, 384)

quality, red = 4, 2
api.Quality(slot)
api.Update(slot)
assert(not slot.qualityR)
Housing(env.SHARED_CARVING, 256)

quality, red, unavailable = 4, 0.64, env.GEMMED_CARVING
api.Quality(slot)
api.Update(slot)
assert(slot.carvingPending, "failed gemmed artwork must retry")
Housing(env.SHARED_CARVING, 256)
unavailable = nil
api.Update(slot)
assert(not slot.carvingPending)
Housing(env.GEMMED_CARVING, 256)

visible = false
bindings, crops = writes.texture, writes.uv
local visibility = writes.visibility
api.Clear(slot)
assert(slot.carvingPending and not slot.qualityR and not slot.texture)
assert(writes.texture == bindings and writes.uv == crops and writes.visibility == visibility)
visible = true
api.Clear(slot)
Housing(env.SHARED_CARVING, 256)
bindings, crops = writes.texture, writes.uv
api.Clear(slot)
assert(writes.texture == bindings and writes.uv == crops, "settled empty slot repeated artwork writes")

slot.texture, slot.empty = "native:return", nil
api.Quality(slot)
api.Update(slot)
Housing(env.GEMMED_CARVING, 256)
unavailable = env.SHARED_CARVING
api.Clear(slot)
assert(not slot.carving.shown and slot.carvingPending, "failed neutral return showed stale gemmed artwork")
unavailable = nil
api.Clear(slot)
Housing(env.SHARED_CARVING, 256)
print("PASS Runecarver quality selects the approved gem and halo artwork through one reused housing region")
print("PASS rarity keeps native tooltip RGB, changed-only writes, neutral fallback and hidden recovery")
