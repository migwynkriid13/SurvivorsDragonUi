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
