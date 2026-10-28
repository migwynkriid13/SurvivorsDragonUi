-- CI only: exact production cooldown helper/controller over seven native slots.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "cooldown lifecycle fixtures require CI Lua 5.1")
local file = assert(io.open("modules/bars/bars.lua", "r"))
local source = file:read("*a")
file:close()
local function Between(first, last)
    local start = assert(string.find(source, first, 1, true))
    local finish = assert(string.find(source, last, start, true))
    return string.sub(source, start, finish - 1)
end
local body = Between("    local ACTION_SLOTS =", "    local TEX_PATH =")
    .. Between("    local function FormatCooldown(", "    local initialized = false")
    .. "\nreturn CreateCooldownNumbers"
local function NativeCooldown(context, button)
    local env = context.env
    local model = env.CreateFrame("Model", button:GetName() .. "Cooldown", button)
    model.start, model.duration, model.stopping = 1, 10, 0
    model.nativeUpdates, model.swipes, model.flashes, model.finished = 0, 0, 0, 0
    model.nativeUpdate = function()
        assert(env.this == model, "saved model script lost native this")
        model.nativeUpdates = model.nativeUpdates + 1
        if model.stopping == 0 then
            local progress = (env.GetTime() - model.start) / model.duration
            if progress >= 1 then
                model.stopping, model.sequence = 1, 1
                model.flashes = model.flashes + 1
            else
                model.sequence, model.sequenceTime = 0, progress
                model.swipes = model.swipes + 1
            end
        end
    end
    model.nativeFinished = function()
        model.finished = model.finished + 1
        model:Hide()
    end
    model:SetScript("OnUpdateModel", model.nativeUpdate)
    model:SetScript("OnAnimFinished", model.nativeFinished)
    return model
end

local context = H.New()
local env = context.env
context.settings.cooldownNumbers = true
local bar = env.CreateFrame("Frame", nil, env.UIParent)
env.DFRL.actionButtons = {}
local cooldowns = {}
for index = 1, 7 do
    local button = env.CreateFrame("Button", "LifecycleActionButton" .. index, bar)
    button.slot = index
    env.DFRL.actionButtons[index] = button
    cooldowns[index] = NativeCooldown(context, button)
end
local foreignButton = env.CreateFrame("Button", "ForeignAbilityButton", env.UIParent)
local foreignCooldown = NativeCooldown(context, foreignButton)
local chunk = assert(loadstring(body, "@production-cooldown-lifecycle"))
setfenv(chunk, env)
chunk()(bar)
local controller = context:Controller("ACTIONBAR_UPDATE_COOLDOWN")
assert(controller:GetScript("OnUpdate"), "eligible cooldown controller did not start")
for _, cooldown in ipairs(cooldowns) do
    assert(cooldown:IsShown() and cooldown.nativeUpdates == 0, "normal initialization changed native cooldown state")
    assert(cooldown:GetScript("OnAnimFinished") == cooldown.nativeFinished, "native completion handler changed")
    assert(not cooldown:GetScript("OnUpdate"), "flash suppression added a polling callback")
end
assert(foreignCooldown:GetScript("OnUpdateModel") == foreignCooldown.nativeUpdate, "unrelated cooldown was wrapped")
context.now = 10.999
for _, cooldown in ipairs(cooldowns) do
    context:Call(cooldown, "OnUpdateModel")
    assert(cooldown.swipes == 1 and cooldown.sequence == 0 and cooldown.stopping == 0, "normal swipe changed")
end
context.now = 11
for _, cooldown in ipairs(cooldowns) do
    context:Call(cooldown, "OnUpdateModel")
    assert(cooldown.flashes == 1 and cooldown.sequence == 1 and cooldown.stopping == 1, "normal ready flash changed")
    context:Call(cooldown, "OnAnimFinished")
    assert(cooldown.finished == 1 and not cooldown:IsShown(), "normal completion cleanup changed")
    cooldown.start, cooldown.duration, cooldown.stopping = 1, 10, 0
    cooldown:Show()
end
context.now = 2
context:ResetCounts()
context:Call(controller, "OnUpdate", 0.01)
assert(not context.reads.cooldown, "ordinary cooldown reads lost their100ms gate")
context:Call(controller, "OnUpdate", 0.1)
assert(context.reads.cooldown == 7)
context:SetSetting("cooldownNumbers", false)
assert(not controller:GetScript("OnUpdate"), "disabled cooldown callback stayed attached")
context:ResetCounts()
context:Call(controller, "OnUpdate", 1)
context:Event(controller, "ACTIONBAR_SLOT_CHANGED", 1)
assert(not context.reads.cooldown and not controller:GetScript("OnUpdate"))
context:SetSetting("cooldownNumbers", true)
assert(controller:GetScript("OnUpdate") and context.reads.cooldown == 7)
bar:Hide()
assert(not controller:GetScript("OnUpdate"), "hidden ancestor retained cooldown callback")
context:ResetCounts()
context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
assert(not context.reads.cooldown and not controller:GetScript("OnUpdate"))
bar:Show()
assert(controller:GetScript("OnUpdate") and context.reads.cooldown == 7)
context:Event(controller, "PLAYER_LEAVING_WORLD")
assert(not controller:GetScript("OnUpdate"), "world retirement retained cooldown callback")
context:ResetCounts()
context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
assert(not context.reads.cooldown and not controller:GetScript("OnUpdate"))
context:Event(controller, "PLAYER_ENTERING_WORLD")
assert(controller:GetScript("OnUpdate") and context.reads.cooldown == 7)
context.now = 1
env.GetActionCooldown = function()
    context.reads.cooldown = (context.reads.cooldown or 0) + 1
    return 1, 0.1, 1
end
context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
local overlay = env.DFRL.actionButtons[1].DFRL_cooldownNumber
assert(overlay.text:GetText() == "1", "exact100ms caption changed")
context:ResetCounts()
context.now = 1.001
context:Call(controller, "OnUpdate", 0.001)
assert(context.reads.cooldown == 7 and overlay.text:GetText() == "0", "final window lost per-frame sampling")
context.now = 1.2
context:Call(controller, "OnUpdate", 0.001)
assert(context.reads.cooldown == 14 and not overlay:IsShown(), "expiration skipped its final sample")
assert(controller:GetScript("OnUpdate"), "visible enabled cooldowns stopped observing future native cooldowns")

local durations, starts = { 0.15, 0.25, 10, 10, 10, 10, 10 }, {}
env.GetActionCooldown = function(slot)
    context.reads.cooldown = (context.reads.cooldown or 0) + 1
    return starts[slot] or 1, durations[slot], 1
end
context.now = 1
context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
context:ResetCounts()
context.now = 1.02
context:Call(controller, "OnUpdate", 0.02)
assert(context.reads.cooldown == 1, "one expiring slot resampled all seven native cooldowns")
context.now = 1.06
context:Call(controller, "OnUpdate", 0.04)
assert(context.reads.cooldown == 2, "partial final-window reads repeated unrelated cooldowns")
context.now = 1.11
context:Call(controller, "OnUpdate", 0.05)
assert(context.reads.cooldown == 9, "finishing samples starved the full-bar100ms fallback")
assert(overlay.text:GetText() == "0", "selective final sampling skipped the positive zero window")
context.now = 1.12
context:Call(controller, "OnUpdate", 0.01)
assert(context.reads.cooldown == 11, "a newly finishing second slot missed frame sampling")
durations[2] = 10
context.now = 1.13
context:Call(controller, "OnUpdate", 0.01)
assert(context.reads.cooldown == 13, "finishing native replacement was not freshly sampled")
context.now = 1.14
context:Call(controller, "OnUpdate", 0.01)
assert(context.reads.cooldown == 14, "a replaced long cooldown retained finishing-only sampling")
starts[3], durations[3] = context.now, 0.05
context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
assert(context.reads.cooldown == 21, "native cooldown event stopped refreshing the full bar immediately")
assert(env.DFRL.actionButtons[3].DFRL_cooldownNumber.text:GetText() == "0")
for _, cooldown in ipairs(cooldowns) do
    cooldown.stopping = 1
end
context:SetSetting("performanceMode", true)
assert(context.settings.cooldownNumbers == true, "Performance Mode rewrote the cooldown choice")
assert(not controller:GetScript("OnUpdate"), "Performance Mode retained cooldown-number polling")
for _, button in ipairs(env.DFRL.actionButtons) do
    assert(not button.DFRL_cooldownNumber:IsShown(), "Performance Mode left a cooldown number visible")
    assert(button.DFRL_cooldownNumber.finishing == nil, "Performance Mode retained final-window state")
end
for _, cooldown in ipairs(cooldowns) do
    assert(not cooldown:IsShown(), "Performance Mode left an active native ready flash visible")
    assert(
        cooldown.start == 1 and cooldown.duration == 10 and cooldown.stopping == 1,
        "suppression rewrote native timing"
    )
    assert(
        cooldown:GetScript("OnAnimFinished") == cooldown.nativeFinished,
        "suppression replaced native completion cleanup"
    )
end
context:ResetCounts()
context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
context:SetSetting("performanceMode", true)
context:Call(controller, "OnUpdate", 1)
assert(
    not context.reads.cooldown and not controller:GetScript("OnUpdate"),
    "Performance Mode read native number timing"
)
context:NoPresentationWrites()
local flashes = cooldowns[1].flashes
for _, cooldown in ipairs(cooldowns) do
    cooldown.start, cooldown.duration, cooldown.stopping = 20, 1, 0
    cooldown:Show()
end
context.now = 20.999
for _, cooldown in ipairs(cooldowns) do
    local updates = cooldown.nativeUpdates
    context:Call(cooldown, "OnUpdateModel")
    assert(cooldown:IsShown() and cooldown.nativeUpdates == updates + 1, "Performance Mode stopped a running swipe")
    assert(cooldown.sequence == 0 and cooldown.stopping == 0, "Performance Mode changed unfinished native state")
end
context.now = 21
context:ResetCounts()
for _, cooldown in ipairs(cooldowns) do
    local updates = cooldown.nativeUpdates
    context:Call(cooldown, "OnUpdateModel")
    assert(not cooldown:IsShown() and cooldown.nativeUpdates == updates, "ready handoff reached native flash script")
    assert(cooldown.flashes == flashes and cooldown.stopping == 0, "Performance Mode started a ready flash")
    assert(cooldown.start == 20 and cooldown.duration == 1, "ready suppression mutated native timing")
end
assert(context.writes.Hide == 7 and not context.reads.cooldown, "ready suppression polled native cooldown timing")
context:ResetCounts()
for _, cooldown in ipairs(cooldowns) do
    context:Call(cooldown, "OnUpdateModel")
end
context:NoPresentationWrites()
context:Call(foreignCooldown, "OnUpdateModel")
assert(foreignCooldown.flashes == 1, "Performance Mode suppressed an unrelated cooldown")
context:ResetCounts()
context:SetSetting("performanceMode", false)
assert(
    controller:GetScript("OnUpdate") and context.reads.cooldown == 7,
    "Performance Mode exit did not read current cooldowns"
)
for _, cooldown in ipairs(cooldowns) do
    assert(not cooldown:IsShown() and cooldown.flashes == flashes, "mode exit replayed a suppressed ready flash")
    cooldown.start, cooldown.duration, cooldown.stopping = 30, 1, 0
    cooldown:Show()
end
context.now = 31
for _, cooldown in ipairs(cooldowns) do
    context:Call(cooldown, "OnUpdateModel")
    assert(
        cooldown.flashes == flashes + 1 and cooldown.stopping == 1,
        "normal mode failed to restore the next ready flash"
    )
end
context:SetSetting("cooldownNumbers", false)
bar:Hide()
context:ResetCounts()
context:SetSetting("performanceMode", true)
assert(
    not controller:GetScript("OnUpdate") and not context.reads.cooldown,
    "hidden numbers-off suppression started polling"
)
for _, cooldown in ipairs(cooldowns) do
    assert(not cooldown:IsShown(), "hidden numbers-off transition retained an active flash")
end
context:Event(controller, "PLAYER_LEAVING_WORLD")
context:Event(controller, "PLAYER_ENTERING_WORLD")
context:ResetCounts()
bar:Show()
-- The fixture shows the owner once; recovery must add no cosmetic writes.
assert(context.writes.Show == 1, "world/show recovery showed extra cooldown presentation")
for method, count in pairs(context.writes) do
    assert(method == "Show" and count == 1, "world/show recovery wrote " .. method)
end
assert(
    not context.reads.cooldown and not controller:GetScript("OnUpdate"),
    "world/show recovery polled Performance Mode numbers"
)
context:ResetCounts()
context:SetSetting("performanceMode", true)
context:Event(controller, "ACTIONBAR_UPDATE_COOLDOWN")
assert(
    not context.reads.cooldown and not controller:GetScript("OnUpdate"),
    "world/show recovery polled Performance Mode numbers"
)
context:NoPresentationWrites()
context:SetSetting("performanceMode", false)
assert(
    context.settings.cooldownNumbers == false and not controller:GetScript("OnUpdate"),
    "mode exit changed saved numbers choice"
)
for _, cooldown in ipairs(cooldowns) do
    assert(not cooldown:IsShown(), "preview cancellation replayed an old flash")
end
bar:Hide()
for _, button in ipairs(env.DFRL.actionButtons) do
    assert(button.DFRL_cooldownNumber.finishing == nil, "hidden cooldown retained final-window state")
end

local initial = H.New()
initial.settings.performanceMode, initial.settings.cooldownNumbers = true, false
local initialEnv = initial.env
local initialBar = initialEnv.CreateFrame("Frame", nil, initialEnv.UIParent)
initialEnv.DFRL.actionButtons = {}
local initialModels = {}
for index = 1, 7 do
    local button = initialEnv.CreateFrame("Button", "InitialPerformanceButton" .. index, initialBar)
    button.slot = index
    initialEnv.DFRL.actionButtons[index] = button
    if index < 7 then
        local cooldown = NativeCooldown(initial, button)
        initialModels[index] = cooldown
        if index == 6 then
            cooldown:SetScript("OnUpdateModel", nil)
        elseif index == 5 then
            cooldown.start, cooldown.duration, cooldown.stopping = 1, 0.5, 0
        else
            cooldown.stopping = 1
        end
    end
end
local initialChunk = assert(loadstring(body, "@production-cooldown-initial-performance"))
setfenv(initialChunk, initialEnv)
initialChunk()(initialBar)
assert(
    not initial:Controller("ACTIONBAR_UPDATE_COOLDOWN"):GetScript("OnUpdate"),
    "initial Performance Mode attached number polling"
)
assert(not initial.reads.cooldown, "initial Performance Mode read native numbers")
for index = 1, 5 do
    assert(not initialModels[index]:IsShown(), "initial Performance Mode retained a completed/active ready flash")
end
assert(
    initialModels[6]:IsShown() and not initialModels[6]:GetScript("OnUpdateModel"),
    "missing native handler was replaced"
)
print(
    "PASS cooldown callbacks retain native timing; Performance Mode suppresses only the seven native ready flashes without replay or polling"
)
