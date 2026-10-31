-- CI only: production roster timing and extracted minimap pin lifecycle.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "guardian timer fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
local phase, now = "playing", 100
env.AZS_GetPhase = function() return phase end
env.AZS_GetRunTime = function()
    context.reads.clock = (context.reads.clock or 0) + 1
    return now
end
env.DFRL.navigation = {
    IsRunPhase = function(value) return value == "playing" or value == "paused" or value == "choosing" end,
    MinimapLevel = function() return 11 end,
    GuideDelta = function(entry) return entry.x, entry.y, nil, true end,
}
env.navigation = env.DFRL.navigation
env.texturePath = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\waypoint\\"
env.Minimap = env.CreateFrame("Frame", nil, env.UIParent)
local setNativeFont = env.T.SetFont
env.T.SetFont = function(label, size, flags)
    setNativeFont(label, size, env.T.GetFontFlags(flags))
    -- Native GetFont may report the resolved path instead of the requested alias.
    label.font[1] = "Fonts\\FRIZQT__.TTF"
end
env.T.SetChatShadow = function(label)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
end
env.T.RegisterTooltipIcon = function() end
env.T.CreateDefeatedMarkerCheck = function(parent) return parent:CreateTexture(nil, "OVERLAY") end
env.T.StyleDefeatedMarker = function() end
context:Load("core/display.lua", "Display")
context:Load("modules/ui/guardians.lua", "GuardianRoster")
local display, roster = env.DFRL.display, env.DFRL.guardians
local chunk = assert(loadfile(assert(arg[1], "missing extracted guardian timer source")))
setfenv(chunk, env)
local Update = chunk()
local entry = { key = "1:0", index = 1, id = 0, state = "empty", left = 12, x = 0, y = 0 }
local tracker = {
    kind = "guardian",
    displayKey = "guardianGuidance",
    hudArt = "GuardianFloating.blp",
    hudTexCoord = { 0, 65 / 128, 0, 65 / 128 },
    minimapPins = {},
    minimapPool = {},
    minimapCycle = 0,
    entries = {},
    acceptedMinimapEntries = { entry },
}
local function Timers(enabled)
    display.Set("guardianMinimapTimers", enabled)
    env.showGuardianTimers = display.Get("guardianMinimapTimers")
end
local function Publish(left)
    entry.left = left
    roster.AcceptLairs({ entry }, now, now)
end
local function Paint(refresh, scale) Update(tracker, scale, 40, refresh) end

assert(display.Get("guardianMinimapTimers") == false, "guardian timers must default off")
assert(display.Copy({ guardianMinimapTimers = "true" }).guardianMinimapTimers == false, "invalid timer default")
display.BeginEdit()
Timers(true)
assert(not env.SurvivorsDragonUiDisplay, "timer preview saved early")
display.FinishEdit(false)
assert(not display.Get("guardianMinimapTimers"), "timer Cancel retained the preview")
display.BeginEdit()
Timers(true)
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.guardianMinimapTimers, "Confirm lost the timer choice")
display.BeginEdit()
display.Load({ guardianMinimapTimers = false })
assert(not display.Get("guardianMinimapTimers"), "profile did not preview timers off")
display.FinishEdit(false)
assert(display.Get("guardianMinimapTimers"), "profile Cancel lost the confirmed choice")
display.Reset()
assert(not display.Get("guardianMinimapTimers"), "reset did not restore timers off")
display.BeginEdit()
Timers(false)
Publish(12)
context:ResetCounts()
Paint(true, 1)
assert(not next(tracker.minimapPins) and not context.reads.clock, "off timers retained defeated pins or read time")

Timers(true)
context:ResetCounts()
Paint(true, 1)
local pin = assert(tracker.minimapPins[entry.key], "timers did not retain their defeated icon")
local label = assert(pin.timer, "timer label was not created lazily")
assert(label:GetText() == "0:12" and label:IsVisible(), "initial guardian timer missing")
assert(label.width == 64 and label.height == 15, "timer needs explicit native text bounds")
assert(label.font[1] == "Fonts\\FRIZQT__.TTF", "resolved font path was rejected")
assert(env.T.NearlyEqual(label.font[2], 8.6) and label.font[3] == "OUTLINE", "timer font styling changed")
local allocated = #context.objects
context:ResetCounts()
Paint(true, 1)
context:NoPresentationWrites()
assert(#context.objects == allocated, "unchanged timer allocated another label")
context:ResetCounts()
Paint(false, 1)
assert(not context.reads.clock, "per-frame pin projection sampled the countdown")
context:NoPresentationWrites()
now = 101
Paint(true, 1)
assert(label:GetText() == "0:11", "countdown did not follow native run time")
phase = "paused"
context:ResetCounts()
Paint(true, 1)
context:NoPresentationWrites()
assert(label:GetText() == "0:11", "paused countdown moved")
phase = "choosing"
Paint(true, 1)
assert(label:GetText() == "0:11", "card choice moved the countdown")
phase, now = "playing", 150
Paint(true, 1)
assert(label:GetText() == "0:11", "stale sample exceeded the bounded smoothing")
now = 99
Paint(true, 1)
assert(label:GetText() == "0:12", "regressed native time invented progress")
now = nil
Paint(true, 1)
assert(label:GetText() == "0:12", "missing native clock hid the received countdown")
now = 200
Publish(65)
Paint(true, 1)
assert(label:GetText() == "1:05", "minute formatting changed")
Publish(0)
Paint(true, 1)
assert(label:GetText() == "0:00", "native due value invented a respawn")
for _, left in ipairs({ -1, false, 0 / 0 }) do
    now = now + 1
    Publish(left)
    Paint(true, 1)
    assert(not label:IsShown() and label:GetText() == "", "unknown countdown retained old text")
end
now = now + 1
Publish(30)
Paint(true, 1)
assert(label:IsVisible(), "valid countdown did not recover")
context:ResetCounts()
Paint(true, nil)
assert(not context.reads.clock and not label:IsShown(), "hidden minimap painted or sampled countdowns")
assert(not next(tracker.minimapPins), "hidden minimap retained an active pin")
Paint(true, 1)
assert(tracker.minimapPins[entry.key] == pin and #context.objects == allocated, "pin label pool was not reused")
display.Set("keepDefeatedGuardianIcons", true)
Timers(false)
context:ResetCounts()
Paint(true, 1)
assert(tracker.minimapPins[entry.key] == pin and not label:IsShown(), "timers off changed retained icons")
assert(not context.reads.clock, "timers off still sampled the clock")
Timers(true)
entry.key, entry.id, entry.state = "1:42", 42, "awake"
tracker.entries = { entry }
now = now + 1
Publish(30)
Paint(true, 1)
local living = tracker.minimapPins[entry.key]
assert(living and not living.timer, "living guardian allocated a respawn label")
assert(not label:IsShown(), "returned guardian retained a respawn countdown")
entry.key, entry.id, entry.state = "1:0", 0, "empty"
tracker.entries = {}
now = now + 1
Publish(30)
Paint(true, 1)
pin = tracker.minimapPins[entry.key]
assert(pin.timer:IsVisible(), "returning pin did not recover its pooled label")
roster.Clear()
Paint(true, 1)
assert(not pin.timer:IsShown(), "retired roster retained a countdown")
now = now + 1
Publish(30)
pin.timerFontReady = nil
local setFont = env.T.SetFont
env.T.SetFont = function() return false end
pin.timer.font = nil
Paint(true, 1)
assert(not pin.timer:IsShown(), "failed font displayed uninitialized text")
env.T.SetFont = setFont
Paint(true, 1)
assert(pin.timer:IsVisible(), "failed timer font was not retried")
local originalFlags = env.T.GetFontFlags
for _, outline in ipairs({ "", "THICKOUTLINE" }) do
    -- Model the shared font owner's effective style without loading it here.
    env.T.GetFontFlags = function() return outline end
    pin.timerFontReady = nil
    pin.timer:Hide()
    Paint(true, 1)
    assert(pin.timer:IsVisible() and pin.timer.font[3] == outline, "global outline blocked countdown readiness")
    context:ResetCounts()
    Paint(true, 1)
    context:NoPresentationWrites()
end
env.T.GetFontFlags = originalFlags
local other = { key = "2:0", index = 2, id = 0, state = "empty", left = 20, x = 10, y = 0 }
tracker.acceptedMinimapEntries = { entry, other }
now = now + 1
roster.AcceptLairs({ entry, other }, now, now)
context:ResetCounts()
Paint(true, 1)
assert(context.reads.clock == 1, "multiple guardian timers sampled separate clocks")
display.Set("guardianGuidance", false)
context:ResetCounts()
Paint(true, 1)
assert(not context.reads.clock and not next(tracker.minimapPins), "disabled guidance retained timers or read time")
display.Set("guardianGuidance", true)
Paint(true, 1)
tracker.acceptedMinimapEntries = { entry }
context.failText = "0:24"
now = now + 1
Publish(24)
Paint(true, 1)
assert(not tracker.minimapPins[entry.key], "failed text assignment retained a partially painted pin")
Paint(true, 1)
assert(tracker.minimapPins[entry.key].timer:GetText() == "0:24", "failed timer text was not retried")
print("PASS guardian timer defaults, drafts, native timing, idle work, lazy pooling and retirement")

do
    local party = {
        kind = "party",
        displayKey = "partyGuidance",
        hudArt = "FallenAlly.blp",
        hudTexCoord = { 0, 1, 0, 1 },
        minimapPins = {},
        minimapPool = {},
        minimapCycle = 0,
        entries = {},
    }
    for index = 1, 4 do
        party.entries[index] = { key = "party" .. index, x = 100 * index, y = 50 * index }
    end
    Update(party, 1, 40, true)
    local first = party.minimapPins.party1
    assert(first and first.drawnX == 40 and first.drawnY == 20, "distant fallen ally did not clamp to the minimap edge")
    assert(first:GetWidth() == 20 and not first.check and not first.timer, "fallen ally inherited guardian decorations")
    assert(party.entries[1].x == 100, "pin placement changed native destination data")
    local allocations = #context.objects
    context:ResetCounts()
    Update(party, 1, 40, true)
    context:NoPresentationWrites()
    assert(
        #context.objects == allocations and not context.reads.clock,
        "unchanged party pins allocated or read respawn time"
    )
    for index = 1, 4 do
        party.entries[index] = { key = "replacement" .. index, x = 20, y = 10 }
    end
    Update(party, 1, 40, true)
    assert(#context.objects == allocations and #party.minimapPool == 0, "a replaced roster expanded the four-pin pool")
    party.entries[1].x = nil
    Update(party, 1, 40, true)
    assert(not party.minimapPins.replacement1, "failed geometry retained a pre-recycled party pin")
    party.entries[1].x = 20
    Update(party, 1, 40, true)
    assert(#context.objects == allocations, "recovered geometry expanded the pin pool")
    party.entries = {}
    Update(party, 1, 40, true)
    assert(
        not next(party.minimapPins) and #party.minimapPool == 4 and not first:IsShown(),
        "retired party pins were not recycled"
    )
    party.entries = { { key = "replacement", x = 0, y = 0 } }
    Update(party, 1, 40, true)
    assert(
        party.minimapPins.replacement and #context.objects == allocations,
        "replacement member bypassed the existing pin pool"
    )
    display.Set("partyGuidance", false)
    Update(party, 1, 40, true)
    assert(not next(party.minimapPins), "disabled party guidance retained its minimap pin")
    print("PASS four Winged Soul minimap pins share edge clamping, unchanged writes and retirement pooling")
end

do
    local navigationContext = H.New()
    local native = navigationContext.env
    local currentPhase, browsing, mapName, playerX, playerY = "playing", false, "CurrentZone", 0.5, 0.5
    local facing, facingReady, positionReady = 0.25, true, true
    local reads = {}
    local function Read(key) reads[key] = (reads[key] or 0) + 1 end
    native.AZS_GetPhase = function()
        Read("phase")
        return currentPhase
    end
    native.AZS_RUN = { px = 0, py = 0, pf = 0.75 }
    native.AZS_RUN_UPDATED = 12
    native.AZS_ZONE = { zone = "CurrentZone", map = 1 }
    native.AZS_ZONE_UPDATED = 2
    native.GetRealZoneText = function()
        Read("context")
        return "CurrentZone"
    end
    native.GetMapInfo = function()
        Read("map")
        return mapName, 1000, 500
    end
    native.GetCurrentMapContinent = function()
        Read("continent")
        return 1
    end
    native.GetCurrentMapZone = function()
        Read("zone")
        return 1
    end
    native.SetMapToCurrentZone = function()
        Read("setMap")
        mapName = "CurrentZone"
    end
    native.GetPlayerMapPosition = function()
        Read("position")
        if positionReady then return playerX, playerY end
        return 0, 0
    end
    native.GetWorldLocMapPosition = function(map, x, y)
        Read("project")
        assert(map == 1, "projection changed the accepted native map")
        return 0.5 - y / 1000, 0.5 - x / 500
    end
    native.WorldMapFrame = { IsShown = function() return browsing end }
    local player = {
        GetModel = function() return "Interface\\Minimap\\MinimapArrow" end,
        GetFacing = function()
            Read("heading")
            if facingReady then return facing end
        end,
    }
    native.Minimap = { GetChildren = function() return player end }
    navigationContext:Load("modules/map/navigation.lua", "Navigation")
    local nav = native.DFRL.navigation
    local minimapWidth, minimapHeight = 100, 100
    native.T.GetLocalSize = function(frame)
        assert(frame == native.Minimap, "minimap sampling read another frame")
        Read("minimapSize")
        return minimapWidth, minimapHeight
    end
    nav.BeginSample()
    assert(nav.MinimapSize(20) == 100, "usable native minimap bounds were rejected")
    minimapWidth = 120
    assert(nav.MinimapSize() == 100 and reads.minimapSize == 1, "one callback mixed minimap sizes")
    nav.EndSample()
    nav.BeginSample()
    assert(nav.MinimapSize() == 120 and reads.minimapSize == 2, "next callback retained old minimap bounds")
    nav.EndSample()
    minimapWidth, minimapHeight = nil, nil
    nav.BeginSample()
    assert(nav.MinimapSize() == nil, "missing minimap bounds were invented")
    minimapWidth, minimapHeight = 10, 10
    assert(nav.MinimapSize(20) == 10, "missing bounds did not retry in the same callback")
    minimapWidth, minimapHeight = 100, 100
    assert(nav.MinimapSize(20) == 100, "too-small bounds did not retry in the same callback")
    minimapWidth, minimapHeight = 140, 140
    assert(nav.MinimapSize(120) == 140, "a stricter caller retained insufficient cached bounds")
    nav.EndSample()
    minimapWidth = 160
    assert(nav.MinimapSize() == 160, "unsampled geometry retained a prior callback")
    minimapWidth = 180
    assert(nav.MinimapSize() == 180, "ordinary geometry reads were cached across callbacks")
    print("PASS minimap size sharing, callback boundaries and unavailable/insufficient geometry retry")
    local destination = { x = 100, y = -100, mx = 0.6, my = 0.3 }
    nav.SetPoints("AZS_CHESTS", { destination })
    nav.Position()
    reads = {}
    nav.BeginSample()
    for _ = 1, 12 do
        local east, north, distance, metric, stamp = nav.GuideDelta(destination)
        assert(math.abs(east - 100) < 0.00001 and math.abs(north - 100) < 0.00001, "shared map delta moved")
        assert(metric and distance > 141 and distance < 142 and stamp == nil, "map source gained a sampled stamp")
        assert(nav.Heading() == facing, "native heading changed")
        assert(nav.Phase() == "playing", "guide phase changed")
    end
    nav.EndSample()
    for _, key in ipairs({ "phase", "context", "map", "continent", "zone", "position", "heading" }) do
        assert(reads[key] == 1, key .. " was sampled separately for repeated guides and pins")
    end
    assert(not reads.setMap, "shared reads moved the current map again")
    playerX, facing = 0.55, 0.5
    nav.BeginSample()
    local east = nav.GuideDelta(destination)
    assert(math.abs(east - 50) < 0.00001 and nav.Heading() == 0.5, "next frame reused old native movement")
    nav.EndSample()

    browsing, mapName, facingReady = true, "AnotherZone", false
    reads = {}
    nav.BeginSample()
    local worldEast, worldNorth, _, worldMetric, worldStamp = nav.GuideDelta(destination)
    local fallbackFacing, fallbackStamp = nav.Heading()
    assert(
        worldEast == 100 and worldNorth == 100 and worldMetric and worldStamp == 12,
        "foreign map lost official fallback"
    )
    assert(fallbackFacing == 0.75 and fallbackStamp == 12, "heading fallback lost its native stamp")
    assert(not reads.setMap and not reads.position, "browsing another map changed or sampled that sheet")
    native.AZS_RUN.px, native.AZS_RUN_UPDATED = 20, 13
    local _, retainedNorth, _, _, retainedStamp = nav.Delta(destination)
    assert(retainedNorth == 100 and retainedStamp == 12, "one sample mixed native run publications")
    nav.EndSample()
    nav.BeginSample()
    local _, freshNorth, _, _, freshStamp = nav.Delta(destination)
    assert(freshNorth == 80 and freshStamp == 13, "next sample retained a retired run tuple")
    nav.EndSample()

    browsing, mapName, positionReady, facingReady = false, "CurrentZone", false, true
    nav.BeginSample()
    nav.GuideDelta(destination)
    positionReady = true
    assert(select(5, nav.GuideDelta(destination)) == 13, "missing position retried within one frame")
    nav.EndSample()
    nav.BeginSample()
    assert(select(5, nav.GuideDelta(destination)) == nil, "missing position did not retry next frame")
    nav.EndSample()
    currentPhase = "dead"
    nav.Reset()
    nav.BeginSample()
    assert(nav.GuideDelta(destination) == nil, "retired phase retained sampled navigation")
    nav.EndSample()
    currentPhase = "playing"
    assert(nav.Position() ~= nil, "ordinary reads retained the completed sample")
    local failed, failure = pcall(nav.WithSample, function()
        nav.Position()
        error("injected navigation sample failure")
    end)
    assert(
        not failed and string.find(failure, "injected navigation sample failure", 1, true),
        "sample swallowed a callback failure"
    )
    local sampledPosition = reads.position or 0
    playerX = 0.65
    assert(
        nav.Position() == playerX and reads.position == sampledPosition + 1,
        "failed sample left ordinary reads cached"
    )
    print("PASS navigation shares synchronous native samples and preserves browsing, fallbacks, stamps and retries")
end
