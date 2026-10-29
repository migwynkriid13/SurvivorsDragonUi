-- CI only: real chat initializers over explicit stock-chat boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "default-chat fixtures require CI Lua 5.1")

local function Boot(defaultChat, presentation)
    local c = H.New()
    local env, priorities = c.env, {}
    env.SurvivorsDragonUiDisplay = { defaultChat = defaultChat }
    env.SurvivorsDragonUiCopyEnabled = true
    env.DFRL.locale.Native = function(key) return key end
    env.DFRL.locale.Match = function() return nil end
    local native = env.CreateFrame("ScrollingMessageFrame", "ChatFrame1", env.UIParent)
    env.ChatFrame1Tab = env.CreateFrame("Button", "ChatFrame1Tab", env.UIParent)
    env.ChatFrameEditBox = env.CreateFrame("EditBox", "ChatFrameEditBox", env.UIParent)
    native.AddMessage = function(_, text)
        c.stockMessage = text
        return "stock"
    end
    local nativeEvent = function() c.stockEvent = true end
    native:SetScript("OnEvent", nativeEvent)
    local originals = { add = native.AddMessage, alpha = native.SetAlpha, event = nativeEvent }
    env.ChatEdit_UpdateHeader = function() end
    originals.header = env.ChatEdit_UpdateHeader
    env.SlashCmdList = { STOCK = function() end }
    local register = env.DFRL.NewMod
    function env.DFRL:NewMod(name, priority, callback)
        priorities[name] = priority
        register(self, name, priority, callback)
    end
    c:Load("core/messages.lua")
    c:Load("core/display.lua", "Display")
    local allocated = #c.objects
    c:ResetCounts()
    for _, file in ipairs({ "prettify", "capture", "copy", "chat" }) do
        c:Load("modules/chat/" .. file .. ".lua")
    end
    assert(priorities.Display < priorities.ChatFormats and priorities.ChatFormats < priorities.ChatCapture)
    assert(priorities.ChatCapture < priorities.ChatCopy and priorities.ChatCopy < priorities.Chat)
    for _, name in ipairs({ "ChatFormats", "ChatCapture", "ChatCopy", "Chat" }) do
        if name ~= "Chat" or presentation then c.modules[name]() end
    end
    if defaultChat then
        assert(#c.objects == allocated, "default chat allocated a custom frame, collector or Copy dialog")
        assert(env.DFRL.CleanerChat == nil, "default chat retained custom formatters/capture/presentation")
        assert(native.AddMessage == originals.add and native.SetAlpha == originals.alpha)
        assert(native:GetScript("OnEvent") == originals.event and env.ChatEdit_UpdateHeader == originals.header)
        assert(native:GetParent() == env.UIParent and env.ChatFrame1Tab:IsShown())
        assert(env.ChatFrameEditBox:IsShown() and not c.layoutFrame, "native chat acquired a custom Layout owner")
        assert(not env.SlashCmdList.SURVIVORSDRAGONUICOPY and not env.SLASH_SURVIVORSDRAGONUICOPY1)
        assert(env.SurvivorsDragonUiCopyEnabled == true, "default chat erased the explicit Copy preference")
        c:NoPresentationWrites()
    end
    return c, native, originals
end

local c, native = Boot(true, true)
local env, display = c.env, c.env.DFRL.display
assert(native:AddMessage("Unchanged native message") == "stock" and c.stockMessage == "Unchanged native message")
assert(not display.Copy({ defaultChat = "true" }).defaultChat and not display.Copy({}).defaultChat)
display.BeginEdit()
display.Set("defaultChat", false)
assert(not display.Get("defaultChat") and env.SurvivorsDragonUiDisplay.defaultChat, "preview saved before Confirm")
assert(not env.DFRL.CleanerChat, "a reload-only draft partially initialized custom chat")
display.FinishEdit(false)
assert(display.Get("defaultChat"), "Cancel lost the confirmed default-chat choice")
display.BeginEdit()
display.Load({ defaultChat = false })
display.FinishEdit(false)
assert(display.Get("defaultChat"), "profile Cancel lost default chat")
display.BeginEdit()
display.Set("defaultChat", false)
display.FinishEdit(true)
assert(
    not env.SurvivorsDragonUiDisplay.defaultChat and not env.DFRL.CleanerChat,
    "Confirm changed the running chat before reload"
)
display.Reset()
assert(
    not display.Get("defaultChat") and env.SurvivorsDragonUiCopyEnabled,
    "reset changed defaults or the Copy preference"
)
print(
    "PASS default chat skips every chat initializer and preserves native methods, scripts, input and transactional reload-only choices"
)

local custom = Boot(false, false)
assert(custom.env.DFRL.CleanerChat.PrettifyMessage and custom.env.DFRL.CleanerChat.IsCaptureEnabled())
assert(custom.env.SlashCmdList.SURVIVORSDRAGONUICOPY, "returning to custom chat did not restore Copy")
assert(custom.env.DFRL.CleanerChat.PrettifyMessage("Party text", "CHAT_MSG_PARTY") == "Party text")

local a, b = {}, {}
local messages = custom.env.DFRL.messages
assert(messages.FirstDelivery(a, "same", "CHAT_MSG_SYSTEM", "", "same"))
assert(not messages.FirstDelivery(b, "same", "CHAT_MSG_SYSTEM", "", "same"), "shared delivery duplicated one broadcast")
assert(
    messages.FirstDelivery(a, "same", "CHAT_MSG_SYSTEM", "", "same"),
    "shared delivery dropped a repeated native message"
)
custom.now = custom.now + 1
assert(messages.FirstDelivery(b, "same", "CHAT_MSG_SYSTEM", "", "same"), "a later delivery inherited an old count")
print(
    "PASS custom chat restores its format/capture/Copy initializers and shared delivery retains native broadcast semantics"
)

local function Loot(defaultChat)
    local context, frame, original = Boot(defaultChat, false)
    context:Load("core/hud.lua")
    context:Load("modules/ui/loot.lua", "LootNotifications")
    local pushed = {}
    context.env.DFRL.loot.SetRenderer({
        IsReady = function() return true end,
        Push = function(entry)
            table.insert(pushed, entry)
            return true
        end,
        Clear = function() end,
    })
    return context, context:Controller("CVAR_UPDATE"), pushed, frame, original
end
local lootContext, controller, pushed, stock, original = Loot(true)
assert(controller.events.CHAT_MSG_LOOT and controller.events.CHAT_MSG_SYSTEM, "independent loot intake did not attach")
lootContext:Event(controller, "CHAT_MSG_LOOT", "You receive loot: [Native Band].")
lootContext:Call(controller, "OnUpdate", 0.2)
assert(#pushed == 1 and pushed[1].name == "Native Band", "default chat stopped independent SDUI loot delivery")
assert(
    stock.AddMessage == original.add and not lootContext.env.DFRL.CleanerChat,
    "loot intake initialized or hooked custom chat"
)
local lootDisplay = lootContext.env.DFRL.display
lootDisplay.BeginEdit()
lootDisplay.Set("lootMode", "game")
assert(
    not controller.events.CHAT_MSG_LOOT and not controller.events.CHAT_MSG_SYSTEM,
    "Game loot retained custom message intake"
)
lootDisplay.Set("lootMode", "off")
assert(not controller.events.CHAT_MSG_LOOT, "Off loot retained custom message intake")
lootDisplay.FinishEdit(false)
assert(controller.events.CHAT_MSG_LOOT, "Cancel did not restore independent loot intake")
lootContext:Event(controller, "PLAYER_LEAVING_WORLD")
assert(
    not controller.events.CHAT_MSG_LOOT and not controller.events.CHAT_MSG_SYSTEM,
    "world cleanup retained loot intake"
)
lootContext:Event(controller, "PLAYER_ENTERING_WORLD")
assert(controller.events.CHAT_MSG_LOOT, "world entry did not restore the independent native feed")
local _, customController = Loot(false)
assert(
    not customController.events.CHAT_MSG_LOOT and not customController.events.CHAT_MSG_SYSTEM,
    "custom chat gained duplicate event intake"
)
print("PASS native chat keeps independent loot delivery with active-only event subscriptions and no chat hooks")
