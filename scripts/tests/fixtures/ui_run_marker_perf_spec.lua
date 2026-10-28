-- CI only: extracted production marker lifecycle over explicit native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "marker fixtures require the CI Lua 5.1 interpreter")

local context = H.New()
local env = context.env
env.markers, env.markerStates = {}, {}
env.render = { activeMarkers = {}, activeMarkerCount = 0, markerStatesDirty = true }
env.GameTooltip = { IsOwned = function() return false end }
env.T.StyleDefeatedMarker = function(_, check, _, dead)
    context.reads.styles = (context.reads.styles or 0) + 1
    if dead then
        check:Show()
    else
        check:Hide()
    end
end
env.GetTime = function()
    context.reads.clock = (context.reads.clock or 0) + 1
    return context.now
end
env.math = {}
for name, value in pairs(math) do
    env.math[name] = value
end
env.math.cos = function(...)
    context.reads.pulses = (context.reads.pulses or 0) + 1
    return math.cos(...)
end
for index = 1, 5 do
    local marker = env.CreateFrame("Frame", nil, env.UIParent)
    marker.skull = marker:CreateTexture(nil)
    marker.check = marker:CreateTexture(nil)
    marker.glowCardinal = env.CreateFrame("Frame", nil, marker)
    marker.glowDiagonal = env.CreateFrame("Frame", nil, marker)
    marker.glow = {}
    for copy = 1, 8 do
        marker.glow[copy] = { texture = marker:CreateTexture(nil) }
    end
    local shown = marker.IsShown
    function marker:IsShown()
        context.reads.markerShown = (context.reads.markerShown or 0) + 1
        return shown(self)
    end
    env.markers[index] = marker
end
env.markerStates[1], env.markerStates[2], env.markerStates[3] = "due", "dead", "up"
local chunk = assert(loadfile(assert(arg[1], "missing extracted marker source")))
setfenv(chunk, env)
local source = chunk()
local update = source.Update
update(false)
assert(env.render.activeMarkerCount == 1 and env.render.activeMarkers[1] == env.markers[3])
assert(env.markers[1]:IsShown() and env.markers[2].check:IsShown() and not env.markers[4]:IsShown())
assert(context.reads.styles == 3 and context.reads.clock == 1 and context.reads.pulses == 1)

context:ResetCounts()
update(false)
context:NoPresentationWrites()
assert(context.reads.clock == 1 and context.reads.pulses == 1, "active marker lost frame cadence")
assert(not context.reads.markerShown and not context.reads.styles, "unchanged state traversed inactive marker slots")
context.now = context.now + 0.01
context:ResetCounts()
update(false)
assert(context.writes.SetAlpha == 8 and context.writes.SetWidth == 2 and context.writes.SetHeight == 2)
local pulse = 0.5 - 0.5 * math.cos(context.now * 2 * math.pi / 2.4)
local alpha, offset = 0.25 + 0.25 * pulse, 0.9 + (4.55 - 0.9) * pulse
assert(env.markers[3].glow[1].texture:GetAlpha() == alpha, "active halo alpha equation changed")
assert(env.markers[3].glowCardinal:GetWidth() == 2 * offset, "active halo offset equation changed")
assert(env.markers[3].glowCardinal:GetHeight() == 2 * offset, "cardinal halo height lost its pulse")
local diagonal = 2 * ((1 / math.sqrt(2)) * offset)
assert(env.markers[3].glowDiagonal:GetWidth() == diagonal, "diagonal halo width lost its pulse")
assert(env.markers[3].glowDiagonal:GetHeight() == diagonal, "diagonal halo height lost its pulse")

source.Hide(env.markers[3])
assert(env.render.markerStatesDirty and not env.markers[3]:IsShown(), "external retirement did not dirty state")
local show = env.markers[3].Show
local rejectShow = true
env.markers[3].Show = function(self)
    if rejectShow then
        rejectShow = false
        return
    end
    show(self)
end
update(false)
assert(env.render.markerStatesDirty and not env.markers[3]:IsShown(), "failed marker Show was marked settled")
update(false)
assert(env.markers[3]:IsShown() and env.render.activeMarkerCount == 1, "retirement blocked same-schedule recovery")

local texture = env.markers[3].glow[4].texture
local setAlpha = texture.SetAlpha
function texture:SetAlpha(value)
    if context.rejectAlpha then
        context.rejectAlpha = nil
        error("injected halo alpha failure")
    end
    setAlpha(self, value)
end
local oldAlpha = env.markers[3].glowAlpha
context.now, context.rejectAlpha = context.now + 0.01, true
local ok = pcall(update, false)
assert(not ok and env.markers[3].glowAlpha == oldAlpha, "failed pulse was published as successfully painted")
context:ResetCounts()
update(false)
assert(context.writes.SetAlpha == 8, "failed pulse did not retry every halo copy")

env.markerStates[3], env.render.markerStatesDirty = "dead", true
context:ResetCounts()
update(false)
assert(env.render.activeMarkerCount == 0 and env.table.getn(env.render.activeMarkers) == 0)
assert(context.reads.styles == 1 and not context.reads.clock, "defeated state retained active pulse work")
assert(env.markers[3].check:IsShown() and not env.markers[3].glow[1].texture:IsShown())
context:ResetCounts()
for _ = 1, 60 do
    context.now = context.now + 1 / 60
    update(false)
end
context:NoPresentationWrites()
assert(not next(context.reads), "inactive markers still sampled time, traversed slots or computed pulses")

env.markerStates[2], env.render.markerStatesDirty = "up", true
update(false)
assert(env.render.activeMarkerCount == 1 and env.render.activeMarkers[1] == env.markers[2])
assert(not env.markers[2].check:IsShown() and env.markers[2].glow[1].texture:IsShown())
local hide = env.markers[2].Hide
local rejectHide = true
env.markers[2].Hide = function(self)
    if rejectHide then
        rejectHide = false
        return
    end
    hide(self)
end
update(true)
assert(env.render.markerStatesDirty and env.markers[2]:IsShown(), "failed marker Hide was marked settled")
update(true)
assert(env.render.activeMarkerCount == 0, "native limit retained active halos")
for _, marker in ipairs(env.markers) do
    assert(not marker:IsShown() and not marker.check:IsShown(), "native limit left a marker visible")
end
context:ResetCounts()
update(true)
context:NoPresentationWrites()
assert(not next(context.reads), "settled native limit repeated marker cleanup")
update(false)
assert(env.render.activeMarkerCount == 1 and env.markers[2]:IsShown(), "time correction did not restore schedule state")

env.performanceMode, env.render.markerStatesDirty = true, true
context:ResetCounts()
update(false)
assert(env.markers[2]:IsShown() and not env.markers[2].check:IsShown(), "static mode lost the living skull state")
assert(env.render.activeMarkerCount == 0 and not context.reads.clock and not context.reads.pulses)
for _, glow in ipairs(env.markers[2].glow) do
    assert(not glow.texture:IsShown(), "static mode retained a red skull halo")
end
context:ResetCounts()
for _ = 1, 60 do
    update(false)
end
context:NoPresentationWrites()
assert(not next(context.reads), "static skulls retained frame animation work")
env.performanceMode, env.render.markerStatesDirty = false, true
update(false)
assert(
    env.render.activeMarkerCount == 1 and env.markers[2].glow[1].texture:IsShown(),
    "disabling performance mode did not restore the unchanged living skull halo"
)

env.markerStates[2], env.render.markerStatesDirty = nil, true
update(false)
assert(not env.markers[2]:IsShown() and env.render.activeMarkerCount == 0)
print("PASS marker transitions reconcile on changes and only active skulls retain exact frame-driven halo animation")
