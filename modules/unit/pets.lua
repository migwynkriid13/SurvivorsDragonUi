DFRL:NewMod("PetFrames", 4, function()
    local CELL_WIDTH, CELL_HEIGHT = 174, 46
    local ICON_SIZE = 34
    local CENTER_X, CENTER_Y = 24.5, 22.5
    local RIM_SIZE = 39
    local petIcons = {
        wolf = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
        raptor = "Interface\\Icons\\Ability_Hunter_Pet_Raptor",
    }
    local path = DFRL:GetInfoOrCons("tex")
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetWidth(CELL_WIDTH)
    root:SetHeight(CELL_HEIGHT)
    root:SetFrameStrata("MEDIUM")
    root:EnableMouse(false)
    root:Hide()
    local rows, entries, seen, groups = {}, {}, {}, {}
    local feeds = {
        {
            packetName = "AZS_PETS",
            stampName = "AZS_PETS_UPDATED",
            getter = "AZS_GetSummons",
            entries = {},
            received = 0,
            blockedReceived = -1,
            count = 0,
        },
        {
            packetName = "AZS_TOTEMS",
            stampName = "AZS_TOTEMS_UPDATED",
            getter = "AZS_GetTotems",
            entries = {},
            received = 0,
            blockedReceived = -1,
            count = 0,
        },
    }
    local inWorld, age, displayed = true, 0, false
    local choiceHidden = false
    local entryCount = 0
    local dirty, paintedScale = true, nil
    local geometry = {}
    local metadataPending, learningDeferred, SyncUpdates = false, false, nil

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Wipe(target)
        for key in pairs(target) do
            target[key] = nil
        end
    end
    local function Text(label, value)
        if label.petText == value then return end
        label:SetText(value)
        label.petText = value
    end
    local function Native(name)
        local getter = _G[name]
        if type(getter) ~= "function" then return end
        local ok, value = pcall(getter)
        if ok then return value end
    end
    local function Label(parent, size)
        local label = parent:CreateFontString(nil, "OVERLAY")
        T.SetFont(label, size, "OUTLINE")
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(1, 1, 1)
        T.SetChatShadow(label)
        return label
    end
    local function Row(index)
        if rows[index] then return rows[index] end
        local frame = CreateFrame("Frame", nil, root)
        frame:SetWidth(CELL_WIDTH)
        frame:SetHeight(CELL_HEIGHT)
        frame:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        frame:EnableMouse(false)
        frame:Hide()
        local row = { frame = frame, index = index }
        row.name = Label(frame, 10)
        row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -8)
        row.name:SetWidth(CELL_WIDTH - 50)
        row.name:SetHeight(14)
        row.status = Label(frame, 9)
        row.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -24)
        row.status:SetWidth(CELL_WIDTH - 50)
        row.status:SetHeight(12)
        table.insert(rows, row)
        return row
    end
    local function Circle(row)
        if row.circle then return row.circle end
        local frame = CreateFrame("Frame", nil, row.frame)
        frame:SetWidth(49)
        frame:SetHeight(46)
        frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
        frame:SetFrameLevel(row.frame:GetFrameLevel() + 1)
        frame:EnableMouse(false)
        frame:Hide()
        local rim = frame:CreateTexture(nil, "OVERLAY")
        rim:SetTexture(path .. "jewelry\\Frame.blp")
        rim:SetTexCoord(129 / 512, 201 / 512, 1 / 128, 73 / 128)
        rim:SetWidth(RIM_SIZE)
        rim:SetHeight(RIM_SIZE)
        rim:SetPoint("CENTER", frame, "TOPLEFT", CENTER_X, -CENTER_Y)
        -- A complete alpha-edged rim avoids clipping its gold contour into
        -- hard horizontal steps or retaining pieces of the old bar borders.
        local portrait = frame:CreateTexture("SurvivorsDragonUiPetPortrait" .. row.index, "ARTWORK")
        portrait:SetWidth(ICON_SIZE)
        portrait:SetHeight(ICON_SIZE)
        portrait:SetPoint("CENTER", frame, "TOPLEFT", CENTER_X, -CENTER_Y)
        portrait:Hide()
        local circle = { frame = frame, image = T.NewCircularIcon(portrait, ICON_SIZE) }
        circle.count = Label(frame, 10)
        circle.count:SetJustifyH("RIGHT")
        circle.count:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", CENTER_X + RIM_SIZE / 2, -CENTER_Y - RIM_SIZE / 2)
        circle.count:SetHeight(14)
        row.circle = circle
        return circle
    end
    local function HideCircle(circle)
        if not circle.active then return end
        circle.frame:Hide()
        circle.image.Clear()
        Text(circle.count, "")
        circle.active = false
    end
    local function HideRow(row)
        row.timerSecond, row.timerText, row.countValue, row.countText = nil, nil, nil, nil
        row.paintName, row.paintIcon, row.paintCount, row.paintTemporary = nil, nil, nil, nil
        if not row.active then return end
        row.frame:Hide()
        Text(row.name, "")
        Text(row.status, "")
        if row.circle then HideCircle(row.circle) end
        row.id, row.active = nil, false
    end
    local function Bounds(count)
        local rowCount = math.min(DFRL.display.Get("petRows"), math.max(1, count))
        local columns = math.max(1, math.ceil(count / rowCount))
        local cellWidth = CELL_WIDTH
        if DFRL.display.Get("hidePetNames") then cellWidth = DFRL.display.Get("hidePetTimers") and 49 or 98 end
        local spacing = DFRL.display.Get("petSpacing")
        local width = columns * cellWidth + (columns - 1) * spacing
        local height = rowCount * CELL_HEIGHT + (rowCount - 1) * spacing
        if not T.NearlyEqual(root:GetWidth(), width) or not T.NearlyEqual(root:GetHeight(), height) then
            root:SetWidth(width)
            root:SetHeight(height)
            DFRL.layout.Place("petFrames")
        end
        return rowCount, cellWidth, spacing, width, height
    end
    local function HideView()
        if not displayed then return end
        for _, row in ipairs(rows) do
            HideRow(row)
        end
        root:Hide()
        displayed = false
    end
    local function ClearFeed(feed)
        for _, entry in ipairs(feed.entries) do
            Wipe(entry)
        end
        feed.count, feed.hasTemporary = 0, false
        feed.packet, feed.stamp, feed.acceptedReceived = nil, nil, nil
    end
    local function Clear()
        choiceHidden = false
        if not displayed and entryCount == 0 and not dirty and not feeds[1].packet and not feeds[2].packet then
            return
        end
        HideView()
        for _, feed in ipairs(feeds) do
            ClearFeed(feed)
        end
        Wipe(entries)
        Wipe(seen)
        Wipe(groups)
        entryCount = 0
        dirty, paintedScale = false, nil
        Bounds(0)
    end
    local function Retire()
        for _, feed in ipairs(feeds) do
            feed.blockedPacket, feed.blockedStamp = _G[feed.packetName], _G[feed.stampName]
            feed.blockedReceived = feed.received
        end
        Clear()
    end
    local function Time(seconds)
        local rounded = math.ceil(seconds)
        return string.format("%d:%02d", math.floor(rounded / 60), math.mod(rounded, 60))
    end
    local function TimerText(row, remaining, enabled)
        local second = enabled and Number(remaining) and remaining >= 0 and math.ceil(remaining) or nil
        local state = enabled and (second or "missing") or false
        if row.timerSecond ~= state or row.timerText == nil then
            local text = not enabled and "" or (second and Time(second) or "--:--")
            row.timerSecond, row.timerText = state, text
        end
        return row.timerText
    end
    local function CountText(row, count, enabled)
        local value = enabled and count > 1 and count or nil
        if row.countValue ~= value or row.countText == nil then
            row.countValue, row.countText = value, value and ("x" .. value) or ""
        end
        return row.countText
    end
    local function Paint(row, entry, scale, column, line, cellWidth, spacing)
        row.id = entry.id
        local x, y = column * (cellWidth + spacing), -line * (CELL_HEIGHT + spacing)
        local resized = row.width ~= cellWidth
        if row.x ~= x or row.y ~= y or resized then
            row.frame:SetWidth(cellWidth)
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", root, "TOPLEFT", x, y)
            row.x, row.y, row.width = x, y, cellWidth
        end
        local showName = not DFRL.display.Get("hidePetNames")
        local showTimer = not DFRL.display.Get("hidePetTimers") and entry.temporary > 0
        Text(row.name, showName and entry.name or "")
        if resized or row.showName ~= showName or row.showTimer ~= showTimer then
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 48, showTimer and -8 or -16)
            row.name:SetWidth(math.max(1, cellWidth - 50))
            row.status:ClearAllPoints()
            row.status:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 48, showName and -24 or -16)
            row.status:SetWidth(math.max(1, cellWidth - 50))
            row.showName, row.showTimer = showName, showTimer
        end
        local circle = Circle(row)
        local usable = circle.image.Bind(entry.icon, scale)
        Text(circle.count, CountText(row, entry.count, not DFRL.display.Get("hidePetCounts")))
        if not circle.active then circle.frame:Show() end
        circle.active = true
        Text(row.status, TimerText(row, entry.remaining, showTimer))
        if not row.active then row.frame:Show() end
        row.active = true
        row.paintName, row.paintIcon, row.paintCount, row.paintTemporary =
            entry.name, entry.icon, entry.count, entry.temporary
        return usable
    end
    local function ReadRoster(list, feed)
        -- Combine each supplied type key in first-arrival order, counting all
        -- members while timing only the temporary ones. Reuse our own scratch
        -- tables; never retain or change the getter's normalized rows.
        Wipe(seen)
        Wipe(groups)
        local roster = feed.entries
        local count = 0
        feed.hasTemporary = false
        for _, entry in ipairs(list) do
            if
                type(entry) ~= "table"
                or not Number(entry.id)
                or entry.id <= 0
                or entry.id ~= math.floor(entry.id)
                or seen[entry.id]
                or type(entry.name) ~= "string"
                or entry.name == ""
            then
                return false
            end
            seen[entry.id] = true
            local key = type(entry.key) == "string" and entry.key ~= "" and entry.key
            local group = key and groups[key]
            if not group then
                count = count + 1
                group = roster[count]
                if not group then
                    group = {}
                    table.insert(roster, group)
                end
                group.id, group.name = entry.id, entry.name
                group.icon = petIcons[entry.key]
                    or (type(entry.icon) == "string" and entry.icon ~= "" and entry.icon or nil)
                group.temporary, group.count, group.remaining = 0, 0, nil
                if key then groups[key] = group end
            end
            group.count = group.count + 1
            if entry.permanent ~= true then
                feed.hasTemporary = true
                group.temporary = group.temporary + 1
                local remaining = Number(entry.remaining) and entry.remaining >= 0 and entry.remaining or nil
                if group.temporary == 1 then
                    group.remaining = remaining
                elseif group.remaining and remaining then
                    group.remaining = math.min(group.remaining, remaining)
                else
                    group.remaining = nil
                end
            end
        end
        for index = count + 1, table.getn(roster) do
            if roster[index].id then Wipe(roster[index]) end
        end
        feed.count = count
        return true
    end
    local function ReadTotems(list, feed)
        Wipe(seen)
        local readClock = not DFRL.display.Get("hidePetTimers") and not DFRL.layout.IsHidden("petFrames")
        local clockReady
        local count = 0
        for _, entry in ipairs(list) do
            if
                type(entry) ~= "table"
                or type(entry.key) ~= "string"
                or entry.key == ""
                or seen[entry.key]
                or type(entry.name) ~= "string"
                or entry.name == ""
                or not Number(entry.count)
                or entry.count <= 0
                or entry.count ~= math.floor(entry.count)
                or not Number(entry.cap)
                or entry.cap < entry.count
                or entry.cap ~= math.floor(entry.cap)
            then
                return false
            end
            seen[entry.key] = true
            count = count + 1
            local group = feed.entries[count]
            if not group then
                group = {}
                table.insert(feed.entries, group)
            end
            group.id, group.name = entry.key, entry.name
            group.icon = type(entry.icon) == "string" and entry.icon ~= "" and entry.icon or nil
            group.count, group.temporary = entry.count, entry.count
            local remaining = entry.remaining
            if not readClock or clockReady == false or not Number(remaining) or remaining < 0 then remaining = nil end
            if remaining and clockReady == nil then
                local clock = Native("AZS_GetRunTime")
                clockReady = Number(clock) and clock >= 0
            end
            group.remaining = clockReady and remaining or nil
        end
        for index = count + 1, table.getn(feed.entries) do
            if feed.entries[index].id then Wipe(feed.entries[index]) end
        end
        feed.count, feed.hasTemporary = count, count > 0
        return true
    end
    local function RefreshFeed(feed)
        local packet, stamp = _G[feed.packetName], _G[feed.stampName]
        if
            type(_G[feed.getter]) ~= "function"
            or type(packet) ~= "table"
            or not Number(stamp)
            or (packet == feed.blockedPacket and stamp == feed.blockedStamp and feed.received == feed.blockedReceived)
        then
            if feed.packet or feed.count > 0 then
                ClearFeed(feed)
                dirty = true
            end
            return
        end
        local changed = packet ~= feed.packet or stamp ~= feed.stamp or feed.received ~= feed.acceptedReceived
        local ticking = feed.hasTemporary
            and not DFRL.display.Get("hidePetTimers")
            and (root:IsVisible() or (choiceHidden and not DFRL.layout.IsHidden("petFrames") and UIParent:IsVisible()))
        if not changed and not ticking then return end
        if changed then dirty = true end
        local previousCount = feed.count
        local list = Native(feed.getter)
        local reader = feed == feeds[1] and ReadRoster or ReadTotems
        if type(list) ~= "table" or not reader(list, feed) then
            ClearFeed(feed)
            dirty = true
            return true
        end
        if previousCount ~= feed.count then dirty = true end
        local source = DFRL.sct
        if changed and source and type(source.LearnSummonIcon) == "function" then
            for index = 1, feed.count do
                local entry = feed.entries[index]
                source.LearnSummonIcon(entry.name, entry.icon)
            end
        end
        feed.packet, feed.stamp, feed.acceptedReceived = packet, stamp, feed.received
        return true
    end
    local function Refresh()
        if not inWorld then return end
        -- Retained roster tables are never read before the native phase gate.
        local phase = Native("AZS_GetPhase")
        if not DFRL.navigation.IsRunPhase(phase) then
            learningDeferred = false
            Retire()
            return
        end
        if phase == "choosing" then
            choiceHidden = true
            learningDeferred = DFRL.layout.IsHidden("petFrames")
            if root:IsShown() then root:Hide() end
            return
        end
        learningDeferred = false
        local sampled = false
        for _, feed in ipairs(feeds) do
            if RefreshFeed(feed) then sampled = true end
        end
        -- Hidden receipt work only maintains the shared SCT icon metadata.
        -- Geometry, countdown painting and the steady phase reader wait for Show.
        if DFRL.layout.IsHidden("petFrames") then return end
        if dirty then
            Wipe(entries)
            entryCount = 0
            for _, feed in ipairs(feeds) do
                for index = 1, feed.count do
                    entryCount = entryCount + 1
                    entries[entryCount] = feed.entries[index]
                end
            end
        end
        if entryCount == 0 then
            if dirty then
                HideView()
                Bounds(0)
                dirty, paintedScale = false, nil
            end
            return
        end
        if not displayed or choiceHidden then
            choiceHidden = false
            root:Show()
        end
        displayed = true
        local scale = root:GetEffectiveScale()
        if not Number(scale) or scale <= 0 then return end
        local layoutChanged = dirty or not T.NearlyEqual(paintedScale, scale)
        if not layoutChanged and not sampled then return end
        -- Ticking feeds still catch native size resets at the same reader pass.
        -- Stable countdowns reuse the last layout rather than rebuilding it.
        if not layoutChanged then
            layoutChanged = not T.NearlyEqual(root:GetWidth(), geometry.width)
                or not T.NearlyEqual(root:GetHeight(), geometry.height)
        end
        local rowCount, cellWidth, spacing = geometry.rows, geometry.cellWidth, geometry.spacing
        if layoutChanged then
            rowCount, cellWidth, spacing, geometry.width, geometry.height = Bounds(entryCount)
            geometry.rows, geometry.cellWidth, geometry.spacing = rowCount, cellWidth, spacing
            -- Placing changed bounds may also apply confirmed/draft scale.
            scale = root:GetEffectiveScale()
            if not Number(scale) or scale <= 0 then return end
        end
        if not root:IsVisible() then
            dirty, paintedScale = false, scale
            return
        end
        local perRow, extra = math.floor(entryCount / rowCount), math.mod(entryCount, rowCount)
        local column, line = 0, 0
        local retry = false
        for index = 1, entryCount do
            local row, entry = rows[index], entries[index]
            if
                layoutChanged
                or not row
                or not row.active
                or row.id ~= entry.id
                or row.paintName ~= entry.name
                or row.paintIcon ~= entry.icon
                or row.paintCount ~= entry.count
                or row.paintTemporary ~= entry.temporary
            then
                if not Paint(row or Row(index), entry, scale, column, line, cellWidth, spacing) then retry = true end
            else
                Text(row.status, TimerText(row, entry.remaining, row.showTimer))
            end
            column = column + 1
            if column == perRow + (line < extra and 1 or 0) then
                column, line = 0, line + 1
            end
        end
        for index = entryCount + 1, table.getn(rows) do
            HideRow(rows[index])
        end
        dirty, paintedScale = retry, scale
    end
    local controller = CreateFrame("Frame")
    local updating
    local function Tick()
        age = age + (tonumber(arg1) or 0)
        if age < 0.1 then return end
        age = 0
        metadataPending = false
        Refresh()
        SyncUpdates()
    end
    SyncUpdates = function()
        local active = inWorld and (not DFRL.layout.IsHidden("petFrames") or metadataPending)
        if updating == active then return end
        updating = active
        controller:SetScript("OnUpdate", active and Tick or nil)
    end
    root:SetScript("OnShow", function()
        if choiceHidden then
            root:Hide()
            return
        end
        dirty, age = true, 0.1
    end)
    DFRL.layout.Register("petFrames", root, function()
        root:ClearAllPoints()
        if PlayerFrame and PlayerFrame.portrait then
            root:SetPoint("TOPLEFT", PlayerFrame.portrait, "BOTTOMLEFT", -10, -8)
        elseif PlayerFrame then
            root:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", -10, -8)
        else
            root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 2, -220)
        end
    end, { labelAbove = true, refreshDefault = true, onReset = Clear })
    DFRL.layout.ListenVisibility("petFrames", function(permitted)
        if permitted then
            for _, feed in ipairs(feeds) do
                feed.packet = nil
            end
            dirty, age = true, 0.1
        elseif choiceHidden then
            learningDeferred = true
        end
        SyncUpdates()
    end)
    DFRL.locale.Listen(function()
        for _, feed in ipairs(feeds) do
            feed.packet = nil
        end
        dirty, age = true, 0.1
        metadataPending = true
        SyncUpdates()
    end)
    DFRL.display.Listen(function()
        dirty, age = true, 0.1
    end)
    for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "CHAT_MSG_ADDON" }) do
        controller:RegisterEvent(name)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld, age = true, 0.1
            metadataPending = true
            SyncUpdates()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            metadataPending, learningDeferred = false, false
            SyncUpdates()
            Retire()
        elseif arg1 == "AZSZONE" then
            Retire()
            metadataPending, learningDeferred = false, false
            age = 0.1
            SyncUpdates()
        elseif arg1 == "AZSPETS" or arg1 == "AZSTOTEMS" then
            local feed = arg1 == "AZSPETS" and feeds[1] or feeds[2]
            feed.received = feed.received + 1
            metadataPending = true
            age = 0.1
            SyncUpdates()
        elseif arg1 == "AZSRUN" then
            if learningDeferred then metadataPending = true end
            age = 0.1
            SyncUpdates()
        end
        -- Native packet parsing finishes before the next OnUpdate reads getters.
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            metadataPending, learningDeferred = false, false
            SyncUpdates()
            Retire()
            return reloadUI()
        end
    end
    SyncUpdates()
end)
