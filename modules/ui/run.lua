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
    local FLOW_WIDTH, FLOW_SPEED = 64, 32
    local FLOW_INTERVAL = 1 / 30
    local FLOW_SPACING = (BAR_WIDTH + FLOW_WIDTH) / 5 / 1.7
    local FLOW_COUNT = math.ceil((BAR_WIDTH + FLOW_WIDTH) / FLOW_SPACING)
    local FLOW_SPAN = FLOW_SPACING * FLOW_COUNT
    local RED_SPARKLE_OPACITY = 0.85
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

    -- Pooled cosmetic fill effects; native run data still controls progress.
    local function AnimatedRunFill(bar)
        local runGlow = bar:CreateTexture(nil, "OVERLAY")
        runGlow:SetTexture(path .. "FillWhite.tga")
        runGlow:SetBlendMode("ADD")
        runGlow:SetAllPoints(bar)
        runGlow:SetVertexColor(0.65, 0.04, 0.055)
        runGlow:SetAlpha(0.18)
        runGlow:Hide()
        local glowShown = false
        local runFlows = {}
        local flowRed, flowUpdatedAt
        -- Broad, soft ripples in three staggered streams form a continuous
        -- current. Each stream drifts right at its own speed and gently bends.
        for lane = 1, 3 do
            for index = 1, FLOW_COUNT do
                local texture = bar:CreateTexture(nil, "OVERLAY")
                texture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
                texture:SetBlendMode("ADD")
                texture:SetHeight(lane == 2 and 4 or 3)
                texture:SetVertexColor(0.22, 0.75, 1)
                texture:SetAlpha(lane == 2 and 0.7644 or 0.546)
                texture:Hide()
                table.insert(runFlows, {
                    texture = texture,
                    offset = (index - 1) * FLOW_SPACING + (lane - 1) * FLOW_WIDTH / 3,
                    speed = FLOW_SPEED + (lane - 2) * 6,
                    y = (lane - 2) * 4,
                    phase = lane * 1.7 + index * 1.2,
                })
            end
        end

        local redSparkles = {}
        local sparklesShown = false
        for index = 1, 28 do
            local center = (index - 0.5) * BAR_WIDTH / 28
            local left, right = math.max(0, center - 7), math.min(BAR_WIDTH, center + 7)
            local texture = bar:CreateTexture(nil, "OVERLAY")
            texture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            texture:SetBlendMode("ADD")
            texture:SetWidth(right - left)
            texture:SetHeight(9)
            texture:SetPoint("LEFT", bar, "LEFT", left, (math.mod(index - 1, 3) - 1) * 3)
            texture:SetTexCoord((left - center + 7) / 14, (right - center + 7) / 14, 0, 1)
            texture:SetVertexColor(1, 0.8, 0.7)
            texture:SetAlpha(0.22 * RED_SPARKLE_OPACITY)
            texture:Hide()
            redSparkles[index] = {
                texture = texture,
                period = 1.1 + math.mod(index, 7) * 0.2,
                phase = index * 2.39996,
            }
        end

        local function SetRunAppearance(atLimit)
            if glowShown ~= atLimit then
                if atLimit then
                    runGlow:Show()
                else
                    runGlow:Hide()
                end
                glowShown = atLimit
            end
            if sparklesShown ~= atLimit then
                for _, sparkle in ipairs(redSparkles) do
                    if atLimit then
                        sparkle.texture:Show()
                    else
                        sparkle.texture:Hide()
                    end
                end
                sparklesShown = atLimit
            end
            if flowRed == atLimit then return end
            flowRed = atLimit
            bar:SetStatusBarTexture(path .. (atLimit and "FillWhite" or "FillBlue") .. ".tga")
            bar:SetStatusBarColor(
                atLimit and 0.72 or 1,
                atLimit and 0.025 or 1,
                atLimit and 0.045 or 1,
                atLimit and 0.9 or 1
            )
            for _, flow in ipairs(runFlows) do
                if atLimit and flow.shown then
                    flow.texture:Hide()
                    flow.shown = false
                end
            end
        end

        local function HideRunFlow()
            flowUpdatedAt = nil
            if glowShown then
                runGlow:Hide()
                glowShown = false
            end
            if sparklesShown then
                for _, sparkle in ipairs(redSparkles) do
                    sparkle.texture:Hide()
                end
                sparklesShown = false
            end
            for _, flow in ipairs(runFlows) do
                if flow.shown then
                    flow.texture:Hide()
                    flow.shown = false
                end
            end
        end

        local function UpdateRunFlow(seconds, maximum)
            if seconds == 0 then
                HideRunFlow()
                return
            end
            -- UI time only moves decoration; native elapsed time owns the fill.
            -- Crop each pooled streak to that fill without texture wrapping or
            -- newer clipping APIs, beneath the separate metal border and skulls.
            local now = GetTime()
            if flowUpdatedAt and now - flowUpdatedAt < FLOW_INTERVAL then return end
            flowUpdatedAt = now
            if flowRed then
                -- Keep the full red fill alive everywhere: overlapping stationary
                -- glints twinkle independently, with no gaps between passing waves.
                -- Geometry is fixed at creation; only alpha changes during updates.
                for _, sparkle in ipairs(redSparkles) do
                    local pulse = 0.5 + 0.5 * math.sin(now * 2 * math.pi / sparkle.period + sparkle.phase)
                    sparkle.texture:SetAlpha((0.22 + 0.68 * pulse * pulse * pulse) * RED_SPARKLE_OPACITY)
                end
                return
            end
            local filledWidth = BAR_WIDTH * math.min(1, seconds / maximum)
            local span = FLOW_SPAN
            for _, flow in ipairs(runFlows) do
                local left = math.mod(now * flow.speed + flow.offset, span) - FLOW_WIDTH
                local first, last = math.max(0, left), math.min(filledWidth, left + FLOW_WIDTH)
                if first < last then
                    local y = flow.y + 0.65 * math.sin(now * 1.7 + flow.phase)
                    flow.texture:SetWidth(last - first)
                    flow.texture:SetPoint("LEFT", bar, "LEFT", first, y)
                    flow.texture:SetTexCoord((first - left) / FLOW_WIDTH, (last - left) / FLOW_WIDTH, 0, 1)
                    if not flow.shown then
                        flow.texture:Show()
                        flow.shown = true
                    end
                elseif flow.shown then
                    flow.texture:Hide()
                    flow.shown = false
                end
            end
        end
        return SetRunAppearance, HideRunFlow, UpdateRunFlow
    end

    local run, runBar, runText, overlay = Pill("DFRL_RunTimerPill", "FillBlue")
    local SetRunAppearance, HideRunFlow, UpdateRunFlow = AnimatedRunFill(runBar)

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
    local faceLabel, sizeLabel, shadowControl, visibilityControl
    local displayControls, outlineButtons, faceButtons, sctButtons = {}, {}, {}, {}
    local incomingControl, sctDescription

    local function UpdateSctLabels()
        if not incomingControl or not DFRL.sct then return end
        local mode = DFRL.sct.GetMode()
        for value, button in pairs(sctButtons) do
            button:SetSelected(value == mode)
        end
        if mode == "on" then
            sctDescription:SetText("Addon damage numbers follow enemies.")
        elseif mode == "off" then
            sctDescription:SetText("Custom and native outgoing damage text are off.")
        else
            sctDescription:SetText("Native outgoing text follows Show Target Damage.")
        end
        incomingControl:SetChecked(DFRL.sct.GetIncoming())
    end

    local function UpdateDisplayLabels()
        for key, control in pairs(displayControls) do
            control:SetChecked(DFRL.display.Get(key))
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
            if faceButtons[entry.face] then faceButtons[entry.face]:SetSelected(currentFont.face == entry.face) end
        end
        for _, entry in ipairs(fontOutlines) do
            outlineButtons[entry.value]:SetSelected(currentFont.outline == entry.value)
        end
        sizeLabel:SetText(tostring(currentFont.size))
        shadowControl:SetChecked(currentFont.shadow)
        visibilityControl:SetChecked(currentFont.showText)
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
        local button = T.CreateEditorButton(parent, text, width, 28)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        button:SetScript("OnClick", callback)
        return button.label, button
    end

    local function ChangeSize(direction)
        if not fontDraft then return end
        fontDraft.size = math.max(8, math.min(32, fontDraft.size + direction))
        PreviewFont(fontDraft)
    end

    local function PlaceFontEditor()
        if not fontEditor then return end
        fontEditor:ClearAllPoints()
        fontEditor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
        local padding, gap = 20, 8
        local labelWidth = math.max(TextWidth("Font"), TextWidth("Size"), TextWidth("Outline"))
        local dropdownWidth, tabWidth, modeWidth = 0, 0, 0
        local tabs = {
            { key = "layout", label = "Layout" },
            { key = "hud", label = "HUD" },
            { key = "combat", label = "Combat text" },
            { key = "timer", label = "Run timer" },
        }
        local modes = {
            { value = "on", label = "Custom" },
            { value = "off", label = "Off" },
            { value = "default", label = "Game settings" },
        }
        for _, entry in ipairs(fontFaces) do
            dropdownWidth = math.max(dropdownWidth, TextWidth(entry.label) + 36)
        end
        for _, entry in ipairs(tabs) do
            tabWidth = math.max(tabWidth, TextWidth(entry.label) + 32)
        end
        for _, entry in ipairs(modes) do
            modeWidth = math.max(modeWidth, TextWidth(entry.label) + 24)
        end
        local outlineWidth = 0
        for _, entry in ipairs(fontOutlines) do
            outlineWidth = math.max(outlineWidth, TextWidth(entry.label) + 24)
        end
        local defaultsWidth = TextWidth("Addon defaults") + 24
        local instructions = "Drag frames to move. Drag corners to resize."
        local contentWidth = math.max(
            tabWidth * table.getn(tabs) + gap * (table.getn(tabs) - 1),
            modeWidth * 3 + gap * 2,
            labelWidth + gap + dropdownWidth,
            labelWidth + gap + outlineWidth * 3 + gap * 2,
            defaultsWidth * 2 + 140 + gap * 4,
            TextWidth(instructions)
        )
        local width = contentWidth + padding * 2
        local inputX = padding + labelWidth + gap
        dropdownWidth = contentWidth - labelWidth - gap

        fontEditor = T.CreateEditorPanel(UIParent, width, 464)
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
        local title = FontEditorLabel(fontEditor, "SurvivorsDragonUi", 0, 0, 17)
        title:ClearAllPoints()
        title:SetPoint("TOP", fontEditor, "TOP", 0, -18)
        title:SetTextColor(1, 0.84, 0.48)
        local hint = FontEditorLabel(fontEditor, instructions, 0, 0, 10)
        hint:ClearAllPoints()
        hint:SetPoint("TOP", fontEditor, "TOP", 0, -49)
        hint:SetTextColor(0.75, 0.73, 0.67)

        local pages, tabButtons = {}, {}
        local function SelectPage(key)
            if fontMenu then fontMenu:Hide() end
            for pageKey, page in pairs(pages) do
                if pageKey == key then
                    page:Show()
                else
                    page:Hide()
                end
                tabButtons[pageKey]:SetSelected(pageKey == key)
            end
        end
        local tabSize = (contentWidth - gap * (table.getn(tabs) - 1)) / table.getn(tabs)
        local modeSize = (contentWidth - gap * 2) / 3
        for index, entry in ipairs(tabs) do
            local key = entry.key
            local page = CreateFrame("Frame", nil, fontEditor)
            page:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", padding, -130)
            page:SetWidth(contentWidth)
            page:SetHeight(264)
            page:SetFrameLevel(152)
            pages[key] = page
            local button = T.CreateEditorButton(fontEditor, entry.label, tabSize, 30)
            button:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", padding + (index - 1) * (tabSize + gap), -76)
            button:SetScript("OnClick", function() SelectPage(key) end)
            tabButtons[key] = button
        end
        local divider = T.EditorDivider(fontEditor, contentWidth)
        divider:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", padding, -116)

        DFRL.layout.CreateControls(pages.layout, contentWidth, function() SelectPage("layout") end)

        local function DisplayToggle(parent, key, label, description, y)
            local control = T.CreateEditorToggle(
                parent,
                label,
                description,
                contentWidth,
                function(value) DFRL.display.Set(key, value) end
            )
            control:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            displayControls[key] = control
        end
        DisplayToggle(
            pages.hud,
            "classHealth",
            "Class-colored health",
            "Use your vanilla class color for player health.",
            0
        )
        DisplayToggle(pages.hud, "classResources", "Class resources", "Show power inside the player frame.", -44)
        DisplayToggle(pages.hud, "cooldownNumbers", "Cooldown numbers", "Show countdowns on ability buttons.", -88)
        DisplayToggle(pages.hud, "bossDebuffs", "Boss debuffs", "Effects on boss and guardian health bars.", -132)
        DisplayToggle(pages.hud, "cacheGuidance", "Cache guidance", "Show the cache direction and distance.", -176)
        DisplayToggle(
            pages.hud,
            "guardianGuidance",
            "Guardian guidance",
            "Show the guardian lair direction and distance.",
            -220
        )

        local combat = pages.combat
        local heading = FontEditorLabel(combat, "Outgoing damage", 0, 0, 12)
        heading:SetTextColor(0.94, 0.79, 0.47)
        for index, entry in ipairs(modes) do
            local mode = entry.value
            local button = T.CreateEditorButton(combat, entry.label, modeSize, 30)
            button:SetPoint("TOPLEFT", combat, "TOPLEFT", (index - 1) * (modeSize + gap), -24)
            button:SetScript("OnClick", function()
                if DFRL.sct then DFRL.sct.SetMode(mode) end
            end)
            sctButtons[mode] = button
        end
        sctDescription = FontEditorLabel(combat, "", 0, -66, 10)
        sctDescription:SetWidth(contentWidth)
        sctDescription:SetHeight(28)
        sctDescription:SetJustifyH("LEFT")
        sctDescription:SetJustifyV("TOP")
        sctDescription:SetTextColor(0.75, 0.73, 0.67)
        divider = T.EditorDivider(combat, contentWidth)
        divider:SetPoint("TOPLEFT", combat, "TOPLEFT", 0, -104)
        incomingControl = T.CreateEditorToggle(
            combat,
            "Incoming / self text",
            "Received damage and other native self feedback.",
            contentWidth,
            function(value)
                if DFRL.sct then DFRL.sct.SetIncoming(value) end
            end
        )
        incomingControl:SetPoint("TOPLEFT", combat, "TOPLEFT", 0, -120)
        DisplayToggle(combat, "damageIcons", "Damage icons", "Spell icons beside custom damage numbers.", -172)

        local timer = pages.timer
        local caption = FontEditorLabel(timer, "Timer label preview", 0, 0, 9)
        caption:SetTextColor(0.75, 0.73, 0.67)
        fontSample = FontEditorLabel(timer, "RUN 02:34 / 20:00", 0, 0)
        fontSample:ClearAllPoints()
        fontSample:SetPoint("TOP", timer, "TOP", 0, -16)
        local controlX = inputX - padding
        FontEditorLabel(timer, "Font", 0, -66, 11)
        local fontButton
        faceLabel, fontButton = FontEditorButton("", dropdownWidth, controlX, -58, function()
            if not fontDraft then return end
            if fontMenu:IsShown() then
                fontMenu:Hide()
            else
                fontMenu:Show()
            end
        end, timer)
        local arrow = FontEditorLabel(fontButton, "v", 0, 0)
        arrow:ClearAllPoints()
        arrow:SetPoint("RIGHT", fontButton, "RIGHT", -12, 0)

        -- The popup catches outside clicks while its list stays above the editor.
        fontMenu = CreateFrame("Button", nil, fontEditor)
        fontMenu:SetAllPoints(UIParent)
        fontMenu:SetFrameLevel(180)
        fontMenu:EnableMouse(true)
        fontMenu:SetScript("OnClick", function() fontMenu:Hide() end)
        fontMenu:Hide()
        local fontList = T.CreateEditorPanel(fontMenu, dropdownWidth, table.getn(fontFaces) * 28 + 16)
        fontList:SetFrameLevel(190)
        fontList:SetPoint("TOPLEFT", fontButton, "BOTTOMLEFT", 0, -4)
        for index, entry in ipairs(fontFaces) do
            local selectedFace = entry.face
            local _, button = FontEditorButton(entry.label, dropdownWidth - 16, 8, -8 - (index - 1) * 28, function()
                if not fontDraft then return end
                fontDraft.face = selectedFace
                PreviewFont(fontDraft)
                fontMenu:Hide()
            end, fontList)
            faceButtons[selectedFace] = button
        end
        fontEditor:SetScript("OnHide", function()
            FinishFontEditorDrag()
            fontMenu:Hide()
        end)
        FontEditorLabel(timer, "Size", 0, -104, 11)
        FontEditorButton("-", 28, controlX, -96, function() ChangeSize(-1) end, timer)
        sizeLabel = FontEditorLabel(timer, "", controlX + 42, -104)
        FontEditorButton("+", 28, controlX + 76, -96, function() ChangeSize(1) end, timer)
        FontEditorLabel(timer, "Outline", 0, -140, 11)
        local outlineSize = (dropdownWidth - gap * 2) / 3
        for index, entry in ipairs(fontOutlines) do
            local value = entry.value
            local _, button = FontEditorButton(
                entry.label,
                outlineSize,
                controlX + (index - 1) * (outlineSize + gap),
                -132,
                function()
                    if not fontDraft then return end
                    fontDraft.outline = value
                    PreviewFont(fontDraft)
                end,
                timer
            )
            outlineButtons[value] = button
        end
        local halfWidth = (contentWidth - gap) / 2
        shadowControl = T.CreateEditorToggle(timer, "Black shadow", nil, halfWidth, function(value)
            if not fontDraft then return end
            fontDraft.shadow = value
            PreviewFont(fontDraft)
        end)
        shadowControl:SetPoint("TOPLEFT", timer, "TOPLEFT", 0, -176)
        visibilityControl = T.CreateEditorToggle(timer, "Run text", nil, halfWidth, function(value)
            if not fontDraft then return end
            fontDraft.showText = value
            PreviewFont(fontDraft)
        end)
        visibilityControl:SetPoint("TOPLEFT", timer, "TOPLEFT", halfWidth + gap, -176)

        divider = T.EditorDivider(fontEditor, contentWidth)
        divider:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", padding, -400)
        hint = FontEditorLabel(fontEditor, "Changes preview immediately. Confirm keeps them.", 0, 0, 9)
        hint:ClearAllPoints()
        hint:SetPoint("TOP", fontEditor, "TOP", 0, -409)
        hint:SetTextColor(0.75, 0.73, 0.67)
        local footer = CreateFrame("Frame", nil, fontEditor)
        footer:SetWidth(contentWidth)
        footer:SetHeight(30)
        footer:SetPoint("BOTTOM", fontEditor, "BOTTOM", 0, 16)
        local defaults = T.CreateEditorButton(footer, "Addon defaults", defaultsWidth, 30)
        defaults:SetPoint("LEFT", footer, "LEFT", 0, 0)
        defaults:SetScript("OnClick", function() DFRL.layout.Reset() end)
        local cancel = T.CreateEditorButton(footer, "Cancel", defaultsWidth, 30)
        cancel:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
        cancel:SetScript("OnClick", function() DFRL.layout.CancelEdit() end)
        DFRL.layout.SetConfirmAnchor(footer)
        SelectPage("layout")
        UpdateDisplayLabels()
        if DFRL.sct then DFRL.sct.Listen(UpdateSctLabels) end
        UpdateSctLabels()
    end

    local function EditRunFont(active, save)
        if active then
            DFRL.display.BeginEdit()
            if DFRL.sct then DFRL.sct.BeginEdit() end
            fontDraft = FontSettings(_G.SurvivorsDragonUiRunFont)
            if not fontEditor then CreateFontEditor() end
            PreviewFont(fontDraft)
            UpdateSctLabels()
            fontEditor:Show()
        else
            DFRL.display.FinishEdit(save)
            if DFRL.sct then DFRL.sct.FinishEdit(save) end
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
    local function SetTallyFieldWidth(entry, width)
        entry.frame:SetWidth(width)
        -- Native FontStrings need an explicit width; opposing anchors alone
        -- do not resolve their width in the packaged client.
        entry.text:SetWidth(width - 32)
    end
    for index, counter in ipairs(counters) do
        local field = CreateFrame("Frame", nil, tallyOverlay)
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
        text:SetHeight(18)
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        local entry = { key = counter.key, label = counter.label, text = text, frame = field }
        SetTallyFieldWidth(entry, fieldWidth)
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
            SetTallyFieldWidth(entry, sectionWidth)
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("LEFT", tally, "LEFT", 8 + (index - 1) * sectionWidth, 0)
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
        HideRunFlow()
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

    local function UpdateMarkerStates(atLimit)
        if atLimit then
            for _, marker in ipairs(markers) do
                if marker.state then HideMarker(marker) end
            end
            return
        end
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
            local atLimit = seconds >= maximum
            SetRunAppearance(atLimit)
            UpdateRunFlow(seconds, maximum)
            local clockText = "RUN " .. Clock(seconds)
            if not atLimit then clockText = clockText .. " / " .. Clock(maximum) end
            if runText:GetText() ~= clockText then
                runText:SetText(clockText)
                UpdateRunFontBounds()
            end
            -- Missing schedule replay affects only spawn markers, never a clock
            -- whose native elapsed time and duration have already recovered.
            if refreshRows or not run:IsShown() or not scheduled then UpdateMarkers(maximum, scheduled or {}) end
            UpdateMarkerStates(atLimit)
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
