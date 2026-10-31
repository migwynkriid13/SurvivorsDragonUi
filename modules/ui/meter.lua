-- The War Within artwork: Karl-HeinzSchneider, MIT; shipped notice in
-- media/tex/meter/LICENSE.txt. Pinned source: third_party/DetailsTWW-ARTWORK.md.
-- The existing gold ring retains third_party/Jewelry-ARTWORK.md's provenance.
DFRL:NewMod("DamageMeter", 7, function()
    local HEADER, ROW_HEIGHT, FOOTER = 32, 32, 32
    local width, fontSize = 240, DFRL.display.Get("meterFontSize")
    local nameFontSize = DFRL.display.Get("meterNameFontSize")
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
    local PARTY_COLOR = { 0.6, 0.6, 0.6 }
    local UNKNOWN_ICON = T.SourceIconFallback
    local path = DFRL:GetInfoOrCons("tex")
    local native = T.NewHudOwner("meter", "hudMeter")
    local api = T.NewNativeMeter()
    local apiIdentity = {}
    local modes = {
        {
            title = "Damage Done",
            rate = "DPS",
            query = { metric = "damage", scope = "self", period = "run", groupBy = "source" },
        },
        {
            title = "Healing Done",
            rate = "HPS",
            query = {
                metric = "healing",
                healingPerspective = "received",
                scope = "self",
                period = "run",
                groupBy = "source",
            },
        },
        {
            title = "Boss Damage",
            rate = "DPS",
            query = { metric = "damage", scope = "self", period = "encounter", groupBy = "source" },
        },
        {
            title = "Party Damage",
            rate = "DPS",
            party = true,
            query = { metric = "damage", scope = "party", period = "run", groupBy = "owner" },
        },
    }
    local phases = { playing = true, choosing = true, paused = true, dead = true, victory = true }
    local mode, offset, age = 1, 0, 0.2
    local inWorld, editing, ready, faulted = true, false, true, false
    local rows = {}
    local viewSelection = { dirty = true, direction = 1, steps = 0, candidates = {}, reads = {} }
    local dataValid = false
    local snapshot = { rows = {}, count = 0 }
    local rateSamples, rateSampledAt = {}, nil
    local rateWindow = DFRL.display.Get("meterDpsWindow")
    local presentation = { shown = false, cleared = true }
    local tooltipState = {}
    local hovered
    local root = CreateFrame("Frame", "DFRL_DamageMeter", UIParent)
    root:SetScale(0.8)
    root:SetWidth(width)
    root:SetHeight(HEADER + visible * ROW_HEIGHT + FOOTER)
    root:SetFrameStrata("MEDIUM")
    root:EnableMouse(true)
    root:EnableMouseWheel(true)
    root:Hide()
    local controller = CreateFrame("Frame")
    local Tick, updating = nil, false
    local function UpdateController()
        local listen = inWorld and enabled and ready and not faulted and true or false
        local active = inWorld and (listen or native.IsCaptured() or api.PendingCleanup()) and true or false
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
    local function ClearSamples()
        rateSampledAt = nil
        for rowId in pairs(rateSamples) do
            rateSamples[rowId] = nil
        end
    end
    local function Compact(value)
        if value >= 1000000000 then return string.format("%.1fB", value / 1000000000) end
        if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
        if value >= 1000 then return string.format("%.1fK", value / 1000) end
        return string.format("%.0f", value)
    end
    local function HeaderText(amount, rate)
        if presentation.waiting then return DFRL.locale.Text(modes[mode].title) end
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
    local function Label(parent, size, justify, flags)
        local label = parent:CreateFontString(nil, "OVERLAY")
        label.meterFontFlags = flags or ""
        T.SetFont(label, size, label.meterFontFlags)
        if not label:GetFont() then ready = false end
        label:SetJustifyH(justify or "LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(1, 1, 1)
        T.SetChatShadow(label)
        return label
    end
    local function SizeLabel(label, size, height)
        local flags = label.meterFontFlags or ""
        T.SetFont(label, size, flags)
        local _, applied, appliedFlags = label:GetFont()
        if not T.NearlyEqual(applied, size) or (appliedFlags or "") ~= T.GetFontFlags(flags) then return false end
        if height and not T.NearlyEqual(label:GetHeight(), height) then label:SetHeight(height) end
        return true
    end
    local function Texture(parent, name, layer)
        local texture = parent:CreateTexture(nil, layer)
        if texture:SetTexture(path .. "meter\\" .. name .. ".blp") == false then ready = false end
        return texture
    end
    local function ClearIcon(row)
        row.circularIcon.Clear()
        if row.rim:IsShown() then row.rim:Hide() end
        row.apiPortraitKey, row.apiPortraitRun = nil, nil
        row.apiPortraitBound, row.apiPortraitRetryAt = nil, nil
    end
    local function BindIcon(row, icon)
        if not icon then
            ClearIcon(row)
            return false
        end
        return row.circularIcon.Bind(icon)
    end
    local function BindNativePortrait(row, entry)
        local key, run = entry.portraitKey, entry.portraitRunId
        if not key or not run or entry.portraitStatus ~= "ready" then
            if row.apiPortraitKey then ClearIcon(row) end
            return BindIcon(row, UNKNOWN_ICON)
        end
        local same = row.apiPortraitKey == key and row.apiPortraitRun == run
        if same and not row.apiPortraitBound then
            if not row.apiPortraitRetryAt or GetTime() < row.apiPortraitRetryAt then
                return BindIcon(row, UNKNOWN_ICON)
            end
        end
        if not same then
            ClearIcon(row)
            row.apiPortraitKey, row.apiPortraitRun = key, run
        end
        local setter = row.circularIcon.BindNative
        local ok, result, failure = false, nil, nil
        if type(setter) == "function" then
            ok, result, failure = pcall(setter, run, key)
        end
        if ok and result == true and failure == nil then
            row.apiPortraitBound, row.apiPortraitRetryAt = true, nil
            return true
        end
        row.apiPortraitBound = false
        row.apiPortraitRetryAt = nil
        if ok and type(failure) == "table" and failure.retryable == true then
            local delay = failure.retryAfterSeconds
            if type(delay) == "number" and delay - delay == 0 and delay > 0 then
                row.apiPortraitRetryAt = GetTime() + delay
            end
        end
        return BindIcon(row, UNKNOWN_ICON)
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
        local rate = entry.dps and string.format("%.1f", entry.dps) or "--"
        local average = entry.averageDps and string.format("%.1f", entry.averageDps) or "--"
        local reset = api.IsReset()
        local share = string.format("%.1f%%", entry.share * 100)
        if
            hovered == row
            and GameTooltip:IsOwned(row)
            and tooltipState.name == entry.name
            and tooltipState.damage == damage
            and tooltipState.rate == rate
            and tooltipState.average == average
            and tooltipState.reset == reset
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
        if mode == 1 then
            GameTooltip:AddDoubleLine(
                DFRL.locale.Text(reset and "Average DPS since Reset" or "Average DPS this run"),
                average
            )
        end
        GameTooltip:AddDoubleLine(DFRL.locale.Text("Share"), share)
        GameTooltip:Show()
        tooltipState.name, tooltipState.damage, tooltipState.rate, tooltipState.share = entry.name, damage, rate, share
        tooltipState.average, tooltipState.reset = average, reset
        tooltipState.mode, tooltipState.language, tooltipState.scale = mode, language, scale
    end
    local header = CreateFrame("Button", nil, root)
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    header:SetWidth(width)
    header:SetHeight(HEADER)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local artwork = Texture(header, "Header", "BACKGROUND")
    artwork:SetAllPoints(header)
    local total = Label(header, fontSize + 2)
    total:SetPoint("LEFT", header, "LEFT", 14, 1)
    total:SetWidth(width - 52)
    total:SetHeight(fontSize + 9)
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
            and presentation.headerWaiting == presentation.waiting
        then
            return
        end
        T.SetTextIfChanged(total, HeaderText(amount, rate))
        presentation.headerDrawn, presentation.headerAmount, presentation.headerRate = true, amount, rate
        presentation.headerMode, presentation.headerLanguage, presentation.headerRevision =
            mode, language, optionsRevision
        presentation.headerWaiting = presentation.waiting
    end
    -- Blizzard's existing gold X and native button states; see Character-ARTWORK.md.
    local resetButton = CreateFrame("Button", nil, header)
    resetButton:SetPoint("RIGHT", header, "RIGHT", -12, 1)
    resetButton:SetWidth(16)
    resetButton:SetHeight(16 * 38 / 36)
    resetButton:RegisterForClicks("LeftButtonUp")
    for _, entry in ipairs({ { "Normal", 0, 0 }, { "Pushed", 64, 0 }, { "Highlight", 64, 64 } }) do
        resetButton["Set" .. entry[1] .. "Texture"](resetButton, path .. "character\\Close.blp")
        local texture = resetButton["Get" .. entry[1] .. "Texture"](resetButton)
        if texture then
            texture:SetTexCoord(entry[2] / 128, (entry[2] + 36) / 128, entry[3] / 128, (entry[3] + 38) / 128)
            texture:ClearAllPoints()
            texture:SetAllPoints(resetButton)
            if entry[1] == "Highlight" then texture:SetBlendMode("ADD") end
        end
    end

    local function ShowHeaderTooltip()
        if editing or not GameTooltip then return end
        local average = snapshot.averageRate and string.format("%.1f", snapshot.averageRate) or "--"
        local reset = api.IsReset()
        local scale = GameTooltip:GetEffectiveScale()
        if
            hovered == header
            and GameTooltip:IsOwned(header)
            and tooltipState.mode == mode
            and tooltipState.average == average
            and tooltipState.reset == reset
            and tooltipState.window == rateWindow
            and tooltipState.language == DFRL.locale.code
            and tooltipState.scale == scale
        then
            return
        end
        HideTooltip()
        hovered = header
        GameTooltip:SetOwner(header, "ANCHOR_NONE")
        GameTooltip:SetText(DFRL.locale.Text(modes[mode].title))
        if mode == 1 then
            GameTooltip:AddDoubleLine(
                DFRL.locale.Text("DPS window"),
                rateWindow == 0 and DFRL.locale.Text("All") or tostring(rateWindow)
            )
            GameTooltip:AddDoubleLine(
                DFRL.locale.Text(reset and "Average DPS since Reset" or "Average DPS this run"),
                average
            )
        end
        GameTooltip:AddLine(DFRL.locale.Text("Click to change meter view. Scroll to see more sources."), 1, 1, 1)
        GameTooltip:Show()
        tooltipState.mode, tooltipState.average, tooltipState.reset = mode, average, reset
        tooltipState.window, tooltipState.language = rateWindow, DFRL.locale.code
        tooltipState.scale = scale
    end

    local status = Label(root, fontSize + 1, "CENTER")
    status:SetPoint("TOPLEFT", root, "TOPLEFT", 12, -HEADER - 12)
    status:SetWidth(width - 24)
    status:SetHeight(64)

    local presentationWidth, presentationFontSize = width, fontSize
    local function PreparePresentation()
        if presentationWidth ~= width then
            header:SetWidth(width)
            total:SetWidth(width - 52)
            status:SetWidth(width - 24)
            presentationWidth = width
        end
        if presentationFontSize ~= fontSize then
            local totalSized = SizeLabel(total, fontSize + 2, fontSize + 9)
            local statusSized = SizeLabel(status, fontSize + 1)
            if totalSized and statusSized then presentationFontSize = fontSize end
        end
    end

    local function Row(index)
        if rows[index] then return rows[index] end
        local row = CreateFrame("Frame", nil, root)
        row:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -HEADER - (index - 1) * ROW_HEIGHT)
        row:SetWidth(width - 16)
        row:SetHeight(ROW_HEIGHT)
        row:EnableMouse(not editing)
        local outline = Texture(row, "Background", "BACKGROUND")
        -- Reuse the rounded rail silhouette; its first fourteen source rows are empty.
        -- Keep this below BORDER so native equal-texture sorting cannot cover the artwork.
        outline:SetTexCoord(0, 1, 14 / 32, 1)
        outline:SetVertexColor(0, 0, 0, 1)
        local background = Texture(row, "Background", "BORDER")
        row.background = background
        background:SetPoint("LEFT", row, "LEFT", 32, 0)
        background:SetWidth(width - 48)
        background:SetHeight(ROW_HEIGHT)
        outline:SetPoint("TOPLEFT", background, "LEFT", -2, 4)
        outline:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 2, -2)
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
        row.name = Label(labels, nameFontSize, "LEFT", "OUTLINE")
        row.name:SetPoint("TOPLEFT", labels, "TOPLEFT", 35, 1)
        row.name:SetWidth(math.max(1, width - 232))
        row.name:SetHeight(nameFontSize + 5)
        row.value = Label(labels, fontSize, "RIGHT", "OUTLINE")
        row.value:SetPoint("TOPRIGHT", labels, "TOPRIGHT", -2, 1)
        row.value:SetWidth(174)
        row.value:SetHeight(fontSize + 5)
        row.layoutIcons, row.valueColumns = true, 3
        local _, appliedNameSize, appliedNameFlags = row.name:GetFont()
        if T.NearlyEqual(appliedNameSize, nameFontSize) and (appliedNameFlags or "") == T.GetFontFlags("OUTLINE") then
            row.layoutNameFontSize = nameFontSize
        end
        local _, appliedValueSize, appliedValueFlags = row.value:GetFont()
        if T.NearlyEqual(appliedValueSize, fontSize) and (appliedValueFlags or "") == T.GetFontFlags("OUTLINE") then
            row.layoutFontSize = fontSize
        end
        row.icon = row:CreateTexture("SurvivorsDragonUiMeterIcon" .. index, "ARTWORK")
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon:SetWidth(ICON_SIZE)
        row.icon:SetHeight(ICON_SIZE)
        row.icon:Hide()
        row.circularIcon = T.NewCircularIcon(row.icon, ICON_SIZE, 4)
        row.rim = row:CreateTexture(nil, "OVERLAY")
        if row.rim:SetTexture(path .. "jewelry\\Frame.blp") == false then ready = false end
        row.rim:SetTexCoord(576 / 1024, 648 / 1024, 56 / 256, 128 / 256)
        row.rim:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
        row.rim:SetWidth(RIM_SIZE)
        row.rim:SetHeight(RIM_SIZE)
        row.rim:Hide()
        row:SetScript("OnEnter", function() ShowRowTooltip(row) end)
        row:SetScript("OnLeave", HideTooltip)
        row:SetScript("OnHide", function()
            row.valueMetric = nil
            HideTooltip()
        end)
        row:Hide()
        table.insert(rows, row)
        return row
    end
    -- One row establishes body-font/artwork readiness; further rows are lazy.
    Row(1)
    local function LayoutRow(row)
        local columns = (options.damage and 1 or 0) + (options.dps and 1 or 0) + (options.percentage and 1 or 0)
        local nameLeft = options.icons and 35 or 3
        if row.layoutWidth ~= width then row:SetWidth(width - 16) end
        if row.layoutIcons ~= options.icons or row.layoutWidth ~= width then
            row.background:SetWidth(options.icons and width - 48 or width - 16)
        end
        if row.layoutIcons ~= options.icons then
            row.background:ClearAllPoints()
            row.background:SetPoint("LEFT", row, "LEFT", options.icons and 32 or 0, 0)
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row.name:GetParent(), "TOPLEFT", nameLeft, 1)
        end
        if row.layoutNameFontSize ~= nameFontSize and SizeLabel(row.name, nameFontSize, nameFontSize + 5) then
            row.layoutNameFontSize = nameFontSize
        end
        if columns > 0 and row.layoutFontSize ~= fontSize and SizeLabel(row.value, fontSize, fontSize + 5) then
            row.layoutFontSize = fontSize
        end
        local available = width - 16 - nameLeft - 2
        local valueWidth = 0
        if columns > 0 then
            -- Reserve only the current numeric caption's natural width. Keep
            -- the old conservative reservation until native metrics are ready.
            valueWidth = columns * math.ceil(58 * fontSize / 11)
            local text = row.value:GetText()
            local face, size, flags = row.value:GetFont()
            local scale = row:GetEffectiveScale()
            local metric = row.valueMetric
            if
                metric
                and metric.text == text
                and metric.face == face
                and metric.size == size
                and metric.flags == flags
                and metric.scale == scale
                and metric.available == available
            then
                valueWidth = metric.width
            elseif face and Number(size) and size > 0 and Number(scale) and scale > 0 and text and text ~= "" then
                local measured = row.value:GetStringWidth()
                if Number(measured) and measured > 0 then
                    metric = metric or {}
                    metric.text, metric.face, metric.size, metric.flags = text, face, size, flags
                    metric.scale, metric.available, metric.width = scale, available, math.ceil(measured) + 1
                    row.valueMetric = metric
                    valueWidth = metric.width
                end
            end
            valueWidth = math.min(valueWidth, math.max(1, available - 5 - 48))
        end
        local nameWidth = available - (columns > 0 and valueWidth + 5 or 0)
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
        row.layoutWidth = width
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
        row.valueMetric = nil
        if row:IsShown() then row:Hide() end
        row.active = false
    end
    local function ClearRows()
        if presentation.cleared then return end
        HideTooltip()
        for _, row in ipairs(rows) do
            ClearRow(row)
        end
        snapshot.count, snapshot.total, snapshot.rate, snapshot.averageRate = 0, nil, nil, nil
        snapshot.source, snapshot.publication = nil, nil
        snapshot.nativeRunId, snapshot.nativeEpoch, snapshot.nativeAuthority = nil, nil, nil
        snapshot.nativeEncounter = nil
        ClearSamples()
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
    local function ClearReadPass()
        if not viewSelection.read then return end
        for index = 1, table.getn(modes) do
            local entry = viewSelection.reads[index]
            if entry and entry.read then
                entry.read, entry.source, entry.amount, entry.rate, entry.message, entry.publication =
                    nil, nil, nil, nil, nil, nil
                entry.meta = nil
            end
        end
        viewSelection.read = nil
    end
    local function Invalidate()
        HideTooltip()
        api.Clear()
        apiIdentity = {}
        ClearReadPass()
        viewSelection.first, viewSelection.steps, viewSelection.dirty, viewSelection.paint = nil, 0, true, false
        Release()
        T.SetTextIfChanged(total, "")
        T.SetTextIfChanged(status, "")
        if status:IsShown() then status:Hide() end
        presentation.headerDrawn, presentation.headerAmount, presentation.headerRate = false, nil, nil
        offset = 0
        SetShown(false)
    end
    local function ReadOnce(index)
        local entry = viewSelection.reads[index]
        if not entry then
            entry = {}
            viewSelection.reads[index] = entry
        end
        if not entry.read then
            entry.source, entry.amount, entry.rate, entry.message, entry.publication, entry.meta =
                api.Read(modes[index].query, index == 1 and rateWindow or 0)
            entry.read, viewSelection.read = true, true
        end
        return entry.source, entry.amount, entry.rate, entry.message, entry.publication, entry.meta
    end
    local function ResolveView(source, amount, rate, message, publication, meta)
        if not viewSelection.first then
            if source or message then
                viewSelection.dirty = false
                return source, amount, rate, message, publication, meta
            end
            if not viewSelection.dirty then return source, amount, rate, message, publication, meta end
        end
        -- Probe other views only for navigation or readiness recovery. Native
        -- empty snapshots and explicit errors remain selectable; waiting views
        -- have no source or message and stay outside the available ring.
        local count, current = 0, false
        for step = 0, table.getn(modes) - 1 do
            local index = math.mod(mode - 1 + step, table.getn(modes)) + 1
            local candidateSource, candidateMessage
            local _
            candidateSource, _, _, candidateMessage = ReadOnce(index)
            if candidateSource or candidateMessage then
                count = count + 1
                viewSelection.candidates[count] = index
                if step == 0 then current = true end
            end
        end
        if count > 0 then
            local slot
            if viewSelection.first then
                -- The first click enters the available ring even if the old
                -- view was waiting; later clicks advance within that ring.
                slot = current and 1 + viewSelection.first or (viewSelection.first > 0 and 1 or count)
                slot = slot + viewSelection.steps
            else
                slot = viewSelection.direction > 0 and 1 or count
            end
            slot = math.mod(math.mod(slot - 1, count) + count, count) + 1
            local selected = viewSelection.candidates[slot]
            if mode ~= selected then
                HideTooltip()
                Release()
                mode, offset = selected, 0
            end
            source, amount, rate, message, publication, meta = ReadOnce(selected)
        end
        viewSelection.first, viewSelection.steps, viewSelection.dirty = nil, 0, false
        return source, amount, rate, message, publication, meta
    end
    local function Read(source, amount, rate, message, publication, meta)
        if not source then return false, message end
        dataValid = true
        if
            snapshot.nativeRunId ~= meta.runId
            or snapshot.nativeEpoch ~= meta.counterEpoch
            or snapshot.nativeAuthority ~= meta.authorityId
            or snapshot.nativeEncounter ~= meta.encounterId
        then
            ClearSamples()
        end
        snapshot.nativeRunId, snapshot.nativeEpoch, snapshot.nativeAuthority =
            meta.runId, meta.counterEpoch, meta.authorityId
        snapshot.nativeEncounter = meta.encounterId
        if type(DFRL.locale.Select) == "function" then DFRL.locale.Select(meta.languageCode) end
        local count = table.getn(source)
        -- Native snapshots supply every rate. UI time only limits repaint.
        local now = GetTime()
        local sampleRates = not rateSampledAt
            or now < rateSampledAt
            or now - rateSampledAt >= 1
            or (snapshot.total and amount < snapshot.total)
        if sampleRates then
            snapshot.rate, snapshot.averageRate = rate, meta.averageRate
            rateSampledAt = now
        end
        local countersChanged = snapshot.publication ~= publication or snapshot.source ~= source
        if not countersChanged and not sampleRates then return true end
        for index, entry in ipairs(source) do
            local copy = snapshot.rows[index] or {}
            if countersChanged then
                copy.name, copy.dmg, copy.share, copy.proc = entry.name, entry.dmg, entry.share, entry.proc
                copy.class = modes[mode].party and entry.class or nil
                copy.rowId, copy.icon = entry.rowId, entry.icon
                copy.portraitKey, copy.portraitRunId = entry.portraitKey, entry.portraitRunId
                copy.portraitStatus = entry.portraitStatus
            end
            local sample = rateSamples[copy.rowId]
            if not sample then
                sample = {}
                rateSamples[copy.rowId] = sample
            end
            if sample.epoch ~= rateSampledAt then
                sample.rate, sample.average = entry.dps, entry.averageDps
                sample.epoch = rateSampledAt
            end
            sample.publication = publication
            copy.dps, copy.averageDps = sample.rate, sample.average
            snapshot.rows[index] = copy
        end
        if countersChanged then
            for key, sample in pairs(rateSamples) do
                if sample.publication ~= publication then rateSamples[key] = nil end
            end
            for index = count + 1, snapshot.count do
                snapshot.rows[index] = nil
            end
            table.setn(snapshot.rows, count)
            snapshot.count, snapshot.total = count, amount
            snapshot.source, snapshot.publication = source, publication
        end
        presentation.cleared = false
        return true
    end
    local function Draw()
        offset = math.max(0, math.min(offset, snapshot.count - visible))
        local maximum = snapshot.rows[1] and snapshot.rows[1].dmg or 0
        local party = modes[mode].party
        local classColor = party and PARTY_COLOR or T.GetPlayerClassColor() or { 0.8, 0.63, 0.28 }
        for index = 1, visible do
            local entry = snapshot.rows[index + offset]
            if entry then
                local row = Row(index)
                if hovered == row and row.displayName ~= entry.name then HideTooltip() end
                row.entry, row.active = entry, true
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
                    if options.dps then
                        values = values .. (values ~= "" and "   " or "") .. (rate and Compact(rate) or "--")
                    end
                    if share then
                        values = values .. (values ~= "" and "   " or "") .. string.format("%.1f%%", share * 100)
                    end
                    T.SetTextIfChanged(row.value, values)
                    row.drawDamage, row.drawRate, row.drawShare = damage, rate, share
                end
                row.drawRevision = optionsRevision
                LayoutRow(row)
                local fraction = maximum > 0 and math.min(1, entry.dmg / maximum) or 0
                if row.fraction ~= fraction then row.bar:SetValue(fraction) end
                row.fraction = fraction
                local r, g, b = unpack(classColor)
                if party then
                    local color = T.GetClassColor(entry.class)
                    if color then
                        r, g, b = unpack(color)
                    else
                        r, g, b = 0.6, 0.6, 0.6
                    end
                elseif entry.proc == 1 then
                    r, g, b = 0.25, 0.58, 1
                end
                if row.red ~= r or row.green ~= g or row.blue ~= b then row.bar:SetStatusBarColor(r, g, b) end
                row.red, row.green, row.blue = r, g, b
                if options.icons then
                    local bound
                    if party then
                        bound = BindNativePortrait(row, entry)
                    else
                        bound = BindIcon(row, entry.icon or UNKNOWN_ICON)
                    end
                    if bound then
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
        if hovered == header and GameTooltip and GameTooltip:IsVisible() and GameTooltip:IsOwned(header) then
            ShowHeaderTooltip()
        end
        if snapshot.count == 0 then
            T.SetTextIfChanged(status, DFRL.locale.Text("No meter entries yet."))
            if not status:IsShown() then status:Show() end
        else
            if status:IsShown() then status:Hide() end
        end
    end
    local function ReadPhase()
        if api.PendingCleanup() then api.RetryCleanup() end
        local context = api.Context()
        if not context then return end
        if apiIdentity.runId and apiIdentity.runId ~= context.runId then
            api.Clear()
            Release()
            ClearSamples()
            ClearReadPass()
            viewSelection.dirty = true
        elseif
            apiIdentity.epoch ~= context.counterEpoch
            or apiIdentity.authority ~= context.authorityId
            or apiIdentity.encounter ~= (context.encounter and context.encounter.encounterId)
        then
            ClearSamples()
        end
        apiIdentity.runId, apiIdentity.epoch, apiIdentity.authority =
            context.runId, context.counterEpoch, context.authorityId
        apiIdentity.encounter = context.encounter and context.encounter.encounterId
        return context.phase
    end
    local function Refresh()
        if not inWorld or not enabled or not ready or faulted then
            if api.PendingCleanup() then api.RetryCleanup() end
            Release()
            SetShown(false)
            UpdateController()
            return
        end
        local phase = ReadPhase()
        if not phases[phase] then
            if phase == "ready" then
                Invalidate()
            else
                Release()
            end
            SetShown(false)
            return
        end
        local paint = not DFRL.layout.IsHidden("damageMeter") and UIParent:IsVisible()
        if paint and not viewSelection.paint then viewSelection.dirty = true end
        viewSelection.paint = paint
        if not paint then
            if dataValid then native.Acquire() end
            return
        end
        local source, amount, rate, message, publication, meta = ReadOnce(mode)
        if not source then viewSelection.dirty = true end
        source, amount, rate, message, publication, meta = ResolveView(source, amount, rate, message, publication, meta)
        local valid
        valid, message = Read(source, amount, rate, message, publication, meta)
        presentation.waiting = not valid and message == nil
        SetShown(true)
        if root:IsVisible() then PreparePresentation() end
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
        if editing or not enabled or not inWorld then return end
        HideTooltip()
        local direction = arg1 == "RightButton" and -1 or 1
        if viewSelection.first then
            viewSelection.steps = viewSelection.steps + direction
        else
            viewSelection.first, viewSelection.steps = direction, 0
        end
        viewSelection.direction, age = direction, 0.2
    end)
    header:SetScript("OnEnter", ShowHeaderTooltip)
    header:SetScript("OnLeave", HideTooltip)
    resetButton:SetScript("OnClick", function()
        if not editing then DFRL.ResetMeterStats() end
    end)
    resetButton:SetScript("OnEnter", function()
        if editing or not GameTooltip then return end
        HideTooltip()
        hovered = resetButton
        GameTooltip:SetOwner(resetButton, "ANCHOR_NONE")
        GameTooltip:SetText(DFRL.locale.Text("Reset statistics"))
        GameTooltip:AddLine(DFRL.locale.Text("Clear damage and healing. Start again from zero."), 1, 1, 1)
        GameTooltip:Show()
    end)
    resetButton:SetScript("OnLeave", HideTooltip)
    root:SetScript("OnHide", function()
        viewSelection.paint = false
        HideTooltip()
        ClearSamples()
        for _, row in ipairs(rows) do
            row.valueMetric = nil
        end
    end)
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
        edgeWidth = true,
        minWidth = 120,
        maxWidth = 960,
        onHeightDrag = function(height)
            DFRL.display.Set("meterRows", math.floor((height - HEADER - FOOTER) / ROW_HEIGHT + 0.5))
        end,
        onResize = function(frame)
            width, age = frame:GetWidth(), 0.2
        end,
        onEdit = function(active)
            editing, age = active, 0.2
            HideTooltip()
            header:EnableMouse(not active)
            resetButton:EnableMouse(not active)
            for _, row in ipairs(rows) do
                row:EnableMouse(not active)
            end
        end,
        onReset = function()
            mode, offset, age, faulted = 1, 0, 0.2, false
            viewSelection.first, viewSelection.steps, viewSelection.dirty = nil, 0, true
            HideTooltip()
            api.Clear()
            Release()
            UpdateController()
        end,
    })
    DFRL.display.Listen(function()
        local enable = DFRL.display.Get("meterEnabled")
        local enabledChanged = enabled ~= enable
        local count = DFRL.display.Get("meterRows")
        local selectedFontSize = DFRL.display.Get("meterFontSize")
        local selectedNameFontSize = DFRL.display.Get("meterNameFontSize")
        local fontChanged = fontSize ~= selectedFontSize or nameFontSize ~= selectedNameFontSize
        local window = DFRL.display.Get("meterDpsWindow")
        local windowChanged = rateWindow ~= window
        local changed, iconsWereShown = false, options.icons
        for key, setting in pairs(optionKeys) do
            local value = DFRL.display.Get(setting)
            if options[key] ~= value then
                options[key], changed = value, true
            end
        end
        if visible == count and not changed and not enabledChanged and not fontChanged and not windowChanged then
            return
        end
        HideTooltip()
        enabled = enable
        fontSize = selectedFontSize
        nameFontSize = selectedNameFontSize
        if windowChanged then
            rateWindow = window
            ClearSamples()
        end
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
        ClearSamples()
        age = 0.2
    end)
    function DFRL.ResetMeterStats()
        if not enabled or not inWorld or not ready or faulted then return end
        if not api.Reset() then return end
        ClearRows()
        ClearSamples()
        ClearReadPass()
        offset = 0
        if root:IsVisible() then
            DrawHeader(0)
            T.SetTextIfChanged(status, "")
            if status:IsShown() then status:Hide() end
        end
        age = 0.2
    end
    Tick = function()
        if not inWorld then return end
        age = age + (tonumber(arg1) or 0)
        if age < 0.2 then return end
        age = 0
        local ok, message = pcall(Refresh)
        ClearReadPass()
        if not ok then
            faulted = true
            api.Clear()
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
