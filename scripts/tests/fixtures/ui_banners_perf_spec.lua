-- CI only: production banner controller over explicit native handler/HUD mocks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
local context = H.New()
local env = context.env
context.settings.customBanners = false
env.DFRL.locale.data = { en = { native = {} } }
env.DFRL.CleanerChat = { IsCaptureEnabled = function() return false end, ListenCapture = function() end }
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
