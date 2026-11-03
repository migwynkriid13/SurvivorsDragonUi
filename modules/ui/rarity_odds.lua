DFRL:NewMod("RarityOdds", 5, function()
    local INTERVAL, WIDTH, HEIGHT = 0.25, 420, 166
    local GOLD, MUTED, WHITE = { 0.93, 0.8, 0.53 }, { 0.73, 0.76, 0.82 }, { 1, 0.96, 0.87 }
    local TIERS = {
        { "Rare", 0.28, 0.65, 1 },
        { "Epic", 0.76, 0.49, 1 },
        { "Legendary", 1, 0.64, 0.28 },
    }
    -- Source modifiers for a base roll. A new amulet adds 0.50; the
    -- guardian reward path adds 0.25 to either jewelry category.
    local REWARDS = {
        { "Spell cards", 0 },
        { "Cache jewelry", 0 },
        { "New cache amulets", 0.5 },
        { "Guardian jewelry", 0.25 },
        { "New guardian amulets", 0.75 },
    }
    local display, layout, locale = DFRL.display, DFRL.layout, DFRL.locale
    local enabled, overCards = display.Get("rarityOdds"), display.Get("rarityOddsOverCards")
    local inWorld, permitted, elapsed = true, not layout.IsHidden("rarityOdds"), INTERVAL
    local labels, language, registeredTop, shown
    local retiredRun, retiredStats, paintedLuck, paintedLevel
    local lastRun, lastStats, lastZone, lastClock
    local pendingFonts = {}
    local controller = CreateFrame("Frame", nil, UIParent)
    local panel = CreateFrame("Frame", "SurvivorsDragonUiRarityOdds", UIParent)
    panel:Hide()
    panel:SetWidth(WIDTH)
    panel:SetHeight(HEIGHT)
    panel:SetFrameStrata("MEDIUM")
    panel:EnableMouse(false)
    layout.Register("rarityOdds", panel, function(frame)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -235)
    end, { labelAbove = true })

    local function Number(value) return type(value) == "number" and value - value == 0 end
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
        return luck, bonus, strength, phase == "choosing"
    end

    local function Label(parent, size, x, y, width, color, justify)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetWidth(width)
        label:SetHeight(size + 5)
        label:SetJustifyH(justify or "LEFT")
        label:SetTextColor(unpack(color))
        T.SetFont(label, size, "OUTLINE")
        if not label:GetFont() then pendingFonts[label] = size end
        return label
    end

    local function PreparePanel()
        T.StyleHoverCard(panel, 0.58, 0.47, 0.31)
        local rule = panel:CreateTexture(nil, "ARTWORK")
        rule:SetTexture("Interface\\Buttons\\WHITE8X8")
        rule:SetVertexColor(0.61, 0.47, 0.29, 0.6)
        rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -56)
        rule:SetWidth(WIDTH - 24)
        rule:SetHeight(1)
        labels = {
            title = Label(panel, 15, 12, -10, 190, GOLD),
            luck = Label(panel, 11, 204, -13, WIDTH - 216, MUTED, "RIGHT"),
            note = Label(panel, 10, 12, -146, WIDTH - 24, MUTED),
            tiers = {},
            rows = {},
        }
        for index, tier in ipairs(TIERS) do
            local x = 180 + (index - 1) * 76
            labels.tiers[index] = Label(panel, 11, x, -36, 76, { tier[2], tier[3], tier[4] }, "CENTER")
        end
        for index = 1, table.getn(REWARDS) do
            local y = -60 - (index - 1) * 16
            local row = { name = Label(panel, 11, 12, y, 168, WHITE) }
            for column = 1, table.getn(TIERS) do
                row[column] = Label(panel, 11, 180 + (column - 1) * 76, y, 76, WHITE, "CENTER")
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

    local function Paint(luck, bonus, strength)
        local currentLanguage = locale.code or "en"
        local relabel = language ~= currentLanguage
        if relabel then
            T.SetTextIfChanged(labels.title, locale.Text("Rarity odds"))
            T.SetTextIfChanged(labels.note, locale.Text("Estimated base rolls per card"))
            for index, tier in ipairs(TIERS) do
                T.SetTextIfChanged(labels.tiers[index], locale.Text(tier[1]))
            end
            for index, reward in ipairs(REWARDS) do
                T.SetTextIfChanged(labels.rows[index].name, locale.Text(reward[1]))
            end
            language = currentLanguage
        end
        if paintedLuck == luck and paintedLevel == bonus and not relabel then return end
        T.SetTextIfChanged(
            labels.luck,
            string.format(locale.Text("Luck %.1f%%  /  Level +%.0f%%"), luck * 100, bonus * 100)
        )
        if paintedLuck ~= luck or paintedLevel ~= bonus then
            local previousBonus, rareText, epicText, legendaryText
            for index, reward in ipairs(REWARDS) do
                if reward[2] ~= previousBonus then
                    local k = strength + reward[2]
                    local square = k * k
                    local rare, epic, legendary = 10 * square, 4 * square * k, square * square
                    local total = 60 + 25 * k + rare + epic + legendary
                    rareText = string.format("%.1f%%", 100 * rare / total)
                    epicText = string.format("%.1f%%", 100 * epic / total)
                    legendaryText = string.format("%.1f%%", 100 * legendary / total)
                    previousBonus = reward[2]
                end
                local row = labels.rows[index]
                T.SetTextIfChanged(row[1], rareText)
                T.SetTextIfChanged(row[2], epicText)
                T.SetTextIfChanged(row[3], legendaryText)
            end
            paintedLuck, paintedLevel = luck, bonus
        end
    end

    local function Update()
        local luck, bonus, strength, choosing = Read()
        if not luck then
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
        Paint(luck, bonus, strength)
        if not shown then panel:Show() end
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
