-- CI only: production caption formatting and native measurement retry lifecycle.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
env.DFRL.locale.code = "en"
env.DFRL.locale.Text = function(value)
    if env.DFRL.locale.code == "de" then
        if value == "RUN" then return "LAUF" end
        if value == "BOSS IN: %s" then return "BOSS: %s" end
    end
    return value
end
env.string = {}
for name, value in pairs(string) do
    env.string[name] = value
end
env.string.format = function(...)
    context.formats = (context.formats or 0) + 1
    return string.format(...)
end
local parent = env.CreateFrame("Frame", nil, env.UIParent)
parent.scale = 1
function parent:GetEffectiveScale() return self.scale end
local make = context.Object
function context:Object(...)
    local object = make(self, ...)
    function object:GetStringWidth()
        context.reads.measure = (context.reads.measure or 0) + 1
        if context.missingMetrics then return 0 end
        local _, size = self:GetFont()
        return string.len(self:GetText()) * (size or 14) / 2
    end
    return object
end
env.UpdateRunFontBounds = function() context.bounds = (context.bounds or 0) + 1 end
for _, mode in ipairs({ "Regular", "Endless" }) do
    context.settings["runCurrent" .. mode], context.settings["runText" .. mode] = true, true
    context.settings["bossCountdown" .. mode] = mode == "Endless"
end
context.settings.runMaximumRegular = true
env.AZS_RUN, env.AZS_RUN_UPDATED = { endl = 0, nb = 30.2 }, 1
local chunk = assert(loadfile(assert(arg[1], "missing extracted run caption source")))
setfenv(chunk, env)
local api = chunk()
local runSource, bossSource = parent:CreateFontString(), parent:CreateFontString()
runSource:SetHeight(18)
bossSource:SetHeight(18)
env.runClock, env.bossClock = api.New(runSource), api.New(bossSource, "RUN")
local font = { face = "Fonts\\SKURRI.TTF", size = 14, outline = "OUTLINE", shadow = true }
api.Style(env.runClock, font, false)
api.Style(env.bossClock, font, false)
context.formats = 0
api.Update(10.1, 1200.4, true)
assert(env.runClock.source:GetText() == "RUN 00:10 / 20:00" and env.bossClock.source:GetText() == "")
assert(context.formats == 2, "disabled boss countdown still performed formatting")
assert(env.runClock.caption == nil and env.bossClock.caption == "RUN", "formatting replaced font captions")
api.Style(env.runClock, font, true)
api.Style(env.bossClock, font, false)
assert(type(env.runClock.captionCache) == "table", "formatting cache was not stored independently")
context:ResetCounts()
context.formats = 0
api.Update(10.9, 1200.8, true)
context:NoPresentationWrites()
assert(context.formats == 0, "unchanged displayed seconds reformatted captions")

context.settings.runCurrentRegular, context.settings.runMaximumRegular, context.settings.runTextRegular =
    false, false, false
api.Refresh()
context:ResetCounts()
context.formats = 0
env.AZS_RUN.nb = 99.4
api.Update(45.1, 1300.2, true)
context:NoPresentationWrites()
assert(context.formats == 0, "disabled captions formatted changing native inputs")
context.settings.runCurrentRegular, context.settings.bossCountdownRegular = true, true
api.Refresh()
assert(
    env.runClock.source:GetText() == "00:45" and env.bossClock.source:GetText() == "BOSS IN: 1:40",
    "option preview did not use retained native values"
)
env.DFRL.locale.code = "de"
api.Refresh()
assert(env.bossClock.source:GetText() == "BOSS: 1:40", "language change retained formatted captions")
env.AZS_RUN.endl = 1
api.Update(60.3, 1300.2, true)
assert(env.runClock.source:GetText() == "LAUF 01:00", "Endless mode retained Regular maximum/options")

context:ResetCounts()
context.formats = 0
parent.scale = 1.5
api.Update(60.7, 1300.2, true)
assert(context.reads.measure and context.formats == 0, "format cache blocked an effective-scale refit")
context.missingMetrics = true
font = { face = "DEFAULT", size = 16, outline = "OUTLINE", shadow = true }
api.Style(env.runClock, font, true)
assert(env.runClock.text == nil, "unavailable font metrics were cached as ready")
context:ResetCounts()
context.missingMetrics = false
api.Update(60.8, 1300.2, true)
assert(
    env.runClock.text == "LAUF 01:00" and env.runClock.parts[1]:IsShown(),
    "font preview did not retry unchanged text after metrics recovered"
)
assert(context.formats == 0, "metric readiness retried caption formatting")
api.Clear()
assert(env.runClock.source:GetText() == "" and env.bossClock.source:GetText() == "")
local cleared = env.runClock.captionCache
context:ResetCounts()
api.Clear()
context:NoPresentationWrites()
assert(env.runClock.captionCache == cleared, "settled disabled clock recreated its empty format cache")
api.Update(0, 1300.2, true)
assert(env.runClock.source:GetText() == "LAUF 00:00", "retirement lost the next native zero sample")
print("PASS timer captions cache visible formats and retain preview, language, scale and metric recovery")
