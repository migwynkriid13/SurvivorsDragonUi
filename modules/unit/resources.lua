-- Combo-point atlas and coordinates: source commit b8b35451d4621a8097e887385f72ec03e17765f1,
-- Textures/Unitframe/classoverlaycombopoints.blp and Modules/Unitframe/Target.mixin.lua.
-- Source provenance: docs/CLASS-RESOURCES.md. The underlying WoW artwork is Blizzard's.
-- Soul-shard artwork is also Blizzard's, obtained from Gethe/wow-ui-textures,
-- commit d23deaf8f44a7d280dc974a5c9d5321c013db59b, PLAYERFRAME/ClassOverlayWarlockShards725.PNG.
-- Shard UVs: Ketho/BlizzardInterfaceResources, commit 36dd01db2d8fa5086dffda5cbfb3d55f4a70e526,
-- Resources/AtlasInfo.lua, Warlock-EmptyShard / Warlock-ReadyShard.
-- Only texture pixels/coordinates are reused; no later-client class frames are loaded.
--
-- MIT License
-- Copyright (c) 2022 Karl-HeinzSchneider
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

DFRL:NewMod("Class resources", 2, function()
    if not PlayerFrame then return end

    local path = DFRL:GetInfoOrCons("tex") .. "resources\\"
    local POINTS = 5
    local SLOT_WIDTH, ROW_HEIGHT = 24, 32
    local styles = {
        WARLOCK = {
            color = { 0.55, 0.25, 1 },
            texture = path .. "SoulShards.blp",
            empty = { 1 / 256, 18 / 256, 38 / 64, 60 / 64 },
            full = { 23 / 256, 40 / 256, 25 / 64, 47 / 64 },
            width = 17,
            height = 22,
        },
        ROGUE = {
            color = { 1, 0, 0 },
            texture = path .. "ComboPoints.blp",
            empty = { 29 / 128, 49 / 128, 66 / 128, 86 / 128 },
            full = { 29 / 128, 49 / 128, 44 / 128, 64 / 128 },
            width = 20,
            height = 20,
        },
    }
    local procs = {
        seal_fate = styles.ROGUE,
        soul_fire = styles.WARLOCK,
        lightwell = { color = { 1, 0.82, 0 } },
    }

    local row = CreateFrame("Frame", "SurvivorsDragonUiClassResources", PlayerFrame)
    row:SetWidth(POINTS * SLOT_WIDTH)
    row:SetHeight(ROW_HEIGHT)
    row:SetFrameStrata("MEDIUM")
    row:SetFrameLevel(PlayerFrame:GetFrameLevel() + 5)
    row:EnableMouse(false)
    row:Hide()

    -- Secondary meters belong to the player frame too: its confirmed position
    -- and scale move the health, primary power and point artwork together.
    row:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 105, -68)

    local points = {}
    for i = 1, POINTS do
        local point = {}
        point.empty = row:CreateTexture(nil, "BACKGROUND")
        point.full = row:CreateTexture(nil, "ARTWORK")
        for _, texture in ipairs({ point.empty, point.full }) do
            texture:SetPoint("CENTER", row, "LEFT", (i - 0.5) * SLOT_WIDTH, 0)
        end
        point.full:Hide()
        points[i] = point
    end

    local meter = CreateFrame("StatusBar", nil, row)
    meter:SetWidth(row:GetWidth())
    meter:SetHeight(12)
    meter:SetPoint("CENTER", row, "CENTER", 0, 0)
    meter:EnableMouse(false)
    meter:SetStatusBarTexture(
        DFRL:GetInfoOrCons("tex") .. "unitframes\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Status.blp"
    )
    meter:SetMinMaxValues(0, 1)
    meter:SetValue(0)
    local background = meter:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(meter)
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0, 0, 0, 0.6)
    local meterText = meter:CreateFontString(nil, "OVERLAY")
    T.SetFont(meterText, 10, "OUTLINE")
    meterText:SetTextColor(1, 1, 1)
    meterText:SetShadowColor(0, 0, 0, 1)
    meterText:SetShadowOffset(1, -1)
    meterText:SetPoint("CENTER", meter, "CENTER", 0, 0)
    meter:Hide()

    local inWorld, retiredRun = true, nil
    local displayedStyle, displayedValue, displayedMaximum, bindingPending
    local function IsNumber(value) return type(value) == "number" and value >= 0 and value - value == 0 end
    local function ReadPrimary()
        -- Native unit getters stay current across reload and power-type changes,
        -- without retaining run packets or assuming a class-specific maximum.
        local power = UnitPowerType("player")
        local value, maximum = UnitMana("player"), UnitManaMax("player")
        if not IsNumber(power) or not IsNumber(value) or not IsNumber(maximum) or maximum <= 0 then return end
        return value, maximum, power
    end

    local function ReadSecondary(paint)
        if type(_G.AZS_GetPhase) ~= "function" or not DFRL.navigation then return end
        local ok, phase = pcall(_G.AZS_GetPhase)
        if not ok then return end
        if not DFRL.navigation.IsRunPhase(phase) then
            retiredRun = _G.AZS_RUN
            return
        end
        if not paint then return end
        local state = _G.AZS_RUN
        if type(state) ~= "table" or state == retiredRun or not IsNumber(_G.AZS_RUN_UPDATED) then return end
        -- The native proc identifies the meter and publishes its own range.
        -- Empty, unknown or missing fields never fall back to active power.
        local style = procs[state.proc]
        if not style or not IsNumber(state.pv) or not IsNumber(state.pm) or state.pm <= 0 then return end
        return style, math.min(state.pv, state.pm), state.pm
    end

    local function BindPoint(texture, style, crop)
        local loaded = texture:SetTexture(style.texture)
        texture:SetTexCoord(unpack(crop))
        texture:SetWidth(style.width)
        texture:SetHeight(style.height)
        if loaded == false then return false end
        local assigned = texture:GetTexture()
        local stem = string.gsub(style.texture, "%.[^%.]*$", "")
        return loaded == true or loaded == 1 or assigned == style.texture or assigned == stem
    end

    local function HidePoints()
        for _, point in ipairs(points) do
            if point.empty:IsShown() then point.empty:Hide() end
            if point.full:IsShown() then point.full:Hide() end
        end
    end

    local function Clear()
        row:Hide()
        displayedStyle, displayedValue, displayedMaximum = nil, nil, nil
        bindingPending = nil
        HidePoints()
        meter:Hide()
        meterText:SetText("")
        meter:SetValue(0)
        meter:SetMinMaxValues(0, 1)
    end

    local function Update()
        -- Phase retirement remains live while the player's presentation is hidden.
        local style, current, total
        if inWorld then
            style, current, total = ReadSecondary(PlayerFrame:IsVisible() and DFRL.display.Get("classResources"))
        end
        if not PlayerFrame:IsVisible() then return end
        local enabled = inWorld and UnitExists("player") and DFRL.display.Get("classResources")
        local value, maximum, power
        if enabled then
            value, maximum, power = ReadPrimary()
        end
        if DFRL.playerResources then DFRL.playerResources.SetPrimary(value, maximum, power) end
        if not enabled or not style then
            if displayedStyle then Clear() end
            return
        end
        if
            not bindingPending
            and style == displayedStyle
            and current == displayedValue
            and total == displayedMaximum
        then
            return
        end
        bindingPending = nil
        if style.texture and total <= POINTS and total == math.floor(total) then
            if meter:IsShown() then meter:Hide() end
            T.SetTextIfChanged(meterText, "")
            for i, point in ipairs(points) do
                if point.style ~= style then
                    point.style = nil
                    if point.emptyStyle ~= style and BindPoint(point.empty, style, style.empty) then
                        point.emptyStyle = style
                    end
                    if point.fullStyle ~= style and BindPoint(point.full, style, style.full) then
                        point.fullStyle = style
                    end
                    if point.emptyStyle == style and point.fullStyle == style then point.style = style end
                    if not point.style then bindingPending = true end
                end
                if i <= total then
                    if not point.empty:IsShown() then point.empty:Show() end
                else
                    if point.empty:IsShown() then point.empty:Hide() end
                end
                if i <= current and i <= total then
                    if not point.full:IsShown() then point.full:Show() end
                else
                    if point.full:IsShown() then point.full:Hide() end
                end
            end
        else
            -- Continuous procs, or point ranges beyond the existing artwork,
            -- retain their exact native range rather than assuming five points.
            HidePoints()
            if meter.style ~= style then
                meter:SetStatusBarColor(unpack(style.color))
                meter.style = style
            end
            local minimum, maximum = meter:GetMinMaxValues()
            if minimum ~= 0 or maximum ~= total then meter:SetMinMaxValues(0, total) end
            if meter:GetValue() ~= current then meter:SetValue(current) end
            T.SetTextIfChanged(meterText, tostring(current) .. " / " .. tostring(total))
            if not meter:IsShown() then meter:Show() end
        end
        displayedStyle, displayedValue, displayedMaximum = style, current, total
        if not row:IsShown() then row:Show() end
    end

    -- A separate, always-shown controller can recover while the row is hidden.
    local controller = CreateFrame("Frame")
    local elapsed = 0
    local function Tick()
        elapsed = elapsed + (arg1 or 0)
        if elapsed < 0.1 then return end
        elapsed = 0
        Update()
    end
    controller:SetScript("OnUpdate", Tick)
    for _, name in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_LOGOUT",
        "CHAT_MSG_ADDON",
        "UNIT_MANA",
        "UNIT_RAGE",
        "UNIT_FOCUS",
        "UNIT_ENERGY",
        "UNIT_MAXMANA",
        "UNIT_MAXRAGE",
        "UNIT_MAXFOCUS",
        "UNIT_MAXENERGY",
        "UNIT_DISPLAYPOWER",
    }) do
        controller:RegisterEvent(name)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            elapsed = 0
            controller:SetScript("OnUpdate", Tick)
            Update()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            retiredRun = _G.AZS_RUN
            if DFRL.playerResources then DFRL.playerResources.SetPrimary() end
            Clear()
        elseif event == "CHAT_MSG_ADDON" then
            -- Read after the native parser has replaced the run snapshot.
            if arg1 == "AZSRUN" then elapsed = 0.1 end
        elseif arg1 == "player" then
            Update()
        end
    end)

    DFRL.display.Listen(Update)
    HookScript(PlayerFrame, "OnShow", Update)
    Update()
end)
