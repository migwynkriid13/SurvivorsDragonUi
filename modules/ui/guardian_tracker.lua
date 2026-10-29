--[[
Guardian tracker artwork is copyright Blizzard Entertainment.
Header source: NeticSoul/DragonUI commit 5aefa049d22ba1a9e968b433d96eed7be86d6ac9,
DragonUI/Textures/UI/QuestTracker.BLP, 1024x512, rectangle (11,247,571,317).
https://github.com/NeticSoul/DragonUI/blob/5aefa049d22ba1a9e968b433d96eed7be86d6ac9/DragonUI/Textures/UI/QuestTracker.BLP
The source's third-party notices identify RetailUI as an artwork conduit;
Blizzard textures are excluded from its software MIT license and included for
use with the game. No source-addon code or framework is imported.
Existing guardian medallion and WidgetStatusBar artwork retain their shipped
notices. Exact sources, regions and assembly: third_party/GuardianTracker-ARTWORK.md.
]]
DFRL:NewMod("GuardianTracker", 4, function()
    local roster = DFRL.guardians
    local minimapDefaults = DFRL.minimapDefaults
    if not roster or not minimapDefaults then return end
    local path = DFRL:GetInfoOrCons("tex")
    local rows = {}
    local inWorld, dirty, age = true, true, 0
    local showDead = DFRL.display.Get("guardianShowDead")
    local showCurrent = DFRL.display.Get("guardianShowCurrentHealth")
    local showMaximum = DFRL.display.Get("guardianShowMaximumHealth")
    local showPercentage = DFRL.display.Get("guardianShowHealthPercentage") == true
    local shortenHealth = DFRL.display.Get("guardianShortHealth") ~= false
    local DEFAULT_SCALE = 0.85
    local ROW_INSET, NAME_WIDTH, COLUMN_GAP = 12, 120, 16 * 0.9
    local HEALTH_RIGHT_OFFSET = 4
    local TITLE_LEFT = 44
    local TITLE_PADDING = TITLE_LEFT + ROW_INSET
    local WIDTH, ROW_HEIGHT = 128 + NAME_WIDTH + COLUMN_GAP + 2 * ROW_INSET, 26
    local visibleRows, rowOffset = DFRL.display.Get("guardianRows"), 0
    local preferredStatusWidth, headerHeight = 128, WIDTH / 8
    local width, statusWidth = 240, 128
    local healthWidth = 0
    local presentation = { snapshot = { rows = {}, counts = {} }, shown = false }
    local frame = CreateFrame("Frame", "DFRL_GuardianTracker", UIParent)
    frame:SetScale(DEFAULT_SCALE)
    frame:SetWidth(width)
    frame:SetHeight(headerHeight + (visibleRows > 0 and visibleRows or 5) * ROW_HEIGHT + 12)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(false)
    frame:EnableMouseWheel(true)
    frame:Hide()

    local function Label(parent, size, justify)
        local label = parent:CreateFontString(nil, "OVERLAY")
        T.SetFont(label, size, "OUTLINE")
        label:SetJustifyH(justify or "LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(0.87, 0.74, 0.49)
        label:SetShadowColor(0, 0, 0, 0.9)
        label:SetShadowOffset(1, -1)
        return label
    end
    local function Texture(parent, file, layer, w, h, right, bottom)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetTexture(path .. file .. ".blp")
        texture:SetWidth(w)
        texture:SetHeight(h)
        texture:SetTexCoord(0, right or 1, 0, bottom or 1)
        return texture
    end
    local header = Texture(frame, "guardians\\Header", "BACKGROUND", width, headerHeight, 560 / 1024, 70 / 128)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetAlpha(0.8)
    local icon = Texture(frame, "waypoint\\GuardianFloating", "ARTWORK", 28, 28, 65 / 128, 65 / 128)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -6)
    local title = Label(frame, 14)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", TITLE_LEFT, -8)
    title:SetHeight(23)
    local measure = Label(frame, 12)
    measure:Hide()

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Format(source, first, second) return string.format(DFRL.locale.Text(source), first, second) end
    local function Time(seconds)
        local rounded = math.max(0, math.ceil(seconds))
        return string.format("%d:%02d", math.floor(rounded / 60), math.mod(rounded, 60))
    end
    local aliveColor = { 0.61, 0.81, 0.52 }
    local colors = {
        asleep = aliveColor,
        fighting = aliveColor,
        returning = { 0.9, 0.73, 0.4 },
        due = aliveColor,
        empty = { 0.61, 0.67, 0.65 },
    }
    local captions = { asleep = "Alive", fighting = "Alive", due = "Alive", empty = "Empty" }
    local function ClearStatus(row)
        if row.statusText == nil then return end
        row.statusIdentity, row.statusKind, row.statusSecond, row.statusLanguage, row.statusText =
            nil, nil, nil, nil, nil
    end
    local function ClearStatuses()
        for _, row in ipairs(rows) do
            ClearStatus(row)
        end
    end
    local function Status(entry, row)
        if entry.status == "fighting" and Number(entry.healthFraction) then
            return T.EncounterHealthText(
                entry.hp,
                entry.maximum,
                showCurrent,
                showMaximum,
                nil,
                shortenHealth,
                showPercentage
            )
        end
        local second = entry.status == "returning" and math.max(0, math.ceil(entry.remaining)) or nil
        local language = DFRL.locale.code
        if
            row.statusIdentity ~= entry.key
            or row.statusKind ~= entry.status
            or row.statusSecond ~= second
            or row.statusLanguage ~= language
            or row.statusText == nil
        then
            local text = entry.status == "returning" and Format("Respawns in %s", Time(second))
                or DFRL.locale.Text(captions[entry.status] or "Empty")
            row.statusIdentity, row.statusKind, row.statusSecond, row.statusLanguage =
                entry.key, entry.status, second, language
            row.statusText = text
        end
        return row.statusText
    end
    local function LairName(entry, row)
        if entry.name then return entry.name end
        local language = DFRL.locale.code
        if row.lairIndex ~= entry.index or row.lairLanguage ~= language or row.lairText == nil then
            local text = Format("Lair %d", entry.index)
            row.lairIndex, row.lairLanguage, row.lairText = entry.index, language, text
        end
        return row.lairText
    end
    local function ClearRow(row)
        ClearStatus(row)
        row.lairIndex, row.lairLanguage, row.lairText = nil, nil, nil
        if row.value ~= 0 then row.bar:SetValue(0) end
        row.value = 0
        T.SetEncounterHealthText(row.health, nil, nil, false, false)
        if row.pill:IsShown() then row.pill:Hide() end
        if row:IsShown() then row:Hide() end
    end
    local function Clear()
        rowOffset = 0
        presentation.healthLabels, healthWidth, dirty = nil, 0, true
        presentation.filteredCount = 0
        if presentation.filtered then
            for index in ipairs(presentation.filtered) do
                presentation.filtered[index] = nil
            end
            table.setn(presentation.filtered, 0)
        end
        for _, row in ipairs(rows) do
            ClearRow(row)
        end
        if presentation.shown then
            presentation.shown = false
            frame:Hide()
        end
    end

    local function MakeRow()
        local row = CreateFrame("Frame", nil, frame)
        row:SetHeight(ROW_HEIGHT)
        row:EnableMouse(false)
        row.name = Label(row, 12)
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name:SetHeight(ROW_HEIGHT)
        row.status = Label(row, 12, "RIGHT")
        row.status:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.status:SetHeight(ROW_HEIGHT)
        local pill = CreateFrame("Frame", nil, row)
        pill:SetHeight(22)
        pill:SetPoint("RIGHT", row, "RIGHT", HEALTH_RIGHT_OFFSET, 0)
        pill:EnableMouse(false)
        local background = Texture(pill, "timer\\BackgroundCenter", "BACKGROUND", statusWidth, 12, 1, 18 / 32)
        background:SetPoint("LEFT", pill, "LEFT", 6, 0)
        background:SetPoint("RIGHT", pill, "RIGHT", -6, 0)
        local bar = CreateFrame("StatusBar", nil, pill)
        bar:SetPoint("LEFT", pill, "LEFT", 7, 0)
        bar:SetPoint("RIGHT", pill, "RIGHT", -7, 0)
        bar:SetHeight(11)
        bar:SetMinMaxValues(0, 1)
        bar:SetStatusBarTexture(path .. "timer\\FillWhite.blp")
        bar:SetValue(0)
        bar:EnableMouse(false)
        local overlay = CreateFrame("Frame", nil, pill)
        overlay:SetAllPoints(pill)
        overlay:SetFrameLevel(bar:GetFrameLevel() + 1)
        overlay:EnableMouse(false)
        local left = Texture(overlay, "timer\\BorderLeft", "OVERLAY", 25, 22, 35 / 64, 31 / 32)
        left:SetPoint("LEFT", pill, "LEFT", 0, 0)
        local right = Texture(overlay, "timer\\BorderRight", "OVERLAY", 25, 22, 35 / 64, 31 / 32)
        right:SetPoint("RIGHT", pill, "RIGHT", 0, 0)
        -- The caps contain translucent inner shadows; overlapping the center
        -- darkens them twice and leaves black bands across the health fill.
        local center = Texture(overlay, "timer\\BorderCenter", "OVERLAY", statusWidth + 8 - 2 * 25, 22, 1, 31 / 32)
        center:SetPoint("LEFT", left, "RIGHT", 0, 0)
        center:SetPoint("RIGHT", right, "LEFT", 0, 0)
        local health = Label(overlay, T.EncounterHealthStyle.fontSize, "CENTER")
        health:SetPoint("LEFT", overlay, "LEFT", 6, 0)
        health:SetPoint("RIGHT", overlay, "RIGHT", -6, 0)
        health:SetHeight(22)
        T.StyleEncounterHealth(bar, health)
        row.pill, row.bar, row.health = pill, bar, health
        pill:Hide()
        table.insert(rows, row)
        return row
    end

    -- Measure the real game font across every caption translation, including
    -- populated format fields. Native guardian names remain bounded separately.
    local function CaptionWidth(source, first, size)
        if presentation.measureSize ~= (size or 12) then
            T.SetFont(measure, size or 12, "OUTLINE")
            presentation.measureSize = size or 12
        end
        local maximum = 0
        for _, catalog in pairs(DFRL.locale.data) do
            local text = catalog.ui[source] or source
            if first ~= nil then text = string.format(text, first) end
            measure:SetText(text)
            maximum = math.max(maximum, measure:GetStringWidth() or 0)
        end
        return math.ceil(maximum)
    end
    local function ApplyWidth()
        width = frame:GetWidth()
        local available = width - 2 * ROW_INSET - COLUMN_GAP
        -- Stay within the saved width; percentages reserve measured health space
        -- before shrinking the name. Keep the pill's two 25-unit caps apart.
        statusWidth = math.min(
            preferredStatusWidth,
            math.max(
                42,
                available * preferredStatusWidth / (NAME_WIDTH + preferredStatusWidth),
                showPercentage and healthWidth or 0
            ),
            available - 24
        )
    end
    local function Measure()
        preferredStatusWidth = math.max(128, healthWidth, CaptionWidth("Respawns in %s", "99:59") + 16)
        for _, source in pairs(captions) do
            preferredStatusWidth = math.max(preferredStatusWidth, CaptionWidth(source) + 16)
        end
        local titleWidth = CaptionWidth("GUARDIANS", nil, 14)
        if titleWidth <= 0 then return false end
        headerHeight = math.max(
            WIDTH,
            preferredStatusWidth + NAME_WIDTH + COLUMN_GAP + 2 * ROW_INSET,
            titleWidth + TITLE_PADDING
        ) / 8
        ApplyWidth()
        return true
    end
    local function MeasureHealthLabels(snapshot)
        if
            (showCurrent or showMaximum or showPercentage)
            and presentation.measureSize ~= T.EncounterHealthStyle.fontSize
        then
            T.SetFont(measure, T.EncounterHealthStyle.fontSize, "OUTLINE")
            presentation.measureSize = T.EncounterHealthStyle.fontSize
        end
        if showCurrent or showMaximum or showPercentage then
            local labels = presentation.healthLabels or {}
            presentation.healthLabels = labels
            for index, entry in ipairs(snapshot.rows) do
                if entry.status == "fighting" and Number(entry.healthFraction) then
                    local cache = labels[index] or {}
                    labels[index] = cache
                    local text = T.EncounterHealthText(
                        entry.hp,
                        entry.maximum,
                        showCurrent,
                        showMaximum,
                        cache,
                        shortenHealth,
                        showPercentage
                    )
                    if cache.measuredText ~= text or not cache.measured then
                        T.SetTextIfChanged(measure, text)
                        local measured = measure:GetStringWidth() or 0
                        cache.measuredText, cache.measured = text, measured > 0 and math.ceil(measured) + 16 or nil
                    end
                    if cache.measured and cache.measured > healthWidth then
                        healthWidth, dirty = cache.measured, true
                    end
                else
                    labels[index] = nil
                end
            end
            for index in pairs(labels) do
                if index > table.getn(snapshot.rows) then labels[index] = nil end
            end
        end
        if dirty then
            if not Measure() then return false end
            dirty = false
        end
        return true
    end
    local function Refresh()
        if not inWorld or DFRL.layout.IsHidden("guardianTracker") or not UIParent:IsVisible() then return end
        local snapshot = roster.GetSnapshot(presentation.snapshot)
        if snapshot.status ~= "ready" or not snapshot.rows[1] then
            Clear()
            return
        end
        if not presentation.shown then
            presentation.shown = true
            frame:Show()
        end
        if not frame:IsVisible() then return end
        if not MeasureHealthLabels(snapshot) then
            Clear()
            return
        end
        if presentation.measuredWidth ~= width then
            title:SetWidth(width - TITLE_PADDING)
            header:SetWidth(width)
            presentation.measuredWidth = width
        end
        if presentation.headerHeight ~= headerHeight then
            header:SetHeight(headerHeight)
            presentation.headerHeight = headerHeight
        end
        T.SetTextIfChanged(title, DFRL.locale.Text("GUARDIANS"))
        local filtered, count = presentation.filtered or {}, 0
        presentation.filtered = filtered
        for _, entry in ipairs(snapshot.rows) do
            if showDead or entry.state == "asleep" or entry.state == "awake" then
                count = count + 1
                filtered[count] = entry
            end
        end
        for index = count + 1, table.getn(filtered) do
            filtered[index] = nil
        end
        table.setn(filtered, count)
        presentation.filteredCount = count
        local capacity = visibleRows > 0 and visibleRows or count
        rowOffset = math.max(0, math.min(rowOffset, count - capacity))
        local used = 0
        for index = rowOffset + 1, math.min(count, rowOffset + capacity) do
            local entry = filtered[index]
            if entry then
                used = used + 1
                local row = rows[used] or MakeRow()
                if
                    row.layoutWidth ~= width
                    or row.layoutIndex ~= used
                    or row.statusWidth ~= statusWidth
                    or row.headerHeight ~= headerHeight
                then
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_INSET, -(headerHeight + 6 + (used - 1) * ROW_HEIGHT))
                    row:SetWidth(width - 2 * ROW_INSET)
                    row.name:SetWidth(width - statusWidth - 2 * ROW_INSET - COLUMN_GAP)
                    row.status:SetWidth(statusWidth)
                    row.pill:SetWidth(statusWidth + 8)
                    row.layoutWidth, row.layoutIndex, row.statusWidth = width, used, statusWidth
                    row.headerHeight = headerHeight
                end
                T.SetTextIfChanged(row.name, LairName(entry, row))
                local color = colors[entry.status] or colors.empty
                if row.color ~= color then
                    row.status:SetTextColor(color[1], color[2], color[3])
                    row.color = color
                end
                -- Only the native fighting state with valid current health gets a
                -- bar. Every other state clears the old fill before showing text.
                if entry.state == "awake" and Number(entry.healthFraction) then
                    ClearStatus(row)
                    if row.value ~= entry.healthFraction then row.bar:SetValue(entry.healthFraction) end
                    row.value = entry.healthFraction
                    T.SetEncounterHealthText(
                        row.health,
                        entry.hp,
                        entry.maximum,
                        showCurrent,
                        showMaximum,
                        shortenHealth,
                        showPercentage
                    )
                    if row.status:IsShown() then row.status:Hide() end
                    if not row.pill:IsShown() then row.pill:Show() end
                else
                    if row.value ~= 0 then row.bar:SetValue(0) end
                    row.value = 0
                    if row.pill:IsShown() then row.pill:Hide() end
                    T.SetEncounterHealthText(row.health, nil, nil, false, false)
                    T.SetTextIfChanged(row.status, Status(entry, row))
                    if not row.status:IsShown() then row.status:Show() end
                end
                if not row:IsShown() then row:Show() end
            end
        end
        for index = used + 1, table.getn(rows) do
            ClearRow(rows[index])
        end
        local height = headerHeight + 12 + (visibleRows > 0 and visibleRows or used) * ROW_HEIGHT
        if not T.NearlyEqual(frame:GetHeight(), height) then frame:SetHeight(height) end
    end
    local function ScrollRows(direction)
        if visibleRows == 0 then return end
        rowOffset = math.max(
            0,
            math.min(rowOffset - (tonumber(direction) or 0), (presentation.filteredCount or 0) - visibleRows)
        )
        age = 0.1
    end
    frame:SetScript("OnMouseWheel", function() ScrollRows(arg1) end)
    DFRL.layout.Register("guardianTracker", frame, function()
        -- Match the health pill's right edge to the default minimap right edge.
        local right = minimapDefaults.right / DEFAULT_SCALE + ROW_INSET - HEALTH_RIGHT_OFFSET
        frame:ClearAllPoints()
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", right, -252 / DEFAULT_SCALE)
    end, {
        labelAbove = true,
        refreshDefault = true,
        edgeWidth = true,
        minWidth = 120,
        maxWidth = 960,
        onResize = function()
            local scale = frame:GetEffectiveScale()
            if presentation.resizeScale ~= scale then
                presentation.resizeScale = scale
                presentation.healthLabels, healthWidth = nil, 0
                dirty = true
            end
            ApplyWidth()
            age = 0.1
        end,
        onHeightDrag = function(height)
            DFRL.display.Set("guardianRows", math.max(1, math.floor((height - headerHeight - 12) / ROW_HEIGHT + 0.5)))
        end,
        onMouseWheel = ScrollRows,
        onReset = Refresh,
    })
    DFRL.locale.Listen(function()
        ClearStatuses()
        presentation.healthLabels, healthWidth = nil, 0
        dirty = true
        Refresh()
    end)
    local controller = CreateFrame("Frame", nil, UIParent)
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    local function Tick()
        if not inWorld then return end
        age = age + (tonumber(arg1) or 0)
        if age < 0.1 then return end
        age = 0
        Refresh()
    end
    local function SyncUpdates()
        controller:SetScript("OnUpdate", inWorld and not DFRL.layout.IsHidden("guardianTracker") and Tick or nil)
    end
    DFRL.display.Listen(function()
        local selected = DFRL.display.Get("guardianRows")
        local selectedShowDead = DFRL.display.Get("guardianShowDead")
        local selectedCurrent = DFRL.display.Get("guardianShowCurrentHealth")
        local selectedMaximum = DFRL.display.Get("guardianShowMaximumHealth")
        local selectedPercentage = DFRL.display.Get("guardianShowHealthPercentage") == true
        local selectedShortHealth = DFRL.display.Get("guardianShortHealth") ~= false
        if
            selectedCurrent ~= showCurrent
            or selectedMaximum ~= showMaximum
            or selectedShortHealth ~= shortenHealth
            or selectedPercentage ~= showPercentage
        then
            ClearStatuses()
            showCurrent, showMaximum = selectedCurrent, selectedMaximum
            showPercentage = selectedPercentage
            shortenHealth = selectedShortHealth
            presentation.healthLabels, healthWidth = nil, 0
            dirty, age = true, 0.1
        end
        if selected ~= visibleRows or selectedShowDead ~= showDead then
            ClearStatuses()
            visibleRows, showDead, age, rowOffset = selected, selectedShowDead, 0.1, 0
            local height = headerHeight
                + 12
                + (visibleRows > 0 and visibleRows or (presentation.filteredCount or 5)) * ROW_HEIGHT
            if not T.NearlyEqual(frame:GetHeight(), height) then frame:SetHeight(height) end
        end
    end)
    controller:SetScript("OnEvent", function()
        inWorld = event == "PLAYER_ENTERING_WORLD"
        if inWorld then
            dirty, age = true, 0
        else
            healthWidth = 0
            Clear()
        end
        SyncUpdates()
    end)
    DFRL.layout.ListenVisibility("guardianTracker", function(permitted)
        ClearStatuses()
        dirty, age = true, 0.1
        SyncUpdates()
        if permitted then Refresh() end
    end)
end)
