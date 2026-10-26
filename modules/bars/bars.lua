DFRL:NewMod("Bars", 1, function()
    -- The run fills slots 1-6; the always-available ability stays in native slot 12.
    local ACTION_SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
    local BUTTON_COUNT = 7
    local BUTTON_SPACING = 6
    local COOLDOWN_INTERVAL = 0.1
    local COOLDOWN_ZERO = 0.1
    local COOLDOWN_FINAL_WINDOW = 0.2
    local COOLDOWN_UNITS = { { 86400, "d" }, { 3600, "h" }, { 60, "m" }, { 1, "" } }
    local TEX_PATH = DFRL:GetInfoOrCons("tex") .. "actionbars\\"
    -- Dragonflight gryphon crop and source: third_party/XP-ARTWORK.md.
    -- Retain retail proportions after trimming the atlas member's empty edges;
    -- tuck the chest into the shell so the shorter bar has no side gap.
    local ornament = {
        width = 104.5 * 312 / 356,
        height = 98 * 306 / 334,
        overlap = 14 - 104.5 * 5 / 356,
        bottom = -22 + 98 * 18 / 334,
        endU = 312 / 512,
        endV = 306 / 512,
    }
    local defaults = {
        bottom = 55,
        topInset = 14,
        sideInset = 6,
        buttonWidth = ActionButton1:GetWidth(),
        buttonGap = BUTTON_SPACING,
        width = BUTTON_COUNT * ActionButton1:GetWidth() + (BUTTON_COUNT - 1) * BUTTON_SPACING,
        height = ActionButton1:GetHeight(),
        xpExtension = 8,
        xpTop = -3,
        xpInset = 9,
    }
    -- The half-shell keeps sixteen transparent source rows below its silver
    -- bevel, including in the taller joined-XP crop.
    defaults.silverBottomInset = (defaults.height + 2 * defaults.topInset) * 16 / 128
    DFRL.actionBarDefaults = defaults

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
        left:SetTexture(TEX_PATH .. "HDActionBar.blp")
        left:SetPoint("LEFT", bar, "LEFT", -defaults.sideInset, 0)
        left:SetPoint("RIGHT", bar, "CENTER", 0, 0)
        left:SetPoint("TOP", bar, "TOP", 0, defaults.topInset)
        left:SetPoint("BOTTOM", bar, "BOTTOM", 0, -defaults.topInset)

        local right = bar:CreateTexture("DFRL_ActionBarRightTexture", "BACKGROUND")
        right:SetTexture(TEX_PATH .. "HDActionBar.blp")
        right:SetPoint("LEFT", bar, "CENTER", 0, 0)
        right:SetPoint("RIGHT", bar, "RIGHT", defaults.sideInset, 0)
        right:SetPoint("TOP", bar, "TOP", 0, defaults.topInset)
        right:SetPoint("BOTTOM", bar, "BOTTOM", 0, -defaults.topInset)
        right:SetTexCoord(1, 0, 0, 1)
        DFRL.actionBarBGleft = left
        DFRL.actionBarBGright = right

        -- Keep every socket foot and straight span in one texture and anchor
        -- space. Separate scaled caps can round to different screen rows.
        local artHeight = defaults.height + 2 * defaults.topInset
        local socketBottom = defaults.buttonWidth * 2 / 36
        local upper = bar:CreateTexture(nil, "BACKGROUND")
        upper:SetTexture(DFRL:GetInfoOrCons("tex") .. "jewelry\\SocketRail.blp")
        upper:SetPoint("TOPLEFT", bar, "TOPLEFT", -defaults.sideInset, defaults.buttonWidth * 40 / 36)
        upper:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", defaults.sideInset, socketBottom)
        upper:SetTexCoord(0, 1200 / 2048, 0, 152 / 256)
        upper:Hide()
        local jewelryShown, xpJoined = false, false
        local jewelryTop = defaults.topInset
        local ornaments, ornamentsShown
        local tallyExtent = 0
        local boundRegion, boundSide, boundTop, boundBottom
        local function SilverBottom()
            return -defaults.topInset - (xpJoined and defaults.xpExtension or 0) + defaults.silverBottomInset
        end
        local function UpdateBounds()
            local region = DFRL.actionBarMoveRegion
            if not region then return end
            local side, top = defaults.sideInset, jewelryTop
            local bottom = xpJoined and -(defaults.topInset + defaults.xpExtension) or 0
            if tallyExtent > 0 then bottom = math.min(bottom, SilverBottom() - tallyExtent) end
            if ornamentsShown then
                side = math.max(side, ornament.width - ornament.overlap)
                top = math.max(top, ornament.bottom + ornament.height - defaults.height)
                bottom = math.min(bottom, ornament.bottom)
            end
            if boundRegion == region and boundSide == side and boundTop == top and boundBottom == bottom then return end
            region:SetPoint("TOPLEFT", DFRL.mainBar, "TOPLEFT", -side, top)
            region:SetPoint("BOTTOMRIGHT", DFRL.mainBar, "BOTTOMRIGHT", side, bottom)
            boundRegion, boundSide, boundTop, boundBottom = region, side, top, bottom
        end
        DFRL.RefreshActionBarBounds = UpdateBounds
        function DFRL.SetActionBarJewelryTop(top)
            if jewelryTop == top then return end
            jewelryTop = top
            UpdateBounds()
        end
        function DFRL.GetActionBarSilverBottom() return SilverBottom() end
        function DFRL.SetRunTallyBarExtent(extent)
            tallyExtent = extent or 0
            UpdateBounds()
        end
        local function UpdateOrnaments()
            local shown = DFRL.display.Get("showGryphons")
            if ornamentsShown == shown then return end
            if shown and not ornaments then
                ornaments = {}
                for index, side in ipairs({ "LEFT", "RIGHT" }) do
                    local texture = bar:CreateTexture(nil, "OVERLAY")
                    texture:SetTexture(TEX_PATH .. "Gryphon.blp")
                    texture:SetWidth(ornament.width)
                    texture:SetHeight(ornament.height)
                    local opposite = side == "LEFT" and "RIGHT" or "LEFT"
                    texture:SetPoint(
                        "BOTTOM" .. opposite,
                        bar,
                        "BOTTOM" .. side,
                        index == 1 and ornament.overlap or -ornament.overlap,
                        ornament.bottom
                    )
                    texture:SetTexCoord(
                        index == 1 and 0 or ornament.endU,
                        index == 1 and ornament.endU or 0,
                        0,
                        ornament.endV
                    )
                    table.insert(ornaments, texture)
                end
            end
            if ornaments then
                for _, texture in ipairs(ornaments) do
                    if shown then
                        texture:Show()
                    else
                        texture:Hide()
                    end
                end
            end
            ornamentsShown = shown
            UpdateBounds()
        end
        DFRL.display.Listen(UpdateOrnaments)
        UpdateOrnaments()
        local function UpdateBackground()
            local top = jewelryShown and socketBottom or defaults.topInset
            local bottom = -defaults.topInset - (xpJoined and defaults.xpExtension or 0)
            local texture = TEX_PATH .. (xpJoined and "HDActionBarXP.blp" or "HDActionBar.blp")
            local endUV = xpJoined and 144 / 256 or 1
            local height = artHeight + (xpJoined and defaults.xpExtension or 0)
            local topUV = jewelryShown and (defaults.topInset - socketBottom) / height * endUV or 0
            left:SetTexture(texture)
            right:SetTexture(texture)
            left:ClearAllPoints()
            left:SetPoint("TOPLEFT", bar, "TOPLEFT", -defaults.sideInset, top)
            left:SetPoint("BOTTOMRIGHT", bar, "BOTTOM", 0, bottom)
            right:ClearAllPoints()
            right:SetPoint("TOPLEFT", bar, "TOP", 0, top)
            right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", defaults.sideInset, bottom)
            left:SetTexCoord(0, 1, topUV, endUV)
            right:SetTexCoord(1, 0, topUV, endUV)
            if jewelryShown then
                upper:Show()
            else
                upper:Hide()
            end
        end
        function DFRL.SetJewelryBarShown(shown)
            if jewelryShown == shown then return end
            jewelryShown = shown
            UpdateBackground()
        end
        function DFRL.SetXPBarJoined(shown)
            if xpJoined == shown then return end
            xpJoined = shown
            UpdateBackground()
            UpdateBounds()
            if DFRL.RefreshRunTallyAttachment then DFRL.RefreshRunTallyAttachment() end
        end
    end

    local selectedButton
    local function ClearSelection()
        if selectedButton then selectedButton.DFRL_swapSelection:Hide() end
        selectedButton = nil
    end

    local function SelectOrSwap(button)
        if
            type(PickupAction) ~= "function"
            or type(PlaceAction) ~= "function"
            or type(CursorHasSpell) ~= "function"
            or type(CursorHasItem) ~= "function"
            or CursorHasSpell()
            or CursorHasItem()
        then
            ClearSelection()
            return
        end
        local target = ActionButton_GetPagedID(button)
        local source = selectedButton and ActionButton_GetPagedID(selectedButton)
        if not HasAction(target) or source == target then
            ClearSelection()
            return
        end
        if not source then
            selectedButton = button
            button.DFRL_swapSelection:Show()
            return
        end
        ClearSelection()
        if not HasAction(source) then return end
        -- Only this synchronous exchange uses the native cursor. Selection never
        -- picks up an action, and a refused destination returns it to its source.
        local success, message = pcall(function()
            PickupAction(source)
            if CursorHasSpell() then PlaceAction(target) end
        end)
        if CursorHasSpell() then PlaceAction(source) end
        if not success then geterrorhandler()(message) end
    end

    local function StyleButton(button, index, bar)
        -- Never expose pickup or outside drops. Unlocked Shift-clicks select two
        -- occupied native slots; ordinary clicks keep their original activation.
        button:RegisterForDrag()
        button:SetScript("OnDragStart", nil)
        button:SetScript("OnReceiveDrag", nil)
        button:SetScript("OnClick", function()
            if arg1 == "LeftButton" and IsShiftKeyDown() and not DFRL.display.Get("lockActionButtons") then
                SelectOrSwap(button)
                return
            end
            ClearSelection()
            UseAction(ActionButton_GetPagedID(button), 0)
            ActionButton_UpdateState()
        end)
        button:SetParent(DFRL.mainBar)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", DFRL.mainBar, "BOTTOMLEFT", (index - 1) * (button:GetWidth() + BUTTON_SPACING), 0)
        button:SetScale(1)
        button:SetAlpha(1)
        button:SetFrameStrata("LOW")
        button:SetFrameLevel(4)

        local background = bar:CreateTexture("DFRL_ActionButtonBg" .. index, "BORDER")
        background:SetTexture(TEX_PATH .. "HDActionBarBtn.blp")
        background:SetPoint("CENTER", button, "CENTER", 0, 0)
        background:SetWidth(button:GetWidth() + 5)
        background:SetHeight(button:GetHeight() + 5)

        local border = button:CreateTexture(button:GetName() .. "DFRL_BorderOverlay", "OVERLAY")
        border:SetTexture(TEX_PATH .. "border.blp")
        border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        button.DFRL_BorderOverlay = border

        button:SetHighlightTexture(TEX_PATH .. "uiactionbariconframehighlight.blp")
        local highlight = button:GetHighlightTexture()
        if highlight then
            highlight:SetAllPoints(button)
            highlight:SetBlendMode("ADD")
            highlight:SetVertexColor(1, 0.82, 0)
        end

        local selection = button:CreateTexture(nil, "OVERLAY")
        selection:SetTexture(TEX_PATH .. "uiactionbariconframehighlight.blp")
        selection:SetAllPoints(button)
        selection:SetBlendMode("ADD")
        selection:SetVertexColor(1, 0.82, 0)
        selection:Hide()
        button.DFRL_swapSelection = selection
        button:SetScript("OnHide", ClearSelection)

        HideHotkey(button)

        local macro = _G[button:GetName() .. "Name"]
        macro:ClearAllPoints()
        macro:SetPoint("TOP", button, "TOP", 0, 2)
        T.SetFont(macro, 13, "OUTLINE")
        macro:SetTextColor(1, 1, 1)
    end

    -- Visual reference: Turtle Dragonflight by TheLinuxITGuy, with Shagu's
    -- cooldown-number styling. This implementation reads only our seven native
    -- action slots; it does not import their code or hook cooldowns globally.
    -- https://github.com/DustinChecketts/Turtle-Dragonflight/tree/b2c62e9095e1c859bff0209db09f4ff5b9884f5a
    local function FormatCooldown(remaining)
        if remaining < COOLDOWN_ZERO then return "0" end
        for _, unit in ipairs(COOLDOWN_UNITS) do
            if remaining >= unit[1] or unit[1] == 1 then
                return math.ceil(remaining / unit[1]) .. DFRL.locale.Text(unit[2])
            end
        end
    end

    local function UpdateCooldownNumber(button, now)
        local overlay = button.DFRL_cooldownNumber
        local slot = ActionButton_GetPagedID(button)
        if not button:IsVisible() or not HasAction(slot) or type(GetActionCooldown) ~= "function" then
            if overlay:IsShown() then overlay:Hide() end
            return
        end

        -- Read again on every refresh so native resets, replacements and clock
        -- adjustments take effect without keeping a separate cooldown clock.
        local start, duration, enabled = GetActionCooldown(slot)
        if
            type(start) ~= "number"
            or not (start > 0)
            or type(duration) ~= "number"
            or not (duration > 0)
            or enabled ~= 1
        then
            if overlay:IsShown() then overlay:Hide() end
            return
        end
        local remaining = duration - (now - start)
        if not (remaining > 0 and remaining <= duration) then
            if overlay:IsShown() then overlay:Hide() end
            return
        end

        T.SetTextIfChanged(overlay.text, FormatCooldown(remaining))
        local red, green, blue = 1, 1, 1
        if remaining < 1 then
            green, blue = 85 / 255, 85 / 255
        elseif math.ceil(remaining) < 5 then
            blue = 85 / 255
        end
        local currentRed, currentGreen, currentBlue, currentAlpha = overlay.text:GetTextColor()
        if
            not T.NearlyEqual(currentRed, red)
            or not T.NearlyEqual(currentGreen, green)
            or not T.NearlyEqual(currentBlue, blue)
            or (currentAlpha and not T.NearlyEqual(currentAlpha, 1))
        then
            overlay.text:SetTextColor(red, green, blue)
        end
        if not overlay:IsShown() then overlay:Show() end
        return remaining
    end

    local function CreateCooldownNumbers(bar)
        for _, button in ipairs(DFRL.actionButtons) do
            local cooldown = _G[button:GetName() .. "Cooldown"]
            local overlay = CreateFrame("Frame", nil, button)
            overlay:SetAllPoints(button)
            overlay:SetFrameLevel(math.max(button:GetFrameLevel(), cooldown and cooldown:GetFrameLevel() or 0) + 1)
            overlay:EnableMouse(false)
            overlay.text = overlay:CreateFontString(nil, "OVERLAY")
            overlay.text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
            T.SetFont(overlay.text, math.min(14, button:GetHeight() * 0.64), "OUTLINE")
            overlay.text:SetShadowColor(0, 0, 0, 1)
            overlay.text:SetShadowOffset(1, -1)
            overlay:Hide()
            button.DFRL_cooldownNumber = overlay
        end

        local active, finishing = true, false
        local elapsed = 0
        local function ClearNumbers()
            finishing = false
            for _, button in ipairs(DFRL.actionButtons) do
                local overlay = button.DFRL_cooldownNumber
                if overlay:IsShown() then overlay:Hide() end
            end
        end
        local function RefreshNumbers()
            if not active or not DFRL.display.Get("cooldownNumbers") then
                ClearNumbers()
                return
            end
            local now = GetTime()
            finishing = false
            for _, button in ipairs(DFRL.actionButtons) do
                local remaining = UpdateCooldownNumber(button, now)
                if remaining and remaining <= COOLDOWN_FINAL_WINDOW then finishing = true end
            end
        end

        -- One updater serves the whole bar. Text inherits each button's scale,
        -- alpha and visibility, while its stock swipe and click scripts stay intact.
        local controller = CreateFrame("Frame", nil, bar)
        controller:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        controller:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        controller:RegisterEvent("PLAYER_ENTERING_WORLD")
        controller:RegisterEvent("PLAYER_LEAVING_WORLD")
        controller:RegisterEvent("PLAYER_LOGOUT")
        controller:SetScript("OnEvent", function()
            if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
                active = false
                ClearNumbers()
                return
            end
            if event == "PLAYER_ENTERING_WORLD" then active = true end
            elapsed = 0
            RefreshNumbers()
        end)
        controller:SetScript("OnUpdate", function()
            if not active or not DFRL.display.Get("cooldownNumbers") then return end
            elapsed = elapsed + arg1
            -- Sample each rendered frame near expiration so a 100-ms periodic
            -- refresh does not skip the positive final-100-ms zero window.
            if not finishing and elapsed < COOLDOWN_INTERVAL then return end
            elapsed = 0
            RefreshNumbers()
        end)
        controller:SetScript("OnHide", ClearNumbers)
        controller:SetScript("OnShow", RefreshNumbers)
        DFRL.display.Listen(RefreshNumbers)
        RefreshNumbers()
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
        mainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, defaults.bottom)
        mainBar:SetWidth(defaults.width)
        mainBar:SetHeight(defaults.height)
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
        CreateCooldownNumbers(mainBar)
        local selectionEvents = CreateFrame("Frame", nil, mainBar)
        for _, name in ipairs({
            "ACTIONBAR_SLOT_CHANGED",
            "PLAYER_LEAVING_WORLD",
            "PLAYER_ENTERING_WORLD",
            "PLAYER_LOGOUT",
        }) do
            selectionEvents:RegisterEvent(name)
        end
        selectionEvents:SetScript("OnEvent", ClearSelection)
        DFRL.display.Listen(ClearSelection)
        local moveRegion = CreateFrame("Frame", nil, mainBar)
        moveRegion:SetPoint("TOPLEFT", mainBar, "TOPLEFT", -defaults.sideInset, defaults.topInset)
        moveRegion:SetPoint("BOTTOMRIGHT", mainBar, "BOTTOMRIGHT", defaults.sideInset, 0)
        DFRL.actionBarMoveRegion = moveRegion
        DFRL.RefreshActionBarBounds()
        DFRL.layout.Register("actionBar", mainBar, function()
            mainBar:ClearAllPoints()
            mainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, defaults.bottom)
        end, {
            region = moveRegion,
            onEdit = function(active)
                ClearSelection()
                if DFRL.SetJewelryEditing then DFRL.SetJewelryEditing(active) end
            end,
        })
        if DFRL.AttachJewelry then DFRL.AttachJewelry(mainBar) end
        if DFRL.AttachXPBar then DFRL.AttachXPBar(mainBar) end
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        events:SetScript("OnEvent", nil)
    end
    events:SetScript("OnEvent", InitializeBar)
    -- The port can load loose addons after the initial world event.
    if UnitExists("player") then InitializeBar() end
end)
