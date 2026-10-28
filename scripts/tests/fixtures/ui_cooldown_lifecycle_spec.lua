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
local context = H.New()
local env = context.env
context.settings.cooldownNumbers = true
local bar = env.CreateFrame("Frame", nil, env.UIParent)
env.DFRL.actionButtons = {}
for index = 1, 7 do
    local button = env.CreateFrame("Button", "LifecycleActionButton" .. index, bar)
    button.slot = index
    env.DFRL.actionButtons[index] = button
end
local chunk = assert(loadstring(body, "@production-cooldown-lifecycle"))
setfenv(chunk, env)
chunk()(bar)
local controller = context:Controller("ACTIONBAR_UPDATE_COOLDOWN")
assert(controller:GetScript("OnUpdate"), "eligible cooldown controller did not start")
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
print(
    "PASS cooldown callbacks detach while disabled/hidden/retired and retain immediate recovery and final-window reads"
)
