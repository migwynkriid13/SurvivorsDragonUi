DFRL:NewMod("Player", 1, function()
    if not PlayerFrame or not PlayerFrameHealthBar then return end

    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local font = "DEFAULT"
    local healthText
    local initialized = false

    local function CreateValueText(bar, size, y)
        local frame = CreateFrame("Frame", nil, PlayerFrame)
        frame:SetAllPoints(bar)
        frame:SetFrameLevel(PlayerFrameHealthBar:GetFrameLevel() + 3)
        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetFont(font, size, "OUTLINE")
        text:SetTextColor(1, 1, 1)
        text:SetPoint("CENTER", bar, "CENTER", 0, y)
        return text
    end

    local function UpdateValues()
        if not initialized then return end
        healthText:SetText(UnitHealth("player"))
        if PlayerLevelText then PlayerLevelText:SetText(UnitLevel("player")) end
        PlayerFrameHealthBar:SetStatusBarColor(0, 1, 0)
    end

    local function HidePowerBar()
        if PlayerFrameManaBar then
            KillFrame(PlayerFrameManaBar)
            PlayerFrameManaBar:SetAlpha(0)
            PlayerFrameManaBar.Show = PlayerFrameManaBar.Hide
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
        local pulseTime = 0
        overlay:SetScript("OnUpdate", function()
            local elapsed = arg1 or 0
            if active() then
                pulseTime = math.mod(pulseTime + elapsed, 1)
                texture:SetAlpha(0.5 + 0.5 * math.sin(pulseTime * 2 * math.pi))
            else
                texture:SetAlpha(math.max(0, texture:GetAlpha() - elapsed * 2))
            end
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
            if IsResting() then animation:Show() else animation:Hide() end
        end
        local events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_UPDATE_RESTING")
        events:SetScript("OnEvent", UpdateResting)
        UpdateResting()
    end

    local function Initialize()
        if initialized then return end
        initialized = true
        PlayerFrame:SetScale(1)
        PlayerFrame:Show()
        T.CreateHealthOnlyUnitBorder(PlayerFrame, PlayerFrameHealthBar,
            PlayerFrameTexture, PlayerFrameBackground, tex .. "UI-TargetingFrameDF.blp", "LEFT")
        HidePowerBar()
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
            PlayerFrame.name:SetWidth(PlayerFrameHealthBar:GetWidth() - 24)
            PlayerFrame.name:SetJustifyH("LEFT")
            PlayerFrame.name:SetFont(font, 11, "NONE")
            PlayerFrame.name:SetTextColor(1, 0.82, 0)
        end
        if PlayerLevelText then
            PlayerLevelText:ClearAllPoints()
            PlayerLevelText:SetPoint("RIGHT", PlayerFrame, "RIGHT", -14, 25)
            PlayerLevelText:SetFont(font, 11, "NONE")
            PlayerLevelText:SetTextColor(1, 0.82, 0)
        end
        -- Preserve the original addon status effects without stock overlays.
        _G.PlayerFrame_UpdateStatus = function() end
        for _, name in ipairs({"PlayerStatusTexture", "PlayerAttackGlow", "PlayerAttackIcon", "PlayerRestIcon", "PlayerRestGlow", "PlayerAttackBackground"}) do
            local texture = _G[name]
            if texture then
                texture:SetTexture(nil)
                texture:Hide()
            end
        end
        CreatePulse(1, 0, 0, function() return UnitAffectingCombat("player") end)
        CreatePulse(0, 1, 1, IsResting)
        CreateRestingAnimation()
        FixPlayerClick()
        UpdateValues()
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
