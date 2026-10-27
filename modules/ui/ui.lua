DFRL:NewMod("Native micro buttons", 1, function()
    local quietButtons = {}
    for _, name in ipairs({ "TalentMicroButton", "PlayerFrame" }) do
        local button = _G[name]
        if button then
            quietButtons[button] = true
            if type(ButtonPulse_StopPulse) == "function" then ButtonPulse_StopPulse(button) end
            button:UnlockHighlight()
        end
    end
    if next(quietButtons) then
        local setButtonPulse = _G.SetButtonPulse
        if type(setButtonPulse) == "function" then
            _G.SetButtonPulse = function(button, duration, pulseRate)
                if quietButtons[button] then return end
                return setButtonPulse(button, duration, pulseRate)
            end
        end
    end
    for _, name in ipairs({
        "CharacterMicroButton",
        "TalentMicroButton",
        "MainMenuMicroButton",
        "SpellbookMicroButton",
        "WorldMapMicroButton",
        "QuestLogMicroButton",
        "SocialsMicroButton",
        "HelpMicroButton",
    }) do
        PermanentlyDisableFrame(_G[name])
    end
    if MicroButtonPortrait then
        MicroButtonPortrait:Hide()
        MicroButtonPortrait.Show = MicroButtonPortrait.Hide
    end
end)

DFRL:NewMod("Ui", 5, function()
    -- locals
    local texpath = DFRL:GetInfoOrCons("tex") .. "ui\\"
    local UnitHealth = UnitHealth
    local UnitHealthMax = UnitHealthMax
    local sin = math.sin

    -- hide stuff
    do
        if PetPaperDollCloseButton then PetPaperDollCloseButton:Hide() end
        if SkillFrameCancelButton then SkillFrameCancelButton:Hide() end
    end

    -- close button
    do
        local closeButtonData = {
            { "FriendsFrame", "FriendsFrameCloseButton", -36, -15 },
            { "HelpFrame", "HelpFrameCloseButton", -50, -10 },
            { "GuildMemberDetailFrame", "GuildMemberDetailCloseButton", -10, -10 },
        }

        for i = 1, 5 do
            table.insert(closeButtonData, { "ContainerFrame" .. i, "ContainerFrame" .. i .. "CloseButton", -8, -8 })
        end

        local path = texpath .. "close_normal.blp"
        local pathpushed = texpath .. "close_pushed.blp"

        for _, data in ipairs(closeButtonData) do
            local frameName, buttonName, offsetX, offsetY = unpack(data)
            local frame = _G[frameName]
            local button = _G[buttonName]

            if button then
                button:SetNormalTexture(path)
                button:SetPushedTexture(pathpushed)
                button:SetHighlightTexture(path)
                button:SetWidth(17)
                button:SetHeight(17)
                button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", offsetX, offsetY)
            end
        end
    end

    SetCVar("CameraDistanceMaxFactor", 3)

    local warning = CreateFrame("Frame", "DFRL_LowHpWarnFrame", UIParent)
    warning:SetAllPoints(UIParent)
    warning:SetFrameStrata("BACKGROUND")
    warning:Hide()
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local texture = warning:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        if side == "TOP" or side == "BOTTOM" then
            texture:SetPoint(side .. "LEFT", warning, side .. "LEFT", 0, 0)
            texture:SetPoint(side .. "RIGHT", warning, side .. "RIGHT", 0, 0)
            texture:SetHeight(64)
        else
            texture:SetPoint("TOP" .. side, warning, "TOP" .. side, 0, 0)
            texture:SetPoint("BOTTOM" .. side, warning, "BOTTOM" .. side, 0, 0)
            texture:SetWidth(64)
        end
        edges[side] = texture
    end
    local elapsed, pulse = 0, 0
    local updateCursor = DFRL.cursor and DFRL.cursor.Update
    local monitor = CreateFrame("Frame")
    monitor:SetScript("OnUpdate", function()
        if updateCursor then updateCursor() end
        elapsed = elapsed + arg1
        if elapsed < 0.05 then return end
        local maximum = UnitHealthMax("player")
        local health = maximum > 0 and UnitHealth("player") / maximum * 100 or 100
        if health > 70 or UnitIsDeadOrGhost("player") then
            if warning:IsShown() then warning:Hide() end
            pulse = 0
        else
            local intensity = math.max(0, math.min(1, (70 - health) / 70))
            pulse = pulse + elapsed * (1 + 7 * intensity)
            local alpha = 0.7 * (0.1 + 0.9 * intensity) * (0.3 + 0.7 * (sin(pulse) + 1) / 2)
            edges.TOP:SetGradientAlpha("VERTICAL", 1, 0, 0, 0, 1, 0, 0, alpha)
            edges.BOTTOM:SetGradientAlpha("VERTICAL", 1, 0, 0, alpha, 1, 0, 0, 0)
            edges.LEFT:SetGradientAlpha("HORIZONTAL", 1, 0, 0, alpha, 1, 0, 0, 0)
            edges.RIGHT:SetGradientAlpha("HORIZONTAL", 1, 0, 0, 0, 1, 0, 0, alpha)
            if not warning:IsShown() then warning:Show() end
        end
        elapsed = 0
    end)
end)

-- The native build is renderer-owned; control it through the official HUD API.
DFRL:NewMod("Native build rows", 1, function()
    local inWorld, applying = true, false
    local function ApplyBuild()
        if not inWorld or applying then return end
        if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then return end
        local ok, shown = pcall(AZS_IsHudShown, "build")
        if not ok or (shown ~= true and shown ~= false and shown ~= 1 and shown ~= 0) then return end
        local wanted = not DFRL.display.Get("hideNativeBuild")
        if (shown == true or shown == 1) == wanted then return end
        applying = true
        pcall(AZS_SetHudShown, "build", wanted)
        applying = false
    end
    local controller = CreateFrame("Frame")
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("CVAR_UPDATE")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            ApplyBuild()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            -- Restore the committed native preference before world-exit saving,
            -- regardless of the layout controller's event-handler order.
            DFRL.display.FinishEdit(false)
            ApplyBuild()
            inWorld = false
        elseif type(arg1) == "string" and string.lower(arg1) == "hudbuild" then
            ApplyBuild()
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            -- The native setter also changes the game's saved HUD preference.
            -- Discard previews before ReloadUI can serialize that preference.
            DFRL.display.FinishEdit(false)
            ApplyBuild()
            return reloadUI()
        end
    end
    DFRL.display.Listen(ApplyBuild)
    ApplyBuild()
end)
