-- The War Within artwork: Karl-HeinzSchneider, MIT; shipped notice in
-- media/tex/meter/LICENSE.txt. Pinned source: third_party/DetailsTWW-ARTWORK.md.
-- Reset glyph: Blizzard Entertainment; provenance in the same source notes.
-- The existing gold ring retains third_party/Jewelry-ARTWORK.md's provenance.
DFRL:NewMod("DamageMeter", 7, function()
    local HEADER, ROW_HEIGHT, FOOTER, REFRESH_SECONDS = 32, 32, 32, 1
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
        groupPets = "meterGroupPets",
        total = "meterShowTotal",
        totalDps = "meterShowTotalDps",
    }
    local options, optionsRevision = {}, 0
    for key, setting in pairs(optionKeys) do
        options[key] = DFRL.display.Get(setting)
    end
    local palette = { revision = 0 }
    local function ReadPalette()
        local mode = DFRL.display.Get("meterColorMode")
        local ability, proc = DFRL.display.Get("meterAbilityColor"), DFRL.display.Get("meterProcColor")
        if palette.initialized and palette.mode == mode and palette.ability == ability and palette.proc == proc then
            return false
        end
        local changed = not palette.initialized or palette.mode ~= mode or mode == "custom"
        palette.initialized, palette.mode, palette.ability, palette.proc = true, mode, ability, proc
        if not changed then return false end
        palette.revision = palette.revision + 1
        if mode == "custom" then
            palette.red, palette.green, palette.blue = DFRL.display.ColorRGB(ability)
            palette.procRed, palette.procGreen, palette.procBlue = DFRL.display.ColorRGB(proc)
        end
        return true
    end
    ReadPalette()
    local schoolColors = {
        [1] = { 1, 1, 0 },
        [2] = { 1, 0.9, 0.5 },
        [4] = { 1, 0.5, 0 },
        [8] = { 0.3, 1, 0.3 },
        [16] = { 0.5, 1, 1 },
        [32] = { 0.5, 0.5, 1 },
        [64] = { 1, 0.5, 1 },
    }
    local function SchoolColor(mask)
        if type(mask) ~= "number" or mask < 1 or mask > 127 or mask ~= math.floor(mask) then return end
        local color = schoolColors[mask]
        if color then return unpack(color) end
        -- A native hybrid school is explicit; blend its bits once and reuse it.
        local red, green, blue, count, bit = 0, 0, 0, 0, 1
        for _ = 1, 7 do
            if math.mod(math.floor(mask / bit), 2) == 1 then
                local base = schoolColors[bit]
                red, green, blue, count = red + base[1], green + base[2], blue + base[3], count + 1
            end
            bit = bit * 2
        end
        red, green, blue = red / count, green / count, blue / count
        schoolColors[mask] = { red, green, blue }
        return red, green, blue
    end
    local categoryColors = {
        periodic = { 0.35, 0.84, 0.36 },
        basic_attack = { 0.72, 0.75, 0.8 },
        talent = { 0.72, 0.48, 1 },
        item = { 1, 0.62, 0.2 },
        proc = { 0.25, 0.58, 1 },
    }
    local function DefaultColor(entry)
        local color = entry.periodicDamage and categoryColors.periodic or categoryColors[entry.colorKind]
        if color then return unpack(color) end
        if entry.proc == 1 then return unpack(categoryColors.proc) end
        if entry.schoolMask then return SchoolColor(entry.schoolMask) end
    end
    local ICON_SIZE, RIM_SIZE = 26, 31
    local PARTY_COLOR = { 0.6, 0.6, 0.6 }
    local UNKNOWN_ICON = T.SourceIconFallback
    local path = DFRL:GetInfoOrCons("tex")
    local native = T.NewHudOwner("meter", "hudMeter")
    local api = type(T.NewNativeMeter) == "function" and T.NewNativeMeter() or nil
    local apiActive, apiIdentity, nativeContext = false, {}, nil
    local modes = {
        {
            getter = "AZS_GetMeter",
            stamp = "AZS_METER_UPDATED",
            prefix = "AZSMETER",
            title = "Damage Done",
            rate = "DPS",
            query = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source" },
        },
        {
            getter = "AZS_GetHealing",
            stamp = "AZS_HEALING_UPDATED",
            prefix = "AZSHEAL",
            title = "Healing Done",
            rate = "HPS",
            healing = true,
            query = {
                metric = "healing",
                healingPerspective = "received",
                scope = "self",
                period = "run",
                groupBy = "source",
            },
        },
        {
            getter = "AZS_GetBossMeter",
            stamp = "AZS_BOSSMETER_UPDATED",
            prefix = "AZSBOSSDMG",
            title = "Boss Damage",
            rate = "DPS",
            query = { metric = "damage", scope = "self", period = "encounter", groupBy = "actor_source" },
        },
        {
            getter = "AZS_GetPartyMeter",
            stamp = "AZS_PARTY_UPDATED",
            prefix = "AZSPARTY",
            title = "Party Damage",
            rate = "DPS",
            party = true,
            query = { metric = "damage", scope = "party", period = "run", groupBy = "owner" },
        },
    }
    for _, selected in ipairs(modes) do
        if not selected.party then selected.groups = T.NewMeterSourceGroups() end
    end
    local phases = { playing = true, choosing = true, paused = true, dead = true, victory = true }
    local mode, offset, age = 1, 0, REFRESH_SECONDS
    local inWorld, editing, ready, faulted = true, false, true, false
    local rows, received, blocked = {}, {}, {}
    local receipts, publications, publicationSequence = {}, {}, 0
    local viewSelection = { dirty = true, direction = 1, steps = 0, candidates = {}, reads = {} }
    local partyUnits = {
        { unit = "player" },
        { unit = "party1", portrait = "PartyMemberFrame1Portrait" },
        { unit = "party2", portrait = "PartyMemberFrame2Portrait" },
        { unit = "party3", portrait = "PartyMemberFrame3Portrait" },
        { unit = "party4", portrait = "PartyMemberFrame4Portrait" },
    }
    local dataDirty, dataValid = true, false
    local snapshot = { rows = {}, count = 0 }
    local rateSamples, rateSampledAt, ratePass = {}, nil, 0
    local recentView = {}
    local dps = T.NewMeterDps(DFRL.display.Get("meterDpsWindow"))
    local session, resetPending = T.NewMeterSession(), false
    local presentation = {
        shown = false,
        cleared = true,
        fontChoice = DFRL.display.Get("uiFont"),
        fontOutline = DFRL.display.Get("uiFontOutline"),
        fontRevision = 0,
    }
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
    local function ClearSourceGroups()
        for _, selected in ipairs(modes) do
            if selected.groups then selected.groups.Clear() end
        end
    end
    local function UpdateController()
        local listen = inWorld and enabled and ready and not faulted and true or false
        local packets = listen and not (api and api.Supported()) and true or false
        if listening ~= packets then
            listening = packets
            if packets then
                controller:RegisterEvent("CHAT_MSG_ADDON")
            else
                controller:UnregisterEvent("CHAT_MSG_ADDON")
            end
        end
        local cleanup = api and api.PendingCleanup()
        local active = inWorld and (listen or native.IsCaptured() or cleanup) and true or false
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
    local function SuspendRates()
        dps.Suspend()
        ClearSamples()
        if api then api.SuspendRecent() end
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
        row.staticIcon, row.staticScale, row.staticBound = nil, nil, nil
        if row.rim:IsShown() then row.rim:Hide() end
        row.partyUnit, row.partyName, row.partySource, row.partyTexture = nil, nil, nil, nil
        row.apiPortraitKey, row.apiPortraitRun = nil, nil
        row.apiPortraitBound, row.apiPortraitRetryAt = nil, nil
    end
    local function BindIcon(row, icon)
        row.staticBound = nil
        if not icon then
            ClearIcon(row)
            return false
        end
        return row.circularIcon.Bind(icon, presentation.scale)
    end
    local function BindStaticIcon(row, icon)
        if row.staticBound and row.staticIcon == icon and row.staticScale == presentation.scale then return true end
        local bound = BindIcon(row, icon)
        row.staticIcon, row.staticScale, row.staticBound = icon, presentation.scale, bound
        return bound
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
    local function IsReset()
        if apiActive then return api.IsReset() end
        return session.IsReset()
    end
    local function HideTooltip()
        if not hovered then return end
        if hovered and GameTooltip and GameTooltip:IsOwned(hovered) then GameTooltip:Hide() end
        hovered = nil
        for key in pairs(tooltipState) do
            tooltipState[key] = nil
        end
    end
    local function ShiftHeld() return type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and true or false end
    local function ShowRowTooltip(row)
        if editing or not row.entry or not row:IsVisible() or not GameTooltip then return end
        local entry, language, scale = row.entry, DFRL.locale.code, GameTooltip:GetEffectiveScale()
        local damage = string.format("%.0f", entry.dmg)
        local rate = entry.dps and string.format("%.1f", entry.dps) or "--"
        local average = entry.averageDps and string.format("%.1f", entry.averageDps) or "--"
        local reset = IsReset()
        local share = string.format("%.1f%%", entry.share * 100)
        local source, identity = apiActive and snapshot.source or nil, apiActive and entry.rateIdentity or nil
        local debug = source ~= nil and ShiftHeld() or false
        local details = debug and tooltipState.details or nil
        if
            debug
            and (
                not tooltipState.debug
                or hovered ~= row
                or tooltipState.source ~= source
                or tooltipState.rowId ~= entry.rowId
                or tooltipState.identity ~= identity
            )
        then
            details = source and type(api.Describe) == "function" and api.Describe(source, entry.rowId) or nil
        end
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
            and tooltipState.source == source
            and tooltipState.rowId == entry.rowId
            and tooltipState.identity == identity
            and tooltipState.debug == debug
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
        if details and table.getn(details) > 0 then
            GameTooltip:AddLine(DFRL.locale.Text("Native IDs"), 1, 0.82, 0)
            for _, text in ipairs(details) do
                GameTooltip:AddLine(text, 0.75, 0.75, 0.75, true)
            end
        end
        GameTooltip:Show()
        tooltipState.name, tooltipState.damage, tooltipState.rate, tooltipState.share = entry.name, damage, rate, share
        tooltipState.average, tooltipState.reset = average, reset
        tooltipState.debug = debug
        tooltipState.mode, tooltipState.language, tooltipState.scale = mode, language, scale
        tooltipState.source, tooltipState.rowId, tooltipState.identity, tooltipState.details =
            source, entry.rowId, identity, details
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
    -- Blizzard's gold refresh glyph and native button states; see DetailsTWW-ARTWORK.md.
    local resetButton = CreateFrame("Button", nil, header)
    resetButton:SetPoint("RIGHT", header, "RIGHT", -12, 1)
    resetButton:SetWidth(16)
    resetButton:SetHeight(16 * 38 / 36)
    resetButton:RegisterForClicks("LeftButtonUp")
    for _, state in ipairs({ "Normal", "Pushed", "Highlight" }) do
        resetButton["Set" .. state .. "Texture"](resetButton, path .. "meter\\Reset.blp")
        local texture = resetButton["Get" .. state .. "Texture"](resetButton)
        if texture then
            texture:SetTexCoord(0, 1, 0, 1)
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", resetButton, "CENTER", 0, 0)
            texture:SetWidth(16)
            texture:SetHeight(16)
            if state == "Pushed" then texture:SetVertexColor(0.65, 0.65, 0.65) end
            if state == "Highlight" then texture:SetBlendMode("ADD") end
        end
    end

    local function ShowHeaderTooltip()
        if editing or not GameTooltip then return end
        local average = snapshot.averageRate and string.format("%.1f", snapshot.averageRate) or "--"
        local reset = IsReset()
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
        presentation.scale = root:GetEffectiveScale()
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
            row.layoutReady = nil
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
        local face, size, flags
        -- Native font changes can affect just one label without a settings edit.
        if columns > 0 then
            face, size, flags = row.value:GetFont()
        end
        local scale = presentation.scale
        if
            row.layoutReady
            and (columns == 0 or row.valueMetric ~= nil)
            and row.layoutWidth == width
            and row.layoutIcons == options.icons
            and row.valueColumns == columns
            and row.layoutText == row.valueText
            and row.layoutNameFontSize == nameFontSize
            and (columns == 0 or row.layoutFontSize == fontSize)
            and row.layoutFontRevision == presentation.fontRevision
            and row.layoutFace == face
            and row.layoutSize == size
            and row.layoutFlags == flags
            and T.NearlyEqual(row.layoutScale, scale)
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
        if row.layoutNameFontSize ~= nameFontSize and SizeLabel(row.name, nameFontSize, nameFontSize + 5) then
            row.layoutNameFontSize = nameFontSize
        end
        if columns > 0 and row.layoutFontSize ~= fontSize then
            if SizeLabel(row.value, fontSize, fontSize + 5) then row.layoutFontSize = fontSize end
            face, size, flags = row.value:GetFont()
        end
        local available = width - 16 - nameLeft - 2
        local valueWidth, measuredReady = 0, columns == 0
        if columns > 0 then
            -- Reserve only the current numeric caption's natural width. Keep
            -- the old conservative reservation until native metrics are ready.
            valueWidth = columns * math.ceil(58 * fontSize / 11)
            local text = row.valueText
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
                measuredReady = true
            elseif face and Number(size) and size > 0 and Number(scale) and scale > 0 and text and text ~= "" then
                local measured = row.value:GetStringWidth()
                if Number(measured) and measured > 0 then
                    metric = metric or {}
                    metric.text, metric.face, metric.size, metric.flags = text, face, size, flags
                    metric.scale, metric.available, metric.width = scale, available, math.ceil(measured) + 1
                    row.valueMetric = metric
                    valueWidth = metric.width
                    measuredReady = true
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
        row.layoutText, row.layoutFace, row.layoutSize, row.layoutFlags = row.valueText, face, size, flags
        row.layoutScale, row.layoutFontRevision = scale, presentation.fontRevision
        row.layoutReady = measuredReady
            and row.layoutNameFontSize == nameFontSize
            and (columns == 0 or row.layoutFontSize == fontSize)
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
        row.drawDamageShown, row.drawDpsShown, row.drawShareShown = nil, nil, nil
        row.valueText, row.layoutReady = nil, nil
        row.fractionDamage, row.fractionMaximum = nil, nil
        row.valueMetric = nil
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
        snapshot.maximum, snapshot.offset, snapshot.visible = nil, nil, nil
        snapshot.nativeRunId, snapshot.nativeEpoch, snapshot.nativeAuthority = nil, nil, nil
        snapshot.nativeEncounter, snapshot.nativeRunSeconds = nil, nil
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
    local function ClearReadPass()
        nativeContext = nil
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
        dps.Clear()
        session.Clear()
        ClearSourceGroups()
        if api then api.Clear() end
        apiIdentity = {}
        resetPending = false
        ClearReadPass()
        viewSelection.first, viewSelection.steps, viewSelection.dirty, viewSelection.paint = nil, 0, true, false
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
    local function LegacyRows(selected, source, amount, rate, publication)
        if selected.groups and viewSelection.paint then
            source = selected.groups.Read(source, publication)
            if not source then return nil, nil, nil, "Meter data is unavailable." end
        elseif selected.party then
            for _, entry in ipairs(source) do
                if type(entry) ~= "table" or not Number(entry.dps) then
                    return nil, nil, nil, "Meter data is unavailable."
                end
            end
        end
        return source, amount, rate, nil, publication
    end
    local function ReadNative(index)
        local selected = modes[index]
        if apiActive then
            local window = index == 1 and dps.window or 0
            local policy
            if window > 0 then
                local now = GetTime()
                recentView.offset, recentView.count = offset, visible
                recentView.refresh = not rateSampledAt
                    or now < rateSampledAt
                    or now - rateSampledAt >= 1
                    or index ~= mode
                    or viewSelection.first ~= nil
                    or viewSelection.dirty
                policy = recentView
            end
            return api.Read(selected.query, window, options.groupPets, nativeContext, policy)
        end
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
            return LegacyRows(selected, source, amount, rate, publication.revision)
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
        return LegacyRows(selected, source, amount, rate, publication.revision)
    end
    local function ReadOnce(index)
        local entry = viewSelection.reads[index]
        if not entry then
            entry = {}
            viewSelection.reads[index] = entry
        end
        if not entry.read then
            entry.source, entry.amount, entry.rate, entry.message, entry.publication, entry.meta = ReadNative(index)
            entry.read, viewSelection.read = true, true
        end
        return entry.source, entry.amount, entry.rate, entry.message, entry.publication, entry.meta
    end
    local function ResolveView(source, amount, rate, message, publication, meta)
        local supported = apiActive or type(_G[modes[mode].getter]) == "function"
        if not viewSelection.first then
            if supported and (source or message) then
                viewSelection.dirty = false
                return source, amount, rate, message, publication, meta
            end
            if not viewSelection.dirty then return source, amount, rate, message, publication, meta end
        end
        -- Only a navigation request or newly relevant publication/readiness
        -- probes other views. Empty received snapshots and explicit errors
        -- have useful presentation; only unpublished blank views are skipped.
        local count, current = 0, false
        for step = 0, table.getn(modes) - 1 do
            local index = math.mod(mode - 1 + step, table.getn(modes)) + 1
            if apiActive or type(_G[modes[index].getter]) == "function" then
                local candidateSource, candidateMessage
                local _
                candidateSource, _, _, candidateMessage = ReadOnce(index)
                if candidateSource or candidateMessage then
                    count = count + 1
                    viewSelection.candidates[count] = index
                    if step == 0 then current = true end
                end
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
                Release(true)
                mode, offset = selected, 0
            end
            source, amount, rate, message, publication, meta = ReadOnce(selected)
        end
        viewSelection.first, viewSelection.steps, viewSelection.dirty = nil, 0, false
        return source, amount, rate, message, publication, meta
    end
    local function ObserveDamage(source, amount, rate, publication)
        if not source then
            local _
            source, amount, rate, _, publication = ReadOnce(1)
            if not source then
                dps.Suspend()
                return
            end
            source, amount, rate = session.Apply(1, source, amount, rate, RunSeconds(), publication)
        end
        if not dps.Observe(RunSeconds(), source, amount, rate, publication) then dps.Suspend() end
    end
    local function Read(paint, source, amount, rate, message, publication, meta)
        if not source then return false, message end
        dataValid = true
        if not paint then
            dps.Suspend()
            return true
        end
        if apiActive and meta then
            if
                snapshot.nativeRunId ~= meta.runId
                or snapshot.nativeEpoch ~= meta.counterEpoch
                or snapshot.nativeAuthority ~= meta.authorityId
                or snapshot.nativeEncounter ~= meta.encounterId
                or (snapshot.nativeRunSeconds and meta.asOfRunSeconds < snapshot.nativeRunSeconds)
            then
                ClearSamples()
            end
            snapshot.nativeRunId, snapshot.nativeEpoch, snapshot.nativeAuthority =
                meta.runId, meta.counterEpoch, meta.authorityId
            snapshot.nativeEncounter = meta.encounterId
            snapshot.nativeRunSeconds = meta.asOfRunSeconds
            if type(DFRL.locale.Select) == "function" then DFRL.locale.Select(meta.languageCode) end
        end
        if not apiActive then
            source, amount, rate = session.Apply(mode, source, amount, rate, RunSeconds(), publication)
        end
        local count = table.getn(source)
        local revision = dps.revision
        if mode == 1 and not apiActive then ObserveDamage(source, amount, rate, publication) end
        if revision ~= dps.revision then ClearSamples() end
        -- Native run seconds own the rate window; UI time only limits repaint.
        local now = GetTime()
        local sampleRates = not rateSampledAt
            or now < rateSampledAt
            or now - rateSampledAt >= 1
            or (snapshot.total and amount < snapshot.total)
        if sampleRates then
            if apiActive then
                snapshot.rate, snapshot.averageRate = rate, meta and meta.averageRate
            elseif mode == 1 then
                snapshot.rate, snapshot.averageRate = dps.Header(rate)
            else
                snapshot.rate, snapshot.averageRate = rate, nil
            end
            rateSampledAt = now
        end
        offset = math.max(0, math.min(offset, count - visible))
        local countersChanged = snapshot.publication ~= publication
            or snapshot.source ~= source
            or snapshot.count ~= count
            or snapshot.total ~= amount
        local viewportChanged = snapshot.offset ~= offset or snapshot.visible ~= visible
        if not countersChanged and not sampleRates and not viewportChanged then return true end
        ratePass = ratePass + 1
        local displayed = math.min(visible, count - offset)
        for index = 1, displayed do
            local entry = source[index + offset]
            local copy = snapshot.rows[index] or {}
            if countersChanged or viewportChanged then
                copy.name, copy.dmg, copy.share, copy.proc = entry.name, entry.dmg, entry.share, entry.proc
                copy.class = modes[mode].party and type(entry.class) == "string" and entry.class or nil
                copy.rowId, copy.icon = entry.rowId, entry.icon
                copy.rateIdentity = apiActive and entry.rateIdentity or nil
                copy.portraitKey, copy.portraitRunId = entry.portraitKey, entry.portraitRunId
                copy.portraitStatus = entry.portraitStatus
            end
            copy.schoolMask = apiActive and entry.schoolMask or nil
            copy.colorKind = apiActive and entry.colorKind or nil
            copy.periodicDamage = apiActive and entry.periodicDamage or nil
            local key = apiActive and copy.rowId or copy.name
            local samples = rateSamples[key]
            if not samples then
                samples = {}
                rateSamples[key] = samples
            end
            local proc = copy.proc == 1
            local sample = samples[proc]
            if not sample then
                sample = {}
                samples[proc] = sample
            end
            if sample.epoch ~= rateSampledAt or (apiActive and sample.identity ~= copy.rateIdentity) then
                if apiActive then
                    sample.rate, sample.average = entry.dps, entry.averageDps
                elseif mode == 1 then
                    sample.rate, sample.average = dps.Row(copy.name, copy.proc, entry.dps)
                else
                    sample.rate, sample.average = entry.dps, nil
                end
                sample.epoch, sample.identity = rateSampledAt, copy.rateIdentity
            end
            sample.seen = ratePass
            copy.dps, copy.averageDps = sample.rate, sample.average
            snapshot.rows[index] = copy
        end
        for key, samples in pairs(rateSamples) do
            for proc, sample in pairs(samples) do
                if sample.seen ~= ratePass then samples[proc] = nil end
            end
            if not next(samples) then rateSamples[key] = nil end
        end
        for index = displayed + 1, table.getn(snapshot.rows) do
            snapshot.rows[index] = nil
        end
        table.setn(snapshot.rows, displayed)
        snapshot.count, snapshot.total = count, amount
        snapshot.maximum = source[1] and source[1].dmg or 0
        snapshot.source, snapshot.publication = source, publication
        snapshot.offset, snapshot.visible = offset, visible
        presentation.cleared = false
        return true
    end
    local function Draw()
        offset = math.max(0, math.min(offset, snapshot.count - visible))
        local maximum = snapshot.maximum or 0
        local party = modes[mode].party
        local classColor = party and PARTY_COLOR or T.GetPlayerClassColor() or { 0.8, 0.63, 0.28 }
        local classRed, classGreen, classBlue = unpack(classColor)
        if not party and palette.mode == "custom" then
            classRed, classGreen, classBlue = palette.red, palette.green, palette.blue
        end
        if party and options.icons and not apiActive then
            if snapshot.count > 0 then
                ReadPartyUnits()
            else
                ClearPartyUnits()
            end
        end
        for index = 1, visible do
            local entry = snapshot.rows[index]
            if entry then
                local row = Row(index)
                if hovered == row and row.displayName ~= entry.name then HideTooltip() end
                row.entry, row.active = entry, true
                local rank = options.ranks and index + offset or nil
                if row.displayName ~= entry.name or row.drawIndex ~= rank then
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
                    or row.drawDamageShown ~= options.damage
                    or row.drawDpsShown ~= options.dps
                    or row.drawShareShown ~= options.percentage
                then
                    local values = damage and Compact(damage) or ""
                    if options.dps then
                        values = values .. (values ~= "" and "   " or "") .. (rate and Compact(rate) or "--")
                    end
                    if share then
                        values = values .. (values ~= "" and "   " or "") .. string.format("%.1f%%", share * 100)
                    end
                    T.SetTextIfChanged(row.value, values)
                    row.valueText = values
                    row.drawDamage, row.drawRate, row.drawShare = damage, rate, share
                    row.drawDamageShown, row.drawDpsShown, row.drawShareShown =
                        options.damage, options.dps, options.percentage
                end
                LayoutRow(row)
                if row.fractionDamage ~= entry.dmg or row.fractionMaximum ~= maximum then
                    local fraction = maximum > 0 and math.min(1, entry.dmg / maximum) or 0
                    if row.fraction ~= fraction then row.bar:SetValue(fraction) end
                    row.fraction, row.fractionDamage, row.fractionMaximum = fraction, entry.dmg, maximum
                end
                if
                    party
                    or row.colorParty ~= party
                    or row.colorProc ~= entry.proc
                    or row.colorRed ~= classRed
                    or row.colorGreen ~= classGreen
                    or row.colorBlue ~= classBlue
                    or row.colorPalette ~= palette.revision
                    or (
                        palette.mode ~= "custom"
                        and (
                            row.colorSchoolMask ~= entry.schoolMask
                            or row.colorKind ~= entry.colorKind
                            or row.colorPeriodic ~= entry.periodicDamage
                        )
                    )
                then
                    local r, g, b = classRed, classGreen, classBlue
                    if party then
                        local color = T.GetClassColor(entry.class)
                        if color then
                            r, g, b = unpack(color)
                        else
                            r, g, b = 0.6, 0.6, 0.6
                        end
                    elseif palette.mode == "custom" then
                        if entry.proc == 1 then
                            r, g, b = palette.procRed, palette.procGreen, palette.procBlue
                        end
                    else
                        local red, green, blue = DefaultColor(entry)
                        if red then
                            r, g, b = red, green, blue
                        end
                    end
                    if row.red ~= r or row.green ~= g or row.blue ~= b then row.bar:SetStatusBarColor(r, g, b) end
                    row.red, row.green, row.blue = r, g, b
                    row.colorParty, row.colorProc = party, entry.proc
                    row.colorRed, row.colorGreen, row.colorBlue = classRed, classGreen, classBlue
                    row.colorPalette = palette.revision
                    row.colorSchoolMask = entry.schoolMask
                    row.colorKind, row.colorPeriodic = entry.colorKind, entry.periodicDamage
                end
                if options.icons then
                    local bound
                    if apiActive and (party or entry.portraitKey) then
                        bound = BindNativePortrait(row, entry)
                    elseif party then
                        bound = BindPartyIcon(row, entry)
                    elseif apiActive then
                        bound = BindStaticIcon(row, entry.icon or UNKNOWN_ICON)
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
    local function ReadPhase()
        if api and api.PendingCleanup() then api.RetryCleanup() end
        local ok, phase = false, nil
        local useApi = api and api.Supported() and true or false
        if apiActive ~= useApi then
            ClearRows()
            ClearSamples()
            ClearReadPass()
            session.Clear()
            dps.Clear()
            ClearSourceGroups()
            apiActive = useApi
            apiIdentity = {}
            viewSelection.dirty = true
            UpdateController()
        end
        if apiActive then
            local context = api.Context()
            if context then
                ok, phase = true, context.phase
                if apiIdentity.runId and apiIdentity.runId ~= context.runId then
                    api.Clear()
                    ClearRows()
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
            end
            nativeContext = context
        elseif type(AZS_GetPhase) == "function" then
            ok, phase = pcall(AZS_GetPhase)
        end
        return ok, phase
    end
    local function CaptureLegacyReset()
        if not resetPending or apiActive then return end
        local time = RunSeconds()
        -- Legacy clients capture once in the visible deferred reader.
        for index = 1, table.getn(modes) do
            local source, amount, rate, _, publication = ReadOnce(index)
            if source then session.Apply(index, source, amount, rate, time, publication) end
        end
        resetPending = false
    end
    local function Refresh()
        if not inWorld or not enabled or not ready or faulted then
            if api and api.PendingCleanup() then api.RetryCleanup() end
            Release()
            SetShown(false)
            UpdateController()
            return
        end
        -- Native context owns v1 phase/run identity; legacy clients retain packets.
        local ok, phase = ReadPhase()
        local wasChoiceHidden = presentation.choiceHidden
        presentation.choiceHidden = ok and phase == "choosing" or false
        if not ok or not phases[phase] then
            if phase == "ready" then
                Invalidate()
            else
                Release()
            end
            SetShown(false)
            return
        end
        if presentation.choiceHidden then
            -- Choice cards hide presentation without retiring the active session.
            SetShown(false)
            native.Acquire()
            return
        end
        local paint = not DFRL.layout.IsHidden("damageMeter") and UIParent:IsVisible()
        if wasChoiceHidden and not paint then SuspendRates() end
        if paint and not viewSelection.paint then viewSelection.dirty = true end
        viewSelection.paint = paint
        if not paint and not dataDirty then
            if dataValid then native.Acquire() end
            return
        end
        if paint then CaptureLegacyReset() end
        local source, amount, rate, message, publication, meta = ReadOnce(mode)
        if apiActive and not source then viewSelection.dirty = true end
        if paint then
            source, amount, rate, message, publication, meta =
                ResolveView(source, amount, rate, message, publication, meta)
        end
        -- Keep the recent damage window while another view awaits its own data.
        if paint and mode ~= 1 and not apiActive and dps.NeedsRead() then
            local revision = dps.revision
            ObserveDamage()
            if revision ~= dps.revision then ClearSamples() end
        end
        local valid
        valid, message = Read(paint, source, amount, rate, message, publication, meta)
        presentation.waiting = not valid and message == nil
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
        if editing or not enabled or not inWorld then return end
        HideTooltip()
        local direction = arg1 == "RightButton" and -1 or 1
        if viewSelection.first then
            viewSelection.steps = viewSelection.steps + direction
        else
            viewSelection.first, viewSelection.steps = direction, 0
        end
        viewSelection.direction, age = direction, REFRESH_SECONDS
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
        if not presentation.choiceHidden then SuspendRates() end
        for _, row in ipairs(rows) do
            row.valueMetric = nil
            row.layoutReady = nil
        end
    end)
    root:SetScript("OnShow", function()
        if presentation.choiceHidden then
            root:Hide()
            return
        end
        if not viewSelection.paint then age = REFRESH_SECONDS end
    end)
    root:SetScript("OnMouseWheel", function()
        if editing then return end
        HideTooltip()
        offset = math.max(0, math.min(offset - (tonumber(arg1) or 0), snapshot.count - visible))
        age = REFRESH_SECONDS
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
            width, age = frame:GetWidth(), REFRESH_SECONDS
        end,
        onEdit = function(active)
            editing, age = active, REFRESH_SECONDS
            HideTooltip()
            header:EnableMouse(not active)
            resetButton:EnableMouse(not active)
            for _, row in ipairs(rows) do
                row:EnableMouse(not active)
            end
        end,
        onReset = function()
            mode, offset, age, faulted = 1, 0, REFRESH_SECONDS, false
            viewSelection.first, viewSelection.steps, viewSelection.dirty = nil, 0, true
            dataDirty = true
            HideTooltip()
            dps.Clear()
            session.Clear()
            ClearSourceGroups()
            if api then api.Clear() end
            resetPending = false
            Release()
            UpdateController()
        end,
    })
    DFRL.display.Listen(function()
        local paletteChanged = ReadPalette()
        local enable = DFRL.display.Get("meterEnabled")
        local enabledChanged = enabled ~= enable
        local count = DFRL.display.Get("meterRows")
        local selectedFontSize = DFRL.display.Get("meterFontSize")
        local selectedNameFontSize = DFRL.display.Get("meterNameFontSize")
        local fontChanged = fontSize ~= selectedFontSize or nameFontSize ~= selectedNameFontSize
        local fontChoice, fontOutline = DFRL.display.Get("uiFont"), DFRL.display.Get("uiFontOutline")
        local styleChanged = presentation.fontChoice ~= fontChoice or presentation.fontOutline ~= fontOutline
        local window = DFRL.display.Get("meterDpsWindow")
        local windowChanged = dps.window ~= window
        local changed, iconsWereShown, petsWereCombined = false, options.icons, options.groupPets
        for key, setting in pairs(optionKeys) do
            local value = DFRL.display.Get(setting)
            if options[key] ~= value then
                options[key], changed = value, true
            end
        end
        if
            visible == count
            and not changed
            and not enabledChanged
            and not fontChanged
            and not styleChanged
            and not windowChanged
            and not paletteChanged
        then
            return
        end
        HideTooltip()
        enabled = enable
        fontSize = selectedFontSize
        nameFontSize = selectedNameFontSize
        if styleChanged then
            presentation.fontChoice, presentation.fontOutline = fontChoice, fontOutline
            presentation.fontRevision = presentation.fontRevision + 1
        end
        if windowChanged then
            dps.SetWindow(window)
            ClearSamples()
        end
        if petsWereCombined ~= options.groupPets then
            ClearSamples()
            ClearReadPass()
        end
        if changed then optionsRevision = optionsRevision + 1 end
        visible, age = count, REFRESH_SECONDS
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
        if not apiActive and session.IsReset() then
            session.Reset()
            resetPending = true
        end
        ClearSamples()
        dataDirty = true
        age = REFRESH_SECONDS
    end)
    function DFRL.ResetMeterStats()
        if not enabled or not inWorld or not ready or faulted then return end
        if api and api.Supported() then
            local captured = api.Reset()
            if not captured then return end
            apiActive = true
            resetPending = false
        else
            session.Reset()
            resetPending = true
        end
        dps.Clear()
        ClearRows()
        ClearSamples()
        ClearReadPass()
        offset = 0
        if root:IsVisible() then
            DrawHeader(0)
            T.SetTextIfChanged(status, "")
            if status:IsShown() then status:Hide() end
        end
        dataDirty, age = true, REFRESH_SECONDS
    end
    Tick = function()
        if not inWorld then return end
        age = age + (tonumber(arg1) or 0)
        if age < REFRESH_SECONDS then
            if hovered and hovered.entry then
                if
                    not hovered:IsVisible()
                    or not GameTooltip
                    or not GameTooltip:IsVisible()
                    or not GameTooltip:IsOwned(hovered)
                then
                    HideTooltip()
                elseif tooltipState.debug ~= (apiActive and ShiftHeld() or false) then
                    ShowRowTooltip(hovered)
                end
            end
            return
        end
        age = 0
        local ok, message = pcall(Refresh)
        ClearReadPass()
        if not ok then
            faulted = true
            dps.Clear()
            session.Clear()
            ClearSourceGroups()
            if api then api.Clear() end
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
            inWorld, faulted, age = true, false, REFRESH_SECONDS
            UpdateController()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            Invalidate()
            UpdateController()
        elseif event == "CVAR_UPDATE" then
            if native.Observe(arg1) then
                age = REFRESH_SECONDS
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
                        viewSelection.dirty = true
                        if index == mode then dataDirty = true end
                    end
                end
            end
            -- The one-second read coalesces packets and runs after native parsing.
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
