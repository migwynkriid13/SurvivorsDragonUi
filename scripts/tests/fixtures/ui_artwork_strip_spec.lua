-- CI only: production artwork strips over explicit native texture boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "artwork strip fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local make = context.Object
function context:Object(...)
    local object = make(self, ...)
    local setPoint, setTexCoord = object.SetPoint, object.SetTexCoord
    function object:SetPoint(...)
        setPoint(self, ...)
        self.point = { ... }
    end
    function object:SetTexCoord(...)
        setTexCoord(self, ...)
        self.coordinates = { ... }
    end
    return object
end
local owner = env.CreateFrame("Frame", nil, env.UIParent)
local count = #context.objects
local strip = env.T.CreateArtworkStrip(owner, "BACKGROUND", 3)
assert(#context.objects == count + 3, "strip allocated more than its three texture regions")
for _, piece in ipairs(strip.pieces) do
    assert(piece.kind == "Texture" and piece:GetParent() == owner and not piece:GetScript("OnUpdate"))
end
local files = { "SocketRail.blp", "SocketRail_2.blp", "SocketRail_3.blp" }
strip:SetTextures("rail/", files)
strip:SetWidth(600)
strip:SetHeight(76)
strip:SetPoint("TOPLEFT", owner, "TOPLEFT", -6, 40)
strip:SetTexCoord(1 / 512, 401 / 512, 0, 152 / 256)
strip:SetAlpha(0.8)
strip:Show()
for index, piece in ipairs(strip.pieces) do
    assert(piece:GetWidth() == 200 and piece:GetHeight() == 76 and piece:GetTexture() == "rail/" .. files[index])
    if index > 1 then assert(piece.point[2] == strip.pieces[index - 1] and piece.point[3] == "TOPRIGHT") end
end
context:ResetCounts()
strip:SetTextures("rail/", files)
strip:SetWidth(600)
strip:SetHeight(76)
strip:SetPoint("TOPLEFT", owner, "TOPLEFT", -6, 40)
strip:SetTexCoord(1 / 512, 401 / 512, 0, 152 / 256)
strip:SetAlpha(0.8)
strip:Show()
context:NoPresentationWrites()
strip:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)
strip:SetWidth(900)
assert(strip.pieces[3].point[2] == owner and strip.pieces[1].point[2] == strip.pieces[2])
for _, piece in ipairs(strip.pieces) do
    assert(piece:GetWidth() == 300)
end
owner:Hide()
for _, piece in ipairs(strip.pieces) do
    assert(not piece:IsVisible(), "strip escaped parent hiding")
end
strip:Hide()
owner:Show()
for _, piece in ipairs(strip.pieces) do
    assert(not piece:IsShown(), "hidden artwork was forced back on with its parent")
end
strip:Show()
context.failTexture = "retry/" .. files[2]
strip:SetTextures("retry/", files)
context.failTexture = nil
context:ResetCounts()
strip:SetTextures("retry/", files)
assert(context.writes.SetTexture == 1 and strip.pieces[2]:GetTexture() == "retry/" .. files[2])
assert(#context.objects == count + 3, "resize, binding retry or hiding allocated another region")

local chrome = owner:CreateTexture(nil, "BORDER")
env.T.SetChromeTexture(chrome, 640, 0, 704, 64)
assert(chrome.coordinates[1] == 128 / 512 and chrome.coordinates[2] == 192 / 512)
assert(chrome.coordinates[3] == 256 / 512 and chrome.coordinates[4] == 320 / 512)
print("PASS artwork strips preserve joins, right anchors, parent hiding, retries and changed-only writes")
