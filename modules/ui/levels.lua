-- A movable replacement for the game's stored-level button, using its own APIs.
DFRL:NewMod("StoredLevels", 5, function()
    local HEIGHT, INTERVAL = 72, 0.1
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
    button:SetHeight(HEIGHT)
    button:SetFrameStrata("HIGH")
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.12, 0.015, 0.015, 0.96)
    button:SetBackdropBorderColor(0.73, 0.58, 0.34, 1)
    button:Hide()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    icon:SetWidth(48)
    icon:SetHeight(48)
    icon:SetPoint("LEFT", button, "LEFT", 12, 0)
    local title = button:CreateFontString(nil, "OVERLAY")
    DFRL.locale.Bind(title)
    T.SetFont(title, 22, "OUTLINE")
    title:SetTextColor(1, 0.91, 0.69)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    title:SetJustifyH("LEFT")
    title:SetPoint("BOTTOMLEFT", button, "LEFT", 78, -25)
    title:SetText("Level Up!")
    local width = math.max(220, DFRL.locale.Width(title, "Level Up!") + 96)
    button:SetWidth(width)
    title:SetWidth(width - 90)
    title:SetHeight(30)
    local level = button:CreateFontString(nil, "OVERLAY")
    T.SetFont(level, 12, "OUTLINE")
    level:SetWidth(width - 90)
    level:SetHeight(18)
    level:SetJustifyH("LEFT")
    level:SetTextColor(0.87, 0.73, 0.41)
    level:SetPoint("TOPLEFT", button, "TOPLEFT", 78, -12)

    local badge = CreateFrame("Frame", nil, button)
    badge:SetWidth(26)
    badge:SetHeight(24)
    badge:SetPoint("TOPRIGHT", button, "TOPLEFT", 72, -6)
    badge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    badge:SetBackdropColor(0.97, 0.82, 0.42, 1)
    badge:SetBackdropBorderColor(0.73, 0.58, 0.34, 1)
    local countText = badge:CreateFontString(nil, "OVERLAY")
    T.SetFont(countText, 14, "")
    countText:SetHeight(20)
    countText:SetTextColor(0.1, 0.05, 0)
    countText:SetPoint("CENTER", badge, "CENTER", 0, 0)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    highlight:SetVertexColor(0.97, 0.82, 0.42, 0.12)

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
        local badgeWidth = math.max(26, math.ceil(countText:GetStringWidth() or 0) + 12)
        badge:SetWidth(badgeWidth)
        countText:SetWidth(badgeWidth - 8)
        level:SetText(DFRL.locale.Native("LEVEL {n}", { n = currentLevel }))
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
            button:EnableMouse(not active)
        end,
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
