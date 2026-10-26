-- The War Within artwork: Karl-HeinzSchneider, MIT; shipped notice in
-- media/tex/meter/LICENSE.txt. Pinned source: third_party/DetailsTWW-ARTWORK.md.
DFRL:NewMod("DamageMeter", 7, function()
    local WIDTH, HEADER, ROW_HEIGHT, VISIBLE, FOOTER = 400, 32, 32, 6, 32
    local path = DFRL:GetInfoOrCons("tex")
    local native = T.NewHudOwner("meter", "hudMeter")
    local modes = {
        { getter = "AZS_GetMeter", prefix = "AZSMETER", title = "Damage Done", rate = "DPS" },
        { getter = "AZS_GetHealing", prefix = "AZSHEAL", title = "Healing Done", rate = "HPS" },
        { getter = "AZS_GetBossMeter", prefix = "AZSBOSSDMG", title = "Boss Damage", rate = "DPS" },
    }
    local phases = { playing = true, choosing = true, paused = true, dead = true, victory = true }
    local mode, offset, age = 1, 0, 0.2
    local inWorld, editing, ready, faulted = true, false, true, false
    local rows, received, blocked = {}, {}, {}
    local snapshot = { rows = {}, count = 0 }
    local hovered
    local root = CreateFrame("Frame", "DFRL_DamageMeter", UIParent)
    root:SetWidth(WIDTH)
    root:SetHeight(HEADER + VISIBLE * ROW_HEIGHT + FOOTER)
    root:SetFrameStrata("MEDIUM")
    root:EnableMouse(true)
    root:EnableMouseWheel(true)
    root:Hide()

    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end
    local function Compact(value)
        if value >= 1000000000 then return string.format("%.1fB", value / 1000000000) end
        if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
        if value >= 1000 then return string.format("%.1fK", value / 1000) end
        return string.format("%.0f", value)
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
    local function HideTooltip()
        if hovered and GameTooltip and GameTooltip:IsOwned(hovered) then GameTooltip:Hide() end
        hovered = nil
    end
    local function ShowRowTooltip(row)
        if editing or not row.entry or not GameTooltip then return end
        HideTooltip()
        hovered = row
        GameTooltip:SetOwner(row, "ANCHOR_NONE")
        GameTooltip:SetText(row.entry.name)
        GameTooltip:AddDoubleLine(DFRL.locale.Text(modes[mode].title), string.format("%.0f", row.entry.dmg))
        GameTooltip:AddDoubleLine(DFRL.locale.Text(modes[mode].rate), string.format("%.1f", row.entry.dps))
        GameTooltip:AddDoubleLine(DFRL.locale.Text("Share"), string.format("%.1f%%", row.entry.share * 100))
        GameTooltip:Show()
    end
    local header = CreateFrame("Button", nil, root)
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    header:SetWidth(WIDTH)
    header:SetHeight(HEADER)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local artwork = Texture(header, "Header", "BACKGROUND")
    artwork:SetAllPoints(header)
    local title = Label(header, 13)
    title:SetPoint("LEFT", header, "LEFT", 14, 1)
    title:SetWidth(WIDTH - 52)
    title:SetHeight(20)
    title:SetTextColor(1, 0.82, 0)
    local nextView = Label(header, 14, "RIGHT")
    nextView:SetPoint("RIGHT", header, "RIGHT", -12, 1)
    nextView:SetWidth(20)
    nextView:SetHeight(20)
    nextView:SetText(">")
    nextView:SetTextColor(1, 0.82, 0)

    local total = Label(root, 11)
    total:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 12, 5)
    total:SetWidth(WIDTH - 24)
    total:SetHeight(22)
    total:SetTextColor(0.95, 0.83, 0.57)
    local status = Label(root, 12, "CENTER")
    status:SetPoint("TOPLEFT", root, "TOPLEFT", 12, -HEADER - 12)
    status:SetWidth(WIDTH - 24)
    status:SetHeight(64)

    for index = 1, VISIBLE do
        local row = CreateFrame("Frame", nil, root)
        row:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -HEADER - (index - 1) * ROW_HEIGHT)
        row:SetWidth(WIDTH - 16)
        row:SetHeight(ROW_HEIGHT)
        row:EnableMouse(true)
        local background = Texture(row, "Background", "BACKGROUND")
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
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon:SetWidth(26)
        row.icon:SetHeight(26)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.rim = row:CreateTexture(nil, "OVERLAY")
        if row.rim:SetTexture(path .. "character\\QualityBorder.blp") == false then ready = false end
        row.rim:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
        row.rim:SetWidth(31)
        row.rim:SetHeight(31)
        row.rim:SetVertexColor(1, 0.82, 0.35)
        row:SetScript("OnEnter", function() ShowRowTooltip(row) end)
        row:SetScript("OnLeave", HideTooltip)
        row:SetScript("OnHide", HideTooltip)
        row:Hide()
        rows[index] = row
    end
    local function ClearRows()
        HideTooltip()
        for _, row in ipairs(rows) do
            if row.iconPath then row.icon:SetTexture(nil) end
            row.entry, row.iconPath, row.displayName = nil, nil, nil
            if row:IsShown() then row:Hide() end
        end
        snapshot.count = 0
        for key in pairs(snapshot.rows) do
            snapshot.rows[key] = nil
        end
        table.setn(snapshot.rows, 0)
    end
    local function Release()
        ClearRows()
        native.Release()
    end
    local function Invalidate()
        Release()
        for index = 1, table.getn(modes) do
            received[index], blocked[index] = nil, true
        end
        offset = 0
        root:Hide()
    end
    local function Read()
        local selected = modes[mode]
        local getter = _G[selected.getter]
        if type(getter) ~= "function" then return false, "Meter data is unavailable." end
        if blocked[mode] and not received[mode] then return false, "Waiting for meter data." end
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
        if count == 0 and not received[mode] then return false, "Waiting for meter data." end
        received[mode], blocked[mode] = true, nil
        for index, entry in ipairs(source) do
            local copy = snapshot.rows[index] or {}
            copy.name, copy.dmg, copy.dps, copy.share, copy.proc =
                entry.name, entry.dmg, entry.dps, entry.share, entry.proc
            snapshot.rows[index] = copy
        end
        for index = count + 1, snapshot.count do
            snapshot.rows[index] = nil
        end
        table.setn(snapshot.rows, count)
        snapshot.count, snapshot.total, snapshot.rate = count, amount, rate
        return true
    end
    local function Draw()
        offset = math.max(0, math.min(offset, snapshot.count - VISIBLE))
        local maximum = snapshot.rows[1] and snapshot.rows[1].dmg or 0
        local classColor = T.GetPlayerClassColor() or { 0.8, 0.63, 0.28 }
        for index, row in ipairs(rows) do
            local entry = snapshot.rows[index + offset]
            if entry then
                if hovered == row and row.displayName ~= entry.name then HideTooltip() end
                row.entry = entry
                row.displayName = entry.name
                T.SetTextIfChanged(row.name, tostring(index + offset) .. ". " .. entry.name)
                local values = Compact(entry.dmg)
                    .. "   "
                    .. Compact(entry.dps)
                    .. "   "
                    .. string.format("%.1f%%", entry.share * 100)
                T.SetTextIfChanged(row.value, values)
                local fraction = maximum > 0 and math.min(1, entry.dmg / maximum) or 0
                if row.fraction ~= fraction then row.bar:SetValue(fraction) end
                row.fraction = fraction
                local r, g, b = unpack(classColor)
                if entry.proc == 1 then
                    r, g, b = 0.25, 0.58, 1
                end
                if row.red ~= r or row.green ~= g or row.blue ~= b then row.bar:SetStatusBarColor(r, g, b) end
                row.red, row.green, row.blue = r, g, b
                local resolver = DFRL.sct and DFRL.sct.GetSourceIcon
                local icon = type(resolver) == "function" and resolver(entry.name) or nil
                if icon ~= row.iconPath then
                    row.iconPath = nil
                    if row.icon:SetTexture(icon) ~= false then row.iconPath = icon end
                end
                if icon and row.iconPath then
                    if not row.icon:IsShown() then row.icon:Show() end
                    if not row.rim:IsShown() then row.rim:Show() end
                else
                    if row.icon:IsShown() then row.icon:Hide() end
                    if row.rim:IsShown() then row.rim:Hide() end
                end
                if not row:IsShown() then row:Show() end
                if hovered == row then ShowRowTooltip(row) end
            else
                row.entry = nil
                if row:IsShown() then row:Hide() end
            end
        end
        T.SetTextIfChanged(
            total,
            DFRL.locale.Text("Total")
                .. ": "
                .. Compact(snapshot.total)
                .. "   "
                .. DFRL.locale.Text(modes[mode].rate)
                .. ": "
                .. Compact(snapshot.rate)
        )
        if snapshot.count == 0 then
            T.SetTextIfChanged(status, DFRL.locale.Text("No meter entries yet."))
            if not status:IsShown() then status:Show() end
        else
            if status:IsShown() then status:Hide() end
        end
    end
    local function Refresh()
        if not inWorld or not ready or faulted then
            Release()
            root:Hide()
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
            root:Hide()
            return
        end
        T.SetTextIfChanged(title, DFRL.locale.Text(modes[mode].title))
        local valid, message = Read()
        if valid then
            Draw()
            native.Acquire()
        else
            Release()
            T.SetTextIfChanged(total, "")
            T.SetTextIfChanged(status, DFRL.locale.Text(message))
            if not status:IsShown() then status:Show() end
        end
        if not root:IsShown() then root:Show() end
    end
    header:SetScript("OnClick", function()
        if editing then return end
        HideTooltip()
        local direction = arg1 == "RightButton" and -1 or 1
        for step = 1, table.getn(modes) do
            local candidate = math.mod(mode - 1 + direction * step + table.getn(modes), table.getn(modes)) + 1
            if type(_G[modes[candidate].getter]) == "function" then
                mode, offset, age = candidate, 0, 0.2
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
        GameTooltip:SetText(DFRL.locale.Text("Click to change meter view. Scroll to see more sources."))
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", HideTooltip)
    root:SetScript("OnHide", HideTooltip)
    root:SetScript("OnMouseWheel", function()
        if editing then return end
        HideTooltip()
        offset = math.max(0, math.min(offset - (tonumber(arg1) or 0), snapshot.count - VISIBLE))
        age = 0.2
    end)
    DFRL.layout.Register("damageMeter", root, function()
        root:ClearAllPoints()
        root:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 100)
    end, {
        labelAbove = true,
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
            Release()
        end,
    })
    DFRL.locale.Listen(function()
        HideTooltip()
        age = 0.2
    end)
    local controller = CreateFrame("Frame")
    local function Tick()
        if not inWorld then return end
        age = age + (tonumber(arg1) or 0)
        if age < 0.2 then return end
        age = 0
        local ok, message = pcall(Refresh)
        if not ok then
            faulted = true
            Release()
            root:Hide()
            geterrorhandler()(message)
        end
    end
    for _, name in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_LOGOUT",
        "CHAT_MSG_ADDON",
        "CVAR_UPDATE",
    }) do
        controller:RegisterEvent(name)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld, faulted, age = true, false, 0.2
            controller:SetScript("OnUpdate", Tick)
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Invalidate()
        elseif event == "CVAR_UPDATE" then
            if native.Observe(arg1) then age = 0.2 end
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 == "AZSZONE" then
                Invalidate()
            else
                for index, entry in ipairs(modes) do
                    if arg1 == entry.prefix then received[index] = true end
                end
            end
            -- The five-Hz read coalesces packets and runs after native parsing.
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Invalidate()
            return reloadUI()
        end
    end
    controller:SetScript("OnUpdate", Tick)
end)
