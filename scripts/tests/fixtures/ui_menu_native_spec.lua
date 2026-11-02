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
    -- Stock-layer suppression must not wait for the AS API initialization.
    env.ShowUIPanel = function(frame, force)
        context.reads.panels = (context.reads.panels or 0) + 1
        context.panel = frame
        frame:Show()
        return "native panel", nil, force
    end
    env.HideUIPanel = function(frame)
        if context.panel == frame then context.panel = nil end
        frame:Hide()
    end
    local toggle = function(clicked)
        table.insert(calls, { clicked = clicked })
        env.ShowUIPanel(env.GameMenuFrame, clicked)
        return "native", nil, clicked
    end
    env.ToggleGameMenu = toggle
    env.IsOptionFrameOpen = function() return "native options" end
    env.UpdateMicroButtons = function() return "native buttons" end
    return context, env, toggle, calls
end

for _, performance in ipairs({ false, true }) do
    for _, missing in ipairs({
        false,
        "BenillaOptionsFrame",
        "BenillaOptionsFrameCloseButton",
        "BenillaGameMenuButtonEditMode",
        "BenillaGameMenuButtonSupport",
    }) do
        local context, env, toggle, calls = New(performance)
        if missing then env[missing] = nil end
        local menu = env.GameMenuFrame
        local stockLogout = context:Object("Button", nil, menu)
        local exits, optionOpens = 0, 0
        stockLogout:SetScript("OnClick", function() exits = exits + 1 end)
        -- Independent native AS controls occupy the same pointer location as the
        -- stock Logout rung. Dispatch to both visible layers models the report.
        local asMenu = context:Object("Frame", nil, env.UIParent)
        local asOptions = context:Object("Button", nil, asMenu)
        local optionsPanel = context:Object("Frame", nil, env.UIParent)
        asOptions:SetScript("OnClick", function()
            optionOpens = optionOpens + 1
            env.ShowUIPanel(optionsPanel, "AS options")
        end)
        local function ClickOptions()
            if asOptions:IsVisible() then context:Call(asOptions, "OnClick") end
            if stockLogout:IsVisible() then context:Call(stockLogout, "OnClick") end
        end
        ClickOptions()
        assert(optionOpens == 1 and exits == 1, "fixture did not reproduce the overlapping click")
        exits, optionOpens = 0, 0
        local nativeShow = menu.Show
        menu:SetScript("OnShow", function() exits = exits + 1 end)
        context.panel = menu
        local objectCount, parent = #context.objects, menu:GetParent()
        local options, buttons = env.IsOptionFrameOpen, env.UpdateMicroButtons
        env.T.CreateDFRLFrame = function() error("AS menu constructed a replacement") end
        env.T.CreateButton = function() error("AS menu constructed a button") end
        env.DFRL.layout.Register = function() error("AS menu registered SDUI geometry") end
        context:ResetCounts()
        context:Load("modules/menu/menu.lua", "Menu")
        assert(env.ToggleGameMenu == toggle, "native Escape close ladder replaced")
        assert(env.DFRL.menuframe == nil, "stock menu retained as an addon menu")
        assert(
            #context.objects == objectCount and menu:GetParent() == parent,
            "suppression allocated or reparented frames"
        )
        assert(not menu:IsShown() and context.panel == nil, "stock panel ownership survived suppression")
        assert(env.IsOptionFrameOpen == options and env.UpdateMicroButtons == buttons, "native settings wrappers lost")
        assert(#calls == 0, "initialization invoked the Escape handler")
        context:ResetCounts()

        local first, second, third = env.ToggleGameMenu()
        assert(first == "native" and second == nil and third == nil, "Escape returns changed")
        first, second, third = env.ToggleGameMenu(true)
        assert(first == "native" and second == nil and third == true, "clicked returns changed")
        assert(#calls == 2 and calls[1].clicked == nil and calls[2].clicked == true, "native arguments changed")
        assert(
            not context.reads.panels and context.panel == nil and not menu:IsShown(),
            "stock menu reached the panel manager"
        )
        context:NoPresentationWrites()

        menu:Show()
        nativeShow(menu) -- A retained native Show bypasses the replaced method.
        assert(not menu:IsShown() and not stockLogout:IsVisible() and exits == 0, "native Show exposed stock controls")
        context:ResetCounts()
        first, second, third = env.ShowUIPanel(optionsPanel, "force")
        assert(first == "native panel" and second == nil and third == "force", "other panel arguments/returns changed")
        assert(context.panel == optionsPanel and optionsPanel:IsShown(), "other panel did not open")
        ClickOptions()
        assert(optionOpens == 1 and exits == 0 and optionsPanel:IsShown(), "AS Options reached the hidden stock Logout")
        env.HideUIPanel(optionsPanel)
        assert(context.panel == nil, "ordinary panel close lost ownership")
        context:ResetCounts()
        context:SetSetting("performanceMode", not performance)
        context:NotifyLocale()
        context:NoPresentationWrites()
        local foreign = function() return "foreign" end
        env.ToggleGameMenu = foreign
        context:SetSetting("performanceMode", performance)
        assert(env.ToggleGameMenu == foreign, "later foreign Escape handler overwritten")
    end
end

-- Partial/older kits retain the established fallback, including settings and
-- one Escape consumer per press. The fixture supplies only the native boundary.
for _, missing in ipairs({
    "GameMenuFrame",
    "BenillaOptionsFrame",
    "BenillaOptionsFrameCloseButton",
    "ToggleGameMenu",
}) do
    local context, env, nativeToggle = New(false)
    env.BenillaGameMenuButtonEditMode, env.BenillaGameMenuButtonSupport = nil, nil
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

print("PASS AS Options cannot reach suppressed stock Logout; native Escape and other panel ownership are retained")
print("PASS incomplete native menus retain legacy Escape/settings behavior and layout ownership")
