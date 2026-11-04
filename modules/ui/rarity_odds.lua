DFRL:NewMod("RarityOdds", 5, function()
    local style, SCALE = T.RightHudStyle, 0.85
    local INTERVAL, WIDTH, GAP = 0.25, style.width / SCALE, 8
    local TITLE_SIZE, TITLE_HEIGHT = style.titleSize / SCALE, 19
    local HEADER_HEIGHT, ROW_HEIGHT, COLUMN_LEFT = style.questHeaderHeight / SCALE, 19, 100
    local BODY_SIZE = 10
    local TIERS = {
        { "Rare", 0.28, 0.65, 1, 39 },
        { "Epic", 0.76, 0.49, 1, 39 },
        { "Legendary", 1, 0.64, 0.28, 60 },
    }
    -- Source modifiers for a base roll. A new amulet adds 0.50; the
    -- guardian reward path adds 0.25 to either jewelry category.
    local REWARDS = {
        { "Spells / cache jewelry", 0, "Spells / cache" },
        { "Guardian jewelry", 0.25 },
        { "Cache amulets", 0.5 },
        { "Guardian amulets", 0.75 },
    }
    local ROW_TOP, ROW_COUNT = HEADER_HEIGHT + 19, table.getn(REWARDS)
    local HEIGHT = ROW_TOP + ROW_COUNT * ROW_HEIGHT + 2
    local display, layout, locale = DFRL.display, DFRL.layout, DFRL.locale
    local enabled = display.Get("rarityOdds")
    local meterRows = display.Get("meterRows")
    local fontChoice, fontFile, fontOutline =
        display.Get("uiFont"), display.Get("uiCustomFont"), display.Get("uiFontOutline")
    local inWorld, permitted, elapsed = true, not layout.IsHidden("rarityOdds"), INTERVAL
    local labels, language, shown
    local tooltipArea, tooltipValue, tooltipBonus, tooltipLanguage
    local width, drawnWidth, Reflow = WIDTH, nil, nil
    local retiredRun, retiredStats, paintedStrength
    local lastRun, lastStats, lastZone, lastClock
    local pendingFonts, pendingFits = {}, {}
    local controller = CreateFrame("Frame", nil, UIParent)
    local panel = CreateFrame("Frame", "SurvivorsDragonUiRarityOdds", UIParent)
    panel:Hide()
    panel:SetScale(SCALE)
    panel:SetWidth(WIDTH)
    panel:SetHeight(HEIGHT)
    panel:SetFrameStrata("MEDIUM")
    panel:EnableMouse(false)

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function QueueCaptionFit()
        if not labels then return end
        pendingFits[labels.title] = TITLE_SIZE
        for _, heading in ipairs(labels.tiers) do
            pendingFits[heading] = BODY_SIZE
        end
        for _, row in ipairs(labels.rows) do
            pendingFits[row.name] = BODY_SIZE
        end
    end

    local function HideTooltip()
        if tooltipArea and GameTooltip and GameTooltip:IsOwned(panel) then GameTooltip:Hide() end
        tooltipArea = nil
    end
    panel:SetScript("OnHide", HideTooltip)

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
    end, {
        labelAbove = true,
        refreshDefault = true,
        edgeWidth = true,
        minWidth = WIDTH,
        maxWidth = 960,
        onResize = function(_, nextWidth)
            width = nextWidth
            if shown then Reflow() end
            QueueCaptionFit()
            elapsed = INTERVAL
        end,
        onEdit = function(editing)
            if editing then HideTooltip() end
        end,
    })

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
        if phase ~= "playing" and phase ~= "paused" then
            if phase == "ready" then Retire() end
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
        return strength, luck, bonus
    end

    local function Label(parent, size, color, justify, height)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetHeight(height or size + 5)
        label:SetJustifyH(justify or "LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(unpack(color))
        T.SetFont(label, size, "")
        T.SetChatShadow(label)
        if not label:GetFont() then pendingFonts[label] = size end
        return label
    end

    local function PreparePanel()
        local header = T.CreateQuestTrackerHeader(panel, width, HEADER_HEIGHT)
        local icon = panel:CreateTexture(nil, "ARTWORK")
        -- Blizzard's Bonus Objective star, cropped with its original alpha.
        icon:SetTexture(DFRL:GetInfoOrCons("tex") .. "rarity\\BonusObjectiveStar.blp")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 9, -(HEADER_HEIGHT - 20) / 2)
        labels = {
            header = header,
            title = Label(panel, TITLE_SIZE, style.titleColor, "LEFT", TITLE_HEIGHT),
            tiers = {},
            rows = {},
        }
        labels.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 36, -(HEADER_HEIGHT - TITLE_HEIGHT) / 2)
        for index, tier in ipairs(TIERS) do
            labels.tiers[index] = Label(panel, BODY_SIZE, { tier[2], tier[3], tier[4] }, "CENTER")
        end
        for index = 1, ROW_COUNT do
            local row = { name = Label(panel, BODY_SIZE, style.bodyColor, "LEFT") }
            row.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -ROW_TOP - (index - 1) * ROW_HEIGHT)
            for column = 1, table.getn(TIERS) do
                row[column] = Label(panel, BODY_SIZE, style.bodyColor, "CENTER")
            end
            labels.rows[index] = row
        end
    end

    local function FitCaption(label, size)
        if not T.SetFont(label, size, "") then return false end
        local available = label:GetWidth() - 2
        local measured = label:GetStringWidth()
        while Number(measured) and measured > available and size > 1 do
            size = math.max(1, math.min(math.ceil(size) - 1, math.floor(size * available / measured)))
            if not T.SetFont(label, size, "") then return false end
            measured = label:GetStringWidth()
        end
        return Number(measured) and measured > 0
    end

    Reflow = function()
        if drawnWidth == width then return end
        drawnWidth = width
        labels.header:SetWidth(width)
        labels.title:SetWidth(width - 46)
        local extra = math.max(0, width - WIDTH)
        local left = COLUMN_LEFT + extra / 2
        for _, row in ipairs(labels.rows) do
            row.name:SetWidth(left - 12)
        end
        for index, tier in ipairs(TIERS) do
            local columnWidth = tier[5] + extra / 6
            local heading = labels.tiers[index]
            heading:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -HEADER_HEIGHT - 2)
            heading:SetWidth(columnWidth)
            for rowIndex, row in ipairs(labels.rows) do
                local label = row[index]
                label:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -ROW_TOP - (rowIndex - 1) * ROW_HEIGHT)
                label:SetWidth(columnWidth)
            end
            left = left + columnWidth
        end
    end

    local function Hide()
        if shown then panel:Hide() end
        shown = false
    end

    local function RollWeights(k)
        local square = k * k
        local rare, epic, legendary = 10 * square, 4 * square * k, square * square
        return rare, epic, legendary, 60 + 25 * k + rare + epic + legendary
    end

    local function HoverArea()
        if
            not GameTooltip
            or not panel:IsVisible()
            or layout.IsEditing()
            or type(GetCursorPosition) ~= "function"
            or type(_G.GetMouseFocus) ~= "function"
        then
            return
        end
        local x, y = GetCursorPosition()
        local scale, left, top = panel:GetEffectiveScale(), panel:GetLeft(), panel:GetTop()
        if not Number(x) or not Number(y) or not Number(scale) or scale <= 0 or not Number(left) or not Number(top) then
            return
        end
        x, y = x / scale - left, top - y / scale
        if x < 0 or x >= width or y < 0 or y >= HEIGHT then return end
        local focus = _G.GetMouseFocus()
        if focus and focus ~= WorldFrame and focus ~= UIParent then return end
        if y < HEADER_HEIGHT then return 0 end
        local rowOffset = y - ROW_TOP
        if rowOffset >= 0 and rowOffset < ROW_HEIGHT * ROW_COUNT then return 1 + math.floor(rowOffset / ROW_HEIGHT) end
    end

    local function OneIn(weight, total)
        if weight <= 0 then return "—" end
        local rolls = total / weight
        if not Number(rolls) then return "—" end
        local format = rolls < 2 and "%.1f" or rolls < 1000000 and "%.0f" or "%.3g"
        return string.format(locale.Text("1 in %s"), string.format(format, rolls))
    end

    local function UpdateTooltip(strength, luck, levelBonus)
        local area = HoverArea()
        if not area then
            HideTooltip()
            return
        end
        local owned = GameTooltip:IsOwned(panel)
        local visible = GameTooltip:IsVisible()
        if visible and not owned then
            tooltipArea = nil
            return
        end
        local value = area == 0 and luck or strength
        local bonus = area == 0 and levelBonus or 0
        if
            owned
            and visible
            and tooltipArea == area
            and tooltipValue == value
            and tooltipBonus == bonus
            and tooltipLanguage == language
        then
            return
        end
        GameTooltip:SetOwner(panel, "ANCHOR_LEFT")
        if area == 0 then
            GameTooltip:SetText(locale.Text("Rarity odds"))
            GameTooltip:AddDoubleLine(locale.Text("Character luck"), string.format("%.1f%%", luck * 100))
            GameTooltip:AddDoubleLine(locale.Text("Level bonus"), string.format("+%.0f%%", levelBonus * 100))
            GameTooltip:AddDoubleLine(locale.Text("Effective luck"), string.format("%.1f%%", (luck + levelBonus) * 100))
        else
            local reward = REWARDS[area]
            local rare, epic, legendary, total = RollWeights(strength + reward[2])
            GameTooltip:SetText(locale.Text(reward[1]))
            GameTooltip:AddLine(locale.Text("Chance per roll"), 1, 1, 1)
            GameTooltip:AddDoubleLine(locale.Text("Rare"), OneIn(rare, total))
            GameTooltip:AddDoubleLine(locale.Text("Epic"), OneIn(epic, total))
            GameTooltip:AddDoubleLine(locale.Text("Legendary"), OneIn(legendary, total))
        end
        tooltipArea, tooltipValue, tooltipBonus, tooltipLanguage = area, value, bonus, language
        GameTooltip:Show()
    end

    local function Paint(strength)
        local currentLanguage = locale.code or "en"
        if language ~= currentLanguage then
            T.SetTextIfChanged(labels.title, locale.Text("Rarity odds"))
            for index, tier in ipairs(TIERS) do
                T.SetTextIfChanged(labels.tiers[index], locale.Text(tier[1]))
            end
            for index, reward in ipairs(REWARDS) do
                T.SetTextIfChanged(labels.rows[index].name, locale.Text(reward[3] or reward[1]))
            end
            language = currentLanguage
            QueueCaptionFit()
        end
        if paintedStrength == strength then return end
        for index, reward in ipairs(REWARDS) do
            local rare, epic, legendary, total = RollWeights(strength + reward[2])
            local row = labels.rows[index]
            T.SetTextIfChanged(row[1], string.format("%.1f%%", 100 * rare / total))
            T.SetTextIfChanged(row[2], string.format("%.1f%%", 100 * epic / total))
            T.SetTextIfChanged(row[3], string.format("%.1f%%", 100 * legendary / total))
        end
        paintedStrength = strength
    end

    local function Update()
        local strength, luck, levelBonus = Read()
        if not strength then
            Hide()
            return
        end
        if not labels then PreparePanel() end
        for label, size in pairs(pendingFonts) do
            T.SetFont(label, size, "")
            if label:GetFont() then pendingFonts[label] = nil end
        end
        if next(pendingFonts) then return end
        if not shown then PlaceDefault() end
        Reflow()
        Paint(strength)
        for label, size in pairs(pendingFits) do
            if FitCaption(label, size) then pendingFits[label] = nil end
        end
        if not shown then panel:Show() end
        shown = true
        UpdateTooltip(strength, luck, levelBonus)
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
        local choice, file, outline = display.Get("uiFont"), display.Get("uiCustomFont"), display.Get("uiFontOutline")
        if choice ~= fontChoice or file ~= fontFile or outline ~= fontOutline then
            fontChoice, fontFile, fontOutline = choice, file, outline
            QueueCaptionFit()
            elapsed = INTERVAL
        end
        local rows = display.Get("meterRows")
        if meterRows ~= rows then
            meterRows = rows
            DFRL.RefreshRarityOddsPlacement()
        end
        local show = display.Get("rarityOdds")
        if enabled == show then return end
        enabled = show
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
