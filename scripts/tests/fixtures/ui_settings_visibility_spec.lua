-- CI only: production settings listeners with explicit native visibility/font boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "settings visibility fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local values = {
    performanceMode = false,
    sctScale = 1,
    sctStyle = "diablo",
    sctFont = "diablo",
    sctShortNumbers = false,
    sctClassColors = true,
    damageIcons = true,
    meterRows = 6,
    tallyStyle = 1,
    customRunTimer = true,
    guardianGuidance = true,
    guardianRespawnGuidance = true,
}
local reads, styled, measured = 0, 0, 0
local sctMode = "on"
env.DFRL.display.Get = function(key)
    reads = reads + 1
    return values[key]
end
env.DFRL.sct = {
    GetMode = function()
        reads = reads + 1
        return sctMode
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
local combat, timer, map = Frame(env.fontEditor), Frame(env.fontEditor), Frame(env.fontEditor)
map:Hide()
env.incomingControl = Check(combat)
env.sctDescription = combat:CreateFontString(nil, "OVERLAY")
env.sctSizeLabel = combat:CreateFontString(nil, "OVERLAY")
env.sctButtons = { on = Choice(combat), off = Choice(combat) }
env.fontEditor.sctStyleButtons = { enemy = Choice(combat), msbt = Choice(combat), diablo = Choice(combat) }
env.fontEditor.sctFontButtons = { default = Choice(combat), diablo = Choice(combat) }
env.fontEditor.combatSettings = { frame = combat, controls = { env.incomingControl } }
for _, button in pairs(env.fontEditor.sctStyleButtons) do
    table.insert(env.fontEditor.combatSettings.controls, button)
    local enable = button.EnableMouse
    button.EnableMouse = function(self, value)
        self.styleMouseEnabled = value
        enable(self, value)
    end
end
for _, button in pairs(env.fontEditor.sctFontButtons) do
    table.insert(env.fontEditor.combatSettings.controls, button)
    local enable = button.EnableMouse
    button.EnableMouse = function(self, value)
        self.fontMouseEnabled = value
        enable(self, value)
    end
end
env.displayControls = {
    performanceMode = Check(env.fontEditor),
    damageIcons = Check(combat),
    sctShortNumbers = Check(combat),
    sctClassColors = Check(combat),
    guardianRespawnGuidance = Check(map),
}
for _, key in ipairs({ "sctShortNumbers", "sctClassColors" }) do
    local control = env.displayControls[key]
    table.insert(env.fontEditor.combatSettings.controls, control)
    local enable = control.EnableMouse
    control.EnableMouse = function(self, value)
        self.inputEnabled = value
        enable(self, value)
    end
end
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
assert(env.fontEditor.sctStyleButtons.diablo.editorSelected, "shown style selection is stale")
assert(env.fontEditor.sctFontButtons.diablo.editorSelected, "shown font selection is stale")
local classColors = env.displayControls.sctClassColors
assert(
    classColors.editorChecked and classColors.editorAvailable == false and classColors.inputEnabled == false,
    "Diablo did not retain and disable class colors"
)
assert(classColors:GetAlpha() == 0.45, "inactive class color option was not dimmed")
assert(env.displayControls.sctShortNumbers.inputEnabled, "abbreviation is unavailable in Custom")
assert(
    env.sctDescription:GetText() == "Diablo IV numbers burst around enemies; amber highlights big criticals.",
    "style description is stale"
)
context:ResetCounts()
views.Display()
views.SCT()
context:NoPresentationWrites()
sctMode = "off"
views.SCT()
assert(not env.displayControls.sctShortNumbers.inputEnabled, "non-Custom mode retained abbreviation input")
for _, button in pairs(env.fontEditor.sctStyleButtons) do
    assert(button.styleMouseEnabled == false, "non-Custom mode retained style input")
end
assert(combat:GetAlpha() == 0.45 and values.sctStyle == "diablo", "inactive mode lost its dimming or saved style")
assert(
    env.fontEditor.sctFontButtons.diablo.fontMouseEnabled == false and values.sctFont == "diablo",
    "inactive font input"
)
sctMode = "on"
views.SCT()
assert(env.fontEditor.sctFontButtons.diablo.fontMouseEnabled, "Custom did not restore font input")
assert(
    env.displayControls.sctShortNumbers.inputEnabled and not classColors.inputEnabled,
    "mode transition enabled class colors in Diablo or disabled abbreviation"
)
values.sctStyle = "enemy"
views.SCT()
assert(
    classColors.inputEnabled and classColors:GetAlpha() == 1 and values.sctClassColors,
    "leaving Diablo lost the saved class-color choice"
)
values.sctStyle = "diablo"
views.SCT()
assert(not classColors.inputEnabled and classColors:GetAlpha() == 0.45, "Diablo retained class-color input")
assert(
    env.fontEditor.sctStyleButtons.diablo.styleMouseEnabled and combat:GetAlpha() == 1,
    "Custom did not restore style input"
)

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
local respawnControl = env.displayControls.guardianRespawnGuidance
local enableRespawnMouse = respawnControl.EnableMouse
function respawnControl:EnableMouse(value)
    self.inputEnabled = value
    enableRespawnMouse(self, value)
end
map:Show()
views.Display()
assert(respawnControl.editorAvailable and respawnControl.editorChecked, "shown respawn option did not catch up")
values.guardianGuidance = false
views.Display()
assert(
    respawnControl.editorAvailable == false
        and respawnControl.inputEnabled == false
        and respawnControl:GetAlpha() == 0.45
        and respawnControl.editorChecked,
    "disabled guardian guidance did not dim the respawn option while retaining its value"
)
context:ResetCounts()
views.Display()
context:NoPresentationWrites()
values.guardianGuidance = true
views.Display()
assert(
    respawnControl.editorAvailable and respawnControl.inputEnabled and respawnControl:GetAlpha() == 1,
    "respawn option did not become available"
)
print("PASS closed/category-hidden settings, current-value catch-up, unchanged labels and deferred font work")
