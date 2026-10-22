DFRL:NewMod("Player", 1, function()
    if not PlayerFrame or not PlayerFrameHealthBar then return end

    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local healthText
    local primaryBar, primaryText, setPowerShown, setPortraitOverlap
    local updateBorder
    local pulseTextures = {}
    local initialized = false

    local healthR, healthG, healthB = 0, 1, 0
    local setHealthColor = PlayerFrameHealthBar.SetStatusBarColor
    -- Native health updates also recolor this bar; keep the effective display choice.
    PlayerFrameHealthBar.SetStatusBarColor = function(bar)
        local red, green, blue, alpha = bar:GetStatusBarColor()
        if
            not T.NearlyEqual(red, healthR)
            or not T.NearlyEqual(green, healthG)
            or not T.NearlyEqual(blue, healthB)
            or (alpha and not T.NearlyEqual(alpha, 1))
        then
            setHealthColor(bar, healthR, healthG, healthB)
        end
    end

    local function UpdateHealthColor()
        local color
        if DFRL.display.Get("classHealth") then color = T.GetPlayerClassColor() end
        if color then
            healthR, healthG, healthB = unpack(color)
        else
            healthR, healthG, healthB = 0, 1, 0
        end
        -- Tint the shared shaded healthDF2 artwork; retain its crop and damage-loss overlay.
        PlayerFrameHealthBar:SetStatusBarColor(healthR, healthG, healthB)
    end
    DFRL.display.Listen(UpdateHealthColor)

    local appliedRound, appliedHidden
    local function UpdatePortraitShape()
        if not updateBorder then return end
        local round = DFRL.display.Get("roundPlayerPortrait")
        local hidden = DFRL.display.Get("hidePortraits")
        if round == appliedRound and hidden == appliedHidden then return end
        appliedRound, appliedHidden = round, hidden
        updateBorder(tex .. (round and "UI-TargetingFrameDF1.blp" or "UI-TargetingFrameDF.blp"))
        local extension = setPortraitOverlap(round)
        if healthText then healthText:SetPoint("CENTER", PlayerFrameHealthBar, "CENTER", extension / 2, 0) end
        if PlayerFrame.name then
            PlayerFrame.name:SetPoint("BOTTOMLEFT", PlayerFrameHealthBar, "TOPLEFT", 2 + extension, 4)
            PlayerFrame.name:SetWidth(PlayerFrameHealthBar:GetWidth() - extension - 24)
        end
        if primaryBar then
            primaryBar:SetWidth(PlayerFrameHealthBar:GetWidth())
            primaryText:SetPoint("CENTER", primaryBar, "CENTER", extension / 2, 0)
        end
        for _, textures in ipairs(pulseTextures) do
            if hidden then
                textures.original:Hide()
                textures.round:Hide()
            elseif round then
                textures.original:Hide()
                textures.round:Show()
            else
                textures.original:Show()
                textures.round:Hide()
            end
        end
    end
    DFRL.display.Listen(UpdatePortraitShape)

    DFRL.playerResources = DFRL.playerResources or {}
    DFRL.playerResources.SetPrimary = function(value, maximum, powerType)
        if not primaryBar then return end
        if
            type(value) ~= "number"
            or value < 0
            or value - value ~= 0
            or type(maximum) ~= "number"
            or maximum <= 0
            or maximum - maximum ~= 0
            or type(powerType) ~= "number"
        then
            if primaryBar:IsShown() then primaryBar:Hide() end
            T.SetTextIfChanged(primaryText, "")
            setPowerShown(false)
            return
        end
        local color = type(ManaBarColor) == "table" and ManaBarColor[powerType]
        local red, green, blue = 1, 1, 1
        if type(color) == "table" then
            red, green, blue = color.r, color.g, color.b
        end
        local currentRed, currentGreen, currentBlue, currentAlpha = primaryBar:GetStatusBarColor()
        if
            not T.NearlyEqual(red, currentRed)
            or not T.NearlyEqual(green, currentGreen)
            or not T.NearlyEqual(blue, currentBlue)
            or (currentAlpha and not T.NearlyEqual(currentAlpha, 1))
        then
            primaryBar:SetStatusBarColor(red, green, blue)
        end
        local minimum, currentMaximum = primaryBar:GetMinMaxValues()
        if minimum ~= 0 or currentMaximum ~= maximum then primaryBar:SetMinMaxValues(0, maximum) end
        if primaryBar:GetValue() ~= value then primaryBar:SetValue(value) end
        T.SetTextIfChanged(primaryText, value)
        setPowerShown(true)
        if not primaryBar:IsShown() then primaryBar:Show() end
    end

    local function CreateValueText(bar, size, y)
        local frame = CreateFrame("Frame", nil, PlayerFrame)
        frame:SetAllPoints(bar)
        frame:SetFrameLevel(PlayerFrameHealthBar:GetFrameLevel() + 3)
        local text = frame:CreateFontString(nil, "OVERLAY")
        T.SetFont(text, size, "OUTLINE")
        text:SetTextColor(1, 1, 1)
        text:SetPoint("CENTER", bar, "CENTER", 0, y)
        return text
    end

    local function UpdateValues()
        if not initialized then return end
        T.SetTextIfChanged(healthText, UnitHealth("player"))
        if PlayerLevelText then T.SetTextIfChanged(PlayerLevelText, UnitLevel("player")) end
        UpdateHealthColor()
    end

    local function HidePowerBar()
        if PlayerFrameManaBar then
            PermanentlyDisableFrame(PlayerFrameManaBar)
            PlayerFrameManaBar:SetAlpha(0)
        end
        if PlayerFrameManaBarText then
            PlayerFrameManaBarText:SetText("")
            PlayerFrameManaBarText:SetAlpha(0)
            PlayerFrameManaBarText:Hide()
            PlayerFrameManaBarText.Show = PlayerFrameManaBarText.Hide
        end
    end

    local function FixPlayerClick()
        -- The multiplayer SELF dropdown is unused in Survivors and can
        -- overflow its native button pool. Right-click opens our fixed menu.
        local original = _G.PlayerFrame_OnClick
        _G.PlayerFrame_OnClick = function(button)
            if button == "RightButton" and not SpellIsTargeting() then
                ToggleGameMenu(true)
                return
            end
            if original then original(button) end
        end
        _G.PlayerFrameDropDown_Initialize = function() end
        if PlayerFrameDropDown then
            PlayerFrameDropDown.initialize = _G.PlayerFrameDropDown_Initialize
            PlayerFrameDropDown:Hide()
        end
    end

    local function CreatePulse(r, g, b, active)
        local overlay = CreateFrame("Frame", nil, PlayerFrame)
        overlay:SetAllPoints(PlayerFrame)
        overlay:SetFrameStrata("MEDIUM")
        local texture = overlay:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(tex .. "UI-Player-Status.blp")
        texture:SetPoint("CENTER", PlayerFrame, "CENTER", 45, -21)
        texture:SetVertexColor(r, g, b)
        texture:SetBlendMode("ADD")
        texture:SetAlpha(0)
        -- Use the same circular rim as the target for the optional status pulse,
        -- so the original pointed silhouette cannot return during combat/rest.
        local round = T.CreateRoundPlayerRim(PlayerFrame, PlayerFrame, r, g, b, "ADD")
        round:SetFrameLevel(PlayerFrameHealthBar:GetFrameLevel() + 3)
        round:SetAlpha(0)
        round:Hide()
        table.insert(pulseTextures, { original = texture, round = round })
        local pulseTime, pulseAlpha = 0, 0
        overlay:SetScript("OnUpdate", function()
            if DFRL.display.Get("hidePortraits") then return end
            local elapsed = arg1 or 0
            if active() then
                pulseTime = math.mod(pulseTime + elapsed, 1)
                texture:SetAlpha(0.5 + 0.5 * math.sin(pulseTime * 2 * math.pi))
            else
                -- Keep native state detection at frame cadence without repainting
                -- either inactive artwork after its original fade reaches zero.
                if pulseAlpha == 0 then return end
                texture:SetAlpha(math.max(0, texture:GetAlpha() - elapsed * 2))
            end
            pulseAlpha = texture:GetAlpha()
            round:SetAlpha(pulseAlpha)
        end)
    end

    local function CreateRestingAnimation()
        local animation = CreateFrame("Frame", nil, PlayerFrame)
        animation:SetPoint("CENTER", PlayerFrame, "CENTER", -20, 30)
        animation:SetWidth(24)
        animation:SetHeight(24)
        local texture = animation:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(tex .. "UIUnitFrameRestingFlipbook")
        texture:SetAllPoints(animation)
        local tick, index = 0, 0
        texture:SetTexCoord(0, 60 / 512, 0, 60 / 512)
        animation:SetScript("OnUpdate", function()
            tick = tick + (arg1 or 0)
            if tick >= 0.05 then
                local steps = math.floor(tick / 0.05)
                tick = tick - steps * 0.05
                index = math.mod(index + steps, 36)
                local x = math.mod(index, 6) * 60 / 512
                local y = math.floor(index / 6) * 60 / 512
                texture:SetTexCoord(x, x + 60 / 512, y, y + 60 / 512)
            end
        end)
        local function UpdateResting()
            if IsResting() and not DFRL.display.Get("hidePortraits") then
                animation:Show()
            else
                animation:Hide()
            end
        end
        local events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_UPDATE_RESTING")
        events:SetScript("OnEvent", UpdateResting)
        DFRL.display.Listen(UpdateResting)
        UpdateResting()
    end

    local function Initialize()
        if initialized then return end
        initialized = true
        PlayerFrame:SetScale(1)
        PlayerFrame:Show()
        -- Unit clicks need no locked button highlight or reminder flash.
        PlayerFrame:UnlockHighlight()
        PlayerFrame.LockHighlight = PlayerFrame.UnlockHighlight
        local highlight = PlayerFrame:GetHighlightTexture()
        if highlight then
            highlight:SetAlpha(0)
            highlight:Hide()
        end
        updateBorder, setPowerShown, setPortraitOverlap = T.CreateUnitBorder(
            PlayerFrame,
            PlayerFrameHealthBar,
            PlayerFrameTexture,
            PlayerFrameBackground,
            tex .. "UI-TargetingFrameDF.blp",
            "LEFT"
        )
        HidePowerBar()
        primaryBar = CreateFrame("StatusBar", nil, PlayerFrame)
        primaryBar:SetWidth(PlayerFrameHealthBar:GetWidth())
        primaryBar:SetHeight(9)
        primaryBar:SetPoint("TOPLEFT", PlayerFrameHealthBar, "TOPLEFT", 0, -20)
        primaryBar:SetFrameLevel(PlayerFrameHealthBar:GetFrameLevel())
        primaryBar:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Status.tga")
        primaryBar:SetMinMaxValues(0, 1)
        primaryBar:SetValue(0)
        local primaryBackground = primaryBar:CreateTexture(nil, "BACKGROUND")
        primaryBackground:SetAllPoints(primaryBar)
        primaryBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        primaryBackground:SetVertexColor(0, 0, 0, 0.6)
        primaryText = primaryBar:CreateFontString(nil, "OVERLAY")
        T.SetFont(primaryText, 8, "OUTLINE")
        primaryText:SetTextColor(1, 1, 1)
        primaryText:SetPoint("CENTER", primaryBar, "CENTER", 0, 0)
        primaryBar:Hide()
        if PlayerFrameHealthBarText then PlayerFrameHealthBarText:SetAlpha(0) end
        healthText = CreateValueText(PlayerFrameHealthBar, 10, 0)
        if PlayerFrame.portrait then
            PlayerFrame.portrait:ClearAllPoints()
            PlayerFrame.portrait:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 42, -12)
            PlayerFrame.portrait:SetHeight(62)
            PlayerFrame.portrait:SetWidth(62)
        end
        -- Keep combat damage feedback from covering the portrait.
        PlayerFrame:UnregisterEvent("UNIT_COMBAT")
        if PlayerHitIndicator then PlayerHitIndicator:Hide() end
        if PlayerFrame.name then
            PlayerFrame.name:ClearAllPoints()
            PlayerFrame.name:SetPoint("BOTTOMLEFT", PlayerFrameHealthBar, "TOPLEFT", 2, 4)
            PlayerFrame.name:SetJustifyH("LEFT")
            T.SetFont(PlayerFrame.name, 11, "NONE")
            PlayerFrame.name:SetTextColor(1, 0.82, 0)
        end
        if PlayerLevelText then
            PlayerLevelText:ClearAllPoints()
            PlayerLevelText:SetPoint("RIGHT", PlayerFrame, "RIGHT", -14, 25)
            T.SetFont(PlayerLevelText, 11, "NONE")
            PlayerLevelText:SetTextColor(1, 0.82, 0)
        end
        T.BindUnitLabelVisibility(PlayerFrame.name, "showPlayerName")
        T.BindUnitLabelVisibility(PlayerLevelText, "showPlayerLevel")
        -- Preserve the original addon status effects without stock overlays.
        _G.PlayerFrame_UpdateStatus = function() end
        for _, name in ipairs({
            "PlayerStatusTexture",
            "PlayerAttackGlow",
            "PlayerAttackIcon",
            "PlayerRestIcon",
            "PlayerRestGlow",
            "PlayerAttackBackground",
        }) do
            local texture = _G[name]
            if texture then
                texture:SetTexture(nil)
                texture:Hide()
            end
        end
        CreatePulse(1, 0, 0, function() return UnitAffectingCombat("player") end)
        CreatePulse(0, 1, 1, IsResting)
        UpdatePortraitShape()
        CreateRestingAnimation()
        FixPlayerClick()
        UpdateValues()
        DFRL.layout.Register("playerFrame", PlayerFrame)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UNIT_LEVEL")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            Initialize()
            frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        elseif event == "PLAYER_LEVEL_UP" or arg1 == "player" then
            UpdateValues()
        end
    end)
    if UnitExists("player") then
        Initialize()
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
