-- The War Within artwork: Karl-HeinzSchneider, MIT; shipped notice in
-- media/tex/meter/LICENSE.txt. Pinned source: third_party/DetailsTWW-ARTWORK.md.
-- The existing gold ring retains third_party/Jewelry-ARTWORK.md's provenance.
DFRL:NewMod("DamageMeter", 7, function()
    local WIDTH, HEADER, ROW_HEIGHT, FOOTER = 320, 32, 32, 32
    local enabled = DFRL.display.Get("meterEnabled")
    local visible = DFRL.display.Get("meterRows")
    local optionKeys = {
        damage = "meterShowDamage",
        dps = "meterShowDps",
        percentage = "meterShowPercentage",
        icons = "meterShowIcons",
        ranks = "meterShowRanks",
        total = "meterShowTotal",
        totalDps = "meterShowTotalDps",
    }
    local options, optionsRevision = {}, 0
    for key, setting in pairs(optionKeys) do
        options[key] = DFRL.display.Get(setting)
    end
    local ICON_SIZE, RIM_SIZE = 26, 31
    local UNKNOWN_ICON = T.SourceIconFallback
    local path = DFRL:GetInfoOrCons("tex")
    local native = T.NewHudOwner("meter", "hudMeter")
    local modes = {
        { getter = "AZS_GetMeter", prefix = "AZSMETER", title = "Damage Done", rate = "DPS" },
        { getter = "AZS_GetHealing", prefix = "AZSHEAL", title = "Healing Done", rate = "HPS", healing = true },
        { getter = "AZS_GetBossMeter", prefix = "AZSBOSSDMG", title = "Boss Damage", rate = "DPS" },
    }
    local phases = { playing = true, choosing = true, paused = true, dead = true, victory = true }
    local mode, offset, age = 1, 0, 0.2
    local inWorld, editing, ready, faulted = true, false, true, false
    local rows, received, blocked = {}, {}, {}
    local dataDirty, dataValid = true, false
    local snapshot = { rows = {}, count = 0 }
    local rateSamples, rateSampledAt = {}, nil
    local presentation = { shown = false, cleared = true }
    local tooltipState = {}
    local hovered
    local root = CreateFrame("Frame", "DFRL_DamageMeter", UIParent)
    root:SetScale(0.8)
    root:SetWidth(WIDTH)
    root:SetHeight(HEADER + visible * ROW_HEIGHT + FOOTER)
    root:SetFrameStrata("MEDIUM")
    root:EnableMouse(true)
    root:EnableMouseWheel(true)
    root:Hide()
    local controller = CreateFrame("Frame")
    local Tick, updating, listening = nil, false, false
    local function UpdateController()
        local listen = inWorld and enabled and ready and not faulted and true or false
        if listening ~= listen then
            listening = listen
            if listen then
                controller:RegisterEvent("CHAT_MSG_ADDON")
            else
                controller:UnregisterEvent("CHAT_MSG_ADDON")
            end
        end
        local active = inWorld and (listen or native.IsCaptured()) and true or false
        if updating == active then return end
        updating = active
        if active then
            controller:RegisterEvent("CVAR_UPDATE")
        else
            controller:UnregisterEvent("CVAR_UPDATE")
        end
        controller:SetScript("OnUpdate", active and Tick or nil)
    end

    local function SetShown(shown)
        if presentation.shown == shown then return end
        presentation.shown = shown
        if shown then
            root:Show()
        else
            root:Hide()
        end
    end

    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end
    local function Compact(value)
        if value >= 1000000000 then return string.format("%.1fB", value / 1000000000) end
        if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
        if value >= 1000 then return string.format("%.1fK", value / 1000) end
        return string.format("%.0f", value)
    end
    local function HeaderText(amount, rate)
        local text = ""
        if options.total then text = DFRL.locale.Text("Total") .. ": " .. (amount and Compact(amount) or "--") end
        if options.totalDps then
            text = text
                .. (text ~= "" and "   " or "")
                .. DFRL.locale.Text(modes[mode].rate)
                .. ": "
                .. (rate and Compact(rate) or "--")
        end
        return text ~= "" and text or DFRL.locale.Text(modes[mode].title)
    end
    local function Label(parent, size, justify)
        local label = parent:CreateFontString(nil, "OVERLAY")
        T.SetFont(label, size, "")
        if not label:GetFont() then ready = false end
        label:SetJustifyH(justify or "LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(1, 1, 1)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        return label
    end
    local function Texture(parent, name, layer)
        local texture = parent:CreateTexture(nil, layer)
        if texture:SetTexture(path .. "meter\\" .. name .. ".blp") == false then ready = false end
        return texture
    end
    local function ClearIconParts(row)
        for _, strip in ipairs(row.iconParts) do
            if strip.boundTexture then strip:SetTexture(nil) end
            strip.boundTexture = nil
            if strip:IsShown() then strip:Hide() end
        end
    end
    local function ClearIcon(row)
        if row.iconPath or row.iconNative then row.icon:SetTexture(nil) end
        if row.icon:IsShown() then row.icon:Hide() end
        if row.rim:IsShown() then row.rim:Hide() end
        ClearIconParts(row)
        row.iconPath, row.iconNative, row.nativeFailedIcon = nil, nil, nil
    end
    local function BindIcon(row, icon)
        if not icon then
            ClearIcon(row)
            return false
        end
        if row.iconPath == icon and row.iconNative then return true end
        local scale = row:GetEffectiveScale()
        if type(scale) ~= "number" or scale - scale ~= 0 or scale <= 0 then
            ClearIcon(row)
            return false
        end
        if row.iconPath == icon and T.NearlyEqual(row.iconScale, scale) then return true end
        local stem = string.gsub(icon, "%.[^%.]*$", "")
        if row.nativeFailedIcon ~= icon and type(_G.SetPortraitToTexture) == "function" then
            local ok = pcall(_G.SetPortraitToTexture, row.icon:GetName(), icon)
            local assigned = row.icon:GetTexture()
            if ok and (assigned == icon or assigned == stem) then
                ClearIconParts(row)
                if not row.icon:IsShown() then row.icon:Show() end
                row.iconPath, row.iconNative, row.nativeFailedIcon = icon, true, nil
                return true
            end
            row.nativeFailedIcon = icon
        end
        row.icon:SetTexture(nil)
        if row.icon:IsShown() then row.icon:Hide() end
        row.iconPath, row.iconNative = nil, nil
        if not T.NearlyEqual(row.iconScale, scale) then
            -- Match the pet fallback's circular boundary at physical-pixel steps.
            local radius = ICON_SIZE / 2
            local parts = math.max(4, math.ceil(ICON_SIZE * scale))
            local step, used = ICON_SIZE / parts, 0
            for part = 1, parts do
                local top, bottom = (part - 1) * step, part * step
                local edge = math.max(math.abs(top - radius), math.abs(bottom - radius))
                local half = math.sqrt(math.max(0, radius * radius - edge * edge))
                if half > 0 then
                    used = used + 1
                    local strip = row.iconParts[used]
                    if not strip then
                        strip = row:CreateTexture(nil, "ARTWORK")
                        strip:Hide()
                        table.insert(row.iconParts, strip)
                    end
                    strip:ClearAllPoints()
                    strip:SetPoint("TOPLEFT", row, "LEFT", radius - half, radius - top)
                    strip:SetWidth(half * 2)
                    strip:SetHeight(step)
                    strip:SetTexCoord(
                        (radius - half) / ICON_SIZE,
                        (radius + half) / ICON_SIZE,
                        top / ICON_SIZE,
                        bottom / ICON_SIZE
                    )
                end
            end
            row.iconUsed, row.iconScale = used, scale
        end
        local usable = true
        for index, strip in ipairs(row.iconParts) do
            if index <= row.iconUsed then
                if strip.boundTexture ~= icon then
                    strip.boundTexture = nil
                    local loaded = strip:SetTexture(icon)
                    local assigned = strip:GetTexture()
                    if loaded ~= false and (loaded == true or loaded == 1 or assigned == icon or assigned == stem) then
                        strip.boundTexture = icon
                    else
                        strip:SetTexture(nil)
                    end
                end
                if not strip.boundTexture then usable = false end
            else
                if strip.boundTexture then strip:SetTexture(nil) end
                strip.boundTexture = nil
                if strip:IsShown() then strip:Hide() end
            end
        end
        for index = 1, row.iconUsed do
            local strip = row.iconParts[index]
            if usable then
                if not strip:IsShown() then strip:Show() end
            elseif strip:IsShown() then
                strip:Hide()
            end
        end
        if usable then row.iconPath = icon end
        return usable
    end
    local function HideTooltip()
        if not hovered then return end
        if hovered and GameTooltip and GameTooltip:IsOwned(hovered) then GameTooltip:Hide() end
        hovered = nil
        for key in pairs(tooltipState) do
            tooltipState[key] = nil
        end
    end
    local function ShowRowTooltip(row)
        if editing or not row.entry or not GameTooltip then return end
        local entry, language, scale = row.entry, DFRL.locale.code, GameTooltip:GetEffectiveScale()
        local damage = string.format("%.0f", entry.dmg)
        local rate = string.format("%.1f", entry.dps)
        local share = string.format("%.1f%%", entry.share * 100)
        if
            hovered == row
            and GameTooltip:IsOwned(row)
            and tooltipState.name == entry.name
            and tooltipState.damage == damage
            and tooltipState.rate == rate
            and tooltipState.share == share
            and tooltipState.mode == mode
            and tooltipState.language == language
            and T.NearlyEqual(tooltipState.scale, scale)
        then
            return
        end
        HideTooltip()
        hovered = row
        GameTooltip:SetOwner(row, "ANCHOR_NONE")
        GameTooltip:SetText(row.entry.name)
        GameTooltip:AddDoubleLine(DFRL.locale.Text(modes[mode].title), damage)
        GameTooltip:AddDoubleLine(DFRL.locale.Text(modes[mode].rate), rate)
        GameTooltip:AddDoubleLine(DFRL.locale.Text("Share"), share)
        GameTooltip:Show()
        tooltipState.name, tooltipState.damage, tooltipState.rate, tooltipState.share = entry.name, damage, rate, share
        tooltipState.mode, tooltipState.language, tooltipState.scale = mode, language, scale
    end
    local header = CreateFrame("Button", nil, root)
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    header:SetWidth(WIDTH)
    header:SetHeight(HEADER)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local artwork = Texture(header, "Header", "BACKGROUND")
    artwork:SetAllPoints(header)
    local total = Label(header, 13)
    total:SetPoint("LEFT", header, "LEFT", 14, 1)
    total:SetWidth(WIDTH - 52)
    total:SetHeight(20)
    total:SetTextColor(1, 0.82, 0)
    local function DrawHeader(amount, rate)
        amount = options.total and amount or nil
        rate = options.totalDps and rate or nil
        local language = DFRL.locale.code
        if
            presentation.headerDrawn
            and presentation.headerAmount == amount
            and presentation.headerRate == rate
            and presentation.headerMode == mode
            and presentation.headerLanguage == language
            and presentation.headerRevision == optionsRevision
        then
            return
        end
        T.SetTextIfChanged(total, HeaderText(amount, rate))
        presentation.headerDrawn, presentation.headerAmount, presentation.headerRate = true, amount, rate
        presentation.headerMode, presentation.headerLanguage, presentation.headerRevision =
            mode, language, optionsRevision
    end
    local nextView = Label(header, 14, "RIGHT")
    nextView:SetPoint("RIGHT", header, "RIGHT", -12, 1)
    nextView:SetWidth(20)
    nextView:SetHeight(20)
    nextView:SetText(">")
    nextView:SetTextColor(1, 0.82, 0)

    local status = Label(root, 12, "CENTER")
    status:SetPoint("TOPLEFT", root, "TOPLEFT", 12, -HEADER - 12)
    status:SetWidth(WIDTH - 24)
    status:SetHeight(64)

    local function Row(index)
        if rows[index] then return rows[index] end
        local row = CreateFrame("Frame", nil, root)
        row:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -HEADER - (index - 1) * ROW_HEIGHT)
        row:SetWidth(WIDTH - 16)
        row:SetHeight(ROW_HEIGHT)
        row:EnableMouse(not editing)
        local background = Texture(row, "Background", "BACKGROUND")
        row.background = background
        background:SetPoint("LEFT", row, "LEFT", 32, 0)
        background:SetWidth(WIDTH - 48)
        background:SetHeight(ROW_HEIGHT)
        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetAllPoints(background)
        bar:SetMinMaxValues(0, 1)
        if bar:SetStatusBarTexture(path .. "meter\\Bar.blp") == false then ready = false end
        bar:SetValue(0)
        bar:EnableMouse(false)
        row.bar = bar
        local labels = CreateFrame("Frame", nil, row)
        labels:SetAllPoints(row)
        labels:SetFrameLevel(bar:GetFrameLevel() + 1)
        labels:EnableMouse(false)
        row.name = Label(labels, 11)
        row.name:SetPoint("TOPLEFT", labels, "TOPLEFT", 35, 1)
        row.name:SetWidth(WIDTH - 232)
        row.name:SetHeight(16)
        row.value = Label(labels, 11, "RIGHT")
        row.value:SetPoint("TOPRIGHT", labels, "TOPRIGHT", -2, 1)
        row.value:SetWidth(174)
        row.value:SetHeight(16)
        row.layoutIcons, row.valueColumns = true, 3
        row.iconParts = {}
        row.icon = row:CreateTexture("SurvivorsDragonUiMeterIcon" .. index, "ARTWORK")
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon:SetWidth(ICON_SIZE)
        row.icon:SetHeight(ICON_SIZE)
        row.icon:Hide()
        row.rim = row:CreateTexture(nil, "OVERLAY")
        if row.rim:SetTexture(path .. "jewelry\\Frame.blp") == false then ready = false end
        row.rim:SetTexCoord(576 / 1024, 648 / 1024, 56 / 256, 128 / 256)
        row.rim:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
        row.rim:SetWidth(RIM_SIZE)
        row.rim:SetHeight(RIM_SIZE)
        row.rim:Hide()
        row:SetScript("OnEnter", function() ShowRowTooltip(row) end)
        row:SetScript("OnLeave", HideTooltip)
        row:SetScript("OnHide", HideTooltip)
        row:Hide()
        table.insert(rows, row)
        return row
    end
    -- One row establishes body-font/artwork readiness; further rows are lazy.
    Row(1)
    local function LayoutRow(row)
        local columns = (options.damage and 1 or 0) + (options.dps and 1 or 0) + (options.percentage and 1 or 0)
        if row.layoutIcons == options.icons and row.valueColumns == columns then return end
        local nameLeft = options.icons and 35 or 3
        if row.layoutIcons ~= options.icons then
            row.background:ClearAllPoints()
            row.background:SetPoint("LEFT", row, "LEFT", options.icons and 32 or 0, 0)
            row.background:SetWidth(options.icons and WIDTH - 48 or WIDTH - 16)
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row.name:GetParent(), "TOPLEFT", nameLeft, 1)
        end
        local valueWidth = columns * 58
        local nameWidth = WIDTH - 16 - nameLeft - 2 - (columns > 0 and valueWidth + 5 or 0)
        if not T.NearlyEqual(row.name:GetWidth(), nameWidth) then row.name:SetWidth(nameWidth) end
        if not T.NearlyEqual(row.value:GetWidth(), math.max(1, valueWidth)) then
            row.value:SetWidth(math.max(1, valueWidth))
        end
        if columns > 0 then
            if not row.value:IsShown() then row.value:Show() end
        elseif row.value:IsShown() then
            row.value:Hide()
        end
        row.layoutIcons, row.valueColumns = options.icons, columns
    end
    local function ClearRow(row)
        if not row or not row.active then return end
        ClearIcon(row)
        T.SetTextIfChanged(row.name, "")
        T.SetTextIfChanged(row.value, "")
        if row.fraction and row.fraction ~= 0 then row.bar:SetValue(0) end
        row.fraction = 0
        row.entry, row.displayName, row.drawIndex, row.drawDamage, row.drawRate, row.drawShare =
            nil, nil, nil, nil, nil, nil
        row.drawRevision = nil
        if row:IsShown() then row:Hide() end
        row.active = false
    end
    local function ClearRows()
        if presentation.cleared then return end
        HideTooltip()
        for _, row in ipairs(rows) do
            ClearRow(row)
        end
        snapshot.count, snapshot.total, snapshot.rate, rateSampledAt = 0, nil, nil, nil
        for name in pairs(rateSamples) do
            rateSamples[name] = nil
        end
        for key in pairs(snapshot.rows) do
            snapshot.rows[key] = nil
        end
        table.setn(snapshot.rows, 0)
        presentation.cleared = true
    end
    local function Release()
        dataValid = false
        ClearRows()
        native.Release()
    end
    local function Invalidate()
        HideTooltip()
        Release()
        for index = 1, table.getn(modes) do
            received[index], blocked[index] = nil, true
        end
        T.SetTextIfChanged(total, "")
        T.SetTextIfChanged(status, "")
        if status:IsShown() then status:Hide() end
        presentation.headerDrawn, presentation.headerAmount, presentation.headerRate = false, nil, nil
        offset = 0
        dataDirty = true
        SetShown(false)
    end
    local function Read(paint)
        local selected = modes[mode]
        local getter = _G[selected.getter]
        if type(getter) ~= "function" then return false, "Meter data is unavailable." end
        if blocked[mode] and not received[mode] then return false end
        local ok, source, amount, rate = pcall(getter)
        if not ok or type(source) ~= "table" or not Number(amount) or not Number(rate) then
            return false, "Meter data is unavailable."
        end
        local count = 0
        for _, entry in ipairs(source) do
            if
                type(entry) ~= "table"
                or type(entry.name) ~= "string"
                or entry.name == ""
                or not Number(entry.dmg)
                or not Number(entry.dps)
                or not Number(entry.share)
                or entry.share > 1
            then
                return false, "Meter data is unavailable."
            end
            count = count + 1
        end
        -- Fresh empty getter tables after reload are not received snapshots.
        if count == 0 and not received[mode] then return false end
        received[mode], blocked[mode] = true, nil
        dataValid = true
        if not paint then return true end
        -- UI time limits repaint cadence only; rates still come from the game.
        local now = GetTime()
        if
            not rateSampledAt
            or now < rateSampledAt
            or now - rateSampledAt >= 1
            or (snapshot.total and amount < snapshot.total)
        then
            for name in pairs(rateSamples) do
                rateSamples[name] = nil
            end
            snapshot.rate, rateSampledAt = rate, now
        end
        for index, entry in ipairs(source) do
            local samples = rateSamples[entry.name]
            if not samples then
                samples = {}
                rateSamples[entry.name] = samples
            end
            local proc = entry.proc == 1
            if samples[proc] == nil then samples[proc] = entry.dps end
            local copy = snapshot.rows[index] or {}
            copy.name, copy.dmg, copy.dps, copy.share, copy.proc =
                entry.name, entry.dmg, samples[proc], entry.share, entry.proc
            snapshot.rows[index] = copy
        end
        for index = count + 1, snapshot.count do
            snapshot.rows[index] = nil
        end
        table.setn(snapshot.rows, count)
        snapshot.count, snapshot.total = count, amount
        presentation.cleared = false
        return true
    end
    local function Draw()
        offset = math.max(0, math.min(offset, snapshot.count - visible))
        local maximum = snapshot.rows[1] and snapshot.rows[1].dmg or 0
        local classColor = T.GetPlayerClassColor() or { 0.8, 0.63, 0.28 }
        for index = 1, visible do
            local entry = snapshot.rows[index + offset]
            if entry then
                local row = Row(index)
                if hovered == row and row.displayName ~= entry.name then HideTooltip() end
                row.entry, row.active = entry, true
                LayoutRow(row)
                local rank = options.ranks and index + offset or nil
                if row.displayName ~= entry.name or row.drawIndex ~= rank or row.drawRevision ~= optionsRevision then
                    T.SetTextIfChanged(row.name, rank and (tostring(rank) .. ". " .. entry.name) or entry.name)
                    row.displayName, row.drawIndex = entry.name, rank
                end
                local damage = options.damage and entry.dmg or nil
                local rate = options.dps and entry.dps or nil
                local share = options.percentage and entry.share or nil
                if
                    row.drawDamage ~= damage
                    or row.drawRate ~= rate
                    or row.drawShare ~= share
                    or row.drawRevision ~= optionsRevision
                then
                    local values = damage and Compact(damage) or ""
                    if rate then values = values .. (values ~= "" and "   " or "") .. Compact(rate) end
                    if share then
                        values = values .. (values ~= "" and "   " or "") .. string.format("%.1f%%", share * 100)
                    end
                    T.SetTextIfChanged(row.value, values)
                    row.drawDamage, row.drawRate, row.drawShare = damage, rate, share
                end
                row.drawRevision = optionsRevision
                local fraction = maximum > 0 and math.min(1, entry.dmg / maximum) or 0
                if row.fraction ~= fraction then row.bar:SetValue(fraction) end
                row.fraction = fraction
                local r, g, b = unpack(classColor)
                if entry.proc == 1 then
                    r, g, b = 0.25, 0.58, 1
                end
                if row.red ~= r or row.green ~= g or row.blue ~= b then row.bar:SetStatusBarColor(r, g, b) end
                row.red, row.green, row.blue = r, g, b
                if options.icons then
                    local resolver = DFRL.sct and DFRL.sct.GetSourceIcon
                    local icon = type(resolver) == "function" and resolver(entry.name, modes[mode].healing, entry.proc)
                        or UNKNOWN_ICON
                    if BindIcon(row, icon) then
                        if not row.rim:IsShown() then row.rim:Show() end
                    else
                        if row.rim:IsShown() then row.rim:Hide() end
                    end
                end
                if not row:IsShown() then row:Show() end
                if hovered == row then
                    if GameTooltip and GameTooltip:IsVisible() and GameTooltip:IsOwned(row) then
                        ShowRowTooltip(row)
                    else
                        HideTooltip()
                    end
                end
            else
                ClearRow(rows[index])
            end
        end
        for index = visible + 1, table.getn(rows) do
            ClearRow(rows[index])
        end
        DrawHeader(snapshot.total, snapshot.rate)
        if snapshot.count == 0 then
            T.SetTextIfChanged(status, DFRL.locale.Text("No meter entries yet."))
            if not status:IsShown() then status:Show() end
        else
            if status:IsShown() then status:Hide() end
        end
    end
    local function Refresh()
        if not inWorld or not enabled or not ready or faulted then
            Release()
            SetShown(false)
            UpdateController()
            return
        end
        -- Retained API tables may describe the previous run outside these phases.
        local ok, phase = false, nil
        if type(AZS_GetPhase) == "function" then
            ok, phase = pcall(AZS_GetPhase)
        end
        if not ok or not phases[phase] then
            if phase == "ready" then
                Invalidate()
            else
                Release()
            end
            SetShown(false)
            return
        end
        local paint = not DFRL.layout.IsHidden("damageMeter") and UIParent:IsVisible()
        if not paint and not dataDirty then
            if dataValid then native.Acquire() end
            return
        end
        local valid, message = Read(paint)
        dataDirty = false
        SetShown(true)
        if valid then
            if root:IsVisible() then
                Draw()
            else
                HideTooltip()
            end
            if not ready then
                Release()
                SetShown(false)
                return
            end
            native.Acquire()
        else
            Release()
            if root:IsVisible() then
                DrawHeader()
                T.SetTextIfChanged(status, message and DFRL.locale.Text(message) or "")
                if message then
                    if not status:IsShown() then status:Show() end
                elseif status:IsShown() then
                    status:Hide()
                end
            end
        end
    end
    header:SetScript("OnClick", function()
        if editing then return end
        HideTooltip()
        local direction = arg1 == "RightButton" and -1 or 1
        for step = 1, table.getn(modes) do
            local candidate = math.mod(mode - 1 + direction * step + table.getn(modes), table.getn(modes)) + 1
            if type(_G[modes[candidate].getter]) == "function" then
                mode, offset, age = candidate, 0, 0.2
                dataDirty = true
                Release()
                break
            end
        end
    end)
    header:SetScript("OnEnter", function()
        if editing or not GameTooltip then return end
        HideTooltip()
        hovered = header
        GameTooltip:SetOwner(header, "ANCHOR_NONE")
        GameTooltip:SetText(DFRL.locale.Text(modes[mode].title))
        GameTooltip:AddLine(DFRL.locale.Text("Click to change meter view. Scroll to see more sources."), 1, 1, 1)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", HideTooltip)
    root:SetScript("OnHide", HideTooltip)
    root:SetScript("OnShow", function() age = 0.2 end)
    root:SetScript("OnMouseWheel", function()
        if editing then return end
        HideTooltip()
        offset = math.max(0, math.min(offset - (tonumber(arg1) or 0), snapshot.count - visible))
        age = 0.2
    end)
    DFRL.layout.Register("damageMeter", root, function()
        root:ClearAllPoints()
        root:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    end, {
        labelAbove = true,
        refreshDefault = true,
        onEdit = function(active)
            editing, age = active, 0.2
            HideTooltip()
            header:EnableMouse(not active)
            for _, row in ipairs(rows) do
                row:EnableMouse(not active)
            end
        end,
        onReset = function()
            mode, offset, age, faulted = 1, 0, 0.2, false
            dataDirty = true
            HideTooltip()
            Release()
            UpdateController()
        end,
    })
    DFRL.display.Listen(function()
        local enable = DFRL.display.Get("meterEnabled")
        local enabledChanged = enabled ~= enable
        local count = DFRL.display.Get("meterRows")
        local changed, iconsWereShown = false, options.icons
        for key, setting in pairs(optionKeys) do
            local value = DFRL.display.Get(setting)
            if options[key] ~= value then
                options[key], changed = value, true
            end
        end
        if visible == count and not changed and not enabledChanged then return end
        HideTooltip()
        enabled = enable
        if changed then optionsRevision = optionsRevision + 1 end
        visible, age = count, 0.2
        offset = math.max(0, math.min(offset, snapshot.count - visible))
        for index = visible + 1, table.getn(rows) do
            ClearRow(rows[index])
        end
        if iconsWereShown and not options.icons then
            for _, row in ipairs(rows) do
                ClearIcon(row)
            end
        end
        local height = HEADER + visible * ROW_HEIGHT + FOOTER
        if not T.NearlyEqual(root:GetHeight(), height) then
            root:SetHeight(height)
            DFRL.layout.Place("damageMeter")
        end
        if not enabled or enabledChanged then Invalidate() end
        UpdateController()
    end)
    DFRL.locale.Listen(function()
        HideTooltip()
        dataDirty = true
        age = 0.2
    end)
    Tick = function()
        if not inWorld then return end
        age = age + (tonumber(arg1) or 0)
        if age < 0.2 then return end
        age = 0
        local ok, message = pcall(Refresh)
        if not ok then
            faulted = true
            Release()
            SetShown(false)
            UpdateController()
            geterrorhandler()(message)
        end
    end
    for _, name in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_LOGOUT",
    }) do
        controller:RegisterEvent(name)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld, faulted, age = true, false, 0.2
            UpdateController()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            Invalidate()
            UpdateController()
        elseif event == "CVAR_UPDATE" then
            if native.Observe(arg1) then
                age = 0.2
                UpdateController()
            end
        elseif event == "CHAT_MSG_ADDON" and enabled then
            if arg1 == "AZSZONE" then
                Invalidate()
            else
                for index, entry in ipairs(modes) do
                    if arg1 == entry.prefix then
                        received[index] = true
                        if index == mode then dataDirty = true end
                    end
                end
            end
            -- The five-Hz read coalesces packets and runs after native parsing.
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            Invalidate()
            UpdateController()
            return reloadUI()
        end
    end
    if not enabled then Invalidate() end
    UpdateController()
end)
