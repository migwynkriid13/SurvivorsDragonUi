-- CI only: the production foam pass shares its authored clipping height.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
env.bar = env.CreateFrame("StatusBar", nil, env.UIParent)
env.bar.height, env.dynamicWidth = 15, 280
function env.bar:GetHeight()
    context.reads.height = (context.reads.height or 0) + 1
    return self.height
end
local function Piece()
    local texture = env.bar:CreateTexture(nil, "OVERLAY")
    function texture:SetTexCoord(...) self.uv = { ... } end
    function texture:SetPoint(_, _, _, x, y)
        self.x, self.y = x, y
    end
    return { texture = texture }
end
env.foamGlow, env.foamCrest = Piece(), Piece()
env.foamShoulders, env.foamFlecks = { Piece(), Piece() }, {}
for index = 1, 12 do
    local piece = Piece()
    piece.period, piece.phase, piece.drift, piece.y = 1, index / 20, 7, 0
    env.foamFlecks[index] = piece
end
local chunk = assert(loadfile(assert(arg[1], "missing extracted run foam source")))
setfenv(chunk, env)
local paint = chunk()
paint(2, 7)
assert(context.reads.height == 1, "one foam pass repeated native height reads per piece")
local glow = env.foamGlow.texture
assert(glow:GetWidth() == 13 and glow:GetHeight() == 15 and glow.x == 0 and glow.y == 0)
assert(glow.uv[1] == 4 / 17 and glow.uv[2] == 1 and glow.uv[3] == 0 and glow.uv[4] == 1)
context.reads.height = 0
env.bar.height = 9
paint(2.1, 7)
assert(context.reads.height == 1, "the next foam pass did not sample its current height once")
assert(glow:GetHeight() == 9 and glow.y == 0, "shared height changed vertical clipping")
assert(glow.uv[3] == 3 / 15 and glow.uv[4] == 12 / 15, "shared height changed clipped sampling")
print("PASS run foam shares one native height sample and retains clipping geometry and UVs")

local allocated = #context.objects
context.reads.height = 0
env.endless = true
paint(2.2, 280)
assert(
    context.reads.height == 1 and #context.objects == allocated,
    "full-bar froth repeated height reads or allocated artwork"
)
local first, last, tall = 280, 0, false
for _, fleck in ipairs(env.foamFlecks) do
    local texture = fleck.texture
    assert(
        texture:IsShown() and texture:GetAlpha() >= 0.05 and texture:GetAlpha() <= 0.45,
        "distributed froth lost its subdued, persistent opacity"
    )
    assert(texture.x >= 0 and texture.x + texture:GetWidth() <= 280 + 1e-9, "distributed froth escaped the pill")
    assert(math.abs(texture.y) + texture:GetHeight() / 2 <= 4.5 + 1e-9, "distributed froth escaped vertical clipping")
    first = math.min(first, texture.x)
    last = math.max(last, texture.x + texture:GetWidth())
    if texture:GetHeight() >= 8 then tall = true end
end
assert(first <= 5 and last >= 275, "froth stayed clustered at the end instead of covering the bar")
assert(tall, "full-bar froth collapsed back into thin flow streaks")
assert(env.foamCrest.texture:GetAlpha() > 0.5, "faint full-bar froth dimmed the existing end crest")
env.endless = false
paint(2.3, 280)
assert(env.foamFlecks[1].texture.x > 250, "regular froth did not retain its original leading-edge placement")
assert(#context.objects == allocated, "switching froth placement rebuilt the texture pool")
print("PASS Endless froth reuses twelve faint, clipped flecks across the width and retains the bright end crest")
