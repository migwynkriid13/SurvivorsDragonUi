-- CI only: shared stepped texture rotation over a recording texture.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "rotation fixtures require CI Lua 5.1")

local T = H.New().env.T
local STEP = 2 * math.pi / 128

local function Texture()
    local texture = { writes = 0 }
    function texture:SetTexCoord(...)
        self.writes = self.writes + 1
        self.coords = { ... }
    end
    return texture
end

local function Legacy(angle)
    local c, s = math.cos(angle) / 2, math.sin(angle) / 2
    return {
        0.5 - c - s,
        0.5 + s - c,
        0.5 - c + s,
        0.5 + s + c,
        0.5 + c - s,
        0.5 - s - c,
        0.5 + c + s,
        0.5 - s + c,
    }
end

local function Same(coords, expected)
    assert(table.getn(coords) == 8, "rotation must write all eight coordinates")
    for index = 1, 8 do
        assert(math.abs(coords[index] - expected[index]) < 1e-9, "rotation coordinate differs from the legacy equation")
    end
end

do
    for _, angle in ipairs({ 0, math.pi / 2, math.pi, 3 * math.pi / 2, 37 * STEP }) do
        local texture = Texture()
        T.RotateTexture(texture, angle)
        assert(texture.writes == 1)
        Same(texture.coords, Legacy(angle))
    end
end

do
    local texture = Texture()
    T.RotateTexture(texture, 0.001)
    T.RotateTexture(texture, 0.002)
    T.RotateTexture(texture, -0.001)
    assert(texture.writes == 1, "an unchanged step rewrote its UVs")
    T.RotateTexture(texture, STEP)
    assert(texture.writes == 2, "a new step did not write")
    Same(texture.coords, Legacy(STEP))
end

do
    local negative, positive = Texture(), Texture()
    T.RotateTexture(negative, -math.pi / 2)
    T.RotateTexture(positive, 3 * math.pi / 2)
    assert(negative.rotationStep == positive.rotationStep)
    Same(negative.coords, positive.coords)
    local wrapped, plain = Texture(), Texture()
    T.RotateTexture(wrapped, 2 * math.pi + 0.01)
    T.RotateTexture(plain, 0.01)
    assert(wrapped.rotationStep == plain.rotationStep and wrapped.rotationStep == 0)
    local boundary = Texture()
    T.RotateTexture(boundary, 127.6 * STEP)
    assert(boundary.rotationStep == 0, "the last half step did not wrap to zero")
end

do
    local texture = Texture()
    T.RotateTexture(texture, 5 * STEP)
    T.RotateTexture(texture, 0 / 0)
    T.RotateTexture(texture, 1 / 0)
    T.RotateTexture(texture, -1 / 0)
    T.RotateTexture(texture, nil)
    assert(texture.writes == 1 and texture.rotationStep == 5, "a non-finite angle changed the rotation")
end

do
    local texture = Texture()
    T.RotateTexture(texture, 9 * STEP)
    T.ClearRotation(texture)
    assert(texture.rotationStep == nil)
    T.RotateTexture(texture, 9 * STEP)
    assert(texture.writes == 2, "a cleared rotation did not repaint")
end

print("PASS Shared texture rotation snaps to bounded steps and skips unchanged writes")
