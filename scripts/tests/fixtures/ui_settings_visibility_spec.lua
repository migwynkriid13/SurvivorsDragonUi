-- CI only: production settings listeners with explicit native visibility/font boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "settings visibility fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local values = {
    performanceMode = false,
    sctScale = 1,
    damageIcons = true,
    meterRows = 6,
    tallyStyle = 1,
    customRunTimer = true,
}
local reads, styled, measured = 0, 0, 0
env.DFRL.display.Get = function(key)
    reads = reads + 1
    return values[key]
end
env.DFRL.sct = {
    GetMode = function()
        reads = reads + 1
        return "on"
    end,
    GetIncoming = function()
        reads = reads + 1
        return true
    end,
}
local function Frame(parent) return env.CreateFrame("Frame", nil, parent or env.UIParent) end
local function Check(parent)
    local control = Frame(parent)
    function control:SetChecked(value)
        self.editorChecked = value
        self:SetAlpha(value and 1 or 0.5)
    end
    return control
end
local function Choice(parent)
    local control = Frame(parent)
    function control:SetSelected(value) self.editorSelected = value end
    return control
end
env.fontEditor = Frame()
local combat, timer = Frame(env.fontEditor), Frame(env.fontEditor)
env.incomingControl = Check(combat)
env.sctDescription = combat:CreateFontString(nil, "OVERLAY")
env.sctSizeLabel = combat:CreateFontString(nil, "OVERLAY")
env.sctButtons = { on = Choice(combat), off = Choice(combat) }
env.fontEditor.combatSettings = { frame = combat, controls = { env.incomingControl } }
env.displayControls = { performanceMode = Check(env.fontEditor), damageIcons = Check(combat) }
env.displayNumbers = { meterRows = combat:CreateFontString(nil, "OVERLAY") }
env.dependentSettings = { customRunTimer = { frame = timer, controls = { Check(timer) } } }
env.fontEditor.tallyStyleButtons = { Choice(timer) }
env.fontSample = timer:CreateFontString(nil, "OVERLAY")
env.fontSample:Hide() -- The production source is hidden; its page owns the rendered parts.
env.fontSampleClock = { source = env.fontSample, ruler = timer:CreateFontString(nil, "OVERLAY"), parts = {} }
env.T.GetDefaultFont = function() return "DEFAULT_TEST" end
env.currentFont = { face = "DEFAULT", size = 12, outline = "", shadow = true }
env.fontFaces, env.fontOutlines = { { face = "DEFAULT", label = "Default" } }, { { value = "" } }
env.faceLabel, env.sizeLabel = timer:CreateFontString(nil, "OVERLAY"), timer:CreateFontString(nil, "OVERLAY")
env.faceButtons, env.outlineButtons = { DEFAULT = Choice(timer) }, { [""] = Choice(timer) }
env.shadowControl = Check(timer)
env.StyleClockLabel = function(clock, settings)
    assert(clock.source:GetParent():IsVisible(), "hidden sample reached native font work")
    styled = styled + 1
    if not context.failFont then clock.source:SetFont("DEFAULT_TEST", settings.size, settings.outline) end
    clock.ruler:SetFont("DEFAULT_TEST", settings.size, settings.outline)
end
env.RefreshClockLabel = function(clock)
    assert(clock.source:GetParent():IsVisible(), "hidden sample reached glyph measurement")
    measured = measured + 1
end
local source = assert(loadfile(arg[1]))
setfenv(source, env)
local views = source()
env.fontEditor:Hide()
context:ResetCounts()
views.Display()
views.SCT()
views.Font()
assert(reads == 0 and styled == 0 and measured == 0, "closed settings retained source/font work")
context:NoPresentationWrites()

env.fontEditor:Show()
combat:Hide()
timer:Hide()
context:ResetCounts()
views.Display()
views.SCT()
views.Font()
assert(reads == 1 and styled == 0 and measured == 0, "unselected pages retained setting/font reads")
assert(env.displayControls.damageIcons.editorChecked == nil, "hidden checkbox was painted")
values.damageIcons = false
combat:Show()
views.Display()
views.SCT()
assert(env.displayControls.damageIcons.editorChecked == false, "shown category did not catch up")
assert(env.incomingControl.editorChecked == true and env.sctButtons.on.editorSelected, "shown SCT choices are stale")
context:ResetCounts()
views.Display()
views.SCT()
context:NoPresentationWrites()

timer:Show()
views.Display()
assert(env.dependentSettings.customRunTimer.enabled == true, "shown dependency did not catch up")
views.Font()
assert(styled == 1, "showing the sample's page did not prepare it")
context:ResetCounts()
views.Font()
assert(styled == 1 and measured == 1, "unchanged font controls repeated native font assignments")
context:NoPresentationWrites()
timer:Hide()
env.currentFont.size = 18
views.Font()
assert(styled == 1 and measured == 1, "hidden font choice was painted early")
timer:Show()
context.failFont = true
views.Font()
assert(styled == 2, "deferred font choice did not catch up on Show")
context.failFont = false
views.Font()
assert(styled == 3, "failed native sample font assignment was cached as successful")
print("PASS closed/category-hidden settings, current-value catch-up, unchanged labels and deferred font work")
