-- Suspend only the hidden native Combat Log; keep its groups and visible input.
DFRL:NewMod("CombatLogPause", 1, function()
    if DFRL.display.Get("defaultChat") then return end
    local inWorld, owner = true, nil
    local paused, requested, explicit = {}, {}, {}
    local combat = {}
    local regular = {
        COMBAT_XP_GAIN = true,
        COMBAT_HONOR_GAIN = true,
        COMBAT_FACTION_CHANGE = true,
        SPELL_TRADESKILLS = true,
        SPELL_ITEM_ENCHANTMENTS = true,
    }
    local register, unregister
    local Apply
    local function Hidden()
        if not inWorld or DFRL.display.Get("defaultChat") or not owner then return false end
        local chat = DFRL.CleanerChat
        return not owner:IsVisible() or (chat and chat.IsFrameActive and not chat.IsFrameActive(owner))
    end
    local function CombatGroup(group)
        return type(group) == "string"
            and not regular[group]
            and (string.find(group, "^COMBAT_") or string.find(group, "^SPELL_"))
    end
    local function Wanted()
        local wanted, notices = {}, {}
        if type(owner.messageTypeList) ~= "table" then return wanted end
        for _, group in pairs(owner.messageTypeList) do
            local events = ChatTypeGroup[group]
            if type(events) == "table" then
                for _, eventName in pairs(events) do
                    if type(eventName) == "string" then
                        if CombatGroup(group) then
                            wanted[eventName] = true
                        else
                            notices[eventName] = true
                        end
                    end
                end
            end
        end
        for eventName in pairs(notices) do
            wanted[eventName] = nil
        end
        return wanted
    end
    local function Attach()
        if owner or not ChatFrame2 or type(ChatTypeGroup) ~= "table" then return end
        owner = ChatFrame2
        local notices = {}
        for group, events in pairs(ChatTypeGroup) do
            if type(events) == "table" then
                for _, eventName in pairs(events) do
                    if type(eventName) == "string" then
                        if CombatGroup(group) then
                            combat[eventName] = true
                        else
                            notices[eventName] = true
                        end
                    end
                end
            end
        end
        for eventName in pairs(notices) do
            combat[eventName] = nil
        end
        register, unregister = owner.RegisterEvent, owner.UnregisterEvent
        owner.RegisterEvent = function(frame, eventName)
            if frame == owner and combat[eventName] then
                requested[eventName], explicit[eventName] = true, true
                if Hidden() then
                    paused[eventName] = true
                    return
                end
                paused[eventName] = nil
            end
            return register(frame, eventName)
        end
        owner.UnregisterEvent = function(frame, eventName)
            if frame == owner and combat[eventName] then
                requested[eventName], explicit[eventName], paused[eventName] = false, nil, nil
            end
            return unregister(frame, eventName)
        end
        local unregisterAll = owner.UnregisterAllEvents
        owner.UnregisterAllEvents = function(frame)
            if frame == owner then
                paused, explicit = {}, {}
                for eventName in pairs(combat) do
                    requested[eventName] = false
                end
            end
            return unregisterAll(frame)
        end
        HookScript(owner, "OnShow", function() Apply() end)
        HookScript(owner, "OnHide", function() Apply() end)
    end
    Apply = function()
        Attach()
        if not owner then return end
        local wanted = Wanted()
        if Hidden() then
            for eventName in pairs(wanted) do
                if combat[eventName] and requested[eventName] ~= false and not paused[eventName] then
                    local subscribed = true
                    if owner.IsEventRegistered then subscribed = owner:IsEventRegistered(eventName) end
                    if subscribed == true or subscribed == 1 then
                        unregister(owner, eventName)
                        paused[eventName] = true
                    end
                end
            end
        else
            for eventName in pairs(paused) do
                if requested[eventName] ~= false and (wanted[eventName] or explicit[eventName]) then
                    register(owner, eventName)
                end
                paused[eventName] = nil
            end
        end
    end
    local controller = CreateFrame("Frame")
    for _, eventName in ipairs({
        "PLAYER_LOGIN",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_LOGOUT",
        "UPDATE_CHAT_WINDOWS",
    }) do
        controller:RegisterEvent(eventName)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then inWorld = false end
        if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
        Apply()
    end)
    DFRL.display.Listen(Apply)
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    DFRL.CleanerChat.RefreshHiddenCombatLog = Apply
    Apply()
end)
