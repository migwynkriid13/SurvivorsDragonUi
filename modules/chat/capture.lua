-- Raw chat/event history adapted from CleanerChat's Filters/_Debug.lua.
-- Capture is always on for this UI session and never prints into visible chat.
DFRL:NewMod("ChatCapture", 0, function()
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local chat = DFRL.CleanerChat
    local history, pending = {}, {}
    local pendingBytes = 0
    local PAGE_BYTES, NATIVE_READS = 6144, 64
    local hasCapture = false
    local broadcastTime, broadcasts

    local function Value(value)
        if value == nil then return "<nil>" end
        if value == "" then return "<empty>" end
        return tostring(value)
    end
    local function Flush()
        if table.getn(pending) == 0 then return end
        table.insert(history, table.concat(pending))
        pending, pendingBytes = {}, 0
    end
    local function AppendBytes(text)
        local first, length = 1, string.len(text)
        while first <= length do
            local last = math.min(length, first + PAGE_BYTES - pendingBytes - 1)
            local proposed = last
            -- Keep every UTF-8 sequence on one page, including a large line.
            for _ = 1, 3 do
                if last < first or last == length then break end
                local byte = string.byte(text, last + 1)
                if byte < 128 or byte >= 192 then break end
                last = last - 1
            end
            local following = last < length and string.byte(text, last + 1)
            -- A longer continuation run is malformed: retain its raw bytes
            -- at the proposed boundary instead of backtracking or stalling.
            if following and following >= 128 and following < 192 then last = proposed end
            if last < first then
                Flush()
            else
                table.insert(pending, string.sub(text, first, last))
                pendingBytes = pendingBytes + last - first + 1
                first = last + 1
                if pendingBytes == PAGE_BYTES then Flush() end
            end
        end
    end
    local function Append(line)
        if hasCapture then AppendBytes("\n") end
        AppendBytes(line)
        hasCapture = true
    end
    local function Export(text, plain)
        if plain then
            -- Copy's old escaped-pipe round trip also converted literal SOH.
            if string.find(text, "\001", 1, true) then return (string.gsub(text, "\001", "|")) end
        elseif string.find(text, "|", 1, true) then
            return (string.gsub(text, "|", "||"))
        end
        return text
    end
    local function FrameName(frame) return frame.GetName and frame:GetName() or "<unnamed>" end

    local function FirstDelivery(frame, text, eventName, author, message, source, surface)
        local now = GetTime()
        if now ~= broadcastTime then
            broadcastTime, broadcasts = now, {}
        end
        local signature = tostring(source)
            .. "\001"
            .. tostring(eventName)
            .. "\001"
            .. tostring(author)
            .. "\001"
            .. tostring(message)
            .. "\001"
            .. text
        local delivery = broadcasts[signature]
        if not delivery then
            delivery = { counts = {}, maximum = 0 }
            broadcasts[signature] = delivery
        end
        local counts = delivery.counts
        if surface then
            delivery.surfaces = delivery.surfaces or {}
            delivery.surfaces[surface] = delivery.surfaces[surface] or {}
            counts = delivery.surfaces[surface]
        end
        local count = (counts[frame] or 0) + 1
        counts[frame] = count
        -- Additional chat frames receive the same delivery. Repeated identical
        -- messages on one frame remain distinct, including in the same UI tick.
        -- Optional surfaces pair that frame's legacy and regular-chat calls.
        if count <= delivery.maximum then return false end
        delivery.maximum = count
        return true
    end
    chat.FirstDelivery = FirstDelivery

    chat.CaptureRaw = function(frame, text, eventName, author, message)
        if type(text) ~= "string" then return end
        local first = FirstDelivery(frame, text, eventName, author, message)
        -- Preserve direct native writes in diagnostics even when another frame
        -- received the same text. Only the optional loot view collapses them.
        if first or not eventName or not string.find(eventName, "^CHAT_MSG_") then
            Append('[RAW] frame="' .. Value(FrameName(frame)) .. '" "' .. Value(text) .. '"')
        end
        if first and DFRL.loot then DFRL.loot.Observe(text, eventName) end
    end

    chat.GetCaptureText = function(states, plain)
        Flush()
        local lines = {}
        for _, chunk in ipairs(history) do
            table.insert(lines, Export(chunk, plain))
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
                            if table.getn(lines) > 0 then table.insert(lines, "\n") end
                            table.insert(
                                lines,
                                Export(
                                    '[NATIVE] frame="' .. Value(FrameName(frame)) .. '" "' .. Value(text) .. '"',
                                    plain
                                )
                            )
                        end
                    end
                end
            end
        end
        return table.concat(lines)
    end

    -- The dialog reads one retained chunk or a bounded native page at a time.
    -- Its archive boundary stays fixed while normal session capture continues.
    chat.NewCaptureSnapshot = function(states, plain)
        Flush()
        local archiveCount, native = table.getn(history), {}
        for i = 1, NUM_CHAT_WINDOWS or 7 do
            local frame = states and states[i] and states[i].native or _G["ChatFrame" .. i]
            if frame and frame.GetNumMessages and frame.GetMessageInfo then
                local success, count = pcall(frame.GetNumMessages, frame)
                if success and type(count) == "number" and count > 0 and count - count == 0 then
                    table.insert(native, { frame = frame, count = math.floor(count) })
                end
            end
        end
        local function NativeCursor(index)
            local entry = native[index]
            if entry then return { native = index, message = entry.count } end
        end
        local snapshot = { first = archiveCount > 0 and { archive = archiveCount } or NativeCursor(1) }
        snapshot.Read = function(position)
            if not position then return "", nil end
            if position.archive then
                local index = position.archive
                local nextPosition = index > 1 and { archive = index - 1 } or NativeCursor(1)
                return Export(history[index], plain), nextPosition
            end
            local cursor = {
                native = position.native,
                message = position.message,
                text = position.text,
                last = position.last,
            }
            local parts, bytes, reads = {}, 0, 0
            while cursor and bytes < PAGE_BYTES and reads < NATIVE_READS do
                local entry = native[cursor.native]
                if not cursor.text then
                    reads = reads + 1
                    local success, text = pcall(entry.frame.GetMessageInfo, entry.frame, cursor.message)
                    if success and type(text) == "string" then
                        cursor.text = Export(
                            '[NATIVE] frame="' .. Value(FrameName(entry.frame)) .. '" "' .. Value(text) .. '"',
                            plain
                        )
                        cursor.last = string.len(cursor.text)
                    end
                end
                if cursor.text then
                    local gap = table.getn(parts) > 0 and 1 or 0
                    local first = math.max(1, cursor.last - (PAGE_BYTES - bytes - gap) + 1)
                    local proposed = first
                    for _ = 1, 3 do
                        if first > cursor.last then break end
                        local byte = string.byte(cursor.text, first)
                        if byte < 128 or byte >= 192 then break end
                        first = first + 1
                    end
                    local byte = first <= cursor.last and string.byte(cursor.text, first)
                    if byte and byte >= 128 and byte < 192 then first = proposed end
                    if first > cursor.last then
                        if table.getn(parts) > 0 then break end
                        first = proposed
                    end
                    table.insert(parts, 1, string.sub(cursor.text, first, cursor.last))
                    bytes = bytes + cursor.last - first + 1 + gap
                    if first > 1 then
                        cursor.last = first - 1
                        break
                    end
                end
                cursor.text, cursor.last = nil, nil
                cursor.message = cursor.message - 1
                if cursor.message < 1 then cursor = NativeCursor(cursor.native + 1) end
            end
            return table.concat(parts, "\n"), cursor
        end
        return snapshot
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
        local parts = { "[EVT] ", eventName, ' author="', Value(arguments[2]), '" msg="', Value(arguments[1]), '"' }
        for i = 3, 9 do
            if arguments[i] ~= nil then
                table.insert(parts, " arg" .. i .. '="')
                table.insert(parts, Value(arguments[i]))
                table.insert(parts, '"')
            end
        end
        Append(table.concat(parts))
    end)
end)
