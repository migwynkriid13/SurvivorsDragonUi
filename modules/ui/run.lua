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
    local COINS_ICON = DFRL:GetInfoOrCons("tex") .. "tally\\Coins.tga"
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
        local background =
            Texture(frame, "BackgroundFixed", "BACKGROUND", BAR_WIDTH + 4, 18, (BAR_WIDTH + 4) / 512, 18 / 32)
        background:SetPoint("LEFT", frame, "LEFT", 6, 0)

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
        T.SetFont(text, 14, "OUTLINE")
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

        local blueFoam = {}
        local function NewFoam(r, g, b)
            local texture = bar:CreateTexture(nil, "OVERLAY")
            texture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            texture:SetBlendMode("ADD")
            texture:SetVertexColor(r, g, b)
            texture:Hide()
            local piece = { texture = texture }
            table.insert(blueFoam, piece)
            return piece
        end
        local foamGlow = NewFoam(0.3, 0.8, 1)
        local foamCrest = NewFoam(0.8, 0.96, 1)
        local foamShoulders = { NewFoam(0.66, 0.92, 1), NewFoam(0.66, 0.92, 1) }
        local foamFlecks = {}
        for index = 1, 12 do
            local fleck = NewFoam(0.75, 0.94, 1)
            fleck.period = 0.7 + math.mod(index, 5) * 0.13
            fleck.phase = index * 0.618034
            fleck.drift = 7 + math.mod(index, 4) * 2.5
            fleck.y = (math.mod(index - 1, 5) - 2) * 2.1
            foamFlecks[index] = fleck
        end

        local function HideBlueFoam()
            for _, piece in ipairs(blueFoam) do
                if piece.shown then
                    piece.texture:Hide()
                    piece.shown = false
                end
            end
        end

        local function DrawFoam(piece, left, y, width, height, alpha, filledWidth)
            local first, last = math.max(0, left), math.min(BAR_WIDTH, filledWidth + 6, left + width)
            local halfHeight = bar:GetHeight() / 2
            local bottom, top = math.max(-halfHeight, y - height / 2), math.min(halfHeight, y + height / 2)
            if first >= last or bottom >= top then
                if piece.shown then
                    piece.texture:Hide()
                    piece.shown = false
                end
                return
            end
            local texture = piece.texture
            local drawnWidth, drawnHeight = last - first, top - bottom
            if piece.drawnWidth ~= drawnWidth then
                texture:SetWidth(drawnWidth)
                piece.drawnWidth = drawnWidth
            end
            if piece.drawnHeight ~= drawnHeight then
                texture:SetHeight(drawnHeight)
                piece.drawnHeight = drawnHeight
            end
            texture:SetPoint("LEFT", bar, "LEFT", first, (bottom + top) / 2)
            local u1, u2 = (first - left) / width, (last - left) / width
            local v1, v2 = (y + height / 2 - top) / height, (y + height / 2 - bottom) / height
            if piece.u1 ~= u1 or piece.u2 ~= u2 or piece.v1 ~= v1 or piece.v2 ~= v2 then
                texture:SetTexCoord(u1, u2, v1, v2)
                piece.u1, piece.u2, piece.v1, piece.v2 = u1, u2, v1, v2
            end
            texture:SetAlpha(math.min(1, math.max(0, alpha * 1.4)))
            if not piece.shown then
                texture:Show()
                piece.shown = true
            end
        end

        local function UpdateBlueFoam(now, filledWidth)
            -- A broad, uneven crest feathers past the native edge while
            -- puffs wash back into the current, inside the metal pill.
            DrawFoam(foamGlow, filledWidth - 11, 0, 17, 15, 0.42 + 0.08 * math.sin(now * 4.1), filledWidth)
            DrawFoam(
                foamCrest,
                filledWidth - 5 + 1.1 * math.sin(now * 4.7),
                0.7 * math.sin(now * 3.3),
                8,
                13.5,
                0.62 + 0.1 * math.sin(now * 5.3),
                filledWidth
            )
            for index, shoulder in ipairs(foamShoulders) do
                local phase = now * (3.7 + index * 0.6) + index * 2.1
                DrawFoam(
                    shoulder,
                    filledWidth - 5 + 1.2 * math.sin(phase),
                    (index == 1 and -3.8 or 3.8) + 0.5 * math.sin(phase + 1),
                    6,
                    6.5,
                    0.42 + 0.08 * math.sin(phase),
                    filledWidth
                )
            end
            for index, fleck in ipairs(foamFlecks) do
                local age = math.mod(now / fleck.period + fleck.phase, 1)
                local swell = math.sin(age * math.pi)
                local width = 3.2 + swell * 2.2
                local height = 1.8 + math.mod(index, 3) * 0.5
                local y = fleck.y + 1.1 * math.sin(age * 2 * math.pi + fleck.phase)
                local left = filledWidth + 2.2 * (1 - age) - age * fleck.drift - width / 2
                DrawFoam(fleck, left, y, width, height, 0.78 * swell, filledWidth)
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
            if atLimit then HideBlueFoam() end
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
            HideBlueFoam()
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
                    local drawnWidth = last - first
                    if flow.drawnWidth ~= drawnWidth then
                        flow.texture:SetWidth(drawnWidth)
                        flow.drawnWidth = drawnWidth
                    end
                    flow.texture:SetPoint("LEFT", bar, "LEFT", first, y)
                    local u1, u2 = (first - left) / FLOW_WIDTH, (last - left) / FLOW_WIDTH
                    if flow.u1 ~= u1 or flow.u2 ~= u2 then
                        flow.texture:SetTexCoord(u1, u2, 0, 1)
                        flow.u1, flow.u2 = u1, u2
                    end
                    if not flow.shown then
                        flow.texture:Show()
                        flow.shown = true
                    end
                elseif flow.shown then
                    flow.texture:Hide()
                    flow.shown = false
                end
            end
            UpdateBlueFoam(now, filledWidth)
        end
        return SetRunAppearance, HideRunFlow, UpdateRunFlow
    end

    local run, runBar, runText, overlay = Pill("DFRL_RunTimerPill", "FillBlue")
    local bossText = overlay:CreateFontString(nil, "OVERLAY")
    T.SetFont(bossText, 14, "OUTLINE")
    bossText:SetTextColor(1, 1, 1)
    bossText:SetJustifyH("RIGHT")
    bossText:SetText("")
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
    local currentFont, fontDraft, fontEditor, fontSample, fontSampleClock, fontMenu
    local faceLabel, sizeLabel, shadowControl
    local displayControls, displayNumbers, outlineButtons, faceButtons, sctButtons = {}, {}, {}, {}, {}
    local incomingControl, sctDescription
    local sctSizeLabel

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
        if sctSizeLabel then
            sctSizeLabel:SetText(tostring(math.floor(DFRL.display.Get("sctScale") * 100 + 0.5)) .. "%")
        end
        if fontEditor and fontEditor.tallyStyleButtons then
            local selected = DFRL.display.Get("tallyStyle")
            for id, button in pairs(fontEditor.tallyStyleButtons) do
                button:SetSelected(id == selected)
            end
        end
        for key, label in pairs(displayNumbers) do
            label:SetText(tostring(DFRL.display.Get(key)))
        end
        for key, control in pairs(displayControls) do
            control:SetChecked(DFRL.display.Get(key))
            if key == "roundPlayerPortrait" or key == "playerPortrait3D" then
                local enabled = not DFRL.display.Get("hidePortraits")
                control:EnableMouse(enabled)
                control:SetAlpha(enabled and 1 or 0.45)
            elseif key == "attachJewelry" then
                local enabled = DFRL.display.Get("equippedJewelry")
                control:EnableMouse(enabled)
                control:SetAlpha(enabled and 1 or 0.45)
            end
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

    local function ApplyFont(text, settings, caption)
        -- Initialize the game's DEFAULT face first so a missing native face
        -- leaves readable text at the requested size and outline.
        T.SetFont(text, settings.size, settings.outline)
        -- Translated run captions with non-ASCII glyphs use the game face;
        -- retain the user's saved font choice for the other languages.
        if settings.face ~= "DEFAULT" and not string.find(DFRL.locale.Text(caption or "RUN"), "[\128-\255]") then
            pcall(text.SetFont, text, settings.face, settings.size, settings.outline)
        end
        text:SetShadowColor(0, 0, 0, settings.shadow and 1 or 0)
        text:SetShadowOffset(settings.shadow and 1 or 0, settings.shadow and -1 or 0)
    end

    local function NewClockLabel(source, caption)
        local ruler = source:GetParent():CreateFontString(nil, "OVERLAY")
        ruler:Hide()
        source:Hide()
        return { source = source, ruler = ruler, parts = {}, caption = caption }
    end

    local function RefreshClockLabel(clock)
        local source = clock.source
        local text = source:GetText() or ""
        local scale = source:GetParent():GetEffectiveScale()
        if not IsNumber(scale) or scale <= 0 then return end
        if clock.text == text and T.NearlyEqual(clock.scale, scale) and clock.drawn == clock.visible then return end
        local width, height = source:GetStringWidth() or 0, source:GetHeight() or 0
        if text ~= "" and (width <= 0 or height <= 0) then return end
        local pixel = 1 / scale
        local used, cursor = 0, 1
        local function Part(first, last, raised)
            if last < first then return end
            used = used + 1
            local label = clock.parts[used]
            if not label then
                label = source:GetParent():CreateFontString(nil, "OVERLAY")
                ApplyFont(label, clock.settings, clock.caption)
                label:SetTextColor(source:GetTextColor())
                label:SetJustifyH("LEFT")
                label:SetJustifyV("MIDDLE")
                table.insert(clock.parts, label)
            end
            local x = 0
            if first > 1 then
                -- Keep the full string's kerning at each segment boundary.
                clock.ruler:SetText(string.sub(text, 1, first))
                x = clock.ruler:GetStringWidth() or 0
                clock.ruler:SetText(string.sub(text, first, first))
                x = x - (clock.ruler:GetStringWidth() or 0)
            end
            label:ClearAllPoints()
            label:SetPoint("BOTTOMLEFT", source, "BOTTOMLEFT", x, raised and pixel or 0)
            label:SetHeight(height)
            label:SetText(string.sub(text, first, last))
            if clock.visible then
                label:Show()
            else
                label:Hide()
            end
        end
        while cursor <= string.len(text) do
            local first, last = string.find(text, "%d+:%d%d", cursor)
            if not first then
                Part(cursor, string.len(text), false)
                break
            end
            Part(cursor, last - 2, false)
            Part(last - 1, last, true)
            cursor = last + 1
        end
        for index = used + 1, table.getn(clock.parts) do
            clock.parts[index]:SetText("")
            clock.parts[index]:Hide()
        end
        clock.text, clock.scale, clock.pixel = text, scale, pixel
        clock.drawn = clock.visible
        return true
    end

    local function StyleClockLabel(clock, settings, visible)
        clock.settings, clock.visible, clock.text = settings, visible, nil
        ApplyFont(clock.source, settings, clock.caption)
        ApplyFont(clock.ruler, settings, clock.caption)
        for _, label in ipairs(clock.parts) do
            ApplyFont(label, settings, clock.caption)
            label:Hide()
        end
        RefreshClockLabel(clock)
    end

    local runClock = NewClockLabel(runText)
    -- Both captions resolve the same face, including translated RUN fallback.
    local bossClock = NewClockLabel(bossText, "RUN")
    local function UpdateRunFontBounds()
        local width = runClock.visible and (runText:GetStringWidth() or 0) or 0
        local bossWidth = bossClock.visible and (bossText:GetStringWidth() or 0) or 0
        local overflow = math.max(0, (math.max(width, bossWidth) + 8 - run:GetWidth()) / 2)
        local pixel = math.max(runClock.pixel or 0, bossClock.pixel or 0)
        local inset = runClock.visible and bossClock.visible and 5 * pixel or 0
        runText:ClearAllPoints()
        bossText:ClearAllPoints()
        if runClock.visible and bossClock.visible then
            -- Keep the captions apart at large font sizes or with wider translations.
            overflow = math.max(0, (width + bossWidth + 8 + 2 * inset - run:GetWidth()) / 2)
            runText:SetPoint("BOTTOMLEFT", run, "TOPLEFT", inset - overflow, 2)
            bossText:SetPoint("BOTTOMRIGHT", run, "TOPRIGHT", overflow - inset, 2)
        else
            runText:SetPoint("BOTTOM", run, "TOP", 0, 2)
            bossText:SetPoint("BOTTOM", run, "TOP", 0, 2)
        end
        overflow = math.max(0, overflow - inset)
        local top = (runClock.visible or bossClock.visible) and currentFont.size + 4 + pixel or 0
        runMoveRegion:ClearAllPoints()
        runMoveRegion:SetPoint("TOPLEFT", run, "TOPLEFT", -overflow, top)
        runMoveRegion:SetPoint("BOTTOMRIGHT", run, "BOTTOMRIGHT", overflow, 0)
    end

    local function SetClockLabelText(clock, text, visible)
        if clock.source:GetText() ~= text then clock.source:SetText(text) end
        clock.visible = visible
        return RefreshClockLabel(clock)
    end

    local function RefreshTimerCaptions()
        local mode = runClock.mode or "Regular"
        local text = ""
        if runClock.currentTime then
            if DFRL.display.Get("runCurrent" .. mode) then text = runClock.currentTime end
            if mode == "Regular" and DFRL.display.Get("runMaximumRegular") then
                text = text ~= "" and text .. " / " .. runClock.maximumTime or runClock.maximumTime
            end
            if DFRL.display.Get("runText" .. mode) then
                text = DFRL.locale.Text("RUN") .. (text ~= "" and " " .. text or "")
            end
        end
        local changed = SetClockLabelText(runClock, text, text ~= "")
        local countdown = bossClock.option and DFRL.display.Get(bossClock.option) and bossClock.countdown or ""
        if SetClockLabelText(bossClock, countdown, countdown ~= "") then changed = true end
        if changed then UpdateRunFontBounds() end
    end

    local function PreviewFont(settings)
        currentFont = FontSettings(settings)
        StyleClockLabel(runClock, currentFont, runClock.visible)
        StyleClockLabel(bossClock, currentFont, bossClock.visible)
        RefreshTimerCaptions()
        UpdateRunFontBounds()
        if not fontEditor then return end
        StyleClockLabel(fontSampleClock, currentFont, true)
        for _, entry in ipairs(fontFaces) do
            if currentFont.face == entry.face then faceLabel:SetText(entry.label) end
            if faceButtons[entry.face] then faceButtons[entry.face]:SetSelected(currentFont.face == entry.face) end
        end
        for _, entry in ipairs(fontOutlines) do
            outlineButtons[entry.value]:SetSelected(currentFont.outline == entry.value)
        end
        sizeLabel:SetText(tostring(currentFont.size))
        shadowControl:SetChecked(currentFont.shadow)
    end

    DFRL.runFont = {
        Copy = FontSettings,
        Snapshot = function() return FontSettings(fontDraft or _G.SurvivorsDragonUiRunFont) end,
        Load = function(settings)
            if not fontDraft then return end
            fontDraft = FontSettings(settings)
            PreviewFont(fontDraft)
        end,
    }

    local function ClearClockCaptions()
        runClock.mode, runClock.currentTime, runClock.maximumTime = nil, nil, nil
        bossClock.option, bossClock.countdown = nil, nil
        RefreshTimerCaptions()
    end

    local function UpdateClockCaptions(seconds, maximum, acceptRun)
        -- The caller has already checked the native phase. Only received run
        -- flags select Endless; passing the zone limit or a boss death cannot.
        local state = AZS_RUN
        local received = acceptRun and type(state) == "table" and IsNumber(AZS_RUN_UPDATED)
        local mode
        if received and state.endl == 1 then
            mode = "Endless"
        elseif received and state.endl == 0 then
            mode = "Regular"
        end
        runClock.mode, runClock.currentTime = mode, Clock(seconds)
        runClock.maximumTime = mode ~= "Endless" and Clock(maximum) or nil
        local countdown = ""
        if mode and IsNumber(state.nb) then
            -- Both modes supply pause-aware nb. Do not derive a countdown from
            -- schedules, the zone limit, boss deaths or a private deadline.
            local remaining = math.ceil(state.nb)
            local time = string.format("%d:%02d", math.floor(remaining / 60), math.mod(remaining, 60))
            countdown = string.format(DFRL.locale.Text("BOSS IN: %s"), time)
        end
        bossClock.option = countdown ~= "" and "bossCountdown" .. mode or nil
        bossClock.countdown = countdown
        RefreshTimerCaptions()
        if fontEditor and fontEditor:IsShown() then RefreshClockLabel(fontSampleClock) end
    end

    local function FontEditorLabel(parent, text, x, y, size)
        local label = parent:CreateFontString(nil, "OVERLAY")
        DFRL.locale.Bind(label)
        T.SetFont(label, size or 12, "OUTLINE")
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

    DFRL.locale.Listen(function()
        if fontSample then fontSample:SetText(DFRL.locale.Text("RUN") .. " 02:34 / 20:00") end
        PreviewFont(fontDraft or _G.SurvivorsDragonUiRunFont)
    end)

    local function ChangeSize(direction)
        if not fontDraft then return end
        fontDraft.size = math.max(8, math.min(32, fontDraft.size + direction))
        PreviewFont(fontDraft)
    end

    local function FitFontEditor()
        if not fontEditor then return end
        local screenWidth, screenHeight = T.GetLocalSize(UIParent)
        local scale =
            math.min(1, (screenWidth - 20) / fontEditor:GetWidth(), (screenHeight - 20) / fontEditor:GetHeight())
        scale = scale * 0.85
        if scale > 0 and not T.NearlyEqual(fontEditor:GetScale(), scale) then fontEditor:SetScale(scale) end
    end

    local function PlaceFontEditor()
        if not fontEditor then return end
        FitFontEditor()
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
        local function TextWidth(text) return DFRL.locale.Width(measure, text) end
        local padding, gap = 20, 8
        local labelWidth = math.max(TextWidth("Font"), TextWidth("Size"), TextWidth("Outline"))
        local dropdownWidth, sidebarWidth, modeWidth = 0, 148, 0
        local categories = {
            { key = "layout", label = "Layout" },
            { key = "profiles", label = "Profiles" },
            {
                key = "units",
                label = "Unit frames",
                gapBefore = 8,
                columns = 2,
                options = {
                    { "showPlayerName", "Show player name", "Show the name above the player frame." },
                    { "showPlayerLevel", "Show player level", "Show the level above the player frame." },
                    { "showTargetName", "Show target name", "Show the name above the target frame." },
                    { "showTargetLevel", "Show target level", "Show the level above the target frame." },
                    { "showHealthValue", "Show health", "Show current health on unit health bars." },
                    { "showHealthPercentage", "Show health percentage", "Show remaining health as a percentage." },
                    { "classHealth", "Class-colored health", "Use your vanilla class color for player health." },
                    {
                        "healthLossAnimation",
                        "Health loss animation",
                        "Show recently lost health fading out on unit frames.",
                    },
                    { "classResources", "Class resources", "Show power in player and party frames." },
                    {
                        "hidePortraits",
                        "Hide portraits",
                        "Show player, target and target-of-target as bars without portraits.",
                    },
                    {
                        "roundPlayerPortrait",
                        "Round player portrait",
                        "Use the target's circular border without the pointed corner.",
                    },
                    {
                        "playerPortrait3D",
                        "3D Portrait",
                        "Use 3D for player, target and target-of-target.",
                    },
                },
            },
            {
                key = "pets",
                label = "Pet frames",
                options = {
                    { "petRows", "Rows", "Arrange pet groups in one to six rows.", step = 1 },
                    { "petSpacing", "Spacing", "Gap between pet groups.", step = 1 },
                    { "hidePetNames", "Hide names", "Hide pet names beside the portraits." },
                    { "hidePetCounts", "Hide counts", "Hide the x2, x3 summon count." },
                    { "hidePetTimers", "Hide timers", "Hide the remaining summon duration." },
                },
            },
            {
                key = "bosses",
                label = "Boss bars",
                options = {
                    { "bossDebuffs", "Boss debuffs", "Effects on boss and guardian health bars." },
                    { "guardiansInBossBar", "Guardians in boss bar", "Off: show only bosses in the boss bar." },
                },
            },
            {
                key = "auras",
                label = "Auras",
                options = {
                    { "flipBuffs", "Flip buff layout", "Flip icon order only; keep text placement." },
                    { "targetDebuffsOnTop", "Target debuffs on top", "Place target debuffs above the target frame." },
                },
            },
            {
                key = "abilities",
                label = "Action bar",
                options = {
                    {
                        "lockActionButtons",
                        "Lock action buttons",
                        "Off: Shift-click two occupied buttons to swap them.",
                    },
                    { "cooldownNumbers", "Cooldown numbers", "Show countdowns on ability buttons." },
                    { "showGryphons", "Show gryphons", "Show winged ornaments at both ends of the action bar." },
                    { "attachXP", "Attach XP to action bar", "Off: move and resize the XP bar separately." },
                    {
                        "hideNativeBuild",
                        "Hide default jewelry / abilities",
                        "Off: show the game's original jewelry and ability rows.",
                    },
                },
            },
            {
                key = "tooltip",
                label = "Tooltip",
                options = {
                    {
                        "tooltipAtCursor",
                        "Tooltip at cursor",
                        "Follow the mouse cursor instead of the saved or icon position.",
                    },
                },
            },
            {
                key = "tally",
                label = "Kills, Gold & Caches",
                columns = 3,
                rowHeight = 72,
                stylePicker = true,
                options = {
                    {
                        "attachTally",
                        "Attach to action bar",
                        "Off: move and resize kills, gold and cache cost separately.",
                    },
                    { "showTallyKills", "Show kills", "Show the number of enemies killed." },
                    { "showTallyGold", "Show gold", "Show your current gold." },
                    { "showTallyCache", "Show cache cost", "Show the next cache cost." },
                    {
                        "highlightAffordableCache",
                        "Highlight affordable cache",
                        "Brighten the gold text when you can afford the next cache.",
                    },
                },
            },
            {
                key = "jewelry",
                label = "Equipped jewelry",
                options = {
                    { "equippedJewelry", "Equipped jewelry", "Show five equipped items attached to the action bar." },
                    {
                        "attachJewelry",
                        "Attach jewelry to action bar",
                        "Off: move jewelry separately, keeping the silver rims.",
                    },
                },
            },
            {
                key = "waypoints",
                label = "Waypoints",
                options = {
                    { "cacheGuidance", "Cache guidance", "Show the cache direction and distance." },
                    {
                        "mirrorCacheWaypoint",
                        "Mirror cache waypoint",
                        "Move the arrow to the left and the icon to the right.",
                    },
                    { "guardianGuidance", "Guardian guidance", "Show the guardian lair direction and distance." },
                    {
                        "mirrorGuardianWaypoint",
                        "Mirror guardian waypoint",
                        "Move the arrow to the left and the icon to the right.",
                    },
                },
            },
            {
                key = "minimap",
                label = "Minimap",
                options = {
                    {
                        "keepDefeatedGuardianIcons",
                        "Keep defeated guardian icons",
                        "Keep lair icons on the minimap while guardians are down.",
                    },
                },
            },
            {
                key = "banners",
                label = "Banners",
                options = {
                    { "customBanners", "Custom banners", "Off: use the game's original banners." },
                },
            },
            { key = "combat", label = "Combat text", gapBefore = 8 },
            { key = "timer", label = "Run timer" },
        }
        local modes = {
            { value = "on", label = "Custom" },
            { value = "off", label = "Off" },
            { value = "default", label = "Game settings" },
        }
        local timerModes = {
            { label = "Regular runs", suffix = "Regular" },
            { label = "Endless", suffix = "Endless" },
        }
        local timerOptions = {
            { "runText", "Run text" },
            { "runCurrent", "Current time" },
            { "runMaximum", "Maximum zone time", regularOnly = true },
            { "bossCountdown", "Boss countdown" },
        }
        local combatFilters = {
            {
                label = "Damage type",
                y = -226,
                entries = {
                    { key = "sctNormalHits", label = "Normal damage" },
                    { key = "sctCriticalHits", label = "Critical damage" },
                },
            },
            {
                label = "Damage categories",
                y = -288,
                entries = {
                    { key = "sctAutoAttacks", label = "Auto-attacks" },
                    { key = "sctDirectDamage", label = "Direct abilities / spells" },
                    { key = "sctPeriodicDamage", label = "Damage over time" },
                    { key = "sctReflectedDamage", label = "Reflected damage" },
                    { key = "sctMisses", label = "Misses / avoidance" },
                    { key = "sctPetDamage", label = "Pet damage" },
                },
            },
        }
        for _, entry in ipairs(fontFaces) do
            dropdownWidth = math.max(dropdownWidth, TextWidth(entry.label) + 36)
        end
        local fontListWidth = dropdownWidth
        for _, entry in ipairs(categories) do
            sidebarWidth = math.max(sidebarWidth, TextWidth(entry.label) + 32)
        end
        for _, entry in ipairs(modes) do
            modeWidth = math.max(modeWidth, TextWidth(entry.label) + 24)
        end
        local filterWidth, filterHeadingWidth = TextWidth("Class-colored damage") + 36, 0
        for _, group in ipairs(combatFilters) do
            filterHeadingWidth = math.max(filterHeadingWidth, TextWidth(group.label))
            for _, entry in ipairs(group.entries) do
                filterWidth = math.max(filterWidth, TextWidth(entry.label) + 36)
            end
        end
        local hudOptionWidth = 0
        for _, category in ipairs(categories) do
            local columns = category.stylePicker and 1 or category.columns or 1
            for _, entry in ipairs(category.options or {}) do
                local controlsWidth = entry.step and 156 or 36
                local optionWidth =
                    math.max(TextWidth(entry[2]) + controlsWidth, TextWidth(entry[3]) / 2 + controlsWidth)
                hudOptionWidth =
                    math.max(hudOptionWidth, optionWidth * columns + gap * (columns - 1) + (columns == 1 and 24 or 0))
            end
        end
        local outlineWidth = 0
        for _, entry in ipairs(fontOutlines) do
            outlineWidth = math.max(outlineWidth, TextWidth(entry.label) + 24)
        end
        local tallyStyleWidth = 0
        for _, entry in ipairs(DFRL.tallyStyles or {}) do
            tallyStyleWidth = math.max(tallyStyleWidth, TextWidth(entry.label) + 24)
        end
        local timerOptionWidth = 0
        for _, entry in ipairs(timerOptions) do
            timerOptionWidth = math.max(timerOptionWidth, TextWidth(entry[2]) + 36)
        end
        for _, entry in ipairs(timerModes) do
            timerOptionWidth = math.max(timerOptionWidth, TextWidth(entry.label))
        end
        local timerSizeWidth = TextWidth("Size") + gap + 104
        local tallyStyleHint = "Styles stay the same when attached or detached."
        local defaultsWidth = TextWidth("Addon defaults") + 24
        local instructions = "Drag to move. Hold Shift to snap. Drag corners to resize."
        local contentWidth = math.max(
            modeWidth * 3 + gap * 2,
            filterWidth * 2 + gap,
            filterHeadingWidth,
            hudOptionWidth,
            timerOptionWidth * 2 + gap,
            tallyStyleWidth * 2 + gap + 24,
            TextWidth("Frame style") + 24,
            TextWidth(tallyStyleHint) / 2 + 24,
            (TextWidth("SCT size") + gap + 136) * 2 + gap,
            labelWidth + gap + dropdownWidth,
            labelWidth + gap + outlineWidth * 3 + gap * 2,
            defaultsWidth * 2 + 140 + gap * 4,
            DFRL.profiles.MinimumWidth(TextWidth),
            TextWidth(instructions)
        )
        local contentLeft = padding + sidebarWidth + 24
        local width = contentLeft + contentWidth + padding
        dropdownWidth = contentWidth - labelWidth - gap - gap * 3 - timerSizeWidth

        fontEditor = T.CreateEditorPanel(UIParent, width, 596)
        fontEditor:SetFrameStrata("TOOLTIP")
        fontEditor:SetFrameLevel(150)
        PlaceFontEditor()
        fontEditor:SetMovable(true)
        if fontEditor.SetClampedToScreen then fontEditor:SetClampedToScreen(false) end
        fontEditor:RegisterForDrag("LeftButton")
        fontEditor:SetScript("OnDragStart", function()
            if not fontDraft then return end
            fontMenu:Hide()
            fontEditor:StartMoving()
        end)
        fontEditor:SetScript("OnDragStop", FinishFontEditorDrag)
        fontEditor:SetScript("OnShow", FitFontEditor)
        local title = FontEditorLabel(fontEditor, "SurvivorsDragonUi", 0, 0, 17)
        title:ClearAllPoints()
        title:SetPoint("TOP", fontEditor, "TOP", 0, -18)
        title:SetTextColor(1, 0.84, 0.48)
        local hint = FontEditorLabel(fontEditor, instructions, 0, 0, 10)
        hint:ClearAllPoints()
        hint:SetPoint("TOP", fontEditor, "TOP", 0, -49)
        hint:SetTextColor(0.75, 0.73, 0.67)

        local sidebar = CreateFrame("Frame", nil, fontEditor)
        sidebar:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", padding - 6, -76)
        sidebar:SetWidth(sidebarWidth + 12)
        sidebar:SetHeight(448)
        sidebar:EnableMouse(false)
        local sidebarFill = sidebar:CreateTexture(nil, "BACKGROUND")
        sidebarFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        sidebarFill:SetVertexColor(0.018, 0.02, 0.024, 0.88)
        sidebarFill:SetAllPoints(sidebar)
        local separator = fontEditor:CreateTexture(nil, "BORDER")
        separator:SetTexture("Interface\\Buttons\\WHITE8X8")
        separator:SetVertexColor(0.45, 0.38, 0.23, 0.5)
        separator:SetWidth(1)
        separator:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", contentLeft - 12, -76)
        separator:SetPoint("BOTTOMLEFT", fontEditor, "TOPLEFT", contentLeft - 12, -524)
        local pages, categoryButtons = {}, {}
        local function SelectPage(key)
            if fontMenu then fontMenu:Hide() end
            for pageKey, page in pairs(pages) do
                if pageKey == key then
                    page:Show()
                else
                    page:Hide()
                end
                categoryButtons[pageKey]:SetSelected(pageKey == key)
            end
        end
        local modeSize = (contentWidth - gap * 2) / 3
        local sidebarY, categoryGaps = -6, 0
        for _, entry in ipairs(categories) do
            categoryGaps = categoryGaps + (entry.gapBefore or 0)
        end
        local categoryPitch =
            math.min(42, math.floor((sidebar:GetHeight() - 12 - categoryGaps + 6) / table.getn(categories)))
        for _, entry in ipairs(categories) do
            local key = entry.key
            local page = CreateFrame("Frame", nil, fontEditor)
            page:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", contentLeft, -130)
            page:SetWidth(contentWidth)
            page:SetHeight(396)
            page:SetFrameLevel(152)
            pages[key] = page
            local button = T.CreateEditorCategory(sidebar, entry.label, sidebarWidth, categoryPitch - 6)
            sidebarY = sidebarY - (entry.gapBefore or 0)
            button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, sidebarY)
            sidebarY = sidebarY - categoryPitch
            button:SetScript("OnClick", function() SelectPage(key) end)
            categoryButtons[key] = button
        end
        local divider = T.EditorDivider(fontEditor, contentWidth)
        divider:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", contentLeft, -116)

        DFRL.layout.CreateControls(pages.layout, contentWidth, function() SelectPage("layout") end)
        DFRL.profiles.CreateControls(pages.profiles, contentWidth)

        local function DisplayToggle(parent, key, label, description, y, rowWidth)
            local control = T.CreateEditorToggle(
                parent,
                label,
                description,
                rowWidth or contentWidth,
                function(value) DFRL.display.Set(key, value) end
            )
            control:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            displayControls[key] = control
            return control
        end
        local function DisplayNumber(parent, entry, width, height)
            local control = CreateFrame("Frame", nil, parent)
            control:SetWidth(width)
            control:SetHeight(height)
            local label = FontEditorLabel(control, entry[2], 0, -7, 12)
            label:SetWidth(width - 156)
            label:SetHeight(16)
            label:SetJustifyH("LEFT")
            local description = FontEditorLabel(control, entry[3], 0, -24, 10)
            description:SetTextColor(0.59, 0.59, 0.56)
            description:SetWidth(width - 156)
            description:SetHeight(28)
            description:SetJustifyH("LEFT")
            description:SetJustifyV("TOP")
            for _, direction in ipairs({ -1, 1 }) do
                local step = direction * entry.step
                local button = T.CreateEditorButton(control, direction < 0 and "-" or "+", 28, 28)
                button:SetPoint("TOPRIGHT", control, "TOPRIGHT", direction < 0 and -108 or 0, -8)
                button:SetScript(
                    "OnClick",
                    function() DFRL.display.Set(entry[1], DFRL.display.Get(entry[1]) + step) end
                )
            end
            local value = FontEditorLabel(control, "", 0, 0, 12)
            value:ClearAllPoints()
            value:SetPoint("CENTER", control, "TOPRIGHT", -68, -22)
            value:SetWidth(64)
            value:SetHeight(16)
            value:SetJustifyH("CENTER")
            displayNumbers[entry[1]] = value
            return control
        end
        local function CreateOptionsPage(category)
            local page = pages[category.key]
            local columns, rowHeight = category.columns or 1, category.rowHeight or 60
            local rowWidth = (contentWidth - gap * (columns - 1)) / columns
            local content, scroll, ScrollOptions = page, nil, nil
            if not category.columns then
                local scrollName = "SurvivorsDragonUi" .. category.key .. "OptionsScroll"
                scroll = CreateFrame("ScrollFrame", scrollName, page, "UIPanelScrollFrameTemplate")
                scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
                scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)
                rowWidth = contentWidth - 24
                content = CreateFrame("Frame", nil, scroll)
                content:SetWidth(rowWidth)
                content:SetHeight(table.getn(category.options) * rowHeight)
                scroll:SetScrollChild(content)
                ScrollOptions = function(direction)
                    local slider = _G[scrollName .. "ScrollBar"]
                    if not slider then return end
                    local low, high = slider:GetMinMaxValues()
                    local value = slider:GetValue() - (direction or arg1 or 0) * rowHeight
                    slider:SetValue(math.max(low, math.min(high, value)))
                end
                scroll:EnableMouseWheel(true)
                scroll:SetScript("OnMouseWheel", ScrollOptions)
            end
            for index, entry in ipairs(category.options) do
                local x = math.mod(index - 1, columns) * (rowWidth + gap)
                local y = -math.floor((index - 1) / columns) * rowHeight
                local control
                if entry.step then
                    control = DisplayNumber(content, entry, rowWidth, rowHeight)
                else
                    control = DisplayToggle(content, entry[1], entry[2], entry[3], y, rowWidth)
                    control:SetHeight(rowHeight)
                    control.description:SetHeight(28)
                    control.description:SetJustifyV("TOP")
                    if category.stylePicker then
                        control.label:ClearAllPoints()
                        control.label:SetPoint("TOPLEFT", control, "TOPLEFT", 32, -3)
                        control.label:SetHeight(28)
                        control.label:SetJustifyV("MIDDLE")
                        control.description:ClearAllPoints()
                        control.description:SetPoint("TOPLEFT", control, "TOPLEFT", 32, -32)
                        control.description:SetHeight(36)
                    end
                end
                control:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
                if ScrollOptions then
                    control:EnableMouseWheel(true)
                    control:SetScript("OnMouseWheel", ScrollOptions)
                end
            end
            if category.stylePicker then
                local top = math.ceil(table.getn(category.options) / columns) * rowHeight + 8
                local stylePageWidth = content:GetWidth()
                local heading = FontEditorLabel(content, "Frame style", 0, -top, 12)
                heading:SetTextColor(0.94, 0.79, 0.47)
                local description = FontEditorLabel(content, tallyStyleHint, 0, -top - 22, 10)
                description:SetWidth(stylePageWidth)
                description:SetHeight(28)
                description:SetJustifyH("LEFT")
                description:SetJustifyV("TOP")
                description:SetTextColor(0.59, 0.59, 0.56)
                local styleWidth, pitch = (stylePageWidth - gap) / 2, 36
                fontEditor.tallyStyleButtons = {}
                for index, entry in ipairs(DFRL.tallyStyles or {}) do
                    local id = entry.id
                    local button = T.CreateEditorButton(content, entry.label, styleWidth, 30)
                    button:SetPoint(
                        "TOPLEFT",
                        content,
                        "TOPLEFT",
                        math.mod(index - 1, 2) * (styleWidth + gap),
                        -top - 58 - math.floor((index - 1) / 2) * pitch
                    )
                    button:SetScript("OnClick", function() DFRL.display.Set("tallyStyle", id) end)
                    if ScrollOptions then
                        button:EnableMouseWheel(true)
                        button:SetScript("OnMouseWheel", ScrollOptions)
                    end
                    fontEditor.tallyStyleButtons[id] = button
                end
                content:SetHeight(top + 58 + math.ceil(table.getn(DFRL.tallyStyles or {}) / 2) * pitch)
            end
            if scroll and scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
        for _, category in ipairs(categories) do
            if category.options then CreateOptionsPage(category) end
        end

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
        local combatToggleWidth = (contentWidth - gap) / 2
        incomingControl = T.CreateEditorToggle(
            combat,
            "Incoming / self text",
            "Received damage and other native self feedback.",
            combatToggleWidth,
            function(value)
                if DFRL.sct then DFRL.sct.SetIncoming(value) end
            end
        )
        incomingControl:SetPoint("TOPLEFT", combat, "TOPLEFT", 0, -112)
        local iconControl = DisplayToggle(
            combat,
            "damageIcons",
            "Damage icons",
            "Spell icons beside custom damage numbers.",
            -112,
            combatToggleWidth
        )
        iconControl:ClearAllPoints()
        iconControl:SetPoint("TOPLEFT", combat, "TOPLEFT", combatToggleWidth + gap, -112)
        for _, control in ipairs({ incomingControl, iconControl }) do
            control:SetHeight(60)
            control.description:SetHeight(28)
            control.description:SetJustifyV("TOP")
        end
        FontEditorLabel(combat, "SCT size", 0, -190, 11)
        local scaleX = TextWidth("SCT size") + gap
        local function ChangeSctSize(direction)
            local percent = math.floor(DFRL.display.Get("sctScale") * 100 + 0.5)
            DFRL.display.Set("sctScale", (percent + direction * 5) / 100)
        end
        FontEditorButton("-", 28, scaleX, -182, function() ChangeSctSize(-1) end, combat)
        sctSizeLabel = FontEditorLabel(combat, "", scaleX + 36, -190)
        sctSizeLabel:SetWidth(64)
        sctSizeLabel:SetJustifyH("CENTER")
        FontEditorButton("+", 28, scaleX + 108, -182, function() ChangeSctSize(1) end, combat)
        local filterSize = (contentWidth - gap) / 2
        local function CombatToggle(key, label, x, y)
            local control = DisplayToggle(combat, key, label, nil, y, filterSize)
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", combat, "TOPLEFT", x, y)
            control:SetHeight(28)
            control.label:ClearAllPoints()
            control.label:SetPoint("LEFT", control, "LEFT", 32, 0)
        end
        CombatToggle("sctClassColors", "Class-colored damage", filterSize + gap, -182)
        divider = T.EditorDivider(combat, contentWidth)
        divider:SetPoint("TOPLEFT", combat, "TOPLEFT", 0, -282)
        for _, group in ipairs(combatFilters) do
            heading = FontEditorLabel(combat, group.label, 0, group.y, 12)
            heading:SetTextColor(0.94, 0.79, 0.47)
            for index, entry in ipairs(group.entries) do
                CombatToggle(
                    entry.key,
                    entry.label,
                    math.mod(index - 1, 2) * (filterSize + gap),
                    group.y - 24 - math.floor((index - 1) / 2) * 28
                )
            end
        end

        local timer = pages.timer
        local caption = FontEditorLabel(timer, "Timer label preview", 0, 0, 9)
        caption:SetTextColor(0.75, 0.73, 0.67)
        fontSample = FontEditorLabel(timer, DFRL.locale.Text("RUN") .. " 02:34 / 20:00", 0, 0)
        fontSample:ClearAllPoints()
        fontSample:SetPoint("TOP", timer, "TOP", 0, -16)
        fontSampleClock = NewClockLabel(fontSample)
        local controlX = labelWidth + gap
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
        fontListWidth = math.max(fontListWidth, dropdownWidth)
        local fontList = T.CreateEditorPanel(fontMenu, fontListWidth, table.getn(fontFaces) * 28 + 16)
        fontList:SetFrameLevel(190)
        fontList:SetPoint("TOPLEFT", fontButton, "BOTTOMLEFT", 0, -4)
        for index, entry in ipairs(fontFaces) do
            local selectedFace = entry.face
            local _, button = FontEditorButton(entry.label, fontListWidth - 16, 8, -8 - (index - 1) * 28, function()
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
        local sizeX = contentWidth - timerSizeWidth
        FontEditorLabel(timer, "Size", sizeX, -66, 11)
        sizeX = sizeX + TextWidth("Size") + gap
        FontEditorButton("-", 28, sizeX, -58, function() ChangeSize(-1) end, timer)
        sizeLabel = FontEditorLabel(timer, "", sizeX + 42, -66)
        FontEditorButton("+", 28, sizeX + 76, -58, function() ChangeSize(1) end, timer)
        FontEditorLabel(timer, "Outline", 0, -104, 11)
        local outlineSize = (contentWidth - controlX - gap * 2) / 3
        for index, entry in ipairs(fontOutlines) do
            local value = entry.value
            local _, button = FontEditorButton(
                entry.label,
                outlineSize,
                controlX + (index - 1) * (outlineSize + gap),
                -96,
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
        shadowControl:SetPoint("TOPLEFT", timer, "TOPLEFT", 0, -132)
        for index, mode in ipairs(timerModes) do
            local x = (index - 1) * (halfWidth + gap)
            local heading = FontEditorLabel(timer, mode.label, x, -184, 12)
            heading:SetTextColor(0.94, 0.79, 0.47)
            local row = 0
            for _, entry in ipairs(timerOptions) do
                if not entry.regularOnly or mode.suffix == "Regular" then
                    local y = -204 - row * 44
                    local control = DisplayToggle(timer, entry[1] .. mode.suffix, entry[2], nil, y, halfWidth)
                    control:SetPoint("TOPLEFT", timer, "TOPLEFT", x, y)
                    row = row + 1
                end
            end
        end

        divider = T.EditorDivider(fontEditor, width - padding * 2)
        divider:SetPoint("TOPLEFT", fontEditor, "TOPLEFT", padding, -532)
        local footer = CreateFrame("Frame", nil, fontEditor)
        footer:SetWidth(width - padding * 2)
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
            PreviewFont(fontDraft)
            UpdateSctLabels()
        else
            DFRL.display.FinishEdit(save)
            if DFRL.sct then DFRL.sct.FinishEdit(save) end
            if save and fontDraft then _G.SurvivorsDragonUiRunFont = FontSettings(fontDraft) end
            fontDraft = nil
            PreviewFont(_G.SurvivorsDragonUiRunFont)
            if fontEditor then fontEditor:Hide() end
        end
    end

    DFRL.layout.SetEditorVisibilityHandler(function(shown)
        if shown then
            if not fontEditor then CreateFontEditor() end
            PreviewFont(fontDraft)
            UpdateSctLabels()
            fontEditor:Show()
        elseif fontEditor then
            fontEditor:Hide()
        end
    end)

    PreviewFont(_G.SurvivorsDragonUiRunFont)
    DFRL.layout.Register("runTimer", run, function()
        run:ClearAllPoints()
        run:SetPoint("TOP", UIParent, "TOP", 0, -30)
    end, {
        region = runMoveRegion,
        onEdit = EditRunFont,
        onResize = function()
            RefreshClockLabel(runClock)
            RefreshClockLabel(bossClock)
            UpdateRunFontBounds()
        end,
        onReset = function()
            _G.SurvivorsDragonUiRunFont = nil
            DFRL.display.Reset()
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

    local tally = CreateFrame("Frame", "DFRL_RunTallyPill", UIParent)
    tally:SetWidth(BAR_WIDTH + 16)
    tally:SetHeight(31)
    tally:SetFrameStrata("HIGH")
    tally:EnableMouse(false)
    tally:Hide()
    local tallyOverlay = CreateFrame("Frame", nil, tally)
    tallyOverlay:SetAllPoints(tally)
    tallyOverlay:SetFrameLevel(tally:GetFrameLevel() + 2)
    local tallyFields = {}
    local tallyAttachment = {}
    local visibleTallyFields, tallyPresentationDirty = 3, true
    local goldField
    local fieldWidth = BAR_WIDTH / 3
    local counters = {
        { key = "kills", visibility = "showTallyKills", label = "Enemies killed", icon = ATTACK_ICON },
        { key = "gold", visibility = "showTallyGold", label = "Gold", icon = COINS_ICON },
        { key = "chest", visibility = "showTallyCache", label = "Next cache cost", icon = CACHE_ICON },
    }
    local tallyMeasure = tallyOverlay:CreateFontString(nil, "OVERLAY")
    tallyMeasure:Hide()
    local function RefreshTallyGlowBounds(entry)
        if not entry.glowLights then return end
        local contentWidth = entry.content:GetWidth()
        local width = contentWidth * entry.glowWidthScale
        if not T.NearlyEqual(entry.glowWidth, width) then
            local light = entry.glowLights[1]
            light.spotlight:SetWidth(width)
            light.rays:SetWidth(width)
            light.radiusX = math.max(1, (contentWidth - light.sparkleSize) / 2 - math.abs(light.centerX))
            entry.glowWidth = width
        end
    end
    local function FitTallyField(entry)
        if entry.enabled == false then return end
        local value = entry.text:GetText() or ""
        local scale = entry.content:GetScale()
        if
            entry.fitText == value
            and T.NearlyEqual(entry.fitWidth, entry.fieldWidth)
            and T.NearlyEqual(entry.fitScale, scale)
        then
            return
        end
        -- Measure the full integer without a constrained box adding an ellipsis.
        -- Keep the theme scale; only long numbers need a smaller font.
        local iconWidth = entry.icon and 22 or 0
        local available = math.max(1, (entry.fieldWidth - 2) / scale - iconWidth)
        local budget = math.max(1, available - 2)
        local fontSize = 12
        T.SetFont(tallyMeasure, fontSize, "OUTLINE")
        tallyMeasure:SetText(value)
        local measured = tallyMeasure:GetStringWidth() or 0
        if value ~= "" and measured <= 0 then return end
        if measured > budget then
            fontSize = math.max(1, math.floor(fontSize * budget / measured))
            T.SetFont(tallyMeasure, fontSize, "OUTLINE")
            measured = tallyMeasure:GetStringWidth() or 0
            while fontSize > 1 and measured > budget do
                fontSize = fontSize - 1
                T.SetFont(tallyMeasure, fontSize, "OUTLINE")
                measured = tallyMeasure:GetStringWidth() or 0
            end
        end
        if value ~= "" and measured <= 0 then return end
        local baseline = math.max(1, math.min(64, entry.fieldWidth - 32))
        local textWidth = math.max(1, math.min(baseline, available), math.ceil(measured) + 2)
        if entry.fitFontSize ~= fontSize then
            T.SetFont(entry.text, fontSize, "OUTLINE")
            if entry.glow then
                for _, glow in ipairs(entry.glow) do
                    T.SetFont(glow, fontSize, "")
                end
            end
            entry.fitFontSize = fontSize
        end
        if not T.NearlyEqual(entry.fitTextWidth, textWidth) then
            -- The packaged client needs explicit FontString widths.
            entry.text:SetWidth(textWidth)
            entry.content:SetWidth(iconWidth + textWidth)
            if entry.glow then
                for _, glow in ipairs(entry.glow) do
                    glow:SetWidth(textWidth)
                end
            end
            entry.fitTextWidth = textWidth
        end
        entry.fitText, entry.fitWidth, entry.fitScale = value, entry.fieldWidth, scale
        RefreshTallyGlowBounds(entry)
    end
    local function SetTallyFieldWidth(entry, width)
        entry.frame:SetWidth(width)
        entry.fieldWidth = width
        FitTallyField(entry)
    end
    for index, counter in ipairs(counters) do
        local field = CreateFrame("Frame", nil, tallyOverlay)
        field:SetHeight(20)
        field:SetPoint("LEFT", tally, "LEFT", 8 + (index - 1) * fieldWidth, 0)
        field:EnableMouse(true)

        local content = CreateFrame("Frame", nil, field)
        content:SetHeight(20)
        content:SetPoint("CENTER", field, "CENTER", 0, 0)
        content:EnableMouse(false)

        local icon
        if counter.icon then
            icon = content:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(counter.icon)
            if counter.key == "gold" then
                -- The original 64x64 coin atlas places gold in the top-left 32x32.
                icon:SetTexCoord(0, 0.5, 0, 0.5)
            end
            icon:SetWidth(18)
            icon:SetHeight(18)
            icon:SetPoint("LEFT", content, "LEFT", 0, 0)
        end

        local text = content:CreateFontString(nil, "OVERLAY")
        T.SetFont(text, 12, "OUTLINE")
        text:SetTextColor(1, 0.88, 0.55)
        text:SetHeight(18)
        if icon then
            text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        else
            text:SetPoint("LEFT", content, "LEFT", 0, 0)
        end
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        local entry = {
            key = counter.key,
            visibility = counter.visibility,
            label = counter.label,
            icon = icon,
            text = text,
            frame = field,
            content = content,
        }
        if counter.key == "gold" then
            local glowOpacity = 1.4
            local glyphSpread = 1.25
            entry.glowWidthScale = 1.65
            entry.glow, entry.glowDirections = {}, {}
            entry.glowLights = {
                { anchor = content, centerX = -5, height = 26, sparkleSize = 5, radiusY = 9.5, offset = 0 },
            }
            for _, light in ipairs(entry.glowLights) do
                local spotlight = content:CreateTexture(nil, "BACKGROUND")
                spotlight:SetTexture(DFRL:GetInfoOrCons("tex") .. "tally\\AffordableGlow.tga")
                spotlight:SetBlendMode("ADD")
                spotlight:SetVertexColor(1, 0.86, 0.64, 0.16 * glowOpacity)
                spotlight:SetHeight(light.height)
                spotlight:SetPoint("CENTER", light.anchor, "CENTER", light.centerX, 0)
                spotlight:Hide()
                local rays = content:CreateTexture(nil, "BORDER")
                rays:SetTexture(DFRL:GetInfoOrCons("tex") .. "tally\\AffordableRays.tga")
                rays:SetBlendMode("ADD")
                rays:SetVertexColor(1, 0.87, 0.66, 0.32 * glowOpacity)
                rays:SetHeight(light.height)
                rays:SetPoint("CENTER", light.anchor, "CENTER", light.centerX, 0)
                rays:Hide()
                light.spotlight, light.rays, light.sparkles = spotlight, rays, {}
                for index = 1, 3 do
                    local sparkle = content:CreateTexture(nil, "ARTWORK")
                    sparkle:SetTexture(DFRL:GetInfoOrCons("tex") .. "tally\\AffordableSparkle.tga")
                    sparkle:SetBlendMode("ADD")
                    sparkle:SetVertexColor(1, 0.94, 0.78)
                    sparkle:SetWidth(light.sparkleSize)
                    sparkle:SetHeight(light.sparkleSize)
                    sparkle:Hide()
                    table.insert(light.sparkles, {
                        texture = sparkle,
                        offset = (index - 1) * 2 * math.pi / 3 + light.offset,
                    })
                end
            end
            for y = -1, 1 do
                for x = -1, 1 do
                    if x ~= 0 or y ~= 0 then
                        local glow = content:CreateFontString(nil, "ARTWORK")
                        T.SetFont(glow, 12, "")
                        glow:SetTextColor(1, 0.91, 0.68)
                        glow:SetAlpha(0.04 * glowOpacity)
                        glow:SetHeight(18)
                        glow:SetJustifyH("CENTER")
                        glow:SetJustifyV("MIDDLE")
                        glow:SetPoint("CENTER", text, "CENTER", x * 1.5 * glyphSpread, y * 1.5)
                        glow:Hide()
                        table.insert(entry.glow, glow)
                        local length = math.sqrt(x * x + y * y)
                        table.insert(entry.glowDirections, { x = x / length, y = y / length })
                    end
                end
            end
            local function PaintGlow()
                local c, s = math.cos(entry.glowPhase), math.sin(entry.glowPhase)
                local halfC, halfS = c / 2, s / 2
                for index, glow in ipairs(entry.glow) do
                    local direction = entry.glowDirections[index]
                    local facing = math.max(0, c * direction.x - s * direction.y)
                    glow:SetAlpha((0.04 + 0.14 * facing * facing * facing * facing) * glowOpacity)
                end
                for _, light in ipairs(entry.glowLights) do
                    light.rays:SetTexCoord(
                        0.5 - halfC - halfS,
                        0.5 + halfS - halfC,
                        0.5 - halfC + halfS,
                        0.5 + halfS + halfC,
                        0.5 + halfC - halfS,
                        0.5 - halfS - halfC,
                        0.5 + halfC + halfS,
                        0.5 - halfS + halfC
                    )
                    for _, sparkle in ipairs(light.sparkles) do
                        local twinkle = math.max(0, math.sin(entry.glowPhase * 3 + sparkle.offset * 0.7 + 0.8))
                        local alpha = 0.55 * twinkle * twinkle * twinkle * twinkle
                        if alpha > 0.01 then
                            local angle = entry.glowPhase + sparkle.offset
                            sparkle.texture:SetPoint(
                                "CENTER",
                                light.anchor,
                                "CENTER",
                                light.centerX + light.radiusX * math.cos(angle),
                                -light.radiusY * math.sin(angle)
                            )
                            sparkle.texture:SetAlpha(alpha * glowOpacity)
                            if not sparkle.shown then sparkle.texture:Show() end
                            sparkle.shown = true
                        elseif sparkle.shown then
                            sparkle.texture:Hide()
                            sparkle.shown = false
                        end
                    end
                end
            end
            function entry.StopGlow()
                if not entry.glowRunning then return end
                entry.glowRunning = false
                content:SetScript("OnUpdate", nil)
                for _, light in ipairs(entry.glowLights) do
                    light.rays:Hide()
                    for _, sparkle in ipairs(light.sparkles) do
                        sparkle.texture:Hide()
                        sparkle.shown = false
                    end
                end
                entry.glowAge, entry.glowPhase = nil, nil
            end
            local function AnimateGlow()
                if not entry.affordable or not content:IsVisible() then
                    entry.StopGlow()
                    return
                end
                local elapsed = math.max(0, math.min(tonumber(arg1) or 0, 0.1))
                entry.glowPhase = math.mod(entry.glowPhase + elapsed * 2 * math.pi / 4.8, 2 * math.pi)
                entry.glowAge = entry.glowAge + elapsed
                if entry.glowAge < 1 / 30 then return end
                entry.glowAge = 0
                PaintGlow()
            end
            function entry.StartGlow()
                if entry.glowRunning or not entry.affordable or not content:IsVisible() then return end
                entry.glowRunning = true
                entry.glowAge, entry.glowPhase = 0, 0
                PaintGlow()
                for _, light in ipairs(entry.glowLights) do
                    light.rays:Show()
                end
                content:SetScript("OnUpdate", AnimateGlow)
            end
            content:SetScript("OnShow", entry.StartGlow)
            content:SetScript("OnHide", entry.StopGlow)
            goldField = entry
        end
        SetTallyFieldWidth(entry, fieldWidth)
        table.insert(tallyFields, entry)
        field:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:AddLine(DFRL.locale.Text(entry.label), 1, 0.82, 0)
            GameTooltip:AddLine(entry.text:GetText() or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        field:SetScript("OnLeave", function() GameTooltip:Hide() end)
        T.RegisterTooltipIcon(field, icon or text)

        if index > 1 then
            local divider = tallyOverlay:CreateTexture(nil, "ARTWORK")
            divider:SetTexture("Interface\\Buttons\\WHITE8X8")
            divider:SetVertexColor(0.9, 0.7, 0.3, 0.6)
            divider:SetWidth(1)
            divider:SetHeight(15)
            divider:SetPoint("LEFT", field, "LEFT", 0, 0)
            entry.divider = divider
        end
    end

    local function SetGoldHighlight(affordable)
        if affordable then
            local text = goldField.text:GetText() or ""
            if goldField.glowText ~= text then
                goldField.glowText = text
                for _, glow in ipairs(goldField.glow) do
                    glow:SetText(text)
                end
            end
            RefreshTallyGlowBounds(goldField)
        end
        if goldField.affordable == affordable then return end
        goldField.affordable = affordable
        for _, glow in ipairs(goldField.glow) do
            if affordable then
                glow:Show()
            else
                glow:SetText("")
                glow:Hide()
            end
        end
        if affordable then
            for _, light in ipairs(goldField.glowLights) do
                light.spotlight:Show()
            end
            goldField.StartGlow()
        else
            goldField.StopGlow()
            for _, light in ipairs(goldField.glowLights) do
                light.spotlight:Hide()
            end
            goldField.glowText, goldField.glowWidth = nil, nil
        end
    end

    do
        local detached = CreateFrame("Frame", "SurvivorsDragonUiDetachedRunTally", UIParent)
        detached:SetHeight(tally:GetHeight())
        detached:SetFrameStrata("HIGH")
        detached:EnableMouse(false)
        detached:Hide()
        local docked, lastBottom, lastWidth, lastStyle, lastMask
        local artwork = tally:CreateTexture(nil, "BACKGROUND")
        artwork:SetTexCoord(0, DFRL.tallyStyleCanvas.right, 0, DFRL.tallyStyleCanvas.bottom)
        artwork:SetPoint("TOPLEFT", tally, "TOPLEFT", 0, 0)
        artwork:Hide()

        function tallyAttachment.SetShown(shown)
            tallyAttachment.shown = shown
            if not tallyAttachment.ready then return end
            local visible = shown and visibleTallyFields > 0
            if docked or not visible then
                detached:Hide()
            else
                detached:Show()
            end
            if visible then
                tally:Show()
            else
                tally:Hide()
            end
            DFRL.SetRunTallyBarExtent(docked and visible and tally:GetHeight() or 0)
        end

        function tallyAttachment.Refresh(force)
            if not tallyAttachment.ready then return end
            local joined = DFRL.display.Get("attachTally")
            local bottom = joined and DFRL.GetActionBarSilverBottom() or nil
            local style = DFRL.tallyStyleById[DFRL.display.Get("tallyStyle")]
            local appearance = not joined and style.detached or style
            local mask = ""
            visibleTallyFields = 0
            for _, entry in ipairs(tallyFields) do
                entry.enabled = DFRL.display.Get(entry.visibility)
                mask = mask .. (entry.enabled and "1" or "0")
                if entry.enabled then visibleTallyFields = visibleTallyFields + 1 end
            end
            if not force and docked == joined and lastBottom == bottom and lastStyle == style and lastMask == mask then
                return
            end
            tally:Hide()
            docked, lastBottom, lastStyle, lastMask = joined, bottom, style, mask
            local owner = joined and DFRL.mainBar or detached
            if tally:GetParent() ~= owner then tally:SetParent(owner) end
            tally:SetScale(1)
            local strata = joined and "LOW" or "HIGH"
            tally:SetFrameStrata(strata)
            tallyOverlay:SetFrameStrata(strata)
            tally:SetFrameLevel(owner:GetFrameLevel() + 2)
            tallyOverlay:SetFrameLevel(tally:GetFrameLevel() + 2)
            tally:ClearAllPoints()
            local artScale = lastWidth / DFRL.tallyStyleCanvas.width
            local height = appearance.extent * artScale
            tally:SetHeight(height)
            detached:SetHeight(height)
            if joined then
                tally:SetPoint("TOP", owner, "BOTTOM", 0, bottom)
            else
                tally:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
            end
            artwork:SetTexture(DFRL:GetInfoOrCons("tex") .. "tally\\" .. appearance.texture)
            artwork:SetWidth(lastWidth)
            artwork:SetHeight(DFRL.tallyStyleCanvas.height * artScale)
            artwork:Show()
            local rowCenter, contentScale = appearance.contentY * artScale, style.contentScale
            local divided = style.id == "silver" or style.id == "graphite"
            local inset = divided and 8 or 40 * artScale
            local sectionWidth = (lastWidth - 2 * inset) / math.max(1, visibleTallyFields)
            local visibleIndex = 0
            for _, entry in ipairs(tallyFields) do
                entry.frame:SetFrameStrata(strata)
                entry.frame:SetFrameLevel(tallyOverlay:GetFrameLevel() + 1)
                entry.content:SetFrameStrata(strata)
                entry.content:SetFrameLevel(entry.frame:GetFrameLevel() + 1)
                entry.content:SetScale(contentScale)
                if entry.enabled then
                    SetTallyFieldWidth(entry, sectionWidth)
                    entry.frame:ClearAllPoints()
                    entry.frame:SetPoint("LEFT", tally, "TOPLEFT", inset + visibleIndex * sectionWidth, -rowCenter)
                    entry.frame:Show()
                else
                    entry.frame:Hide()
                end
                if entry.divider then
                    if entry.enabled and visibleIndex > 0 and divided then
                        entry.divider:SetVertexColor(0.55, 0.56, 0.58, 0.6)
                        entry.divider:Show()
                    else
                        entry.divider:Hide()
                    end
                end
                if entry.enabled then visibleIndex = visibleIndex + 1 end
            end
            DFRL.layout.Place("runTally", detached)
            tallyAttachment.SetShown(tallyAttachment.shown)
        end
        DFRL.RefreshRunTallyAttachment = tallyAttachment.Refresh

        function DFRL.AttachRunTally()
            local action = DFRL.actionBarDefaults
            if not DFRL.mainBar or not action or not DFRL.GetActionBarSilverBottom then return false end
            local width = DFRL.mainBar:GetWidth() + 2 * action.sideInset
            if not IsNumber(width) or width <= 70 then return false end
            local resized = lastWidth ~= width
            if resized then
                tally:SetWidth(width)
                detached:SetWidth(width)
                lastWidth = width
            end
            if not tallyAttachment.ready then
                DFRL.layout.Register("runTally", detached, function()
                    detached:ClearAllPoints()
                    detached:SetPoint("TOP", UIParent, "BOTTOM", 0, math.max(39, detached:GetHeight()))
                end, { onlyWhenShown = true, refreshDefault = true })
                tallyAttachment.ready = true
            end
            tallyAttachment.Refresh(resized)
            return true
        end
        DFRL.display.Listen(function()
            tallyPresentationDirty = true
            tallyAttachment.Refresh()
        end)
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
    local render = { emptySchedule = {} }
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
        if render.tallyShown then
            render.tallyShown = false
            tallyAttachment.SetShown(false)
        end
        for _, field in ipairs(tallyFields) do
            T.SetTextIfChanged(field.text, "")
        end
        SetGoldHighlight(false)
        Restore("tally")
    end

    local function UpdateTally()
        tallyPresentationDirty = false
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
        if not tallyAttachment.ready and not DFRL.AttachRunTally() then
            ClearTally()
            return
        end
        for _, field in ipairs(tallyFields) do
            T.SetTextIfChanged(field.text, tostring(math.floor(state[field.key])))
            FitTallyField(field)
        end
        SetGoldHighlight(DFRL.display.Get("highlightAffordableCache") and state.gold >= state.chest)
        if not render.tallyShown then
            render.tallyShown = true
            tallyAttachment.SetShown(true)
        end
        if not TakeOver("tally") then ClearTally() end
    end

    local function HideDebuff(icon)
        if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
        if icon:IsShown() then icon:Hide() end
        if icon.iconPath or icon.effect then icon.texture:SetTexture(nil) end
        icon.iconPath = nil
        T.SetTextIfChanged(icon.count, "")
        T.SetTextIfChanged(icon.time, "")
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
        T.SetTextIfChanged(row.name, "")
        T.SetTextIfChanged(row.health, "")
        if row.value ~= 0 then row.bar:SetValue(0) end
        row.value, row.layoutOffset = 0, nil
        row.id, row.key = nil, nil
        table.insert(spareRows, row)
    end

    local function ClearRows()
        for key, row in pairs(activeRows) do
            Retire(row)
            activeRows[key] = nil
        end
        for index in ipairs(rowOrder) do
            rowOrder[index] = nil
        end
        table.setn(rowOrder, 0)
        if render.bossShown then
            render.bossShown = false
            bossGroup:Hide()
        end
        render.rowsDirty, render.rowsPresentationDirty = nil, nil
    end

    local function ShowMarkerGlow(marker, shown)
        if marker.glowShown == shown then return end
        marker.glowShown = shown
        for _, glow in ipairs(marker.glow) do
            if shown then
                glow.texture:Show()
            else
                glow.texture:Hide()
            end
        end
    end

    local function HideMarkerTooltip(marker)
        if GameTooltip and GameTooltip:IsOwned(marker) then GameTooltip:Hide() end
    end

    local function ShowMarkerTooltip(marker)
        if not GameTooltip then return end
        if not marker.name then
            HideMarkerTooltip(marker)
            return
        end
        GameTooltip:SetOwner(marker, "ANCHOR_BOTTOM")
        GameTooltip:SetText(marker.name, 1, 0.82, 0)
        GameTooltip:Show()
    end

    local function HideMarker(marker)
        HideMarkerTooltip(marker)
        if marker:IsShown() then marker:Hide() end
        if marker.check:IsShown() then marker.check:Hide() end
        ShowMarkerGlow(marker, false)
        marker.state = nil
    end

    local function ReleaseClock()
        if render.runShown then
            render.runShown = false
            run:Hide()
        end
        ClearClockCaptions()
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
                name = type(entry.name) == "string" and entry.name ~= "" and entry.name or nil,
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
        if not IsNumber(state.t) or not IsNumber(state.bs) or not IsNumber(state.bk) or not IsNumber(state.kills) then
            return nil
        end
        local sample = render.sample
        if
            not sample
            or sample.t ~= state.t
            or sample.bs ~= state.bs
            or sample.bk ~= state.bk
            or sample.kills ~= state.kills
        then
            sample = { t = state.t, bs = state.bs, bk = state.bk, kills = state.kills }
            render.sample = sample
        end
        return sample
    end

    local function AcceptedSchedule(source, maximum, expected, replay)
        local key = replay and "replayValidation" or "nativeValidation"
        local cache = render[key] or {}
        render[key] = cache
        if
            cache.source ~= source
            or cache.sequence ~= scheduleSequence
            or cache.maximum ~= maximum
            or cache.expected ~= expected
            or not cache.read
        then
            cache.entries = ValidateSchedule(source, maximum, expected)
            cache.spawned, cache.killed = 0, 0
            if cache.entries then
                for _, entry in ipairs(cache.entries) do
                    if entry.state ~= "due" then cache.spawned = cache.spawned + 1 end
                    if entry.state == "dead" then cache.killed = cache.killed + 1 end
                end
            end
            cache.source, cache.sequence = source, scheduleSequence
            cache.maximum, cache.expected, cache.read = maximum, expected, true
        end
        return cache.entries
    end

    local function ScheduleMarkers(maximum, phase)
        local expected = ExpectedBosses()
        if not expected then return nil end
        local sample = not zoneRunPending and phase ~= "ready" and ScheduleSample(maximum, expected) or nil
        local entries
        -- After a known run boundary, retained native tables are not a fresh
        -- schedule. Packet order is recorded before reading the parsed tables.
        if scheduleSequence > scheduleBarrier then entries = AcceptedSchedule(AZS_SCHEDULE, maximum, expected) end
        if entries then
            local cached = scheduleCache
            scheduleCache = nil
            if sample then
                local validation = render.nativeValidation
                -- The two prefixes can arrive separately. Never stamp new run
                -- counters onto old schedule states for the next reload.
                if
                    validation.spawned == math.min(expected, sample.bs)
                    and validation.killed == math.min(expected, sample.bk)
                then
                    local hero = UnitName("player")
                    if
                        type(cached) == "table"
                        and cached.entries == entries
                        and cached.sample == sample
                        and cached.hero == hero
                    then
                        scheduleCache = cached
                    else
                        scheduleCache = {
                            version = 1,
                            maximum = maximum,
                            expected = expected,
                            hero = hero,
                            entries = entries,
                            sample = sample,
                        }
                    end
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
        entries = AcceptedSchedule(cache.entries, maximum, expected, true)
        if not entries then
            scheduleCache = nil
            return nil
        end
        cache.sample = sample
        return entries
    end

    local function InvalidateSchedule(sequence)
        scheduleCache = nil
        render.nativeValidation, render.replayValidation, render.sample = nil, nil, nil
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
                marker:SetScript("OnEnter", function() ShowMarkerTooltip(marker) end)
                marker:SetScript("OnLeave", function() HideMarkerTooltip(marker) end)
                T.RegisterTooltipIcon(marker)
                marker.glow = {}
                marker.glowCardinal = CreateFrame("Frame", nil, marker)
                marker.glowDiagonal = CreateFrame("Frame", nil, marker)
                marker.glowCardinal:SetPoint("CENTER", marker, "CENTER", 0, 0)
                marker.glowDiagonal:SetPoint("CENTER", marker, "CENTER", 0, 0)
                marker.glowCardinal:SetWidth(2 * ACTIVE_GLOW_MIN_OFFSET)
                marker.glowCardinal:SetHeight(2 * ACTIVE_GLOW_MIN_OFFSET)
                marker.glowDiagonal:SetWidth(2 * ((1 / math.sqrt(2)) * ACTIVE_GLOW_MIN_OFFSET))
                marker.glowDiagonal:SetHeight(2 * ((1 / math.sqrt(2)) * ACTIVE_GLOW_MIN_OFFSET))
                marker.glowCardinal:Hide()
                marker.glowDiagonal:Hide()
                marker.glowOffset = ACTIVE_GLOW_MIN_OFFSET
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
                            local point = (y == 1 and "TOP" or y == -1 and "BOTTOM" or "")
                                .. (x == 1 and "RIGHT" or x == -1 and "LEFT" or "")
                            glow:SetPoint(
                                "CENTER",
                                distance == 1 and marker.glowCardinal or marker.glowDiagonal,
                                point,
                                0,
                                0
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
            if marker.name ~= entry.name then
                marker.name = entry.name
                marker:EnableMouse(marker.name ~= nil)
                if GameTooltip and GameTooltip:IsOwned(marker) then ShowMarkerTooltip(marker) end
            end
            markerStates[index] = entry.state
            if marker.at ~= at or marker.maximum ~= maximum then
                marker:ClearAllPoints()
                if at == maximum then
                    marker:SetPoint("RIGHT", runBar, "RIGHT", 0, 0)
                else
                    marker:SetPoint("CENTER", runBar, "LEFT", BAR_WIDTH * at / maximum, 0)
                end
                marker.at, marker.maximum = at, maximum
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
                    if marker.glowOffset ~= glowOffset then
                        local cardinalSide, diagonalSide = 2 * glowOffset, 2 * ((1 / math.sqrt(2)) * glowOffset)
                        marker.glowCardinal:SetWidth(cardinalSide)
                        marker.glowCardinal:SetHeight(cardinalSide)
                        marker.glowDiagonal:SetWidth(diagonalSide)
                        marker.glowDiagonal:SetHeight(diagonalSide)
                        marker.glowOffset = glowOffset
                    end
                    for _, glow in ipairs(marker.glow) do
                        glow.texture:SetAlpha(glowAlpha)
                    end
                end
                if not marker:IsShown() then marker:Show() end
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
        local showGuardians = DFRL.display.Get("guardiansInBossBar")
        local guardians = showGuardians and Read("AZS_GetGuardians") or nil
        -- The native "bosses" part includes guardians. Only awake guardians
        -- are fighting; the full list also includes sleeping lairs on the map.
        -- Boss-only mode does not depend on the excluded guardian list.
        if type(bosses) ~= "table" or (showGuardians and type(guardians) ~= "table") then return nil end
        local entries, seen = render.encounters or {}, render.encounterSeen or {}
        render.encounters, render.encounterSeen = entries, seen
        for key in pairs(seen) do
            seen[key] = nil
        end
        local used = 0
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
                    used = used + 1
                    local copy = entries[used] or {}
                    copy.key, copy.id, copy.kind = key, entry.id, kind
                    copy.name, copy.hp, copy.maximum = entry.name, entry.hp, entry.hpm
                    entries[used] = copy
                end
            end
            return true
        end
        if not Append(bosses, "boss") or (showGuardians and not Append(guardians, "guardian")) then return nil end
        for index = used + 1, table.getn(entries) do
            entries[index] = nil
        end
        table.setn(entries, used)
        return entries, seen
    end

    local function NewRow()
        local row = table.remove(spareRows)
        if row then return row end
        createdRows = createdRows + 1
        local frame, bar, name, rowOverlay = Pill("DFRL_BossHealthPill" .. tostring(createdRows), "FillWhite")
        frame:SetParent(bossGroup)
        T.SetFont(name, 12, "OUTLINE")
        name:SetWidth(BAR_WIDTH)
        local health = rowOverlay:CreateFontString(nil, "OVERLAY")
        health:SetPoint("CENTER", frame, "CENTER", 0, 0)
        T.StyleEncounterHealth(bar, health)
        return { frame = frame, bar = bar, name = name, health = health, debuffs = {} }
    end

    local function Permanent(effect) return effect.permanent == true or effect.permanent == 1 end

    local function DebuffRemaining(effect)
        if not Permanent(effect) and IsNumber(effect.remaining) then return effect.remaining end
    end

    local function DebuffTooltip(icon)
        local effect = icon.effect
        if not GameTooltip or not effect then return end
        GameTooltip:SetText(
            type(effect.name) == "string" and effect.name ~= "" and effect.name or DFRL.locale.Text("Debuff"),
            1,
            1,
            1
        )
        if IsNumber(effect.stacks) and effect.stacks > 1 then
            GameTooltip:AddLine(DFRL.locale.Text("Stacks: ") .. tostring(math.floor(effect.stacks)), 1, 1, 1)
        end
        if type(effect.dispelType) == "string" and effect.dispelType ~= "" then
            GameTooltip:AddLine(DFRL.locale.Text(effect.dispelType), 0.65, 0.8, 1)
        end
        local remaining = DebuffRemaining(effect)
        if Permanent(effect) then
            GameTooltip:AddLine(DFRL.locale.Text("No expiration"), 1, 0.85, 0.4)
        elseif remaining then
            GameTooltip:AddLine(DFRL.locale.Text("Remaining: ") .. Clock(math.ceil(remaining)), 1, 0.85, 0.4)
        else
            GameTooltip:AddLine(DFRL.locale.Text("Remaining time unavailable"), 0.7, 0.7, 0.7)
        end
        if not Permanent(effect) and IsNumber(effect.duration) and effect.duration > 0 then
            GameTooltip:AddLine(DFRL.locale.Text("Duration: ") .. Clock(math.ceil(effect.duration)), 0.8, 0.8, 0.8)
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
        T.SetFont(icon.count, 10, "OUTLINE")
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
        icon.time = icon:CreateFontString(nil, "OVERLAY")
        T.SetFont(icon.time, 8, "OUTLINE")
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
        T.RegisterTooltipIcon(icon, nil, "below")
        row.debuffs[index] = icon
        return icon
    end

    local function UpdateDebuffs(row, enabled)
        local count = 0
        local paint = bossGroup:IsVisible()
        local getter = _G.AZS_GetDebuffs
        if enabled and type(getter) == "function" then
            -- The getter owns timing and returns current effects for this exact
            -- spawn, including when no unit is targeted. Never advance a local clock.
            local ok, effects = pcall(getter, row.id)
            if ok and type(effects) == "table" then
                for _, effect in ipairs(effects) do
                    if type(effect) == "table" and type(effect.icon) == "string" and effect.icon ~= "" then
                        count = count + 1
                        if paint then
                            local icon = DebuffIcon(row, count)
                            icon.effect = effect
                            if icon.iconPath ~= effect.icon then
                                local loaded = icon.texture:SetTexture(effect.icon)
                                local assigned = icon.texture:GetTexture()
                                local stem = string.gsub(effect.icon, "%.[^%.]*$", "")
                                icon.iconPath = loaded ~= false
                                        and (assigned == effect.icon or assigned == stem)
                                        and effect.icon
                                    or nil
                            end
                            T.SetTextIfChanged(
                                icon.count,
                                IsNumber(effect.stacks) and effect.stacks > 1 and tostring(math.floor(effect.stacks))
                                    or ""
                            )
                            local remaining = DebuffRemaining(effect)
                            local text = ""
                            if remaining then
                                text = remaining >= 60 and (tostring(math.ceil(remaining / 60)) .. "m")
                                    or tostring(math.ceil(remaining))
                            end
                            T.SetTextIfChanged(icon.time, text)
                            if not icon:IsShown() then icon:Show() end
                            if GameTooltip and GameTooltip:IsOwned(icon) then DebuffTooltip(icon) end
                        end
                    end
                end
            end
        end
        if paint then
            for index = count + 1, table.getn(row.debuffs) do
                HideDebuff(row.debuffs[index])
            end
        end
        return math.ceil(count / DEBUFF_COLUMNS) * (DEBUFF_SIZE + DEBUFF_GAP)
    end

    local function ReflowRows()
        local offset = 0
        for _, row in ipairs(rowOrder) do
            if row.layoutOffset ~= offset then
                row.frame:ClearAllPoints()
                row.frame:SetPoint("TOP", bossGroup, "TOP", 0, -16 - offset)
                row.layoutOffset = offset
            end
            offset = offset + ROW_HEIGHT + (row.debuffHeight or 0)
        end
        local height = math.max(47, offset - 1)
        if not T.NearlyEqual(bossGroup:GetHeight(), height) then
            bossGroup:SetHeight(height)
            DFRL.layout.Place("bossBars", bossGroup)
        end
    end

    local function UpdateDebuffRows(phase, reflow)
        local enabled = phase ~= "ready" and phase ~= "dead" and DFRL.display.Get("bossDebuffs")
        for _, row in ipairs(rowOrder) do
            local height = UpdateDebuffs(row, enabled)
            if row.debuffHeight ~= height then reflow = true end
            row.debuffHeight = height
        end
        if reflow or render.rowsDirty then
            if bossGroup:IsVisible() then
                ReflowRows()
                render.rowsDirty = nil
            else
                render.rowsDirty = true
            end
        end
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
        local shown = count > 0
        if render.bossShown ~= shown then
            render.bossShown = shown
            if shown then
                bossGroup:Show()
            else
                bossGroup:Hide()
            end
        end
        local paint = bossGroup:IsVisible()
        render.rowsPresentationDirty = not paint and shown or nil
        local reflow = count ~= table.getn(rowOrder)
        for index, entry in ipairs(entries) do
            local row = activeRows[entry.key]
            if not row then
                row = NewRow()
                activeRows[entry.key] = row
                reflow = true
            end
            row.key = entry.key
            row.id = entry.id
            if paint then
                local value = math.min(1, entry.hp / entry.maximum)
                if row.value ~= value then row.bar:SetValue(value) end
                row.value = value
                T.SetTextIfChanged(row.name, entry.name)
                T.SetTextIfChanged(row.health, T.EncounterHealthText(entry.hp, entry.maximum))
                if not row.frame:IsShown() then row.frame:Show() end
            end
            if rowOrder[index] ~= row then reflow = true end
            rowOrder[index] = row
        end
        for index = count + 1, table.getn(rowOrder) do
            rowOrder[index] = nil
        end
        table.setn(rowOrder, count)
        UpdateDebuffRows(phase, reflow)
        if not TakeOver("bosses") then
            ClearRows()
            Restore("bosses")
        end
    end

    DFRL.display.Listen(function()
        UpdateDisplayLabels()
        RefreshTimerCaptions()
        refreshRows = true
        -- Clearing is immediate even outside a run; valid encounters will reflow
        -- on the next native HUD update without affecting clock takeover.
        for _, row in pairs(activeRows) do
            ClearDebuffs(row)
        end
    end)

    -- Keep boundary and clock work in separate closures. Lua 5.0 permits only
    -- 32 captured locals per closure; the combined HUD update exceeded that
    -- limit and prevented this entire module from compiling on the new client.
    local function UpdateRunBoundary(phase)
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
    end

    local function UpdateClock(phase)
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
            if not render.runShown then
                render.runShown = true
                run:Show()
            end
            if run:IsVisible() then
                if render.runMaximum ~= maximum then runBar:SetMinMaxValues(0, maximum) end
                local value = math.min(maximum, seconds)
                if render.runValue ~= value then runBar:SetValue(value) end
                render.runMaximum, render.runValue = maximum, value
                local atLimit = seconds >= maximum
                SetRunAppearance(atLimit)
                UpdateRunFlow(seconds, maximum)
                UpdateClockCaptions(seconds, maximum, not zoneRunPending)
                -- Missing schedule replay affects only spawn markers, never a clock
                -- whose native elapsed time and duration have already recovered.
                if
                    refreshRows
                    or render.clockHidden
                    or render.markerEntries ~= scheduled
                    or render.markerMaximum ~= maximum
                then
                    UpdateMarkers(maximum, scheduled or render.emptySchedule)
                    render.markerEntries, render.markerMaximum = scheduled, maximum
                end
                UpdateMarkerStates(atLimit)
                render.clockHidden = nil
            else
                render.clockHidden = true
            end
            if not TakeOver("clock") then ReleaseClock() end
        else
            ReleaseClock()
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
            if phase ~= nil then InvalidateSchedule(packetSequence) end
            ReleaseHUD()
            return
        end
        UpdateRunBoundary(phase)
        UpdateClock(phase)
        if render.rowsPresentationDirty and bossGroup:IsVisible() then refreshRows = true end
        -- A missing zone/clock snapshot must not block valid counters or
        -- encounter lists from reconnecting to their own native HUD parts.
        if refreshRows then
            refreshRows = false
            UpdateTally()
            UpdateRows(phase)
        else
            if tallyPresentationDirty then UpdateTally() end
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
                ClearClockCaptions()
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
