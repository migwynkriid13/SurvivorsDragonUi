DFRL:NewMod("PetFrames", 4, function()
    local MAX_VISIBLE, COLUMNS, COLUMN_PITCH, ROW_PITCH = 8, 2, 174, 50
    local WIDTH, HEIGHT = COLUMNS * COLUMN_PITCH, math.ceil(MAX_VISIBLE / COLUMNS) * ROW_PITCH + 18
    local path = DFRL:GetInfoOrCons("tex")
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetWidth(WIDTH)
    root:SetHeight(HEIGHT)
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
    local function Artwork(parent, file, layer)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetTexture(path .. "pets\\" .. file .. ".tga")
        texture:SetWidth(128)
        texture:SetHeight(64)
        texture:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        return texture
    end
    for index = 1, MAX_VISIBLE do
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
        Artwork(frame, "Background", "BACKGROUND")
        local row = { frame = frame, strips = {} }
        -- Legacy textures have no retail masks. Fixed one-unit cropped strips
        -- keep native square icons inside the round portrait opening.
        local radius = 17
        for part = 1, 34 do
            local top, bottom = part - 1, part
            local edge = math.max(math.abs(top - radius), math.abs(bottom - radius))
            local half = math.sqrt(math.max(0, radius * radius - edge * edge))
            if half > 0 then
                local strip = frame:CreateTexture(nil, "ARTWORK")
                strip:SetWidth(half * 2)
                strip:SetHeight(1)
                strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 24.5 - half, -5.5 - top)
                strip:SetTexCoord((radius - half) / 34, (radius + half) / 34, top / 34, bottom / 34)
                strip:Hide()
                table.insert(row.strips, strip)
            end
        end
        row.fill = frame:CreateTexture(nil, "ARTWORK")
        row.fill:SetTexture(path .. "unitframes\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana")
        row.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 40.5, -28)
        row.fill:SetHeight(7.5)
        row.fill:Hide()
        Artwork(frame, "Border", "OVERLAY")
        row.name = Label(frame, 10)
        row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 44, 0)
        row.name:SetWidth(COLUMN_PITCH - 46)
        row.name:SetHeight(14)
        row.status = Label(frame, 9)
        row.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 44, -16)
        row.status:SetWidth(70)
        row.status:SetHeight(12)
        frame:Hide()
        rows[index] = row
    end
    local overflow = Label(root, 11)
    overflow:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -HEIGHT + 18)
    overflow:SetWidth(WIDTH - 16)
    overflow:SetHeight(16)
    overflow:Hide()

    local function HideRow(row)
        row.frame:Hide()
        row.name:SetText("")
        row.status:SetText("")
        row.fill:Hide()
        for _, strip in ipairs(row.strips) do
            strip:Hide()
            strip:SetTexture(nil)
        end
        row.id, row.icon = nil, nil
    end
    local function Clear()
        if not displayed then return end
        for _, row in ipairs(rows) do
            HideRow(row)
        end
        overflow:SetText("")
        overflow:Hide()
        root:Hide()
        displayed = false
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
    local function Paint(row, entry)
        row.id = entry.id
        row.name:SetText(entry.name)
        if row.icon ~= entry.icon then
            for _, strip in ipairs(row.strips) do
                strip:SetTexture(entry.icon)
                if entry.icon then
                    strip:Show()
                else
                    strip:Hide()
                end
            end
            row.icon = entry.icon
        end
        if entry.permanent then
            row.status:SetText(DFRL.locale.Text("Permanent"))
        elseif Number(entry.remaining) and entry.remaining >= 0 then
            row.status:SetText(Time(entry.remaining))
        else
            row.status:SetText("--:--")
        end
        row.fill:Hide()
        if
            not entry.permanent
            and Number(entry.remaining)
            and entry.remaining > 0
            and Number(entry.duration)
            and entry.duration > 0
        then
            local fraction = math.min(1, entry.remaining / entry.duration)
            row.fill:SetWidth(74 * fraction)
            row.fill:SetTexCoord(0, fraction, 0, 1)
            row.fill:Show()
        end
        row.frame:Show()
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
        -- Copy only the bounded visible rows; the native list remains read-only.
        -- The native total includes overflow without allocating more widgets.
        local total, entries, seen = table.getn(list), {}, {}
        local count = math.min(MAX_VISIBLE, total)
        for index = 1, count do
            local entry = list[index]
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
            entries[index] = {
                id = entry.id,
                name = entry.name,
                icon = type(entry.icon) == "string" and entry.icon ~= "" and entry.icon or nil,
                permanent = entry.permanent == true,
                duration = entry.duration,
                remaining = entry.remaining,
            }
        end
        if count == 0 then
            Clear()
            return
        end
        for index = 1, MAX_VISIBLE do
            if entries[index] then
                Paint(rows[index], entries[index])
            else
                HideRow(rows[index])
            end
        end
        local overflowCount = total - count
        if overflowCount > 0 then
            overflow:SetText(string.format(DFRL.locale.Text("+%d more pets"), overflowCount))
            overflow:Show()
        else
            overflow:SetText("")
            overflow:Hide()
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
    end, { labelAbove = true, onReset = Clear })
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
