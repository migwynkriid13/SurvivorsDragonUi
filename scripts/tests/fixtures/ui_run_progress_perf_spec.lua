-- CI only: actual UpdateClock source over explicit native and presentation sinks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "run-progress fixtures require the CI Lua 5.1 interpreter")

local function Clock()
    local context = H.New()
    local env = context.env
    context.maximum, context.schedule = 960, {}
    env.render = { customClock = true, emptySchedule = {} }
    env.AZS_ZONE = { zone = "Elwynn" }
    env.BAR_WIDTH = 280
    env.run = env.CreateFrame("Frame", nil, env.UIParent)
    env.run:Hide()
    function env.run:IsVisible() return self.shown and not context.hidden end
    env.run.RefreshWidth = function() context.reads.width = (context.reads.width or 0) + 1 end
    env.run.affixes = {
        Update = function(_, accepted, force) context.affixes = { accepted = accepted, force = force } end,
    }
    env.runBar = env.CreateFrame("StatusBar", nil, env.run)
    env.runBar.layoutWidth = 280
    function env.runBar:SetMinMaxValues(low, high)
        context.writes.range = (context.writes.range or 0) + 1
        self.minimum, self.maximum = low, high
    end
    function env.runBar:SetValue(value)
        context.writes.value = (context.writes.value or 0) + 1
        self.value = value
    end
    env.Read = function(name)
        assert(name == "AZS_GetRunTime")
        context.reads.time = (context.reads.time or 0) + 1
        return context.seconds
    end
    env.RunLength = function()
        context.reads.length = (context.reads.length or 0) + 1
        return context.maximum
    end
    env.ScheduleMarkers = function(maximum, phase)
        context.reads.schedule = (context.reads.schedule or 0) + 1
        context.scheduleMaximum, context.schedulePhase = maximum, phase
        return context.schedule
    end
    env.ClearRows = function() context.cleared = context.cleared + 1 end
    env.SetRunAppearance = function(atLimit) table.insert(context.appearance, atLimit) end
    env.UpdateRunFlow = function(value, maximum) table.insert(context.flows, { value = value, maximum = maximum }) end
    env.UpdateClockCaptions = function(seconds, maximum, accepted)
        table.insert(context.captions, { seconds = seconds, maximum = maximum, accepted = accepted })
    end
    env.UpdateMarkers = function(maximum, entries)
        table.insert(context.markers, { maximum = maximum, entries = entries })
    end
    env.UpdateMarkerStates = function(atLimit) table.insert(context.states, atLimit) end
    env.TakeOver = function(part)
        assert(part == "clock")
        context.reads.ownership = (context.reads.ownership or 0) + 1
        return true
    end
    env.Restore = function(part)
        assert(part == "clock")
        context.restored = true
    end
    env.ReleaseClock = function() context.released = true end
    function context:ResetPerf()
        self:ResetCounts()
        self.flows, self.captions, self.markers, self.states, self.appearance = {}, {}, {}, {}, {}
        self.cleared = 0
    end
    context:ResetPerf()
    local chunk = assert(loadfile(assert(arg[1], "missing extracted UpdateClock source")))
    setfenv(chunk, env)
    local update = chunk()
    function context:Sample(seconds, phase, refresh)
        self.seconds = seconds
        -- The existing outer controller consumes row refreshes after UpdateClock.
        env.refreshRows = refresh and true or false
        update(phase or "playing")
    end
    return context, env
end

do
    local context, env = Clock()
    for frame = 1, 60 do
        context:Sample(10 + frame / 100)
    end
    assert(context.writes.value == 1 and env.runBar.value == 10, "one native second repainted the fill every frame")
    assert(context.writes.range == 1 and env.runBar.maximum == 960, "unchanged maximum rewrote the range")
    assert(context.reads.time == 60 and context.reads.length == 1 and context.reads.ownership == 60)
    assert(context.reads.schedule == 1, "one refresh scope repeatedly traversed its schedule")
    assert(#context.flows == 60 and #context.captions == 60 and #context.states == 60, "presentation cadence changed")
    for index, flow in ipairs(context.flows) do
        assert(flow.value == 10 and flow.maximum == 960, "effect clipping did not follow the stepped native fill")
        assert(context.captions[index].seconds == 10 + index / 100, "caption input lost native fractional seconds")
        assert(context.appearance[index] == false and context.states[index] == false, "markers reached the limit early")
    end
    context:Sample(11)
    assert(context.writes.value == 2 and env.runBar.value == 11, "the next native integer did not advance the fill")
    context:ResetPerf()
    for _ = 1, 20 do
        context:Sample(11.4, "paused")
    end
    assert(not context.writes.value and #context.flows == 20, "paused progress repainted or stopped cosmetic cadence")
    assert(context.schedulePhase == "paused" and context.captions[20].seconds == 11.4)
    context:Sample(9.8)
    assert(
        context.cleared == 1 and env.refreshRows and env.runBar.value == 9,
        "backward native time did not retire rows"
    )
    context:Sample(9.2)
    assert(
        context.cleared == 2 and env.refreshRows and env.runBar.value == 9,
        "same-integer correction lost retirement"
    )
    assert(context.writes.value == 1 and context.captions[#context.captions].seconds == 9.2)
end
print(
    "PASS native-second progress skips repeated fill writes and retains raw timing, pauses, corrections and cosmetic cadence"
)

do
    local context, env = Clock()
    context.maximum = 10.5
    context:Sample(10.49)
    assert(env.runBar.value == 10 and context.flows[1].value == 10 and context.states[1] == false)
    context:Sample(10.5)
    assert(env.runBar.value == 10.5 and context.flows[2].value == 10.5, "fractional maximum was not filled exactly")
    assert(context.appearance[2] == true and context.states[2] == true, "terminal native input lost marker state")
    context:Sample(12.75)
    assert(context.writes.value == 2 and context.flows[3].value == 10.5, "post-limit progress moved the completed fill")
    assert(context.captions[3].seconds == 12.75 and context.captions[3].maximum == 10.5, "Endless captions were capped")
    env.zoneRunPending = 7
    context:Sample(12.8)
    assert(
        context.captions[4].accepted == false and context.captions[4].seconds == 12.8,
        "publication caption gate changed"
    )
end
print("PASS fractional native limits fill exactly while captions and marker states retain original native inputs")

do
    local context, env = Clock()
    context:Sample(2.2)
    context.hidden = true
    context:ResetPerf()
    context:Sample(50.7, nil, true)
    assert(not context.writes.value and not context.writes.range, "hidden clock wrote its fill")
    assert(#context.flows == 0 and #context.captions == 0 and #context.appearance == 0 and #context.states == 0)
    assert(#context.markers == 0 and env.render.clockHidden and env.runBar.value == 2, "hidden clock painted effects")
    assert(
        context.reads.time == 1 and context.reads.length == 1 and context.reads.ownership == 1,
        "hidden lifecycle stopped"
    )
    context.hidden = false
    context:Sample(50.9)
    assert(env.runBar.value == 50 and context.writes.value == 1, "Show did not paint current native progress")
    assert(context.flows[1].value == 50 and context.captions[1].seconds == 50.9 and not env.render.clockHidden)
    assert(#context.markers == 1 and context.markers[1].entries == context.schedule, "Show lost schedule recovery")
    context:ResetPerf()
    context.maximum = 1200
    context:Sample(50.91, nil, true)
    assert(context.writes.range == 1 and not context.writes.value and env.runBar.maximum == 1200)
    assert(
        context.flows[1].value == 50 and context.flows[1].maximum == 1200,
        "maximum change left stale effect clipping"
    )
    assert(context.captions[1].seconds == 50.91 and context.captions[1].maximum == 1200)
    assert(
        context.markers[1].maximum == 1200 and context.states[1] == false,
        "maximum change retained old marker inputs"
    )
    context:ResetPerf()
    env.render.customClock = false
    context:Sample(51)
    assert(
        context.restored and not context.reads.time and #context.flows == 0,
        "feature-off read or painted the custom clock"
    )
end
print(
    "PASS hidden and disabled progress stays idle, showing uses current native time and maximum changes remain authoritative"
)

do
    local context, env = Clock()
    context:Sample(1)
    context:ResetPerf()
    context.maximum, context.schedule = 1200, { { index = 1, at = 1200 } }
    context:Sample(1.01)
    assert(not context.reads.length and not context.reads.schedule and env.runBar.maximum == 960)
    assert(context.reads.time == 1 and context.reads.ownership == 1, "data caching delayed raw time or ownership")
    context:Sample(1.02, nil, true)
    assert(context.reads.length == 1 and context.reads.schedule == 1 and env.runBar.maximum == 1200)
    assert(context.markers[#context.markers].entries == context.schedule, "deferred data did not replace the cache")
    context:ResetPerf()
    context:Sample(1.02, "paused")
    assert(context.reads.length == 1 and context.reads.schedule == 1, "phase change retained schedule sampling")
    context.maximum = nil
    context:Sample(1.02, nil, true)
    assert(context.released, "missing duration retained a visible clock")
    context.maximum = 900
    context:Sample(1.03, nil, true)
    assert(env.runBar.maximum == 900, "existing retry scope did not recover duration")
end
print(
    "PASS duration and schedule reuse their refresh scope while phases, deferred reads and missing-data retries remain fresh"
)
