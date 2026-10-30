-- CI only: production chat parsing/catalogs over fake native boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "marks fixtures require the CI Lua 5.1 interpreter")
local passed = 0
local function Test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ": " .. tostring(failure))
    passed = passed + 1
    print("PASS " .. name)
end

local function Chat()
    local context = H.New()
    context:Load("core/localization.lua")
    context:Load("localization/data.lua")
    context:Load("core/messages.lua")
    context:Load("modules/chat/prettify.lua", "ChatFormats")
    return context, context.env.DFRL.CleanerChat, context.env.DFRL.locale
end

local function Plain(text)
    text = string.gsub(text, "|H.-|h(.-)|h", "%1")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    return (string.gsub(text, "|r", ""))
end

local function Loot(settings)
    local context, chat, locale = Chat()
    local env = context.env
    env.SurvivorsDragonUiDisplay = settings
    env.DFRL.actionBarDefaults = { bottom = 55, height = 36, topInset = 14 }
    context:Load("core/display.lua", "Display")
    context:Load("core/hud.lua")
    env.GetItemInfo = function() error("a marks-only card must not read converted-item metadata") end
    context:Load("modules/ui/loot.lua", "LootNotifications")
    context:Load("modules/ui/loot_view.lua", "LootView")
    local animation
    for _, object in ipairs(context.objects) do
        if object.heading then
            local setPoint = object.SetPoint
            function object:SetPoint(...)
                self.stackAnchor = { ... }
                return setPoint(self, unpack(self.stackAnchor))
            end
        elseif object.kind == "Frame" and not object.name and not object.parent and not next(object.events) then
            animation = object
        end
    end
    assert(animation, "missing loot animation boundary")
    return context, chat, locale, context:Controller("CVAR_UPDATE"), animation
end

Test(
    "fractional Hogger rewards make one marks-only toast and two rewards stack with independent retail expiry",
    function()
        for _, performance in ipairs({ false, true }) do
            local context, chat, _, service, animation = Loot({ performanceMode = performance })
            local env = context.env
            local message =
                "You receive loot: |cff9d9d9d|Hitem:123:0:0:0|h[Footpad's Cover]|h|r (already collected) +0.5 marks"
            env.DFRL.loot.Observe(message, "CHAT_MSG_SYSTEM")
            local text, kind = chat.PrettifyMessage(message, "CHAT_MSG_SYSTEM")
            assert(text == nil and kind == "hide", "the converted item/reward remained in chat")
            context:Call(service, "OnUpdate", 0.2)
            local first
            for _, object in ipairs(context.objects) do
                if object.entry then first = object end
            end
            assert(first and first.heading:GetText() == "You received" and first.name:GetText() == "+0.5 Marks")
            assert(first.entry.collection == "collected" and first.entry.name == "Footpad's Cover")
            assert(
                first.icon:IsShown()
                    and first.iconPath == env.DFRL:GetInfoOrCons("tex") .. "loot\\Marks.blp"
                    and not first.border:IsShown()
                    and not first.retryAt,
                "marks did not reuse the selected coin in the existing slot without item rarity/metadata work"
            )
            local started, allocated = first.started, #context.objects
            context.now = started + 0.1
            context:Call(animation, "OnUpdate", 0.1)
            assert(math.abs(first:GetAlpha() - (performance and 1 or 0.5)) < 1e-12, "retail fade-in changed")
            local earned = "You earn 0.5 marks (85.7 in all)."
            env.DFRL.loot.Observe(earned, "CHAT_MSG_SYSTEM")
            text, kind = chat.PrettifyMessage(earned, "CHAT_MSG_SYSTEM")
            assert(text == nil and kind == "hide", "the duplicate marks balance remained in chat")
            context:Call(service, "OnUpdate", 0.2)
            assert(
                first.entry.sequence == 1 and first.started == started,
                "the balance notice replayed or restarted a toast"
            )
            assert(chat.PrettifyMessage(earned, "CHAT_MSG_PARTY") == earned, "conversation text was hidden")
            context.now = started + 1
            env.DFRL.loot.Observe("You receive loot: [Second item] (already collected) +1 marks", "CHAT_MSG_LOOT")
            context:Call(service, "OnUpdate", 0.2)
            local second, active = nil, 0
            for _, object in ipairs(context.objects) do
                if object.entry then
                    active = active + 1
                    if object ~= first then second = object end
                end
            end
            assert(
                active == 2 and second and second.name:GetText() == "+1 Mark",
                "rewards merged or singular wording changed"
            )
            assert(first.stackAnchor[1] == "BOTTOM" and first.stackAnchor[5] == 0)
            assert(
                second.stackAnchor[2] == first.stackAnchor[2] and second.stackAnchor[5] == 106,
                "retail stack gap changed"
            )
            assert(first.started == started and second.started == started + 1, "a second reward restarted the first")
            context.now = started + 4.75
            context:Call(animation, "OnUpdate", 3.75)
            assert(math.abs(first:GetAlpha() - (performance and 1 or 0.5)) < 1e-12, "retail fade-out changed")
            assert(second:GetAlpha() == 1, "the younger toast faded with the older one")
            context.now = started + 5.5
            context:Call(animation, "OnUpdate", 0.75)
            assert(not first.entry and second.entry and second.started == started + 1, "per-card expiry changed")
            assert(second.stackAnchor[5] == 0, "remaining toast did not close the empty stack slot")
            context:SetLayoutHidden(true)
            context.now = started + 6.5
            context:Call(animation, "OnUpdate", 1)
            context:SetLayoutHidden(false)
            assert(not second.entry and not animation:GetScript("OnUpdate"), "hidden reward replayed after expiry")
            assert(#context.objects == allocated, "stacking allocated replacement artwork")
        end
    end
)

Test("marks chat stays available when marks popups are off native or unready", function()
    local context, chat = Loot()
    local display = context.env.DFRL.display
    local message = "You receive loot: [Footpad's Cover] (already collected) +0.5 marks"
    local earned = "You earn 0.5 marks (85.7 in all)."
    local function Visible()
        assert(Plain(chat.PrettifyMessage(message)) == "+ [Footpad's Cover] +0.5 Marks")
        assert(Plain(chat.PrettifyMessage(earned)) == "+ 0.5 Marks - Total 85.7")
    end
    display.BeginEdit()
    display.Set("lootShowMarks", false)
    Visible()
    display.Set("lootShowMarks", true)
    for _, mode in ipairs({ "game", "off" }) do
        display.Set("lootMode", mode)
        Visible()
    end
    display.FinishEdit(false)
    context.env.DFRL.loot.SetRenderer(nil)
    Visible()
end)

Test("collected item marks keep the original item link and reward without its collection suffix", function()
    local _, chat = Chat()
    local reference = "item:123:0:0:0"
    local item = "|cff9d9d9d|H" .. reference .. "|h[Footpad's Cover]|h|r"
    local message = "You receive loot: " .. item .. " |cff787878(already collected)|r |cffffb226+1 marks|r"
    local entry = assert(chat.ParseLootMessage(message))
    assert(entry.collection == "collected" and entry.marks == "1", "conversion reward lost its collection identity")
    assert(entry.name == "Footpad's Cover" and entry.itemReference == reference, "native item identity changed")
    local displayed, kind = chat.PrettifyMessage(message, "CHAT_MSG_SYSTEM")
    assert(kind ~= "hide" and Plain(displayed) == "+ [Footpad's Cover] +1 Mark", "item-plus-marks format differs")
    assert(string.find(displayed, item, 1, true), "original link, brackets or quality color were rewritten")
end)

Test("collected items without a positive reward stay hidden and unknown suffixes stay native", function()
    local _, chat = Chat()
    for _, suffix in ipairs({
        " (already collected)",
        " (already collected) +0 marks",
        " (already collected) +0.00 marks",
    }) do
        local displayed, kind = chat.PrettifyMessage("You receive loot: [Footpad's Cover]" .. suffix)
        assert(displayed == nil and kind == "hide", "a duplicate without marks became visible")
    end
    for _, suffix in ipairs({ " (already collected) +1 gold", " (already collected) +1 marks extra" }) do
        local message = "You receive loot: [Footpad's Cover]" .. suffix
        assert(chat.PrettifyMessage(message) == message, "an unknown reward suffix was rewritten or hidden")
    end
    assert(
        Plain(chat.PrettifyMessage("You receive loot: [Footpad's Cover] New in your collection!"))
            == "+Footpad's Cover New in your collection!",
        "ordinary new-loot formatting changed"
    )
end)

Test("earned marks preserve native amounts and totals and respect chat event scope", function()
    local _, chat = Chat()
    local message = "You earn 1 marks (4 in all)."
    for _, event in ipairs({ "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT" }) do
        assert(Plain(chat.PrettifyMessage(message, event)) == "+ 1 Mark - Total 4", "single-mark summary differs")
    end
    assert(
        Plain(chat.PrettifyMessage("You earn 2 marks (4294967296 in all).")) == "+ 2 Marks - Total 4294967296",
        "a plural amount or large native total was changed"
    )
    assert(
        Plain(chat.PrettifyMessage("You earn 0.5 marks (85.7 in all).")) == "+ 0.5 Marks - Total 85.7",
        "fractional native amounts or totals were changed"
    )
    assert(
        Plain(chat.PrettifyMessage("You earn 01.00 marks (86.70 in all).")) == "+ 01.00 Mark - Total 86.70",
        "decimal singular wording or original numeric strings were changed"
    )
    for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_PARTY", "CHAT_MSG_MONSTER_YELL" }) do
        assert(chat.PrettifyMessage(message, event) == message, "player/NPC conversation was treated as currency")
    end
    for _, unknown in ipairs({
        "You earn -1 marks (4 in all).",
        "You earn 1.5.0 marks (4 in all).",
        "You earn .5 marks (4 in all).",
        "You earn 1 marks (-4 in all).",
        "You earn 1 marks (four in all).",
        "Prefix: You earn 1 marks (4 in all).",
    }) do
        assert(chat.PrettifyMessage(unknown) == unknown, "an unsupported currency message was guessed")
    end
end)

Test("both marks producers match every shipped native language template", function()
    local _, chat, locale = Chat()
    local languages = 0
    for code in pairs(locale.data) do
        locale.Select(code)
        languages = languages + 1
        for _, amount in ipairs({ "2", "0.5" }) do
            local message = locale.Native("You receive loot:")
                .. " [Item] ("
                .. locale.Native("already collected")
                .. ") "
                .. locale.Native("marks.gained", { n = amount })
            local entry = assert(chat.ParseLootMessage(message), "missing combined template for " .. code)
            assert(entry.collection == "collected" and entry.marks == amount, "wrong conversion reward for " .. code)
            local earned = locale.Native("marks.earned", { n = amount, total = "17.5" })
            assert(
                Plain(chat.PrettifyMessage(earned))
                    == "+ " .. amount .. " " .. locale.Text("Marks") .. " - " .. locale.Text("Total") .. " 17.5",
                "wrong marks summary for " .. code
            )
        end
    end
    assert(languages == 14, "not all native language catalogs were exercised")
end)

Test("marks checkbox off excludes conversions before popup metadata reads", function()
    local context = Chat()
    local env = context.env
    env.SurvivorsDragonUiDisplay = { lootShowMarks = false }
    context:Load("core/display.lua", "Display")
    context:Load("core/hud.lua")
    context:Load("modules/ui/loot.lua", "LootNotifications")
    local delivered, metadataReads = 0, 0
    env.GetItemInfo = function()
        metadataReads = metadataReads + 1
        error("a duplicate item must not resolve popup metadata")
    end
    assert(
        env.DFRL.loot.SetRenderer({
            IsReady = function() return true end,
            Push = function()
                delivered = delivered + 1
                return true
            end,
            Clear = function() end,
        }),
        "mock loot renderer did not acquire the native boundary"
    )
    for _, amount in ipairs({ "1", "0.5" }) do
        env.DFRL.loot.Observe(
            "You receive loot: |Hitem:123:0:0:0|h[Footpad's Cover]|h (already collected) +" .. amount .. " marks",
            "CHAT_MSG_SYSTEM"
        )
    end
    context:Call(context:Controller("CVAR_UPDATE"), "OnUpdate", 0.2)
    assert(
        delivered == 0 and metadataReads == 0,
        "a marks conversion displayed or resolved an already-owned item popup"
    )
end)

print("PASS " .. passed .. " marks chat contracts")
