-- CI only: actual UpdateClock source over explicit native and presentation sinks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "run-progress fixtures require the CI Lua 5.1 interpreter")

local function Clock()
    local context = H.New()
    local env = context.env
    context.maximum, context.schedule, context.mode = 960, {}, "Regular"
    env.render = { customClock = true, emptySchedule = {} }
    env.AZS_ZONE = { zone = "Elwynn" }
    env.AZS_RUN, env.runSequence = { t = 0, endl = 0, nb = 30 }, 0
    env.BAR_WIDTH = 280
    env.run = env.CreateFrame("Frame", nil, env.UIParent)
    env.run:SetWidth(296)
    env.run:Hide()
    function env.run:IsVisible() return self.shown and not context.hidden end
    env.run.RefreshWidth = function(width)
        context.reads.width = (context.reads.width or 0) + 1
        context.paintedWidth = width
    end
    env.run.affixes = {
        Update = function(_, accepted, force) context.affixes = { accepted = accepted, force = force } end,
        HeroicLevel = function(_, accepted) return accepted and context.heroicRank or nil end,
    }
    env.run.heroicLevel = {
        Update = function(_, rank, maximum, width)
            context.numeral = { rank = rank, maximum = maximum, width = width }
            context.reads.numeral = (context.reads.numeral or 0) + 1
        end,
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
    env.SetRunAppearance = function(heroic, endless)
        context.appearanceHeroic = heroic
        table.insert(context.appearance, endless)
    end
    env.UpdateRunFlow = function(value, maximum, advancing)
        table.insert(context.flows, { value = value, maximum = maximum, advancing = advancing })
    end
    env.UpdateClockCaptions = function(seconds, maximum, accepted)
        table.insert(context.captions, { seconds = seconds, maximum = maximum, accepted = accepted })
        return accepted and context.mode or nil
    end
    env.RefreshTimerCaptions = function() end
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
    function context:Sample(seconds, phase, refresh, elapsed)
        self.seconds = seconds
        self.now = self.now + (elapsed or 0)
        env.render.clockNow = self.now
        -- The existing outer controller consumes row refreshes after UpdateClock.
        env.refreshRows = refresh and true or false
        update(phase or "playing")
    end
    function context:PublishRun(time)
        env.AZS_RUN.t = time
        env.runSequence = env.runSequence + 1
    end
    return context, env
end

do
    local context, env = Clock()
    context:Sample(10.25)
    for frame = 1, 32 do
        context:Sample(10.25 + frame / 32, nil, frame % 3 == 0, 1 / 32)
    end
    assert(context.writes.value == 1 and env.runBar.value == 10, "fill moved within a native two-second step")
    assert(context.writes.range == 1 and env.runBar.maximum == 960, "unchanged maximum rewrote the range")
    assert(context.reads.time == 2, "row refreshes reread elapsed time between displayed seconds")
    assert(context.reads.width == 1 and context.paintedWidth == 296, "settled timer resampled its pill width")
    assert(context.reads.length == 2 and context.reads.schedule == 2, "schedule did not use one-second fallback")
    assert(#context.markers == 1, "unrelated row refreshes prepared unchanged markers")
    assert(context.reads.ownership == 33, "native ownership lost frame cadence")
    assert(#context.flows == 33 and #context.states == 33, "throttling native clock reads slowed cosmetic presentation")
    for index, flow in ipairs(context.flows) do
        assert(flow.value == 10 and flow.maximum == 960, "effect clipping did not follow the stepped native fill")
        assert(context.appearance[index] == false and context.states[index] == false, "markers reached the limit early")
    end
    assert(context.captions[1].seconds == 10.25 and context.captions[2].seconds == 11)
    context:Sample(11.75, nil, false, 0.5)
    assert(context.writes.value == 1 and env.runBar.value == 10, "fill advanced before two native seconds")
    context:Sample(12, nil, false, 0.25)
    assert(
        context.writes.value == 2 and env.runBar.value == 12,
        "the next native two-second step did not advance the fill"
    )
    assert(context.flows[#context.flows].advancing, "ordinary fill growth did not defer cosmetic writes")
    context:ResetPerf()
    for _ = 1, 20 do
        context:Sample(12.4, "paused", false, 1 / 32)
    end
    assert(not context.writes.value and #context.flows == 20, "paused progress repainted or stopped cosmetic cadence")
    assert(context.schedulePhase == "paused" and context.captions[1].seconds == 12.4)
    assert(context.reads.time == 1, "paused frames repeatedly read the native clock")
    context:Sample(9.8)
    assert(
        context.cleared == 1 and env.refreshRows and env.runBar.value == 8,
        "backward native time did not retire rows"
    )
    assert(not context.flows[#context.flows].advancing, "a backward correction was classified as ordinary growth")
    env.render.clockNextAt = nil
    context:Sample(9.2)
    assert(context.cleared == 2 and env.refreshRows and env.runBar.value == 8, "same-step correction lost retirement")
    assert(context.writes.value == 1 and context.captions[#context.captions].seconds == 9.2)
end
print(
    "PASS native two-second progress skips repeated fill writes and retains raw timing, pauses, corrections and cosmetic cadence"
)

do
    local context, env = Clock()
    context.maximum = 10.5
    context:Sample(10.25)
    assert(env.runBar.value == 10 and context.flows[1].value == 10 and context.states[1] == false)
    context:Sample(10.5, nil, false, 0.25)
    assert(env.runBar.value == 10.5 and context.flows[2].value == 10.5, "fractional maximum was not filled exactly")
    assert(not context.flows[2].advancing, "reaching the fractional limit was classified as ordinary growth")
    assert(
        context.appearance[2] == false and context.states[2] == true,
        "elapsed time inferred Endless or lost marker state"
    )
    context:Sample(12.75, nil, false, 2.25)
    assert(context.writes.value == 2 and context.flows[3].value == 10.5, "post-limit progress moved the completed fill")
    assert(context.captions[3].seconds == 12.75 and context.captions[3].maximum == 10.5, "Endless captions were capped")
    env.zoneRunPending = 7
    context:PublishRun(12.75)
    context:Sample(12.8, nil, true, 0.05)
    assert(context.captions[4].accepted == false, "publication caption gate changed")
end
print("PASS fractional native limits fill exactly while captions and marker states retain original native inputs")

do
    local context, env = Clock()
    context:Sample(2.2)
    context.hidden = true
    context:ResetPerf()
    env.run:SetWidth(336)
    env.run.widthDirty = true
    context:Sample(50.7, nil, true, 48.5)
    assert(not context.writes.value and not context.writes.range, "hidden clock wrote its fill")
    assert(not context.reads.width, "hidden clock applied pending pill geometry")
    assert(#context.flows == 0 and #context.captions == 0 and #context.appearance == 0 and #context.states == 0)
    assert(#context.markers == 0 and env.render.clockHidden and env.runBar.value == 2, "hidden clock painted effects")
    assert(
        context.reads.time == 1 and context.reads.length == 1 and context.reads.ownership == 1,
        "hidden lifecycle stopped"
    )
    context.hidden = false
    context:Sample(50.9, nil, false, 0.2)
    assert(env.runBar.value == 50 and context.writes.value == 1, "Show did not paint current native progress")
    assert(context.reads.width == 1 and context.paintedWidth == 336, "Show missed a hidden width change")
    assert(context.flows[1].value == 50 and context.captions[1].seconds == 50.9 and not env.render.clockHidden)
    assert(#context.markers == 1 and context.markers[1].entries == context.schedule, "Show lost schedule recovery")
    context:ResetPerf()
    context.maximum = 1200
    env.render.clockScheduleAt = nil
    context:Sample(50.91, nil, true, 0.01)
    assert(context.writes.range == 1 and not context.writes.value and env.runBar.maximum == 1200)
    assert(
        context.flows[1].value == 50 and context.flows[1].maximum == 1200,
        "maximum change left stale effect clipping"
    )
    assert(math.floor(context.captions[1].seconds) == 50 and context.captions[1].maximum == 1200)
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
    context:Sample(1.125)
    context:ResetPerf()
    context.maximum, context.schedule = 1200, { { index = 1, at = 1200, state = "up" } }
    context:Sample(1.25, nil, true, 0.125)
    assert(not context.reads.length and not context.reads.schedule and env.runBar.maximum == 960)
    assert(
        not context.reads.time and context.reads.ownership == 1,
        "row refresh changed the clock or ownership cadence"
    )
    -- The native event invalidates the deadline, then the next reader frame sees parsed data.
    env.render.clockScheduleAt = nil
    context:Sample(1.375, nil, true, 0.125)
    assert(context.reads.length == 1 and context.reads.schedule == 1 and env.runBar.maximum == 1200)
    assert(context.markers[#context.markers].entries == context.schedule, "publication did not replace the cache")
    context:ResetPerf()
    context.schedule = { { index = 1, at = 1200, state = "dead" } }
    context:Sample(2.25, nil, true, 0.875)
    assert(not context.reads.schedule, "schedule reread before its one-second fallback")
    context:Sample(2.375, nil, false, 0.125)
    assert(context.reads.schedule == 1 and context.markers[#context.markers].entries == context.schedule)
    context:ResetPerf()
    context:Sample(2.375, "paused")
    assert(context.reads.length == 1 and context.reads.schedule == 1, "phase change retained schedule sampling")
    context.maximum = nil
    env.render.clockScheduleAt = nil
    context:Sample(2.375, "paused", true)
    assert(context.released, "missing duration retained a visible clock")
    context.maximum = 900
    context:Sample(2.375, "paused", true, 1)
    assert(env.runBar.maximum == 900, "fallback did not recover duration")
end
print("PASS schedule updates on native publication and uses a one-second fallback independently of row wakes")

do
    local context, env = Clock()
    context:Sample(10.125)
    context:ResetPerf()
    for _, time in ipairs({ 10.25, 10.375, 10.5 }) do
        context:PublishRun(time)
        context:Sample(time, nil, true, 0.125)
    end
    assert(not context.reads.time and not context.reads.length and not context.reads.schedule)
    context:PublishRun(11)
    context:Sample(11.125, nil, true, 0.125)
    assert(context.reads.time == 1 and context.captions[#context.captions].seconds == 11.125)
    assert(not context.reads.schedule, "a plain elapsed-clock publication refreshed the boss schedule")
    env.AZS_RUN.bs = 1
    context:PublishRun(11.25)
    context:Sample(11.25, nil, true, 0.125)
    assert(context.reads.schedule == 1, "boss progression publication did not reconcile the accepted schedule")
    assert(context.reads.time == 1, "boss progression reread the current elapsed second")
end
print("PASS run publications wake only new elapsed seconds and changed boss schedule inputs")

do
    local context, env = Clock()
    context.heroicRank = 4
    context:Sample(900, nil, true)
    assert(context.numeral.rank == 4 and context.numeral.maximum == 960 and context.numeral.width == 280)
    env.zoneRunPending = 7
    context:PublishRun(900)
    context:Sample(900, nil, true)
    assert(context.numeral.rank == nil, "pending new-zone handshake replayed the old Heroic rank")
    env.zoneRunPending = nil
    env.runBar.layoutWidth = 560
    context:Sample(900)
    assert(context.numeral.rank == 4 and context.numeral.width == 560, "width change lost accepted rank geometry")
    context.hidden = true
    context:ResetPerf()
    context:Sample(900, nil, true)
    assert(not context.reads.numeral, "Layout-hidden timer refreshed the static numeral")
end
print("PASS Heroic rank follows the native handshake and visible geometry refresh")

do
    local context, env = Clock()
    context.heroicRank, context.mode = 2, "Endless"
    context:Sample(42.5, nil, true)
    assert(env.runBar.value == 960 and context.appearance[1] == true, "accepted Endless did not fill the bar")
    assert(context.appearanceHeroic == 2 and context.numeral.rank == 2, "Endless replaced the accepted Heroic rank")
    assert(context.captions[1].seconds == 42.5, "full Endless rendering changed native elapsed time")
    context.mode = "Regular"
    context:PublishRun(42.6)
    context:Sample(42.6)
    assert(env.runBar.value == 42 and context.appearance[2] == false, "regular mode retained full Endless progress")
    context.mode = "Endless"
    env.zoneRunPending = 9
    context:PublishRun(42.7)
    context:Sample(42.7, nil, true)
    assert(env.runBar.value == 42 and context.appearance[3] == false, "pending run accepted the previous Endless flag")
    assert(context.appearanceHeroic == nil, "pending run retained the previous Heroic palette")
    env.zoneRunPending, context.mode = nil, nil
    context:PublishRun(1000)
    context:Sample(1000, nil, false, 957.3)
    assert(
        context.appearance[4] == false and env.runBar.value == 960,
        "elapsed time selected Endless without an accepted flag"
    )
end
print("PASS accepted API mode owns full Endless presentation without changing native time or inferring a mode")
