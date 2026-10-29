-- CI only: production banner controller over explicit native handler/HUD mocks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
context:Load("core/messages.lua")
context.settings.customBanners = false
env.DFRL.locale.data = { en = { native = {} } }
env.DFRL.CleanerChat = nil -- Default chat has no custom chat/capture namespace.
env.DFRL.layout.Place = function() end
env.T.SetChatFont = function(label) label:SetFont("DEFAULT_TEST", 12, "OUTLINE") end
env.T.SetChatShadow = function() end
env.AZS_RegisterBannerHandler = function(callback)
    context.handler = callback
    context.registrations = (context.registrations or 0) + 1
end
env.AZS_UnregisterBannerHandler = function(callback)
    assert(context.handler == callback, "unregistration replaced a foreign handler")
    if context.failUnregister then error("pending unregistration") end
    context.handler = nil
end
env.geterrorhandler = function()
    return function(message) context.failure = message end
end
env.AZS_SetHudShown = function(_, shown)
    if shown and context.failRestore then return end
    context.nativeShown = shown
end
env.AZS_IsHudShown = function()
    context.reads.hud = (context.reads.hud or 0) + 1
    return context.nativeShown
end
context:Load("core/hud.lua")
context:Load("modules/ui/banners.lua", "RunBanners")
local controller = context:Controller("CVAR_UPDATE")
assert(controller:GetScript("OnUpdate") == nil, "initially disabled banners retained an idle callback")
context:ResetCounts()
context:SetSetting("customBanners", false)
assert(not context.reads.hud and not context.handler, "settled disabled banners acquired native work")
context:SetSetting("customBanners", true)
assert(controller:GetScript("OnUpdate") and context.handler, "enabling banners did not attach")
assert(context.nativeShown == false, "custom banners did not acquire native HUD")
local function BannerLabel(text)
    for _, object in ipairs(context.objects) do
        if object.kind == "FontString" and object:GetText() == text then return object end
    end
end
context:SetSetting("performanceMode", true)
for index = 1, 4 do
    context.handler({ id = 100 + index, text = "Static banner " .. index })
end
assert(BannerLabel("Static banner 1"):GetAlpha() == 1, "static banner was initially transparent")
assert(not BannerLabel("Static banner 4"), "full banner pool ignored its queue")
context:ResetCounts()
for _ = 1, 10 do
    context.now = context.now + 0.01
    context:Call(controller, "OnUpdate", 0.01)
end
context:NoPresentationWrites()
-- This lies inside the original fade-out window, just before retirement.
context.now = 6.09
context:ResetCounts()
context:Call(controller, "OnUpdate", 3.99)
for index = 1, 3 do
    local label = assert(BannerLabel("Static banner " .. index))
    assert(label:IsShown() and label:GetAlpha() == 1, "static banner faded during its final lifetime window")
end
context:NoPresentationWrites()
context.now = 6.13
context:Call(controller, "OnUpdate", 0.04)
assert(not BannerLabel("Static banner 1"), "static banner failed to expire")
assert(BannerLabel("Static banner 4"):GetAlpha() == 1, "promoted static banner remained transparent")
context:SetLayoutHidden(true)
context.now = 10.24
context:Call(controller, "OnUpdate", 4.11)
context:SetLayoutHidden(false)
assert(not BannerLabel("Static banner 4"), "hidden expired banner replayed on Show")
context:SetLayoutHidden(true)
local hiddenStarted = context.now
context.handler({ id = 106, text = "Hidden static banner" })
assert(not BannerLabel("Hidden static banner"), "hidden intake painted a banner")
context.now = hiddenStarted + 1
context:SetLayoutHidden(false)
local hidden = assert(BannerLabel("Hidden static banner"))
assert(hidden:IsShown() and hidden:GetAlpha() == 1, "hidden-born static banner faded when shown")
context.now = hiddenStarted + 4.11
context:Call(controller, "OnUpdate", 4.11)
assert(not BannerLabel("Hidden static banner"), "showing a hidden-born banner restarted its lifetime")
context:SetSetting("performanceMode", false)
context.handler({ id = 105, text = "Normal banner" })
local normal = assert(BannerLabel("Normal banner"))
assert(normal:GetAlpha() == 0, "normal banner lost its original fade-in")
context.now = context.now + 0.075
context:Call(controller, "OnUpdate", 0.075)
assert(normal:GetAlpha() > 0 and normal:GetAlpha() < 1, "normal fade did not resume")
local faded = normal:GetAlpha()
context:SetSetting("performanceMode", true)
assert(normal:GetAlpha() == 1, "enabling performance mode did not stop the active fade")
context:SetSetting("performanceMode", false)
assert(normal:GetAlpha() == faded, "mode preview restarted the notification lifetime")
print(
    "PASS static banners are opaque, idle between deadlines and retain queued/hidden expiry and normal fade restoration"
)
context.failRestore, context.failUnregister = true, true
context:SetSetting("customBanners", false)
assert(controller:GetScript("OnUpdate") and context.handler, "pending native cleanup was detached")
context.failRestore, context.failUnregister = false, false
context:Call(controller, "OnUpdate", 0.2)
assert(not context.handler and context.nativeShown == true, "pending cleanup did not retry")
assert(controller:GetScript("OnUpdate") == nil, "settled disabled banners retained their driver")
context:SetSetting("customBanners", true)
context.failText = "Injected failure"
context.handler({ id = 1, text = "Injected failure" })
assert(context.handler, "handler-list mutation occurred inside native dispatch")
context:Call(controller, "OnUpdate", 0.2)
assert(not context.handler and controller:GetScript("OnUpdate") == nil, "fault cleanup did not settle")
assert(context.nativeShown == true, "fault cleanup lost the native preference")
print("PASS banners detach when disabled or faulted after retrying pending native cleanup")
