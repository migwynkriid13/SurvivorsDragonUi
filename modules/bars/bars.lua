DFRL:NewMod("Bars", 1, function()
    -- The run fills slots 1-6; the always-available ability stays in native slot 12.
    local ACTION_SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
    local BUTTON_COUNT = 7
    local BUTTON_SPACING = 6
    local TEX_PATH = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\actionbars\\"

    local function DisableFrame(frame)
        if not frame then return end
        KillFrame(frame)
        if frame.SetScript then frame:SetScript("OnShow", function() frame:Hide() end) end
    end

    local function HideHotkey(button)
        local hotkey = _G[button:GetName() .. "HotKey"]
        if hotkey then
            hotkey:SetText("")
            hotkey:Hide()
        end
    end

    local function HideStockBars()
        HideFrameTextures(MainMenuBar)
        HideFrameTextures(MainMenuBarArtFrame)
        MainMenuBar:EnableMouse(false)
        MainMenuBarArtFrame:EnableMouse(false)

        for _, name in ipairs({
            "ActionBarUpButton",
            "ActionBarDownButton",
            "MainMenuBarPageNumber",
            "MultiBarBottomLeft",
            "MultiBarBottomRight",
            "MultiBarLeft",
            "MultiBarRight",
            "PetActionBarFrame",
            "ShapeshiftBarFrame",
            "BonusActionBarFrame",
            "PossessBarFrame",
            "ExhaustionTick",
        }) do
            DisableFrame(_G[name])
        end

        for i = BUTTON_COUNT + 1, 12 do
            DisableFrame(_G["ActionButton" .. i])
        end
        for _, prefix in ipairs({
            "MultiBarBottomLeftButton",
            "MultiBarBottomRightButton",
            "MultiBarLeftButton",
            "MultiBarRightButton",
            "BonusActionButton",
            "PetActionButton",
            "ShapeshiftButton",
            "PossessButton",
        }) do
            for i = 1, 12 do
                DisableFrame(_G[prefix .. i])
            end
        end
        for _, name in ipairs({
            "MainMenuBarLeftEndCap",
            "MainMenuBarRightEndCap",
            "SlidingActionBarTexture0",
            "SlidingActionBarTexture1",
            "BonusActionBarTexture0",
            "BonusActionBarTexture1",
            "ShapeshiftBarLeft",
            "ShapeshiftBarMiddle",
            "ShapeshiftBarRight",
        }) do
            local texture = _G[name]
            if texture then texture:SetTexture(nil) end
        end

        -- The six run abilities and the permanent ability stay on the first page.
        -- Page bindings must not silently replace the skills behind those buttons.
        local changePage = _G.ChangeActionBarPage
        local function KeepMainPage()
            _G.CURRENT_ACTIONBAR_PAGE = 1
            if changePage then changePage() end
        end
        _G.ChangeActionBarPage = KeepMainPage
        _G.ActionBar_PageUp = KeepMainPage
        _G.ActionBar_PageDown = KeepMainPage
        _G.MultiActionBar_Update = function() end
        _G.ShowBonusActionBar = function() end
        _G.HideBonusActionBar = function() end
        _G.SHOW_MULTI_ACTIONBAR_1 = nil
        _G.SHOW_MULTI_ACTIONBAR_2 = nil
        _G.SHOW_MULTI_ACTIONBAR_3 = nil
        _G.SHOW_MULTI_ACTIONBAR_4 = nil
        KeepMainPage()

        local buttonDown, buttonUp = _G.ActionButtonDown, _G.ActionButtonUp
        _G.ActionButtonDown = function(id)
            if id >= 1 and id <= BUTTON_COUNT then buttonDown(id) end
        end
        _G.ActionButtonUp = function(id, onSelf)
            if id >= 1 and id <= BUTTON_COUNT then buttonUp(id, onSelf) end
        end
        -- Existing client bindings must not execute slots on discarded bars.
        for _, name in ipairs({
            "MultiActionButtonDown",
            "MultiActionButtonUp",
            "BonusActionButtonDown",
            "BonusActionButtonUp",
            "PetActionButtonDown",
            "PetActionButtonUp",
            "ShapeshiftBar_ChangeForm",
        }) do
            _G[name] = function() end
        end
    end

    local function CreateBackground(bar)
        local left = bar:CreateTexture("DFRL_ActionBarLeftTexture", "BACKGROUND")
        left:SetTexture(TEX_PATH .. "HDActionBar.tga")
        left:SetPoint("LEFT", bar, "LEFT", -6, 0)
        left:SetPoint("RIGHT", bar, "CENTER", 0, 0)
        left:SetPoint("TOP", bar, "TOP", 0, 14)
        left:SetPoint("BOTTOM", bar, "BOTTOM", 0, -14)

        local right = bar:CreateTexture("DFRL_ActionBarRightTexture", "BACKGROUND")
        right:SetTexture(TEX_PATH .. "HDActionBar.tga")
        right:SetPoint("LEFT", bar, "CENTER", 0, 0)
        right:SetPoint("RIGHT", bar, "RIGHT", 6, 0)
        right:SetPoint("TOP", bar, "TOP", 0, 14)
        right:SetPoint("BOTTOM", bar, "BOTTOM", 0, -14)
        right:SetTexCoord(1, 0, 0, 1)
        DFRL.actionBarBGleft = left
        DFRL.actionBarBGright = right
    end

    local function StyleButton(button, index, bar)
        button:SetParent(DFRL.mainBar)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", DFRL.mainBar, "BOTTOMLEFT", (index - 1) * (button:GetWidth() + BUTTON_SPACING), 0)
        button:SetScale(1)
        button:SetAlpha(1)
        button:SetFrameStrata("LOW")
        button:SetFrameLevel(4)

        local background = bar:CreateTexture("DFRL_ActionButtonBg" .. index, "BORDER")
        background:SetTexture(TEX_PATH .. "HDActionBarBtn.tga")
        background:SetPoint("CENTER", button, "CENTER", 0, 0)
        background:SetWidth(button:GetWidth() + 5)
        background:SetHeight(button:GetHeight() + 5)

        local border = button:CreateTexture(button:GetName() .. "DFRL_BorderOverlay", "OVERLAY")
        border:SetTexture(TEX_PATH .. "border.blp")
        border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        button.DFRL_BorderOverlay = border

        button:SetHighlightTexture(TEX_PATH .. "uiactionbariconframehighlight.tga")
        local highlight = button:GetHighlightTexture()
        highlight:SetAllPoints(button)
        highlight:SetBlendMode("ADD")
        highlight:SetVertexColor(1, 0.82, 0)

        HideHotkey(button)

        local macro = _G[button:GetName() .. "Name"]
        macro:ClearAllPoints()
        macro:SetPoint("TOP", button, "TOP", 0, 2)
        macro:SetFont("DEFAULT", 13, "OUTLINE")
        macro:SetTextColor(1, 1, 1)
    end

    local initialized = false
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    local function InitializeBar()
        if initialized then return end
        initialized = true

        -- Keep the seventh frame's ID and ACTIONBUTTON7 binding, while every
        -- stock action handler (including slot-change events) reads native slot 12.
        local getPagedID = _G.ActionButton_GetPagedID
        _G.ActionButton_GetPagedID = function(button)
            if button.DFRL_actionSlot then return button.DFRL_actionSlot end
            return getPagedID(button)
        end
        for i = 1, BUTTON_COUNT do
            _G["ActionButton" .. i].DFRL_actionSlot = ACTION_SLOTS[i]
        end
        HideStockBars()

        local mainBar = CreateFrame("Frame", "DFRL_MainBar", UIParent)
        mainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 55)
        mainBar:SetWidth(BUTTON_COUNT * ActionButton1:GetWidth() + (BUTTON_COUNT - 1) * BUTTON_SPACING)
        mainBar:SetHeight(ActionButton1:GetHeight())
        mainBar:SetClampedToScreen(true)
        mainBar:SetFrameStrata("LOW")
        mainBar:SetFrameLevel(1)
        DFRL.mainBar = mainBar

        local art = CreateFrame("Frame", "DFRL_ActionBar", mainBar)
        art:SetAllPoints(mainBar)
        art:SetFrameStrata("LOW")
        art:SetFrameLevel(2)
        DFRL.actionBarFrame = art
        DFRL.actionButtons = {}
        CreateBackground(art)
        for i = 1, BUTTON_COUNT do
            local button = _G["ActionButton" .. i]
            StyleButton(button, i, art)
            DFRL.actionButtons[i] = button
        end
        -- Keep stock cooldown, usability, click and action-slot updates.
        -- Binding and action refreshes must keep button-number labels hidden.
        _G.ActionButton_UpdateHotkeys = function()
            for _, button in ipairs(DFRL.actionButtons) do
                HideHotkey(button)
            end
        end
        local previousThis = _G.this
        for _, button in ipairs(DFRL.actionButtons) do
            _G.this = button
            ActionButton_Update()
        end
        _G.this = previousThis
        local moveRegion = CreateFrame("Frame", nil, mainBar)
        moveRegion:SetPoint("TOPLEFT", mainBar, "TOPLEFT", -6, 14)
        moveRegion:SetPoint("BOTTOMRIGHT", mainBar, "BOTTOMRIGHT", 6, 0)
        DFRL.layout.Register("actionBar", mainBar, function()
            mainBar:ClearAllPoints()
            mainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 55)
        end, { region = moveRegion })
        if DFRL.AttachXPBar then DFRL.AttachXPBar(mainBar) end
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        events:SetScript("OnEvent", nil)
    end
    events:SetScript("OnEvent", InitializeBar)
    -- The port can load loose addons after the initial world event.
    if UnitExists("player") then InitializeBar() end
end)
