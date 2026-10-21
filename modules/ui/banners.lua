-- Native translated banner events, attached to the run timer without saved state.
-- Public API and pinned executable evidence: docs/RUN-BANNERS.md.
DFRL:NewMod("RunBanners", 4, function()
    local banners = {}
    local WIDTH, RESERVED_HEIGHT, GAP = 420, 96, 6
    local MAX_VISIBLE, MAX_QUEUE, MAX_SEEN = 3, 32, 128
    local FADE_IN, HOLD, FADE_OUT = 0.15, 3.5, 0.6
    local native = T.NewHudOwner("banners", "hudBanners")
    local controller = CreateFrame("Frame")
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetWidth(WIDTH)
    root:SetHeight(RESERVED_HEIGHT)
    root:EnableMouse(false)
    root:Hide()
    local pool, visible, queue, seen, seenOrder = {}, {}, {}, {}, {}
    local visibleCount, queueCount, seenCount, sequence = 0, 0, 0, 0
    local inWorld, clockReady, attached, active, faulted = true, false, false, false, false
    local registered, unregister, changedBounds, delivering
    local age, painted, stackHeight = 0, 0, 0
    local OnBanner, Refresh, Update

    for index = 1, MAX_VISIBLE do
        local label = root:CreateFontString(nil, "OVERLAY")
        T.SetChatFont(label)
        T.SetChatShadow(label)
        label:SetWidth(WIDTH)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("TOP")
        label:SetText("")
        label:Hide()
        local face, size = label:GetFont()
        if type(face) ~= "string" or face == "" or size ~= 12 then return end
        pool[index] = { label = label }
    end

    local function Supported()
        return type(AZS_RegisterBannerHandler) == "function"
            and type(AZS_UnregisterBannerHandler) == "function"
            and type(AZS_IsHudShown) == "function"
            and type(AZS_SetHudShown) == "function"
    end
    function banners.GetBounds()
        if not Supported() then return 0, 0 end
        return WIDTH, GAP + math.max(RESERVED_HEIGHT, stackHeight)
    end
    local function Reflow()
        table.sort(visible, function(a, b) return a.sequence < b.sequence end)
        local height = 0
        for index = 1, visibleCount do
            local row = visible[index]
            row.label:ClearAllPoints()
            row.label:SetPoint("TOP", root, "TOP", 0, -height)
            height = height + math.max(16, row.label:GetHeight()) + 4
        end
        local previous = stackHeight
        stackHeight = math.max(0, height - 4)
        root:SetHeight(math.max(RESERVED_HEIGHT, stackHeight))
        if previous ~= stackHeight and changedBounds then changedBounds() end
    end
    function banners.Clear()
        for index = 1, MAX_VISIBLE do
            local row = pool[index]
            row.label:Hide()
            row.label:SetText("")
            row.entry, row.sequence, row.started = nil, nil, nil
        end
        for index = 1, visibleCount do visible[index] = nil end
        for index = 1, queueCount do queue[index] = nil end
        for index = 1, seenCount do
            seen[seenOrder[index]] = nil
            seenOrder[index] = nil
        end
        visibleCount, queueCount, seenCount = 0, 0, 0
        table.setn(visible, 0)
        table.setn(queue, 0)
        table.setn(seenOrder, 0)
        Reflow()
    end
    local function Release()
        active = false
        root:Hide()
        if registered and not delivering then
            pcall(unregister, OnBanner)
            registered, unregister = nil, nil
        end
        -- A broken view must never prevent restoring the native preference.
        pcall(banners.Clear)
        native.Release()
    end
    local function Failed(message)
        faulted = true
        Release()
        if not delivering and geterrorhandler then geterrorhandler()(message) end
    end
    local function Push(entry, now)
        for index = 1, MAX_VISIBLE do
            local row = pool[index]
            if not row.entry then
                row.entry, row.sequence, row.started = entry, entry.sequence, now
                row.label:SetText(entry.text)
                if entry.boss then
                    row.label:SetTextColor(1, 0.25, 0.18)
                else
                    row.label:SetTextColor(1, 0.82, 0)
                end
                row.label:SetAlpha(0)
                row.label:Show()
                visibleCount = visibleCount + 1
                visible[visibleCount] = row
                table.setn(visible, visibleCount)
                Reflow()
                return true
            end
        end
        return false
    end
    local function Receive(entry)
        if not active or not inWorld or not clockReady or type(entry) ~= "table" then return end
        local id = entry.id
        if type(id) ~= "number" or id < 0 or id - id ~= 0 or id ~= math.floor(id) or seen[id] then return end
        if type(entry.text) ~= "string" or entry.text == "" then return end
        if seenCount == MAX_SEEN then
            seen[table.remove(seenOrder, 1)] = nil
            seenCount = seenCount - 1
        end
        seenCount = seenCount + 1
        seenOrder[seenCount], seen[id] = id, true
        table.setn(seenOrder, seenCount)
        sequence = sequence + 1
        -- The API shares its original table with history and every handler.
        -- Copy it; identical text with different native ids remains distinct.
        local copy = { id = id, kind = entry.kind, text = entry.text, boss = entry.boss == true, sequence = sequence }
        if queueCount == 0 and Push(copy, GetTime()) then return end
        if queueCount == MAX_QUEUE then
            table.remove(queue, 1)
            queueCount = queueCount - 1
        end
        queueCount = queueCount + 1
        queue[queueCount] = copy
        table.setn(queue, queueCount)
    end
    OnBanner = function(entry)
        delivering = true
        local ok, message = pcall(Receive, entry)
        if not ok then Failed(message) end
        delivering = false
        if not ok and geterrorhandler then geterrorhandler()(message) end
    end
    Refresh = function()
        if not inWorld or not clockReady or not attached or faulted or not Supported() then
            if active or registered or native.IsCaptured() then Release() end
            return false
        end
        if registered and (registered ~= AZS_RegisterBannerHandler or unregister ~= AZS_UnregisterBannerHandler) then
            Release()
        end
        if not registered then
            local ok = pcall(AZS_RegisterBannerHandler, OnBanner)
            if not ok then return false end
            registered, unregister = AZS_RegisterBannerHandler, AZS_UnregisterBannerHandler
        end
        -- Registration and usable labels must precede native suppression.
        if not native.Acquire() then
            Release()
            return false
        end
        active = true
        root:Show()
        return true
    end
    local function Paint(now)
        local index, moved = 1, false
        while index <= visibleCount do
            local row = visible[index]
            local elapsed = now - row.started
            if elapsed >= HOLD + FADE_OUT then
                row.label:Hide()
                row.label:SetText("")
                row.entry, row.sequence, row.started = nil, nil, nil
                table.remove(visible, index)
                visibleCount = visibleCount - 1
                table.setn(visible, visibleCount)
                moved = true
            else
                row.label:SetAlpha(math.min(1, elapsed / FADE_IN, (HOLD + FADE_OUT - elapsed) / FADE_OUT))
                index = index + 1
            end
        end
        if moved then Reflow() end
        while queueCount > 0 and visibleCount < MAX_VISIBLE do
            if not Push(queue[1], now) then break end
            table.remove(queue, 1)
            queueCount = queueCount - 1
            table.setn(queue, queueCount)
        end
    end
    Update = function()
        local elapsed = tonumber(arg1) or 0
        age, painted = age + elapsed, painted + elapsed
        if age >= 0.2 then
            age = 0
            Refresh()
        end
        if not active or visibleCount == 0 or painted < 1 / 30 then return end
        painted = 0
        Paint(GetTime())
    end
    local function Tick()
        local ok, message = pcall(Update)
        if not ok then Failed(message) end
    end
    function banners.Attach(frame, onBoundsChanged)
        if attached then return end
        root:SetParent(frame)
        root:SetPoint("TOP", frame, "BOTTOM", 0, -GAP)
        root:SetFrameStrata(frame:GetFrameStrata())
        root:SetFrameLevel(frame:GetFrameLevel() + 2)
        changedBounds, attached = onBoundsChanged, true
        controller:SetScript("OnUpdate", inWorld and Tick or nil)
        if changedBounds then changedBounds() end
        Refresh()
    end
    function banners.SetClockReady(value)
        if clockReady == value then return end
        clockReady = value == true
        Refresh()
    end
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("CHAT_MSG_ADDON")
    controller:RegisterEvent("CVAR_UPDATE")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            age, painted = 0, 0
            controller:SetScript("OnUpdate", attached and Tick or nil)
            Refresh()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld, clockReady = false, false
            controller:SetScript("OnUpdate", nil)
            Release()
        elseif event == "CHAT_MSG_ADDON" then
            if arg1 == "AZSZONE" then banners.Clear() end
        elseif native.Observe(arg1) then
            Refresh()
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld, clockReady = false, false
            controller:SetScript("OnUpdate", nil)
            Release()
            return reloadUI()
        end
    end
    DFRL.banners = banners
end)
