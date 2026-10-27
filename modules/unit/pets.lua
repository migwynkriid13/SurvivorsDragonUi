DFRL:NewMod("PetFrames", 4, function()
    local CELL_WIDTH, CELL_HEIGHT = 174, 46
    local ICON_SIZE, ICON_RADIUS = 34, 17
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
    local inWorld, age, displayed = true, 0, false
    local received, blockedReceived = 0, -1
    local blockedPacket, blockedStamp
    local acceptedPacket, acceptedStamp, acceptedReceived
    local entryCount, hasTemporary = 0, false
    local dirty, paintedScale = true, nil

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
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
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
        rim:SetTexCoord(576 / 1024, 648 / 1024, 56 / 256, 128 / 256)
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
        local circle = { frame = frame, portrait = portrait, strips = {} }
        circle.count = Label(frame, 10)
        circle.count:SetJustifyH("RIGHT")
        circle.count:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", CENTER_X + RIM_SIZE / 2, -CENTER_Y - RIM_SIZE / 2)
        circle.count:SetHeight(14)
        row.circle = circle
        return circle
    end
    local function SetStripIcon(circle, icon, scale)
        local changed = not T.NearlyEqual(circle.scale, scale)
        if icon and not changed and circle.icon == icon then return true end
        if changed and icon then
            -- At most one physical pixel per icon strip. The complete rim
            -- covers this clip edge without slicing the rim artwork itself.
            local parts = math.max(2, math.ceil(ICON_SIZE * scale))
            local step, used = ICON_SIZE / parts, 0
            for part = 1, parts do
                local top, bottom = (part - 1) * step, part * step
                local edge = math.max(math.abs(top - ICON_RADIUS), math.abs(bottom - ICON_RADIUS))
                local half = math.sqrt(math.max(0, ICON_RADIUS * ICON_RADIUS - edge * edge))
                if half > 0 then
                    used = used + 1
                    local strip = circle.strips[used]
                    if not strip then
                        strip = circle.frame:CreateTexture(nil, "ARTWORK")
                        table.insert(circle.strips, strip)
                    end
                    strip:ClearAllPoints()
                    strip:SetPoint("TOPLEFT", circle.frame, "TOPLEFT", CENTER_X - half, -CENTER_Y + ICON_RADIUS - top)
                    strip:SetWidth(half * 2)
                    strip:SetHeight(step)
                    strip:SetTexCoord(
                        (ICON_RADIUS - half) / ICON_SIZE,
                        (ICON_RADIUS + half) / ICON_SIZE,
                        top / ICON_SIZE,
                        bottom / ICON_SIZE
                    )
                end
            end
            circle.used, circle.scale = used, scale
        end
        local usable = true
        local stem = icon and string.gsub(icon, "%.[^%.]*$", "")
        for index, strip in ipairs(circle.strips) do
            if icon and index <= (circle.used or 0) then
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
        for index = 1, icon and (circle.used or 0) or 0 do
            local strip = circle.strips[index]
            if usable then
                if not strip:IsShown() then strip:Show() end
            elseif strip:IsShown() then
                strip:Hide()
            end
        end
        circle.icon = usable and icon or nil
        return usable
    end
    local function ClearStrips(circle)
        for _, strip in ipairs(circle.strips) do
            if strip:IsShown() then strip:Hide() end
            if strip.boundTexture then strip:SetTexture(nil) end
            strip.boundTexture = nil
        end
    end
    local function BindPortrait(portrait, icon)
        _G.SetPortraitToTexture(portrait:GetName(), icon)
        local assigned = portrait:GetTexture()
        local stem = string.gsub(icon, "%.[^%.]*$", "")
        return assigned == icon or assigned == stem
    end
    local function ClearPortrait(circle)
        circle.portrait:Hide()
        circle.portrait:SetTexture(nil)
        if circle.native then circle.icon = nil end
        circle.native = false
    end
    local function SetIcon(circle, icon, scale)
        -- The native circle is one cached image, rather than a visible region
        -- for every horizontal pixel. Scaling needs no new portrait binding.
        if icon and circle.native and circle.icon == icon then return true end
        if icon and circle.failedIcon ~= icon and type(_G.SetPortraitToTexture) == "function" then
            local ok, bound = pcall(BindPortrait, circle.portrait, icon)
            if ok and bound then
                ClearStrips(circle)
                circle.portrait:Show()
                circle.native, circle.icon, circle.failedIcon = true, icon, nil
                return true
            end
            ClearPortrait(circle)
            circle.failedIcon = icon
        end
        if circle.native then ClearPortrait(circle) end
        -- Older clients without the global keep the same clipped appearance.
        -- These regions are allocated only if the native path is unavailable.
        return SetStripIcon(circle, icon, scale)
    end
    local function HideCircle(circle)
        if not circle.active then return end
        circle.frame:Hide()
        ClearPortrait(circle)
        ClearStrips(circle)
        Text(circle.count, "")
        circle.icon, circle.active, circle.native, circle.failedIcon = nil, false, false, nil
    end
    local function HideRow(row)
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
        return rowCount, cellWidth, spacing
    end
    local function HideView()
        if not displayed then return end
        for _, row in ipairs(rows) do
            HideRow(row)
        end
        root:Hide()
        displayed = false
    end
    local function Clear()
        if not displayed and entryCount == 0 and not acceptedPacket and not dirty then return end
        HideView()
        for _, entry in ipairs(entries) do
            Wipe(entry)
        end
        Wipe(seen)
        Wipe(groups)
        entryCount, hasTemporary = 0, false
        acceptedPacket, acceptedStamp, acceptedReceived = nil, nil, nil
        dirty, paintedScale = false, nil
        Bounds(0)
    end
    local function Retire()
        blockedPacket, blockedStamp = _G.AZS_PETS, _G.AZS_PETS_UPDATED
        blockedReceived = received
        Clear()
    end
    local function Time(seconds)
        local rounded = math.ceil(seconds)
        return string.format("%d:%02d", math.floor(rounded / 60), math.mod(rounded, 60))
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
        local usable = SetIcon(circle, entry.icon, scale)
        Text(circle.count, not DFRL.display.Get("hidePetCounts") and entry.count > 1 and ("x" .. entry.count) or "")
        if not circle.active then circle.frame:Show() end
        circle.active = true
        if not showTimer then
            Text(row.status, "")
        elseif Number(entry.remaining) and entry.remaining >= 0 then
            Text(row.status, Time(entry.remaining))
        else
            Text(row.status, "--:--")
        end
        if not row.active then row.frame:Show() end
        row.active = true
        return usable
    end
    local function ReadRoster(list)
        -- Combine each supplied type key in first-arrival order, counting all
        -- members while timing only the temporary ones. Reuse our own scratch
        -- tables; never retain or change the getter's normalized rows.
        Wipe(seen)
        Wipe(groups)
        local count = 0
        hasTemporary = false
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
                group = entries[count]
                if not group then
                    group = {}
                    table.insert(entries, group)
                end
                group.id, group.name = entry.id, entry.name
                group.icon = petIcons[entry.key]
                    or (type(entry.icon) == "string" and entry.icon ~= "" and entry.icon or nil)
                group.temporary, group.count, group.remaining = 0, 0, nil
                if key then groups[key] = group end
            end
            group.count = group.count + 1
            if entry.permanent ~= true then
                hasTemporary = true
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
        for index = count + 1, table.getn(entries) do
            if entries[index].id then Wipe(entries[index]) end
        end
        entryCount = count
        return true
    end
    local function Refresh()
        if not inWorld then return end
        -- Retained roster tables are never read before the native phase gate.
        local phase = Native("AZS_GetPhase")
        if not DFRL.navigation.IsRunPhase(phase) then
            Retire()
            return
        end
        local packet, stamp = _G.AZS_PETS, _G.AZS_PETS_UPDATED
        if type(packet) ~= "table" or not Number(stamp) then
            Clear()
            return
        end
        if packet == blockedPacket and stamp == blockedStamp and received == blockedReceived then
            Clear()
            return
        end
        local changed = packet ~= acceptedPacket or stamp ~= acceptedStamp or received ~= acceptedReceived
        local ticking = hasTemporary and not DFRL.display.Get("hidePetTimers") and root:IsVisible()
        -- A static or hidden view needs no clock reads. Visible countdowns
        -- still sample the native pause-aware getter at the existing rate.
        if changed or ticking then
            dirty = true
            local list = Native("AZS_GetSummons")
            if type(list) ~= "table" or not ReadRoster(list) then
                Clear()
                return
            end
            acceptedPacket, acceptedStamp, acceptedReceived = packet, stamp, received
        end
        if entryCount == 0 then
            if dirty then
                HideView()
                Bounds(0)
                dirty, paintedScale = false, nil
            end
            return
        end
        if not displayed then root:Show() end
        displayed = true
        local scale = root:GetEffectiveScale()
        if not Number(scale) or scale <= 0 then return end
        if not dirty and T.NearlyEqual(paintedScale, scale) then return end
        local rowCount, cellWidth, spacing = Bounds(entryCount)
        -- Placing changed bounds may also apply confirmed/draft scale.
        scale = root:GetEffectiveScale()
        if not Number(scale) or scale <= 0 then return end
        if not root:IsVisible() then
            dirty, paintedScale = false, scale
            return
        end
        local perRow, extra = math.floor(entryCount / rowCount), math.mod(entryCount, rowCount)
        local column, line = 0, 0
        local retry = false
        for index = 1, entryCount do
            if not Paint(Row(index), entries[index], scale, column, line, cellWidth, spacing) then retry = true end
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
    local function Tick()
        age = age + (tonumber(arg1) or 0)
        if age < 0.1 then return end
        age = 0
        Refresh()
    end
    root:SetScript("OnShow", function()
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
    DFRL.locale.Listen(function()
        acceptedPacket = nil
        dirty, age = true, 0.1
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
            controller:SetScript("OnUpdate", Tick)
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Retire()
        elseif arg1 == "AZSZONE" then
            Retire()
            age = 0.1
        elseif arg1 == "AZSPETS" then
            received = received + 1
            age = 0.1
        elseif arg1 == "AZSRUN" then
            age = 0.1
        end
        -- Native packet parsing finishes before the next OnUpdate reads getters.
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Retire()
            return reloadUI()
        end
    end
    controller:SetScript("OnUpdate", Tick)
end)
