-- CI only: extracted production marker lifecycle over explicit native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "marker fixtures require the CI Lua 5.1 interpreter")

local context = H.New()
local env = context.env
context:Load("core/display.lua", "Display")
local create = context.Object
function context:Object(...)
    local object = create(self, ...)
    function object:SetBlendMode(value) self.blend = value end
    return object
end
env.markers, env.markerStates = {}, {}
env.render = { activeMarkers = {}, activeMarkerCount = 0, markerStatesDirty = true }
env.GameTooltip = { IsOwned = function() return false end }
local markerSizes = {}
env.T.StyleDefeatedMarker = function(icon, check, size, dead)
    context.reads.styles = (context.reads.styles or 0) + 1
    markerSizes[icon] = size
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
local chunk = assert(loadfile(assert(arg[1], "missing extracted marker source")))
setfenv(chunk, env)
local source = chunk()
local bossIcon = env.DFRL:GetInfoOrCons("tex") .. "waypoint\\WorldQuestBoss.blp"
local bossHalo = env.DFRL:GetInfoOrCons("tex") .. "timer\\WorldQuestBossHalo.blp"
for index = 1, 5 do
    local marker = source.New(env.UIParent)
    marker.check = marker:CreateTexture(nil)
    local shown = marker.IsShown
    function marker:IsShown()
        context.reads.markerShown = (context.reads.markerShown or 0) + 1
        return shown(self)
    end
    env.markers[index] = marker
end
env.markerStates[1], env.markerStates[2], env.markerStates[3] = "due", "dead", "up"
local update = source.Update
local before = #context.objects
env.performanceMode = true
update(false)
assert(#context.objects == before, "Performance Mode prepared disabled skull halo objects")
assert(env.markers[1].skull.texture == bossIcon, "scheduled marker did not bind the boss icon")
assert(math.abs(markerSizes[env.markers[1].skull] - 17.1) < 0.000001, "upcoming skull was not reduced by 5%")
assert(markerSizes[env.markers[2].skull] == 18 and markerSizes[env.markers[3].skull] == 18)
for _, marker in ipairs(env.markers) do
    assert(not marker.glow)
    marker.state = nil
end
env.performanceMode, env.render.markerStatesDirty = false, true
context:ResetCounts()
update(false)
assert(not env.markers[1].glow and not env.markers[2].glow)
assert(#context.objects == before + 1, "first active skull did not prepare exactly one halo texture")
local halo = env.markers[3].glow
assert(halo.texture == bossHalo and halo.blend == "BLEND", "active skull did not bind the red contour")
assert(halo:GetWidth() == 24 and halo:GetHeight() == 24, "halo did not align with the skull")
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
assert(context.writes.SetAlpha == 1 and not context.writes.SetWidth and not context.writes.SetHeight)
local pulse = 0.5 - 0.5 * math.cos(context.now * 2 * math.pi / 2.4)
assert(halo:GetAlpha() == 0.5 + 0.35 * pulse, "active halo alpha equation changed")

env.markerStates[5], env.render.markerStatesDirty = "up", true
update(false)
context.now = context.now + 0.01
context:ResetCounts()
update(false)
assert(env.render.activeMarkerCount == 2 and context.reads.pulses == 1, "active skulls repeated pulse math")
assert(context.writes.SetAlpha == 2 and not context.writes.SetWidth and not context.writes.SetHeight)
env.markerStates[5], env.render.markerStatesDirty = nil, true
update(false)

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

local texture = env.markers[3].glow
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
assert(context.writes.SetAlpha == 1, "failed pulse did not retry the halo opacity")

env.markerStates[3], env.render.markerStatesDirty = "dead", true
context:ResetCounts()
update(false)
assert(env.render.activeMarkerCount == 0 and env.table.getn(env.render.activeMarkers) == 0)
assert(context.reads.styles == 1 and not context.reads.clock, "defeated state retained active pulse work")
assert(env.markers[3].check:IsShown() and not env.markers[3].glow:IsShown())
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
assert(not env.markers[2].check:IsShown() and env.markers[2].glow:IsShown())
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
assert(not env.markers[2].glow:IsShown(), "static mode retained a red skull halo")
context:ResetCounts()
for _ = 1, 60 do
    update(false)
end
context:NoPresentationWrites()
assert(not next(context.reads), "static skulls retained frame animation work")
env.performanceMode, env.render.markerStatesDirty = false, true
update(false)
assert(
    env.render.activeMarkerCount == 1 and env.markers[2].glow:IsShown(),
    "disabling performance mode did not restore the unchanged living skull halo"
)

env.markerStates[2], env.render.markerStatesDirty = nil, true
update(false)
assert(not env.markers[2]:IsShown() and env.render.activeMarkerCount == 0)

context.failTexture = bossHalo
env.markerStates[4], env.render.markerStatesDirty = "up", true
update(false)
local retryHalo = env.markers[4].glow
assert(env.markers[4]:IsShown() and not retryHalo:IsShown() and env.render.activeMarkerCount == 0)
context.failTexture, env.render.markerStatesDirty = nil, true
update(false)
assert(env.markers[4].glow == retryHalo and retryHalo:IsShown(), "failed binding did not reuse its halo region")
local display = env.DFRL.display
display.BeginEdit()
display.Set("bossIconStyle", "original")
env.render.markerStatesDirty = true
update(false)
assert(env.markers[4].skull.texture == "Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
assert(
    env.markers[4].glow == retryHalo
        and retryHalo.texture == env.DFRL:GetInfoOrCons("tex") .. "timer\\ClassicBossHalo.blp"
)
display.FinishEdit(false)
env.render.markerStatesDirty = true
update(false)
assert(
    env.markers[4].skull.texture == bossIcon and retryHalo.texture == bossHalo,
    "Cancel did not restore the active artwork"
)
display.BeginEdit()
display.Load({ bossIconStyle = "original", guardianIconStyle = "original" })
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.bossIconStyle == "original")
assert(env.SurvivorsDragonUiDisplay.guardianIconStyle == "original")
display.Reset()
assert(display.Get("bossIconStyle") == "default" and display.Get("guardianIconStyle") == "default")
print("PASS active skulls pulse one fixed contour without reflow and retire it with their marker state")
