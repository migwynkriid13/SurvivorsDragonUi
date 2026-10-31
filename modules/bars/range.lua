DFRL:NewMod("RangeIndicator", 1, function()
    local TEX_PATH = DFRL:GetInfoOrCons("tex") .. "actionbars\\"
    local INDICATOR_ALPHA = 0.5
    local UPDATE_INTERVAL = 0.1
    local performanceMode = DFRL.display.Get("performanceMode")
    local customActionBar = DFRL.display.Get("customActionBar") ~= false
    local SyncUpdates

    local function ClearIndicator(button)
        local indicator = button.rangeIndicator
        if not indicator or (not indicator.showing and not indicator:IsShown()) then return end
        if type(UIFrameFadeRemoveFrame) == "function" then UIFrameFadeRemoveFrame(indicator) end
        indicator.showing = false
        indicator:Hide()
    end
    local function UpdateButton(button, targetRead, canAttack)
        if not button:IsVisible() then
            ClearIndicator(button)
            return targetRead, canAttack
        end
        local indicator = button.rangeIndicator
        if not indicator then
            indicator = button:CreateTexture(nil, "OVERLAY")
            indicator:SetTexture(TEX_PATH .. "indicator_.blp")
            indicator:SetVertexColor(1, 0, 0)
            indicator:SetAllPoints(button)
            indicator:Hide()
            button.rangeIndicator = indicator
            HookScript(button, "OnHide", function() ClearIndicator(button) end)
        end

        if not targetRead then
            canAttack = UnitExists("target") and UnitCanAttack("player", "target")
            targetRead = true
        end
        local outOfRange = canAttack and IsActionInRange(ActionButton_GetPagedID(button)) == 0
        if performanceMode then
            if outOfRange then
                if indicator:GetAlpha() ~= INDICATOR_ALPHA then indicator:SetAlpha(INDICATOR_ALPHA) end
                if not indicator:IsShown() then indicator:Show() end
            elseif indicator:IsShown() then
                indicator:Hide()
            end
            indicator.showing = outOfRange and true or false
            return targetRead, canAttack
        end
        if outOfRange and not indicator.showing then
            UIFrameFadeIn(indicator, 0.2, 0, INDICATOR_ALPHA)
            indicator.showing = true
        elseif not outOfRange and indicator.showing then
            UIFrameFadeOut(indicator, 0.2, INDICATOR_ALPHA, 0)
            indicator.showing = false
        end
        return targetRead, canAttack
    end

    local function UpdateIndicators()
        if not DFRL.actionButtons then return end
        if not customActionBar then
            for _, button in ipairs(DFRL.actionButtons) do
                ClearIndicator(button)
            end
            return
        end
        local targetRead, canAttack = false, nil
        for _, button in ipairs(DFRL.actionButtons) do
            targetRead, canAttack = UpdateButton(button, targetRead, canAttack)
        end
    end
    DFRL.display.Listen(function()
        local enabled = DFRL.display.Get("performanceMode")
        local custom = DFRL.display.Get("customActionBar") ~= false
        if performanceMode == enabled and customActionBar == custom then return end
        performanceMode = enabled
        customActionBar = custom
        if DFRL.actionButtons then
            for _, button in ipairs(DFRL.actionButtons) do
                ClearIndicator(button)
            end
        end
        UpdateIndicators()
        if SyncUpdates then SyncUpdates() end
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    events:RegisterEvent("SPELLS_CHANGED")
    events:SetScript("OnEvent", UpdateIndicators)
    local elapsed = 0
    local function Tick()
        elapsed = elapsed + arg1
        if elapsed >= UPDATE_INTERVAL then
            elapsed = 0
            UpdateIndicators()
        end
    end
    local hooked
    SyncUpdates = function()
        local visible = customActionBar and DFRL.mainBar and DFRL.mainBar:IsVisible()
        events:SetScript("OnUpdate", visible and Tick or nil)
        if visible then
            elapsed = UPDATE_INTERVAL
        else
            UpdateIndicators()
        end
    end
    DFRL.layout.ListenVisibility("actionBar", function()
        if DFRL.mainBar and not hooked then
            hooked = true
            HookScript(DFRL.mainBar, "OnShow", SyncUpdates)
            HookScript(DFRL.mainBar, "OnHide", SyncUpdates)
        end
        SyncUpdates()
    end)
end)
