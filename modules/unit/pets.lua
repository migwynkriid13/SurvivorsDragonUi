DFRL:NewMod("PetFrames", 4, function()
    local COLUMNS, COLUMN_PITCH, ROW_PITCH = 2, 174, 50
    local ICON_SIZE, ICON_RADIUS = 34, 17
    local CENTER_X, CENTER_Y = 24.5, 22.5
    local RIM_SIZE = 39
    local petIcons = {
        wolf = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
        raptor = "Interface\\Icons\\Ability_Hunter_Pet_Raptor",
    }
    local path = DFRL:GetInfoOrCons("tex")
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetWidth(COLUMNS * COLUMN_PITCH)
    root:SetHeight(ROW_PITCH)
    root:SetFrameStrata("MEDIUM")
    root:EnableMouse(false)
    root:Hide()
    local rows = {}
    local inWorld, age, displayed = true, 0, false
    local received, blockedReceived = 0, -1
    local blockedPacket, blockedStamp

    local function Number(value) return type(value) == "number" and value - value == 0 end
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
        frame:SetWidth(COLUMN_PITCH)
        frame:SetHeight(ROW_PITCH)
        frame:SetPoint(
            "TOPLEFT",
            root,
            "TOPLEFT",
            math.mod(index - 1, COLUMNS) * COLUMN_PITCH,
            -math.floor((index - 1) / COLUMNS) * ROW_PITCH
        )
        frame:EnableMouse(false)
        frame:Hide()
        local row = { frame = frame }
        row.name = Label(frame, 10)
        row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -8)
        row.name:SetWidth(COLUMN_PITCH - 50)
        row.name:SetHeight(14)
        row.status = Label(frame, 9)
        row.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -24)
        row.status:SetWidth(COLUMN_PITCH - 50)
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
        rim:SetTexture(path .. "jewelry\\Frame.tga")
        rim:SetTexCoord(106 / 1024, 178 / 1024, 56 / 256, 128 / 256)
        rim:SetWidth(RIM_SIZE)
        rim:SetHeight(RIM_SIZE)
        rim:SetPoint("CENTER", frame, "TOPLEFT", CENTER_X, -CENTER_Y)
        -- A complete alpha-edged rim avoids clipping its gold contour into
        -- hard horizontal steps or retaining pieces of the old bar borders.
        local circle = { frame = frame, strips = {} }
        circle.count = Label(frame, 10)
        circle.count:SetJustifyH("RIGHT")
        circle.count:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", CENTER_X + RIM_SIZE / 2, -CENTER_Y - RIM_SIZE / 2)
        circle.count:SetHeight(14)
        row.circle = circle
        return circle
    end
    local function SetIcon(circle, icon, scale)
        local changed = not T.NearlyEqual(circle.scale, scale)
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
        if changed or circle.icon ~= icon then
            for index, strip in ipairs(circle.strips) do
                if icon and index <= (circle.used or 0) then
                    strip:SetTexture(icon)
                    strip:Show()
                else
                    strip:Hide()
                    strip:SetTexture(nil)
                end
            end
            circle.icon = icon
        end
    end
    local function HideCircle(circle)
        if not circle.active then return end
        circle.frame:Hide()
        for _, strip in ipairs(circle.strips) do
            strip:Hide()
            strip:SetTexture(nil)
        end
        circle.count:SetText("")
        circle.icon, circle.active = nil, false
    end
    local function HideRow(row)
        if not row.active then return end
        row.frame:Hide()
        row.name:SetText("")
        row.status:SetText("")
        if row.circle then HideCircle(row.circle) end
        row.id, row.active = nil, false
    end
    local function Bounds(count)
        local width = COLUMNS * COLUMN_PITCH
        local height = math.max(ROW_PITCH, math.ceil(count / COLUMNS) * ROW_PITCH)
        if T.NearlyEqual(root:GetWidth(), width) and T.NearlyEqual(root:GetHeight(), height) then return end
        root:SetWidth(width)
        root:SetHeight(height)
        DFRL.layout.Place("petFrames")
    end
    local function Clear()
        if not displayed then return end
        for _, row in ipairs(rows) do
            HideRow(row)
        end
        root:Hide()
        displayed = false
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
    local function Paint(row, entry, scale)
        row.id = entry.id
        row.name:SetText(entry.name)
        local circle = Circle(row)
        SetIcon(circle, entry.icon, scale)
        circle.count:SetText(entry.count > 1 and ("x" .. entry.count) or "")
        if not circle.active then circle.frame:Show() end
        circle.active = true
        if entry.temporary == 0 then
            row.status:SetText("")
        elseif Number(entry.remaining) and entry.remaining >= 0 then
            row.status:SetText(Time(entry.remaining))
        else
            row.status:SetText("--:--")
        end
        if not row.active then row.frame:Show() end
        row.active = true
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
        local list = Native("AZS_GetSummons")
        if type(list) ~= "table" then
            Clear()
            return
        end
        -- Combine each supplied type key in first-arrival order, counting all
        -- members while timing only the temporary ones.
        local entries, seen, groups = {}, {}, {}
        local count = 0
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
                Clear()
                return
            end
            seen[entry.id] = true
            local key = type(entry.key) == "string" and entry.key ~= "" and entry.key
            local group = key and groups[key]
            if not group then
                count = count + 1
                group = {
                    id = entry.id,
                    name = entry.name,
                    icon = petIcons[entry.key]
                        or (type(entry.icon) == "string" and entry.icon ~= "" and entry.icon or nil),
                    temporary = 0,
                    count = 0,
                }
                entries[count] = group
                if key then groups[key] = group end
            end
            group.count = group.count + 1
            if entry.permanent ~= true then
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
        if count == 0 then
            Clear()
            return
        end
        local scale = root:GetEffectiveScale()
        if not Number(scale) or scale <= 0 then return end
        Bounds(count)
        for index = 1, count do
            Paint(Row(index), entries[index], scale)
        end
        for index = count + 1, table.getn(rows) do
            HideRow(rows[index])
        end
        root:Show()
        displayed = true
    end
    local controller = CreateFrame("Frame")
    local function Tick()
        age = age + (tonumber(arg1) or 0)
        if age < 0.1 then return end
        age = 0
        Refresh()
    end
    DFRL.layout.Register("petFrames", root, function()
        root:ClearAllPoints()
        root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -220)
    end, { labelAbove = true, refreshDefault = true, onReset = Clear })
    DFRL.locale.Listen(Refresh)
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
