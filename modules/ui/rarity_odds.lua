DFRL:NewMod("RarityOdds", 5, function()
    local INTERVAL, WIDTH, SCALE, GAP = 0.25, 240, 0.85, 8
    local HEADER_HEIGHT, ROW_HEIGHT, COLUMN_LEFT = WIDTH / 8, 25, 88
    local GOLD, WHITE = { 0.87, 0.74, 0.49 }, { 1, 0.96, 0.87 }
    local TIERS = {
        { "Rare", 0.28, 0.65, 1, 45 },
        { "Epic", 0.76, 0.49, 1, 45 },
        { "Legendary", 1, 0.64, 0.28, 56 },
    }
    -- Source modifiers for a base roll. A new amulet adds 0.50; the
    -- guardian reward path adds 0.25 to either jewelry category.
    local REWARDS = {
        { "Spells / cache jewelry", 0 },
        { "Guardian jewelry", 0.25 },
        { "New cache amulets", 0.5 },
        { "New guardian amulets", 0.75 },
    }
    local HEIGHT = HEADER_HEIGHT + 21 + table.getn(REWARDS) * ROW_HEIGHT
    local display, layout, locale = DFRL.display, DFRL.layout, DFRL.locale
    local enabled, overCards = display.Get("rarityOdds"), display.Get("rarityOddsOverCards")
    local meterRows = display.Get("meterRows")
    local inWorld, permitted, elapsed = true, not layout.IsHidden("rarityOdds"), INTERVAL
    local labels, language, registeredTop, shown
    local retiredRun, retiredStats, paintedStrength
    local lastRun, lastStats, lastZone, lastClock
    local pendingFonts = {}
    local controller = CreateFrame("Frame", nil, UIParent)
    local panel = CreateFrame("Frame", "SurvivorsDragonUiRarityOdds", UIParent)
    panel:Hide()
    panel:SetScale(SCALE)
    panel:SetWidth(WIDTH)
    panel:SetHeight(HEIGHT)
    panel:SetFrameStrata("MEDIUM")
    panel:EnableMouse(false)

    local function Number(value) return type(value) == "number" and value - value == 0 end
    layout.Register("rarityOdds", panel, function(frame)
        local height = UIParent:GetHeight()
        if not Number(height) or height < 0 then height = 0 end
        local guardian, guardianDefaults = _G.DFRL_GuardianTracker, DFRL.guardianTrackerDefaults
        local meter = DFRL.damageMeterDefaults
        local bottom = meter and (meter.header + meterRows * meter.row + meter.footer) * meter.scale or 0
        local right, top = 0, height
        if guardian and guardianDefaults then
            right = guardianDefaults.right
            top = top - guardianDefaults.top - guardian:GetHeight() * guardian:GetScale()
        end
        local half = HEIGHT * SCALE / 2
        if top - bottom < 2 * (half + GAP) then
            -- Short viewports put the panel alongside the default stack.
            local guardianLeft = guardian and right - guardian:GetWidth() * guardian:GetScale() or right
            local meterLeft = meter and -meter.width * meter.scale or 0
            right = math.min(guardianLeft, meterLeft) - GAP
        end
        local center = math.max(half, math.min(height - half, (top + bottom) / 2))
        frame:ClearAllPoints()
        frame:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", right / SCALE, center / SCALE)
    end, { labelAbove = true, refreshDefault = true })

    local function PlaceDefault()
        if not layout.IsPlaced("rarityOdds") then layout.Place("rarityOdds") end
    end
    DFRL.RefreshRarityOddsPlacement = function()
        if shown then PlaceDefault() end
    end
    local function Retire()
        if lastRun then
            retiredRun, retiredStats = lastRun, lastStats
        end
        lastRun, lastStats, lastZone, lastClock = nil, nil, nil, nil
    end

    local function Read()
        if type(AZS_GetPhase) ~= "function" then return end
        local ok, phase = pcall(AZS_GetPhase)
        if not ok then return end
        if phase ~= "playing" and phase ~= "paused" and phase ~= "choosing" then
            if phase == "ready" then Retire() end
            return
        end
        if
            phase == "choosing"
            and (not overCards or type(AZS_SetOnTopOfScreens) ~= "function" or type(AZS_IsOnTopOfScreens) ~= "function")
        then
            return
        end
        local run, stats, runStamp, zoneStamp = AZS_RUN, AZS_STATS, AZS_RUN_UPDATED, AZS_ZONE_UPDATED
        if type(run) ~= "table" or not Number(runStamp) or runStamp < 0 or not Number(run.t) then return end
        if lastRun and ((lastZone and Number(zoneStamp) and zoneStamp ~= lastZone) or run.t < lastClock) then
            Retire()
        end
        -- The installed AZS parser replaces the stats table and publishes no
        -- stats timestamp. A prior run's table cannot seed the next run.
        if
            runStamp == retiredRun
            or (Number(zoneStamp) and runStamp < zoneStamp)
            or type(stats) ~= "table"
            or stats == retiredStats
        then
            return
        end
        local level, luck = run.lvl, stats.luck
        if not Number(level) or level < 1 or level ~= math.floor(level) or not Number(luck) then return end
        local bonus = math.min(level, 30) / 100
        local strength = 1 + luck + bonus
        if strength <= 0 or not Number(100 * (strength + 0.75) ^ 4) then return end
        retiredRun, retiredStats = nil, nil
        lastRun, lastStats, lastZone, lastClock = runStamp, stats, Number(zoneStamp) and zoneStamp or lastZone, run.t
        return strength, phase == "choosing"
    end

    local function Label(parent, size, x, y, width, color, justify, height)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetWidth(width)
        label:SetHeight(height or size + 5)
        label:SetJustifyH(justify or "LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(unpack(color))
        T.SetFont(label, size, "OUTLINE")
        T.SetChatShadow(label)
        if not label:GetFont() then pendingFonts[label] = size end
        return label
    end

    local function PreparePanel()
        T.CreateQuestTrackerHeader(panel, WIDTH, HEADER_HEIGHT)
        local icon = panel:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\Icons\\INV_Jewelry_Amulet_03")
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetWidth(18)
        icon:SetHeight(18)
        icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -(HEADER_HEIGHT - 18) / 2)
        local rim = panel:CreateTexture(nil, "OVERLAY")
        rim:SetTexture(DFRL:GetInfoOrCons("tex") .. "character\\QualityBorder.blp")
        rim:SetVertexColor(unpack(GOLD))
        rim:SetWidth(22)
        rim:SetHeight(22)
        rim:SetPoint("CENTER", icon, "CENTER", 0, 0)
        labels = {
            title = Label(panel, 14, 36, -(HEADER_HEIGHT - 19) / 2, WIDTH - 46, GOLD),
            tiers = {},
            rows = {},
        }
        local x = COLUMN_LEFT
        for index, tier in ipairs(TIERS) do
            labels.tiers[index] =
                Label(panel, 10, x, -HEADER_HEIGHT - 2, tier[5], { tier[2], tier[3], tier[4] }, "CENTER")
            x = x + tier[5]
        end
        for index = 1, table.getn(REWARDS) do
            local y = -HEADER_HEIGHT - 19 - (index - 1) * ROW_HEIGHT
            local row = { name = Label(panel, 10, 10, y, COLUMN_LEFT - 12, GOLD, "LEFT", ROW_HEIGHT) }
            local left = COLUMN_LEFT
            for column, tier in ipairs(TIERS) do
                row[column] = Label(panel, 10, left, y, tier[5], WHITE, "CENTER", ROW_HEIGHT)
                left = left + tier[5]
            end
            labels.rows[index] = row
        end
    end

    local function SetTop(wanted)
        if wanted and registeredTop == true then return true end
        if not wanted and not registeredTop then return true end
        local setter = AZS_SetOnTopOfScreens
        if type(setter) ~= "function" then return false end
        local ok, result = pcall(setter, panel, wanted)
        local getter = AZS_IsOnTopOfScreens
        if type(getter) == "function" then
            local checked, state = pcall(getter, panel)
            if checked and state == wanted then
                registeredTop = wanted
                return true
            end
        elseif not wanted and ok and result ~= false then
            registeredTop = false
            return true
        end
        -- A partial write can still have entered the native registry.
        if wanted then registeredTop = "pending" end
        return false
    end

    local function Hide()
        if shown then panel:Hide() end
        shown = false
        SetTop(false)
    end

    local function Paint(strength)
        local currentLanguage = locale.code or "en"
        if language ~= currentLanguage then
            T.SetTextIfChanged(labels.title, locale.Text("Rarity odds"))
            for index, tier in ipairs(TIERS) do
                T.SetTextIfChanged(labels.tiers[index], locale.Text(tier[1]))
            end
            for index, reward in ipairs(REWARDS) do
                T.SetTextIfChanged(labels.rows[index].name, locale.Text(reward[1]))
            end
            language = currentLanguage
        end
        if paintedStrength == strength then return end
        for index, reward in ipairs(REWARDS) do
            local k = strength + reward[2]
            local square = k * k
            local rare, epic, legendary = 10 * square, 4 * square * k, square * square
            local total = 60 + 25 * k + rare + epic + legendary
            local row = labels.rows[index]
            T.SetTextIfChanged(row[1], string.format("%.1f%%", 100 * rare / total))
            T.SetTextIfChanged(row[2], string.format("%.1f%%", 100 * epic / total))
            T.SetTextIfChanged(row[3], string.format("%.1f%%", 100 * legendary / total))
        end
        paintedStrength = strength
    end

    local function Update()
        local strength, choosing = Read()
        if not strength then
            Hide()
            return
        end
        if not labels then PreparePanel() end
        for label, size in pairs(pendingFonts) do
            T.SetFont(label, size, "OUTLINE")
            if label:GetFont() then pendingFonts[label] = nil end
        end
        if next(pendingFonts) then return end
        if not SetTop(choosing) then
            Hide()
            return
        end
        Paint(strength)
        if not shown then
            PlaceDefault()
            panel:Show()
        end
        shown = true
    end

    local function Tick()
        elapsed = elapsed + (tonumber(arg1) or 0)
        if elapsed < INTERVAL then return end
        elapsed = 0
        Update()
    end

    local function Sync()
        local nextUpdate = inWorld and enabled and permitted and Tick or nil
        if controller:GetScript("OnUpdate") ~= nextUpdate then controller:SetScript("OnUpdate", nextUpdate) end
        if not nextUpdate then
            Hide()
        else
            elapsed = INTERVAL
        end
    end
    local function Stop()
        inWorld = false
        Retire()
        Sync()
    end

    layout.ListenVisibility("rarityOdds", function(visible)
        permitted = visible
        Sync()
    end)
    display.Listen(function()
        local rows = display.Get("meterRows")
        if meterRows ~= rows then
            meterRows = rows
            DFRL.RefreshRarityOddsPlacement()
        end
        local show, above = display.Get("rarityOdds"), display.Get("rarityOddsOverCards")
        if enabled == show and overCards == above then return end
        enabled, overCards = show, above
        if not above and registeredTop then Hide() end
        Sync()
    end)
    locale.Listen(function() elapsed = INTERVAL end)
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            Sync()
        else
            Stop()
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            Stop()
            return reloadUI()
        end
    end
    Sync()
end)
