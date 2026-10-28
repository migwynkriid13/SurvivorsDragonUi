-- CI only: production tally sampling and boundaries over explicit native mocks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "tally cadence fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
env.activeRows, env.markers, env.runEffects = {}, {}, {}
context.lossClears = 0
env.render = {
    bossLoss = {
        ClearAll = function(_, rows)
            assert(rows == env.activeRows, "mode transition did not clear the current boss rows")
            context.lossClears = context.lossClears + 1
        end,
    },
}
env.performanceMode = false
context.settings.performanceMode = false
context.settings.highlightAffordableCache = true
local owner = env.CreateFrame("Frame", nil, env.UIParent)
env.tally = env.CreateFrame("Frame", nil, owner)
env.tallyFields = {}
for _, key in ipairs({ "kills", "gold", "chest" }) do
    table.insert(env.tallyFields, { key = key, text = env.tally:CreateFontString(nil, "OVERLAY") })
end
local function Value(key)
    for _, field in ipairs(env.tallyFields) do
        if field.key == key then return field.text:GetText() end
    end
    error("unknown tally field " .. key)
end
local function Values(kills, gold, chest) env.AZS_RUN = { kills = kills, gold = gold, chest = chest, t = 20 } end
env.GetTime = function()
    context.reads.clock = (context.reads.clock or 0) + 1
    return context.now
end
env.tostring = function(value)
    context.reads.formats = (context.reads.formats or 0) + 1
    return tostring(value)
end
env.FitTallyField = function(field)
    context.fitted = context.fitted or {}
    context.fitted[field.key] = field.text:GetText()
    context.reads.fit = (context.reads.fit or 0) + 1
end
env.SetGoldHighlight = function(value) context.highlight = value end
env.TakeOver = function(part)
    assert(part == "tally", "tally sampling changed another native HUD owner")
    context.reads.ownership = (context.reads.ownership or 0) + 1
    return not context.failedOwnership
end
env.Restore = function(part)
    assert(part == "tally")
    context.restored = (context.restored or 0) + 1
end
env.tallyAttachment = {
    ready = true,
    SetShown = function(shown)
        if shown then
            env.tally:Show()
        else
            env.tally:Hide()
        end
    end,
}
env.DFRL.AttachRunTally = function() return false end
env.InvalidateSchedule = function() context.invalidated = true end
env.RetireEncounters = function() context.retired = true end
env.run = env.CreateFrame("Frame", nil, env.UIParent)
env.run:Hide()
env.run.affixes = { Clear = function() context.affixesCleared = true end }
env.HideRunFlow, env.ShowMarkerGlow = function() end, function() end
env.SetRunAppearance = function() error("hidden run timer must not repaint during mode transition") end
env.runSequence, env.packetSequence = 0, 0
local chunk = assert(loadfile(assert(arg[1], "missing extracted tally counter source")))
setfenv(chunk, env)
local api = chunk()
local allocated = table.getn(context.objects)

-- Exercise the exact production Performance Mode branch, without constructing
-- the settings editor, run timer artwork or the rest of the run controller.
local file = assert(io.open("modules/ui/run.lua", "r"))
local source = file:read("*a")
file:close()
local showFirst = assert(string.find(source, '    HookScript(tally, "OnShow", function()', 1, true))
local showLast = assert(string.find(source, "    local function HideDebuff", showFirst, true))
local show = assert(loadstring(string.sub(source, showFirst, showLast - 1)))
setfenv(show, env)
show()
local first = assert(string.find(source, '        local performance = DFRL.display.Get("performanceMode")', 1, true))
local last = assert(string.find(source, "        SyncReplacements()", first, true))
local transition = assert(loadstring("return function()\n" .. string.sub(source, first, last - 1) .. "\nend"))
setfenv(transition, env)
transition = transition()
local function Mode(value)
    local previous, cleared = env.performanceMode, context.lossClears
    context.settings.performanceMode = value
    transition()
    assert(
        context.lossClears == cleared + (previous ~= value and 1 or 0),
        "boss loss must clear only on actual Performance Mode transitions"
    )
end

Values(10.9, 200.8, 300.7)
context:ResetCounts()
api.Update()
assert(Value("kills") == "10" and Value("gold") == "200" and Value("chest") == "300")
Values(11, 201, 301)
api.Update()
assert(Value("kills") == "11" and Value("gold") == "201" and Value("chest") == "301")
assert(not context.reads.clock and context.reads.formats == 6, "normal mode acquired a counter throttle")

context.now = 10
Mode(true)
Values(20, 400, 600)
api.Update()
assert(Value("kills") == "20" and Value("gold") == "400", "first Performance Mode sample was delayed")
context.now = 14.999
Values(21, 401, 601)
context:ResetCounts()
api.Update()
assert(Value("kills") == "20" and Value("gold") == "400", "counter changed before five seconds")
assert(Value("chest") == "601" and context.reads.formats == 1, "cache cost was throttled or held counters formatted")
assert(context.fitted.kills == "20" and context.fitted.gold == "400", "layout fitting did not retain held text")
assert(context.reads.fit == 3 and context.reads.ownership == 1, "counter throttle skipped fit retries or HUD ownership")
context.now = 15
api.Update()
assert(Value("kills") == "21" and Value("gold") == "401", "exact five-second deadline did not sample current counters")

-- Ordinary mode notifications and style/attachment Hide/Show must not reset
-- the same active sampling window and expose more frequent numeric changes.
context.now = 16
Mode(true)
env.tally:Hide()
env.tally:Show()
Values(22, 402, 602)
api.Update()
assert(Value("kills") == "21" and Value("gold") == "401", "unchanged mode or style Show bypassed the interval")
Mode(false)
context:ResetCounts()
api.Update()
assert(Value("kills") == "22" and Value("gold") == "402", "leaving Performance Mode retained held numbers")
assert(not context.reads.clock, "normal-mode restoration still sampled the throttle clock")
context.now = 16.5
Mode(true)
Values(23, 403, 603)
api.Update()
assert(Value("kills") == "23" and Value("gold") == "403", "new mode preview retained a previous sampling window")

owner:Hide()
Values(24, 404, 604)
context.now = 30
context:ResetCounts()
api.Update()
assert(
    not context.reads.clock and not context.reads.formats and not context.reads.fit,
    "hidden tally sampled or formatted numbers"
)
assert(context.reads.ownership == 1, "hidden tally lost required HUD ownership work")
context:NoPresentationWrites()
owner:Show()
api.Update()
assert(Value("kills") == "24" and Value("gold") == "404", "long-hidden recovery replayed the old counter sample")
owner:Hide()
context.now = 31
Values(25, 405, 605)
api.Update()
owner:Show()
api.Update()
assert(
    Value("kills") == "24" and Value("gold") == "404" and Value("chest") == "605",
    "quick re-show bypassed the active interval"
)

-- Invalid data and failed native handoffs retire the tally immediately; its
-- next valid presentation starts with a fresh sample rather than old numbers.
env.AZS_RUN = { kills = 25, gold = 405 }
api.Update()
assert(Value("kills") == "" and Value("gold") == "" and not env.render.tallyCountersAt)
Values(26, 406, 606)
api.Update()
assert(Value("kills") == "26" and Value("gold") == "406", "invalid-data recovery retained the old deadline")
context.failedOwnership = true
api.Update()
assert(Value("kills") == "" and not env.render.tallyCountersAt, "failed native ownership retained a sampled tally")
context.failedOwnership = false
Values(27, 407, 607)
api.Update()
assert(Value("kills") == "27" and Value("gold") == "407", "ownership recovery waited for a retired deadline")

local function Held() assert(env.render.tallyCountersAt, "fixture did not establish a held counter window") end
env.zoneSequence, env.runSequence = 40, 39
Held()
api.Boundary("playing")
assert(not env.render.tallyCountersAt, "zone boundary retained old run's counter deadline")
Values(0, 0, 100)
api.Update()
Held()
env.runSequence = 41
api.Boundary("playing")
assert(not env.render.tallyCountersAt, "new run receipt after zone boundary retained the old deadline")
api.Update()
env.previousPhase, env.previousNativeTime = "playing", 50
env.AZS_RUN.t = 1
api.Boundary("playing")
assert(not env.render.tallyCountersAt, "native run-clock rollback retained counter cadence")
api.Update()
env.previousPhase, env.previousNativeTime = "playing", 1
api.Boundary("ready")
assert(not env.render.tallyCountersAt, "ready transition retained the previous run's cadence")
api.Update()
context.now = 1
Values(1, 2, 3)
api.Update()
assert(Value("kills") == "1" and Value("gold") == "2", "UI clock rollback permanently froze held counters")
assert(table.getn(context.objects) == allocated, "cadence changes allocated drawing objects")
print(
    "PASS only Performance Mode kill/gold text uses five-second sampling with live cache cost and safe lifecycle resets"
)
