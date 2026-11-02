-- CI only: exact production rarity helpers over fake native color/texture boundaries.
assert(_VERSION == "Lua 5.1", "jewelry rarity fixtures require CI Lua 5.1")
local env = setmetatable({}, { __index = _G })
env._G = env
local visible, allocations = true, 0
local writes = { color = 0, uv = 0, geometry = 0, texture = 0, alpha = 0, blend = 0, show = 0, hide = 0 }
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
function methods:SetBlendMode(value)
    writes.blend = writes.blend + 1
    self.blend = value
end
function methods:SetAlpha(value)
    writes.alpha = writes.alpha + 1
    self.alpha = value
end
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
        assert(name == nil and layer == "OVERLAY", "steady glow must brighten the existing border")
        allocations = allocations + 1
        return Region()
    end,
}
env.texturePath = "owned/"
env.carvingSize = 43 * 128 / 108
env.performanceMode, env.editing = false, false
env.slots = {}
for index = 1, 5 do
    env.slots[index] = { id = index, button = {}, carving = Region() }
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
assert(not api.Update(slot) and allocations == 0, "empty slot allocated glow")
Color(slot.carving, 1, 1, 1)
slot.texture = "native:item"
api.Quality(slot)
env.performanceMode = true
assert(not api.Update(slot) and allocations == 0, "Performance Mode allocated glow")
Color(slot.carving, 0.208, 1, 0.1)
env.performanceMode = false
assert(api.Update(slot) and allocations == 1)
local glow = slot.glow
assert(glow.texture == "owned/Frame.blp" and glow.blend == "ADD" and glow.alpha == 0.4)
assert(glow.width == env.carvingSize and glow.height == env.carvingSize)
assert(glow.point[2] == slot.button and glow.point[4] == 0 and glow.point[5] == 0)
assert(glow.uv[1] == 384 / 512 and glow.uv[2] == 1 and glow.uv[3] == 0 and glow.uv[4] == 1)
Color(glow, red, green, blue)
assert(glow.shown and slot.glowShown and writes.show == 1, "steady glow did not show")
local colors, geometry, textures, uvs = writes.color, writes.geometry, writes.texture, writes.uv
local alphas, blends, shows, hides = writes.alpha, writes.blend, writes.show, writes.hide
for _ = 1, 10 do
    assert(api.Update(slot))
end
assert(writes.color == colors and writes.geometry == geometry and writes.texture == textures)
assert(writes.uv == uvs and allocations == 1, "steady glow changed its artwork crop")
assert(writes.alpha == alphas and writes.blend == blends, "steady glow changed its intensity")
assert(writes.show == shows and writes.hide == hides, "steady glow repeated visibility writes")
api.Stop()
assert(not glow.shown and not slot.glowShown)
hides = writes.hide
api.Stop()
assert(writes.hide == hides, "retired glow repeated hide writes")
for _, state in ipairs({ "performanceMode", "editing" }) do
    env[state] = true
    uvs = writes.uv
    assert(not api.Update(slot))
    assert(writes.uv == uvs and not glow.shown and allocations == 1)
    env[state] = false
    assert(api.Update(slot) and glow.shown and slot.glow == glow and allocations == 1)
end
-- Hidden recoloring waits for Show, then reuses the same region and raw native RGB.
visible = false
quality, red, green, blue = 4, 0.64, 0.21, 0.93
api.Quality(slot)
colors, uvs = writes.color, writes.uv
assert(not api.Update(slot))
assert(writes.color == colors and writes.uv == uvs and not glow.shown)
visible = true
assert(api.Update(slot) and slot.glow == glow and allocations == 1)
Color(glow, red, green, blue)
Color(slot.carving, 0.676, 0.289, 0.937)
-- Poor/common are valid native qualities; missing or malformed metadata stays grey.
for _, rank in ipairs({ 0, 1 }) do
    quality, red, green, blue = rank, 0.62 + rank * 0.38, 0.62 + rank * 0.38, 0.62 + rank * 0.38
    api.Quality(slot)
    assert(api.Update(slot), "poor/common rarity was rejected")
    Color(glow, red, green, blue)
end
quality = nil
api.Quality(slot)
assert(not api.Update(slot) and not glow.shown and not slot.qualityR)
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
assert(allocations == 5 and slot.glow == glow, "equipment changes did not reuse glow regions")
for _, entry in ipairs(env.slots) do
    assert(entry.glow.shown and entry.glow.uv[1] == 384 / 512 and entry.glow.uv[2] == 1)
end
api.Stop()
for _, entry in ipairs(env.slots) do
    assert(not entry.glow.shown and not entry.glowShown)
end
slot.texture = nil
assert(not api.Update(slot), "empty slot retained glow")
Color(slot.carving, 1, 1, 1)
print("PASS jewelry rarity reuses the housing artwork with a steady native-color glow and unchanged writes")
print("PASS jewelry glow retires for hidden/empty/editing/Performance Mode without native reads")
