DFRL:NewMod("Cut-Out", 1, function()
    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local bars = {
        { "PlayerFrameHealthBar", "player" },
        { "TargetFrameHealthBar", "target" },
        { "TargetofTargetHealthBar", "targettarget" },
    }
    local cutouts, fading = {}, {}
    local frame = CreateFrame("Frame")
    local initialized = false
    local animationEnabled = DFRL.display.Get("healthLossAnimation") and not DFRL.display.Get("performanceMode")

    local function ReadValue(cutout) return T.GetUnitHealth(cutout.unit) end

    local function Stop(cutout)
        if cutout.texture:IsShown() then cutout.texture:Hide() end
        cutout.startFraction, cutout.widthFraction = nil, nil
        if cutout.fading then
            for index = table.getn(fading), 1, -1 do
                if fading[index] == cutout then table.remove(fading, index) end
            end
            cutout.fading = nil
            if table.getn(fading) == 0 then frame:SetScript("OnUpdate", nil) end
        end
    end

    local function Reset(cutout)
        Stop(cutout)
        cutout.lastValue, cutout.lastMax, cutout.generation = nil, nil, nil
        if not animationEnabled or not cutout.bar:IsVisible() then return end
        cutout.lastValue, cutout.lastMax, cutout.generation = ReadValue(cutout)
        if cutout.lastValue and cutout.lastMax and cutout.lastMax > 0 then
            cutout.lastValue = math.max(0, math.min(cutout.lastValue, cutout.lastMax))
        end
    end

    local function PlaceLoss(cutout)
        if not cutout.bar:IsVisible() then return end
        if not cutout.startFraction or not cutout.widthFraction then return end
        local width = cutout.bar:GetWidth()
        if width <= 0 then return end
        local texture = cutout.texture
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", cutout.bar, "TOPLEFT", width * cutout.startFraction, 0)
        texture:SetPoint("BOTTOMLEFT", cutout.bar, "BOTTOMLEFT", width * cutout.startFraction, 0)
        texture:SetWidth(width * cutout.widthFraction)
    end

    local function Animate()
        local now = GetTime()
        local i = 1
        while i <= table.getn(fading) do
            local cutout = fading[i]
            local elapsed = now - cutout.fadeStart
            if elapsed >= 0.5 or not cutout.texture:IsVisible() then
                cutout.texture:Hide()
                cutout.fading = nil
                table.remove(fading, i)
            else
                cutout.texture:SetAlpha(1 - elapsed / 0.5)
                i = i + 1
            end
        end
        if table.getn(fading) == 0 then frame:SetScript("OnUpdate", nil) end
    end

    local function Update(cutout)
        if
            not animationEnabled
            or not cutout.bar:IsVisible()
            or not UnitExists(cutout.unit)
            or UnitIsDead(cutout.unit)
            or UnitIsGhost(cutout.unit)
        then
            Reset(cutout)
            return
        end
        local current, maximum, generation = ReadValue(cutout)
        if
            not current
            or not maximum
            or maximum <= 0
            or maximum ~= cutout.lastMax
            or generation ~= cutout.generation
            or not cutout.lastValue
        then
            Reset(cutout)
            return
        end
        current = math.max(0, math.min(current, maximum))
        local previous = math.max(0, math.min(cutout.lastValue, maximum))
        local lost = previous - current
        cutout.lastValue = current
        if lost <= 0 then return end
        local width = cutout.bar:GetWidth()
        if width <= 0 then return end
        cutout.startFraction = current / maximum
        cutout.widthFraction = math.min(1 - cutout.startFraction, lost / maximum)
        if cutout.widthFraction <= 0 then return end
        PlaceLoss(cutout)
        local texture = cutout.texture
        texture:SetAlpha(1)
        texture:Show()
        cutout.fadeStart = GetTime()
        if not cutout.fading then
            cutout.fading = true
            table.insert(fading, cutout)
        end
        frame:SetScript("OnUpdate", Animate)
    end

    DFRL.display.Listen(function()
        local enabled = DFRL.display.Get("healthLossAnimation") and not DFRL.display.Get("performanceMode")
        if enabled == animationEnabled then return end
        animationEnabled = enabled
        frame:SetScript("OnUpdate", nil)
        fading = {}
        for _, cutout in ipairs(cutouts) do
            cutout.fading, cutout.fadeStart = nil, nil
            Reset(cutout)
        end
    end)

    local function Initialize()
        if initialized then return end
        initialized = true
        for _, data in ipairs(bars) do
            local bar = _G[data[1]]
            if bar then
                local overlay = CreateFrame("Frame", nil, bar)
                overlay:SetFrameLevel(bar:GetFrameLevel() + 1)
                overlay:SetAllPoints(bar)
                local texture = overlay:CreateTexture(nil, "OVERLAY")
                if data[1] == "PlayerFrameHealthBar" or data[1] == "TargetFrameHealthBar" then
                    local healthFill = T.LargeHealthFill
                    texture:SetTexture(healthFill.texture)
                    texture:SetTexCoord(unpack(healthFill.texCoords))
                else
                    texture:SetTexture(tex .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-HealthFill.blp")
                end
                texture:SetVertexColor(1, 1, 1, 0.7)
                local cutout = { bar = bar, texture = texture, unit = data[2] }
                table.insert(cutouts, cutout)
                Reset(cutout)
                HookScript(bar, "OnHide", function() Reset(cutout) end)
                HookScript(bar, "OnValueChanged", function() Update(cutout) end)
                HookScript(bar, "OnShow", function() Reset(cutout) end)
                HookScript(bar, "OnSizeChanged", function() PlaceLoss(cutout) end)
                if cutout.unit == "target" and DFRL.targetHealth then
                    DFRL.targetHealth.Listen(function() Update(cutout) end)
                end
            end
        end
    end

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("UNIT_TARGET")
    frame:RegisterEvent("PLAYER_LEAVING_WORLD")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            Initialize()
            for _, cutout in ipairs(cutouts) do
                Reset(cutout)
            end
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            for _, cutout in ipairs(cutouts) do
                Stop(cutout)
                cutout.lastValue, cutout.lastMax, cutout.generation = nil, nil, nil
            end
        elseif event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_TARGET" and arg1 == "target") then
            for _, cutout in ipairs(cutouts) do
                if cutout.unit == "targettarget" or (cutout.unit == "target" and event == "PLAYER_TARGET_CHANGED") then
                    Reset(cutout)
                end
            end
        end
    end)
    if UnitExists("player") then Initialize() end
end)
