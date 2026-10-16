-- Azeroth Survivors 0.87.0+ supplies these APIs before addon initialization.
-- The clock, encounters and run counters are owned by the game; this module draws them.
DFRL:NewMod("RunTimers", 5, function()
    local path = DFRL:GetInfoOrCons("tex") .. "timer\\"
    local BAR_WIDTH = 280
    local ROW_HEIGHT = 48
    local DEBUFF_SIZE, DEBUFF_GAP = 18, 4
    local DEBUFF_COLUMNS = math.floor((BAR_WIDTH + DEBUFF_GAP) / (DEBUFF_SIZE + DEBUFF_GAP))
    local SKULL_ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    local CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"
    local ATTACK_ICON = "Interface\\Cursor\\Attack.blp"
    local CACHE_ICON = "Interface\\Cursor\\LootAll.blp"
    local COINS_ICON = DFRL:GetInfoOrCons("tex") .. "chat\\cleaner_coins.tga"
    local MARKER_SIZE = 18
    local DEAD_MARKER_SCALE = 0.8
    local DEAD_MARKER_ALPHA = 0.7
    local ACTIVE_GLOW_PERIOD = 2.4
    local ACTIVE_GLOW_MIN_ALPHA, ACTIVE_GLOW_MAX_ALPHA = 0.25, 0.5
    local ACTIVE_GLOW_MIN_OFFSET, ACTIVE_GLOW_MAX_OFFSET = 0.9, 4.55
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
    local fontDefaults = {
        face = "Fonts\\SKURRI.TTF",
        size = 14,
        outline = "OUTLINE",
        shadow = true,
        showText = true,
    }
    local currentFont, fontDraft, fontEditor, fontSample, fontMenu
    local faceLabel, sizeLabel, outlineLabel, shadowLabel, visibilityLabel
    local debuffsLabel, damageIconsLabel, classResourcesLabel
    local cacheGuidanceLabel, guardianGuidanceLabel

    local function UpdateDisplayLabels()
        if debuffsLabel then
            debuffsLabel:SetText(DFRL.display.Get("bossDebuffs") and "Boss debuffs: on" or "Boss debuffs: off")
            damageIconsLabel:SetText(DFRL.display.Get("damageIcons") and "Damage icons: on" or "Damage icons: off")
            classResourcesLabel:SetText(
                DFRL.display.Get("classResources") and "Class resources: on" or "Class resources: off"
            )
            cacheGuidanceLabel:SetText(
                DFRL.display.Get("cacheGuidance") and "Cache guidance: on" or "Cache guidance: off"
            )
            guardianGuidanceLabel:SetText(
                DFRL.display.Get("guardianGuidance") and "Guardian guidance: on" or "Guardian guidance: off"
            )
        end
    end

    local function FontSettings(value)
        value = type(value) == "table" and value or {}
        local settings = {
            face = fontDefaults.face,
            size = fontDefaults.size,
            outline = fontDefaults.outline,
            shadow = fontDefaults.shadow,
            showText = fontDefaults.showText,
        }
        for _, entry in ipairs(fontFaces) do
            if value.face == entry.face then settings.face = entry.face end
        end
        for _, entry in ipairs(fontOutlines) do
            if value.outline == entry.value then settings.outline = entry.value end
        end
        if IsNumber(value.size) then settings.size = math.max(8, math.min(32, math.floor(value.size))) end
        if type(value.shadow) == "boolean" then settings.shadow = value.shadow end
        if type(value.showText) == "boolean" then settings.showText = value.showText end
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
        local width = currentFont.showText and (runText:GetStringWidth() or 0) or 0
        local overflow = math.max(0, (width + 8 - run:GetWidth()) / 2)
        local top = currentFont.showText and currentFont.size + 4 or 0
        runMoveRegion:ClearAllPoints()
        runMoveRegion:SetPoint("TOPLEFT", run, "TOPLEFT", -overflow, top)
        runMoveRegion:SetPoint("BOTTOMRIGHT", run, "BOTTOMRIGHT", overflow, 0)
    end

    local function PreviewFont(settings)
        currentFont = FontSettings(settings)
        ApplyFont(runText, currentFont)
        if currentFont.showText then
            runText:Show()
        else
            runText:Hide()
        end
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
        visibilityLabel:SetText(currentFont.showText and "Run text: shown" or "Run text: hidden")
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

    local function PlaceFontEditor()
        if not fontEditor then return end
        fontEditor:ClearAllPoints()
        fontEditor:SetPoint("TOP", UIParent, "CENTER", 0, -25)
    end

    local function FinishFontEditorDrag()
        if not fontEditor then return end
        fontEditor:StopMovingOrSizing()
        if fontEditor.SetUserPlaced then fontEditor:SetUserPlaced(false) end
    end

    local function CreateFontEditor()
        local measure = FontEditorLabel(UIParent, "", 0, 0)
        measure:Hide()
        local function TextWidth(text)
            measure:SetText(text)
            return math.ceil(measure:GetStringWidth() or 0)
        end
        local padding, gap = 12, 8
        local labelWidth = math.max(TextWidth("Font"), TextWidth("Size"))
        local dropdownWidth, outlineWidth = 0, 0
        for _, entry in ipairs(fontFaces) do
            dropdownWidth = math.max(dropdownWidth, TextWidth(entry.label) + 36)
        end
        for _, entry in ipairs(fontOutlines) do
            outlineWidth = math.max(outlineWidth, TextWidth(entry.label) + 24)
        end
        local shadowWidth = math.max(TextWidth("Shadow: on"), TextWidth("Shadow: off")) + 24
        local visibilityWidth = math.max(TextWidth("Run text: shown"), TextWidth("Run text: hidden")) + 24
        local defaultsWidth = TextWidth("Addon defaults") + 24
        local contentWidth = math.max(labelWidth + gap + dropdownWidth, outlineWidth + gap + shadowWidth)
        contentWidth = math.max(contentWidth, labelWidth + gap + 96, defaultsWidth, visibilityWidth)
        contentWidth = math.max(
            contentWidth,
            TextWidth("Boss debuffs: off") + 24,
            TextWidth("Damage icons: off") + 24,
            TextWidth("Class resources: off") + 24,
            TextWidth("Cache guidance: off") + 24,
            TextWidth("Guardian guidance: off") + 24
        )
        local width = contentWidth + padding * 2
        local inputX = padding + labelWidth + gap
        dropdownWidth = contentWidth - labelWidth - gap

        fontEditor = T.CreateDFRLFrame(UIParent, width, 398)
        fontEditor:SetFrameStrata("TOOLTIP")
        fontEditor:SetFrameLevel(150)
        PlaceFontEditor()
        fontEditor:SetMovable(true)
        if fontEditor.SetClampedToScreen then fontEditor:SetClampedToScreen(true) end
        fontEditor:RegisterForDrag("LeftButton")
        fontEditor:SetScript("OnDragStart", function()
            if not fontDraft then return end
            fontMenu:Hide()
            fontEditor:StartMoving()
        end)
        fontEditor:SetScript("OnDragStop", FinishFontEditorDrag)
        fontSample = FontEditorLabel(fontEditor, "RUN", padding, -12)
        fontSample:ClearAllPoints()
        fontSample:SetPoint("TOP", fontEditor, "TOP", 0, -12)

        FontEditorLabel(fontEditor, "Font", padding, -60)
        local fontButton
        faceLabel, fontButton = FontEditorButton("", dropdownWidth, inputX, -52, function()
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
        local fontList = T.CreateDFRLFrame(fontMenu, dropdownWidth, table.getn(fontFaces) * 28 + 8)
        fontList:SetFrameLevel(170)
        fontList:SetPoint("TOPLEFT", fontButton, "BOTTOMLEFT", 0, 0)
        for index, entry in ipairs(fontFaces) do
            local selectedFace = entry.face
            FontEditorButton(entry.label, dropdownWidth - 8, 4, -4 - (index - 1) * 28, function()
                if not fontDraft then return end
                fontDraft.face = selectedFace
                PreviewFont(fontDraft)
                fontMenu:Hide()
            end, fontList)
        end
        fontEditor:SetScript("OnHide", function()
            FinishFontEditorDrag()
            fontMenu:Hide()
        end)
        FontEditorLabel(fontEditor, "Size", padding, -94)
        FontEditorButton("-", 28, inputX, -86, function() ChangeSize(-1) end)
        sizeLabel = FontEditorLabel(fontEditor, "", inputX + 38, -94)
        FontEditorButton("+", 28, inputX + 68, -86, function() ChangeSize(1) end)
        outlineLabel = FontEditorButton("", outlineWidth, padding, -120, function()
            if not fontDraft then return end
            for index, entry in ipairs(fontOutlines) do
                if fontDraft.outline == entry.value then
                    fontDraft.outline = fontOutlines[math.mod(index, table.getn(fontOutlines)) + 1].value
                    break
                end
            end
            PreviewFont(fontDraft)
        end)
        shadowLabel = FontEditorButton("", shadowWidth, padding + outlineWidth + gap, -120, function()
            if not fontDraft then return end
            fontDraft.shadow = not fontDraft.shadow
            PreviewFont(fontDraft)
        end)
        visibilityLabel = FontEditorButton("", contentWidth, padding, -154, function()
            if not fontDraft then return end
            fontDraft.showText = not fontDraft.showText
            PreviewFont(fontDraft)
        end)
        debuffsLabel = FontEditorButton(
            "",
            contentWidth,
            padding,
            -188,
            function() DFRL.display.Set("bossDebuffs", not DFRL.display.Get("bossDebuffs")) end
        )
        damageIconsLabel = FontEditorButton(
            "",
            contentWidth,
            padding,
            -222,
            function() DFRL.display.Set("damageIcons", not DFRL.display.Get("damageIcons")) end
        )
        classResourcesLabel = FontEditorButton(
            "",
            contentWidth,
            padding,
            -256,
            function() DFRL.display.Set("classResources", not DFRL.display.Get("classResources")) end
        )
        cacheGuidanceLabel = FontEditorButton(
            "",
            contentWidth,
            padding,
            -290,
            function() DFRL.display.Set("cacheGuidance", not DFRL.display.Get("cacheGuidance")) end
        )
        guardianGuidanceLabel = FontEditorButton(
            "",
            contentWidth,
            padding,
            -324,
            function() DFRL.display.Set("guardianGuidance", not DFRL.display.Get("guardianGuidance")) end
        )
        UpdateDisplayLabels()
        FontEditorButton(
            "Addon defaults",
            defaultsWidth,
            (width - defaultsWidth) / 2,
            -358,
            function() DFRL.layout.Reset() end
        )
    end

    local function EditRunFont(active, save)
        if active then
            DFRL.display.BeginEdit()
            fontDraft = FontSettings(_G.SurvivorsDragonUiRunFont)
            if not fontEditor then CreateFontEditor() end
            PreviewFont(fontDraft)
            fontEditor:Show()
        else
            DFRL.display.FinishEdit(save)
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
            DFRL.display.Reset()
            _G.SurvivorsDragonUiRunFont = nil
            fontDraft = nil
            PreviewFont(nil)
            if fontEditor then fontEditor:Hide() end
            PlaceFontEditor()
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
    local markerStates = {}
    local activeRows = {}
    local rowOrder = {}
    local spareRows = {}
    local createdRows = 0
    local nativeParts = {}
    local inWorld = true
    local pollAge = 0
    local refreshRows = true
    local previousTime
    local previousZone
    local previousPhase, previousNativeTime
    local packetSequence, runSequence, scheduleSequence = 0, 0, 0
    local zoneSequence, zoneRunPending
    local scheduleBarrier = -1
    local reloading = false
    -- Only ReloadUI writes this handoff. Consume it once, keeping an initial
    -- nil phase from destroying it before the native API has replayed AZSRUN.
    local scheduleCache = _G.SurvivorsDragonUiBossSchedule
    _G.SurvivorsDragonUiBossSchedule = nil

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

    local function HideDebuff(icon)
        if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
        icon:Hide()
        icon.texture:SetTexture(nil)
        icon.count:SetText("")
        icon.time:SetText("")
        icon.effect = nil
    end

    local function ClearDebuffs(row)
        for _, icon in ipairs(row.debuffs) do
            HideDebuff(icon)
        end
        row.debuffHeight = 0
    end

    local function Retire(row)
        ClearDebuffs(row)
        row.frame:Hide()
        row.name:SetText("")
        row.health:SetText("")
        row.bar:SetValue(0)
        row.id, row.key = nil, nil
        table.insert(spareRows, row)
    end

    local function ClearRows()
        for key, row in pairs(activeRows) do
            Retire(row)
            activeRows[key] = nil
        end
        rowOrder = {}
        bossGroup:Hide()
    end

    local function ShowMarkerGlow(marker, shown)
        for _, glow in ipairs(marker.glow) do
            if shown then
                glow.texture:Show()
            else
                glow.texture:Hide()
            end
        end
    end

    local function HideMarker(marker)
        marker:Hide()
        marker.check:Hide()
        ShowMarkerGlow(marker, false)
        marker.state = nil
    end

    local function ReleaseClock()
        run:Hide()
        for _, marker in ipairs(markers) do
            HideMarker(marker)
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

    local function ExpectedBosses()
        local state, zone = AZS_RUN, AZS_ZONE
        local expected = type(state) == "table" and state.bt or nil
        if not IsNumber(expected) or expected <= 0 then expected = type(zone) == "table" and zone.bt or nil end
        if not IsNumber(expected) or expected <= 0 or expected ~= math.floor(expected) then return nil end
        return expected
    end

    local function ValidateSchedule(schedule, maximum, expected)
        if type(schedule) ~= "table" then return nil end
        local entries = {}
        local seen, final = {}, false
        -- An empty table after /reload is not a received schedule. Require
        -- every zone boss, including those already up/dead, and matching native
        -- final-boss time before drawing markers. Clock recovery is independent.
        for _, entry in ipairs(schedule) do
            if
                type(entry) ~= "table"
                or not IsNumber(entry.index)
                or entry.index ~= math.floor(entry.index)
                or entry.index < 1
                or entry.index > expected
                or seen[entry.index]
                or not IsNumber(entry.at)
                or entry.at <= 0
                or entry.at > maximum
                or (entry.state ~= "due" and entry.state ~= "up" and entry.state ~= "dead")
            then
                return nil
            end
            seen[entry.index] = true
            if entry.final == 1 or entry.final == true then
                if final or entry.at ~= maximum then return nil end
                final = true
            end
            table.insert(entries, {
                index = entry.index,
                at = entry.at,
                final = entry.final == 1 or entry.final == true,
                state = entry.state,
            })
        end
        if table.getn(entries) ~= expected or not final then return nil end
        return entries
    end

    local function ScheduleSample(maximum, expected)
        local state = AZS_RUN
        if type(state) ~= "table" or state.fin ~= maximum or state.bt ~= expected then return nil end
        for _, key in ipairs({ "t", "bs", "bk", "kills" }) do
            if not IsNumber(state[key]) then return nil end
        end
        return { t = state.t, bs = state.bs, bk = state.bk, kills = state.kills }
    end

    local function ScheduleMarkers(maximum, phase)
        local expected = ExpectedBosses()
        if not expected then return nil end
        local sample = not zoneRunPending and phase ~= "ready" and ScheduleSample(maximum, expected) or nil
        local entries
        -- After a known run boundary, retained native tables are not a fresh
        -- schedule. Packet order is recorded before reading the parsed tables.
        if scheduleSequence > scheduleBarrier then entries = ValidateSchedule(AZS_SCHEDULE, maximum, expected) end
        if entries then
            scheduleCache = nil
            if sample then
                local spawned, killed = 0, 0
                for _, entry in ipairs(entries) do
                    if entry.state ~= "due" then spawned = spawned + 1 end
                    if entry.state == "dead" then killed = killed + 1 end
                end
                -- The two prefixes can arrive separately. Never stamp new run
                -- counters onto old schedule states for the next reload.
                if spawned == math.min(expected, sample.bs) and killed == math.min(expected, sample.bk) then
                    scheduleCache = {
                        version = 1,
                        maximum = maximum,
                        expected = expected,
                        hero = UnitName("player"),
                        entries = entries,
                        sample = sample,
                    }
                end
            end
            return entries
        end
        -- A cache never supplies phase, time, length or boss count. Wait for
        -- native data, including a raw clock sample rather than interpolation.
        if not sample then return nil end
        local cache = scheduleCache
        local saved = type(cache) == "table" and cache.sample or nil
        if
            type(cache) ~= "table"
            or cache.version ~= 1
            or cache.maximum ~= maximum
            or cache.expected ~= expected
            or cache.hero ~= UnitName("player")
            or type(saved) ~= "table"
            or not IsNumber(saved.t)
            or not IsNumber(saved.kills)
            or sample.t < saved.t
            or sample.kills < saved.kills
            or sample.bs ~= saved.bs
            or sample.bk ~= saved.bk
        then
            scheduleCache = nil
            return nil
        end
        entries = ValidateSchedule(cache.entries, maximum, expected)
        if not entries then
            scheduleCache = nil
            return nil
        end
        cache.sample = sample
        return entries
    end

    local function InvalidateSchedule(sequence)
        scheduleCache = nil
        scheduleBarrier = math.max(scheduleBarrier, sequence)
    end

    local function UpdateMarkers(maximum, entries)
        for index, entry in ipairs(entries) do
            local at = entry.at
            local marker = markers[index]
            if not marker then
                marker = CreateFrame("Frame", nil, overlay)
                marker:SetWidth(MARKER_SIZE)
                marker:SetHeight(MARKER_SIZE)
                marker:EnableMouse(false)
                marker.glow = {}
                -- Translucent copies trace the native skull silhouette. Their
                -- offsets breathe inward/outward beneath the unchanged skull.
                for x = -1, 1 do
                    for y = -1, 1 do
                        if x ~= 0 or y ~= 0 then
                            local distance = math.sqrt(x * x + y * y)
                            local dx, dy = x / distance, y / distance
                            local glow = marker:CreateTexture(nil, "BACKGROUND")
                            glow:SetTexture(SKULL_ICON)
                            glow:SetWidth(MARKER_SIZE)
                            glow:SetHeight(MARKER_SIZE)
                            glow:SetPoint(
                                "CENTER",
                                marker,
                                "CENTER",
                                dx * ACTIVE_GLOW_MIN_OFFSET,
                                dy * ACTIVE_GLOW_MIN_OFFSET
                            )
                            glow:SetVertexColor(1, 0.25, 0, 1)
                            glow:SetAlpha(ACTIVE_GLOW_MIN_ALPHA)
                            glow:SetBlendMode("ADD")
                            table.insert(marker.glow, { texture = glow, x = dx, y = dy })
                        end
                    end
                end
                marker.skull = marker:CreateTexture(nil, "ARTWORK")
                marker.skull:SetTexture(SKULL_ICON)
                marker.skull:SetPoint("CENTER", marker, "CENTER", 0, 0)
                marker.check = marker:CreateTexture(nil, "OVERLAY")
                marker.check:SetTexture(CHECK_ICON)
                marker.check:SetVertexColor(0.2, 1, 0.2, 1)
                marker.check:SetWidth(MARKER_SIZE * 0.6)
                marker.check:SetHeight(MARKER_SIZE * 0.6)
                marker.check:SetPoint("BOTTOMRIGHT", marker, "BOTTOMRIGHT", 2, -1)
                HideMarker(marker)
                markers[index] = marker
            end
            markerStates[index] = entry.state
            marker:ClearAllPoints()
            if at == maximum then
                marker:SetPoint("RIGHT", runBar, "RIGHT", 0, 0)
            else
                marker:SetPoint("CENTER", runBar, "LEFT", BAR_WIDTH * at / maximum, 0)
            end
        end
        for index = table.getn(entries) + 1, table.getn(markers) do
            markerStates[index] = nil
            HideMarker(markers[index])
        end
    end

    local function UpdateMarkerStates()
        -- Only the official schedule establishes active and defeated bosses.
        -- UI time drives decoration only, including while the run is paused.
        -- The native run clock and schedule still own all gameplay timing/state.
        local pulse = 0.5 - 0.5 * math.cos(GetTime() * 2 * math.pi / ACTIVE_GLOW_PERIOD)
        local glowAlpha = ACTIVE_GLOW_MIN_ALPHA + (ACTIVE_GLOW_MAX_ALPHA - ACTIVE_GLOW_MIN_ALPHA) * pulse
        local glowOffset = ACTIVE_GLOW_MIN_OFFSET + (ACTIVE_GLOW_MAX_OFFSET - ACTIVE_GLOW_MIN_OFFSET) * pulse
        for index, marker in ipairs(markers) do
            local state = markerStates[index]
            if state then
                if marker.state ~= state then
                    marker.state = state
                    local dead = state == "dead"
                    local size = MARKER_SIZE * (dead and DEAD_MARKER_SCALE or 1)
                    marker.skull:SetWidth(size)
                    marker.skull:SetHeight(size)
                    marker.skull:SetAlpha(dead and DEAD_MARKER_ALPHA or 1)
                    ShowMarkerGlow(marker, state == "up")
                    if dead then
                        marker.check:Show()
                    else
                        marker.check:Hide()
                    end
                end
                if state == "up" then
                    for _, glow in ipairs(marker.glow) do
                        glow.texture:SetAlpha(glowAlpha)
                        glow.texture:ClearAllPoints()
                        glow.texture:SetPoint("CENTER", marker, "CENTER", glow.x * glowOffset, glow.y * glowOffset)
                    end
                end
                marker:Show()
            else
                HideMarker(marker)
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
                    table.insert(entries, {
                        key = key,
                        id = entry.id,
                        kind = kind,
                        name = entry.name,
                        hp = entry.hp,
                        maximum = entry.hpm,
                    })
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
        return { frame = frame, bar = bar, name = name, health = health, debuffs = {} }
    end

    local function Permanent(effect) return effect.permanent == true or effect.permanent == 1 end

    local function DebuffRemaining(effect)
        if not Permanent(effect) and IsNumber(effect.remaining) then return effect.remaining end
    end

    local function DebuffTooltip(icon)
        local effect = icon.effect
        if not GameTooltip or not effect then return end
        GameTooltip:SetText(type(effect.name) == "string" and effect.name ~= "" and effect.name or "Debuff", 1, 1, 1)
        if IsNumber(effect.stacks) and effect.stacks > 1 then
            GameTooltip:AddLine("Stacks: " .. tostring(math.floor(effect.stacks)), 1, 1, 1)
        end
        if type(effect.dispelType) == "string" and effect.dispelType ~= "" then
            GameTooltip:AddLine(effect.dispelType, 0.65, 0.8, 1)
        end
        local remaining = DebuffRemaining(effect)
        if Permanent(effect) then
            GameTooltip:AddLine("No expiration", 1, 0.85, 0.4)
        elseif remaining then
            GameTooltip:AddLine("Remaining: " .. Clock(math.ceil(remaining)), 1, 0.85, 0.4)
        else
            GameTooltip:AddLine("Remaining time unavailable", 0.7, 0.7, 0.7)
        end
        if not Permanent(effect) and IsNumber(effect.duration) and effect.duration > 0 then
            GameTooltip:AddLine("Duration: " .. Clock(math.ceil(effect.duration)), 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end

    local function DebuffIcon(row, index)
        local icon = row.debuffs[index]
        if icon then return icon end
        icon = CreateFrame("Frame", nil, row.frame)
        icon:SetWidth(DEBUFF_SIZE)
        icon:SetHeight(DEBUFF_SIZE)
        icon:SetPoint(
            "TOPLEFT",
            row.frame,
            "BOTTOMLEFT",
            8 + math.mod(index - 1, DEBUFF_COLUMNS) * (DEBUFF_SIZE + DEBUFF_GAP),
            -DEBUFF_GAP - math.floor((index - 1) / DEBUFF_COLUMNS) * (DEBUFF_SIZE + DEBUFF_GAP)
        )
        icon:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        icon:SetBackdropColor(0, 0, 0, 1)
        -- Reuse straight metal strips from the pill artwork, keeping squared
        -- corners instead of squeezing rounded end caps around a small icon.
        local top = Texture(icon, "BorderCenter", "OVERLAY", DEBUFF_SIZE, 2, 1, 7 / 32)
        top:SetTexCoord(0, 1, 5 / 32, 7 / 32)
        top:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        local bottom = Texture(icon, "BorderCenter", "OVERLAY", DEBUFF_SIZE, 2, 1, 26 / 32)
        bottom:SetTexCoord(0, 1, 24 / 32, 26 / 32)
        bottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
        local left = Texture(icon, "BorderLeft", "OVERLAY", 2, DEBUFF_SIZE - 4, 7 / 64, 20 / 32)
        left:SetTexCoord(5 / 64, 7 / 64, 11 / 32, 20 / 32)
        left:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, -2)
        local right = Texture(icon, "BorderRight", "OVERLAY", 2, DEBUFF_SIZE - 4, 30 / 64, 20 / 32)
        right:SetTexCoord(28 / 64, 30 / 64, 11 / 32, 20 / 32)
        right:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, -2)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
        icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
        icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon.count = icon:CreateFontString(nil, "OVERLAY")
        icon.count:SetFont("DEFAULT", 10, "OUTLINE")
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
        icon.time = icon:CreateFontString(nil, "OVERLAY")
        icon.time:SetFont("DEFAULT", 8, "OUTLINE")
        icon.time:SetPoint("TOP", icon, "TOP", 0, -1)
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function()
            if not GameTooltip or not icon.effect then return end
            GameTooltip:SetOwner(icon, "ANCHOR_BOTTOMRIGHT")
            DebuffTooltip(icon)
        end)
        icon:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
        end)
        row.debuffs[index] = icon
        return icon
    end

    local function UpdateDebuffs(row, enabled)
        local count = 0
        local getter = _G.AZS_GetDebuffs
        if enabled and type(getter) == "function" then
            -- The getter owns timing and returns current effects for this exact
            -- spawn, including when no unit is targeted. Never advance a local clock.
            local ok, effects = pcall(getter, row.id)
            if ok and type(effects) == "table" then
                for _, effect in ipairs(effects) do
                    if type(effect) == "table" and type(effect.icon) == "string" and effect.icon ~= "" then
                        count = count + 1
                        local icon = DebuffIcon(row, count)
                        icon.effect = effect
                        icon.texture:SetTexture(effect.icon)
                        icon.count:SetText(
                            IsNumber(effect.stacks) and effect.stacks > 1 and tostring(math.floor(effect.stacks)) or ""
                        )
                        local remaining = DebuffRemaining(effect)
                        local text = ""
                        if remaining then
                            text = remaining >= 60 and (tostring(math.ceil(remaining / 60)) .. "m")
                                or tostring(math.ceil(remaining))
                        end
                        icon.time:SetText(text)
                        icon:Show()
                        if GameTooltip and GameTooltip:IsOwned(icon) then DebuffTooltip(icon) end
                    end
                end
            end
        end
        for index = count + 1, table.getn(row.debuffs) do
            HideDebuff(row.debuffs[index])
        end
        return math.ceil(count / DEBUFF_COLUMNS) * (DEBUFF_SIZE + DEBUFF_GAP)
    end

    local function ReflowRows()
        local offset = 0
        for _, row in ipairs(rowOrder) do
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOP", bossGroup, "TOP", 0, -16 - offset)
            offset = offset + ROW_HEIGHT + (row.debuffHeight or 0)
        end
        bossGroup:SetHeight(math.max(47, offset - 1))
        DFRL.layout.Place("bossBars", bossGroup)
    end

    local function UpdateDebuffRows(phase, reflow)
        local enabled = phase ~= "ready" and phase ~= "dead" and DFRL.display.Get("bossDebuffs")
        for _, row in ipairs(rowOrder) do
            local height = UpdateDebuffs(row, enabled)
            if row.debuffHeight ~= height then reflow = true end
            row.debuffHeight = height
        end
        if reflow then ReflowRows() end
    end

    local function UpdateRows(phase)
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
        if count > 0 then
            bossGroup:Show()
        else
            bossGroup:Hide()
        end
        rowOrder = {}
        for _, entry in ipairs(entries) do
            local row = activeRows[entry.key]
            if not row then
                row = NewRow()
                activeRows[entry.key] = row
            end
            row.key = entry.key
            row.id = entry.id
            row.bar:SetValue(math.min(1, entry.hp / entry.maximum))
            row.name:SetText(entry.name)
            row.health:SetText(tostring(math.floor(entry.hp)) .. " / " .. tostring(math.floor(entry.maximum)))
            row.frame:Show()
            table.insert(rowOrder, row)
        end
        UpdateDebuffRows(phase, true)
        if not TakeOver("bosses") then
            ClearRows()
            Restore("bosses")
        end
    end

    DFRL.display.Listen(function()
        UpdateDisplayLabels()
        refreshRows = true
        -- Clearing is immediate even outside a run; valid encounters will reflow
        -- on the next native HUD update without affecting clock takeover.
        for _, row in pairs(activeRows) do
            ClearDebuffs(row)
        end
    end)

    local function Update()
        if not inWorld then
            ReleaseHUD()
            return
        end
        -- Out-of-run tables can retain the previous run. Phase must be read
        -- first; no old table values or invented clocks may stand in for it.
        local phase = Read("AZS_GetPhase")
        if not PHASES[phase] then
            if phase ~= nil then InvalidateSchedule(packetSequence) end
            ReleaseHUD()
            return
        end
        local nativeTime = type(AZS_RUN) == "table" and AZS_RUN.t or nil
        local zoneBoundary = zoneSequence
        if zoneBoundary then
            InvalidateSchedule(zoneBoundary)
            zoneSequence = nil
            zoneRunPending = zoneBoundary
            previousPhase, previousNativeTime = nil, nil
        end
        -- Zone, schedule and run prefixes can land in different frames. Do not
        -- mistake the first new clock sample for another boundary and reject
        -- a schedule already received after AZSZONE.
        if zoneRunPending and runSequence > zoneRunPending then zoneRunPending = nil end
        if
            not zoneRunPending
            and (
                (phase == "ready" and (scheduleCache or (previousPhase and previousPhase ~= "ready")))
                or (previousNativeTime and IsNumber(nativeTime) and nativeTime < previousNativeTime)
            )
        then
            InvalidateSchedule(runSequence)
        end
        if not zoneRunPending then
            previousPhase = phase
            if IsNumber(nativeTime) then previousNativeTime = nativeTime end
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
        local scheduled = maximum and ScheduleMarkers(maximum, phase) or nil
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
            if refreshRows or not run:IsShown() or not scheduled then UpdateMarkers(maximum, scheduled or {}) end
            UpdateMarkerStates()
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
            UpdateRows(phase)
        else
            -- Native remaining time is calculated on every getter call, even
            -- without a new AZSDEBUFFS packet and while the run is paused.
            UpdateDebuffRows(phase)
        end
    end

    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            -- Refresh from native data before the client saves addon variables.
            -- Repeated reloads can hand off an accepted cached schedule too.
            local ok = pcall(Update)
            local phase = Read("AZS_GetPhase")
            local maximum, expected = RunLength(), ExpectedBosses()
            local sample = maximum and expected and ScheduleSample(maximum, expected) or nil
            _G.SurvivorsDragonUiBossSchedule = nil
            if
                ok
                and inWorld
                and PHASES[phase]
                and phase ~= "ready"
                and IsNumber(Read("AZS_GetRunTime"))
                and sample
            then
                _G.SurvivorsDragonUiBossSchedule = scheduleCache
            end
            reloading = true
            return reloadUI()
        end
    end

    local reader = CreateFrame("Frame", "DFRL_NativeHUDReader", UIParent)
    reader:RegisterEvent("CHAT_MSG_ADDON")
    reader:RegisterEvent("PLAYER_ENTERING_WORLD")
    reader:RegisterEvent("PLAYER_LEAVING_WORLD")
    reader:RegisterEvent("PLAYER_LOGOUT")
    reader:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            if not reloading then
                InvalidateSchedule(packetSequence)
                _G.SurvivorsDragonUiBossSchedule = nil
            end
            inWorld = false
            ReleaseHUD()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            refreshRows = true
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 == "AZSDEBUFFS" then
                refreshRows = true
                return
            end
            if arg1 ~= "AZSZONE" and arg1 ~= "AZSRUN" and arg1 ~= "AZSBOSSES" and arg1 ~= "AZSUNITS" then return end
            packetSequence = packetSequence + 1
            if arg1 == "AZSZONE" then
                zoneSequence = packetSequence
            elseif arg1 == "AZSRUN" then
                runSequence = packetSequence
            elseif arg1 == "AZSBOSSES" then
                scheduleSequence = packetSequence
            end
            refreshRows = true
            -- The native parser may run after this handler. Read all prefixes
            -- on the next frame so cache decisions see their parsed values.
            return
        end
        Update()
    end)
    reader:SetScript("OnUpdate", function()
        -- List/marker refreshes are throttled; boss-state packets refresh them
        -- immediately. The pause-aware native clock is read every frame.
        pollAge = pollAge + (tonumber(arg1) or 0)
        if pollAge >= 0.1 then
            pollAge = 0
            refreshRows = true
        end
        Update()
    end)
    Update()
end)
