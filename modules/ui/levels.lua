-- A movable replacement for the game's stored-level button, using its own APIs.
--[[
The selected Framed Icon + Text design uses IconFrameGold.tga from
NeticSoul/DragonUI commit 6d9cc95eedd1de78fab3b965683df13421e21604,
DragonUI/Textures/Collections/IconFrameGold.tga. The clean upper-right border
is mirrored into a plain gold rim; the decorative flourishes are omitted.
Its source notices credit the DragonflightUI Spellbook-Parts artwork.
Underlying World of Warcraft artwork remains copyright Blizzard Entertainment;
the software license below does not relicense Blizzard artwork.
CountBadge.tga, Backdrop.tga and Glow.tga are original geometric artwork.
No source-addon Lua is imported.
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
    local HEIGHT, INTERVAL, VISUAL_SCALE, PULSE_PERIOD = 72, 0.1, 0.7, 1.8
    local TEXT_LEFT, PANEL_PADDING, ICON_OFFSET_X, ICON_OFFSET_Y = 60, 10, -12, 4
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
    local panel = CreateFrame("Frame", nil, visual)
    panel:SetHeight(HEIGHT)
    panel:SetPoint("CENTER", visual, "CENTER", 0, 0)
    panel:EnableMouse(false)
    local backdrop = panel:CreateTexture(nil, "BACKGROUND")
    backdrop:SetTexture(texturePath .. "Backdrop.blp")
    backdrop:SetAllPoints(panel)
    local glow = panel:CreateTexture(nil, "BORDER")
    glow:SetTexture(texturePath .. "Glow.blp")
    glow:SetAllPoints(panel)
    glow:SetBlendMode("ADD")
    glow:Hide()
    local content = CreateFrame("Frame", nil, panel)
    content:SetHeight(HEIGHT)
    content:SetPoint("CENTER", panel, "CENTER", 0, 0)
    content:EnableMouse(false)

    local icon = content:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    icon:SetWidth(HEIGHT * 55 / 103)
    icon:SetHeight(HEIGHT * 55 / 103)
    icon:SetPoint("TOPLEFT", content, "TOPLEFT", HEIGHT * 21 / 103 + ICON_OFFSET_X, -HEIGHT * 17 / 103 - ICON_OFFSET_Y)
    local bezel = content:CreateTexture(nil, "ARTWORK")
    bezel:SetTexture(texturePath .. "IconFrameGold.blp")
    bezel:SetWidth(HEIGHT)
    bezel:SetHeight(HEIGHT)
    bezel:SetPoint("TOPLEFT", content, "TOPLEFT", ICON_OFFSET_X, -ICON_OFFSET_Y)
    local title = content:CreateFontString(nil, "OVERLAY")
    DFRL.locale.Bind(title)
    T.SetFont(title, 22, "OUTLINE")
    title:SetTextColor(1, 0.91, 0.69)
    title:SetShadowColor(0, 0, 0, 0.9)
    title:SetShadowOffset(1, -1)
    title:SetJustifyH("CENTER")
    title:SetPoint("LEFT", content, "LEFT", TEXT_LEFT, 0)
    title:SetText("LEVEL UP")
    local width = math.max(220, DFRL.locale.Width(title, "LEVEL UP") + 96)
    visual:SetWidth(width)
    button:SetWidth(width * VISUAL_SCALE)
    panel:SetWidth(width)
    content:SetWidth(width - PANEL_PADDING * 2)
    title:SetWidth(width - PANEL_PADDING * 2 - TEXT_LEFT)
    title:SetHeight(30)

    local titleMetrics, badgeMetrics = {}, {}
    local function TextWidth(label, metrics, force)
        local text = label:GetText()
        local face, size, flags = label:GetFont()
        local scale = label:GetParent():GetEffectiveScale()
        if
            not force
            and metrics.text == text
            and metrics.face == face
            and metrics.size == size
            and metrics.flags == flags
            and metrics.scale == scale
            and metrics.width
        then
            return metrics.width, false
        end
        local measured = label:GetStringWidth()
        if type(measured) ~= "number" or measured <= 0 or measured - measured ~= 0 then return end
        metrics.text, metrics.face, metrics.size, metrics.flags = text, face, size, flags
        metrics.scale, metrics.width = scale, measured
        return measured, true
    end
    local function AlignContent(force)
        -- Keep the active panel and its edit region centered inside the stable
        -- multilingual layout owner, without moving confirmed coordinates.
        local measured, changed = TextWidth(title, titleMetrics, force)
        if not measured or not changed then return end
        local textWidth = math.ceil(measured) + 4
        local contentWidth = TEXT_LEFT + textWidth
        local panelWidth = contentWidth + PANEL_PADDING * 2
        if not T.NearlyEqual(title:GetWidth(), textWidth) then title:SetWidth(textWidth) end
        if not T.NearlyEqual(content:GetWidth(), contentWidth) then content:SetWidth(contentWidth) end
        if not T.NearlyEqual(panel:GetWidth(), panelWidth) then panel:SetWidth(panelWidth) end
    end

    local badge = CreateFrame("Frame", nil, content)
    badge:SetWidth(20)
    badge:SetHeight(20)
    badge:SetPoint("TOPRIGHT", content, "TOPLEFT", 68 + ICON_OFFSET_X, -8)
    local badgeArt = badge:CreateTexture(nil, "BACKGROUND")
    badgeArt:SetTexture(texturePath .. "CountBadge.blp")
    badgeArt:SetAllPoints(badge)
    local countText = badge:CreateFontString(nil, "OVERLAY")
    T.SetFont(countText, 12, "")
    countText:SetHeight(18)
    countText:SetTextColor(0.1, 0.05, 0)
    countText:SetPoint("CENTER", badge, "CENTER", 0, 0)

    local highlight = content:CreateTexture(nil, "OVERLAY")
    highlight:SetTexture(texturePath .. "IconFrameGold.blp")
    highlight:SetAllPoints(bezel)
    highlight:SetBlendMode("ADD")
    highlight:Hide()
    local pulseElapsed, hovered = 0, false
    local performanceMode = DFRL.display.Get("performanceMode")
    local function AnimatePulse()
        if not button:IsVisible() then return end
        pulseElapsed = pulseElapsed + math.min(tonumber(arg1) or 0, 0.1)
        if pulseElapsed >= PULSE_PERIOD then pulseElapsed = pulseElapsed - PULSE_PERIOD end
        local pulse = 0.5 - 0.5 * math.cos(pulseElapsed * 2 * math.pi / PULSE_PERIOD)
        glow:SetAlpha(0.25 + 0.65 * pulse)
        highlight:SetAlpha((hovered and 0.3 or 0.1) + 0.4 * pulse)
    end
    local function RefreshEffects()
        pulseElapsed = 0
        if performanceMode or not button:IsVisible() then
            button:SetScript("OnUpdate", nil)
            if glow:IsShown() then glow:Hide() end
            if highlight:IsShown() then highlight:Hide() end
            return
        end
        glow:SetAlpha(0.25)
        highlight:SetAlpha(0.1)
        glow:Show()
        highlight:Show()
        button:SetScript("OnUpdate", AnimatePulse)
    end
    button:SetScript("OnEnter", function()
        if not editing then hovered = true end
    end)
    button:SetScript("OnLeave", function() hovered = false end)
    button:SetScript("OnShow", function()
        elapsed = INTERVAL
        RefreshEffects()
    end)
    button:SetScript("OnHide", function()
        pulseElapsed, hovered = 0, false
        button:SetScript("OnUpdate", nil)
        glow:Hide()
        highlight:Hide()
    end)
    DFRL.display.Listen(function()
        local enabled = DFRL.display.Get("performanceMode")
        if performanceMode == enabled then return end
        performanceMode = enabled
        RefreshEffects()
    end)

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
        if type(state) ~= "table" or state == retiredRun or type(AZS_RUN_UPDATED) ~= "number" then return end
        local received, count = pcall(AZS_GetStoredLevels)
        if received and PositiveInteger(count) then return count end
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
        if not shown then return true end
        if not pcall(AZS_SetHudShown, "levels", false) then return false end
        local checked, current = pcall(AZS_IsHudShown, "levels")
        return checked and current == false
    end

    local displayed, paintedCrop = false, nil
    local displayedCount, displayedText
    local function Clear()
        -- Clear the requested visibility even when Layout already hides it.
        if displayed or button:IsShown() then button:Hide() end
        displayed = false
        displayedCount, displayedText = nil, nil
        if highlight:IsShown() then highlight:Hide() end
        T.SetTextIfChanged(countText, "")
        if icon:IsShown() then icon:Hide() end
        RestoreNative()
    end

    local function Update()
        local count = ReadState()
        if not count then
            Clear()
            return
        end
        local paint = not DFRL.layout.IsHidden("levelUp") and UIParent:IsVisible()
        if paint then
            local _, class = UnitClass("player")
            local crop = CLASS_ICONS[class]
            if crop then
                if paintedCrop ~= crop then
                    icon:SetTexCoord(unpack(crop))
                    paintedCrop = crop
                end
                if not icon:IsShown() then icon:Show() end
            else
                if icon:IsShown() then icon:Hide() end
                paintedCrop = nil
            end
        end
        if paint or editing then
            if displayedCount ~= count then
                displayedText, displayedCount = tostring(count), count
            end
            T.SetTextIfChanged(countText, displayedText)
            local measured, changed = TextWidth(countText, badgeMetrics)
            if changed or not measured then
                local badgeWidth = math.max(20, math.ceil(measured or 0) + 10)
                if not T.NearlyEqual(badge:GetWidth(), badgeWidth) then badge:SetWidth(badgeWidth) end
                if not T.NearlyEqual(countText:GetWidth(), badgeWidth - 8) then countText:SetWidth(badgeWidth - 8) end
            end
            AlignContent()
        end
        if not displayed then button:Show() end
        displayed = true
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
        region = panel,
        resizeToRegion = true,
        labelAbove = true,
        onEdit = function(active)
            editing = active
            hovered = false
            button:EnableMouse(not active)
            AlignContent(true)
        end,
        onResize = function() AlignContent(true) end,
    })
    DFRL.locale.Listen(function()
        AlignContent(true)
        Update()
    end)

    local controller = CreateFrame("Frame", nil, UIParent)
    local function Tick()
        elapsed = elapsed + (tonumber(arg1) or 0)
        if elapsed < INTERVAL then return end
        elapsed = 0
        Update()
    end
    local function Stop()
        inWorld = false
        controller:SetScript("OnUpdate", nil)
        retiredRun = AZS_RUN
        Clear()
    end

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
            controller:SetScript("OnUpdate", Tick)
        elseif event == "CHAT_MSG_ADDON" and arg1 == "AZSRUN" then
            -- Read on the next frame, after the native parser replaces AZS_RUN.
            elapsed = INTERVAL
        end
    end)
    controller:SetScript("OnUpdate", Tick)
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
