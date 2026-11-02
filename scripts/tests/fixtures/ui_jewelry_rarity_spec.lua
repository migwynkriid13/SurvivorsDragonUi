-- CI only: exact production rarity helpers over fake native color/texture boundaries.
assert(_VERSION == "Lua 5.1", "jewelry rarity fixtures require CI Lua 5.1")
local env = setmetatable({}, { __index = _G })
env._G = env
local visible, allocations = true, 0
local writes = { color = 0, uv = 0, geometry = 0, texture = 0, show = 0, hide = 0 }
local methods = {}
local function Region() return setmetatable({}, { __index = methods }) end
function methods:SetVertexColor(...)
    writes.color = writes.color + 1
    self.color = { ... }
end
function methods:SetTexCoord(...)
    writes.uv = writes.uv + 1
    self.uv = { ... }
end
function methods:SetTexture(value)
    writes.texture = writes.texture + 1
    self.texture = value
end
function methods:SetWidth(value)
    writes.geometry = writes.geometry + 1
    self.width = value
end
function methods:SetHeight(value)
    writes.geometry = writes.geometry + 1
    self.height = value
end
function methods:SetPoint(...)
    writes.geometry = writes.geometry + 1
    self.point = { ... }
end
function methods:SetBlendMode(value) self.blend = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:Show()
    writes.show = writes.show + 1
    self.shown = true
end
function methods:Hide()
    writes.hide = writes.hide + 1
    self.shown = false
end
env.hud = { IsVisible = function() return visible end }
env.overlay = {
    CreateTexture = function(_, name, layer)
        assert(name == nil and layer == "ARTWORK")
        allocations = allocations + 1
        return Region()
    end,
}
env.texturePath = "owned/"
env.carvingSize = 43 * 128 / 108
env.performanceMode, env.editing, env.flamesActive, env.flameClock = false, false, false, 0
env.slots = {}
for index = 1, 5 do
    env.slots[index] = { id = index, button = {}, carving = Region(), flamePhase = (index - 1) / 5 }
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
assert(not api.Update(slot) and allocations == 0, "empty slot allocated flames")
Color(slot.carving, 1, 1, 1)
slot.texture = "native:item"
api.Quality(slot)
env.performanceMode = true
assert(not api.Update(slot) and allocations == 0, "Performance Mode allocated flames")
Color(slot.carving, 0.472, 1, 0.4)
env.performanceMode = false
assert(api.Update(slot) and allocations == 1)
local flame = slot.flame
assert(flame.texture == "owned/RarityFlames.blp" and flame.blend == "ADD" and flame.alpha == 0.75)
assert(flame.width == env.carvingSize and flame.height == env.carvingSize)
assert(flame.point[2] == slot.button and flame.point[4] == 0 and flame.point[5] == 0)
Color(flame, red, green, blue)
env.flamesActive = true
api.Paint()
assert(flame.shown and slot.flameFrame == 0 and writes.show == 1, "frame zero did not show")
local colors, geometry, textures, uvs = writes.color, writes.geometry, writes.texture, writes.uv
for _ = 1, 10 do
    assert(api.Update(slot))
    api.Paint()
end
assert(writes.color == colors and writes.geometry == geometry and writes.texture == textures)
assert(writes.uv == uvs and allocations == 1, "settled frame repeated native writes")
env.flameClock = 0.02
api.Paint()
assert(writes.uv == uvs, "unchanged sprite repeated UV writes")
env.flameClock = 0.065
api.Paint()
assert(slot.flameFrame == 1 and writes.uv == uvs + 1)
for frame = 0, 16 do
    env.flameClock = frame * 0.96 / 16
    api.Paint()
    for _, edge in ipairs(flame.uv) do
        assert(edge >= 0 and edge <= 1, "sprite escaped its atlas")
    end
    assert(flame.uv[2] - flame.uv[1] == 0.25 and flame.uv[4] - flame.uv[3] == 0.25)
end
assert(slot.flameFrame == 0, "sprite period did not wrap")
api.Stop()
assert(not flame.shown and not slot.flameRunning and slot.flameFrame == nil)
assert(not env.flamesActive and env.flameClock == 0)
local hides = writes.hide
api.Stop()
assert(writes.hide == hides, "retired flame repeated hide writes")
for _, state in ipairs({ "performanceMode", "editing" }) do
    env[state], env.flamesActive = true, true
    uvs = writes.uv
    assert(not api.Update(slot))
    api.Paint()
    assert(writes.uv == uvs and not flame.shown and allocations == 1)
    env[state] = false
end
-- Hidden recoloring waits for Show, then reuses the same region and raw native RGB.
visible = false
quality, red, green, blue = 4, 0.64, 0.21, 0.93
api.Quality(slot)
colors, uvs = writes.color, writes.uv
assert(not api.Update(slot))
api.Paint()
assert(writes.color == colors and writes.uv == uvs)
visible = true
assert(api.Update(slot) and slot.flame == flame and allocations == 1)
Color(flame, red, green, blue)
Color(slot.carving, 0.784, 0.526, 0.958)
-- Poor/common are valid native qualities; missing or malformed metadata stays grey.
for _, rank in ipairs({ 0, 1 }) do
    quality, red, green, blue = rank, 0.62 + rank * 0.38, 0.62 + rank * 0.38, 0.62 + rank * 0.38
    api.Quality(slot)
    assert(api.Update(slot), "poor/common rarity was rejected")
    Color(flame, red, green, blue)
end
quality = nil
api.Quality(slot)
assert(not api.Update(slot) and not flame.shown and not slot.qualityR)
Color(slot.carving, 1, 1, 1)
quality, red = 5, 2
api.Quality(slot)
assert(not api.Update(slot) and not slot.qualityR, "invalid RGB retained previous rarity")
quality, red, green, blue = 3, 0, 0.44, 0.87
for _, entry in ipairs(env.slots) do
    entry.texture = "native:item"
    api.Quality(entry)
    assert(api.Update(entry))
end
env.flamesActive = true
api.Paint()
assert(allocations == 5 and env.slots[2].flameFrame ~= slot.flameFrame, "slots did not reuse staggered sprites")
api.Stop()
for _, entry in ipairs(env.slots) do
    assert(not entry.flame.shown and not entry.flameRunning)
end
slot.texture = nil
assert(not api.Update(slot), "empty slot retained flames")
Color(slot.carving, 1, 1, 1)
print("PASS jewelry rarity uses native RGB, grey fallback, lazy reuse and changed-only sprite frames")
print("PASS jewelry flames retire for hidden/empty/editing/Performance Mode without native reads")
