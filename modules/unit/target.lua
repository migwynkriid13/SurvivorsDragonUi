DFRL:NewMod("Target", 1, function()
    if not TargetFrame or not TargetFrameHealthBar then return end

    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local font = "DEFAULT"
    local T = DFRL.tools

    local function CreateValueText(bar, size)
        local frame = CreateFrame("Frame", nil, TargetFrame)
        frame:SetAllPoints(bar)
        frame:SetFrameLevel(bar:GetFrameLevel() + 3)
        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetFont(font, size, "OUTLINE")
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1)
        return text
    end

    TargetFrame:SetScale(1)
    TargetFrameHealthBar:SetScript("OnEnter", nil)
    TargetFrameHealthBar:SetScript("OnLeave", nil)
    -- Survivors uses this frame for enemies; native health updates must keep it red.
    local setHealthColor = TargetFrameHealthBar.SetStatusBarColor
    TargetFrameHealthBar.SetStatusBarColor = function(bar) setHealthColor(bar, 1, 0, 0) end
    TargetFrameHealthBar:SetStatusBarColor(1, 0, 0)
    local UpdateBorderTexture = T.CreateUnitBorder(
        TargetFrame,
        TargetFrameHealthBar,
        TargetFrameTexture,
        TargetFrameBackground,
        tex .. "UI-TargetingFrameDF1.blp",
        "RIGHT"
    )
    local healthText = CreateValueText(TargetFrameHealthBar, 10)
    local displayedHealth
    local function SetHealthText(value)
        if value == displayedHealth then return end
        displayedHealth = value
        healthText:SetText(value)
    end

    local function HidePowerBar()
        if TargetFrameManaBar then
            PermanentlyDisableFrame(TargetFrameManaBar)
            TargetFrameManaBar:SetAlpha(0)
        end
        if TargetFrameManaBarText then
            TargetFrameManaBarText:SetText("")
            TargetFrameManaBarText:SetAlpha(0)
            TargetFrameManaBarText:Hide()
            TargetFrameManaBarText.Show = TargetFrameManaBarText.Hide
        end
    end
    HidePowerBar()

    if TargetFrameNameBackground then TargetFrameNameBackground:SetTexture(nil) end
    if TargetFrameHealthBarText then TargetFrameHealthBarText:SetAlpha(0) end
    if TargetHPText then TargetHPText:SetAlpha(0) end
    if TargetHPPercText then TargetHPPercText:SetAlpha(0) end
    if TargetFrame.portrait then
        TargetFrame.portrait:SetHeight(61)
        TargetFrame.portrait:SetWidth(61)
    end
    if TargetFrame.name then
        TargetFrame.name:ClearAllPoints()
        TargetFrame.name:SetPoint("CENTER", TargetFrame, "CENTER", -40, 25)
        TargetFrame.name:SetJustifyH("RIGHT")
        TargetFrame.name:SetFont(font, 11, "")
        TargetFrame.name:SetTextColor(1, 0.82, 0)
    end
    if TargetLevelText then
        TargetLevelText:ClearAllPoints()
        TargetLevelText:SetPoint("CENTER", TargetFrame, "CENTER", -102, 25)
        TargetLevelText:SetFont(font, 11, "")
        TargetLevelText:SetTextColor(1, 0.82, 0)
    end

    local borderTexture
    local function UpdateClassification(force)
        local classification = UnitClassification("target")
        local texture = "UI-TargetingFrameDF1.blp"
        if classification == "worldboss" then
            texture = "UI-TargetingFrame-Boss.blp"
        elseif classification == "rareelite" then
            texture = "UI-TargetingFrame-RareElite.blp"
        elseif classification == "elite" then
            texture = "UI-TargetingFrame-Elite.blp"
        elseif classification == "rare" then
            texture = "UI-TargetingFrame-Rare.blp"
        end
        local path = tex .. texture
        -- Health events can arrive through both the native bar and UNIT_HEALTH.
        -- Our border only changes with classification; native rebuilds still force it.
        if force == true or path ~= borderTexture then
            borderTexture = path
            UpdateBorderTexture(path)
        end
    end
    _G.TargetFrame_CheckClassification = function() UpdateClassification(true) end

    local function UpdateTarget(forceBorder)
        if not UnitExists("target") then
            SetHealthText("")
            return
        end
        if UnitIsDead("target") or UnitIsGhost("target") then
            SetHealthText("")
        else
            SetHealthText(UnitHealth("target"))
        end
        UpdateClassification(forceBorder)
    end

    HookScript(TargetFrameHealthBar, "OnValueChanged", function() UpdateTarget() end)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UNIT_FACTION")
    frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" or arg1 == "target" then
            UpdateTarget(event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD")
        end
    end)
    UpdateClassification()
    UpdateTarget()
    DFRL.layout.Register("targetFrame", TargetFrame)
end)
