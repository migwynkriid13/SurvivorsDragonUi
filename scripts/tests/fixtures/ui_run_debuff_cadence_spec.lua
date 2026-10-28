-- CI only: extracted production HUD update and debuff lifecycle.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "run-debuff fixtures require the CI Lua 5.1 interpreter")
local context = H.New()
local env = context.env
context.phase = "playing"
context.settings.bossDebuffs, context.settings.bossRows = true, 0
context.effects = { { spell = 17, name = "Effect", icon = "SpellIcon", stacks = 2, remaining = 61, duration = 90 } }
env.inWorld = true
env.PHASES = { ready = true, playing = true, choosing = true, paused = true, dead = true }
env.render = {}
env.DEBUFF_SIZE, env.DEBUFF_GAP, env.ROW_HEIGHT = 16, 3, 32
env.bossGroup = env.CreateFrame("Frame", nil, env.UIParent)
env.run = env.CreateFrame("Frame", nil, env.UIParent)
env.run:Hide()
env.rowOrder = { { id = 71, columns = 2, debuffs = {}, frame = env.CreateFrame("Frame", nil, env.bossGroup) } }
local row = env.rowOrder[1]
local create = context.Object
function context:Object(...)
    local object = create(self, ...)
    function object:SetBackdrop(value) self.backdrop = value end
    function object:SetBackdropColor(...) self.backdropColor = { ... } end
    return object
end
env.Texture = function(parent) return parent:CreateTexture(nil, "OVERLAY") end
env.T.RegisterTooltipIcon = function() end
env.DFRL.layout.Place = function(name)
    assert(name == "bossBars")
    context.reads.reflow = (context.reads.reflow or 0) + 1
end
env.Read = function(name)
    assert(name == "AZS_GetPhase")
    context.reads.phase = (context.reads.phase or 0) + 1
    return context.phase
end
env.AZS_GetDebuffs = function(id)
    assert(id == 71)
    context.reads.debuffs = (context.reads.debuffs or 0) + 1
    return context.effects
end
env.GameTooltip = {
    IsOwned = function(_, icon) return context.owner == icon end,
    SetOwner = function(_, icon)
        context.owner = icon
        context.reads.opened = (context.reads.opened or 0) + 1
    end,
    Hide = function() context.owner = nil end,
}
env.DebuffTooltip = function(icon, opening)
    context.tooltipEffect, context.tooltipOpening = icon.effect, opening
end
env.ReleaseHUD = function() context.released = true end
env.InvalidateSchedule = function() end
env.RetireEncounters = function() end
env.UpdateRunBoundary = function() context.reads.boundary = (context.reads.boundary or 0) + 1 end
env.UpdateClock = function() context.reads.clock = (context.reads.clock or 0) + 1 end
env.UpdateTally = function() context.reads.tally = (context.reads.tally or 0) + 1 end
local api
env.UpdateRows = function(phase) api.Rows(phase) end
local chunk = assert(loadfile(assert(arg[1], "missing extracted run-debuff source")))
setfenv(chunk, env)
api = chunk()
local function Refresh()
    env.refreshRows = true
    api.Update()
end

Refresh()
local icon = assert(row.debuffs[1])
assert(icon:IsVisible() and icon.count:GetText() == "2" and icon.time:GetText() == "2m")
assert(row.debuffHeight == 19 and row.RefreshDebuffs, "debuff row did not retain its hover refresh")
env.run:Show()
context:ResetCounts()
for _ = 1, 40 do
    api.Update()
end
assert(not context.reads.debuffs and not context.reads.tally, "frame-only clock updates traversed boss debuffs")
assert(context.reads.phase == 40 and context.reads.boundary == 40 and context.reads.clock == 40)
context.effects[1].remaining = 60
Refresh()
assert(context.reads.debuffs == 1 and icon.time:GetText() == "1m", "refresh did not read current native timing")
context.effects[1].remaining = 59.9
context:ResetCounts()
context:Call(icon, "OnEnter")
assert(context.reads.debuffs == 1 and context.reads.phase == 1, "hover reused an old native debuff time")
assert(context.reads.opened == 1 and context.tooltipEffect.remaining == 59.9 and context.tooltipOpening)
assert(icon.time:GetText() == "60", "hover did not refresh the actual countdown label")
context:Call(icon, "OnLeave")
context.phase = "paused"
Refresh()
assert(icon.time:GetText() == "60", "paused debuff time used a private clock")

context.effects = {}
context:ResetCounts()
context:Call(icon, "OnEnter")
assert(context.reads.debuffs == 1 and not context.reads.opened, "expired hover opened stale native effects")
assert(not icon:IsShown() and not icon.effect and row.debuffHeight == 0)
context.effects = { { icon = "SpellIcon", name = "Permanent", permanent = true } }
Refresh()
assert(row.debuffs[1] == icon and icon.time:GetText() == "" and icon.count:GetText() == "")
context.effects = { { icon = "SpellIcon", name = "Unknown timing" } }
Refresh()
assert(icon.time:GetText() == "", "missing native timing gained a countdown")
context.effects = { { icon = "RetryIcon", remaining = 5 } }
context.failTexture = "RetryIcon"
Refresh()
assert(icon.iconPath == nil, "failed texture assignment was cached as ready")
context.failTexture = nil
Refresh()
assert(icon.iconPath == "RetryIcon" and icon.time:GetText() == "5", "texture readiness did not retry")

env.bossGroup:Hide()
context:ResetCounts()
Refresh()
assert(not context.reads.debuffs, "hidden boss view retained debuff getters")
env.bossGroup:Show()
Refresh()
assert(icon.time:GetText() == "5", "visible recovery did not read current native effects")
context.phase = "ready"
context:ResetCounts()
Refresh()
assert(not context.reads.debuffs and not icon:IsShown() and icon.effect == nil)
env.inWorld = false
context:ResetCounts()
api.Update()
assert(context.released and not context.reads.phase and not context.reads.debuffs)
print("PASS boss debuffs use refresh/publication scopes, fresh hover timing, hidden guards, native pauses and retries")
