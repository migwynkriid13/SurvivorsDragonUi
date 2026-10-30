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
local bar = env.CreateFrame("StatusBar", nil, env.UIParent)
local border = env.CreateFrame("Frame", nil, env.UIParent)
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
assert(view.texture.point[4] == 17.5, "marker did not use the native one-minute coordinate")
assert(view.texture.width == 32 and view.texture.height == 16, "atlas display size changed")
local texture = view.texture
c:ResetCounts()
for _ = 1, 20 do
    view:Update(1, 960, 280)
end
c:NoPresentationWrites()
assert(not c.writes.Show and not c.writes.Hide, "unchanged marker rewrote visibility")
view:Resize(560)
assert(texture.point[4] == 35 and not c.writes.SetTexture, "width change rebound or misplaced artwork")
view:Resize(104)
assert(texture.point[4] == 16, "narrow bar clipped the numeral against its cap")
local lastTint
for rank = 1, 10 do
    view:Update(rank, 960, 280)
    assert(texture:IsShown() and #c.objects == count + 1, "changing rank rebuilt or hid its texture")
    local uv = texture.uv
    assert(uv[1] >= 0 and uv[2] <= 1 and uv[3] >= 0 and uv[4] <= 1, "numeral crop left its atlas")
    assert(not lastTint or rank > 5 or texture.color[2] < lastTint[2], "Heroic colors failed to warm by tier")
    lastTint = texture.color
end
assert(texture.uv[1] == 0.25 and texture.uv[2] == 0.5 and texture.uv[3] == 0.5, "X selected the wrong cell")
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
border:Hide()
c:ResetCounts()
view:Update(2, 960, 280)
view:Resize(560)
c:NoPresentationWrites()
print("PASS static Heroic numeral lifecycle, ranks, resize, retirement and binding retry")
