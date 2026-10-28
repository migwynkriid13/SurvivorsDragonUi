DFRL:NewMod("Player Auras", 2, function()
    if not Minimap or not BuffFrame then return end

    local iconSize, gap, rowGap, columns = 28, 3, 14, 6
    local flipped = DFRL.display.Get("flipBuffs")
    local inWorld, editing, age, received = true, false, 0, 0
    local observePending = false
    local width = columns * iconSize + (columns - 1) * gap
    local container = CreateFrame("Frame", "DFRL_PlayerAuras", UIParent)
    local function PlaceDefault()
        container:ClearAllPoints()
        -- Match the old position beside the minimap without following map moves.
        container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -238, -6)
    end
    PlaceDefault()
    container:SetWidth(width)
    container:SetHeight(iconSize + rowGap)

    -- Keep the native frames, buttons, and aura updates. Only their layout changes.
    local nativeFrames = { BuffFrame }
    if TemporaryEnchantFrame then table.insert(nativeFrames, TemporaryEnchantFrame) end
    for _, frame in ipairs(nativeFrames) do
        frame:SetParent(container)
        frame:SetScale(1)
    end

    local entries = {}
    local function AddButton(name)
        local button = _G[name]
        if button then
            table.insert(entries, {
                button = button,
                icon = _G[name .. "Icon"],
                border = _G[name .. "Border"],
                duration = _G[name .. "Duration"],
                count = _G[name .. "Count"],
            })
            T.RegisterTooltipIcon(button, nil, "below")
        end
    end
    -- Native indices 0-15 are helpful auras; 16-23 are harmful auras.
    for i = 0, 23 do
        AddButton("BuffButton" .. i)
    end
    AddButton("TempEnchant1")
    AddButton("TempEnchant2")

    local function PlaceNativeFrame(frame)
        local point, relative, relativePoint, x, y = frame:GetPoint(1)
        if
            frame:GetNumPoints() ~= 1
            or point ~= "TOPLEFT"
            or relative ~= container
            or relativePoint ~= "TOPLEFT"
            or x ~= 0
            or y ~= 0
        then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        end
    end

    local function SizeButton(entry)
        local button = entry.button
        button:SetScale(1)
        button:SetWidth(iconSize)
        button:SetHeight(iconSize)
        local icon = entry.icon
        if icon then
            icon:ClearAllPoints()
            if entry.timer then
                icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            else
                icon:SetAllPoints(button)
            end
        end
        local border = entry.border
        if border then
            border:ClearAllPoints()
            border:SetAllPoints(button)
        end
        local duration = entry.duration
        if duration then
            T.SetFont(duration, 9, "OUTLINE")
            duration:ClearAllPoints()
            duration:SetPoint("TOP", button, "BOTTOM", 0, -1)
            duration:SetWidth(iconSize)
            duration:SetHeight(12)
        end
        local count = entry.count
        if count then
            T.SetFont(count, 9, "OUTLINE")
            count:ClearAllPoints()
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        end
    end

    local previousRows, layoutDirty = nil, true
    local function Layout(force)
        local paint = container:IsVisible()
        if not paint and not editing then return end
        -- The native enchant update re-anchors BuffFrame even when no aura changes.
        -- Restore its container anchor each time, independently of icon reflow.
        if paint then
            for _, frame in ipairs(nativeFrames) do
                PlaceNativeFrame(frame)
            end
        end
        if not force and not layoutDirty and not editing then return end
        local slot = 0
        for _, entry in ipairs(entries) do
            if entry.button:IsShown() then
                if paint and (force or entry.slot ~= slot) then
                    SizeButton(entry)
                    entry.button:ClearAllPoints()
                    local column = math.mod(slot, columns) * (iconSize + gap)
                    local row = -math.floor(slot / columns) * (iconSize + rowGap)
                    if flipped then
                        entry.button:SetPoint("TOPLEFT", container, "TOPLEFT", column, row)
                    else
                        entry.button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -column, row)
                    end
                    entry.slot = slot
                end
                slot = slot + 1
            else
                entry.slot = nil
            end
        end
        local rows = math.max(1, math.ceil(slot / columns))
        if rows ~= previousRows then
            container:SetHeight(rows * (iconSize + rowGap))
            previousRows = rows
            DFRL.layout.Place("buffs", container)
        end
        layoutDirty = false
    end

    local timers, hovered = {}, nil
    local controller = CreateFrame("Frame")
    local blockedPacket, blockedStamp, blockedReceived
    local blockedRun, blockedRunStamp
    local phases = { playing = true, choosing = true, paused = true, victory = true }
    local Tick

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Native(getter)
        if type(getter) ~= "function" then return end
        local ok, value = pcall(getter)
        if ok then return value end
    end
    local function HideHover()
        if hovered and GameTooltip and GameTooltip:IsOwned(hovered.button) then GameTooltip:Hide() end
        hovered = nil
    end
    local function Tooltip(entry)
        if editing or not inWorld or not entry.name or not entry.button:IsVisible() or not GameTooltip then return end
        GameTooltip:SetOwner(entry.button, "ANCHOR_NONE")
        GameTooltip:ClearLines()
        GameTooltip:SetText(entry.name, 1, 0.82, 0)
        GameTooltip:AddLine(DFRL.locale.Text(entry.kind == "summon" and "Next summon" or "Cooldown"), 1, 1, 1)
        GameTooltip:AddLine(string.format(DFRL.locale.Text("Full wait: %.1f sec"), entry.wait), 1, 1, 1)
        if entry.ready then
            GameTooltip:AddLine(DFRL.locale.Text("Ready"), 0.3, 1, 0.3)
        else
            GameTooltip:AddLine(string.format(DFRL.locale.Text("Remaining: %.1f sec"), entry.remaining), 1, 1, 1)
        end
        GameTooltip:Show()
    end
    local function Timer(index)
        if timers[index] then return timers[index] end
        local button = CreateFrame("Button", nil, container)
        button:SetWidth(iconSize)
        button:SetHeight(iconSize)
        button:Hide()
        button:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        button:SetBackdropBorderColor(0.6, 0.66, 0.74, 1)
        local entry = { button = button, timer = true }
        entry.icon = button:CreateTexture(nil, "ARTWORK")
        entry.icon:SetAllPoints(button)
        entry.duration = button:CreateFontString(nil, "OVERLAY")
        SizeButton(entry)
        button:SetScript("OnEnter", function()
            if editing then return end
            hovered = entry
            Tooltip(entry)
        end)
        button:SetScript("OnLeave", HideHover)
        button:SetScript("OnShow", function() layoutDirty = true end)
        button:SetScript("OnHide", function()
            layoutDirty = true
            if hovered == entry then HideHover() end
        end)
        T.RegisterTooltipIcon(button, nil, "below")
        table.insert(timers, entry)
        table.insert(entries, entry)
        return entry
    end
    local function HideTimer(entry)
        if not entry.name and not entry.texture and not entry.button:IsShown() then return end
        entry.button:Hide()
        entry.icon:SetTexture(nil)
        T.SetTextIfChanged(entry.duration, "")
        entry.name, entry.kind, entry.wait, entry.remaining, entry.ready, entry.texture = nil, nil, nil, nil, nil, nil
        entry.durationSecond, entry.durationText = nil, nil
    end
    local function ClearTimers()
        HideHover()
        for _, entry in ipairs(timers) do
            HideTimer(entry)
        end
        Layout(false)
    end
    local function RetireTimers()
        observePending = false
        blockedPacket, blockedStamp, blockedReceived = _G.AZS_TIMERS, _G.AZS_TIMERS_UPDATED, received
        blockedRun, blockedRunStamp = _G.AZS_RUN, _G.AZS_RUN_UPDATED
        controller:SetScript("OnUpdate", nil)
        ClearTimers()
    end
    local function Icon(value)
        if type(value) ~= "string" or value == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
        if not string.find(value, "[/\\]") then return "Interface\\Icons\\" .. value end
        return value
    end
    local function Time(value)
        local seconds = math.ceil(value)
        if seconds < 60 then return tostring(seconds) end
        return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
    end
    local function SetTimerDuration(entry, remaining)
        local second = math.ceil(remaining)
        if entry.durationSecond ~= second or entry.durationText == nil then
            local text = Time(second)
            entry.durationSecond, entry.durationText = second, text
        end
        T.SetTextIfChanged(entry.duration, entry.durationText)
    end
    local function RefreshTimers()
        if not inWorld then return end
        -- Read phase before retained caches; the getter itself has no world guard.
        local phase = Native(_G.AZS_GetPhase)
        if not phases[phase] then
            RetireTimers()
            return
        end
        local packet, stamp = _G.AZS_TIMERS, _G.AZS_TIMERS_UPDATED
        if
            type(packet) ~= "table"
            or not Number(stamp)
            or not Number(_G.AZS_RUN_UPDATED)
            or (packet == blockedPacket and stamp == blockedStamp and received == blockedReceived)
            or (_G.AZS_RUN == blockedRun and _G.AZS_RUN_UPDATED == blockedRunStamp)
        then
            ClearTimers()
            return
        end
        if not container:IsVisible() then return end
        local now = Native(_G.AZS_GetRunTime)
        local list = Number(now) and now >= 0 and Native(_G.AZS_GetTimers)
        if type(list) ~= "table" then
            ClearTimers()
            return
        end
        for _, timer in ipairs(list) do
            if
                type(timer) ~= "table"
                or type(timer.name) ~= "string"
                or timer.name == ""
                or (timer.kind ~= "summon" and timer.kind ~= "cooldown")
                or not Number(timer.duration)
                or timer.duration < 0
                or not Number(timer.remaining)
                or timer.remaining < 0
                or type(timer.ready) ~= "boolean"
                or timer.ready ~= (timer.remaining == 0)
            then
                ClearTimers()
                return
            end
        end
        local count, ticking = 0, false
        -- Preserve every received effect, including distinct rows with one name.
        for index, timer in ipairs(list) do
            local entry = Timer(index)
            local texture = Icon(timer.icon)
            if entry.texture ~= texture then
                entry.icon:SetTexture(texture)
                entry.texture = texture
            end
            if entry.ready ~= timer.ready then entry.icon:SetAlpha(timer.ready and 1 or 0.65) end
            entry.name, entry.kind, entry.wait = timer.name, timer.kind, timer.duration
            entry.remaining, entry.ready = timer.remaining, timer.ready
            SetTimerDuration(entry, timer.remaining)
            if not entry.button:IsShown() then entry.button:Show() end
            ticking = ticking or not timer.ready
            count = index
        end
        for index = count + 1, table.getn(timers) do
            HideTimer(timers[index])
        end
        Layout(false)
        if hovered and GameTooltip and GameTooltip:IsOwned(hovered.button) and GameTooltip:IsShown() then
            Tooltip(hovered)
        end
        return phase == "playing" and ticking
    end
    Tick = function()
        age = age + math.max(0, tonumber(arg1) or 0)
        if age < 0.1 then return end
        age = 0
        observePending = false
        if not RefreshTimers() then controller:SetScript("OnUpdate", nil) end
    end
    local function WakeTimers(observe)
        if not inWorld then return end
        observePending = observePending or observe == true
        if not container:IsVisible() and not observePending then return end
        age = 0.1
        controller:SetScript("OnUpdate", Tick)
    end

    for _, entry in ipairs(entries) do
        HookScript(entry.button, "OnShow", function()
            layoutDirty = true
            Layout(false)
        end)
        HookScript(entry.button, "OnHide", function()
            layoutDirty = true
            Layout(false)
        end)
    end
    -- Duration settings rewrite the native second buff row and debuff anchors.
    -- Force those anchors back even when the visible buttons have not changed.
    hooksecurefunc("BuffButtons_UpdatePositions", function() Layout(true) end)
    hooksecurefunc("BuffFrame_Enchant_OnUpdate", function() Layout(false) end)
    hooksecurefunc("UIParent_ManageFramePositions", function() Layout(true) end)
    DFRL.display.Listen(function()
        local value = DFRL.display.Get("flipBuffs")
        if value == flipped then return end
        flipped = value
        Layout(true)
    end)
    Layout(true)
    -- Aura updates resize/reflow this container without replacing its own anchor.
    DFRL.layout.Register("buffs", container, PlaceDefault, {
        refreshDefault = true,
        onEdit = function(active)
            editing = active
            HideHover()
            if active then Layout(true) end
        end,
        onReset = function()
            ClearTimers()
            WakeTimers()
        end,
    })
    HookScript(container, "OnShow", function()
        Layout(true)
        WakeTimers()
    end)
    HookScript(container, "OnHide", function()
        ClearTimers()
        if not observePending then controller:SetScript("OnUpdate", nil) end
    end)
    DFRL.locale.Listen(function()
        if hovered and GameTooltip and GameTooltip:IsOwned(hovered.button) and GameTooltip:IsShown() then
            Tooltip(hovered)
        end
    end)
    for _, name in ipairs({ "CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
        controller:RegisterEvent(name)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            WakeTimers()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            RetireTimers()
        elseif arg1 == "AZSZONE" then
            RetireTimers()
            WakeTimers()
        elseif arg1 == "AZSTIMERS" then
            received = received + 1
            WakeTimers(true)
        elseif arg1 == "AZSRUN" then
            WakeTimers(true)
        end
        -- Defer getters until the native API frame has parsed the addon line.
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            RetireTimers()
            return reloadUI()
        end
    end
    WakeTimers()
end)
