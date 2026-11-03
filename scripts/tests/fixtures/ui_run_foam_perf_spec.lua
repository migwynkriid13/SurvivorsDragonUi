-- CI only: production foam keeps full source textures inside the native viewport.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
env.bar = env.CreateFrame("StatusBar", nil, env.UIParent)
env.dynamicWidth = 280
local function Piece()
    local texture = env.bar:CreateTexture(nil, "OVERLAY")
    function texture:SetTexCoord() error("foam rewrote a material crop") end
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
paint(2, 7, 7.5)
local glow = env.foamGlow.texture
assert(glow:GetWidth() == 17 and glow:GetHeight() == 15 and glow.x == -4 and glow.y == 0)
paint(2.1, 7, 4.5)
assert(glow:GetHeight() == 15 and glow.y == 0, "viewport clipping stretched or re-anchored the glow")
print("PASS foam keeps the source geometry and full UVs across partial horizontal and vertical clipping")

local allocated = #context.objects
env.endless = true
paint(2.2, 280, 4.5)
assert(#context.objects == allocated, "full-bar froth allocated artwork")
local first, last, tall = 280, 0, false
for _, fleck in ipairs(env.foamFlecks) do
    local texture = fleck.texture
    assert(
        texture:IsShown() and texture:GetAlpha() >= 0.05 and texture:GetAlpha() <= 0.45,
        "distributed froth lost its subdued, persistent opacity"
    )
    assert(texture.x < 280 and texture.x + texture:GetWidth() > 0, "fully clipped foam stayed visible")
    first = math.min(first, math.max(0, texture.x))
    last = math.max(last, math.min(280, texture.x + texture:GetWidth()))
    if texture:GetHeight() >= 8 then tall = true end
end
assert(first <= 5 and last >= 275, "froth stayed clustered at the end instead of covering the bar")
assert(tall, "full-bar froth collapsed back into thin flow streaks")
assert(env.foamCrest.texture:GetAlpha() > 0.5, "faint full-bar froth dimmed the existing end crest")
env.endless = false
paint(2.3, 280, 4.5)
assert(env.foamFlecks[1].texture.x > 250, "regular froth did not retain its original leading-edge placement")
assert(#context.objects == allocated, "switching froth placement rebuilt the texture pool")
print("PASS Endless froth reuses twelve faint, clipped flecks across the width and retains the bright end crest")
