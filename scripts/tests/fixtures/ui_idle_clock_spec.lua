-- CI only: production minimap choice/lifecycle with explicit frame/date boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1")
local context = H.New()
local env = context.env
context:Load("core/display.lua", "Display")
context:Load("core/hud.lua")
local display = env.DFRL.display
local panel = env.CreateFrame("Frame", nil, env.UIParent)
local frame = env.CreateFrame("Frame", nil, panel)
local label = frame:CreateFontString(nil, "OVERLAY")
label:SetFont("DEFAULT_TEST", 10, "")
local zoneButton = env.CreateFrame("Button", nil, panel)
local zoneText = zoneButton:CreateFontString(nil, "OVERLAY")
function zoneButton:SetPoint(...) self.point = { ... } end
function zoneText:SetJustifyH(value) self.justify = value end
local reads, value = 0, "12:34"
env.date = function(format)
    assert(format == "%H:%M")
    reads = reads + 1
    return value
end
env.GetTime = function() error("the minimap clock polled native UI time per frame") end
env.AZS_IsHudShown = function() error("legacy clock queried an unknown native HUD part") end
env.AZS_SetHudShown = function() error("legacy clock changed an unknown native HUD part") end
env.GameTooltip = {
    IsOwned = function(_, owner) return owner == frame end,
    IsShown = function() return false end,
    Hide = function() context.tooltipHides = (context.tooltipHides or 0) + 1 end,
}
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env)
local minimap = chunk()
minimap.Watch(frame, label, zoneButton, zoneText, panel)
assert(display.Get("minimapShowClock") == true, "clock must default on")
assert(display.Copy({ minimapShowClock = "true" }).minimapShowClock == true, "invalid clock choice must default on")
assert(display.Copy({ minimapShowClock = false }).minimapShowClock == false, "saved clock-off choice was lost")
assert(reads == 1 and label:GetText() == "12:34" and frame:IsVisible() and frame:GetScript("OnUpdate"))
assert(zoneButton.point[1] == "LEFT" and zoneText.justify == "LEFT")
display.BeginEdit()
display.Set("minimapShowClock", false)
assert(reads == 1 and not frame:IsShown() and frame:GetScript("OnUpdate") == nil, "disabled clock retained its worker")
assert(zoneButton.point[1] == "CENTER" and zoneButton.point[2] == panel and zoneText.justify == "CENTER")
for _ = 1, 100 do
    context:Call(frame, "OnUpdate", 1)
end
assert(reads == 1, "disabled clock sampled time")

display.Set("minimapShowClock", true)
assert(reads == 2 and label:GetText() == "12:34" and frame:IsVisible())
assert(not env.SurvivorsDragonUiDisplay, "clock preview saved early")
assert(zoneButton.point[1] == "LEFT" and zoneText.justify == "LEFT")
context:ResetCounts()
for _ = 1, 40 do
    context:Call(frame, "OnUpdate", 0.1)
end
assert(reads == 2, "clock sampled before its five-second interval")
context:NoPresentationWrites()
context:Call(frame, "OnUpdate", 1.1)
assert(reads == 3 and not context.writes.SetText, "unchanged minute was repainted")
panel:Hide()
assert(frame:GetScript("OnUpdate") == nil, "hidden minimap retained the clock callback")
value = "12:35"
context:Call(frame, "OnUpdate", 20)
assert(reads == 3, "hidden clock sampled local time")
panel:Show()
assert(label:GetText() == "12:35" and reads == 4 and frame:GetScript("OnUpdate"))
context:Call(frame, "OnUpdate", 4.9)
assert(reads == 4, "Show retained a pre-hide deadline")
context:Call(frame, "OnUpdate", 0.2)
assert(reads == 5)

display.Set("minimapShowClock", false)
display.FinishEdit(false)
assert(display.Get("minimapShowClock") and frame:IsShown() and frame:GetScript("OnUpdate"))
assert(zoneButton.point[1] == "LEFT" and zoneText.justify == "LEFT", "Cancel lost the default clock layout")
display.BeginEdit()
display.Set("minimapShowClock", false)
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.minimapShowClock == false, "Confirm lost the clock-off choice")
local previousReads = reads
display.BeginEdit()
display.Load({})
assert(frame:IsShown() and frame:GetScript("OnUpdate") and reads == previousReads + 1)
display.Load({ minimapShowClock = false })
assert(not frame:IsShown() and not frame:GetScript("OnUpdate"), "profile preview left clock work running")
display.Load({})
assert(frame:IsShown() and reads == previousReads + 2)
display.FinishEdit(false)
assert(not display.Get("minimapShowClock") and not frame:IsShown() and not frame:GetScript("OnUpdate"))
assert(env.SurvivorsDragonUiDisplay.minimapShowClock == false, "profile preview overwrote the saved clock choice")
display.Reset()
assert(display.Get("minimapShowClock") and frame:IsShown() and frame:GetScript("OnUpdate"))
assert(zoneText.justify == "LEFT", "reset did not restore the default clock layout")
print("PASS default-on minimap clock, saved off choice, preview/discard/Confirm/profile/reset and hidden recovery")

local function NativeClock(preference, configure)
    local c = H.New()
    local boundary = c.env
    c:Load("core/display.lua", "Display")
    c:Load("core/hud.lua")
    local state = {
        shown = preference,
        supported = true,
        reads = 0,
        dateReads = 0,
        writes = 0,
        value = { text = "10:42 PM", hour = 22, minute = 42, is24Hour = false },
    }
    c.panel = boundary.CreateFrame("Frame", nil, boundary.UIParent)
    c.clock = boundary.CreateFrame("Frame", nil, c.panel)
    c.label = c.clock:CreateFontString(nil, "OVERLAY")
    c.label:SetFont("DEFAULT_TEST", 10, "")
    local zone = boundary.CreateFrame("Button", nil, c.panel)
    local name = zone:CreateFontString(nil, "OVERLAY")
    boundary.GameTooltip = boundary.CreateFrame("Frame", nil, boundary.UIParent)
    function boundary.GameTooltip:SetOwner(owner) self.owner = owner end
    function boundary.GameTooltip:IsOwned(owner) return self.owner == owner end
    function boundary.GameTooltip:ClearLines() self.lines = {} end
    function boundary.GameTooltip:AddLine(text) table.insert(self.lines, text) end
    boundary.GameTooltip:Hide()
    boundary.GetTime = function() error("clock added native UI-time polling") end
    boundary.AZS_GetPhase = function() error("local clock depends on a run phase") end
    boundary.AZS_GetRunTime = function() error("local clock used the run timer") end
    boundary.date = function()
        state.dateReads = state.dateReads + 1
        error("available native clock fell back to a separate wall-clock source")
    end
    boundary.AZS_GetLocalTime = function()
        state.reads = state.reads + 1
        if state.throwRead then error("temporary native time failure") end
        if not state.value then return nil end
        local copy = {}
        for key, value in pairs(state.value) do
            copy[key] = value
        end
        return copy
    end
    boundary.AZS_IsHudShown = function(part)
        assert(part == "localClock", "minimap clock touched the run timer or another HUD part")
        if state.supported then return state.shown end
    end
    boundary.AZS_SetHudShown = function(part, shown)
        assert(part == "localClock" and type(shown) == "boolean")
        state.writes = state.writes + 1
        if state.failWrite then error("temporary native handoff failure") end
        state.shown = shown
        c:Event(c.clock, "CVAR_UPDATE", "hudLocalClock")
    end
    boundary.ReloadUI = function() state.reloaded = true end
    if configure then configure(c, state, boundary) end
    local factory = assert(loadfile(assert(arg[1])))
    setfenv(factory, boundary)
    factory().Watch(c.clock, c.label, zone, name, c.panel)
    function c:ClockTick(seconds) self:Call(self.clock, "OnUpdate", seconds or 5.1) end
    return c, state, boundary
end

for _, performance in ipairs({ false, true }) do
    local c, state, boundary = NativeClock(
        true,
        function(_, _, env) env.SurvivorsDragonUiDisplay = { performanceMode = performance } end
    )
    local display = boundary.DFRL.display
    assert(display.Get("performanceMode") == performance)
    assert(state.shown == false and state.reads == 1 and c.clock:GetScript("OnUpdate"))
    assert(c.label:GetText() == "22:42" and c.label:IsShown(), "default-on native clock was not ready")
    display.BeginEdit()
    display.Set("minimapShowClock", false)
    assert(not c.clock:IsShown() and not c.clock:GetScript("OnUpdate") and state.reads == 1)
    display.Set("minimapShowClock", true)
    assert(c.label:GetText() == "22:42" and c.label:IsShown() and state.reads == 2)
    assert(boundary.SurvivorsDragonUiDisplay.minimapShowClock == nil, "native clock preview saved early")
    local allocated, writes = #c.objects, state.writes
    c:ResetCounts()
    c:ClockTick(4.9)
    assert(state.reads == 2)
    c:NoPresentationWrites()
    c:ClockTick(0.2)
    assert(state.reads == 3 and not c.writes.SetText and state.writes == writes)
    c:Call(c.clock, "OnEnter")
    assert(boundary.GameTooltip.lines[1] == "Local time: 22:42")
    state.value = { text = "12:05 AM", hour = 0, minute = 5, is24Hour = false }
    c:ClockTick()
    assert(c.label:GetText() == "00:05" and boundary.GameTooltip.lines[1] == "Local time: 00:05")
    state.value = { text = "12:00 PM", hour = 12, minute = 0, is24Hour = false }
    c:ClockTick()
    assert(c.label:GetText() == "12:00")
    local foreign = boundary.CreateFrame("Frame", nil, boundary.UIParent)
    boundary.GameTooltip:SetOwner(foreign)
    state.value = { text = "07:09", hour = 7, minute = 9, is24Hour = true }
    c:ClockTick()
    c:Call(c.clock, "OnLeave")
    assert(boundary.GameTooltip:IsOwned(foreign) and boundary.GameTooltip:IsShown())
    c.panel:Hide()
    local reads = state.reads
    c:ClockTick(30)
    assert(state.reads == reads and not c.clock:GetScript("OnUpdate"))
    state.value = { text = "23:59", hour = 23, minute = 59, is24Hour = true }
    c.panel:Show()
    assert(c.label:GetText() == "23:59" and state.reads == reads + 1)
    assert(#c.objects == allocated + 1 and state.dateReads == 0)
    display.Set("minimapShowClock", false)
    display.FinishEdit(false)
    assert(c.clock:IsShown() and c.clock:GetScript("OnUpdate") and not state.shown)
    c:Event(c.clock, "PLAYER_LEAVING_WORLD")
    assert(state.shown == true, "clock cleanup did not restore the captured native preference")
    c:Event(c.clock, "PLAYER_ENTERING_WORLD")
    assert(state.shown == false and c.clock:IsShown() and c.label:IsShown())
    boundary.ReloadUI()
    assert(state.reloaded and state.shown == true and not c.clock:GetScript("OnUpdate"))
end
print("PASS native clock uses 24-hour fields, bounded/hidden sampling, owned hover and preview/world/reload handoff")

for _, preference in ipairs({ false, true }) do
    local c, state, boundary = NativeClock(preference)
    local display = boundary.DFRL.display
    display.BeginEdit()
    display.Set("minimapShowClock", true)
    local valid = state.value
    local malformed = {
        { text = "bad", hour = 24, minute = 0, is24Hour = true },
        { text = "bad", hour = 12, minute = 60, is24Hour = true },
        { text = "bad", hour = 12.5, minute = 5, is24Hour = true },
        { text = "bad", hour = -1, minute = 5, is24Hour = true },
        { text = "bad", hour = 0 / 0, minute = 5, is24Hour = true },
        { text = "bad", hour = math.huge, minute = 5, is24Hour = true },
        { text = "bad", hour = 12, minute = 5, is24Hour = "true" },
        { hour = 12, minute = 5, is24Hour = true },
    }
    for _, value in ipairs(malformed) do
        state.value = value
        c:ClockTick()
        assert(not c.label:IsShown() and state.shown == preference and state.dateReads == 0)
        state.value = valid
        c:ClockTick()
        assert(c.label:IsShown() and state.shown == false)
    end
    state.value = nil
    c:ClockTick()
    assert(not c.label:IsShown() and state.shown == preference)
    state.throwRead = true
    c:ClockTick()
    assert(not c.label:IsShown() and state.shown == preference)
    state.throwRead, state.value = false, valid
    c:ClockTick()
    state.value = { text = "10:43 PM", hour = 22, minute = 43, is24Hour = false }
    c.failText = "22:43"
    c:ClockTick()
    assert(not c.label:IsShown() and state.shown == preference, "failed text assignment suppressed the native clock")
    c:ClockTick()
    assert(c.label:GetText() == "22:43" and c.label:IsShown() and state.shown == false)
    c.label.font = nil
    display.Set("uiFont", "arial")
    assert(not c.label:IsShown() and state.shown == preference, "missing font retained native suppression")
    c:ClockTick()
    assert(c.label:GetFont() and c.label:IsShown() and state.shown == false, "visible font retry did not recover")
    boundary.GameTooltip:SetOwner(c.clock)
    boundary.GameTooltip:Show()
    state.shown = true
    c:Event(c.clock, "CVAR_UPDATE", "hudLocalClock")
    assert(state.shown == false, "external native clock preference escaped active replacement ownership")
    boundary.ReloadUI()
    assert(state.shown == true, "cleanup forgot the later external preference")
    assert(not boundary.GameTooltip:IsShown())
end
print("PASS invalid native clocks clear presentation, restore prior visibility and recover without a date fallback")

local partial, partialState, partialEnv = NativeClock(true, function(_, state) state.supported = false end)
partialEnv.DFRL.display.BeginEdit()
partialEnv.DFRL.display.Set("minimapShowClock", true)
assert(partial.label:GetText() == "22:42" and partialState.writes == 0)
assert(partialState.shown == true, "an unsupported HUD part received a guessed visibility write")
local retry, retryState, retryEnv = NativeClock(true, function(_, state) state.failWrite = true end)
assert(retryState.shown == true)
retryState.failWrite = false
retryEnv.DFRL.display.BeginEdit()
retryEnv.DFRL.display.Set("minimapShowClock", false)
retryEnv.DFRL.display.Set("minimapShowClock", true)
assert(retryState.shown == false and retry.label:IsShown())
retryState.failWrite, retryState.shown = true, true
retry:Event(retry.clock, "CVAR_UPDATE", "hudLocalClock")
assert(retryState.shown == true and not retry.label:IsShown(), "failed handoff left two visible clocks")
retryState.failWrite = false
retry:ClockTick()
assert(retryState.shown == false and retry.label:IsShown())
retry:Event(retry.clock, "PLAYER_LOGOUT")
assert(retryState.shown == true)
print("PASS partial native support avoids unknown HUD writes and failed handoffs recover through existing input")

-- The launcher remains clickable above Layout and restores its gameplay layer.
minimap.Editing(true) -- No launcher has been allocated yet.
env.Minimap = env.CreateFrame("Frame", nil, env.UIParent)
function env.Minimap:GetFrameStrata() return "MEDIUM" end
env.Minimap:SetFrameLevel(3)
local launcher = env.CreateFrame("Button", "SurvivorsDragonUiMinimapButton", env.Minimap)
local setStrata = launcher.SetFrameStrata
function launcher:SetFrameStrata(value)
    setStrata(self, value)
    self.strata = value
end
function launcher:GetFrameStrata() return self.strata or "MEDIUM" end
launcher:SetFrameLevel(23)
minimap.Editing(true)
assert(
    launcher:GetFrameStrata() == "TOOLTIP" and launcher:GetFrameLevel() == 125,
    "selection overlay covers launcher input"
)
local allocated = #context.objects
context:ResetCounts()
minimap.Editing(true)
context:NoPresentationWrites()
env.Minimap:SetFrameLevel(7)
minimap.Editing(false)
assert(
    launcher:GetFrameStrata() == "MEDIUM" and launcher:GetFrameLevel() == 27,
    "close did not restore current minimap layer"
)
context:ResetCounts()
minimap.Editing(false)
context:NoPresentationWrites()
assert(
    #context.objects == allocated and not launcher:GetScript("OnUpdate"),
    "launcher layering added views or an idle worker"
)
