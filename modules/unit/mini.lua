DFRL:NewMod("Mini", 1, function()
    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local font = "DEFAULT"
    local units = {}

    local function AddValues(frame, health, mana, unit)
        local values = { unit = unit, healthBar = health, manaBar = mana }
        values.health = health:CreateFontString(nil, "OVERLAY")
        values.health:SetFont(font, 9, "OUTLINE")
        values.health:SetPoint("CENTER", health, "CENTER", 0, 0)
        values.health:SetTextColor(1, 1, 1)
        if mana then
            values.mana = mana:CreateFontString(nil, "OVERLAY")
            values.mana:SetFont(font, 8, "OUTLINE")
            values.mana:SetPoint("CENTER", mana, "CENTER", 0, 0)
            values.mana:SetTextColor(1, 1, 1)
        end
        frame:SetScale(1)
        table.insert(units, values)
        return values
    end

    local function UpdateValues(values)
        local unit = values.unit
        if not UnitExists(unit) or (unit == "targettarget" and (UnitIsDead(unit) or UnitIsGhost(unit))) then
            values.health:SetText("")
            if values.mana then values.mana:SetText("") end
            return
        end
        values.health:SetText(UnitHealth(unit))
        if values.mana then
            if UnitManaMax(unit) > 0 then
                values.mana:SetText(UnitMana(unit))
            else
                values.mana:SetText("")
            end
        end
        if unit == "targettarget" then
            if not UnitIsPlayer(unit) and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
                values.healthBar:SetStatusBarColor(0.5, 0.5, 0.5)
                return
            end
            local reaction = UnitReaction("player", unit)
            if reaction and reaction <= 3 then
                values.healthBar:SetStatusBarColor(1, 0, 0)
            elseif reaction == 4 then
                values.healthBar:SetStatusBarColor(1, 1, 0)
            else
                values.healthBar:SetStatusBarColor(0, 1, 0)
            end
        elseif string.find(unit, "party") then
            values.healthBar:SetStatusBarColor(0, 1, 0)
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
                PetName:SetFont(font, 10, "")
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
        local scaleX = (TargetofTargetFrame:GetWidth() + 20) / 128
        local scaleY = (TargetofTargetFrame:GetHeight() + 15) / 64
        local function AddBorderStrip(x, y, width, height)
            local strip = border:CreateTexture(nil, "OVERLAY")
            strip:SetTexture(tex .. "pet")
            strip:SetTexCoord(x / 128, (x + width) / 128, y / 64, (y + height) / 64)
            strip:SetPoint("TOPLEFT", border, "TOPLEFT", x * scaleX, -y * scaleY)
            strip:SetWidth(width * scaleX)
            strip:SetHeight(height * scaleY)
        end
        AddBorderStrip(0, 0, 44, 64)
        AddBorderStrip(44, 0, 84, 22)
        AddBorderStrip(44, 34, 84, 30)
        AddBorderStrip(114, 22, 14, 12)
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
        if TargetofTargetDeadText then
            TargetofTargetDeadText:SetParent(border)
            TargetofTargetDeadText:ClearAllPoints()
            TargetofTargetDeadText:SetPoint("CENTER", TargetofTargetHealthBar, "CENTER", 0, 0)
            TargetofTargetDeadText:SetFont(font, 9, "OUTLINE")
        end
        if TargetofTargetFrame.name then
            TargetofTargetFrame.name:ClearAllPoints()
            TargetofTargetFrame.name:SetPoint("TOPLEFT", TargetofTargetFrame, "TOPLEFT", 40, 25)
            TargetofTargetFrame.name:SetFont(font, 9, "")
        end
        local function UpdateTarget()
            if TargetofTargetFrame.name and UnitExists("targettarget") then
                local name = UnitName("targettarget")
                if name then
                    local preview, clipped = DFRL.locale.Preview(name, 8)
                    name = preview .. (clipped and "..." or "")
                end
                TargetofTargetFrame.name:SetText(name or DFRL.locale.Text("No target"))
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
            local border = frame:CreateTexture(nil, "BORDER")
            border:SetTexture(tex .. "pet")
            border:SetVertexColor(1, 1, 1, 1)
            border:SetPoint("CENTER", frame, "CENTER", 0, 0)
            border:SetWidth(128)
            border:SetHeight(64)
            local portrait = _G[prefix .. "Portrait"]
            if portrait then
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
                name:SetFont(font, 10, "")
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
            if _G[prefix .. "HealthBarText"] then _G[prefix .. "HealthBarText"]:SetAlpha(0) end
            HookScript(health, "OnValueChanged", function() UpdateValues(values) end)
        end
    end

    local function UpdateAll()
        for _, values in ipairs(units) do
            UpdateValues(values)
        end
    end
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
    frame:SetScript("OnEvent", UpdateAll)
    UpdateAll()
end)
