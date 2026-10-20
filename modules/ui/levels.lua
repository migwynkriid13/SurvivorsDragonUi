-- A movable replacement for the game's stored-level button, using its own APIs.
--[[
The selected Framed Icon + Text design uses IconFrameGold.tga from
NeticSoul/DragonUI commit 6d9cc95eedd1de78fab3b965683df13421e21604,
DragonUI/Textures/Collections/IconFrameGold.tga, full 128-by-128 canvas.
Its source notices credit the DragonflightUI Spellbook-Parts artwork.
Underlying World of Warcraft artwork remains copyright Blizzard Entertainment;
the software license below does not relicense Blizzard artwork.
CountBadge.tga is original geometric artwork. No source-addon Lua is imported.
Full provenance and preparation: third_party/LevelUp-ARTWORK.md.

Applicable source notices:
MIT License
Copyright (c) 2026 NeticSoul and DragonUI contributors
Copyright (c) 2022 Karl-HeinzSchneider

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
DFRL:NewMod("StoredLevels", 5, function()
    local HEIGHT, INTERVAL, VISUAL_SCALE = 72, 0.1, 0.7
    local texturePath = DFRL:GetInfoOrCons("tex") .. "levelup\\"
    local CLASS_ICONS = {
        WARRIOR = { 0, 0.25, 0, 0.25 },
        MAGE = { 0.25, 0.5, 0, 0.25 },
        ROGUE = { 0.5, 0.75, 0, 0.25 },
        DRUID = { 0.75, 1, 0, 0.25 },
        HUNTER = { 0, 0.25, 0.25, 0.5 },
        SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
        PRIEST = { 0.5, 0.75, 0.25, 0.5 },
        WARLOCK = { 0.75, 1, 0.25, 0.5 },
        PALADIN = { 0, 0.25, 0.5, 0.75 },
    }
    local PHASES = { playing = true, choosing = true, paused = true }
    local inWorld, editing, reloading, elapsed = true, false, false, 0
    local nativePreference, retiredRun
    local button = CreateFrame("Button", "SurvivorsDragonUiStoredLevels", UIParent)
    button:SetHeight(HEIGHT * VISUAL_SCALE)
    button:SetFrameStrata("HIGH")
    button:RegisterForClicks("LeftButtonUp")
    button:Hide()
    -- Keep saved layout scale relative to the smaller design, so existing
    -- 100% records also use the new default without rewriting saved geometry.
    local visual = CreateFrame("Frame", nil, button)
    visual:SetHeight(HEIGHT)
    visual:SetScale(VISUAL_SCALE)
    visual:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    visual:EnableMouse(false)

    local icon = visual:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    icon:SetWidth(HEIGHT * 55 / 103)
    icon:SetHeight(HEIGHT * 55 / 103)
    icon:SetPoint("TOPLEFT", visual, "TOPLEFT", HEIGHT * 21 / 103, -HEIGHT * 17 / 103)
    local bezel = visual:CreateTexture(nil, "ARTWORK")
    bezel:SetTexture(texturePath .. "IconFrameGold.tga")
    bezel:SetWidth(HEIGHT)
    bezel:SetHeight(HEIGHT)
    bezel:SetPoint("TOPLEFT", visual, "TOPLEFT", 0, 0)
    local title = visual:CreateFontString(nil, "OVERLAY")
    DFRL.locale.Bind(title)
    T.SetFont(title, 22, "OUTLINE")
    title:SetTextColor(1, 0.91, 0.69)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    title:SetJustifyH("CENTER")
    title:SetPoint("TOPLEFT", visual, "TOPLEFT", 82, -12)
    title:SetText("Level Up!")
    local width = math.max(220, DFRL.locale.Width(title, "Level Up!") + 96)
    visual:SetWidth(width)
    button:SetWidth(width * VISUAL_SCALE)
    title:SetWidth(width - 90)
    title:SetHeight(30)
    local level = visual:CreateFontString(nil, "OVERLAY")
    T.SetFont(level, 12, "OUTLINE")
    level:SetWidth(width - 90)
    level:SetHeight(18)
    level:SetJustifyH("CENTER")
    level:SetTextColor(0.87, 0.73, 0.41)
    level:SetPoint("TOP", title, "BOTTOM", 0, -2)

    local function AlignCaptions()
        -- Natural glyph width keeps the level centered under the visible title,
        -- independently of the stable edit bounds measured across languages.
        local measured = title:GetStringWidth()
        if type(measured) ~= "number" or measured <= 0 or measured - measured ~= 0 then return end
        local titleWidth = math.ceil(measured) + 4
        local levelWidth = math.max(titleWidth, math.ceil(level:GetStringWidth() or 0) + 4)
        if not T.NearlyEqual(title:GetWidth(), titleWidth) then title:SetWidth(titleWidth) end
        if not T.NearlyEqual(level:GetWidth(), levelWidth) then level:SetWidth(levelWidth) end
    end

    local badge = CreateFrame("Frame", nil, visual)
    badge:SetWidth(20)
    badge:SetHeight(20)
    badge:SetPoint("TOPRIGHT", visual, "TOPLEFT", 68, 0)
    local badgeArt = badge:CreateTexture(nil, "BACKGROUND")
    badgeArt:SetTexture(texturePath .. "CountBadge.tga")
    badgeArt:SetAllPoints(badge)
    local countText = badge:CreateFontString(nil, "OVERLAY")
    T.SetFont(countText, 12, "")
    countText:SetHeight(18)
    countText:SetTextColor(0.1, 0.05, 0)
    countText:SetPoint("CENTER", badge, "CENTER", 0, 0)

    local highlight = visual:CreateTexture(nil, "OVERLAY")
    highlight:SetTexture(texturePath .. "IconFrameGold.tga")
    highlight:SetAllPoints(bezel)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.35)
    highlight:Hide()
    button:SetScript("OnEnter", function()
        if not editing then highlight:Show() end
    end)
    button:SetScript("OnLeave", function() highlight:Hide() end)

    local function PositiveInteger(value)
        return type(value) == "number" and value > 0 and value - value == 0 and math.floor(value) == value
    end

    local function ReadState()
        if
            not inWorld
            or reloading
            or type(AZS_GetPhase) ~= "function"
            or type(AZS_GetStoredLevels) ~= "function"
            or type(AZS_OpenStoredLevels) ~= "function"
        then
            return
        end
        local ok, phase = pcall(AZS_GetPhase)
        if not ok or not PHASES[phase] then return end
        local state = AZS_RUN
        if
            type(state) ~= "table"
            or state == retiredRun
            or type(AZS_RUN_UPDATED) ~= "number"
            or not PositiveInteger(state.lvl)
        then
            return
        end
        local received, count = pcall(AZS_GetStoredLevels)
        if received and PositiveInteger(count) then return count, state.lvl end
    end

    local function RestoreNative()
        if nativePreference == nil or type(AZS_SetHudShown) ~= "function" then return end
        if pcall(AZS_SetHudShown, "levels", nativePreference) then nativePreference = nil end
    end

    local function HideNative()
        if type(AZS_IsHudShown) ~= "function" or type(AZS_SetHudShown) ~= "function" then return false end
        local ok, shown = pcall(AZS_IsHudShown, "levels")
        -- An unknown HUD part returns nil on older clients. Never claim takeover.
        if not ok or type(shown) ~= "boolean" then return false end
        if nativePreference == nil then nativePreference = shown end
        if shown and not pcall(AZS_SetHudShown, "levels", false) then return false end
        local checked, current = pcall(AZS_IsHudShown, "levels")
        return checked and current == false
    end

    local function Clear()
        button:Hide()
        highlight:Hide()
        countText:SetText("")
        level:SetText("")
        icon:Hide()
        RestoreNative()
    end

    local function Update()
        local count, currentLevel = ReadState()
        if not count then
            Clear()
            return
        end
        local _, class = UnitClass("player")
        local crop = CLASS_ICONS[class]
        if crop then
            icon:SetTexCoord(unpack(crop))
            icon:Show()
        else
            icon:Hide()
        end
        countText:SetText(tostring(count))
        local badgeWidth = math.max(20, math.ceil(countText:GetStringWidth() or 0) + 10)
        badge:SetWidth(badgeWidth)
        countText:SetWidth(badgeWidth - 8)
        level:SetText(DFRL.locale.Native("LEVEL {n}", { n = currentLevel }))
        AlignCaptions()
        button:Show()
        -- Construct and populate the replacement before suppressing native UI.
        -- Layout's Hide frame choice intentionally suppresses both versions.
        if not HideNative() then Clear() end
    end

    button:SetScript("OnClick", function()
        if editing or not button:IsVisible() or not ReadState() then return end
        -- The game owns the offer queue, pause rules and spending semantics.
        AZS_OpenStoredLevels()
    end)
    DFRL.layout.Register("levelUp", button, function()
        button:ClearAllPoints()
        button:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    end, {
        onEdit = function(active)
            editing = active
            highlight:Hide()
            button:EnableMouse(not active)
        end,
        onResize = AlignCaptions,
    })
    DFRL.locale.Listen(Update)

    local function Stop()
        inWorld = false
        retiredRun = AZS_RUN
        Clear()
    end

    local controller = CreateFrame("Frame", nil, UIParent)
    controller:RegisterEvent("CHAT_MSG_ADDON")
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            Stop()
        elseif event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            elapsed = INTERVAL
        elseif event == "CHAT_MSG_ADDON" and arg1 == "AZSRUN" then
            -- Read on the next frame, after the native parser replaces AZS_RUN.
            elapsed = INTERVAL
        end
    end)
    controller:SetScript("OnUpdate", function()
        elapsed = elapsed + (tonumber(arg1) or 0)
        if elapsed < INTERVAL then return end
        elapsed = 0
        Update()
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            reloading = true
            Stop()
            return reloadUI()
        end
    end
    Update()
end)
