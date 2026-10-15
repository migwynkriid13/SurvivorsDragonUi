-- Azeroth Survivors 0.87.0+ supplies these APIs before addon initialization.
-- The clock, encounters and run counters are owned by the game; this module draws them.
DFRL:NewMod("RunTimers", 5, function()
    local path = DFRL:GetInfoOrCons("tex") .. "timer\\"
    local BAR_WIDTH = 280
    local ROW_HEIGHT = 48
    local SKULL_ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    local ATTACK_ICON = "Interface\\Cursor\\Attack.blp"
    local CACHE_ICON = "Interface\\Cursor\\LootAll.blp"
    local COINS_ICON = DFRL:GetInfoOrCons("tex") .. "chat\\cleaner_coins.tga"
    local MARKER_SIZE = 18
    local PHASES = {
        ready = true,
        playing = true,
        choosing = true,
        paused = true,
        dead = true,
        victory = true,
    }

    local function IsNumber(value) return type(value) == "number" and value >= 0 and value - value == 0 end

    local function Clock(seconds)
        seconds = math.floor(seconds)
        return string.format("%02d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
    end

    local function Read(name)
        if type(getglobal(name)) ~= "function" then return nil end
        local ok, value = pcall(getglobal(name))
        if ok then return value end
        return nil
    end

    local function RunLength()
        local maximum = Read("AZS_GetRunLength")
        if IsNumber(maximum) and maximum > 0 then return maximum end
        -- ReloadUI creates fresh Lua tables, but AZSZONE is only sent once
        -- per run. The recurring AZSRUN line carries the same native final-
        -- boss time in fin, so no guessed duration or local clock is needed.
        local state = AZS_RUN
        if type(state) == "table" and IsNumber(state.fin) and state.fin > 0 then return state.fin end
        return nil
    end

    local function Texture(parent, name, layer, width, height, right, bottom)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetTexture(path .. name .. ".tga")
        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetTexCoord(0, right, 0, bottom)
        return texture
    end

    local function Pill(name, fillName)
        local frame = CreateFrame("Frame", name, UIParent)
        frame:SetWidth(BAR_WIDTH + 16)
        frame:SetHeight(31)
        frame:SetFrameStrata("HIGH")
        frame:EnableMouse(false)

        local backgroundLeft = Texture(frame, "BackgroundLeft", "BACKGROUND", 29, 18, 29 / 32, 18 / 32)
        backgroundLeft:SetPoint("LEFT", frame, "LEFT", 6, 0)
        local backgroundRight = Texture(frame, "BackgroundRight", "BACKGROUND", 29, 18, 29 / 32, 18 / 32)
        backgroundRight:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
        local backgroundCenter = Texture(frame, "BackgroundCenter", "BACKGROUND", BAR_WIDTH - 54, 18, 1, 18 / 32)
        backgroundCenter:SetPoint("LEFT", backgroundLeft, "RIGHT", 0, 0)
        backgroundCenter:SetPoint("RIGHT", backgroundRight, "LEFT", 0, 0)

        local bar = CreateFrame("StatusBar", nil, frame)
        bar:SetHeight(15)
        bar:SetPoint("LEFT", frame, "LEFT", 8, 0)
        bar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        bar:SetMinMaxValues(0, 1)
        bar:SetStatusBarTexture(path .. fillName .. ".tga")
        bar:SetValue(0)

        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        overlay:SetFrameLevel(bar:GetFrameLevel() + 1)
        local left = Texture(overlay, "BorderLeft", "OVERLAY", 35, 31, 35 / 64, 31 / 32)
        left:SetPoint("LEFT", frame, "LEFT", 0, 0)
        local right = Texture(overlay, "BorderRight", "OVERLAY", 35, 31, 35 / 64, 31 / 32)
        right:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        local center = Texture(overlay, "BorderCenter", "OVERLAY", BAR_WIDTH - 54, 31, 1, 31 / 32)
        center:SetPoint("LEFT", left, "RIGHT", 0, 0)
        center:SetPoint("RIGHT", right, "LEFT", 0, 0)

        local text = overlay:CreateFontString(nil, "OVERLAY")
        text:SetFont("DEFAULT", 14, "OUTLINE")
        text:SetPoint("BOTTOM", frame, "TOP", 0, 2)
        text:SetTextColor(1, 1, 1)
        frame:Hide()
        return frame, bar, text, overlay
    end

    local run, runBar, runText, overlay = Pill("DFRL_RunTimerPill", "FillBlue")
    local runMoveRegion = CreateFrame("Frame", nil, run)
    local fontFaces = {
        { label = "Game DEFAULT", face = "DEFAULT" },
        { label = "Friz Quadrata", face = "Fonts\\FRIZQT__.TTF" },
        { label = "Arial Narrow", face = "Fonts\\ARIALN.TTF" },
        { label = "Morpheus", face = "Fonts\\MORPHEUS.TTF" },
        { label = "Skurri", face = "Fonts\\SKURRI.TTF" },
    }
    local fontOutlines = {
        { label = "None", value = "" },
        { label = "Outline", value = "OUTLINE" },
        { label = "Thick outline", value = "THICKOUTLINE" },
    }
    local fontDefaults = { face = "Fonts\\MORPHEUS.TTF", size = 14, outline = "OUTLINE", shadow = true }
    local currentFont, fontDraft, fontEditor, fontSample, fontMenu
    local faceLabel, sizeLabel, outlineLabel, shadowLabel

    local function FontSettings(value)
        value = type(value) == "table" and value or {}
        local settings = {
            face = fontDefaults.face,
            size = fontDefaults.size,
            outline = fontDefaults.outline,
            shadow = fontDefaults.shadow,
        }
        for _, entry in ipairs(fontFaces) do
            if value.face == entry.face then settings.face = entry.face end
        end
        for _, entry in ipairs(fontOutlines) do
            if value.outline == entry.value then settings.outline = entry.value end
        end
        if IsNumber(value.size) then settings.size = math.max(8, math.min(32, math.floor(value.size))) end
        if type(value.shadow) == "boolean" then settings.shadow = value.shadow end
        return settings
    end

    local function ApplyFont(text, settings)
        -- Initialize the game's DEFAULT face first so a missing native face
        -- leaves readable text at the requested size and outline.
        text:SetFont("DEFAULT", settings.size, settings.outline)
        if settings.face ~= "DEFAULT" then pcall(text.SetFont, text, settings.face, settings.size, settings.outline) end
        text:SetShadowColor(0, 0, 0, settings.shadow and 1 or 0)
        text:SetShadowOffset(settings.shadow and 1 or 0, settings.shadow and -1 or 0)
    end

    local function UpdateRunFontBounds()
        local width = runText:GetStringWidth() or 0
        local overflow = math.max(0, (width + 8 - run:GetWidth()) / 2)
        runMoveRegion:ClearAllPoints()
        runMoveRegion:SetPoint("TOPLEFT", run, "TOPLEFT", -overflow, currentFont.size + 4)
        runMoveRegion:SetPoint("BOTTOMRIGHT", run, "BOTTOMRIGHT", overflow, 0)
    end

    local function PreviewFont(settings)
        currentFont = FontSettings(settings)
        ApplyFont(runText, currentFont)
        UpdateRunFontBounds()
        if not fontEditor then return end
        ApplyFont(fontSample, currentFont)
        for _, entry in ipairs(fontFaces) do
            if currentFont.face == entry.face then faceLabel:SetText(entry.label) end
        end
        for _, entry in ipairs(fontOutlines) do
            if currentFont.outline == entry.value then outlineLabel:SetText(entry.label) end
        end
        sizeLabel:SetText(tostring(currentFont.size))
        shadowLabel:SetText(currentFont.shadow and "Shadow: on" or "Shadow: off")
    end

    local function FontEditorLabel(parent, text, x, y, size)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetFont("DEFAULT", size or 12, "OUTLINE")
        label:SetTextColor(1, 1, 1)
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetText(text)
        return label
    end

    local function FontEditorButton(text, width, x, y, callback, parent)
        parent = parent or fontEditor
        local button = T.CreateButton(parent, "", width, 28)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        local label = button:CreateFontString(nil, "OVERLAY")
        label:SetFont("DEFAULT", 12, "OUTLINE")
        label:SetTextColor(1, 1, 1)
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
        label:SetText(text)
        button:SetScript("OnClick", callback)
        return label, button
    end

    local function ChangeSize(direction)
        if not fontDraft then return end
        fontDraft.size = math.max(8, math.min(32, fontDraft.size + direction))
        PreviewFont(fontDraft)
    end

    local function CreateFontEditor()
        fontEditor = T.CreateDFRLFrame(UIParent, 440, 254)
        fontEditor:SetFrameStrata("TOOLTIP")
        fontEditor:SetFrameLevel(150)
        fontEditor:SetPoint("TOP", UIParent, "CENTER", 0, -25)
        fontSample = FontEditorLabel(fontEditor, "RUN font preview", 16, -57)
        fontSample:ClearAllPoints()
        fontSample:SetPoint("TOP", fontEditor, "TOP", 0, -56)

        FontEditorLabel(fontEditor, "Font", 16, -104)
        local fontButton
        faceLabel, fontButton = FontEditorButton("", 352, 72, -96, function()
            if not fontDraft then return end
            if fontMenu:IsShown() then
                fontMenu:Hide()
            else
                fontMenu:Show()
            end
        end)
        local arrow = FontEditorLabel(fontButton, "v", 0, 0)
        arrow:ClearAllPoints()
        arrow:SetPoint("RIGHT", fontButton, "RIGHT", -12, 0)

        -- The popup catches outside clicks while its list stays above the editor.
        fontMenu = CreateFrame("Button", nil, fontEditor)
        fontMenu:SetAllPoints(UIParent)
        fontMenu:SetFrameLevel(160)
        fontMenu:EnableMouse(true)
        fontMenu:SetScript("OnClick", function() fontMenu:Hide() end)
        fontMenu:Hide()
        local fontList = T.CreateDFRLFrame(fontMenu, 352, table.getn(fontFaces) * 28 + 8)
        fontList:SetFrameLevel(170)
        fontList:SetPoint("TOPLEFT", fontButton, "BOTTOMLEFT", 0, 0)
        for index, entry in ipairs(fontFaces) do
            local selectedFace = entry.face
            FontEditorButton(entry.label, 344, 4, -4 - (index - 1) * 28, function()
                if not fontDraft then return end
                fontDraft.face = selectedFace
                PreviewFont(fontDraft)
                fontMenu:Hide()
            end, fontList)
        end
        fontEditor:SetScript("OnHide", function() fontMenu:Hide() end)
        FontEditorLabel(fontEditor, "Size", 16, -137)
        FontEditorButton("-", 32, 72, -129, function() ChangeSize(-1) end)
        sizeLabel = FontEditorLabel(fontEditor, "", 115, -137)
        FontEditorButton("+", 32, 146, -129, function() ChangeSize(1) end)
        outlineLabel = FontEditorButton("", 130, 188, -129, function()
            if not fontDraft then return end
            for index, entry in ipairs(fontOutlines) do
                if fontDraft.outline == entry.value then
                    fontDraft.outline = fontOutlines[math.mod(index, table.getn(fontOutlines)) + 1].value
                    break
                end
            end
            PreviewFont(fontDraft)
        end)
        shadowLabel = FontEditorButton("", 102, 322, -129, function()
            if not fontDraft then return end
            fontDraft.shadow = not fontDraft.shadow
            PreviewFont(fontDraft)
        end)
        FontEditorButton("Addon defaults", 140, 16, -164, function() DFRL.layout.Reset() end)
    end

    local function EditRunFont(active, save)
        if active then
            fontDraft = FontSettings(_G.SurvivorsDragonUiRunFont)
            if not fontEditor then CreateFontEditor() end
            PreviewFont(fontDraft)
            fontEditor:Show()
        else
            if save and fontDraft then _G.SurvivorsDragonUiRunFont = FontSettings(fontDraft) end
            fontDraft = nil
            PreviewFont(_G.SurvivorsDragonUiRunFont)
            if fontEditor then fontEditor:Hide() end
        end
    end

    PreviewFont(_G.SurvivorsDragonUiRunFont)
    DFRL.layout.Register("runTimer", run, function()
        run:ClearAllPoints()
        run:SetPoint("TOP", UIParent, "TOP", 0, -30)
    end, {
        region = runMoveRegion,
        onEdit = EditRunFont,
        onReset = function()
            _G.SurvivorsDragonUiRunFont = nil
            fontDraft = nil
            PreviewFont(nil)
            if fontEditor then fontEditor:Hide() end
        end,
    })

    -- Encounters share a movable group, independent of the run clock.
    -- Its bounds include the first name and every stacked health pill.
    local bossGroup = CreateFrame("Frame", "DFRL_BossHealthGroup", UIParent)
    bossGroup:SetWidth(BAR_WIDTH + 16)
    bossGroup:SetHeight(47)
    bossGroup:SetFrameStrata("HIGH")
    bossGroup:Hide()
    DFRL.layout.Register("bossBars", bossGroup, function()
        bossGroup:ClearAllPoints()
        bossGroup:SetPoint("TOP", UIParent, "TOP", 0, -77)
    end)

    local tally, tallyBar, tallyTitle, tallyOverlay = Pill("DFRL_RunTallyPill", "FillYellow")
    tallyBar:SetValue(1)
    tallyBar:SetAlpha(0.4)
    tallyTitle:Hide()
    local tallyFields = {}
    local tallyAttached = false
    local tallyRegistered = false
    local fieldWidth = BAR_WIDTH / 3
    local counters = {
        { key = "kills", label = "Enemies killed", icon = ATTACK_ICON },
        { key = "gold", label = "Gold", icon = COINS_ICON },
        { key = "chest", label = "Next cache cost (gold)", icon = CACHE_ICON },
    }
    for index, counter in ipairs(counters) do
        local field = CreateFrame("Frame", nil, tallyOverlay)
        field:SetWidth(fieldWidth)
        field:SetHeight(20)
        field:SetPoint("LEFT", tally, "LEFT", 8 + (index - 1) * fieldWidth, 0)
        field:EnableMouse(true)

        local icon = field:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(counter.icon)
        if counter.key == "gold" then
            -- CleanerChat's 64x64 atlas places gold in the top-left 32x32.
            icon:SetTexCoord(0, 0.5, 0, 0.5)
        end
        icon:SetWidth(18)
        icon:SetHeight(18)
        icon:SetPoint("LEFT", field, "LEFT", 5, 0)

        local text = field:CreateFontString(nil, "OVERLAY")
        text:SetFont("DEFAULT", 12, "OUTLINE")
        text:SetTextColor(1, 0.88, 0.55)
        text:SetWidth(fieldWidth - 48)
        text:SetHeight(18)
        text:SetPoint("CENTER", field, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        local entry = { key = counter.key, label = counter.label, text = text, frame = field }
        table.insert(tallyFields, entry)
        field:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:AddLine(entry.label, 1, 0.82, 0)
            GameTooltip:AddLine(entry.text:GetText() or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        field:SetScript("OnLeave", function() GameTooltip:Hide() end)
        field:SetScript("OnHide", function()
            if GameTooltip:IsOwned(this) then GameTooltip:Hide() end
        end)

        if index > 1 then
            local divider = tallyOverlay:CreateTexture(nil, "ARTWORK")
            divider:SetTexture("Interface\\Buttons\\WHITE8X8")
            divider:SetVertexColor(0.9, 0.7, 0.3, 0.6)
            divider:SetWidth(1)
            divider:SetHeight(15)
            divider:SetPoint("LEFT", field, "LEFT", 0, 0)
        end
    end

    function DFRL.AttachRunTally()
        local xp = DFRL.xpBar
        if not xp or not DFRL.mainBar then return false end
        local width = xp:GetWidth()
        if not IsNumber(width) or width <= 70 then return false end
        -- Match XP's artwork width without making either group follow the
        -- other's position. Maximum XP also cannot hide the tally.
        tally:SetWidth(width)
        if not tallyRegistered then
            DFRL.layout.Register("runTally", tally, function()
                tally:ClearAllPoints()
                tally:SetPoint("TOP", UIParent, "BOTTOM", 0, 39)
            end)
            tallyRegistered = true
        else
            DFRL.layout.Place("runTally", tally)
        end
        local sectionWidth = (width - 16) / table.getn(tallyFields)
        for index, entry in ipairs(tallyFields) do
            entry.frame:SetWidth(sectionWidth)
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("LEFT", tally, "LEFT", 8 + (index - 1) * sectionWidth, 0)
            entry.text:SetWidth(sectionWidth - 48)
        end
        tallyAttached = true
        return true
    end
    DFRL.AttachRunTally()

    local markers = {}
    local markerTimes = {}
    local activeRows = {}
    local spareRows = {}
    local createdRows = 0
    local nativeParts = {}
    local inWorld = true
    local pollAge = 0
    local refreshRows = true
    local previousTime
    local previousZone

    local function Shown(value)
        if value == true or value == 1 or value == "1" then return true end
        if value == false or value == 0 or value == "0" then return false end
        return nil
    end

    local function TakeOver(part)
        if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then return false end
        local ok, value = pcall(AZS_IsHudShown, part)
        if not ok then return false end
        local shown = Shown(value)
        if shown == nil then return false end
        if not nativeParts[part] then nativeParts[part] = { shown = shown } end
        if shown then
            ok = pcall(AZS_SetHudShown, part, false)
            if not ok then return false end
            local checked, now = pcall(AZS_IsHudShown, part)
            return checked and Shown(now) == false
        end
        return true
    end

    local function Restore(part)
        local original = nativeParts[part]
        if not original or type(AZS_SetHudShown) ~= "function" then return end
        if pcall(AZS_SetHudShown, part, original.shown) then nativeParts[part] = nil end
    end

    local function ClearTally()
        tally:Hide()
        for _, field in ipairs(tallyFields) do
            field.text:SetText("")
        end
        Restore("tally")
    end

    local function UpdateTally()
        local state = AZS_RUN
        -- Zero is a valid counter or free cache. Missing fields must not be
        -- replaced by invented values while the native overlay is hidden.
        if
            type(state) ~= "table"
            or not IsNumber(state.kills)
            or not IsNumber(state.gold)
            or not IsNumber(state.chest)
        then
            ClearTally()
            return
        end
        if not tallyAttached and not DFRL.AttachRunTally() then
            ClearTally()
            return
        end
        for _, field in ipairs(tallyFields) do
            field.text:SetText(tostring(math.floor(state[field.key])))
        end
        tally:Show()
        if not TakeOver("tally") then ClearTally() end
    end

    local function Retire(row)
        row.frame:Hide()
        row.name:SetText("")
        row.health:SetText("")
        row.bar:SetValue(0)
        table.insert(spareRows, row)
    end

    local function ClearRows()
        for key, row in pairs(activeRows) do
            Retire(row)
            activeRows[key] = nil
        end
        bossGroup:Hide()
    end

    local function ReleaseClock()
        run:Hide()
        for _, marker in ipairs(markers) do
            marker:Hide()
        end
        Restore("clock")
    end

    local function ReleaseHUD()
        ReleaseClock()
        ClearTally()
        ClearRows()
        Restore("bosses")
        previousTime = nil
        previousZone = nil
        refreshRows = true
    end

    local function ScheduleTimes(maximum)
        local schedule = AZS_SCHEDULE
        if type(schedule) ~= "table" then return nil end
        local state, zone = AZS_RUN, AZS_ZONE
        local expected = type(state) == "table" and state.bt or nil
        if not IsNumber(expected) or expected <= 0 then expected = type(zone) == "table" and zone.bt or nil end
        if not IsNumber(expected) or expected <= 0 or expected ~= math.floor(expected) then return nil end

        local times = {}
        local seen, final = {}, false
        -- An empty table after /reload is not a received schedule. Require
        -- every zone boss, including those already up/dead, and matching native
        -- final-boss time before drawing markers. Clock recovery is independent.
        for _, entry in ipairs(schedule) do
            if
                type(entry) ~= "table"
                or not IsNumber(entry.index)
                or entry.index ~= math.floor(entry.index)
                or seen[entry.index]
                or not IsNumber(entry.at)
                or entry.at <= 0
                or entry.at > maximum
            then
                return nil
            end
            seen[entry.index] = true
            if entry.final == 1 or entry.final == true then
                if final or entry.at ~= maximum then return nil end
                final = true
            end
            table.insert(times, entry.at)
        end
        if table.getn(times) ~= expected or not final then return nil end
        return times
    end

    local function UpdateMarkers(maximum, times)
        for index, at in ipairs(times) do
            local marker = markers[index]
            if not marker then
                marker = overlay:CreateTexture(nil, "OVERLAY")
                marker:SetTexture(SKULL_ICON)
                marker:SetWidth(MARKER_SIZE)
                marker:SetHeight(MARKER_SIZE)
                markers[index] = marker
            end
            markerTimes[index] = at
            marker:ClearAllPoints()
            if at == maximum then
                marker:SetPoint("RIGHT", runBar, "RIGHT", 0, 0)
            else
                marker:SetPoint("CENTER", runBar, "LEFT", BAR_WIDTH * at / maximum, 0)
            end
        end
        for index = table.getn(times) + 1, table.getn(markers) do
            markerTimes[index] = nil
            markers[index]:Hide()
        end
    end

    local function UpdateMarkerVisibility(seconds)
        -- Native pause-aware time owns expiry; no separate clock is advanced.
        for index, marker in ipairs(markers) do
            local at = markerTimes[index]
            if at and seconds < at then
                marker:Show()
            else
                marker:Hide()
            end
        end
    end

    local function EncounterRows()
        -- The API initializes its unit table to {} in each new Lua VM.
        -- Until an actual unit snapshot arrives after /reload, an empty
        -- getter result does not mean the native encounters disappeared.
        if not IsNumber(AZS_UNITS_UPDATED) then return nil end
        local bosses = Read("AZS_GetBosses")
        local guardians = Read("AZS_GetGuardians")
        -- The native "bosses" part includes guardians. Only awake guardians
        -- are fighting; the full list also includes sleeping lairs on the map.
        if type(bosses) ~= "table" or type(guardians) ~= "table" then return nil end
        local entries = {}
        local seen = {}
        local function Append(list, kind)
            for _, entry in ipairs(list) do
                if type(entry) ~= "table" then return false end
                -- Getter flags are booleans; also accept the native 1 form.
                -- Lua considers 0 truthy, so do not test awake by truthiness.
                local engaged = kind ~= "guardian" or entry.awake == true or entry.awake == 1
                if engaged then
                    if
                        not IsNumber(entry.id)
                        or entry.id ~= math.floor(entry.id)
                        or type(entry.name) ~= "string"
                        or entry.name == ""
                        or not IsNumber(entry.hp)
                        or not IsNumber(entry.hpm)
                        or entry.hpm <= 0
                    then
                        return false
                    end
                    local key = kind .. ":" .. tostring(entry.id)
                    if seen[key] then return false end
                    seen[key] = true
                    table.insert(entries, { key = key, name = entry.name, hp = entry.hp, maximum = entry.hpm })
                end
            end
            return true
        end
        if not Append(bosses, "boss") or not Append(guardians, "guardian") then return nil end
        return entries, seen
    end

    local function NewRow()
        local row = table.remove(spareRows)
        if row then return row end
        createdRows = createdRows + 1
        local frame, bar, name, rowOverlay = Pill("DFRL_BossHealthPill" .. tostring(createdRows), "FillWhite")
        frame:SetParent(bossGroup)
        bar:SetStatusBarColor(0.86, 0.12, 0.1, 1)
        name:SetFont("DEFAULT", 12, "OUTLINE")
        name:SetWidth(BAR_WIDTH)
        local health = rowOverlay:CreateFontString(nil, "OVERLAY")
        health:SetFont("DEFAULT", 12, "OUTLINE")
        health:SetPoint("CENTER", frame, "CENTER", 0, 0)
        health:SetTextColor(1, 1, 1)
        return { frame = frame, bar = bar, name = name, health = health }
    end

    local function UpdateRows()
        local entries, seen = EncounterRows()
        if not entries then
            ClearRows()
            Restore("bosses")
            return
        end
        for key, row in pairs(activeRows) do
            if not seen[key] then
                Retire(row)
                activeRows[key] = nil
            end
        end
        local count = table.getn(entries)
        bossGroup:SetHeight(47 + math.max(0, count - 1) * ROW_HEIGHT)
        DFRL.layout.Place("bossBars", bossGroup)
        if count > 0 then
            bossGroup:Show()
        else
            bossGroup:Hide()
        end
        for index, entry in ipairs(entries) do
            local row = activeRows[entry.key]
            if not row then
                row = NewRow()
                activeRows[entry.key] = row
            end
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOP", bossGroup, "TOP", 0, -16 - (index - 1) * ROW_HEIGHT)
            row.bar:SetValue(math.min(1, entry.hp / entry.maximum))
            row.name:SetText(entry.name)
            row.health:SetText(tostring(math.floor(entry.hp)) .. " / " .. tostring(math.floor(entry.maximum)))
            row.frame:Show()
        end
        if not TakeOver("bosses") then
            ClearRows()
            Restore("bosses")
        end
    end

    local function Update()
        if not inWorld then
            ReleaseHUD()
            return
        end
        -- Out-of-run tables can retain the previous run. Phase must be read
        -- first; no old table values or invented clocks may stand in for it.
        local phase = Read("AZS_GetPhase")
        if not PHASES[phase] then
            ReleaseHUD()
            return
        end
        local seconds = Read("AZS_GetRunTime")
        local maximum = RunLength()
        local zone = type(AZS_ZONE) == "table" and AZS_ZONE.zone or nil
        if previousZone ~= zone or (previousTime and IsNumber(seconds) and seconds < previousTime) then
            ClearRows()
            refreshRows = true
        end
        previousZone = zone
        if IsNumber(seconds) then previousTime = seconds end
        local times = maximum and ScheduleTimes(maximum) or nil
        if IsNumber(seconds) and maximum then
            runBar:SetMinMaxValues(0, maximum)
            runBar:SetValue(math.min(maximum, seconds))
            local clockText = "RUN " .. Clock(seconds) .. " / " .. Clock(maximum)
            if runText:GetText() ~= clockText then
                runText:SetText(clockText)
                UpdateRunFontBounds()
            end
            -- Missing schedule replay affects only spawn markers, never a clock
            -- whose native elapsed time and duration have already recovered.
            if refreshRows or not run:IsShown() or not times then UpdateMarkers(maximum, times or {}) end
            UpdateMarkerVisibility(seconds)
            run:Show()
            if not TakeOver("clock") then ReleaseClock() end
        else
            ReleaseClock()
        end
        -- A missing zone/clock snapshot must not block valid counters or
        -- encounter lists from reconnecting to their own native HUD parts.
        if refreshRows then
            refreshRows = false
            UpdateTally()
            UpdateRows()
        end
    end

    local reader = CreateFrame("Frame", "DFRL_NativeHUDReader", UIParent)
    reader:RegisterEvent("CHAT_MSG_ADDON")
    reader:RegisterEvent("PLAYER_ENTERING_WORLD")
    reader:RegisterEvent("PLAYER_LEAVING_WORLD")
    reader:RegisterEvent("PLAYER_LOGOUT")
    reader:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            ReleaseHUD()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            refreshRows = true
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 ~= "AZSZONE" and arg1 ~= "AZSRUN" and arg1 ~= "AZSBOSSES" and arg1 ~= "AZSUNITS" then return end
            refreshRows = true
        end
        Update()
    end)
    reader:SetScript("OnUpdate", function()
        -- Only list/marker placement refreshes are throttled. The clock and
        -- skull visibility use AZS_GetRunTime() every frame, including pauses.
        pollAge = pollAge + (tonumber(arg1) or 0)
        if pollAge >= 0.1 then
            pollAge = 0
            refreshRows = true
        end
        Update()
    end)
    Update()
end)
