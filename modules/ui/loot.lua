-- Design-independent loot intake and native HUD ownership. No view is selected.
-- API and renderer contract: docs/LOOT-NOTIFICATIONS.md.
DFRL:NewMod("LootNotifications", 0, function()
    local loot = {}
    DFRL.loot = loot
    local renderer, nativePreference
    local inWorld, active, applying = true, false, false
    local queue, count, sequence, age = {}, 0, 0, 0
    local MAX_QUEUE = 32
    local controller = CreateFrame("Frame")

    local function Shown(value)
        if value == true or value == 1 or value == "1" then return true end
        if value == false or value == 0 or value == "0" then return false end
    end
    local function ReadNative()
        if type(AZS_IsHudShown) ~= "function" then return nil end
        local ok, value = pcall(AZS_IsHudShown, "loot")
        if ok then return Shown(value) end
    end
    local function WriteNative(shown)
        if applying or type(AZS_SetHudShown) ~= "function" then return false end
        applying = true
        local ok = pcall(AZS_SetHudShown, "loot", shown)
        applying = false
        return ok
    end
    local function Clear()
        for index = 1, count do
            queue[index] = nil
        end
        count = 0
        table.setn(queue, 0)
        if renderer then pcall(renderer.Clear) end
    end
    local function Release()
        active = false
        if nativePreference ~= nil then
            local current = ReadNative()
            -- A later external value that no longer matches our suppression
            -- wins. An originally hidden preference must remain hidden too.
            if current == nil then return end
            if current == false and current ~= nativePreference then
                if not WriteNative(nativePreference) or ReadNative() ~= nativePreference then return end
            end
            nativePreference = nil
        end
    end
    local function Ready()
        if not inWorld or not renderer then return false end
        local ok, ready = pcall(renderer.IsReady)
        return ok and ready == true
    end
    local function Refresh()
        if not Ready() then
            if active or nativePreference ~= nil then
                Clear()
                Release()
            end
            return false
        end
        if type(AZS_SetHudShown) ~= "function" then
            Clear()
            Release()
            return false
        end
        local shown = ReadNative()
        if shown == nil then
            Clear()
            Release()
            return false
        end
        if nativePreference == nil then nativePreference = shown end
        if shown and (not WriteNative(false) or ReadNative() ~= false) then
            Clear()
            Release()
            return false
        end
        active = true
        return true
    end

    -- Unknown item templates and missing icons/slots stay unknown. In 1.12 the
    -- getter takes the inner item: reference, not the colored display hyperlink.
    function loot.Resolve(entry)
        local result = {}
        for key, value in pairs(entry) do
            result[key] = value
        end
        if type(entry.itemReference) ~= "string" or type(GetItemInfo) ~= "function" then return result end
        local ok, name, _, quality, _, _, _, _, slot, icon = pcall(GetItemInfo, entry.itemReference)
        if not ok or type(name) ~= "string" or name == "" then return result end
        if type(quality) == "number" and quality >= 0 and quality - quality == 0 and quality == math.floor(quality) then
            result.quality = quality
        end
        if type(slot) == "string" and string.find(slot, "^INVTYPE_[A-Z_]+$") then
            result.equipLoc = slot
            if type(_G[slot]) == "string" and _G[slot] ~= "" then result.equipText = _G[slot] end
        end
        if
            type(icon) == "string"
            and icon ~= ""
            and not string.find(string.lower(icon), "inv_misc_questionmark", 1, true)
        then
            result.icon = icon
        end
        return result
    end

    function loot.IsActive() return active end
    function loot.Clear() Clear() end
    function loot.Observe(text, eventName)
        if not active or not inWorld then return end
        if eventName and eventName ~= "CHAT_MSG_LOOT" and eventName ~= "CHAT_MSG_SYSTEM" then return end
        local chat = DFRL.CleanerChat
        if not chat or type(chat.ParseLootMessage) ~= "function" then return end
        local ok, entry = pcall(chat.ParseLootMessage, text)
        if not ok or type(entry) ~= "table" then return end
        sequence = sequence + 1
        entry.sequence, entry.receivedAt = sequence, GetTime()
        if count == MAX_QUEUE then
            table.remove(queue, 1)
            count = count - 1
        end
        count = count + 1
        queue[count] = entry
        table.setn(queue, count)
    end

    local function Update()
        age = age + (tonumber(arg1) or 0)
        if age < 0.2 then return end
        age = 0
        if not Refresh() then return end
        local delivered = 0
        while count > 0 and delivered < 4 do
            local ok, accepted = pcall(renderer.Push, loot.Resolve(queue[1]))
            if not ok then
                Clear()
                Release()
                renderer = nil
                controller:SetScript("OnUpdate", nil)
                return
            end
            if accepted ~= true then return end
            table.remove(queue, 1)
            count = count - 1
            table.setn(queue, count)
            delivered = delivered + 1
        end
    end

    function loot.SetRenderer(value)
        Clear()
        Release()
        renderer = nil
        if
            type(value) == "table"
            and type(value.IsReady) == "function"
            and type(value.Push) == "function"
            and type(value.Clear) == "function"
        then
            renderer = value
        end
        age = 0
        controller:SetScript("OnUpdate", inWorld and renderer and Update or nil)
        return Refresh()
    end

    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("CVAR_UPDATE")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            age = 0
            controller:SetScript("OnUpdate", renderer and Update or nil)
            Refresh()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Clear()
            Release()
        elseif not applying and type(arg1) == "string" and string.lower(arg1) == "hudloot" then
            if nativePreference ~= nil then
                local shown = ReadNative()
                if shown ~= nil then nativePreference = shown end
            end
            Refresh()
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Clear()
            Release()
            return reloadUI()
        end
    end
end)
