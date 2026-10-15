-- Fixed CleanerChat formatting, adapted for the original Lua 5.0 chat API.
-- The chat renderer supplies the native event name when one is available.
-- Unknown game announcements and errors always retain their original text.
DFRL.CleanerChat = DFRL.CleanerChat or {}
local CleanerChat = DFRL.CleanerChat
local GREEN = "|cff80d180"
local RED = "|cffe88888"
local GRAY = "|cffaaaaaa"
local WHITE = "|cfffafafa"
local YELLOW = "|cffdfba69"
local PLUS = GREEN .. "+|r"
local MINUS = RED .. "-|r "

local conversations = {
    CHAT_MSG_SAY = true,
    CHAT_MSG_YELL = true,
    CHAT_MSG_EMOTE = true,
    CHAT_MSG_TEXT_EMOTE = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true,
    CHAT_MSG_GUILD = true,
    CHAT_MSG_OFFICER = true,
    CHAT_MSG_WHISPER = true,
    CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_CHANNEL = true,
    CHAT_MSG_MONSTER_SAY = true,
    CHAT_MSG_MONSTER_YELL = true,
    CHAT_MSG_MONSTER_WHISPER = true,
    CHAT_MSG_MONSTER_EMOTE = true,
    CHAT_MSG_AFK = true,
    CHAT_MSG_DND = true,
    CHAT_MSG_IGNORED = true,
    CHAT_MSG_ADDON = true,
}

local patternCharacters = {
    ["^"] = true,
    ["$"] = true,
    ["("] = true,
    [")"] = true,
    ["%"] = true,
    ["."] = true,
    ["["] = true,
    ["]"] = true,
    ["*"] = true,
    ["+"] = true,
    ["-"] = true,
    ["?"] = true,
}
local compiledFormats = {}

-- Escape the literal portions of localized GlobalStrings instead of treating
-- punctuation as Lua patterns. Positional %2$s/%1$d formats keep argument order.
local function CompileFormat(formatText, anchored)
    if type(formatText) ~= "string" or formatText == "" then return nil end
    local key = (anchored and "a:" or "p:") .. formatText
    if compiledFormats[key] then return compiledFormats[key] end
    local pattern = anchored and "^" or ""
    local slots = {}
    local cursor = 1
    local sequential = 0
    while cursor <= string.len(formatText) do
        local character = string.sub(formatText, cursor, cursor)
        if character == "%" then
            local remainder = string.sub(formatText, cursor)
            local first, last, position, kind = string.find(remainder, "^%%(%d+)%$([sd])")
            if not first then
                first, last, kind = string.find(remainder, "^%%[0-9%.%-+]*([sd])")
                position = nil
            end
            if first then
                sequential = sequential + 1
                table.insert(slots, tonumber(position) or sequential)
                pattern = pattern .. (kind == "d" and "(%d+)" or "(.-)")
                cursor = cursor + last
            elseif string.sub(remainder, 1, 2) == "%%" then
                pattern = pattern .. "%%"
                cursor = cursor + 2
            else
                pattern = pattern .. "%%"
                cursor = cursor + 1
            end
        else
            pattern = pattern .. (patternCharacters[character] and "%" or "") .. character
            cursor = cursor + 1
        end
    end
    if anchored then pattern = pattern .. "$" end
    local compiled = { pattern = pattern, slots = slots }
    compiledFormats[key] = compiled
    return compiled
end

local function CaptureFormat(text, formatText, anchored)
    local compiled = CompileFormat(formatText, anchored)
    if not compiled then return nil end
    local first, last, a, b, c, d = string.find(text, compiled.pattern)
    if not first then return nil end
    local captures = { a, b, c, d }
    local arguments = {}
    for i = 1, table.getn(compiled.slots) do
        arguments[compiled.slots[i]] = captures[i]
    end
    return arguments[1], arguments[2], arguments[3], arguments[4]
end

local function GlobalFormat(name, fallback) return _G[name] or fallback end

local function CompactItem(text)
    if not text then return text end
    -- Only alter the displayed label, preserving complete clickable item data.
    return (string.gsub(text, "(|Hitem:[^|]+|h)%[([^|]-)%](|h)", "%1%2%3"))
end

local function ItemGain(item, count)
    local text = PLUS .. CompactItem(item)
    count = tonumber(count)
    if count and count > 1 then text = text .. GRAY .. " (" .. count .. ")|r" end
    return text
end

local function OtherItemGain(name, item, count)
    local text = name .. GRAY .. ":|r " .. CompactItem(item)
    count = tonumber(count)
    if count and count > 1 then text = text .. GRAY .. " (" .. count .. ")|r" end
    return text
end

local function XP(amount, source)
    local text = PLUS .. WHITE .. amount .. "|r " .. (_G.XP or "XP")
    if source and source ~= "" then text = text .. GRAY .. ":|r " .. YELLOW .. source .. "|r" end
    return text
end

local function Reputation(faction, amount, loss)
    return (loss and MINUS or PLUS)
        .. WHITE
        .. amount
        .. "|r "
        .. (_G.REPUTATION or "Reputation")
        .. GRAY
        .. ":|r "
        .. faction
end

local lootRules = {
    { "LOOT_ITEM_CREATED_SELF_MULTIPLE", "You create: %sx%d.", ItemGain },
    { "LOOT_ITEM_CREATED_SELF", "You create: %s.", ItemGain },
    { "LOOT_ITEM_SELF_MULTIPLE", "You receive loot: %sx%d.", ItemGain },
    { "LOOT_ITEM_SELF", "You receive loot: %s.", ItemGain },
    { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "You receive item: %sx%d.", ItemGain },
    { "LOOT_ITEM_PUSHED_SELF", "You receive item: %s.", ItemGain },
    { "LOOT_ITEM_MULTIPLE", "%s receives loot: %sx%d.", OtherItemGain },
    { "LOOT_ITEM", "%s receives loot: %s.", OtherItemGain },
    { "LOOT_ITEM_PUSHED_MULTIPLE", "%s receives item: %sx%d.", OtherItemGain },
    { "LOOT_ITEM_PUSHED", "%s receives item: %s.", OtherItemGain },
}

local function ApplyRules(text, rules)
    for _, rule in ipairs(rules) do
        local a, b, c, d = CaptureFormat(text, GlobalFormat(rule[1], rule[2]), true)
        if a then return rule[3](a, b, c, d) end
    end
    return nil
end

local function PrettifyNumber(number)
    local text = tostring(number)
    local replacements
    repeat
        text, replacements = string.gsub(text, "^(%d+)(%d%d%d)", "%1 %2")
    until replacements == 0
    return text
end

local function FormatMoney(text)
    local gold = CaptureFormat(text, GlobalFormat("GOLD_AMOUNT", "%d Gold"), false)
    local silver = CaptureFormat(text, GlobalFormat("SILVER_AMOUNT", "%d Silver"), false)
    local copper = CaptureFormat(text, GlobalFormat("COPPER_AMOUNT", "%d Copper"), false)
    if not gold and not silver and not copper then return nil end
    local parts = {}
    if gold then table.insert(parts, YELLOW .. PrettifyNumber(tonumber(gold)) .. "g|r") end
    if silver then table.insert(parts, "|cffc0c0c0" .. silver .. "s|r") end
    if copper then table.insert(parts, "|cffb88b61" .. copper .. "c|r") end
    return PLUS .. table.concat(parts, " ")
end

local function FormatGameNotice(text, eventName)
    -- Ordinary player/NPC dialogue never enters the system-message rules.
    if conversations[eventName] then return text end
    if string.find(text, "|Huierror", 1, true) or string.find(text, "|Hquestie", 1, true) then return text end
    local result
    if not eventName or eventName == "CHAT_MSG_LOOT" then
        result = ApplyRules(text, lootRules)
        if result then return result end
    end
    if not eventName or eventName == "CHAT_MSG_MONEY" then
        local amount = CaptureFormat(text, GlobalFormat("YOU_LOOT_MONEY", "You loot %s."), true)
        if not amount then
            amount = CaptureFormat(text, GlobalFormat("LOOT_MONEY_SPLIT", "Your share of the loot is %s."), true)
        end
        if amount then return FormatMoney(amount) or text end
    end
    if not eventName or eventName == "CHAT_MSG_COMBAT_XP_GAIN" then
        local source, amount =
            CaptureFormat(text, GlobalFormat("COMBATLOG_XPGAIN_FIRSTPERSON", "%s dies, you gain %d experience."), true)
        if source and amount then return XP(amount, source) end
        amount =
            CaptureFormat(text, GlobalFormat("COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED", "You gain %d experience."), true)
        if amount then return XP(amount) end
    end
    if not eventName or eventName == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        local faction, amount = CaptureFormat(
            text,
            GlobalFormat("FACTION_STANDING_INCREASED", "Your %s reputation has increased by %d."),
            true
        )
        if faction and amount then return Reputation(faction, amount, false) end
        faction, amount = CaptureFormat(
            text,
            GlobalFormat("FACTION_STANDING_DECREASED", "Your %s reputation has decreased by %d."),
            true
        )
        if faction and amount then return Reputation(faction, amount, true) end
    end
    if not eventName or eventName == "CHAT_MSG_SKILL" then
        local skill, rank =
            CaptureFormat(text, GlobalFormat("SKILL_RANK_UP", "Your skill in %s has increased to %d."), true)
        if skill and rank then return PLUS .. skill .. GRAY .. ":|r " .. WHITE .. rank .. "|r" end
    end
    if eventName and eventName ~= "CHAT_MSG_SYSTEM" then return text end

    local label = CaptureFormat(text, GlobalFormat("ERR_QUEST_ACCEPTED_S", "Quest accepted: %s"), true)
    if label then return PLUS .. (_G.ACCEPTED or "Accepted") .. GRAY .. ":|r " .. YELLOW .. label .. "|r" end
    label = CaptureFormat(text, GlobalFormat("ERR_QUEST_COMPLETE_S", "%s completed."), true)
    if label then return PLUS .. (_G.COMPLETE or "Complete") .. GRAY .. ":|r " .. YELLOW .. label .. "|r" end
    local amount = CaptureFormat(text, GlobalFormat("ERR_QUEST_REWARD_EXP_I", "Experience gained: %d."), true)
    if amount then return XP(amount) end
    local source
    source, amount =
        CaptureFormat(text, GlobalFormat("ERR_ZONE_EXPLORED_XP", "Discovered %s: %d experience gained"), true)
    if source and amount then return XP(amount, source) end
    amount = CaptureFormat(text, GlobalFormat("LEVEL_UP", "Congratulations, you have reached level %d!"), true)
    if amount then return YELLOW .. "Level " .. amount .. "|r" end

    -- Preserve learned/unlearned abilities and talent gains: they are meaningful
    -- run progression in this game, unlike the original server-specific filter.
    local spellRules = {
        { "ERR_LEARN_ABILITY_S", "You have learned a new ability: %s.", PLUS .. "Ability" },
        { "ERR_LEARN_PASSIVE_S", "You have learned a new passive effect: %s.", PLUS .. "Passive" },
        { "ERR_LEARN_SPELL_S", "You have learned a new spell: %s.", PLUS .. "Spell" },
        { "ERR_LEARN_RECIPE_S", "You have learned how to create a new item: %s.", PLUS .. "Recipe" },
        { "ERR_SPELL_UNLEARNED_S", "You have unlearned %s.", MINUS .. "Spell" },
    }
    for _, rule in ipairs(spellRules) do
        label = CaptureFormat(text, GlobalFormat(rule[1], rule[2]), true)
        if label then return rule[3] .. GRAY .. ":|r " .. label end
    end

    if text == GlobalFormat("MARKED_AFK", "You are now AFK.") then return YELLOW .. "+Away|r" end
    if text == GlobalFormat("CLEARED_AFK", "You are no longer AFK.") then return GREEN .. "- Away|r" end
    if text == GlobalFormat("CLEARED_DND", "You are no longer marked DND.") then return GREEN .. "- Busy|r" end
    label = CaptureFormat(text, GlobalFormat("MARKED_AFK_MESSAGE", "You are now AFK: %s"), true)
    if label then return YELLOW .. "+Away:|r " .. label end
    label = CaptureFormat(text, GlobalFormat("MARKED_DND", "You are now DND: %s."), true)
    if label then return YELLOW .. "+Busy:|r " .. label end
    return text
end

local groupTags = {
    { "CHAT_GUILD_GET", "Guild", "G" },
    { "CHAT_OFFICER_GET", "Officer", "O" },
    { "CHAT_PARTY_GET", "Party", "P" },
    { "CHAT_RAID_GET", "Raid", "R" },
    { "CHAT_RAID_LEADER_GET", "Raid Leader", "RL" },
    { "CHAT_RAID_WARNING_GET", "Raid Warning", "!" },
}

local function FormatChannel(number, name) return number .. ". [" .. string.upper(string.sub(name, 1, 1)) .. "]" end

local function FormatChannels(text)
    -- Native channel hyperlink payloads remain unchanged and clickable.
    text = string.gsub(
        text,
        "(|Hchannel:[^|]+|h)%[(%d+)%. ([^%]|]+)%](|h)",
        function(open, number, name, close) return open .. FormatChannel(number, name) .. close end
    )
    local color = ""
    if string.find(text, "^|c%x%x%x%x%x%x%x%x") then
        color = string.sub(text, 1, 10)
        text = string.sub(text, 11)
    end
    text = string.gsub(text, "^%[(%d+)%. ([^%]|]+)%]", FormatChannel)
    for _, tag in ipairs(groupTags) do
        local localized = _G[tag[1]]
        local first, last, name
        if localized then
            first, last, name = string.find(localized, "%[([^%]]+)%]")
        end
        name = name or tag[2]
        local escaped = ""
        for i = 1, string.len(name) do
            local char = string.sub(name, i, i)
            escaped = escaped .. (patternCharacters[char] and "%" or "") .. char
        end
        text = string.gsub(text, "^%[" .. escaped .. "%]", "[" .. tag[3] .. "]")
        text = string.gsub(text, "(|Hchannel:[^|]+|h)%[" .. escaped .. "%](|h)", "%1[" .. tag[3] .. "]%2")
    end
    return color .. text
end

local classUnits = { "player", "target", "targettarget", "mouseover" }
for i = 1, 4 do
    table.insert(classUnits, "party" .. i)
end
for i = 1, 40 do
    table.insert(classUnits, "raid" .. i)
end

local function ClassColoredName(name)
    name = string.gsub(name, "^%a", string.upper)
    if not UnitExists or not UnitIsPlayer or not UnitName or not UnitClass or not RAID_CLASS_COLORS then return name end
    for _, unit in ipairs(classUnits) do
        if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit) == name then
            local localized, class = UnitClass(unit)
            local color = class and RAID_CLASS_COLORS[class]
            if color then
                return string.format(
                    "|cff%02x%02x%02x%s|r",
                    math.floor(color.r * 255),
                    math.floor(color.g * 255),
                    math.floor(color.b * 255),
                    name
                )
            end
            return name
        end
    end
    return name
end

local function FormatPlayerLinks(text)
    return (
        string.gsub(text, "(|Hplayer:[^|]+|h)(.-)(|h)", function(open, name, close)
            local first, last, bare = string.find(name, "^%[(.-)%]$")
            name = bare or name
            if string.find(name, "|", 1, true) then
                name = string.gsub(
                    name,
                    "^(|c%x%x%x%x%x%x%x%x)(%a)",
                    function(color, initial) return color .. string.upper(initial) end
                )
            else
                name = ClassColoredName(name)
            end
            return open .. name .. close
        end)
    )
end

local function LinkifyPlainText(text)
    local output = ""
    local cursor = 1
    local lower = string.lower(text)
    while cursor <= string.len(text) do
        local first
        for _, prefix in ipairs({ "http://", "https://", "www." }) do
            local position = string.find(lower, prefix, cursor, true)
            if position and (not first or position < first) then first = position end
        end
        if not first then
            output = output .. string.sub(text, cursor)
            break
        end
        local previous = string.sub(text, first - 1, first - 1)
        if first > 1 and (string.find(previous, "[%w_/@]") ~= nil) then
            output = output .. string.sub(text, cursor, first)
            cursor = first + 1
        else
            local boundary = string.find(text, "[%s|]", first)
            local last = boundary and boundary - 1 or string.len(text)
            while last >= first and string.find(string.sub(text, last, last), "[.,;!%?%)%]]") do
                last = last - 1
            end
            local url = string.sub(text, first, last)
            output = output .. string.sub(text, cursor, first - 1)
            local hasAddress = string.find(string.lower(url), "^https?://[^/]+")
                or (string.find(string.lower(url), "^www%.") and string.len(url) > 4)
            if hasAddress then
                output = output .. "|Hurl:" .. url .. "|h[" .. url .. "]|h"
            else
                output = output .. url
            end
            cursor = last + 1
        end
    end
    return output
end

-- Process only text outside existing hyperlink payloads and displayed labels.
function CleanerChat.LinkifyURLs(text)
    if type(text) ~= "string" then return text end
    local output = ""
    local cursor = 1
    while cursor <= string.len(text) do
        local open = string.find(text, "|H", cursor, true)
        if not open then
            output = output .. LinkifyPlainText(string.sub(text, cursor))
            break
        end
        output = output .. LinkifyPlainText(string.sub(text, cursor, open - 1))
        local label = string.find(text, "|h", open + 2, true)
        local close = label and string.find(text, "|h", label + 2, true)
        if not close then
            output = output .. string.sub(text, open)
            break
        end
        output = output .. string.sub(text, open, close + 1)
        cursor = close + 2
    end
    return output
end

function CleanerChat.FilterMessage(text, eventName)
    if type(text) ~= "string" or not string.find(text, "%S") then return nil end
    text = FormatGameNotice(text, eventName)
    text = FormatChannels(text)
    text = FormatPlayerLinks(text)
    return CleanerChat.LinkifyURLs(text)
end
