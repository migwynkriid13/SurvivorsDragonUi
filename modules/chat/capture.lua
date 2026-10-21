-- Raw chat/event history adapted from CleanerChat's Filters/_Debug.lua.
-- Capture is always on for this UI session and never prints into visible chat.
DFRL:NewMod("ChatCapture", 0, function()
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local chat = DFRL.CleanerChat
    local history = {}
    local broadcastTime, broadcasts

    -- Escaping pipes preserves color/link payloads through Copy's PlainText.
    local function Escape(value)
        if value == nil then return "<nil>" end
        if value == "" then return "<empty>" end
        return (string.gsub(tostring(value), "|", "||"))
    end
    local function FrameName(frame) return frame.GetName and frame:GetName() or "<unnamed>" end

    local function FirstDelivery(frame, text, eventName, author, message)
        local now = GetTime()
        if now ~= broadcastTime then
            broadcastTime, broadcasts = now, {}
        end
        local signature = tostring(eventName) .. "\001" .. tostring(author) .. "\001" .. tostring(message) .. "\001" .. text
        local delivery = broadcasts[signature]
        if not delivery then
            delivery = { counts = {}, maximum = 0 }
            broadcasts[signature] = delivery
        end
        local count = (delivery.counts[frame] or 0) + 1
        delivery.counts[frame] = count
        -- Additional chat frames receive the same delivery. Repeated identical
        -- messages on one frame remain distinct, including in the same UI tick.
        if count <= delivery.maximum then return false end
        delivery.maximum = count
        return true
    end

    chat.CaptureRaw = function(frame, text, eventName, author, message)
        if type(text) ~= "string" then return end
        local first = FirstDelivery(frame, text, eventName, author, message)
        -- Preserve direct native writes in diagnostics even when another frame
        -- received the same text. Only the optional loot view collapses them.
        if first or not eventName or not string.find(eventName, "^CHAT_MSG_") then
            table.insert(history, '[RAW] frame="' .. Escape(FrameName(frame)) .. '" "' .. Escape(text) .. '"')
        end
        if first and DFRL.loot then DFRL.loot.Observe(text, eventName) end
    end

    chat.GetCaptureText = function(states)
        local lines = {}
        for _, line in ipairs(history) do
            table.insert(lines, line)
        end
        -- Some ports expose native history readers. Include their retained
        -- output separately, including writes that bypass the Lua hook.
        for i = 1, NUM_CHAT_WINDOWS or 7 do
            local frame = states and states[i] and states[i].native or _G["ChatFrame" .. i]
            if frame and frame.GetNumMessages and frame.GetMessageInfo then
                local success, count = pcall(frame.GetNumMessages, frame)
                if success and type(count) == "number" then
                    for j = 1, count do
                        local readable, text = pcall(frame.GetMessageInfo, frame, j)
                        if readable and type(text) == "string" then
                            table.insert(
                                lines,
                                '[NATIVE] frame="' .. Escape(FrameName(frame)) .. '" "' .. Escape(text) .. '"'
                            )
                        end
                    end
                end
            end
        end
        return table.concat(lines, "\n")
    end

    local collector = CreateFrame("Frame")
    local allEvents = collector.RegisterAllEvents and pcall(collector.RegisterAllEvents, collector)
    local registered = {}
    local function Watch(name)
        if type(name) == "string" and not registered[name] then
            if pcall(collector.RegisterEvent, collector, name) then registered[name] = true end
        end
    end
    local function RegisterKnownEvents()
        if type(ChatTypeInfo) == "table" then
            for name in pairs(ChatTypeInfo) do
                Watch("CHAT_MSG_" .. name)
            end
        end
        if type(ChatTypeGroup) == "table" then
            for _, group in pairs(ChatTypeGroup) do
                if type(group) == "table" then
                    for _, name in pairs(group) do
                        Watch(name)
                    end
                end
            end
        end
        for _, name in ipairs({
            "CHAT_MSG_ADDON",
            "CHAT_MSG_CURRENCY",
            "CHAT_MSG_PARTY_LEADER",
            "CHAT_MSG_RAID_BOSS_EMOTE",
            "CHAT_MSG_RAID_BOSS_WHISPER",
            "UI_INFO_MESSAGE",
            "UI_ERROR_MESSAGE",
            "PLAYER_LEVEL_UP",
            "PLAYER_ENTERING_WORLD",
        }) do
            Watch(name)
        end
    end
    if not allEvents then RegisterKnownEvents() end
    collector:SetScript("OnEvent", function()
        local eventName = event
        if not allEvents and eventName == "PLAYER_ENTERING_WORLD" then RegisterKnownEvents() end
        if
            not eventName
            or (
                not string.find(eventName, "^CHAT_MSG_")
                and eventName ~= "UI_INFO_MESSAGE"
                and eventName ~= "UI_ERROR_MESSAGE"
                and eventName ~= "PLAYER_LEVEL_UP"
            )
        then
            return
        end
        local arguments = { arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 }
        local line = "[EVT] "
            .. eventName
            .. ' author="'
            .. Escape(arguments[2])
            .. '" msg="'
            .. Escape(arguments[1])
            .. '"'
        for i = 3, 9 do
            if arguments[i] ~= nil then line = line .. " arg" .. i .. '="' .. Escape(arguments[i]) .. '"' end
        end
        table.insert(history, line)
    end)
end)
