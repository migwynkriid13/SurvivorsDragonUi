DFRL:NewMod("Mini", 1, function()
    local tex = DFRL:GetInfoOrCons("tex") .. "unitframes\\"
    local units = {}
    local healthFill = T.LargeHealthFill
    -- The compact one-unit metal edge needs half the large frame's underlap.
    local healthUnderlap = healthFill.underlap / 2
    local partyHealthCrops = {
        { 0, 0, 44, 26 },
        { 0, 26, 43, 1 },
        { 0, 27, 44, 1 },
        { 0, 28, 43, 1 },
        { 0, 29, 42, 3 },
        { 0, 32, 41, 2 },
        { 0, 34, 40, 1 },
        { 0, 35, 44, 29 },
        { 44, 0, 68, 18 },
        { 112, 0, 16, 18 },
        { 44, 34, 68, 30 },
        { 112, 34, 16, 30 },
        { 112, 18, 16, 8 },
        { 112, 26, 16, 3, 22 },
        { 112, 29, 16, 5 },
    }

    -- Keep the original target-of-target crop; party rows additionally trim the
    -- portrait's divider stubs and retain the complete rounded outer end.
    local function HealthOnlyBorder(parent, anchor, width, height, layer, crops, elastic)
        local scaleX, scaleY = width / 128, height / 64
        local strips, pieces = {}, elastic and {} or nil
        for _, crop in ipairs(crops or { { 0, 0, 44, 64 }, { 44, 0, 84, 22 }, { 44, 34, 84, 30 }, { 114, 22, 14, 12 } }) do
            local x, y, w, h, sourceY = unpack(crop)
            sourceY = sourceY or y
            -- One-row portrait tips must not filter the neighboring divider.
            local tip = h == 1 and 0.5 or 0
            local strip = parent:CreateTexture(nil, layer)
            strip:SetTexture(tex .. "pet")
            strip:SetTexCoord(x / 128, (x + w - tip) / 128, (sourceY + tip) / 64, (sourceY + h - tip) / 64)
            strip:SetPoint("TOPLEFT", anchor, "TOPLEFT", x * scaleX, -y * scaleY)
            strip:SetWidth(w * scaleX)
            strip:SetHeight(h * scaleY)
            table.insert(strips, strip)
            if elastic then table.insert(pieces, { texture = strip, x = x, y = -y * scaleY, width = w * scaleX }) end
        end
        if not elastic then return strips end
        local applied = 0
        local function Resize(delta)
            if T.NearlyEqual(applied, delta) then return end
            applied = delta
            for _, piece in ipairs(pieces) do
                local x = piece.x * scaleX + (piece.x >= 112 and delta or 0)
                local w = piece.width + (piece.x >= 44 and piece.x < 112 and delta or 0)
                if not T.NearlyEqual(piece.texture:GetWidth(), w) then piece.texture:SetWidth(w) end
                piece.texture:ClearAllPoints()
                piece.texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, piece.y)
            end
        end
        return strips, Resize
    end

    local function AddValues(frame, health, mana, unit)
        local values = { frame = frame, unit = unit, healthBar = health, manaBar = mana }
        values.health = health:CreateFontString(nil, "OVERLAY")
        T.SetFont(values.health, 9, "OUTLINE")
        values.health:SetPoint("CENTER", health, "CENTER", 0, 0)
        values.health:SetTextColor(1, 1, 1)
        values.healthLabels = T.BindUnitHealthText(health, values.health, unit, unit == "targettarget")
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
        if not values.frame:IsVisible() then return end
        if values.resize then values.resize() end
        local unit = values.unit
        values.healthLabels.Update()
        if not UnitExists(unit) or (unit == "targettarget" and (UnitIsDead(unit) or UnitIsGhost(unit))) then
            if values.mana then T.SetTextIfChanged(values.mana, "") end
            return
        end
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
        elseif values.updateHealthColor then
            values.updateHealthColor()
        end
    end

    if PetFrame and PetFrameHealthBar and PetFrameManaBar then
        local pet = AddValues(PetFrame, PetFrameHealthBar, PetFrameManaBar, "pet")
        local function CenterPet(region, x, y)
            local point, relative, relativePoint, oldX, oldY = region:GetPoint(1)
            if
                region:GetNumPoints() == 1
                and point == "CENTER"
                and relative == PetFrame
                and relativePoint == "CENTER"
                and T.NearlyEqual(oldX, x)
                and T.NearlyEqual(oldY, y)
            then
                return
            end
            region:ClearAllPoints()
            region:SetPoint("CENTER", PetFrame, "CENTER", x, y)
        end
        local function PetBarTexture(bar, name)
            local texture = bar:GetStatusBarTexture()
            local path = tex .. name
            if not texture or texture:GetTexture() ~= path then bar:SetStatusBarTexture(path) end
        end
        local function UpdatePet()
            if not PetFrame:IsVisible() then return end
            if PetFrameTexture then
                local path = tex .. "pet"
                if PetFrameTexture:GetTexture() ~= path then PetFrameTexture:SetTexture(path) end
                local r, g, b, a
                if PetFrameTexture.GetVertexColor then
                    r, g, b, a = PetFrameTexture:GetVertexColor()
                end
                if
                    not T.NearlyEqual(r, 1)
                    or not T.NearlyEqual(g, 1)
                    or not T.NearlyEqual(b, 1)
                    or not T.NearlyEqual(a, 1)
                then
                    PetFrameTexture:SetVertexColor(1, 1, 1, 1)
                end
                if not PetFrameTexture.GetDrawLayer or PetFrameTexture:GetDrawLayer() ~= "BACKGROUND" then
                    PetFrameTexture:SetDrawLayer("BACKGROUND")
                end
            end
            PetBarTexture(PetFrameHealthBar, "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health")
            if not T.NearlyEqual(PetFrameHealthBar:GetHeight(), 13) then PetFrameHealthBar:SetHeight(13) end
            CenterPet(PetFrameHealthBar, 15, 3)
            local power = UnitPowerType("pet")
            PetBarTexture(
                PetFrameManaBar,
                power == 2 and "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus"
                    or "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana"
            )
            CenterPet(PetFrameManaBar, 15, -7)
            if PetName then
                CenterPet(PetName, 5, 16)
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
        HookScript(PetFrame, "OnShow", UpdatePet)
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
        target.healthLabels.percentage:SetParent(border)
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
        TargetofTargetHealthBar:SetStatusBarTexture(
            tex .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-HealthFill.blp"
        )
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
                if hidden then
                    if strip:IsShown() then strip:Hide() end
                elseif not strip:IsShown() then
                    strip:Show()
                end
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
            if not TargetofTargetFrame:IsVisible() then return end
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
        HookScript(TargetofTargetFrame, "OnShow", UpdateTarget)
        UpdateTarget()
    end

    local partyRoot, partyRegion
    if PartyMemberFrame1 and PartyMemberFrame1HealthBar and PartyMemberFrame1ManaBar then
        partyRoot = CreateFrame("Frame", "DFRL_PartyFrames", UIParent)
        partyRoot:SetWidth(PartyMemberFrame1:GetWidth())
        partyRoot.defaultWidth = partyRoot:GetWidth()
        partyRoot:SetHeight(PartyMemberFrame1:GetHeight())
        partyRoot:EnableMouse(false)
        partyRegion = CreateFrame("Frame", nil, partyRoot)
        partyRegion:EnableMouse(false)
    end

    for i = 1, 4 do
        local prefix = "PartyMemberFrame" .. i
        local frame, health, mana = _G[prefix], _G[prefix .. "HealthBar"], _G[prefix .. "ManaBar"]
        if frame and health and mana then
            local values = AddValues(frame, health, nil, "party" .. i)
            values.updateHealthColor = T.BindClassHealthColor(health, values.unit)
            if partyRoot then
                -- Keep native row/pet anchors and visibility; the passive owner
                -- supplies only the shared layout transform and hidden flag.
                frame:SetParent(partyRoot)
                if frame.SetUserPlaced then frame:SetUserPlaced(false) end
                frame:SetMovable(false)
            end
            if i == 1 and partyRoot then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", partyRoot, "TOPLEFT", 0, 0)
            end
            local nativeTexture = _G[prefix .. "Texture"]
            if nativeTexture then
                nativeTexture:Hide()
                nativeTexture.Show = nativeTexture.Hide
            end
            local borderFrame = CreateFrame("Frame", nil, frame)
            borderFrame:SetAllPoints(frame)
            borderFrame:SetFrameLevel(math.max(health:GetFrameLevel(), mana:GetFrameLevel()) + 1)
            values.health:SetParent(borderFrame)
            values.healthLabels.percentage:SetParent(borderFrame)
            local defaultWidth = frame:GetWidth()
            local border = CreateFrame("Frame", nil, borderFrame)
            border:EnableMouse(false)
            border:SetPoint("CENTER", frame, "CENTER", 0, 0)
            border:SetWidth(128)
            border:SetHeight(64)
            if partyRegion then
                if i == 1 then partyRegion:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0) end
                partyRegion:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
            end
            local fullBorder, resizeFullBorder = HealthOnlyBorder(borderFrame, border, 128, 64, "BORDER", {
                { 0, 0, 44, 64 },
                { 44, 0, 68, 64 },
                { 112, 0, 16, 64 },
            }, true)
            local healthOnlyBorder, resizeHealthBorder =
                HealthOnlyBorder(borderFrame, border, 128, 64, "BORDER", partyHealthCrops, true)
            local portrait = _G[prefix .. "Portrait"]
            if portrait then
                portrait:SetParent(borderFrame)
                portrait:SetHeight(35)
                portrait:SetWidth(35)
                portrait:SetDrawLayer("BACKGROUND")
                portrait:ClearAllPoints()
                portrait:SetPoint("CENTER", border, "LEFT", 24, 8.25)
            end
            local name = _G[prefix .. "Name"]
            if name then
                name:ClearAllPoints()
                name:SetPoint("CENTER", frame, "CENTER", 6, 23)
                name:SetDrawLayer("BORDER")
                T.SetFont(name, 10, "")
            end
            health:SetStatusBarTexture(healthFill.texture)
            mana:SetStatusBarTexture(tex .. "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Health-Status.blp")
            health:SetHeight(11)
            health:ClearAllPoints()
            health:SetPoint("CENTER", frame, "CENTER", 15, 10)
            mana:SetHeight(5)
            mana:ClearAllPoints()
            mana:SetPoint("CENTER", frame, "CENTER", 15, 0.5)
            for _, bar in ipairs({ health, mana }) do
                local texture = bar:GetStatusBarTexture()
                if texture then
                    local background = bar:CreateTexture(nil, "BACKGROUND")
                    if bar == health then
                        background:SetTexture("Interface\\Buttons\\WHITE8X8")
                        background:SetVertexColor(0, 0, 0, 0.6)
                    else
                        background:SetTexture(texture:GetTexture())
                        background:SetVertexColor(0.3, 0.3, 0.3, 0.5)
                    end
                    background:SetAllPoints(bar)
                end
            end
            -- Mask the native row rather than disabling its Show/Hide or value
            -- updates, so preview, Cancel and later native refreshes coexist.
            T.BindUnitLabelVisibility(mana, "classResources")
            T.BindUnitLabelVisibility(_G[prefix .. "ManaBarText"], "classResources")
            local healthWidth, manaWidth = health:GetWidth(), mana:GetWidth()
            if i == 1 and partyRoot then partyRoot.minWidth = partyRoot.defaultWidth - math.max(0, healthWidth - 40) end
            local nameWidth = name and name:GetWidth()
            local resourcesShown, appliedDelta
            local function UpdateResources()
                local shown = DFRL.display.Get("classResources")
                local delta = partyRoot and partyRoot:GetWidth() - partyRoot.defaultWidth or 0
                -- Row/root bounds remain available to the shared editor while
                -- invisible native rows defer their texture and caption work.
                if not T.NearlyEqual(frame:GetWidth(), defaultWidth + delta) then
                    frame:SetWidth(defaultWidth + delta)
                end
                if not T.NearlyEqual(border:GetWidth(), 128 + delta) then border:SetWidth(128 + delta) end
                if resourcesShown ~= nil and not frame:IsVisible() and not DFRL.layout.IsEditing() then return end
                if shown == resourcesShown and T.NearlyEqual(appliedDelta, delta) then return end
                local modeChanged = resourcesShown ~= shown
                resourcesShown, appliedDelta = shown, delta
                resizeFullBorder(delta)
                resizeHealthBorder(delta)
                if name then
                    local width = math.max(1, nameWidth + delta)
                    if not T.NearlyEqual(name:GetWidth(), width) then name:SetWidth(width) end
                end
                if not T.NearlyEqual(mana:GetWidth(), manaWidth + delta) then mana:SetWidth(manaWidth + delta) end
                -- Share the player's prepared fill beneath the existing metal
                -- edge; compensate label insets to retain their old positions.
                local extension = shown and 0 or 12
                local width = healthWidth + delta + extension + 2 * healthUnderlap
                local height = (shown and 11 or 17.5) + 2 * healthUnderlap
                if not T.NearlyEqual(health:GetWidth(), width) then health:SetWidth(width) end
                if not T.NearlyEqual(health:GetHeight(), height) then health:SetHeight(height) end
                if modeChanged then
                    health:SetPoint("CENTER", frame, "CENTER", 15 - extension / 2, shown and 10 or 6.75)
                end
                values.healthLabels.SetInsets(extension + healthUnderlap, healthUnderlap, extension / 2)
                for _, strip in ipairs(fullBorder) do
                    if shown then
                        if not strip:IsShown() then strip:Show() end
                    elseif strip:IsShown() then
                        strip:Hide()
                    end
                end
                for _, strip in ipairs(healthOnlyBorder) do
                    if shown then
                        if strip:IsShown() then strip:Hide() end
                    elseif not strip:IsShown() then
                        strip:Show()
                    end
                end
            end
            DFRL.display.Listen(UpdateResources)
            values.resize = UpdateResources
            UpdateResources()
            if _G[prefix .. "HealthBarText"] then _G[prefix .. "HealthBarText"]:SetAlpha(0) end
            HookScript(health, "OnValueChanged", function() UpdateValues(values) end)
        end
    end

    if partyRoot then
        if PartyMemberBackground then PartyMemberBackground:SetParent(partyRoot) end
        local function ResizeParty()
            for _, values in ipairs(units) do
                if values.resize then values.resize() end
            end
        end
        HookScript(partyRoot, "OnShow", ResizeParty)
        DFRL.layout.Register("partyFrames", partyRoot, function()
            partyRoot:ClearAllPoints()
            partyRoot:SetPoint("LEFT", UIParent, "LEFT", 10, 220)
        end, {
            region = partyRegion,
            resizeToRegion = true,
            edgeWidth = true,
            edgeRegion = partyRegion,
            minWidth = partyRoot.minWidth,
            maxWidth = partyRoot.defaultWidth + 800,
            onEdit = function(active)
                if active then ResizeParty() end
            end,
            onResize = ResizeParty,
        })
    end

    local function UpdateAll()
        for _, values in ipairs(units) do
            UpdateValues(values)
        end
    end
    for _, values in ipairs(units) do
        local record = values
        HookScript(record.frame, "OnShow", function() UpdateValues(record) end)
    end
    local unitEvents = {
        UNIT_HEALTH = true,
        UNIT_MAXHEALTH = true,
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
    frame:RegisterEvent("UNIT_MAXHEALTH")
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
