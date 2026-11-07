-- CI only: the production numeral view over explicit fake texture boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local c = H.New()
local env = c.env
local create = c.Object
function c:Object(...)
    local object = create(self, ...)
    local setPoint, setUV, setColor = object.SetPoint, object.SetTexCoord, object.SetVertexColor
    function object:SetPoint(...)
        self.point = { ... }
        setPoint(self, ...)
    end
    function object:SetTexCoord(...)
        self.uv = { ... }
        setUV(self, ...)
    end
    function object:SetVertexColor(...)
        self.color = { ... }
        setColor(self, ...)
    end
    return object
end
local pill = env.CreateFrame("Frame", nil, env.UIParent)
local bar = env.CreateFrame("StatusBar", nil, pill)
local border = env.CreateFrame("Frame", nil, pill)
local rim = {}
function pill:CreateTexture(name, layer)
    local texture = c:Object("Texture", name, self)
    texture.layer = layer
    function texture:SetBlendMode(mode) self.blend = mode end
    table.insert(rim, texture)
    return texture
end
local chunk = assert(loadfile(assert(arg[1], "missing extracted numeral source")))
setfenv(chunk, env)
local new = chunk()
local view = new(bar, border)
local count = #c.objects
view:Update(0, 960, 280)
border:Hide()
view:Update(1, 960, 280)
assert(#c.objects == count, "normal or hidden bars allocated numeral artwork")
border:Show()
view:Update(1, 960, 280)
assert(#c.objects == count + 1 and view.texture:IsShown(), "Heroic marker is not one lazy texture")
assert(view.texture.point[2] == bar and view.texture.point[3] == "LEFT")
assert(view.texture.point[4] == 26.25, "marker did not use the 1:30-of-16:00 percentage coordinate")
assert(view.texture.point[5] == -0.25, "visible lettering is not centered vertically in the pill")
assert(view.texture.width == 32 and view.texture.height == 16, "atlas display size changed")
local texture = view.texture
c:ResetCounts()
for _ = 1, 20 do
    view:Update(1, 960, 280)
end
c:NoPresentationWrites()
assert(not c.writes.Show and not c.writes.Hide, "unchanged marker rewrote visibility")
c:ResetCounts()
for _, maximum in ipairs({ 45, 600, 960, 1200, 1800 }) do
    view:Update(1, maximum, 280)
    assert(texture.point[4] == 26.25 and texture:IsShown(), "zone duration changed the fixed percentage position")
end
c:NoPresentationWrites()
assert(not c.writes.SetPoint, "duration-only changes rewrote the numeral anchor")
view:Resize(560)
assert(texture.point[4] == 52.5 and not c.writes.SetTexture, "width change rebound or misplaced percentage artwork")
view:Resize(104)
assert(texture.point[4] == 16, "narrow bar clipped the numeral against its cap")
local lastTint
for rank = 1, 10 do
    view:Update(rank, 960, 280)
    assert(texture:IsShown() and #c.objects == count + 1, "changing rank rebuilt or hid its texture")
    assert(texture.point[4] == 26.25, "Heroic rank changed the shared percentage position")
    assert(texture.point[5] == -0.25, "rank change moved the visible lettering off the pill center")
    local uv = texture.uv
    assert(uv[1] >= 0 and uv[2] <= 1 and uv[3] >= 0 and uv[4] <= 1, "numeral crop left its atlas")
    assert(not lastTint or rank > 5 or texture.color[2] < lastTint[2], "Heroic colors failed to warm by tier")
    lastTint = texture.color
end
assert(texture.uv[1] == 0.25 and texture.uv[2] == 0.5 and texture.uv[3] == 0.5, "X selected the wrong cell")
assert(texture.color[2] == 211 / 255 and texture.color[3] == 200 / 255, "X retained the lower-tier tint")
for _, rank in ipairs({ 0, -1, 1.5, 11, "5", math.huge }) do
    view:Update(rank, 960, 280)
    assert(not texture:IsShown(), "unsupported rank displayed a previous numeral")
end
view:Update(nil, 960, 280)
view:Update(5, nil, 280)
view:Update(5, 0, 280)
view:Update(5, 960, nil)
assert(not texture:IsShown(), "missing geometry replayed the last valid numeral")
view:Update(5, 960, 280)
env.performanceMode = true
c:ResetCounts()
view:Update(5, 960, 280)
c:NoPresentationWrites()
assert(texture:IsShown(), "Performance Mode removed static difficulty information")
view:Clear()
assert(not texture:IsShown() and not view.rank and not view.maximum, "retirement retained an active rank")
c:ResetCounts()
view:Clear()
c:NoPresentationWrites()
assert(not c.writes.Hide, "settled retirement rewrote hiding")
local failed = new(bar, border)
c.failTexture = texture:GetTexture()
failed:Update(3, 960, 280)
assert(not failed.texture:IsShown() and not failed.bound, "failed image binding became ready")
local failedTexture, allocated = failed.texture, #c.objects
c.failTexture = nil
failed:Update(3, 960, 280)
assert(
    failed.texture == failedTexture and #c.objects == allocated and failed.texture:IsShown(),
    "retry rebuilt or lost the texture"
)
local affixes = { center = 18 + 12.5 + 25 / 29 - 8 }
function affixes:FirstCenter(width)
    self.width = width
    return self.center
end
local aligned = new(bar, border, affixes)
aligned:Update(5, 960, 280)
local alignedTexture, alignedObjects = aligned.texture, #c.objects
assert(
    math.abs(alignedTexture.point[4] - affixes.center) < 0.000001 and alignedTexture.point[5] == -0.25,
    "numeral does not sit beneath the first affix's visible center"
)
assert(affixes.width == 280, "affix owner did not receive the actual fill width")
c:ResetCounts()
for _, maximum in ipairs({ 45, 600, 960, 1800 }) do
    aligned:Update(5, maximum, 280)
end
c:NoPresentationWrites()
assert(#c.objects == alignedObjects, "aligned updates rebuilt the numeral")
affixes.center = 125.5
aligned:Resize(280)
assert(alignedTexture.point[4] == 125.5 and alignedTexture.point[5] == -0.25)
assert(c.writes.SetPoint == 1 and not c.writes.SetTexture, "affix movement rebound or repeatedly placed the artwork")
c:ResetCounts()
aligned:Resize(280)
c:NoPresentationWrites()
for _, center in ipairs({ -20, 0, 400 }) do
    affixes.center = center
    aligned:Resize(280)
    assert(alignedTexture.point[4] == (center > 280 and 264 or 16), "affix alignment escaped the pill caps")
end
for _, center in ipairs({ false, "invalid", math.huge, 0 / 0 }) do
    affixes.center = center
    aligned:Resize(280)
    assert(alignedTexture.point[4] == 26.25, "invalid affix center did not retain the percentage fallback")
end
affixes.center = nil
aligned:Resize(560)
assert(alignedTexture.point[4] == 52.5, "detached or absent affixes lost the percentage fallback")
for _, performance in ipairs({ false, true }) do
    env.performanceMode = performance
    affixes.center = 91.75
    aligned:Update(10, 960, 280)
    c:ResetCounts()
    aligned:Update(10, 1200, 280)
    c:NoPresentationWrites()
    assert(alignedTexture.point[4] == 91.75 and alignedTexture.point[5] == -0.25 and alignedTexture:IsShown())
end
border:Hide()
c:ResetCounts()
view:Update(2, 960, 280)
view:Resize(560)
aligned:Resize(560)
c:NoPresentationWrites()

local paused, resumed
env.T.AnimationTime = function()
    c.reads.animation = (c.reads.animation or 0) + 1
    return c.now, paused, resumed
end
view:Update(6, 960, 280)
view:AnimateRim()
assert(#rim == 0, "hidden timer allocated rim effects")
border:Show()
view:Update(6, 960, 280)
view:AnimateRim()
assert(#rim == 0 and texture:IsShown(), "Performance Mode allocated rim effects or hid the numeral")
env.performanceMode = false
view:Update(5, 960, 280)
view:AnimateRim()
assert(#rim == 0, "Heroic V allocated rim effects")

local lastWidth, lastGreen = 0, 1
for rank = 6, 10 do
    view:Update(rank, 960, 280)
    view:AnimateRim()
    assert(#rim == rank - 2, "Heroic rim did not grow by one ember per rank")
    assert(rim[1].width > lastWidth and rim[1].color[2] < lastGreen, "danger did not escalate by rank")
    lastWidth, lastGreen = rim[1].width, rim[1].color[2]
end
assert(rim[1].point[3] == "LEFT" and rim[2].point[3] == "RIGHT", "rim glows missed the two pill caps")
for _, effect in ipairs(rim) do
    assert(effect.layer == "BACKGROUND" and effect.blend == "ADD" and effect:IsShown(), "invalid rim effect layer")
end

c:ResetCounts()
view:AnimateRim()
c:NoPresentationWrites()
c.now = c.now + 0.1
view:AnimateRim()
assert(c.writes.SetAlpha == 8 and c.writes.SetPoint == 6, "timed paint rewrote the static glow anchors")
c:ResetCounts()
paused, c.now = true, c.now + 0.1
view:AnimateRim()
paused, resumed = false, true
view:AnimateRim()
c:NoPresentationWrites()
resumed = false
view:AnimateRim()
assert(c.writes.SetAlpha == 8, "rim did not resume from the held cosmetic clock")

view:Update(6, 960, 280)
view:AnimateRim()
for index, effect in ipairs(rim) do
    assert(effect:IsShown() == (index <= 4), "lower rank retained surplus embers")
end
env.performanceMode = true
view:HideRim()
c:ResetCounts()
view:AnimateRim()
c:NoPresentationWrites()
assert(not c.reads.animation and not rim[1]:IsShown() and texture:IsShown(), "static mode kept animating the rim")
env.performanceMode = false
view:AnimateRim()
assert(#rim == 8 and rim[1]:IsShown(), "rim recovery failed to reuse its textures")
view:Clear()
for _, effect in ipairs(rim) do
    assert(not effect:IsShown(), "retired timer retained a rim effect")
end
print("PASS Heroic numeral lifecycle, rank-scaled rim, pause, pooling and retirement")
