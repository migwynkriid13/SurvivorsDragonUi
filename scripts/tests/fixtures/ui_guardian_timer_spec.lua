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
    setNativeFont(label, size, flags)
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
