DFRL:NewMod("Bars", 1, function()
    -- The run fills slots 1-6; the always-available ability stays in native slot 12.
    local ACTION_SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
    local BUTTON_COUNT = 7
    local active = false
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
    defaults.jewelryTopInset = defaults.buttonWidth * 40 / 36
    DFRL.actionBarDefaults = defaults
    function DFRL.ActionBarAttached(key) return DFRL.display.Get("customActionBar") ~= false and DFRL.display.Get(key) end
    function DFRL.GetActionBarSilverBottom() return -defaults.topInset + defaults.silverBottomInset end
    function DFRL.SetRunTallyBarExtent() end
    function DFRL.RefreshActionBarBounds() end

    local disabledFrames = {}
    local function DisableFrame(frame)
        if not frame then return end
        if frame.EnableMouse then frame:EnableMouse(false) end
        if frame.SetScript then
            local guard = disabledFrames[frame]
            if not guard then
                guard = function()
                    if DFRL.display.Get("customActionBar") ~= false then frame:Hide() end
                end
                disabledFrames[frame] = guard
            end
            frame:SetScript("OnShow", guard)
        end
        frame:Hide()
    end

    local function HideHotkey(button)
        local hotkey = _G[button:GetName() .. "HotKey"]
        if hotkey then
            hotkey:SetText("")
            hotkey:Hide()
        end
    end

    local stockFrames = {
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
        "CharacterMicroButton",
        "TalentMicroButton",
        "MainMenuMicroButton",
        "SpellbookMicroButton",
        "WorldMapMicroButton",
        "QuestLogMicroButton",
        "SocialsMicroButton",
        "HelpMicroButton",
        "MainMenuBarBackpackButton",
        "CharacterBag0Slot",
        "CharacterBag1Slot",
        "CharacterBag2Slot",
        "CharacterBag3Slot",
        "KeyRingButton",
    }
    local stockPrefixes = {
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarLeftButton",
        "MultiBarRightButton",
        "BonusActionButton",
        "PetActionButton",
        "ShapeshiftButton",
        "PossessButton",
    }
    local stockTextures = {
        "MainMenuBarLeftEndCap",
        "MainMenuBarRightEndCap",
        "SlidingActionBarTexture0",
        "SlidingActionBarTexture1",
        "BonusActionBarTexture0",
        "BonusActionBarTexture1",
        "ShapeshiftBarLeft",
        "ShapeshiftBarMiddle",
        "ShapeshiftBarRight",
    }
    local function HideStockBars()
        HideFrameTextures(MainMenuBar)
        HideFrameTextures(MainMenuBarArtFrame)
        MainMenuBar:EnableMouse(false)
        MainMenuBarArtFrame:EnableMouse(false)

        for _, name in ipairs(stockFrames) do
            DisableFrame(_G[name])
        end

        for i = BUTTON_COUNT + 1, 12 do
            DisableFrame(_G["ActionButton" .. i])
        end
        for _, prefix in ipairs(stockPrefixes) do
            for i = 1, 12 do
                DisableFrame(_G[prefix .. i])
            end
        end
        for _, name in ipairs(stockTextures) do
            local texture = _G[name]
            if texture then texture:SetTexture(nil) end
        end
        if MicroButtonPortrait then MicroButtonPortrait:Hide() end

        -- The six run abilities and the permanent ability stay on the first page.
        -- Page bindings must not silently replace the skills behind those buttons.
        local changePage = _G.ChangeActionBarPage
        local pageUp, pageDown = _G.ActionBar_PageUp, _G.ActionBar_PageDown
        local function KeepMainPage()
            if not active then return changePage and changePage() end
            _G.CURRENT_ACTIONBAR_PAGE = 1
            if changePage then changePage() end
        end
        _G.ChangeActionBarPage = KeepMainPage
        _G.ActionBar_PageUp = function()
            if not active then return pageUp and pageUp() end
            return KeepMainPage()
        end
        _G.ActionBar_PageDown = function()
            if not active then return pageDown and pageDown() end
            return KeepMainPage()
        end
        _G.SHOW_MULTI_ACTIONBAR_1 = nil
        _G.SHOW_MULTI_ACTIONBAR_2 = nil
        _G.SHOW_MULTI_ACTIONBAR_3 = nil
        _G.SHOW_MULTI_ACTIONBAR_4 = nil
        KeepMainPage()

        local buttonDown, buttonUp = _G.ActionButtonDown, _G.ActionButtonUp
        _G.ActionButtonDown = function(id)
            if not active or (id >= 1 and id <= BUTTON_COUNT) then return buttonDown(id) end
        end
        _G.ActionButtonUp = function(id, onSelf)
            if not active or (id >= 1 and id <= BUTTON_COUNT) then return buttonUp(id, onSelf) end
        end
        -- Existing client bindings must not execute slots on discarded bars.
        for _, name in ipairs({
            "MultiActionBar_Update",
            "ShowBonusActionBar",
            "HideBonusActionBar",
            "MultiActionButtonDown",
            "MultiActionButtonUp",
            "BonusActionButtonDown",
            "BonusActionButtonUp",
            "PetActionButtonDown",
            "PetActionButtonUp",
            "ShapeshiftBar_ChangeForm",
        }) do
            local original = _G[name]
            _G[name] = function(a1, a2, a3)
                if not active and type(original) == "function" then return original(a1, a2, a3) end
            end
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
        upper:SetPoint("TOPLEFT", bar, "TOPLEFT", -defaults.sideInset, defaults.jewelryTopInset)
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
    local function FormatCooldown(remaining, overlay)
        if remaining < COOLDOWN_ZERO then return "0" end
        for _, unit in ipairs(COOLDOWN_UNITS) do
            if remaining >= unit[1] or unit[1] == 1 then
                local value, language = math.ceil(remaining / unit[1]), DFRL.locale.code
                if
                    overlay.cooldownValue ~= value
                    or overlay.cooldownUnit ~= unit[2]
                    or overlay.cooldownLanguage ~= language
                then
                    local text = value .. DFRL.locale.Text(unit[2])
                    overlay.cooldownValue, overlay.cooldownUnit, overlay.cooldownLanguage = value, unit[2], language
                    overlay.cooldownText = text
                end
                return overlay.cooldownText
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

        T.SetTextIfChanged(overlay.text, FormatCooldown(remaining, overlay))
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
        local performanceMode
        local cooldowns = {}
        local function HideReadyCooldown(cooldown)
            if cooldown.stopping ~= 1 then
                local start, duration = cooldown.start, cooldown.duration
                if
                    cooldown.stopping ~= 0
                    or type(start) ~= "number"
                    or not (start > 0)
                    or type(duration) ~= "number"
                    or not (duration > 0)
                    or not ((GetTime() - start) / duration >= 1)
                then
                    return false
                end
            end
            if cooldown:IsShown() then cooldown:Hide() end
            return true
        end
        for _, button in ipairs(DFRL.actionButtons) do
            local cooldown = _G[button:GetName() .. "Cooldown"]
            local updateModel = cooldown and cooldown:GetScript("OnUpdateModel")
            if type(updateModel) == "function" then
                table.insert(cooldowns, cooldown)
                -- The stock Model scrubs sequence 0 for the swipe, then starts
                -- sequence 1 for the ready flash. Stop before that handoff.
                cooldown:SetScript("OnUpdateModel", function()
                    if
                        DFRL.display.Get("customActionBar") ~= false
                        and performanceMode
                        and HideReadyCooldown(cooldown)
                    then
                        return
                    end
                    updateModel()
                end)
            end
            local overlay = CreateFrame("Frame", nil, button)
            overlay:SetAllPoints(button)
            overlay:SetFrameLevel(math.max(button:GetFrameLevel(), cooldown and cooldown:GetFrameLevel() or 0) + 1)
            overlay:EnableMouse(false)
            overlay.text = overlay:CreateFontString(nil, "OVERLAY")
            overlay.text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
            T.SetFont(overlay.text, math.min(14, button:GetHeight() * 0.64), "OUTLINE")
            T.SetChatShadow(overlay.text)
            overlay:Hide()
            button.DFRL_cooldownNumber = overlay
        end

        local active, finishing = true, false
        local elapsed = 0
        local controller, running, TickNumbers
        local function ClearNumbers()
            if running then
                controller:SetScript("OnUpdate", nil)
                running = false
            end
            finishing = false
            for _, button in ipairs(DFRL.actionButtons) do
                local overlay = button.DFRL_cooldownNumber
                if overlay:IsShown() then overlay:Hide() end
                overlay.cooldownValue, overlay.cooldownUnit, overlay.cooldownLanguage, overlay.cooldownText =
                    nil, nil, nil, nil
                overlay.finishing = nil
            end
        end
        local function RefreshNumbers(finalOnly)
            local selected = DFRL.display.Get("customActionBar") ~= false and DFRL.display.Get("performanceMode")
            if performanceMode ~= selected then
                performanceMode = selected
                if performanceMode then
                    for _, cooldown in ipairs(cooldowns) do
                        HideReadyCooldown(cooldown)
                    end
                end
            end
            if not active or not bar:IsVisible() or performanceMode or not DFRL.display.Get("cooldownNumbers") then
                ClearNumbers()
                return
            end
            if not running then
                controller:SetScript("OnUpdate", TickNumbers)
                running = true
            end
            local now = GetTime()
            finishing = false
            for _, button in ipairs(DFRL.actionButtons) do
                local overlay = button.DFRL_cooldownNumber
                if not finalOnly or overlay.finishing then
                    local remaining = UpdateCooldownNumber(button, now)
                    overlay.finishing = remaining and remaining <= COOLDOWN_FINAL_WINDOW or false
                end
                if overlay.finishing then finishing = true end
            end
        end

        -- One updater serves the whole bar. Text inherits each button's scale,
        -- alpha and visibility, while its stock swipe and click scripts stay intact.
        controller = CreateFrame("Frame", nil, bar)
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
        TickNumbers = function()
            if not active or not bar:IsVisible() or performanceMode or not DFRL.display.Get("cooldownNumbers") then
                return
            end
            elapsed = elapsed + arg1
            if elapsed >= COOLDOWN_INTERVAL then
                elapsed = 0
                RefreshNumbers()
            elseif finishing then
                -- Only final-window buttons need frame samples. Keep the full
                -- bar's independent 100-ms clock so other slots cannot starve.
                RefreshNumbers(true)
            end
        end
        controller:SetScript("OnHide", ClearNumbers)
        controller:SetScript("OnShow", RefreshNumbers)
        DFRL.display.Listen(RefreshNumbers)
        DFRL.ClearActionBarCooldowns = ClearNumbers
        RefreshNumbers()
    end

    local initialized = false
    local prepared, nativeSkin, customSkin, nativeGlobals = false, nil, nil, nil
    local inWorld = UnitExists("player") and true or false
    local stateOwner
    local globalNames = {
        "ActionButton_GetPagedID",
        "ActionButton_UpdateHotkeys",
        "ChangeActionBarPage",
        "ActionBar_PageUp",
        "ActionBar_PageDown",
        "MultiActionBar_Update",
        "ShowBonusActionBar",
        "HideBonusActionBar",
        "ActionButtonDown",
        "ActionButtonUp",
        "MultiActionButtonDown",
        "MultiActionButtonUp",
        "BonusActionButtonDown",
        "BonusActionButtonUp",
        "PetActionButtonDown",
        "PetActionButtonUp",
        "ShapeshiftBar_ChangeForm",
        "SHOW_MULTI_ACTIONBAR_1",
        "SHOW_MULTI_ACTIONBAR_2",
        "SHOW_MULTI_ACTIONBAR_3",
        "SHOW_MULTI_ACTIONBAR_4",
        "CURRENT_ACTIONBAR_PAGE",
    }
    local function CaptureGlobals()
        local result = {}
        for _, name in ipairs(globalNames) do
            result[name] = { original = _G[name] }
        end
        return result
    end
    local function CaptureNative()
        nativeSkin, nativeGlobals = stateOwner.Capture(), CaptureGlobals()
    end
    local function RememberGlobals()
        for name, record in pairs(nativeGlobals) do
            record.applied = _G[name]
        end
    end
    local function RestoreGlobals()
        for name, record in pairs(nativeGlobals or {}) do
            if _G[name] == record.applied then _G[name] = record.original end
        end
    end
    local function ClearCosmetics()
        ClearSelection()
        if DFRL.ClearActionBarCooldowns then DFRL.ClearActionBarCooldowns() end
        for _, button in ipairs(DFRL.actionButtons or {}) do
            for _, field in ipairs({ "DFRL_BorderOverlay", "DFRL_swapSelection", "rangeIndicator" }) do
                local region = button[field]
                if region then
                    if field == "rangeIndicator" and type(UIFrameFadeRemoveFrame) == "function" then
                        UIFrameFadeRemoveFrame(region)
                        region.showing = false
                    end
                    if region:IsShown() then region:Hide() end
                end
            end
        end
    end
    local function RefreshNativeButtons()
        local previousThis = _G.this
        for index = 1, 12 do
            local button = _G["ActionButton" .. index]
            if button and type(_G.ActionButton_Update) == "function" then
                _G.this = button
                _G.ActionButton_Update()
                if type(_G.ActionButton_UpdateHotkeys) == "function" then _G.ActionButton_UpdateHotkeys() end
            end
        end
        _G.this = previousThis
    end
    local function RestoreNative()
        if not active then return end
        customSkin = stateOwner.Capture()
        active = false
        if DFRL.mainBar:IsShown() then DFRL.mainBar:Hide() end
        ClearCosmetics()
        for _, button in ipairs(DFRL.actionButtons) do
            button.DFRL_actionSlot = nil
            local macro = _G[button:GetName() .. "Name"]
            if macro then T.SetFont(macro, 13, "OUTLINE", true) end
        end
        RestoreGlobals()
        stateOwner.Apply(nativeSkin)
        RefreshNativeButtons()
    end
    local function ApplyBindings()
        local getPagedID = nativeGlobals.ActionButton_GetPagedID.original
        _G.ActionButton_GetPagedID = function(button)
            if active and button.DFRL_actionSlot then return button.DFRL_actionSlot end
            return getPagedID(button)
        end
        local hotkeys = nativeGlobals.ActionButton_UpdateHotkeys.original
        _G.ActionButton_UpdateHotkeys = function()
            if not active then return hotkeys and hotkeys() end
            for _, button in ipairs(DFRL.actionButtons) do
                HideHotkey(button)
            end
        end
        for index, button in ipairs(DFRL.actionButtons) do
            button.DFRL_actionSlot = ACTION_SLOTS[index]
            local macro = _G[button:GetName() .. "Name"]
            if macro then T.SetFont(macro, 13, "OUTLINE") end
            if button.DFRL_BorderOverlay then button.DFRL_BorderOverlay:Show() end
        end
    end
    local function PrepareCustomBar()
        local mainBar = DFRL.mainBar
        local art = CreateFrame("Frame", "DFRL_ActionBar", mainBar)
        art:SetAllPoints(mainBar)
        art:SetFrameStrata("LOW")
        art:SetFrameLevel(2)
        DFRL.actionBarFrame = art
        CreateBackground(art)
        for index, button in ipairs(DFRL.actionButtons) do
            StyleButton(button, index, art)
        end
        CreateCooldownNumbers(mainBar)
        customSkin = stateOwner.Capture()
        prepared = true
    end
    local function ApplyMode()
        if not initialized then return end
        ClearSelection()
        local wanted = inWorld and DFRL.display.Get("customActionBar") ~= false
        if not wanted then
            RestoreNative()
            if DFRL.mainBar:IsShown() then DFRL.mainBar:Hide() end
            return
        end
        if active then return end
        CaptureNative()
        active = true
        HideStockBars()
        if prepared then
            stateOwner.Apply(customSkin)
        else
            PrepareCustomBar()
        end
        ApplyBindings()
        RememberGlobals()
        RefreshNativeButtons()
        if not DFRL.layout.IsHidden("actionBar") then DFRL.mainBar:Show() end
        if DFRL.AttachJewelry then DFRL.AttachJewelry(DFRL.mainBar) end
        if DFRL.AttachXPBar then DFRL.AttachXPBar(DFRL.mainBar) end
        if DFRL.AttachRunTally then DFRL.AttachRunTally() end
    end
    local function InitializeBar()
        if initialized then return end
        initialized = true
        local ignored = {}
        for _, name in ipairs({ "MainMenuExpBar", "ReputationWatchBar", "MainMenuBarPerformanceBarFrame" }) do
            if _G[name] then ignored[_G[name]] = true end
        end
        stateOwner = T.NewActionBarState(ignored)
        stateOwner.Track(MainMenuBar)
        stateOwner.Track(MainMenuBarArtFrame)
        stateOwner.Track(MicroButtonPortrait)
        for _, name in ipairs(stockFrames) do
            stateOwner.Track(_G[name])
        end
        for _, name in ipairs(stockTextures) do
            stateOwner.Track(_G[name])
        end
        for _, prefix in ipairs(stockPrefixes) do
            for index = 1, 12 do
                stateOwner.Track(_G[prefix .. index])
            end
        end
        DFRL.actionButtons = {}
        for index = 1, 12 do
            local button = _G["ActionButton" .. index]
            stateOwner.Track(button)
            if index <= BUTTON_COUNT then DFRL.actionButtons[index] = button end
        end
        local mainBar = CreateFrame("Frame", "DFRL_MainBar", UIParent)
        mainBar:Hide()
        mainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, defaults.bottom)
        mainBar:SetWidth(defaults.width)
        mainBar:SetHeight(defaults.height)
        mainBar:SetClampedToScreen(true)
        mainBar:SetFrameStrata("LOW")
        mainBar:SetFrameLevel(1)
        mainBar:SetScript("OnShow", function()
            if not active then mainBar:Hide() end
        end)
        DFRL.mainBar = mainBar
        local moveRegion = CreateFrame("Frame", nil, mainBar)
        moveRegion:SetPoint("TOPLEFT", mainBar, "TOPLEFT", -defaults.sideInset, defaults.topInset)
        moveRegion:SetPoint("BOTTOMRIGHT", mainBar, "BOTTOMRIGHT", defaults.sideInset, 0)
        DFRL.actionBarMoveRegion = moveRegion
        DFRL.layout.Register("actionBar", mainBar, function()
            mainBar:ClearAllPoints()
            mainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, defaults.bottom)
        end, {
            region = moveRegion,
            onEdit = function(editing)
                ClearSelection()
                if DFRL.SetJewelryEditing then DFRL.SetJewelryEditing(editing) end
            end,
        })
        ApplyMode()
        if DFRL.AttachJewelry then DFRL.AttachJewelry(mainBar) end
        if DFRL.AttachXPBar then DFRL.AttachXPBar(mainBar) end
    end
    local events = CreateFrame("Frame")
    for _, name in ipairs({ "ACTIONBAR_SLOT_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
        events:RegisterEvent(name)
    end
    events:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            InitializeBar()
            ApplyMode()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            if DFRL.ReleaseActionBarXP then DFRL.ReleaseActionBarXP() end
            RestoreNative()
        else
            ClearSelection()
        end
    end)
    DFRL.display.Listen(ApplyMode)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            if DFRL.ReleaseActionBarXP then DFRL.ReleaseActionBarXP() end
            RestoreNative()
            return reloadUI()
        end
    end
    -- The port can load loose addons after the initial world event.
    if inWorld then InitializeBar() end
end)
