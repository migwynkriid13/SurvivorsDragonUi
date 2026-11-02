-- CI-only ownership boundaries; no client files or game execution.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")

local nativeGlobals = {
    "GameMenuFrame",
    "BenillaOptionsFrame",
    "BenillaOptionsFrameCloseButton",
    "BenillaGameMenuButtonEditMode",
    "BenillaGameMenuButtonSupport",
}

local function New(performance)
    local context = H.New()
    local env = context.env
    context.settings.performanceMode = performance
    for _, name in ipairs(nativeGlobals) do
        context:Object("Frame", name, env.UIParent)
    end
    local calls = {}
    local toggle = function(clicked)
        table.insert(calls, { clicked = clicked })
        return "native", nil, clicked
    end
    env.ToggleGameMenu = toggle
    env.IsOptionFrameOpen = function() return "native options" end
    env.UpdateMicroButtons = function() return "native buttons" end
    return context, env, toggle, calls
end

for _, performance in ipairs({ false, true }) do
    local context, env, toggle, calls = New(performance)
    local menu = env.GameMenuFrame
    local shows, hides, events = 0, 0, 0
    local onShow = function() shows = shows + 1 end
    local onHide = function() hides = hides + 1 end
    local onEvent = function() events = events + 1 end
    menu:SetScript("OnShow", onShow)
    menu:SetScript("OnHide", onHide)
    menu:SetScript("OnEvent", onEvent)
    menu:RegisterEvent("NATIVE_MENU_EVENT")
    menu:Hide()
    local objectCount = #context.objects
    local parent = menu:GetParent()
    local options, buttons = env.IsOptionFrameOpen, env.UpdateMicroButtons
    env.T.CreateDFRLFrame = function() error("native menu constructed a replacement") end
    env.T.CreateButton = function() error("native menu constructed a button") end
    env.DFRL.layout.Register = function() error("native menu registered SDUI geometry") end
    context:ResetCounts()
    context:Load("modules/menu/menu.lua", "Menu")
    assert(env.ToggleGameMenu == toggle, "native Escape handler replaced")
    assert(env.DFRL.menuframe == menu, "native menu reference lost")
    assert(#context.objects == objectCount and menu:GetParent() == parent, "native menu allocated or reparented")
    assert(menu:GetScript("OnShow") == onShow and menu:GetScript("OnHide") == onHide, "native visibility hooks lost")
    assert(menu:GetScript("OnEvent") == onEvent and menu.events.NATIVE_MENU_EVENT, "native event ownership lost")
    assert(env.IsOptionFrameOpen == options and env.UpdateMicroButtons == buttons, "native settings wrappers lost")
    context:NoPresentationWrites()
    assert(#calls == 0 and not menu:IsShown(), "module opened or invoked the native menu")

    local first, second, third = env.ToggleGameMenu()
    assert(first == "native" and second == nil and third == nil, "Escape returns changed")
    first, second, third = env.ToggleGameMenu(true)
    assert(first == "native" and second == nil and third == true, "portrait click returns changed")
    assert(#calls == 2 and calls[1].clicked == nil and calls[2].clicked == true, "native arguments changed")
    context:SetSetting("performanceMode", not performance)
    context:NotifyLocale()
    context:NoPresentationWrites()

    menu:Show()
    menu:Hide()
    context:Event(menu, "NATIVE_MENU_EVENT")
    assert(shows == 1 and hides == 2 and events == 1, "native callbacks stopped working")
    local foreign = function() return "foreign" end
    env.ToggleGameMenu = foreign
    context:SetSetting("performanceMode", performance)
    assert(env.ToggleGameMenu == foreign, "later foreign handler overwritten")
end

-- Partial/older kits retain the established fallback, including settings and
-- one Escape consumer per press. The fixture supplies only the native boundary.
for _, missing in ipairs({
    "GameMenuFrame",
    "BenillaOptionsFrame",
    "BenillaOptionsFrameCloseButton",
    "BenillaGameMenuButtonEditMode",
    "BenillaGameMenuButtonSupport",
    "ToggleGameMenu",
}) do
    local context, env, nativeToggle = New(false)
    env[missing] = nil
    local widgets = {}
    env.T.CreateDFRLFrame = function(parent, width, height)
        local frame = context:Object("Frame", nil, parent)
        frame.width, frame.height = width, height
        return frame
    end
    env.T.CreateButton = function(parent, caption)
        local button = context:Object("Button", nil, parent)
        widgets[caption] = button
        return button
    end
    local order, consumes = {}, nil
    for _, name in ipairs({
        "StaticPopup_EscapePressed",
        "CloseMenus",
        "SpellStopCasting",
        "SpellStopTargeting",
        "CloseAllWindows",
    }) do
        local operation = name
        env[operation] = function()
            table.insert(order, operation)
            return consumes == operation
        end
    end
    local target = false
    env.UnitExists = function(unit)
        assert(unit == "target")
        return target
    end
    env.ClearTarget = function()
        table.insert(order, "ClearTarget")
        target = false
    end
    env.ShowUIPanel = function(frame) frame:Show() end
    env.HideUIPanel = function(frame) frame:Hide() end
    env.Quit = function() table.insert(order, "Quit") end
    if env.BenillaOptionsFrame then env.BenillaOptionsFrame:Hide() end
    if env.BenillaOptionsFrameCloseButton then
        env.BenillaOptionsFrameCloseButton.Click = function() env.BenillaOptionsFrame:Hide() end
    end
    context:Load("modules/menu/menu.lua", "Menu")
    local menu = env.DFRL.menuframe
    assert(menu and menu ~= env.GameMenuFrame and context.layoutFrame == menu, "legacy fallback not registered")
    assert(env.ToggleGameMenu ~= nativeToggle and not menu:IsShown(), "legacy handler not installed")
    if env.GameMenuFrame then assert(not env.GameMenuFrame:IsShown(), "fallback left stock menu visible") end
    consumes = "StaticPopup_EscapePressed"
    env.ToggleGameMenu()
    assert(#order == 1 and not menu:IsShown(), "popup Escape fell through")
    order, consumes = {}, "CloseAllWindows"
    env.ToggleGameMenu()
    assert(#order == 5 and not menu:IsShown(), "window Escape fell through")
    order, consumes, target = {}, nil, true
    env.ToggleGameMenu()
    assert(order[#order] == "ClearTarget" and not menu:IsShown(), "target Escape opened menu")
    env.ToggleGameMenu()
    assert(menu:IsShown(), "idle legacy Escape did not open menu")
    context:Call(widgets["Resume Game"], "OnClick")
    assert(not menu:IsShown(), "legacy Resume did not close menu")
    target = true
    env.ToggleGameMenu(true)
    assert(menu:IsShown() and target, "deliberate click cleared target or failed to open menu")
    if env.BenillaOptionsFrame then
        context:Call(widgets.Options, "OnClick")
        assert(not menu:IsShown() and env.BenillaOptionsFrame:IsShown(), "legacy Options did not open settings")
        env.ToggleGameMenu()
        assert(not menu:IsShown() and not env.BenillaOptionsFrame:IsShown(), "settings Escape fell through")
    else
        assert(widgets.Options == nil, "legacy kit invented unavailable settings")
    end
end

print("PASS native menu retains Escape, click, settings, events and visibility ownership without SDUI allocation")
print("PASS incomplete native menus retain legacy Escape/settings behavior and layout ownership")
