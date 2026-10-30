-- CI only: real display/profile transactions, XP controller and extracted Chat owners.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "Performance Mode fixtures require CI Lua 5.1")

local function Read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end

do
    local context = H.New()
    local env = context.env
    context:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    assert(display.Get("performanceMode") == false, "Performance Mode must default off")
    assert(display.Copy({ performanceMode = "true" }).performanceMode == false, "invalid mode did not default off")
    assert(display.Copy({ performanceMode = true }).performanceMode == true, "explicit mode was lost")
    display.BeginEdit()
    display.Set("performanceMode", true)
    assert(display.Get("performanceMode") and not env.SurvivorsDragonUiDisplay, "preview saved Performance Mode early")
    display.FinishEdit(false)
    assert(not display.Get("performanceMode"), "Cancel retained Performance Mode preview")

    local function Copy(value)
        local result = {}
        for key, item in pairs(value) do
            result[key] = item
        end
        return result
    end
    env.DFRL.layout.Copy = Copy
    env.DFRL.layout.Snapshot = function() return {} end
    env.DFRL.layout.Load = function() end
    env.DFRL.runFont = { Copy = Copy, Snapshot = function() return {} end, Load = function() end }
    context:Load("core/profiles.lua", "Profiles")
    local profiles = env.DFRL.profiles
    -- The separate retail Layout fixture covers the production shared commit.
    env.DFRL.layout.ConfirmEdit = function()
        display.FinishEdit(true)
        profiles.FinishEdit(true)
        return true
    end
    display.BeginEdit()
    profiles.BeginEdit()
    display.Set("performanceMode", true)
    assert(profiles.Save("Performance", false), "profile did not capture Performance Mode")
    assert(env.SurvivorsDragonUiDisplay.performanceMode, "profile save did not commit Performance Mode")
    assert(env.SurvivorsDragonUiProfiles.Performance.display.performanceMode, "saved profile lost Performance Mode")
    display.BeginEdit()
    display.Set("performanceMode", false)
    display.FinishEdit(true)
    display.BeginEdit()
    profiles.BeginEdit()
    assert(profiles.Load("Performance"))
    assert(
        display.Get("performanceMode") and not env.SurvivorsDragonUiDisplay.performanceMode,
        "profile load saved early"
    )
    profiles.FinishEdit(false)
    display.FinishEdit(false)
    assert(not display.Get("performanceMode"), "profile discard changed the confirmed mode")
    display.BeginEdit()
    profiles.BeginEdit()
    assert(profiles.Load("Performance"))
    profiles.FinishEdit(true)
    display.FinishEdit(true)
    assert(display.Get("performanceMode"), "confirmed profile load lost Performance Mode")
    display.BeginEdit()
    display.Reset()
    assert(
        not display.Get("performanceMode") and not env.SurvivorsDragonUiDisplay,
        "reset did not restore default-off mode"
    )
    display.BeginEdit()
    display.Set("performanceMode", true)
    display.FinishEdit(true)
    display.Reset()
    assert(not display.Get("performanceMode"), "reset outside editing retained Performance Mode")
end
print("PASS Performance Mode defaults, invalid values, preview/Cancel/Confirm, profiles and resets")

do
    local context = H.New()
    local env = context.env
    context.xp, context.maximum, context.level = 20, 100, 1
    env.KillFrame = function() end
    env.UnitXP = function() return context.xp end
    env.UnitXPMax = function() return context.maximum end
    env.UnitLevel = function() return context.level end
    env.DFRL.mainBar = env.CreateFrame("Frame", "PerformanceActionBar", env.UIParent)
    env.DFRL.actionBarDefaults = { sideInset = 2, xpTop = 0, xpInset = 2 }
    env.T.GetLocalSize = function(frame) return frame:GetWidth(), frame:GetHeight() end
    env.T.SetChatShadow = function(label)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
    end
    local create = context.Object
    function context:Object(...)
        local object = create(self, ...)
        function object:SetStatusBarTexture(value) self.texture = value end
        function object:SetStatusBarColor() end
        function object:SetMinMaxValues(low, high)
            self.minimum, self.maximum = low, high
        end
        function object:GetValue() return self.value end
        function object:SetValue(value)
            context.writes.SetValue = (context.writes.SetValue or 0) + 1
            self.value = value
        end
        function object:SetBlendMode(value) assert(value == "ADD") end
        function object:SetParent(parent) self.parent = parent end
        function object:SetScale(value) self.scale = value end
        return object
    end
    context:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    context:Load("modules/xprep/xprep.lua", "Xprep")
    local controller = context:Controller("PLAYER_XP_UPDATE")
    local bar = env.DFRL_XPBar
    local gain, spark
    for _, object in ipairs(context.objects) do
        if object.parent == bar and object.kind == "Texture" then
            if object.texture and object.texture:find("main_soft.blp", 1, true) then gain = object end
            if object.texture == "Interface\\CastingBar\\UI-CastingBar-Spark" then spark = object end
        end
    end
    assert(gain and spark and bar:IsVisible(), "missing production XP effect regions")
    context:Call(controller, "OnUpdate", 0.01)
    assert(bar:GetValue() == 0.2 and not controller:GetScript("OnUpdate"), "initial XP did not settle")
    assert(display.Get("xpShowText") == false and display.Copy({ xpShowText = "true" }).xpShowText == false)
    local function XPLabel()
        for _, object in ipairs(context.objects) do
            if object.parent == bar and object.kind == "FontString" then return object end
        end
    end
    assert(not XPLabel(), "disabled XP text allocated a label")
    env.DFRL.mainBar:Hide()
    display.BeginEdit()
    display.Set("xpShowText", true)
    assert(not XPLabel() and not controller:GetScript("OnUpdate"), "hidden text preview allocated or added a worker")
    env.DFRL.mainBar:Show()
    context:Call(controller, "OnUpdate", 0.01)
    local text = assert(XPLabel(), "XP text did not prepare on first visible preview")
    assert(text:GetText() == "20/100" and text:IsShown(), "XP text missed current native values")
    assert(
        not env.SurvivorsDragonUiDisplay and not controller:GetScript("OnUpdate"),
        "text preview saved or added a worker"
    )
    display.FinishEdit(false)
    assert(not text:IsShown(), "Cancel retained XP text")
    local textPoolSize = #context.objects
    display.BeginEdit()
    display.Set("xpShowText", true)
    display.FinishEdit(true)
    assert(
        env.SurvivorsDragonUiDisplay.xpShowText and #context.objects == textPoolSize,
        "Confirm lost text or its pool"
    )
    display.BeginEdit()
    display.Load({ xpShowText = false })
    assert(not text:IsShown(), "profile did not preview hiding XP text")
    display.FinishEdit(false)
    assert(text:IsShown(), "profile discard lost confirmed XP text")
    context.xp = 60
    context:Event(controller, "PLAYER_XP_UPDATE", "player")
    context:Call(controller, "OnUpdate", 0.05)
    assert(
        bar:GetValue() > 0.2 and bar:GetValue() < 0.6 and gain:IsShown() and spark:IsShown(),
        "normal XP gain did not animate"
    )
    assert(text:GetText() == "60/100", "XP text followed the animation instead of native XP")
    local progress, worker = bar:GetValue(), controller:GetScript("OnUpdate")
    display.BeginEdit()
    display.Set("xpShowText", false)
    display.Set("xpShowText", true)
    assert(
        bar:GetValue() == progress and controller:GetScript("OnUpdate") == worker,
        "text preview restarted an active gain"
    )
    display.BeginEdit()
    display.Set("performanceMode", true)
    assert(
        bar:GetValue() == 0.6 and not gain:IsShown() and not spark:IsShown(),
        "Performance Mode did not settle the active XP gain"
    )
    assert(not controller:GetScript("OnUpdate"), "Performance Mode retained an XP animation worker")
    local allocated = #context.objects
    context.xp = 80
    context:Event(controller, "PLAYER_XP_UPDATE", "player")
    context:Call(controller, "OnUpdate", 0.01)
    assert(
        bar:GetValue() == 0.8 and not gain:IsShown() and not spark:IsShown(),
        "Performance Mode did not use native XP immediately"
    )
    assert(text:GetText() == "80/100", "Performance Mode changed the compact XP format")
    assert(
        not controller:GetScript("OnUpdate") and #context.objects == allocated,
        "static XP retained animation or allocated replacement artwork"
    )
    context.level, context.xp = 2, 10
    context:Event(controller, "PLAYER_LEVEL_UP")
    context:Call(controller, "OnUpdate", 0.01)
    assert(bar:GetValue() == 0.1 and not gain:IsShown(), "Performance Mode replayed a level-wrap gain")
    assert(text:GetText() == "10/100", "level-up text retained the old level's XP")
    display.FinishEdit(false)
    assert(bar:GetValue() == 0.1 and not controller:GetScript("OnUpdate"), "Cancel replayed a suppressed XP gain")
    context.xp = 50
    context:Event(controller, "PLAYER_XP_UPDATE", "player")
    context:Call(controller, "OnUpdate", 0.05)
    assert(
        bar:GetValue() > 0.1 and bar:GetValue() < 0.5 and gain:IsShown(),
        "mode exit did not restore future XP animation"
    )
    display.BeginEdit()
    display.Set("performanceMode", true)
    context:Event(controller, "PLAYER_LEAVING_WORLD")
    assert(
        not controller:GetScript("OnUpdate") and not bar:IsShown() and not gain:IsShown() and not spark:IsShown(),
        "world retirement retained XP presentation"
    )
    assert(not text:IsShown(), "world retirement retained XP text")
    context.level, context.xp, context.maximum = 3, 90, 200
    context:Event(controller, "PLAYER_ENTERING_WORLD")
    context:Call(controller, "OnUpdate", 0.01)
    assert(text:GetText() == "90/200" and text:IsVisible(), "world entry replayed stale XP text")
    context:ResetCounts()
    context:Event(controller, "PLAYER_XP_UPDATE", "player")
    context:Call(controller, "OnUpdate", 0.01)
    assert(not context.writes.SetText, "unchanged XP rewrote the caption")
    context.maximum = 0
    context:Event(controller, "PLAYER_XP_UPDATE", "player")
    context:Call(controller, "OnUpdate", 0.01)
    assert(not text:IsShown() and not bar:IsVisible(), "invalid XP retained a caption")
    context.maximum, context.xp = 200, 0
    context:Event(controller, "PLAYER_XP_UPDATE", "player")
    context:Call(controller, "OnUpdate", 0.01)
    assert(text:GetText() == "0/200" and text:IsVisible(), "zero XP or invalid-data recovery failed")
    display.BeginEdit()
    display.Set("attachXP", false)
    assert(text:IsVisible() and #context.objects == textPoolSize, "detaching XP replaced or lost text")
    display.Reset()
    assert(not text:IsShown() and not display.Get("xpShowText"), "reset retained XP text")
end
print(
    "PASS full XP controller settles active effects, keeps current native progress and restores future animation without replay"
)

do
    local context = H.New()
    local env = context.env
    context:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    env.root = env.CreateFrame("Frame", nil, env.UIParent)
    local native = env.CreateFrame("Frame", nil, env.root)
    local faded, scrolls, timeVisible, fadeDuration = nil, 0, nil, nil
    function native:SetTimeVisible(value) timeVisible = value end
    function native:SetFadeDuration(value) fadeDuration = value end
    function native:SetFading(value) faded = value end
    function native:AtBottom() return true end
    function native:ScrollDown() scrolls = scrolls + 1 end
    env.selected = { native = native, visualAlpha = 0.2, slideStart = context.now, revealStart = context.now }
    env.states = { env.selected }
    env.rootWidth, env.rootHeight = 520, 340
    env.Flag = function(value) return value == true or value == 1 end
    env.Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end
    local source = Read("modules/chat/chat.lua")
    local first = assert(source:find("        DFRL.display.Listen(function()", 1, true))
    assert(
        not source:find("        DFRL.display.Listen(function()", first + 1, true),
        "ambiguous Chat mode-listener seam"
    )
    local last = assert(source:find('        HookScript(root, "OnHide", function()', first, true))
    local body = Read(assert(arg[1], "missing extracted Chat source"))
    local returnAt = assert(body:find("\nreturn NoticeMessage", 1, true))
    body = 'local performanceMode = DFRL.display.Get("performanceMode")\n'
        .. body:sub(1, returnAt - 1)
        .. source:sub(first, last - 1)
        .. "\nreturn { Fade = FadeSettings, Notice = NoticeMessage, Reveal = Reveal }"
    local chunk = assert(loadstring(body, "@production-chat-performance"))
    setfenv(chunk, env)
    local chat = chunk()
    chat.Fade(env.selected, false)
    assert(faded == true and timeVisible == 14 and fadeDuration == 0.6)
    display.BeginEdit()
    display.Set("performanceMode", true)
    assert(
        faded == true
            and math.abs(timeVisible - 14.6) < 0.000001
            and fadeDuration == 0
            and env.selected.visualAlpha == 1
            and native:GetAlpha() == 1,
        "Performance Mode stopped Chat expiry or retained its native fade"
    )
    assert(not env.selected.slideStart and not env.selected.revealStart, "Performance Mode retained active Chat motion")
    local allocated = #context.objects
    chat.Notice(env.selected)
    assert(not env.selected.slideStart, "Performance Mode started new Chat motion")
    context.now = 100
    chat.Reveal(env.selected)
    assert(
        not env.selected.revealStart and env.selected.visualAlpha == 1 and scrolls == 1,
        "static Chat lost wheel history or started a reveal"
    )
    env.root:Hide()
    display.FinishEdit(false)
    assert(fadeDuration == 0, "hidden mode exit performed native fade work")
    env.root:Show()
    chat.Fade(env.selected, false)
    assert(
        faded == true
            and timeVisible == 14
            and fadeDuration == 0.6
            and not env.selected.slideStart
            and not env.selected.revealStart,
        "mode exit replayed old Chat motion"
    )
    chat.Notice(env.selected)
    assert(
        env.selected.slideStart == context.now and #context.objects == allocated,
        "normal future Chat motion did not recover"
    )
end
print(
    "PASS extracted Chat toggle keeps instant native expiry and wheel history, settles motion and restores future effects"
)
