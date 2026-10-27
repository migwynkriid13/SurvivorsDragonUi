DFRL:NewMod("RangeIndicator", 1, function()
    local TEX_PATH = DFRL:GetInfoOrCons("tex") .. "actionbars\\"
    local INDICATOR_ALPHA = 0.5
    local UPDATE_INTERVAL = 0.1

    local function ClearIndicator(button)
        local indicator = button.rangeIndicator
        if not indicator or (not indicator.showing and not indicator:IsShown()) then return end
        if type(UIFrameFadeRemoveFrame) == "function" then UIFrameFadeRemoveFrame(indicator) end
        indicator.showing = false
        indicator:Hide()
    end
    local function UpdateButton(button)
        if not button:IsVisible() then
            ClearIndicator(button)
            return
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

        local outOfRange = button:IsVisible()
            and UnitExists("target")
            and UnitCanAttack("player", "target")
            and IsActionInRange(ActionButton_GetPagedID(button)) == 0
        if outOfRange and not indicator.showing then
            UIFrameFadeIn(indicator, 0.2, 0, INDICATOR_ALPHA)
            indicator.showing = true
        elseif not outOfRange and indicator.showing then
            UIFrameFadeOut(indicator, 0.2, INDICATOR_ALPHA, 0)
            indicator.showing = false
        end
    end

    local function UpdateIndicators()
        if not DFRL.actionButtons then return end
        for _, button in ipairs(DFRL.actionButtons) do
            UpdateButton(button)
        end
    end

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
    local function SyncUpdates()
        local visible = DFRL.mainBar and DFRL.mainBar:IsVisible()
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
