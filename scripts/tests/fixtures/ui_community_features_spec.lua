-- CI only: production sharing, hidden-log ownership and minimap FX over native mocks.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "community feature fixtures require CI Lua 5.1")
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do
        result[key] = Copy(entry)
    end
    return result
end

do
    local c = H.New()
    local env = c.env
    c:Load("core/display.lua", "Display")
    local display = env.DFRL.display
    local geometry = { playerFrame = { x = 12.3456789012345, y = -6.25, scale = 1.2 } }
    env.DFRL.layout.Copy = Copy
    env.DFRL.layout.Snapshot = function() return Copy(geometry) end
    env.DFRL.layout.Load = function(value) c.loadedGeometry = value end
    env.DFRL.runFont = { Copy = Copy, Snapshot = function() return { size = 14 } end, Load = function() end }
    env.loadstring = function() error("profile strings must never execute Lua") end
    c:Load("core/profiles.lua", "Profiles")
    local profiles = env.DFRL.profiles
    env.DFRL.layout.ConfirmEdit = function()
        display.FinishEdit(true)
        profiles.FinishEdit(true)
        return true
    end
    local function Begin()
        display.BeginEdit()
        profiles.BeginEdit()
    end
    Begin()
    display.Set("guardianNameFontSize", 9)
    display.Set("hideSoulShards", true)
    display.Set("uiCustomFont", "Český.ttf")
    assert(profiles.Save("Original", false))
    local ok, shared = profiles.Export("Original")
    assert(ok and string.sub(shared, 1, 6) == "SDUI1:" and not string.find(shared, "Č", 1, true))
    assert(select(2, profiles.Export("Original")) == shared, "export was not deterministic")
    Begin()
    display.Set("guardianNameFontSize", 17)
    display.FinishEdit(true)
    profiles.FinishEdit(false)
    Begin()
    assert(profiles.Import(shared, "Imported"))
    assert(not env.SurvivorsDragonUiProfiles.Imported, "import saved its draft early")
    assert(display.Get("guardianNameFontSize") == 17, "import silently activated the profile")
    assert(profiles.Load("Imported"))
    assert(display.Get("guardianNameFontSize") == 9 and display.Get("hideSoulShards"), "import lost current options")
    assert(display.Get("uiCustomFont") == "Český.ttf", "profile sharing lost UTF-8 bytes")
    assert(c.loadedGeometry.playerFrame.x == geometry.playerFrame.x, "sharing rounded layout coordinates")
    display.FinishEdit(false)
    profiles.FinishEdit(false)
    assert(not env.SurvivorsDragonUiProfiles.Imported and display.Get("guardianNameFontSize") == 17)
    Begin()
    assert(profiles.Import(shared, "Imported"))
    assert(not profiles.Import(shared, "Imported"), "import overwrote an existing profile")
    assert(not profiles.Import(shared, ""), "import accepted an empty profile name")
    assert(profiles.Export("Imported"))
    assert(select(2, profiles.Export("Imported")) == shared, "round-trip changed the profile payload")
    for _, malformed in ipairs({
        "SDUI2:{}",
        shared .. "t",
        string.sub(shared, 1, -2),
        "SDUI1:{s%GG;{}slayout;{}sdisplay;{}srunFont;{}}",
        "SDUI1:{slayout;{}sdisplay;{}srunFont;{}slayout;{}}",
        "SDUI1:{slayout;{sx;n1e999;}sdisplay;{}srunFont;{}}",
        "SDUI1:" .. string.rep("{sa;", 17) .. string.rep("}", 17),
        "SDUI1:" .. string.rep("a", 131073),
        "SDUI1:loadstring('anything')()",
    }) do
        local safe, accepted = pcall(profiles.Import, malformed, "Rejected")
        assert(safe and not accepted, "malformed profile escaped bounded data parsing")
    end
    env.DFRL.layout.ConfirmEdit()
    assert(env.SurvivorsDragonUiProfiles.Imported, "Confirm did not retain the imported profile")
    display.Reset()
    assert(env.SurvivorsDragonUiProfiles.Imported, "reset erased imported profiles")
end
print("PASS SDUI1 sharing round-trips, normalization, precision, UTF-8, transactions and bounded malformed inputs")

for _, performance in ipairs({ false, true }) do
    local c = H.New()
    local env = c.env
    c.settings.performanceMode = performance
    local log = env.CreateFrame("ScrollingMessageFrame", "ChatFrame2", env.UIParent)
    local groups = { "COMBAT_XP_GAIN" }
    env.ChatTypeGroup = { COMBAT_XP_GAIN = { "CHAT_MSG_COMBAT_XP_GAIN" } }
    log:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
    for index = 1, 33 do
        local group, event = "COMBAT_GROUP" .. index, "CHAT_MSG_COMBAT_GROUP" .. index
        env.ChatTypeGroup[group] = { event }
        table.insert(groups, group)
        log:RegisterEvent(event)
    end
    log.messageTypeList = groups
    env.DFRL.CleanerChat = { IsFrameActive = function(frame) return c.selected == frame end }
    c:Load("modules/chat/combat_log_pause.lua", "CombatLogPause")
    local apply = env.DFRL.CleanerChat.RefreshHiddenCombatLog
    assert(log:IsVisible(), "fixture did not retain the alpha-masked native window")
    assert(not log.events.CHAT_MSG_COMBAT_GROUP1, "unselected but shown combat log retained combat subscriptions")
    assert(
        log.events.CHAT_MSG_COMBAT_XP_GAIN and log.messageTypeList == groups,
        "pausing changed notices or saved groups"
    )
    assert(#c.objects == 3, "hidden log added presentation objects or an extra worker")
    for _, object in ipairs(c.objects) do
        assert(not object:GetScript("OnUpdate"), "hidden-log ownership added idle polling")
    end
    c.selected = log
    apply()
    assert(log.events.CHAT_MSG_COMBAT_GROUP1 and log.events.CHAT_MSG_COMBAT_GROUP33, "selected log did not resume")
    c.selected = nil
    apply()
    log:UnregisterEvent("CHAT_MSG_COMBAT_GROUP1")
    log:RegisterEvent("CHAT_MSG_COMBAT_GROUP2")
    assert(not log.events.CHAT_MSG_COMBAT_GROUP2, "native reregistration bypassed hidden masking")
    c.selected = log
    apply()
    assert(not log.events.CHAT_MSG_COMBAT_GROUP1 and log.events.CHAT_MSG_COMBAT_GROUP2, "foreign unsubscribe was lost")
    log:Hide()
    assert(not log.events.CHAT_MSG_COMBAT_GROUP2, "hidden selected log kept intake")
    log:Show()
    assert(log.events.CHAT_MSG_COMBAT_GROUP2, "Show did not resume current combat groups")
    c.selected = nil
    apply()
    c:SetSetting("defaultChat", true)
    assert(log.events.CHAT_MSG_COMBAT_GROUP2, "default-chat preview did not release native event ownership")
    c:SetSetting("defaultChat", false)
    assert(not log.events.CHAT_MSG_COMBAT_GROUP2, "custom-chat recovery retained hidden combat intake")
    local controller = c:Controller("PLAYER_LEAVING_WORLD")
    c:Event(controller, "PLAYER_LEAVING_WORLD")
    assert(log.events.CHAT_MSG_COMBAT_GROUP2, "world cleanup did not restore native log subscriptions")
    c:Event(controller, "PLAYER_ENTERING_WORLD")
    assert(not log.events.CHAT_MSG_COMBAT_GROUP2, "world recovery did not suspend the hidden log")
    log:UnregisterAllEvents()
    c.selected = log
    apply()
    assert(not next(log.events), "foreign complete unsubscription was reversed")
end
print(
    "PASS hidden combat log respects selection, notices, native group changes, cleanup and both modes without polling"
)

do
    local c = H.New()
    local env = c.env
    local create = c.Object
    function c:Object(kind, name, parent)
        local object = create(self, kind, name, parent)
        function object:RegisterForClicks(...) self.clicks = { ... } end
        function object:RegisterForDrag(...) self.dragButtons = { ... } end
        return object
    end
    env.Minimap = env.CreateFrame("Frame", "Minimap", env.UIParent)
    function env.Minimap:GetCenter() return 100, 100 end
    function env.Minimap:GetEffectiveScale() return 1 end
    env.GetCursorPosition = function() return 140, 90 end
    env.inWorld = true
    env.Visible = function() return env.inWorld and env.Minimap:IsVisible() and not c.hidden end
    env.Number = function(value) return type(value) == "number" and value - value == 0 end
    env.Register = function(button) c.squareButton = button end
    env.DFRL.layout.IsEditing = function() return c.editing end
    c.fx, c.fxReads, c.fxWrites = "0", 0, 0
    env.GetCVar = function(name)
        assert(name == "noSpellEffects")
        c.fxReads = c.fxReads + 1
        return c.fx
    end
    env.SetCVar = function(name, value)
        assert(name == "noSpellEffects" and (value == "0" or value == "1"))
        c.fx, c.fxWrites = value, c.fxWrites + 1
    end
    local file = assert(io.open("modules/map/buttons.lua", "r"))
    local source = file:read("*a")
    file:close()
    local first = assert(string.find(source, "    -- The native graphics preference", 1, true))
    local last = assert(string.find(source, "    local controller = CreateFrame", first, true))
    local chunk = assert(loadstring(string.sub(source, first, last - 1) .. "\nreturn PaintFx"))
    setfenv(chunk, env)
    local paint = chunk()
    local button = assert(env.SurvivorsDragonUiSpellFxButton)
    assert(c.fxWrites == 0 and c.squareButton == button and button.clicks[1] == "LeftButtonUp")
    c:Call(button, "OnClick")
    assert(c.fx == "1" and c.fxWrites == 1, "button did not disable native spell visuals")
    c:Call(button, "OnClick")
    assert(c.fx == "0" and c.fxWrites == 2, "button did not restore native spell visuals")
    c.editing = true
    c:Call(button, "OnClick")
    assert(c.fxWrites == 2, "Layout editing toggled the game setting")
    c.editing = false
    c:ResetCounts()
    paint()
    c:NoPresentationWrites()
    assert(c.fxWrites == 2, "painting wrote the native preference")
    c.hidden = true
    local reads = c.fxReads
    paint()
    assert(c.fxReads == reads, "hidden button polled its CVar")
    c.hidden = false
    c:Call(button, "OnDragStart")
    assert(button:GetScript("OnUpdate"), "active edge dragging did not attach its pointer worker")
    c:Call(button, "OnDragStop")
    assert(not button:GetScript("OnUpdate"), "finished dragging retained an idle worker")
    c:Call(button, "OnClick")
    assert(c.fxWrites == 2, "drag release also toggled spell effects")
end
print("PASS minimap spell effects use click-only CVar writes, hidden deferral, editor guards and drag cleanup")
