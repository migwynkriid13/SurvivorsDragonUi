-- Native translated notices with independent, geometry-only Layout controls.
-- Public API and pinned executable evidence: docs/RUN-BANNERS.md.
DFRL:NewMod("RunBanners", 4, function()
    local banners = {}
    local WIDTH, MIN_HEIGHT = 420, 16
    local MAX_VISIBLE, MAX_QUEUE, MAX_SEEN = 3, 32, 128
    local FADE_IN, HOLD, FADE_OUT = 0.15, 3.5, 0.6
    local GUARDIAN_SLAIN =
        "%s is slain! Its lair yields treasure and its strength, and the other guardians grow stronger."
    local DOT_STACKS = "Your damage over time spells now stack {n} times on one enemy."
    local native = T.NewHudOwner("banners", "hudBanners")
    local controller = CreateFrame("Frame")
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetWidth(WIDTH)
    root:SetHeight(MIN_HEIGHT)
    root:SetFrameStrata("HIGH")
    root:EnableMouse(false)
    root:Hide()
    local pool, visible, queue, seen, seenOrder = {}, {}, {}, {}, {}
    local visibleCount, queueCount, seenCount, sequence = 0, 0, 0, 0
    local inWorld, active, faulted = true, false, false
    local registered, unregister, delivering
    local legacyFrame, legacyAdd, legacyHook
    local errorFrame, errorAdd, errorHook
    local pendingErrors, errorCount = {}, 0
    local MAX_ERRORS = 32
    local age, painted = 0, 0
    local OnBanner, Refresh, Update
    local companions = {}

    -- These two legacy surfaces accompany official boss/guardian publications.
    -- Select their display source by exact native template, never by an entity
    -- name, inferred encounter state, approximate wording or a timing window.
    for _, source in ipairs({
        "%s enters the battlefield!",
        GUARDIAN_SLAIN,
    }) do
        companions[source] = true
        for _, catalog in pairs(DFRL.locale.data) do
            local text = catalog.native[source]
            if text then companions[text] = true end
        end
    end

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
    function banners.IsActive() return active and inWorld and DFRL.display.Get("customBanners") end
    local function Reflow()
        table.sort(visible, function(a, b) return a.sequence < b.sequence end)
        local height = 0
        for index = 1, visibleCount do
            local row = visible[index]
            row.label:ClearAllPoints()
            row.label:SetPoint("TOP", root, "TOP", 0, -height)
            height = height + math.max(16, row.label:GetHeight()) + 4
        end
        root:SetHeight(math.max(MIN_HEIGHT, height - 4))
        DFRL.layout.Place("banners")
    end
    function banners.Clear()
        pendingErrors, errorCount = {}, 0
        for index = 1, MAX_VISIBLE do
            local row = pool[index]
            row.label:Hide()
            row.label:SetText("")
            row.entry, row.sequence, row.started = nil, nil, nil
        end
        for index = 1, visibleCount do
            visible[index] = nil
        end
        for index = 1, queueCount do
            queue[index] = nil
        end
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
    local function ReleaseLegacy()
        if legacyFrame and legacyFrame.AddMessage == legacyHook then legacyFrame.AddMessage = legacyAdd end
        legacyFrame, legacyAdd, legacyHook = nil, nil, nil
    end
    local function PlainText(text)
        if type(text) ~= "string" or string.find(text, "|Huierror", 1, true) then return end
        text = string.gsub(text, "|H.-|h(.-)|h", "%1")
        text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        text = string.gsub(text, "|r", "")
        text = string.gsub(text, "^[ \t]+", "")
        return (string.gsub(text, "[ \t]+$", ""))
    end
    local function HasBanner(text)
        local plain = PlainText(text)
        if not plain or plain == "" then return false end
        local function Matches(entry)
            return entry and (PlainText(entry.text) == plain or PlainText(entry.originalText) == plain)
        end
        for index = 1, visibleCount do
            if Matches(visible[index].entry) then return true end
        end
        for index = 1, queueCount do
            if Matches(queue[index]) then return true end
        end
        return false
    end
    local function ShowError(entry)
        return entry.add(entry.owner, entry.text, entry.r, entry.g, entry.b, entry.id, entry.hold)
    end
    local function FlushErrors(force)
        if errorCount == 0 then return end
        local pending, count = pendingErrors, errorCount
        pendingErrors, errorCount = {}, 0
        for index = 1, count do
            local entry = pending[index]
            if force or not HasBanner(entry.text) then ShowError(entry) end
        end
    end
    local function ReleaseErrors()
        if errorFrame and errorFrame.AddMessage == errorHook then errorFrame.AddMessage = errorAdd end
        errorFrame, errorAdd, errorHook = nil, nil, nil
        FlushErrors(true)
    end
    local function Release()
        active = false
        root:Hide()
        ReleaseLegacy()
        pcall(ReleaseErrors)
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
    local function Enqueue(text, boss, kind, id, originalText)
        sequence = sequence + 1
        local copy = {
            id = id,
            kind = kind,
            text = text,
            originalText = originalText,
            boss = boss,
            sequence = sequence,
        }
        if queueCount == 0 and Push(copy, GetTime()) then return end
        if queueCount == MAX_QUEUE then
            table.remove(queue, 1)
            queueCount = queueCount - 1
        end
        queueCount = queueCount + 1
        queue[queueCount] = copy
        table.setn(queue, queueCount)
    end
    local function Receive(entry)
        if not banners.IsActive() or type(entry) ~= "table" then return end
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
        -- Copy the API table; distinct ids with equal text remain distinct.
        local text = entry.text
        if entry.kind == "guardian" and type(entry.name) == "string" and entry.name ~= "" then
            local ok, full = pcall(string.format, DFRL.locale.Native(GUARDIAN_SLAIN), entry.name)
            if ok then text = full end
        end
        Enqueue(text, entry.boss == true, entry.kind, id, entry.text)
    end
    function banners.RedirectChat(source, text, eventName, speaker, message)
        if not banners.IsActive() or not source or type(text) ~= "string" then return false end
        if eventName == "CHAT_MSG_RAID_BOSS_EMOTE" then
            -- The owned legacy bridge already forwards this whole native
            -- event category to Banners. Suppress its regular-chat copy
            -- regardless of wording, boss, mechanic or selected language.
            return legacyFrame ~= nil and legacyHook ~= nil and legacyFrame.AddMessage == legacyHook
        end
        if eventName and eventName ~= "CHAT_MSG_SYSTEM" then return false end
        local chat = DFRL.CleanerChat
        if not chat or type(chat.FirstDelivery) ~= "function" then return false end
        local plain = PlainText(text)
        if not plain then return false end
        local fields = DFRL.locale.Match(DOT_STACKS, plain)
        if not fields or type(fields.n) ~= "string" or not string.find(fields.n, "^%d+$") then return false end
        local function Redirect()
            if chat.FirstDelivery(source, plain, eventName, speaker, message, "chat-banners") then
                -- Forward this received display call, without inventing a
                -- gameplay event or replaying earlier chat history.
                Enqueue(plain, false, "chat")
            end
        end
        local ok, failure = pcall(Redirect)
        if not ok then
            Failed(failure)
            return false
        end
        return true
    end
    local function RedirectLegacy()
        local frame, chat = RaidBossEmoteFrame, DFRL.CleanerChat
        if not frame or type(frame.AddMessage) ~= "function" or not chat or type(chat.FirstDelivery) ~= "function" then
            return
        end
        if legacyFrame == frame then return end
        ReleaseLegacy()
        local original, hook = frame.AddMessage
        local function ReceiveLegacy(source, text, eventName, speaker, message)
            if eventName == "CHAT_MSG_RAID_BOSS_EMOTE" then
                if
                    companions[message] or not chat.FirstDelivery(source, text, eventName, speaker, message, "banners")
                then
                    return
                end
            end
            -- Forward the already formatted native display call. Do not
            -- reconstruct a notice from zone, chat history or gameplay.
            Enqueue(text, false, "legacy")
        end
        hook = function(owner, text, r, g, b, id, addToStart)
            if banners.IsActive() and legacyHook == hook and type(text) == "string" and text ~= "" then
                local ok, message = pcall(ReceiveLegacy, this or owner, text, event, arg2, arg1)
                if ok then return end
                Failed(message)
            end
            return original(owner, text, r, g, b, id, addToStart)
        end
        legacyFrame, legacyAdd, legacyHook = frame, original, hook
        frame.AddMessage = hook
        -- Retire only notices already visible at takeover; never replay them.
        if type(frame.Clear) == "function" then frame:Clear() end
    end
    local function RedirectErrors()
        local frame = UIErrorsFrame
        if not frame or type(frame.AddMessage) ~= "function" or errorFrame == frame then return end
        ReleaseErrors()
        local original, hook = frame.AddMessage
        hook = function(owner, text, r, g, b, id, hold)
            if banners.IsActive() and errorHook == hook and type(text) == "string" and text ~= "" then
                if HasBanner(text) then return end
                -- Wait until the next update so either native delivery order
                -- can pair with an accepted banner. Unmatched errors stay native.
                if errorCount == MAX_ERRORS then
                    local oldest = table.remove(pendingErrors, 1)
                    errorCount = errorCount - 1
                    ShowError(oldest)
                end
                errorCount = errorCount + 1
                pendingErrors[errorCount] = {
                    add = original,
                    owner = owner,
                    text = text,
                    r = r,
                    g = g,
                    b = b,
                    id = id,
                    hold = hold,
                }
                table.setn(pendingErrors, errorCount)
                return
            end
            return original(owner, text, r, g, b, id, hold)
        end
        errorFrame, errorAdd, errorHook = frame, original, hook
        frame.AddMessage = hook
    end
    OnBanner = function(entry)
        delivering = true
        local ok, message = pcall(Receive, entry)
        if not ok then Failed(message) end
        delivering = false
        if not ok and geterrorhandler then geterrorhandler()(message) end
    end
    Refresh = function()
        if delivering then return false end
        if not inWorld or not DFRL.display.Get("customBanners") or faulted or not Supported() then
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
        RedirectLegacy()
        RedirectErrors()
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
        FlushErrors(not active)
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
    DFRL.layout.Register("banners", root, function()
        root:ClearAllPoints()
        root:SetPoint("TOP", UIParent, "TOP", 0, -130)
    end, { labelAbove = true, refreshDefault = true, onReset = banners.Clear })
    DFRL.display.Listen(Refresh)
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("CHAT_MSG_ADDON")
    controller:RegisterEvent("CVAR_UPDATE")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            age, painted = 0, 0
            controller:SetScript("OnUpdate", Tick)
            Refresh()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
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
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Release()
            return reloadUI()
        end
    end
    DFRL.banners = banners
    controller:SetScript("OnUpdate", Tick)
    Refresh()
end)
