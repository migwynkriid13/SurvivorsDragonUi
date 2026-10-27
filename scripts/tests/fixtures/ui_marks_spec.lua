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
    context:Load("modules/chat/prettify.lua")
    return context, context.env.DFRL.CleanerChat, context.env.DFRL.locale
end

local function Plain(text)
    text = string.gsub(text, "|H.-|h(.-)|h", "%1")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    return (string.gsub(text, "|r", ""))
end

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
    for _, suffix in ipairs({ " (already collected)", " (already collected) +0 marks" }) do
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
    for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_PARTY", "CHAT_MSG_MONSTER_YELL" }) do
        assert(chat.PrettifyMessage(message, event) == message, "player/NPC conversation was treated as currency")
    end
    for _, unknown in ipairs({
        "You earn -1 marks (4 in all).",
        "You earn 1.5 marks (4 in all).",
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
        local message = locale.Native("You receive loot:")
            .. " [Item] ("
            .. locale.Native("already collected")
            .. ") "
            .. locale.Native("marks.gained", { n = "2" })
        local entry = assert(chat.ParseLootMessage(message), "missing combined template for " .. code)
        assert(entry.collection == "collected" and entry.marks == "2", "wrong conversion reward for " .. code)
        local earned = locale.Native("marks.earned", { n = "2", total = "17" })
        assert(
            Plain(chat.PrettifyMessage(earned))
                == "+ 2 " .. locale.Text("Marks") .. " - " .. locale.Text("Total") .. " 17",
            "wrong marks summary for " .. code
        )
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
    env.DFRL.loot.Observe(
        "You receive loot: |Hitem:123:0:0:0|h[Footpad's Cover]|h (already collected) +1 marks",
        "CHAT_MSG_SYSTEM"
    )
    context:Call(context:Controller("CVAR_UPDATE"), "OnUpdate", 0.2)
    assert(
        delivered == 0 and metadataReads == 0,
        "a marks conversion displayed or resolved an already-owned item popup"
    )
end)

print("PASS " .. passed .. " marks chat contracts")
