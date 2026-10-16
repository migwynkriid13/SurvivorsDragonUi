-- Combo-point atlas and coordinates from Karl-HeinzSchneider/WoW-DragonflightUI,
-- commit b8b35451d4621a8097e887385f72ec03e17765f1, Textures/Unitframe/classoverlaycombopoints.blp
-- and Modules/Unitframe/Target.mixin.lua. The underlying WoW artwork is Blizzard's.
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
    local POINTS, UNITS_PER_POINT = 5, 20
    local SLOT_WIDTH, ROW_HEIGHT = 24, 32
    local PHASES = { playing = true, choosing = true, paused = true }
    local styles = {
        WARLOCK = {
            power = 0,
            texture = path .. "SoulShards.tga",
            empty = { 1 / 256, 18 / 256, 38 / 64, 60 / 64 },
            full = { 23 / 256, 40 / 256, 25 / 64, 47 / 64 },
            width = 17,
            height = 22,
        },
        ROGUE = {
            power = 3,
            texture = path .. "ComboPoints.tga",
            empty = { 29 / 128, 49 / 128, 66 / 128, 86 / 128 },
            full = { 29 / 128, 49 / 128, 44 / 128, 64 / 128 },
            width = 20,
            height = 20,
        },
    }

    local row = CreateFrame("Frame", "SurvivorsDragonUiClassResources", UIParent)
    row:SetWidth(POINTS * SLOT_WIDTH)
    row:SetHeight(ROW_HEIGHT)
    row:SetFrameStrata("MEDIUM")
    row:SetFrameLevel(PlayerFrame:GetFrameLevel() + 5)
    row:EnableMouse(false)
    row:Hide()

    local function PlaceDefault()
        row:ClearAllPoints()
        -- Match the player's default health area. The layout controller then
        -- resolves this to an independent position, like the buffs and XP groups.
        row:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 105, -72)
    end
    PlaceDefault()

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

    local inWorld, displayedStyle, displayedCount = true, nil, nil
    local function IsNumber(value) return type(value) == "number" and value >= 0 and value - value == 0 end
    local function ReadResource()
        if not inWorld or type(AZS_GetPhase) ~= "function" or not PHASES[AZS_GetPhase()] then return end
        if not UnitExists("player") then return end
        -- Native class is current even if the once-per-run AZSZONE packet has
        -- not replayed after reload. No retained AZS tables are consulted.
        local _, class = UnitClass("player")
        local style = styles[class]
        if not style or UnitPowerType("player") ~= style.power then return end
        local value, maximum = UnitMana("player"), UnitManaMax("player")
        if not IsNumber(value) or not IsNumber(maximum) or maximum <= 0 then return end
        -- Survivors encodes each shard/point as 20 active-power units. This is
        -- an absolute conversion, not a percentage of maximum mana or energy.
        -- GetComboPoints() is target-dependent and does not read this mechanic.
        local count = math.floor(math.min(value, maximum, POINTS * UNITS_PER_POINT) / UNITS_PER_POINT)
        return style, count
    end

    local function Clear()
        row:Hide()
        displayedStyle, displayedCount = nil, nil
        for _, point in ipairs(points) do
            point.full:Hide()
        end
    end

    local function Update()
        local style, count = ReadResource()
        if not style then
            if displayedStyle then Clear() end
            return
        end
        if style ~= displayedStyle then
            for _, point in ipairs(points) do
                point.empty:SetTexture(style.texture)
                point.empty:SetTexCoord(unpack(style.empty))
                point.full:SetTexture(style.texture)
                point.full:SetTexCoord(unpack(style.full))
                for _, texture in ipairs({ point.empty, point.full }) do
                    texture:SetWidth(style.width)
                    texture:SetHeight(style.height)
                end
            end
        end
        if style ~= displayedStyle or count ~= displayedCount then
            for i, point in ipairs(points) do
                if i <= count then
                    point.full:Show()
                else
                    point.full:Hide()
                end
            end
        end
        displayedStyle, displayedCount = style, count
        row:Show()
    end

    -- A separate, always-shown controller can recover while the row is hidden.
    local controller = CreateFrame("Frame")
    local elapsed = 0
    controller:SetScript("OnUpdate", function()
        elapsed = elapsed + (arg1 or 0)
        if elapsed < 0.1 then return end
        elapsed = 0
        Update()
    end)
    for _, name in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_LOGOUT",
        "UNIT_MANA",
        "UNIT_ENERGY",
        "UNIT_MAXMANA",
        "UNIT_MAXENERGY",
        "UNIT_DISPLAYPOWER",
        "CHAT_MSG_ADDON",
    }) do
        controller:RegisterEvent(name)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            Update()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            Clear()
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 == "AZSZONE" or arg1 == "AZSRUN" then Update() end
        elseif arg1 == "player" then
            Update()
        end
    end)

    DFRL.layout.Register("classResources", row, PlaceDefault)
    Update()
end)
