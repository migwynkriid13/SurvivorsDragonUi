DFRL:NewMod("RangeIndicator", 1, function()
    local TEX_PATH = DFRL:GetInfoOrCons("tex") .. "actionbars\\"
    local INDICATOR_ALPHA = 0.5
    local FADE_DURATION = 0.2
    local UPDATE_INTERVAL = 0.1
    local fades = {}
    local performanceMode = DFRL.display.Get("performanceMode")
    local customActionBar = DFRL.display.Get("customActionBar") ~= false
    local SyncUpdates

    local function ClearIndicator(button)
        local indicator = button.rangeIndicator
        if not indicator then return end
        fades[indicator] = nil
        indicator.fadeFrom = nil
        indicator.showing = false
        if indicator:IsShown() then indicator:Hide() end
    end
    local function PaintFade(indicator, progress)
        local target = indicator.showing and INDICATOR_ALPHA or 0
        local alpha = indicator.fadeFrom + (target - indicator.fadeFrom) * progress
        if indicator:GetAlpha() ~= alpha then indicator:SetAlpha(alpha) end
        if alpha > 0 or indicator.showing then
            if not indicator:IsShown() then indicator:Show() end
        elseif indicator:IsShown() then
            indicator:Hide()
        end
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
        local outOfRange = canAttack and IsActionInRange(ActionButton_GetPagedID(button)) == 0 or false
        if performanceMode then
            if outOfRange then
                if indicator:GetAlpha() ~= INDICATOR_ALPHA then indicator:SetAlpha(INDICATOR_ALPHA) end
                if not indicator:IsShown() then indicator:Show() end
            elseif indicator:IsShown() then
                indicator:Hide()
            end
            indicator.showing = outOfRange
            return targetRead, canAttack
        end
        if outOfRange ~= (indicator.showing == true) then
            local now, paused = T.AnimationTime()
            if paused then
                indicator.fadeFrom = indicator:IsShown() and indicator:GetAlpha() or 0
            else
                indicator.fadeFrom = outOfRange and 0 or INDICATOR_ALPHA
            end
            indicator.showing = outOfRange
            fades[indicator] = now
            if not paused then PaintFade(indicator, 0) end
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
        if not next(fades) then return end
        local now, paused = T.AnimationTime()
        if paused then return end
        for indicator, started in pairs(fades) do
            local progress = math.min(1, (now - started) / FADE_DURATION)
            PaintFade(indicator, progress)
            if progress == 1 then
                fades[indicator], indicator.fadeFrom = nil, nil
            end
        end
    end
    local hooked
    SyncUpdates = function()
        local visible = customActionBar and DFRL.mainBar and DFRL.mainBar:IsVisible()
        local update = visible and Tick or nil
        if events:GetScript("OnUpdate") ~= update then events:SetScript("OnUpdate", update) end
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
