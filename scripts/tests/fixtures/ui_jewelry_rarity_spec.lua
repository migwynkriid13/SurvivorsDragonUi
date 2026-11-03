-- CI only: exact production rarity helpers over fake native boundaries.
assert(_VERSION == "Lua 5.1", "jewelry rarity fixtures require CI Lua 5.1")
local env = setmetatable({}, { __index = _G })
env._G = env
local visible = true
local writes = { color = 0, uv = 0 }
local methods = {}
function methods:SetVertexColor(...)
    writes.color = writes.color + 1
    self.color = { ... }
end
function methods:SetTexCoord(...)
    writes.uv = writes.uv + 1
    self.uv = { ... }
end
local function Region() return setmetatable({ uv = { 256 / 512, 384 / 512, 0, 1 } }, { __index = methods }) end
env.hud = { IsVisible = function() return visible end }
env.overlay = { CreateTexture = function() error("rarity must not allocate a drawing layer") end }
env.performanceMode, env.editing = false, false
env.slots = {}
for index = 1, 5 do
    env.slots[index] = { id = index, carving = Region() }
end
local quality, red, green, blue = 2, 0.12, 1, 0
env.GetInventoryItemQuality = function(unit, id)
    assert(unit == "player" and id >= 1 and id <= 5)
    return quality
end
env.GetItemQualityColor = function(value)
    assert(value == quality)
    return red, green, blue
end
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
local api = chunk()
local slot = env.slots[1]
local function Color(region, r, g, b)
    assert(math.abs(region.color[1] - r) < 0.000001)
    assert(math.abs(region.color[2] - g) < 0.000001)
    assert(math.abs(region.color[3] - b) < 0.000001 and region.color[4] == 1)
end
local function OriginalHousing(region)
    assert(region.uv[1] == 256 / 512 and region.uv[2] == 384 / 512)
    assert(region.uv[3] == 0 and region.uv[4] == 1)
end
api.Update(slot)
Color(slot.carving, 1, 1, 1)
slot.texture = "native:item"
api.Quality(slot)
api.Update(slot)
Color(slot.carving, 0.692, 1, 0.65)
OriginalHousing(slot.carving)
local colors = writes.color
for _ = 1, 10 do
    api.Update(slot)
end
assert(writes.color == colors and writes.uv == 0, "settled rarity repeated color or crop writes")
for _, state in ipairs({ "performanceMode", "editing" }) do
    env[state] = true
    api.Update(slot)
    Color(slot.carving, 0.692, 1, 0.65)
    env[state] = false
    api.Update(slot)
end
assert(writes.color == colors and writes.uv == 0, "mode changes altered the static rarity treatment")
-- Hidden recoloring waits for Show and retains the same default housing.
visible = false
quality, red, green, blue = 4, 0.64, 0.21, 0.93
api.Quality(slot)
api.Update(slot)
assert(writes.color == colors and writes.uv == 0, "hidden rarity painted early")
visible = true
api.Update(slot)
Color(slot.carving, 0.874, 0.7235, 0.9755)
OriginalHousing(slot.carving)
for _, rank in ipairs({ 0, 1 }) do
    quality, red, green, blue = rank, 0.62 + rank * 0.38, 0.62 + rank * 0.38, 0.62 + rank * 0.38
    api.Quality(slot)
    api.Update(slot)
    local value = rank == 0 and 0.867 or 1
    Color(slot.carving, value, value, value)
end
quality = nil
api.Quality(slot)
api.Update(slot)
assert(not slot.qualityR)
Color(slot.carving, 1, 1, 1)
quality, red = 5, 2
api.Quality(slot)
api.Update(slot)
assert(not slot.qualityR, "invalid RGB retained previous rarity")
Color(slot.carving, 1, 1, 1)
-- Preserve the selected rare-blue accent without changing raw tooltip RGB.
quality, red, green, blue = 3, 0, 0.44, 0.87
for _, entry in ipairs(env.slots) do
    entry.texture = "native:item"
    api.Quality(entry)
    api.Update(entry)
    Color(entry.carving, 0.79, 0.93, 1)
    OriginalHousing(entry.carving)
    assert(entry.qualityR == red and entry.qualityG == green and entry.qualityB == blue)
end
slot.texture = nil
api.Update(slot)
Color(slot.carving, 1, 1, 1)
colors = writes.color
api.Update(slot)
assert(writes.color == colors, "settled empty slot repainted its housing")
slot.texture = "native:return"
api.Quality(slot)
api.Update(slot)
Color(slot.carving, 0.79, 0.93, 1)
visible, slot.texture = false, nil
colors = writes.color
api.Update(slot)
assert(writes.color == colors, "hidden empty transition painted early")
visible = true
api.Update(slot)
Color(slot.carving, 1, 1, 1)
assert(writes.uv == 0, "rarity rebound the original housing crop")
print("PASS original jewelry housing retains neutral empty slots and restrained equipped rarity tint")
print("PASS rarity keeps raw native RGB, changed-only writes, hidden recovery and identical mode appearance")
