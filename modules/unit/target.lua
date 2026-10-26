DFRL:NewMod("Target", 1, function()
    if not TargetFrame or not TargetFrameHealthBar then return end

    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local T = DFRL.tools

    local function CreateValueText(bar, size)
        local frame = CreateFrame("Frame", nil, TargetFrame)
        frame:SetAllPoints(bar)
        frame:SetFrameLevel(bar:GetFrameLevel() + 3)
        local text = frame:CreateFontString(nil, "OVERLAY")
        T.SetFont(text, size, "OUTLINE")
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1)
        return text
    end

    TargetFrame:SetScale(1)
    TargetFrameHealthBar:SetScript("OnEnter", nil)
    TargetFrameHealthBar:SetScript("OnLeave", nil)
    -- Party heroes can be selected too. Keep native updates from painting a
    -- live player/party alias red; other Survivors targets retain enemy red.
    local setHealthColor = TargetFrameHealthBar.SetStatusBarColor
    TargetFrameHealthBar.SetStatusBarColor = function(bar)
        if T.IsPlayerOrPartyUnit("target") then
            setHealthColor(bar, 0, 1, 0)
        else
            setHealthColor(bar, 1, 0, 0)
        end
    end
    local UpdateBorderTexture = T.CreateUnitBorder(
        TargetFrame,
        TargetFrameHealthBar,
        TargetFrameTexture,
        TargetFrameBackground,
        tex .. "UI-TargetingFrameDF1.blp",
        "RIGHT"
    )
    local healthText = CreateValueText(TargetFrameHealthBar, 10)
    local healthLabels = T.BindUnitHealthText(TargetFrameHealthBar, healthText, "target", true)
    local function UpdateHealthInsets()
        local underlap = T.LargeHealthFill.underlap
        healthLabels.SetInsets(
            underlap,
            (DFRL.display.Get("hidePortraits") and 0 or T.UnitPortraitOverlap) + underlap,
            0
        )
    end
    DFRL.display.Listen(UpdateHealthInsets)
    UpdateHealthInsets()

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

    -- Change only TOPLEFT anchors rewritten by the native 1.12 aura updater.
    -- Its icon sizes, horizontal chains, aura data and tooltip scripts stay native.
    if type(_G.TargetDebuffButton_Update) == "function" then
        local debuffsOnTop = DFRL.display.Get("targetDebuffsOnTop")
        local function PlaceDebuffRow(button, relative, gap)
            if not button or not relative then return end
            button:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, button:GetHeight() + gap)
        end
        local function PlaceTargetDebuffs()
            if not debuffsOnTop or not TargetFrameDebuff1 then return end
            TargetFrameDebuff1:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 5, TargetFrameDebuff1:GetHeight() + 4)
            local hasTargetOfTarget = TargetofTargetFrame and TargetofTargetFrame:IsShown()
            local wrap = hasTargetOfTarget and 5 or 6
            PlaceDebuffRow(_G["TargetFrameDebuff" .. (wrap + 1)], TargetFrameDebuff1, 2)
            if hasTargetOfTarget then PlaceDebuffRow(_G.TargetFrameDebuff11, _G.TargetFrameDebuff6, 2) end
            -- Enemy buffs normally follow a debuff row; detach them below the
            -- frame using the native friendly-target buff anchor instead.
            if TargetFrameBuff1 then TargetFrameBuff1:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 5, 32) end
        end
        hooksecurefunc("TargetDebuffButton_Update", PlaceTargetDebuffs)
        DFRL.display.Listen(function()
            local value = DFRL.display.Get("targetDebuffsOnTop")
            if value == debuffsOnTop then return end
            debuffsOnTop = value
            -- Native layout restores every point we change when switching off.
            _G.TargetDebuffButton_Update()
        end)
        if debuffsOnTop then _G.TargetDebuffButton_Update() end
    end

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
        T.SetFont(TargetFrame.name, 11, "")
        TargetFrame.name:SetTextColor(1, 0.82, 0)
    end
    if TargetLevelText then
        TargetLevelText:ClearAllPoints()
        TargetLevelText:SetPoint("CENTER", TargetFrame, "CENTER", -102, 25)
        T.SetFont(TargetLevelText, 11, "")
        TargetLevelText:SetTextColor(1, 0.82, 0)
    end
    T.BindUnitLabelVisibility(TargetFrame.name, "showTargetName")
    T.BindUnitLabelVisibility(TargetLevelText, "showTargetLevel")

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
        healthLabels.Update()
        if not UnitExists("target") then return end
        TargetFrameHealthBar:SetStatusBarColor(1, 0, 0)
        UpdateClassification(forceBorder)
    end

    HookScript(TargetFrameHealthBar, "OnValueChanged", function() UpdateTarget() end)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UNIT_MAXHEALTH")
    frame:RegisterEvent("UNIT_FACTION")
    frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    frame:SetScript("OnEvent", function()
        if
            event == "PLAYER_TARGET_CHANGED"
            or event == "PLAYER_ENTERING_WORLD"
            or event == "PARTY_MEMBERS_CHANGED"
            or arg1 == "target"
        then
            UpdateTarget(event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD")
        end
    end)
    UpdateClassification()
    UpdateTarget()
    DFRL.layout.Register("targetFrame", TargetFrame)
end)
