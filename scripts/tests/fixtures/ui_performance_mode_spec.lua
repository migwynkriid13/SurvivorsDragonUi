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
    display.BeginEdit()
    profiles.BeginEdit()
    display.Set("performanceMode", true)
    assert(profiles.Save("Performance", false), "profile did not capture Performance Mode")
    profiles.FinishEdit(true)
    display.FinishEdit(true)
    assert(env.SurvivorsDragonUiDisplay.performanceMode, "Confirm lost Performance Mode")
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
    context.xp = 60
    context:Event(controller, "PLAYER_XP_UPDATE", "player")
    context:Call(controller, "OnUpdate", 0.05)
    assert(
        bar:GetValue() > 0.2 and bar:GetValue() < 0.6 and gain:IsShown() and spark:IsShown(),
        "normal XP gain did not animate"
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
    assert(
        not controller:GetScript("OnUpdate") and #context.objects == allocated,
        "static XP retained animation or allocated replacement artwork"
    )
    context.level, context.xp = 2, 10
    context:Event(controller, "PLAYER_LEVEL_UP")
    context:Call(controller, "OnUpdate", 0.01)
    assert(bar:GetValue() == 0.1 and not gain:IsShown(), "Performance Mode replayed a level-wrap gain")
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
    local faded, scrolls = nil, 0
    function native:SetTimeVisible(value) assert(value == 14) end
    function native:SetFadeDuration(value) assert(value == 0.6) end
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
    assert(faded == true)
    display.BeginEdit()
    display.Set("performanceMode", true)
    assert(
        faded == false and env.selected.visualAlpha == 1 and native:GetAlpha() == 1,
        "Performance Mode left Chat fading"
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
    assert(faded == false, "hidden mode exit performed native fade work")
    env.root:Show()
    chat.Fade(env.selected, false)
    assert(
        faded == true and not env.selected.slideStart and not env.selected.revealStart,
        "mode exit replayed old Chat motion"
    )
    chat.Notice(env.selected)
    assert(
        env.selected.slideStart == context.now and #context.objects == allocated,
        "normal future Chat motion did not recover"
    )
end
print(
    "PASS extracted Chat toggle stops native fading and active motion, keeps wheel history and restores future effects"
)
