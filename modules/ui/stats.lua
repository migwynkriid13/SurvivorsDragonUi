-- Optional native stat HUD; settings and geometry share the /sdui transaction.
--[[
World of Warcraft artwork copyright Blizzard Entertainment, Inc.
The existing QuestTracker header is reused through T.CreateQuestTrackerHeader:
NeticSoul/DragonUI 5aefa049d22ba1a9e968b433d96eed7be86d6ac9,
DragonUI/Textures/UI/QuestTracker.BLP, source rectangle (11,247,571,317).
The character/equipment icon is cropped from Gethe/wow-ui-textures
d23deaf8f44a7d280dc974a5c9d5321c013db59b,
PaperDollInfoFrame/PaperDollSidebarTabs.PNG, rectangle (1,120,34,155).
Blizzard artwork is not covered by the source projects' software licenses.
Sources and assembly: third_party/GuardianTracker-ARTWORK.md,
third_party/Stats-ARTWORK.md and docs/STATS-WINDOW.md.
]]
DFRL:NewMod("Stats", 5, function()
    local display, layout, locale = DFRL.display, DFRL.layout, DFRL.locale
    local style, SCALE, INSET = T.RightHudStyle, 0.85, 12
    local WIDTH, HEADER_HEIGHT = style.width / SCALE, style.questHeaderHeight / SCALE
    local path = DFRL:GetInfoOrCons("tex")
    local headerFiles = { "guardians\\Header.blp", "guardians\\Header_2.blp" }
    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Percent(value, signed)
        value = value * 100
        if not Number(value) then return end
        if math.abs(value) < 0.05 then value = 0 end
        return (string.gsub(string.format(signed and "%+.1f%%" or "%.1f%%", value), "%.0%%$", "%%"))
    end
    local function Signed(value) return Percent(value, true) end
    local function Plain(value) return Percent(value, false) end
    local function Bonus(value) return Percent(value - 1, true) end
    local function Decimal(value)
        if math.abs(value) < 0.05 then value = 0 end
        return (string.gsub(string.format("%.1f", value), "%.0$", ""))
    end
    local function Count(value) return string.format("%g", value) end
    local function Grouped(value)
        local text = string.format("%.0f", value)
        while true do
            local changed
            text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
            if changed == 0 then return text end
        end
    end
    local read = {
        Damage = { "dmg", Bonus },
        Haste = { "cd", function(value) return Percent(1 - value, true) end },
        Crit = { "crit", Plain },
        CritDamage = { "cm", Plain },
        Melee = { "auto", Signed },
        PetDamage = { "pet", Signed },
        BuffPower = { "bp", Signed },
        Health = { "hp", Grouped },
        Armor = { "arm", Plain },
        Regen = { "reg", Decimal },
        Lifesteal = { "lch", Plain },
        KillHeal = { "heal", Decimal },
        Thorns = { "thn", Plain },
        Shielded = { "shd", Signed },
        Lives = { "liv", Count },
        Area = { "area", Bonus },
        Echo = { "echo", Plain },
        Targets = { "cnt", function(value) return "+" .. Count(value) end },
        DotStacks = { "dots", Count },
        DotHaste = { "doth", Signed },
        VsAfflicted = { "dotd", Signed },
        VsElites = { "big", Signed },
        Execute = { "exe", Signed },
        VsControlled = { "cc", Signed },
        Speed = { "spd", Bonus },
        Experience = { "xp", Bonus },
        Luck = { "luck", Signed },
        Pickup = { "pick", function(value) return locale.Native("common.yards", { n = Decimal(value) }) end },
    }
    local options, model, rows, headings, raw, formatted = {}, {}, {}, {}, {}, {}
    local width, modelCount, fontRevision = WIDTH, 0, 0
    local dirty, shown, editing, inWorld = true, false, false, true
    local permitted, subscribed = not layout.IsHidden("survivorStats"), false
    local receipt, retiredReceipt = 0, 0
    local lastStats, retiredStats, lastZone, lastClock, zonePending
    local pendingAt, retryAt, labels, Tick, Sync
    local aboveScreens = false
    local controller = CreateFrame("Frame", nil, UIParent)
    local panel = CreateFrame("Frame", "SurvivorsDragonUiStats", UIParent)
    panel:SetScale(SCALE)
    panel:SetWidth(WIDTH)
    panel:SetHeight(HEADER_HEIGHT + 14 * 17 + 4 * 23 + 8)
    panel:SetFrameStrata("MEDIUM")
    panel:EnableMouse(false)
    panel:Hide()

    local function Visible(region, value)
        if value then
            if not region:IsShown() then region:Show() end
        elseif region:IsShown() then
            region:Hide()
        end
    end
    local function SetScreenLayer(wanted)
        if aboveScreens == wanted then return true end
        if type(AZS_SetOnTopOfScreens) ~= "function" then return false end
        local ok, applied = pcall(AZS_SetOnTopOfScreens, panel, wanted)
        if not ok or applied == false then return false end
        if type(AZS_IsOnTopOfScreens) == "function" then
            local checked, current = pcall(AZS_IsOnTopOfScreens, panel)
            if not checked or ((current == true or current == 1) ~= wanted) then return false end
        end
        aboveScreens = wanted
        return true
    end
    local function Hide()
        if shown then panel:Hide() end
        shown = false
        SetScreenLayer(false)
    end
    local function Retire(threshold)
        if lastStats then
            retiredStats, retiredReceipt = lastStats, threshold or receipt
        end
        lastStats, lastClock, lastZone = nil, nil, nil
        for key in pairs(raw) do
            raw[key], formatted[key] = nil, nil
        end
        dirty = true
    end
    local function Prime()
        if not inWorld or not options.statsWindow or not permitted then return end
        pendingAt, retryAt = GetTime(), nil
        if controller:GetScript("OnUpdate") ~= Tick then controller:SetScript("OnUpdate", Tick) end
    end
    local function Font(label, size, title)
        if label.statsSize == size and label.statsTitle == title and label.statsFontRevision == fontRevision then
            return true
        end
        if T.SetFont(label, size, title and "" or "OUTLINE") == false then return false end
        if not label:GetFont() then return false end
        label.statsSize, label.statsTitle, label.statsFontRevision = size, title, fontRevision
        return true
    end
    local function Label(size, color, side, title)
        local label = panel:CreateFontString(nil, "OVERLAY")
        Font(label, size, title)
        T.SetChatShadow(label)
        label:SetTextColor(unpack(color))
        label:SetJustifyH(side or "LEFT")
        label:SetJustifyV("MIDDLE")
        label:Hide()
        return label
    end
    local function Prepare()
        if labels then return end
        labels = { header = T.CreateQuestTrackerHeader(panel, width, HEADER_HEIGHT) }
        labels.title = Label(style.titleSize / SCALE, style.titleColor, "LEFT", true)
        labels.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 40, -(HEADER_HEIGHT - 23) / 2)
        labels.title:SetHeight(23)
        labels.icon = panel:CreateTexture(nil, "ARTWORK")
        local iconWidth = 24 * 33 / 35
        labels.icon:SetWidth(iconWidth)
        labels.icon:SetHeight(24)
        labels.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 9 + (24 - iconWidth) / 2, -(HEADER_HEIGHT - 24) / 2)
        labels.icon:SetTexCoord(15 / 64, 48 / 64, 14 / 64, 49 / 64)
        labels.icon:SetBlendMode("BLEND")
        labels.measure = Label(options.statsFontSize, style.bodyColor)
        labels.measure:SetWidth(0)
        labels.measure:SetHeight(30)
    end
    local function Fit(label, text, available, size, title)
        local key = text .. ":" .. tostring(available) .. ":" .. tostring(size) .. ":" .. tostring(fontRevision)
        if label.statsFit == key then return true end
        local measure = labels.measure
        local fitted = size
        while true do
            if not Font(measure, fitted, title) then return false end
            T.SetTextIfChanged(measure, text)
            local measured = measure:GetStringWidth()
            if not Number(measured) or (text ~= "" and measured <= 0) then return false end
            if measured <= available or fitted <= 6 then break end
            fitted = fitted - 1
        end
        if not Font(label, fitted, title) then return false end
        T.SetTextIfChanged(label, text)
        label.statsFit = key
        return true
    end
    local function Collect(stats)
        local used = 0
        local function Add(entry)
            used = used + 1
            if model[used] ~= entry then
                model[used], dirty = entry, true
            end
        end
        for _, group in ipairs(DFRL.statsCatalog) do
            local heading
            if options[group.key] then
                for _, stat in ipairs(group.stats) do
                    local field = read[stat[1]]
                    local value = stats and field and stats[field[1]]
                    if options["statsShow" .. stat[1]] and (Number(value) or editing) then
                        if not heading then
                            if options.statsShowHeadings then Add(group) end
                            heading = true
                        end
                        Add(stat)
                        if raw[stat[1]] ~= value or formatted[stat[1]] == nil then
                            raw[stat[1]] = value
                            formatted[stat[1]] = Number(value) and field[2](value) or "--"
                        end
                    end
                end
            end
        end
        if used ~= modelCount then dirty = true end
        for index = used + 1, modelCount do
            model[index] = nil
        end
        table.setn(model, used)
        modelCount = used
    end
    local function Reflow()
        local y = options.statsShowTitle and HEADER_HEIGHT + 6 or 0
        local size, pitch = options.statsFontSize, math.max(options.statsRowHeight, options.statsFontSize + 4)
        local valueWidth = (width - 2 * INSET - 10) * 0.43
        local nameWidth = width - 2 * INSET - 10 - valueWidth
        for _, row in pairs(rows) do
            Visible(row.name, false)
            Visible(row.value, false)
        end
        for _, heading in pairs(headings) do
            Visible(heading.text, false)
            heading.line:Hide()
        end
        labels.header:SetWidth(width)
        labels.title:SetWidth(math.max(1, width - 40 - INSET))
        for index = 1, modelCount do
            local entry = model[index]
            if entry.stats then
                local heading = headings[entry.key]
                if not heading then
                    heading = { text = Label(size, style.titleColor) }
                    heading.line = T.CreateArtworkStrip(panel, "BACKGROUND", 2)
                    -- Reuse the header's complete fading gold rule, without its body or scrollwork.
                    heading.line:SetTexCoord(1 / 512, 281 / 512, 5 / 128, 10 / 128)
                    heading.line:SetAlpha(0.8)
                    headings[entry.key] = heading
                end
                y = y + 4
                heading.text:ClearAllPoints()
                heading.text:SetPoint("TOPLEFT", panel, "TOPLEFT", INSET, -y)
                heading.text:SetWidth(width - 2 * INSET)
                heading.text:SetHeight(size + 4)
                heading.line:SetPoint("TOPLEFT", panel, "TOPLEFT", INSET, -y - size - 5)
                heading.line:SetWidth(width - 2 * INSET)
                heading.line:SetHeight(3 / panel:GetEffectiveScale())
                Visible(heading.text, true)
                heading.line:Show()
                y = y + size + 11
            else
                local row = rows[entry[1]]
                if not row then
                    row = { name = Label(size, { 0.87, 0.74, 0.49 }), value = Label(size, style.bodyColor, "RIGHT") }
                    rows[entry[1]] = row
                end
                row.nameWidth, row.valueWidth = nameWidth, valueWidth
                row.name:ClearAllPoints()
                row.value:ClearAllPoints()
                row.name:SetPoint("TOPLEFT", panel, "TOPLEFT", INSET, -y)
                row.value:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -INSET, -y)
                row.name:SetWidth(nameWidth)
                row.value:SetWidth(valueWidth)
                row.name:SetHeight(pitch)
                row.value:SetHeight(pitch)
                Visible(row.name, true)
                Visible(row.value, true)
                y = y + pitch
            end
        end
        local height = math.max(HEADER_HEIGHT, y + 5)
        if not T.NearlyEqual(panel:GetHeight(), height) then panel:SetHeight(height) end
        dirty = false
    end
    local function Read()
        if type(AZS_GetPhase) ~= "function" then return end
        local ok, phase = pcall(AZS_GetPhase)
        if not ok or (phase ~= "playing" and phase ~= "paused" and phase ~= "choosing") then
            Retire()
            return
        end
        local run, stamp, zone = AZS_RUN, AZS_RUN_UPDATED, AZS_ZONE_UPDATED
        if type(run) ~= "table" or not Number(stamp) or stamp < 0 or not Number(run.t) or run.t < 0 then return end
        if zonePending or (lastZone and zone ~= lastZone) or (lastClock and run.t < lastClock) then
            Retire(zonePending)
            zonePending = nil
        end
        local stats = AZS_STATS
        if type(stats) ~= "table" or (stats == retiredStats and receipt <= retiredReceipt) then return end
        lastStats, lastZone, lastClock = stats, zone, run.t
        return stats, phase
    end
    local function Update()
        local stats, phase = Read()
        if not stats and not editing then
            Hide()
            return false
        end
        Collect(stats)
        if modelCount == 0 and not editing then
            Hide()
            return false
        end
        local scale = panel:GetEffectiveScale()
        if not Number(scale) or scale <= 0 then return true end
        Prepare()
        if dirty then Reflow() end
        local ready = true
        if options.statsShowTitle then
            labels.header:SetTextures(path, headerFiles)
            if not labels.boundIcon then
                local wanted = path .. "stats\\CharacterEquipment.blp"
                local loaded = labels.icon:SetTexture(wanted)
                labels.boundIcon = T.TextureAssigned(loaded, labels.icon:GetTexture(), wanted)
            end
            ready = labels.boundIcon
                and Fit(labels.title, locale.Text("Stats"), width - 40 - INSET, style.titleSize / SCALE, true)
            labels.header:Show()
        else
            labels.header:Hide()
        end
        Visible(labels.icon, options.statsShowTitle)
        Visible(labels.title, options.statsShowTitle)
        for index = 1, modelCount do
            local entry = model[index]
            if entry.stats then
                local heading = headings[entry.key]
                heading.line:SetTextures(path, headerFiles)
                for _, piece in ipairs(heading.line.pieces) do
                    if not piece.sduiStripPath then ready = false end
                end
                if not Fit(heading.text, locale.Text(entry.title), width - 2 * INSET, options.statsFontSize) then
                    ready = false
                end
            else
                local row = rows[entry[1]]
                if not Fit(row.name, locale.Text(entry[2]), row.nameWidth, options.statsFontSize) then ready = false end
                if not Fit(row.value, formatted[entry[1]] or "--", row.valueWidth, options.statsFontSize) then
                    ready = false
                end
            end
        end
        if options.statsShowTitle then
            for _, piece in ipairs(labels.header.pieces) do
                if not piece.sduiStripPath then ready = false end
            end
        end
        if not SetScreenLayer(phase == "choosing") then ready = false end
        if not shown then
            panel:Show()
            shown = true
        end
        return not ready
    end
    Tick = function()
        local now = GetTime()
        if now == pendingAt or (retryAt and now < retryAt) then return end
        pendingAt = nil
        if Update() then
            retryAt = now + 0.5
        else
            controller:SetScript("OnUpdate", nil)
        end
    end
    Sync = function()
        local active = inWorld and options.statsWindow and permitted
        if subscribed ~= active then
            subscribed = active
            if active then
                controller:RegisterEvent("CHAT_MSG_ADDON")
            else
                controller:UnregisterEvent("CHAT_MSG_ADDON")
            end
        end
        if active then
            Prime()
        else
            controller:SetScript("OnUpdate", nil)
            Hide()
            if not inWorld then
                Retire()
            elseif not options.statsWindow then
                for key in pairs(raw) do
                    raw[key], formatted[key] = nil, nil
                end
                dirty = true
            end
        end
    end
    local function Settings()
        local changed
        local function ReadOption(key)
            local value = display.Get(key)
            if options[key] ~= value then
                options[key], changed = value, true
            end
        end
        for _, key in ipairs({
            "statsWindow",
            "statsShowTitle",
            "statsShowHeadings",
            "statsFontSize",
            "statsRowHeight",
            "uiFont",
            "uiCustomFont",
            "uiFontOutline",
            "uiFontShadow",
        }) do
            ReadOption(key)
        end
        for _, group in ipairs(DFRL.statsCatalog) do
            ReadOption(group.key)
            for _, stat in ipairs(group.stats) do
                ReadOption("statsShow" .. stat[1])
            end
        end
        if changed then
            fontRevision, dirty = fontRevision + 1, true
            Sync()
        end
    end
    layout.Register("survivorStats", panel, function(frame)
        frame:ClearAllPoints()
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -(style.width + 20) / SCALE, -200 / SCALE)
    end, {
        labelAbove = true,
        edgeWidth = true,
        minWidth = 180,
        maxWidth = 600,
        onResize = function(_, nextWidth)
            if Number(nextWidth) then width = nextWidth end
            fontRevision, dirty = fontRevision + 1, true
            Prime()
        end,
        onEdit = function(active)
            editing, dirty = active and true or false, true
            Prime()
        end,
    })
    layout.ListenVisibility("survivorStats", function(value)
        permitted = value
        Sync()
    end)
    display.Listen(Settings)
    locale.Listen(function()
        for key in pairs(formatted) do
            formatted[key] = nil
        end
        fontRevision, dirty = fontRevision + 1, true
        Prime()
    end)
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        if event == "CHAT_MSG_ADDON" then
            if arg1 == "AZS" then receipt = receipt + 1 end
            if arg1 == "AZSZONE" then zonePending = receipt end
            if arg1 == "AZS" or arg1 == "AZSZONE" or arg1 == "AZSRUN" then Prime() end
        else
            inWorld = event == "PLAYER_ENTERING_WORLD"
            if not inWorld then Retire() end
            Sync()
        end
    end)
    Settings()
end)
