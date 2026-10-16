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

    local function UpdateClassification()
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
        UpdateBorderTexture(tex .. texture)
    end
    _G.TargetFrame_CheckClassification = UpdateClassification

    local function UpdateTarget()
        if not UnitExists("target") then
            healthText:SetText("")
            return
        end
        if UnitIsDead("target") or UnitIsGhost("target") then
            healthText:SetText("")
        else
            healthText:SetText(UnitHealth("target"))
        end
        UpdateClassification()
    end

    HookScript(TargetFrameHealthBar, "OnValueChanged", UpdateTarget)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UNIT_FACTION")
    frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" or arg1 == "target" then
            UpdateTarget()
        end
    end)
    UpdateClassification()
    UpdateTarget()
    DFRL.layout.Register("targetFrame", TargetFrame)
end)
