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
    local debuffContainer = CreateFrame("Frame", "DFRL_PlayerDebuffs", UIParent)
    local function PlaceDebuffDefault()
        debuffContainer:ClearAllPoints()
        debuffContainer:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", 0, 0)
    end
    PlaceDebuffDefault()
    debuffContainer:SetWidth(width)
    debuffContainer:SetHeight(iconSize + rowGap)
    local buffGroup = { key = "buffs", frame = container, dirty = true }
    local debuffGroup = { key = "debuffs", frame = debuffContainer, dirty = true }
    local groups = { buffGroup, debuffGroup }

    -- Keep the native frames, buttons, and aura updates. Only their layout changes.
    local nativeFrames = { BuffFrame }
    if TemporaryEnchantFrame then table.insert(nativeFrames, TemporaryEnchantFrame) end
    for _, frame in ipairs(nativeFrames) do
        frame:SetParent(container)
        frame:SetScale(1)
    end

    local entries = {}
    local function AddButton(name, group)
        local button = _G[name]
        if button then
            if group == debuffGroup then button:SetParent(debuffContainer) end
            table.insert(entries, {
                button = button,
                group = group,
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
        AddButton("BuffButton" .. i, i < 16 and buffGroup or debuffGroup)
    end
    AddButton("TempEnchant1", buffGroup)
    AddButton("TempEnchant2", buffGroup)

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
            icon:SetAllPoints(button)
            -- Keep the icon's baked rim from showing outside the native debuff overlay.
            if entry.group == debuffGroup then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
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

    local function Layout(force)
        -- The native enchant update re-anchors BuffFrame even when no aura changes.
        -- Restore its container anchor each time, independently of icon reflow.
        if container:IsVisible() then
            for _, frame in ipairs(nativeFrames) do
                PlaceNativeFrame(frame)
            end
        end
        for _, group in ipairs(groups) do
            local paint = (force or group.dirty or editing) and group.frame:IsVisible()
            if paint or editing then
                local slot = 0
                for priority = 1, 2 do
                    for _, entry in ipairs(entries) do
                        if entry.group == group and (entry.timer == true) == (priority == 1) then
                            if entry.button:IsShown() then
                                if paint and (force or entry.slot ~= slot) then
                                    SizeButton(entry)
                                    entry.button:ClearAllPoints()
                                    local column = math.mod(slot, columns) * (iconSize + gap)
                                    local row = -math.floor(slot / columns) * (iconSize + rowGap)
                                    if flipped then
                                        entry.button:SetPoint("TOPLEFT", group.frame, "TOPLEFT", column, row)
                                    else
                                        entry.button:SetPoint("TOPRIGHT", group.frame, "TOPRIGHT", -column, row)
                                    end
                                    entry.slot = slot
                                end
                                slot = slot + 1
                            else
                                entry.slot = nil
                            end
                        end
                    end
                end
                local rows = math.max(1, math.ceil(slot / columns))
                if rows ~= group.rows then
                    group.frame:SetHeight(rows * (iconSize + rowGap))
                    group.rows = rows
                    DFRL.layout.Place(group.key, group.frame)
                    if group == buffGroup then DFRL.layout.Place("debuffs", debuffContainer) end
                end
                group.dirty = false
            end
        end
    end

    local timers, hovered = {}, nil
    local controller = CreateFrame("Frame")
    local blockedPacket, blockedStamp, blockedReceived
    local blockedRun, blockedRunStamp
    local publication = {}
    local phases = { playing = true, choosing = true, paused = true, victory = true }
    local Tick, RefreshTimers
    local timerUpdates = false

    local function SetTimerUpdates(active)
        if timerUpdates == active then return end
        controller:SetScript("OnUpdate", active and Tick or nil)
        timerUpdates = active
    end
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
        local cache = entry.tooltipCache or {}
        entry.tooltipCache = cache
        local language = DFRL.locale.code
        if cache.language ~= language then
            cache.kindText, cache.waitText, cache.readyText, cache.remainingFormat = nil, nil, nil, nil
            cache.language = language
        end
        if cache.kind ~= entry.kind or not cache.kindText then
            cache.kindText = DFRL.locale.Text(entry.kind == "summon" and "Next summon" or "Cooldown")
            cache.kind = entry.kind
        end
        if cache.wait ~= entry.wait or not cache.waitText then
            cache.waitText = string.format(DFRL.locale.Text("Full wait: %.1f sec"), entry.wait)
            cache.wait = entry.wait
        end
        GameTooltip:SetOwner(entry.button, "ANCHOR_NONE")
        GameTooltip:ClearLines()
        GameTooltip:SetText(entry.name, 1, 0.82, 0)
        GameTooltip:AddLine(cache.kindText, 1, 1, 1)
        GameTooltip:AddLine(cache.waitText, 1, 1, 1)
        if entry.ready then
            if not cache.readyText then cache.readyText = DFRL.locale.Text("Ready") end
            GameTooltip:AddLine(cache.readyText, 0.3, 1, 0.3)
        else
            if not cache.remainingFormat then cache.remainingFormat = DFRL.locale.Text("Remaining: %.1f sec") end
            GameTooltip:AddLine(string.format(cache.remainingFormat, entry.remaining), 1, 1, 1)
        end
        GameTooltip:Show()
    end
    local function Timer(index)
        if timers[index] then return timers[index] end
        local button = CreateFrame("Button", nil, container)
        button:SetWidth(iconSize)
        button:SetHeight(iconSize)
        button:Hide()
        local entry = { button = button, timer = true, group = buffGroup }
        entry.icon = button:CreateTexture(nil, "ARTWORK")
        entry.icon:SetAllPoints(button)
        -- API timers stay bright; their timing details live only in the tooltip.
        entry.icon:SetAlpha(1)
        SizeButton(entry)
        button:SetScript("OnEnter", function()
            if editing or not inWorld then return end
            hovered = entry
            if RefreshTimers(true) then SetTimerUpdates(true) end
            if hovered == entry then Tooltip(entry) end
        end)
        button:SetScript("OnLeave", HideHover)
        button:SetScript("OnShow", function() buffGroup.dirty = true end)
        button:SetScript("OnHide", function()
            buffGroup.dirty = true
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
        entry.name, entry.kind, entry.wait, entry.remaining, entry.ready, entry.texture = nil, nil, nil, nil, nil, nil
        entry.iconSource, entry.tooltipCache = nil, nil
    end
    local function ClearTimers()
        publication.packet, publication.stamp, publication.received = nil, nil, nil
        publication.phase, publication.ticking, publication.getter, publication.clock = nil, nil, nil, nil
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
        SetTimerUpdates(false)
        ClearTimers()
    end
    local function Icon(value)
        if type(value) ~= "string" or value == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
        if not string.find(value, "[/\\]") then return "Interface\\Icons\\" .. value end
        return value
    end
    RefreshTimers = function(force)
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
        local getter, clock = _G.AZS_GetTimers, _G.AZS_GetRunTime
        if type(getter) ~= "function" or type(clock) ~= "function" then
            ClearTimers()
            return
        end
        local now = Native(clock)
        if not Number(now) or now < 0 then
            ClearTimers()
            return
        end
        local ownsHover = hovered and GameTooltip and GameTooltip:IsOwned(hovered.button) and GameTooltip:IsShown()
        -- These buttons have no countdown or ready-state artwork. Reuse their
        -- copied presentation between publications; only an owned hover needs
        -- fresh native remaining time. Keep phase, receipt and clock validation.
        if
            not force
            and not ownsHover
            and publication.packet == packet
            and publication.stamp == stamp
            and publication.received == received
            and publication.phase == phase
            and publication.getter == getter
            and publication.clock == clock
        then
            return phase == "playing" and publication.ticking
        end
        local list = Native(getter)
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
            local source = type(timer.icon) == "string" and timer.icon or nil
            local texture = entry.texture
            if not texture or entry.iconSource ~= source then texture = Icon(source) end
            if entry.texture ~= texture then
                entry.icon:SetTexture(texture)
                entry.texture = texture
            end
            entry.iconSource = source
            entry.name, entry.kind, entry.wait = timer.name, timer.kind, timer.duration
            entry.remaining, entry.ready = timer.remaining, timer.ready
            if not entry.button:IsShown() then entry.button:Show() end
            ticking = ticking or not timer.ready
            count = index
        end
        for index = count + 1, table.getn(timers) do
            HideTimer(timers[index])
        end
        Layout(false)
        if not container:IsVisible() then return end
        publication.packet, publication.stamp, publication.received = packet, stamp, received
        publication.phase, publication.ticking, publication.getter, publication.clock = phase, ticking, getter, clock
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
        if not RefreshTimers() then SetTimerUpdates(false) end
    end
    local function WakeTimers(observe)
        if not inWorld then return end
        observePending = observePending or observe == true
        if not container:IsVisible() and not observePending then return end
        age = 0.1
        SetTimerUpdates(true)
    end

    local function HookGroup(group)
        -- Lua 5.0 reuses generic-for variables through the final nil result.
        -- Keep the retained callback on this call's stable group parameter.
        local function Changed()
            group.dirty = true
            Layout(false)
        end
        for _, entry in ipairs(entries) do
            if entry.group == group then
                HookScript(entry.button, "OnShow", Changed)
                HookScript(entry.button, "OnHide", Changed)
            end
        end
    end
    HookGroup(buffGroup)
    HookGroup(debuffGroup)
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
        onResize = function() DFRL.layout.Place("debuffs", debuffContainer) end,
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
    DFRL.layout.Register("debuffs", debuffContainer, PlaceDebuffDefault, {
        refreshDefault = true,
        onEdit = function(active)
            editing = active
            Layout(true)
            if not active then DFRL.layout.Place("debuffs", debuffContainer) end
        end,
    })
    HookScript(container, "OnShow", function()
        Layout(true)
        WakeTimers()
    end)
    HookScript(container, "OnHide", function()
        ClearTimers()
        if not observePending then SetTimerUpdates(false) end
    end)
    HookScript(debuffContainer, "OnShow", function() Layout(true) end)
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
