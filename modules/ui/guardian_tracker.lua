--[[
Guardian tracker artwork is copyright Blizzard Entertainment.
Header source: NeticSoul/DragonUI commit 5aefa049d22ba1a9e968b433d96eed7be86d6ac9,
DragonUI/Textures/UI/QuestTracker.BLP, 1024x512, rectangle (11,247,571,317).
The header toggle reuses the existing minimap ZoomIn32/ZoomOut32 normal,
pressed, hover and disabled artwork through the common styling helper.
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
    local inWorld, editing, dirty, age = true, false, true, 0
    local expanded = true
    local DEFAULT_SCALE = 0.85
    local ROW_INSET, NAME_WIDTH, COLUMN_GAP = 12, 120, 16 * 0.9
    local HEALTH_RIGHT_OFFSET = 4
    local TOGGLE_SIZE, TOGGLE_INSET = 25.6, 11
    local WIDTH, ROW_HEIGHT = 128 + NAME_WIDTH + COLUMN_GAP + 2 * ROW_INSET, 26
    local width, statusWidth = WIDTH, 128
    local healthWidth = 0
    local presentation = { snapshot = { rows = {}, counts = {} }, shown = false }
    local frame = CreateFrame("Frame", "DFRL_GuardianTracker", UIParent)
    frame:SetScale(DEFAULT_SCALE)
    frame:SetWidth(WIDTH)
    frame:SetHeight(WIDTH / 8 + 5 * ROW_HEIGHT + 12)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(false)
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
    local header = Texture(frame, "guardians\\Header", "BACKGROUND", WIDTH, WIDTH / 8, 560 / 1024, 70 / 128)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetAlpha(0.8)
    local icon = Texture(frame, "waypoint\\GuardianFloating", "ARTWORK", 28, 28, 65 / 128, 65 / 128)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -6)
    local title = Label(frame, 14)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 44, -8)
    title:SetHeight(23)
    local toggle = CreateFrame("Button", nil, frame)
    toggle:SetWidth(TOGGLE_SIZE)
    toggle:SetHeight(TOGGLE_SIZE)
    toggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -TOGGLE_INSET, -7)
    toggle:RegisterForClicks("LeftButtonUp")
    local toggleExpanded
    local function UpdateToggle()
        if toggleExpanded == expanded then return end
        T.StyleMinimapZoomButton(toggle, expanded and "ZoomOut32" or "ZoomIn32", true)
        toggleExpanded = expanded
    end
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
    local function Status(entry)
        if entry.status == "returning" then return Format("Respawns in %s", Time(entry.remaining)) end
        if entry.status == "fighting" and Number(entry.healthFraction) then
            return T.EncounterHealthText(entry.hp, entry.maximum)
        end
        return DFRL.locale.Text(captions[entry.status] or "Empty")
    end
    local function HideTooltip(owner)
        if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    end
    local function ClearRow(row)
        if row.value ~= 0 then row.bar:SetValue(0) end
        row.value = 0
        if row.pill:IsShown() then row.pill:Hide() end
        if row:IsShown() then row:Hide() end
    end
    local function Clear()
        HideTooltip(toggle)
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
    local function Measure()
        statusWidth = math.max(128, healthWidth, CaptionWidth("Respawns in %s", "99:59") + 16)
        for _, source in pairs(captions) do
            statusWidth = math.max(statusWidth, CaptionWidth(source) + 16)
        end
        local titleWidth = CaptionWidth("GUARDIANS", nil, 14)
        if titleWidth <= 0 then return false end
        width = math.max(WIDTH, statusWidth + NAME_WIDTH + COLUMN_GAP + 2 * ROW_INSET, titleWidth + 88)
        local resized = not T.NearlyEqual(width, frame:GetWidth())
        if presentation.measuredWidth ~= width then
            title:SetWidth(width - 88)
            frame:SetWidth(width)
            header:SetWidth(width)
            header:SetHeight(width / 8)
            presentation.measuredWidth = width
        end
        if resized then DFRL.layout.Place("guardianTracker", frame) end
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
        if presentation.measureSize ~= T.EncounterHealthStyle.fontSize then
            T.SetFont(measure, T.EncounterHealthStyle.fontSize, "OUTLINE")
            presentation.measureSize = T.EncounterHealthStyle.fontSize
        end
        for _, entry in ipairs(snapshot.rows) do
            if entry.status == "fighting" and Number(entry.healthFraction) then
                local text = T.EncounterHealthText(entry.hp, entry.maximum)
                local cached = presentation.healthText == text and presentation.healthMeasured
                if not cached then measure:SetText(text) end
                local measured = cached or math.ceil(measure:GetStringWidth() or 0) + 16
                presentation.healthText, presentation.healthMeasured = text, measured
                if measured > healthWidth then
                    healthWidth, dirty = measured, true
                end
            end
        end
        if dirty then
            if not Measure() then
                Clear()
                return
            end
            dirty = false
        end
        UpdateToggle()
        T.SetTextIfChanged(title, DFRL.locale.Text("GUARDIANS"))
        local used = 0
        for _, entry in ipairs(snapshot.rows) do
            if expanded or entry.state == "asleep" or entry.state == "awake" then
                used = used + 1
                local row = rows[used] or MakeRow()
                if row.layoutWidth ~= width or row.layoutIndex ~= used or row.statusWidth ~= statusWidth then
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_INSET, -(width / 8 + 6 + (used - 1) * ROW_HEIGHT))
                    row:SetWidth(width - 2 * ROW_INSET)
                    row.name:SetWidth(width - statusWidth - 2 * ROW_INSET - COLUMN_GAP)
                    row.status:SetWidth(statusWidth)
                    row.pill:SetWidth(statusWidth + 8)
                    row.layoutWidth, row.layoutIndex, row.statusWidth = width, used, statusWidth
                end
                T.SetTextIfChanged(row.name, entry.name or Format("Lair %d", entry.index))
                local color = colors[entry.status] or colors.empty
                if row.color ~= color then
                    row.status:SetTextColor(color[1], color[2], color[3])
                    row.color = color
                end
                -- Only the native fighting state with valid current health gets a
                -- bar. Every other state clears the old fill before showing text.
                if entry.state == "awake" and Number(entry.healthFraction) then
                    if row.value ~= entry.healthFraction then row.bar:SetValue(entry.healthFraction) end
                    row.value = entry.healthFraction
                    T.SetTextIfChanged(row.health, Status(entry))
                    if row.status:IsShown() then row.status:Hide() end
                    if not row.pill:IsShown() then row.pill:Show() end
                else
                    if row.value ~= 0 then row.bar:SetValue(0) end
                    row.value = 0
                    if row.pill:IsShown() then row.pill:Hide() end
                    T.SetTextIfChanged(row.status, Status(entry))
                    if not row.status:IsShown() then row.status:Show() end
                end
                if not row:IsShown() then row:Show() end
            end
        end
        for index = used + 1, table.getn(rows) do
            ClearRow(rows[index])
        end
        local height = width / 8 + 12 + used * ROW_HEIGHT
        if not T.NearlyEqual(frame:GetHeight(), height) then frame:SetHeight(height) end
    end
    toggle:SetScript("OnClick", function()
        if editing or not inWorld then return end
        expanded = not expanded
        HideTooltip(toggle)
        Refresh()
    end)
    toggle:SetScript("OnEnter", function()
        if editing or not GameTooltip then return end
        GameTooltip:SetOwner(toggle, "ANCHOR_LEFT")
        GameTooltip:SetText(DFRL.locale.Text(expanded and "Show living guardians only" or "Show all lairs"))
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() HideTooltip(toggle) end)
    DFRL.layout.Register("guardianTracker", frame, function()
        -- Match the health pill's right edge to the default minimap right edge.
        local right = minimapDefaults.right / DEFAULT_SCALE + ROW_INSET - HEALTH_RIGHT_OFFSET
        frame:ClearAllPoints()
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", right, -252 / DEFAULT_SCALE)
    end, {
        labelAbove = true,
        refreshDefault = true,
        onEdit = function(active)
            editing = active
            HideTooltip(toggle)
            toggle:EnableMouse(not active)
            if active then
                toggle:Disable()
            else
                toggle:Enable()
            end
        end,
        onReset = function()
            expanded = true
            Refresh()
        end,
    })
    DFRL.locale.Listen(function()
        presentation.healthText, presentation.healthMeasured = nil, nil
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
        dirty, age = true, 0.1
        SyncUpdates()
        if permitted then Refresh() end
    end)
end)
