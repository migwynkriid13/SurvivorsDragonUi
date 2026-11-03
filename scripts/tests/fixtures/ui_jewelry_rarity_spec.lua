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
env.HideTooltip = function() end
env.performanceMode, env.editing = false, false
env.slots = {}
for index = 1, 5 do
    env.slots[index] = {
        id = index,
        carving = Region(),
        carvingBright = false,
        placeholderShown = false,
    }
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
local function Housing(region, left)
    assert(region.uv[1] == left / 512 and region.uv[2] == (left + 128) / 512)
    assert(region.uv[3] == 0 and region.uv[4] == 1)
end
api.Update(slot)
Color(slot.carving, 1, 1, 1)
Housing(slot.carving, 256)
slot.texture = "native:item"
api.Quality(slot)
api.Update(slot)
Color(slot.carving, 0.472, 1, 0.4)
Housing(slot.carving, 384)
local colors = writes.color
local crops = writes.uv
assert(crops == 1)
for _ = 1, 10 do
    api.Update(slot)
end
assert(writes.color == colors and writes.uv == crops, "settled rarity repeated color or crop writes")
for _, state in ipairs({ "performanceMode", "editing" }) do
    env[state] = true
    api.Update(slot)
    Color(slot.carving, 0.472, 1, 0.4)
    env[state] = false
    api.Update(slot)
end
assert(writes.color == colors and writes.uv == crops, "mode changes altered the static rarity treatment")
-- Hidden recoloring waits for Show and reuses the equipped crop.
visible = false
quality, red, green, blue = 4, 0.64, 0.21, 0.93
api.Quality(slot)
api.Update(slot)
assert(writes.color == colors and writes.uv == crops, "hidden rarity painted early")
visible = true
api.Update(slot)
Color(slot.carving, 0.784, 0.526, 0.958)
assert(writes.uv == crops, "color-only change rebound the equipped crop")
for _, rank in ipairs({ 0, 1 }) do
    quality, red, green, blue = rank, 0.62 + rank * 0.38, 0.62 + rank * 0.38, 0.62 + rank * 0.38
    api.Quality(slot)
    api.Update(slot)
    local value = rank == 0 and 0.772 or 1
    Color(slot.carving, value, value, value)
    Housing(slot.carving, 384)
end
quality = nil
api.Quality(slot)
api.Update(slot)
assert(not slot.qualityR)
Color(slot.carving, 1, 1, 1)
Housing(slot.carving, 256)
quality, red = 5, 2
api.Quality(slot)
api.Update(slot)
assert(not slot.qualityR, "invalid RGB retained previous rarity")
Color(slot.carving, 1, 1, 1)
Housing(slot.carving, 256)
-- Preserve the selected rare-blue accent without changing raw tooltip RGB.
quality, red, green, blue = 3, 0, 0.44, 0.87
for _, entry in ipairs(env.slots) do
    entry.texture = "native:item"
    api.Quality(entry)
    api.Update(entry)
    Color(entry.carving, 0.64, 0.88, 1)
    Housing(entry.carving, 384)
    assert(entry.qualityR == red and entry.qualityG == green and entry.qualityB == blue)
end
-- Legendary orange uses more of the native color on the same equipped crop.
quality, red, green, blue = 5, 1, 0.5, 0
crops = writes.uv
api.Quality(slot)
api.Update(slot)
Color(slot.carving, 1, 0.525, 0.05)
assert(slot.qualityR == red and slot.qualityG == green and slot.qualityB == blue)
assert(writes.uv == crops, "legendary tint rebound the equipped crop")
api.Clear(slot)
Color(slot.carving, 1, 1, 1)
Housing(slot.carving, 256)
colors, crops = writes.color, writes.uv
api.Clear(slot)
assert(writes.color == colors and writes.uv == crops, "settled empty slot repainted its housing")
slot.texture = "native:return"
slot.empty = false
quality, red, green, blue = 3, 0, 0.44, 0.87
api.Quality(slot)
api.Update(slot)
Color(slot.carving, 0.64, 0.88, 1)
visible = false
colors, crops = writes.color, writes.uv
api.Clear(slot)
assert(writes.color == colors and writes.uv == crops, "hidden empty transition painted early")
visible = true
api.Clear(slot)
Color(slot.carving, 1, 1, 1)
Housing(slot.carving, 256)
assert(writes.uv == crops + 1, "shown empty slot did not restore its neutral crop once")
print("PASS original jewelry housing retains neutral empty slots and brighter equipped rarity tint")
print("PASS rarity keeps raw native RGB, changed-only writes, hidden recovery and identical mode appearance")
