-- Shared loot intake and native HUD ownership; the selected view is separate.
-- API and renderer contract: docs/LOOT-NOTIFICATIONS.md.
DFRL:NewMod("LootNotifications", 0, function()
    local loot = {}
    DFRL.loot = loot
    local renderer
    local native = T.NewHudOwner("loot", "hudLoot")
    local inWorld, active = true, false
    local mode, showMarks = DFRL.display.Get("lootMode"), DFRL.display.Get("lootShowMarks")
    local retry = false
    local SyncUpdates
    local queue, count, sequence, age = {}, 0, 0, 0
    local MAX_QUEUE = 32
    local controller = CreateFrame("Frame")

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
        retry = not native.Release()
    end
    local function Ready()
        if not inWorld or not renderer then return false end
        local ok, ready = pcall(renderer.IsReady)
        return ok and ready == true
    end
    local function Refresh()
        if inWorld and mode ~= "sdui" then
            if active or count > 0 then Clear() end
            active = false
            retry = not native.Acquire(mode == "game")
            return false
        end
        if not Ready() then
            if active or native.IsCaptured() then
                Clear()
                Release()
            end
            return false
        end
        if not native.Acquire() then
            Clear()
            Release()
            return false
        end
        active = true
        retry = false
        return true
    end

    local function CatalogIcon(entry)
        local catalogs = DFRL.LootIconCatalog
        local code = DFRL.locale.code
        local catalog = catalogs and (catalogs[code] or catalogs.en)
        local icon = catalog and catalog[entry.name]
        if type(icon) == "string" then return icon end
        -- Refine only ambiguity in this same native source, using the actual
        -- player class captured at delivery. No class is inferred from a name.
        if icon == false and entry.itemClass then
            local classes = catalogs.classes and catalogs.classes[code]
            local names = classes and classes[entry.itemClass]
            icon = names and names[entry.name]
            if type(icon) == "string" then return icon end
        end
    end
    -- Prefer exact-reference native metadata. Native self-loot text can contain
    -- only a colored name, so use the generated exact native catalog as fallback.
    -- Missing/conflicting catalog entries stay unknown; never invent item ids.
    function loot.Resolve(entry)
        local result = {}
        for key, value in pairs(entry) do
            result[key] = value
        end
        if type(entry.itemReference) == "string" and type(GetItemInfo) == "function" then
            local ok, name, _, quality, _, _, _, _, slot, icon = pcall(GetItemInfo, entry.itemReference)
            if ok and type(name) == "string" and name ~= "" then
                if
                    type(quality) == "number"
                    and quality >= 0
                    and quality - quality == 0
                    and quality == math.floor(quality)
                then
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
                    result.icon, result.iconSource = icon, "native"
                end
            end
        end
        if not result.icon then
            result.icon = CatalogIcon(entry)
            if result.icon then result.iconSource = "catalog" end
        end
        return result
    end

    function loot.IsActive() return active end
    function loot.Clear() Clear() end
    function loot.IsMarkReward(entry)
        return type(entry) == "table"
            and entry.collection == "collected"
            and type(entry.marks) == "string"
            and string.find(entry.marks, "^%d+$") ~= nil
            and string.find(entry.marks, "[1-9]") ~= nil
    end
    function loot.CanShow(entry)
        return mode == "sdui"
            and type(entry) == "table"
            and (entry.collection ~= "collected" or (showMarks and loot.IsMarkReward(entry)))
    end
    function loot.Observe(text, eventName)
        if not active or not inWorld then return end
        if eventName and eventName ~= "CHAT_MSG_LOOT" and eventName ~= "CHAT_MSG_SYSTEM" then return end
        local chat = DFRL.CleanerChat
        if not chat or type(chat.ParseLootMessage) ~= "function" then return end
        local ok, entry = pcall(chat.ParseLootMessage, text)
        if not ok or not loot.CanShow(entry) then return end
        if type(UnitClass) == "function" then
            local classOK, _, class = pcall(UnitClass, "player")
            if classOK and type(class) == "string" then entry.itemClass = string.lower(class) end
        end
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
        local custom = Refresh()
        SyncUpdates()
        if not custom then return end
        local delivered = 0
        while count > 0 and delivered < 4 do
            local ok, accepted = pcall(renderer.Push, queue[1])
            if not ok then
                Clear()
                Release()
                renderer = nil
                SyncUpdates()
                return
            end
            if accepted ~= true then return end
            table.remove(queue, 1)
            count = count - 1
            table.setn(queue, count)
            delivered = delivered + 1
        end
    end

    SyncUpdates = function()
        local update = inWorld and ((mode == "sdui" and renderer) or retry) and Update or nil
        if controller:GetScript("OnUpdate") ~= update then controller:SetScript("OnUpdate", update) end
    end

    function loot.SetRenderer(value)
        Clear()
        if mode == "sdui" then Release() end
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
        local custom = Refresh()
        SyncUpdates()
        return custom
    end

    DFRL.display.Listen(function()
        local selectedMode, selectedMarks = DFRL.display.Get("lootMode"), DFRL.display.Get("lootShowMarks")
        if selectedMode == mode and selectedMarks == showMarks then return end
        mode, showMarks, age = selectedMode, selectedMarks, 0
        Clear()
        Refresh()
        SyncUpdates()
    end)

    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("CVAR_UPDATE")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            age = 0
            Refresh()
            SyncUpdates()
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            Clear()
            Release()
            SyncUpdates()
        elseif native.Observe(arg1) then
            Refresh()
            SyncUpdates()
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            Clear()
            Release()
            SyncUpdates()
            return reloadUI()
        end
    end
    if mode ~= "sdui" then Refresh() end
    SyncUpdates()
end)
