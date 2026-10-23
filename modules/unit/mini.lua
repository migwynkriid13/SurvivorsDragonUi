DFRL:NewMod("Mini", 1, function()
    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local units = {}

    -- The same health-only crop removes the old resource divider for both
    -- target-of-target and party frames, retaining the ring and outer edge.
    local function HealthOnlyBorder(parent, anchor, width, height, layer)
        local scaleX, scaleY = width / 128, height / 64
        local strips = {}
        for _, crop in ipairs({ { 0, 0, 44, 64 }, { 44, 0, 84, 22 }, { 44, 34, 84, 30 }, { 114, 22, 14, 12 } }) do
            local x, y, w, h = unpack(crop)
            local strip = parent:CreateTexture(nil, layer)
            strip:SetTexture(tex .. "pet")
            strip:SetTexCoord(x / 128, (x + w) / 128, y / 64, (y + h) / 64)
            strip:SetPoint("TOPLEFT", anchor, "TOPLEFT", x * scaleX, -y * scaleY)
            strip:SetWidth(w * scaleX)
            strip:SetHeight(h * scaleY)
            table.insert(strips, strip)
        end
        return strips
    end

    local function AddValues(frame, health, mana, unit)
        local values = { unit = unit, healthBar = health, manaBar = mana }
        values.health = health:CreateFontString(nil, "OVERLAY")
        T.SetFont(values.health, 9, "OUTLINE")
        values.health:SetPoint("CENTER", health, "CENTER", 0, 0)
        values.health:SetTextColor(1, 1, 1)
        if mana then
            values.mana = mana:CreateFontString(nil, "OVERLAY")
            T.SetFont(values.mana, 8, "OUTLINE")
            values.mana:SetPoint("CENTER", mana, "CENTER", 0, 0)
            values.mana:SetTextColor(1, 1, 1)
        end
        frame:SetScale(1)
        table.insert(units, values)
        return values
    end

    local function SetHealthColor(bar, red, green, blue)
        local currentRed, currentGreen, currentBlue, currentAlpha = bar:GetStatusBarColor()
        if
            not T.NearlyEqual(currentRed, red)
            or not T.NearlyEqual(currentGreen, green)
            or not T.NearlyEqual(currentBlue, blue)
            or (currentAlpha and not T.NearlyEqual(currentAlpha, 1))
        then
            bar:SetStatusBarColor(red, green, blue)
        end
    end

    local function UpdateValues(values)
        local unit = values.unit
        if not UnitExists(unit) or (unit == "targettarget" and (UnitIsDead(unit) or UnitIsGhost(unit))) then
            T.SetTextIfChanged(values.health, "")
            if values.mana then T.SetTextIfChanged(values.mana, "") end
            return
        end
        T.SetTextIfChanged(values.health, UnitHealth(unit))
        if values.mana then
            if UnitManaMax(unit) > 0 then
                T.SetTextIfChanged(values.mana, UnitMana(unit))
            else
                T.SetTextIfChanged(values.mana, "")
            end
        end
        if unit == "targettarget" then
            if not UnitIsPlayer(unit) and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
                SetHealthColor(values.healthBar, 0.5, 0.5, 0.5)
                return
            end
            local reaction = UnitReaction("player", unit)
            if T.IsPlayerOrPartyUnit(unit) then
                SetHealthColor(values.healthBar, 0, 1, 0)
            elseif reaction and reaction <= 3 then
                SetHealthColor(values.healthBar, 1, 0, 0)
            elseif reaction == 4 then
                SetHealthColor(values.healthBar, 1, 1, 0)
            else
                SetHealthColor(values.healthBar, 0, 1, 0)
            end
        elseif string.find(unit, "party") then
            SetHealthColor(values.healthBar, 0, 1, 0)
        end
    end

    if PetFrame and PetFrameHealthBar and PetFrameManaBar then
        local pet = AddValues(PetFrame, PetFrameHealthBar, PetFrameManaBar, "pet")
        local function UpdatePet()
            if PetFrameTexture then
                PetFrameTexture:SetTexture(tex .. "pet")
                PetFrameTexture:SetVertexColor(1, 1, 1, 1)
                PetFrameTexture:SetDrawLayer("BACKGROUND")
            end
            PetFrameHealthBar:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health")
            PetFrameHealthBar:SetHeight(13)
            PetFrameHealthBar:ClearAllPoints()
            PetFrameHealthBar:SetPoint("CENTER", PetFrame, "CENTER", 15, 3)
            local power = UnitPowerType("pet")
            if power == 2 then
                PetFrameManaBar:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus")
            else
                PetFrameManaBar:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana")
            end
            PetFrameManaBar:ClearAllPoints()
            PetFrameManaBar:SetPoint("CENTER", PetFrame, "CENTER", 15, -7)
            if PetName then
                PetName:ClearAllPoints()
                PetName:SetPoint("CENTER", PetFrame, "CENTER", 5, 16)
                T.SetFont(PetName, 10, "")
            end
            UpdateValues(pet)
        end
        if PlayerFrame then
            PetFrame:ClearAllPoints()
            PetFrame:SetPoint("BOTTOM", PlayerFrame, "BOTTOM", -10, -30)
        end
        PetFrameHealthBar:SetScript("OnEnter", nil)
        PetFrameHealthBar:SetScript("OnLeave", nil)
        PetFrameManaBar:SetScript("OnEnter", nil)
        PetFrameManaBar:SetScript("OnLeave", nil)
        if PetFrameHealthBarText then PetFrameHealthBarText:SetAlpha(0) end
        if PetFrameManaBarText then PetFrameManaBarText:SetAlpha(0) end
        local original = _G.PetFrame_Update
        if original then _G.PetFrame_Update = function()
            original()
            UpdatePet()
        end end
        HookScript(PetFrameHealthBar, "OnValueChanged", function() UpdateValues(pet) end)
        HookScript(PetFrameManaBar, "OnValueChanged", function() UpdateValues(pet) end)
        UpdatePet()
    end

    if TargetofTargetFrame and TargetofTargetHealthBar then
        local target = AddValues(TargetofTargetFrame, TargetofTargetHealthBar, nil, "targettarget")
        PermanentlyDisableFrame(TargetofTargetManaBar)
        if TargetofTargetManaBar then TargetofTargetManaBar:SetAlpha(0) end
        for _, name in ipairs({
            "TargetofTargetHealthBarText",
            "TargetofTargetManaBarText",
            "TargetofTargetFrameManaBarText",
        }) do
            local text = _G[name]
            if text then
                text:SetText("")
                text:SetAlpha(0)
                text:Hide()
                text.Show = text.Hide
            end
        end

        local border = CreateFrame("Frame", nil, TargetofTargetFrame)
        TargetofTargetHealthBar:SetFrameLevel(TargetofTargetFrame:GetFrameLevel() + 1)
        border:SetFrameLevel(TargetofTargetHealthBar:GetFrameLevel() + 2)
        border:SetAllPoints(TargetofTargetFrame)
        target.health:SetParent(border)
        if TargetofTargetTexture then
            TargetofTargetTexture:SetAlpha(0)
            TargetofTargetTexture:Hide()
            TargetofTargetTexture.Show = TargetofTargetTexture.Hide
        end
        -- Preserve the original 128x64 portrait/border sheet at its existing size,
        -- omitting only the interior divider between the old health/power rows.
        local borderStrips = HealthOnlyBorder(
            border,
            border,
            TargetofTargetFrame:GetWidth() + 20,
            TargetofTargetFrame:GetHeight() + 15,
            "OVERLAY"
        )
        if TargetFrame then
            TargetofTargetFrame:ClearAllPoints()
            TargetofTargetFrame:SetPoint("TOPLEFT", TargetFrame, "BOTTOM", 0, 20)
        end
        if TargetofTargetPortrait then
            TargetofTargetPortrait:SetParent(border)
            TargetofTargetPortrait:SetDrawLayer("ARTWORK")
            TargetofTargetPortrait:SetHeight(32)
            TargetofTargetPortrait:SetWidth(32)
        end
        if TargetofTargetFrameDebuff1 then
            TargetofTargetFrameDebuff1:ClearAllPoints()
            TargetofTargetFrameDebuff1:SetPoint("TOPLEFT", TargetofTargetFrame, "BOTTOMLEFT", 40, 5)
        end
        if TargetofTargetBackground then
            TargetofTargetBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
            TargetofTargetBackground:SetTexCoord(0, 1, 0, 1)
            TargetofTargetBackground:SetVertexColor(0, 0, 0, 0.6)
            TargetofTargetBackground:ClearAllPoints()
            TargetofTargetBackground:SetAllPoints(TargetofTargetHealthBar)
        end
        TargetofTargetHealthBar:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health.tga")
        TargetofTargetHealthBar:SetWidth(60)
        TargetofTargetHealthBar:SetHeight(16)
        TargetofTargetHealthBar:ClearAllPoints()
        TargetofTargetHealthBar:SetPoint("LEFT", TargetofTargetFrame, "LEFT", 40, -1.5)
        TargetofTargetHealthBar:SetScript("OnEnter", nil)
        TargetofTargetHealthBar:SetScript("OnLeave", nil)
        local portraitless = T.CreatePortraitlessBorder(TargetofTargetFrame, TargetofTargetHealthBar, 16)
        local portraitsHidden
        local function UpdatePortraitVisibility()
            local hidden = DFRL.display.Get("hidePortraits")
            if hidden == portraitsHidden then return end
            portraitsHidden = hidden
            for _, strip in ipairs(borderStrips) do
                strip:SetAlpha(hidden and 0 or 1)
            end
            if hidden then
                portraitless:Show()
            else
                portraitless:Hide()
            end
        end
        DFRL.display.Listen(UpdatePortraitVisibility)
        UpdatePortraitVisibility()
        if TargetofTargetDeadText then
            TargetofTargetDeadText:SetParent(border)
            TargetofTargetDeadText:ClearAllPoints()
            TargetofTargetDeadText:SetPoint("CENTER", TargetofTargetHealthBar, "CENTER", 0, 0)
            T.SetFont(TargetofTargetDeadText, 9, "OUTLINE")
        end
        if TargetofTargetFrame.name then
            TargetofTargetFrame.name:ClearAllPoints()
            TargetofTargetFrame.name:SetPoint("TOPLEFT", TargetofTargetFrame, "TOPLEFT", 40, 25)
            T.SetFont(TargetofTargetFrame.name, 9, "")
        end
        local function UpdateTarget()
            if TargetofTargetFrame.name and UnitExists("targettarget") then
                local name = UnitName("targettarget")
                if name then
                    local preview, clipped = DFRL.locale.Preview(name, 8)
                    name = preview .. (clipped and "..." or "")
                end
                T.SetTextIfChanged(TargetofTargetFrame.name, name or DFRL.locale.Text("No target"))
            end
            UpdateValues(target)
        end
        local original = _G.TargetofTarget_Update
        if original then
            _G.TargetofTarget_Update = function()
                original()
                UpdateTarget()
            end
        end
        HookScript(TargetofTargetHealthBar, "OnValueChanged", function() UpdateValues(target) end)
        UpdateTarget()
    end

    for i = 1, 4 do
        local prefix = "PartyMemberFrame" .. i
        local frame, health, mana = _G[prefix], _G[prefix .. "HealthBar"], _G[prefix .. "ManaBar"]
        if frame and health and mana then
            local values = AddValues(frame, health, nil, "party" .. i)
            if i == 1 then
                frame:ClearAllPoints()
                frame:SetPoint("LEFT", UIParent, "LEFT", 10, 220)
            end
            if _G[prefix .. "Texture"] then _G[prefix .. "Texture"]:SetAlpha(0) end
            local borderFrame = CreateFrame("Frame", nil, frame)
            borderFrame:SetAllPoints(frame)
            borderFrame:SetFrameLevel(math.max(health:GetFrameLevel(), mana:GetFrameLevel()) + 1)
            values.health:SetParent(borderFrame)
            local border = borderFrame:CreateTexture(nil, "BORDER")
            border:SetTexture(tex .. "pet")
            border:SetVertexColor(1, 1, 1, 1)
            border:SetPoint("CENTER", frame, "CENTER", 0, 0)
            border:SetWidth(128)
            border:SetHeight(64)
            local healthOnlyBorder = HealthOnlyBorder(borderFrame, border, 128, 64, "BORDER")
            local portrait = _G[prefix .. "Portrait"]
            if portrait then
                portrait:SetParent(borderFrame)
                portrait:SetHeight(35)
                portrait:SetWidth(35)
                portrait:SetDrawLayer("BACKGROUND")
                portrait:ClearAllPoints()
                portrait:SetPoint("CENTER", frame, "CENTER", -40, 8.25)
            end
            local name = _G[prefix .. "Name"]
            if name then
                name:ClearAllPoints()
                name:SetPoint("CENTER", frame, "CENTER", 6, 23)
                name:SetDrawLayer("BORDER")
                T.SetFont(name, 10, "")
            end
            health:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health")
            mana:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Health-Status.tga")
            health:SetHeight(11)
            health:ClearAllPoints()
            health:SetPoint("CENTER", frame, "CENTER", 15, 10)
            mana:SetHeight(5)
            mana:ClearAllPoints()
            mana:SetPoint("CENTER", frame, "CENTER", 15, 0.5)
            for _, bar in ipairs({ health, mana }) do
                local background = bar:CreateTexture(nil, "BACKGROUND")
                background:SetTexture(bar:GetStatusBarTexture():GetTexture())
                background:SetVertexColor(0.3, 0.3, 0.3, 0.5)
                background:SetAllPoints(bar)
            end
            -- Mask the native row rather than disabling its Show/Hide or value
            -- updates, so preview, Cancel and later native refreshes coexist.
            T.BindUnitLabelVisibility(mana, "classResources")
            T.BindUnitLabelVisibility(_G[prefix .. "ManaBarText"], "classResources")
            local healthWidth = health:GetWidth()
            local resourcesShown
            local function UpdateResources()
                local shown = DFRL.display.Get("classResources")
                if shown == resourcesShown then return end
                resourcesShown = shown
                -- Cover the lower portrait curve and the fill's shaded leading
                -- edge beneath the rim, keeping the right edge and value fixed.
                local extension = shown and 0 or 12
                health:SetWidth(healthWidth + extension)
                health:SetHeight(shown and 11 or 17.5)
                health:SetPoint("CENTER", frame, "CENTER", 15 - extension / 2, shown and 10 or 6.75)
                values.health:SetPoint("CENTER", health, "CENTER", extension / 2, 0)
                border:SetAlpha(shown and 1 or 0)
                for _, strip in ipairs(healthOnlyBorder) do
                    strip:SetAlpha(shown and 0 or 1)
                end
            end
            DFRL.display.Listen(UpdateResources)
            UpdateResources()
            if _G[prefix .. "HealthBarText"] then _G[prefix .. "HealthBarText"]:SetAlpha(0) end
            HookScript(health, "OnValueChanged", function() UpdateValues(values) end)
        end
    end

    local function UpdateAll()
        for _, values in ipairs(units) do
            UpdateValues(values)
        end
    end
    local unitEvents = {
        UNIT_HEALTH = true,
        UNIT_MANA = true,
        UNIT_ENERGY = true,
        UNIT_RAGE = true,
        UNIT_FOCUS = true,
        UNIT_FACTION = true,
    }
    if table.getn(units) == 0 then return end
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UNIT_MANA")
    frame:RegisterEvent("UNIT_ENERGY")
    frame:RegisterEvent("UNIT_RAGE")
    frame:RegisterEvent("UNIT_FOCUS")
    frame:RegisterEvent("UNIT_PET")
    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("UNIT_TARGET")
    frame:RegisterEvent("UNIT_FACTION")
    frame:SetScript("OnEvent", function()
        if unitEvents[event] and type(arg1) == "string" and arg1 ~= "" then
            for _, values in ipairs(units) do
                if values.unit == arg1 or UnitIsUnit(values.unit, arg1) then UpdateValues(values) end
            end
        else
            -- Ownership and target transitions can invalidate several aliases.
            UpdateAll()
        end
    end)
    UpdateAll()
end)
