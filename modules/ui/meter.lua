-- The War Within artwork: Karl-HeinzSchneider, MIT; shipped notice in
-- media/tex/meter/LICENSE.txt. Pinned source: third_party/DetailsTWW-ARTWORK.md.
-- The existing gold ring retains third_party/Jewelry-ARTWORK.md's provenance.
DFRL:NewMod("DamageMeter", 7, function()
    local HEADER, ROW_HEIGHT, FOOTER = 32, 32, 32
    local width, fontSize = 240, DFRL.display.Get("meterFontSize")
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
    local modes = {
        {
            getter = "AZS_GetMeter",
            stamp = "AZS_METER_UPDATED",
            prefix = "AZSMETER",
            title = "Damage Done",
            rate = "DPS",
        },
        {
            getter = "AZS_GetHealing",
            stamp = "AZS_HEALING_UPDATED",
            prefix = "AZSHEAL",
            title = "Healing Done",
            rate = "HPS",
            healing = true,
        },
        {
            getter = "AZS_GetBossMeter",
            stamp = "AZS_BOSSMETER_UPDATED",
            prefix = "AZSBOSSDMG",
            title = "Boss Damage",
            rate = "DPS",
        },
        {
            getter = "AZS_GetPartyMeter",
            stamp = "AZS_PARTY_UPDATED",
            prefix = "AZSPARTY",
            title = "Party Damage",
            rate = "DPS",
            party = true,
        },
    }
    local phases = { playing = true, choosing = true, paused = true, dead = true, victory = true }
    local mode, offset, age = 1, 0, 0.2
    local inWorld, editing, ready, faulted = true, false, true, false
    local rows, received, blocked = {}, {}, {}
    local receipts, publications, publicationSequence = {}, {}, 0
    local partyUnits = {
        { unit = "player" },
        { unit = "party1", portrait = "PartyMemberFrame1Portrait" },
        { unit = "party2", portrait = "PartyMemberFrame2Portrait" },
        { unit = "party3", portrait = "PartyMemberFrame3Portrait" },
        { unit = "party4", portrait = "PartyMemberFrame4Portrait" },
    }
    local dataDirty, dataValid = true, false
    local snapshot = { rows = {}, count = 0 }
    local rateSamples, rateSampledAt = {}, nil
    local dps = T.NewMeterDps(DFRL.display.Get("meterDpsWindow"))
    local session, resetPending = T.NewMeterSession(), false
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
    local function ClearSamples()
        rateSampledAt = nil
        for name in pairs(rateSamples) do
            rateSamples[name] = nil
        end
    end
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
        if not T.NearlyEqual(applied, size) or (appliedFlags or "") ~= flags then return false end
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
        row.partyUnit, row.partyName, row.partySource, row.partyTexture = nil, nil, nil, nil
    end
    local function BindIcon(row, icon)
        if not icon then
            ClearIcon(row)
            return false
        end
        return row.circularIcon.Bind(icon)
    end
    local function ClearPartyUnits()
        for _, candidate in ipairs(partyUnits) do
            candidate.name, candidate.class, candidate.texture = nil, nil, nil
        end
    end
    local function ReadPartyUnits()
        ClearPartyUnits()
        if type(UnitExists) ~= "function" or type(UnitName) ~= "function" then return end
        for _, candidate in ipairs(partyUnits) do
            local exists = UnitExists(candidate.unit)
            if exists == true or exists == 1 then
                candidate.name = UnitName(candidate.unit)
                if type(UnitClass) == "function" then
                    local _, class = UnitClass(candidate.unit)
                    candidate.class = type(class) == "string" and string.lower(class) or nil
                end
                local portrait
                if candidate.unit == "player" then
                    portrait = PlayerFrame and PlayerFrame.portrait
                else
                    portrait = _G[candidate.portrait]
                end
                if portrait and type(portrait.GetTexture) == "function" then
                    candidate.texture = portrait:GetTexture()
                end
            end
        end
    end
    local function BindPartyIcon(row, entry)
        local match
        for _, candidate in ipairs(partyUnits) do
            if candidate.name == entry.name then
                -- Names are only a bridge to a unique, currently published unit.
                if match then
                    match = nil
                    break
                end
                match = candidate
            end
        end
        if match and entry.class and match.class and string.lower(entry.class) ~= match.class then match = nil end
        if not match then
            if row.partyName then ClearIcon(row) end
            return BindIcon(row, UNKNOWN_ICON)
        end
        if
            row.partyUnit ~= match.unit
            or row.partyName ~= match.name
            or row.partySource ~= match.texture
            or (row.partyTexture and row.icon:GetTexture() ~= row.partyTexture)
        then
            ClearIcon(row)
            row.partyUnit, row.partyName, row.partySource = match.unit, match.name, match.texture
            if type(_G.SetPortraitTexture) == "function" then
                local ok, result = pcall(_G.SetPortraitTexture, row.icon:GetName(), match.unit)
                local texture = row.icon:GetTexture()
                if ok and result ~= false and texture then
                    row.partyTexture = texture
                    if not row.icon:IsShown() then row.icon:Show() end
                    return true
                end
                if texture then row.icon:SetTexture(nil) end
            end
        end
        if row.partyTexture then return true end
        -- Failed native bindings stay memoized until identity/artwork changes.
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
        local reset = session.IsReset()
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
        then
            return
        end
        T.SetTextIfChanged(total, HeaderText(amount, rate))
        presentation.headerDrawn, presentation.headerAmount, presentation.headerRate = true, amount, rate
        presentation.headerMode, presentation.headerLanguage, presentation.headerRevision =
            mode, language, optionsRevision
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
        local reset = session.IsReset()
        local scale = GameTooltip:GetEffectiveScale()
        if
            hovered == header
            and GameTooltip:IsOwned(header)
            and tooltipState.mode == mode
            and tooltipState.average == average
            and tooltipState.reset == reset
            and tooltipState.window == dps.window
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
                dps.window == 0 and DFRL.locale.Text("All") or tostring(dps.window)
            )
            GameTooltip:AddDoubleLine(
                DFRL.locale.Text(reset and "Average DPS since Reset" or "Average DPS this run"),
                average
            )
        end
        GameTooltip:AddLine(DFRL.locale.Text("Click to change meter view. Scroll to see more sources."), 1, 1, 1)
        GameTooltip:Show()
        tooltipState.mode, tooltipState.average, tooltipState.reset = mode, average, reset
        tooltipState.window, tooltipState.language = dps.window, DFRL.locale.code
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
        row.name = Label(labels, fontSize, "LEFT", "OUTLINE")
        row.name:SetPoint("TOPLEFT", labels, "TOPLEFT", 35, 1)
        row.name:SetWidth(math.max(1, width - 232))
        row.name:SetHeight(fontSize + 5)
        row.value = Label(labels, fontSize, "RIGHT", "OUTLINE")
        row.value:SetPoint("TOPRIGHT", labels, "TOPRIGHT", -2, 1)
        row.value:SetWidth(174)
        row.value:SetHeight(fontSize + 5)
        row.layoutIcons, row.valueColumns = true, 3
        row.layoutFontSize = fontSize
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
        row:SetScript("OnHide", HideTooltip)
        row:Hide()
        table.insert(rows, row)
        return row
    end
    -- One row establishes body-font/artwork readiness; further rows are lazy.
    Row(1)
    local function LayoutRow(row)
        local columns = (options.damage and 1 or 0) + (options.dps and 1 or 0) + (options.percentage and 1 or 0)
        if
            row.layoutIcons == options.icons
            and row.valueColumns == columns
            and row.layoutWidth == width
            and row.layoutFontSize == fontSize
        then
            return
        end
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
        if row.layoutFontSize ~= fontSize then
            local nameSized = SizeLabel(row.name, fontSize, fontSize + 5)
            local valueSized = SizeLabel(row.value, fontSize, fontSize + 5)
            if nameSized and valueSized then row.layoutFontSize = fontSize end
        end
        -- Retain the original 58-unit columns at size 11, reserving name room
        -- when large text and all numeric columns meet a narrow viewport.
        local available = width - 16 - nameLeft - 2
        local valueWidth = math.min(columns * math.ceil(58 * fontSize / 11), available - 5 - 48)
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
        if row:IsShown() then row:Hide() end
        row.active = false
    end
    local function ClearRows()
        if presentation.cleared then return end
        HideTooltip()
        ClearPartyUnits()
        for _, row in ipairs(rows) do
            ClearRow(row)
        end
        snapshot.count, snapshot.total, snapshot.rate, snapshot.averageRate = 0, nil, nil, nil
        snapshot.source, snapshot.publication = nil, nil
        ClearSamples()
        for key in pairs(snapshot.rows) do
            snapshot.rows[key] = nil
        end
        table.setn(snapshot.rows, 0)
        presentation.cleared = true
    end
    local function Release(preserveDps)
        dataValid = false
        ClearRows()
        if not preserveDps then dps.Suspend() end
        native.Release()
    end
    local function Invalidate()
        HideTooltip()
        dps.Clear()
        session.Clear()
        resetPending = false
        Release()
        for index = 1, table.getn(modes) do
            received[index], blocked[index] = nil, true
            publications[index] = nil
        end
        T.SetTextIfChanged(total, "")
        T.SetTextIfChanged(status, "")
        if status:IsShown() then status:Hide() end
        presentation.headerDrawn, presentation.headerAmount, presentation.headerRate = false, nil, nil
        offset = 0
        dataDirty = true
        SetShown(false)
    end
    local function RunSeconds()
        if Number(AZS_RUN_UPDATED) and type(AZS_RUN) == "table" and Number(AZS_RUN.t) then return AZS_RUN.t end
    end
    local function ReadNative(index)
        local selected = modes[index]
        local getter = _G[selected.getter]
        if type(getter) ~= "function" then
            publications[index] = nil
            return nil, nil, nil, "Meter data is unavailable."
        end
        if blocked[index] and not received[index] then return end
        local ok, source, amount, rate = pcall(getter)
        if not ok or type(source) ~= "table" or not Number(amount) or not Number(rate) then
            publications[index] = nil
            return nil, nil, nil, "Meter data is unavailable."
        end
        local publication = publications[index]
        local stamp, receipt = _G[selected.stamp], receipts[index] or 0
        -- The native parser replaces these lists on publication. Receipts also
        -- invalidate in-place/same-timestamp deliveries; getters still run so
        -- native rates and the run clock remain live between publications.
        if
            publication
            and publication.getter == getter
            and publication.source == source
            and publication.stamp == stamp
            and publication.receipt == receipt
            and publication.amount == amount
        then
            return source, amount, rate, nil, publication.revision
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
                publications[index] = nil
                return nil, nil, nil, "Meter data is unavailable."
            end
            count = count + 1
        end
        -- Fresh empty getter tables after reload are not received snapshots.
        if count == 0 and not received[index] then return end
        received[index], blocked[index] = true, nil
        publicationSequence = publicationSequence + 1
        publication = publication or {}
        publication.getter, publication.source, publication.stamp = getter, source, stamp
        publication.receipt, publication.amount, publication.revision = receipt, amount, publicationSequence
        publications[index] = publication
        return source, amount, rate, nil, publication.revision
    end
    local function ObserveDamage(source, amount, rate, publication)
        if not source then
            local _
            source, amount, rate, _, publication = ReadNative(1)
            if not source then
                dps.Suspend()
                return
            end
            source, amount, rate = session.Apply(1, source, amount, rate, RunSeconds(), publication)
        end
        if not dps.Observe(RunSeconds(), source, amount, rate, publication) then dps.Suspend() end
    end
    local function Read(paint)
        local source, amount, rate, message, publication = ReadNative(mode)
        if not source then return false, message end
        dataValid = true
        if not paint then
            dps.Suspend()
            return true
        end
        local nativeSource = source
        source, amount, rate = session.Apply(mode, source, amount, rate, RunSeconds(), publication)
        local count = table.getn(source)
        local revision = dps.revision
        if mode == 1 then ObserveDamage(source, amount, rate, publication) end
        if revision ~= dps.revision then ClearSamples() end
        -- Native run seconds own the rate window; UI time only limits repaint.
        local now = GetTime()
        local sampleRates = not rateSampledAt
            or now < rateSampledAt
            or now - rateSampledAt >= 1
            or (snapshot.total and amount < snapshot.total)
        if sampleRates then
            for _, entry in ipairs(nativeSource) do
                if not Number(entry.dps) then return false, "Meter data is unavailable." end
            end
            if mode == 1 then
                snapshot.rate, snapshot.averageRate = dps.Header(rate)
            else
                snapshot.rate, snapshot.averageRate = rate, nil
            end
            rateSampledAt = now
        end
        local countersChanged = snapshot.publication ~= publication or snapshot.source ~= source
        if not countersChanged and not sampleRates then return true end
        for index, entry in ipairs(source) do
            local copy = snapshot.rows[index] or {}
            if countersChanged then
                copy.name, copy.dmg, copy.share, copy.proc = entry.name, entry.dmg, entry.share, entry.proc
                copy.class = modes[mode].party and type(entry.class) == "string" and entry.class or nil
            end
            local samples = rateSamples[copy.name]
            if not samples then
                samples = {}
                rateSamples[copy.name] = samples
            end
            local proc = copy.proc == 1
            local sample = samples[proc]
            if not sample then
                sample = {}
                samples[proc] = sample
            end
            if sample.epoch ~= rateSampledAt then
                if mode == 1 then
                    sample.rate, sample.average = dps.Row(copy.name, copy.proc, entry.dps)
                else
                    sample.rate, sample.average = entry.dps, nil
                end
                sample.epoch = rateSampledAt
            end
            copy.dps, copy.averageDps = sample.rate, sample.average
            snapshot.rows[index] = copy
        end
        if countersChanged then
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
        if party and options.icons then
            if snapshot.count > 0 then
                ReadPartyUnits()
            else
                ClearPartyUnits()
            end
        end
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
                        bound = BindPartyIcon(row, entry)
                    else
                        local resolver = DFRL.sct and DFRL.sct.GetSourceIcon
                        local icon = type(resolver) == "function"
                                and resolver(entry.name, modes[mode].healing, entry.proc)
                            or UNKNOWN_ICON
                        bound = BindIcon(row, icon)
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
        if paint and resetPending then
            local time = RunSeconds()
            -- One deferred capture clears every view, including unselected ones.
            -- Unavailable/unpublished views baseline their first accepted snapshot.
            for index = 1, table.getn(modes) do
                local source, amount, rate, _, publication = ReadNative(index)
                if source then session.Apply(index, source, amount, rate, time, publication) end
            end
            resetPending = false
        end
        -- Keep the recent damage window while another view awaits its own data.
        if paint and mode ~= 1 and dps.NeedsRead() then
            local revision = dps.revision
            ObserveDamage()
            if revision ~= dps.revision then ClearSamples() end
        end
        local valid, message = Read(paint)
        dataDirty = false
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
            Release(paint and mode ~= 1)
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
                Release(true)
                break
            end
        end
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
        HideTooltip()
        dps.Suspend()
        ClearSamples()
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
            dataDirty = true
            HideTooltip()
            dps.Clear()
            session.Clear()
            resetPending = false
            Release()
            UpdateController()
        end,
    })
    DFRL.display.Listen(function()
        local enable = DFRL.display.Get("meterEnabled")
        local enabledChanged = enabled ~= enable
        local count = DFRL.display.Get("meterRows")
        local selectedFontSize = DFRL.display.Get("meterFontSize")
        local fontChanged = fontSize ~= selectedFontSize
        local window = DFRL.display.Get("meterDpsWindow")
        local windowChanged = dps.window ~= window
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
        if windowChanged then
            dps.SetWindow(window)
            ClearSamples()
        end
        if changed then optionsRevision = optionsRevision + 1 end
        visible, age = count, 0.2
        offset = math.max(0, math.min(offset, snapshot.count - visible))
        for index = visible + 1, table.getn(rows) do
            ClearRow(rows[index])
        end
        if iconsWereShown and not options.icons then
            ClearPartyUnits()
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
        dps.Clear()
        if session.IsReset() then
            session.Reset()
            resetPending = true
        end
        ClearSamples()
        dataDirty = true
        age = 0.2
    end)
    function DFRL.ResetMeterStats()
        if not enabled or not inWorld or not ready or faulted then return end
        session.Reset()
        resetPending = true
        dps.Clear()
        ClearRows()
        ClearSamples()
        offset = 0
        if root:IsVisible() then
            DrawHeader(0)
            T.SetTextIfChanged(status, "")
            if status:IsShown() then status:Hide() end
        end
        dataDirty, age = true, 0.2
    end
    Tick = function()
        if not inWorld then return end
        age = age + (tonumber(arg1) or 0)
        if age < 0.2 then return end
        age = 0
        local ok, message = pcall(Refresh)
        if not ok then
            faulted = true
            dps.Clear()
            session.Clear()
            resetPending = false
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
                        receipts[index] = (receipts[index] or 0) + 1
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
