-- Selected incoming-message formats from CleanerChat's Output.lua,
-- Experience.lua and Loot.lua, adapted for Lua 5.0 and native Survivors notices.
-- Learned abilities remain visible with the explicitly requested compact label.
-- Unknown messages and player conversations keep their original text.
DFRL.CleanerChat = DFRL.CleanerChat or {}
local CleanerChat = DFRL.CleanerChat

-- CleanerChat's quest.green, quest.yellow, highlight and quest.gray colors.
local GREEN = "|cff59c959"
local YELLOW = "|cffffb226"
local WHITE = "|cfffafafa"
local GRAY = "|cff787878"
local RED = "|cffcc1a1a"
-- Every prettified gain joins '+' directly to its value or item label.
local PLUS = GREEN .. "+|r"

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
local patterns = {}

-- Match localized GlobalStrings literally, preserving positional arguments.
local function CaptureFormat(text, formatText)
    if type(formatText) ~= "string" or formatText == "" then return nil end
    local compiled = patterns[formatText]
    if not compiled then
        local pattern, slots, cursor, sequential = "^", {}, 1, 0
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
        compiled = { pattern = pattern .. "$", slots = slots }
        patterns[formatText] = compiled
    end
    local first, last, a, b, c, d = string.find(text, compiled.pattern)
    if not first then return nil end
    local captures, arguments = { a, b, c, d }, {}
    for i = 1, table.getn(compiled.slots) do
        arguments[compiled.slots[i]] = captures[i]
    end
    return arguments[1], arguments[2], arguments[3], arguments[4]
end

local function StatGain(amount, label) return PLUS .. WHITE .. amount .. "|r " .. GREEN .. label .. "|r" end

local abilityFormats = {
    { "ERR_LEARN_ABILITY_S", "You have learned a new ability: %s." },
    { "ERR_LEARN_SPELL_S", "You have learned a new spell: %s." },
    { "ERR_LEARN_PASSIVE_S", "You have learned a new passive effect: %s." },
    { "ERR_SKILL_GAINED_S", "You have gained the %s skill." },
    { "ERR_SKILL_UP_SI", "Your skill in %s has increased to %d." },
    { "SKILL_RANK_UP", "Your skill in %s has increased to %d." },
}

local function AbilityMessage(text)
    -- Trained spell ranks use the learned formats in 1.12. Capture the entire
    -- name (including its rank or link), while skill increases omit the counter.
    for _, rule in ipairs(abilityFormats) do
        local name = CaptureFormat(text, _G[rule[1]]) or CaptureFormat(text, rule[2])
        if name then
            name = string.gsub(name, "^%s+", "")
            name = string.gsub(name, "%s+$", "")
            if string.find(name, "%S") then return PLUS .. name end
        end
    end
    return nil
end

local GUARDIAN_SLAIN = "is slain! Its lair yields treasure and its strength, and the other guardians grow stronger."

local function HiddenAnnouncement(text)
    if type(text) ~= "string" or string.find(text, "|Huierror", 1, true) then return false end
    local plain = string.gsub(text, "|H.-|h(.-)|h", "%1")
    plain = string.gsub(plain, "|c%x%x%x%x%x%x%x%x", "")
    plain = string.gsub(plain, "|r", "")
    plain = string.gsub(plain, "^[ \t]+", "")
    plain = string.gsub(plain, "[ \t]+$", "")
    if string.find(plain, "^DFRL: Error") then return false end
    if
        string.find(plain, " yells:", 1, true)
        or string.find(plain, " says:", 1, true)
        or string.find(plain, " whispers:", 1, true)
    then
        return false
    end
    if plain == GUARDIAN_SLAIN then return true end
    local guardian = CaptureFormat(plain, "%s " .. GUARDIAN_SLAIN)
    if guardian and string.find(guardian, "^[^\r\n]+$") then return true end
    -- Match announcement wording, never a mob-name whitelist. Some native
    -- emotes supply the speaker separately and only print the nameless body.
    return plain == "Swarm surrounds you!"
        or plain == "claims its lair once more."
        or plain == "enters the battlefield!"
        or plain == "refuses to fall!"
        or plain == "survive the onslaught!"
        or string.find(plain, "^[^\r\n]+ approaches!$") ~= nil
        or string.find(plain, "^[^\r\n]+ claims its lair once more%.$") ~= nil
        or string.find(plain, "^[^\r\n]+ enters the battlefield!$") ~= nil
        or string.find(plain, "^[^\r\n]+ refuses to fall!$") ~= nil
        or string.find(plain, "^[^\r\n]+ — survive the onslaught!$") ~= nil
        or string.find(plain, "^[^\r\n]+ – survive the onslaught!$") ~= nil
        or string.find(plain, "^[^\r\n]+ %- survive the onslaught!$") ~= nil
end

local function NpcYell(text, speaker, message)
    -- Native event data avoids depending on an English "yells" prefix or on
    -- any particular NPC name. Only transform the corresponding dialogue line.
    if
        type(speaker) == "string"
        and speaker ~= ""
        and type(message) == "string"
        and message ~= ""
        and string.find(text, speaker, 1, true)
        and string.sub(text, -string.len(message)) == message
    then
        local name = string.gsub(speaker, "|c%x%x%x%x%x%x%x%x", "")
        name = string.gsub(name, "|r", "")
        return RED .. name .. ":|r " .. message
    end
    -- Fallback for known NPC-yell events without supplied author/body fields.
    local first, last, name, body = string.find(text, "^(.+) yells: (.*)$")
    if first then
        name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
        name = string.gsub(name, "|r", "")
        return RED .. name .. ":|r " .. body
    end
    return text
end

local function TalentExperience(text)
    -- Capture the game's class label verbatim, including plural/compound names.
    -- Neither a class whitelist nor fixed XP/point amounts belong here.
    local first, last, class, experience, tail =
        string.find(text, "^Your (.-) earns? (%d[%d,]*) talent experience(.*)$")
    if not first or not string.find(class, "%S") then return nil end
    local output = PLUS .. WHITE .. experience .. "|r " .. WHITE .. "Talent XP:|r " .. YELLOW .. class .. "|r"
    if tail == "" or tail == "." or tail == "!" then return output end

    local pointFirst, pointLast, points, instruction = string.find(tail, "^:%s*(%d+) new talent points?!(.*)$")
    if not pointFirst then return nil end
    local prompt = string.gsub(instruction, "^%s+", "")
    prompt = string.gsub(prompt, "%.$", "")
    local armory = prompt == "Spend it in the armory" or prompt == "Spend them in the armory"
    if prompt ~= "" and not armory then return nil end

    local label = tonumber(points) == 1 and "Talent Point" or "Talent Points"
    output = output .. ", " .. StatGain(points, label)
    if armory then output = output .. GRAY .. " (Spend in armory)|r" end
    return output
end

local function ProgressMessage(text)
    local talent = TalentExperience(text)
    if talent then return talent end
    local level = CaptureFormat(text, _G.LEVEL_UP)
    if not level then
        local first, last, value = string.find(text, "^Congratulations, you have reached level (%d+)!$")
        level = value
    end
    -- Only the native plain-number announcement enters the levelup_ding format.
    if level and string.find(level, "^%d+$") then return YELLOW .. "Level " .. level .. "|r", "level" end

    -- Survivors combines the three gains into one notice. Apply the source
    -- levelup_stat/levelup_hp appearance to each gain without rounding decimals.
    local first, last, damage, health, regeneration = string.find(
        text,
        "^You have gained %+([%d%.]+)%% damage, %+([%d%.]+) maximum health and %+([%d%.]+) health per second%.?$"
    )
    if
        first
        and string.find(damage, "^%d+%.?%d*$")
        and string.find(health, "^%d+%.?%d*$")
        and string.find(regeneration, "^%d+%.?%d*$")
    then
        return StatGain(damage .. "%", "Damage") .. ", " .. StatGain(health, "HP") .. ", " .. StatGain(
            regeneration,
            "HP/sec"
        ),
            "level_stats"
    end
    return nil
end

local function ItemLabel(item)
    -- The source removes display brackets. Leave the full hyperlink payload,
    -- item-quality color and all other label characters intact.
    if string.find(item, "|Hitem:", 1, true) then
        return (
            string.gsub(
                item,
                "(|Hitem:[^|]+|h)(.-)(|h)",
                function(open, label, close) return open .. string.gsub(label, "[%[%]]", "") .. close end
            )
        )
    end
    local first, last, color, name, reset = string.find(item, "^(|c%x%x%x%x%x%x%x%x)%[([^%]]+)%](|r)$")
    if first then return color .. name .. reset end
    return (string.gsub(item, "^%[([^%]]+)%]", "%1"))
end

local function LootMessage(text)
    local body = CaptureFormat(text, _G.LOOT_ITEM_SELF)
    if not body then
        local first, last = string.find(text, "You receive loot:", 1, true)
        if first then
            local prefix = string.sub(text, 1, first - 1)
            prefix = string.gsub(prefix, "|c%x%x%x%x%x%x%x%x", "")
            prefix = string.gsub(prefix, "|r", "")
            if prefix == "" then body = string.sub(text, last + 1) end
        end
    end
    if not body then return nil end
    body = string.gsub(body, "^%s+", "")
    -- A colored announcement prefix can leave its reset before the item.
    while string.sub(body, 1, 2) == "|r" do
        body = string.gsub(string.sub(body, 3), "^%s+", "")
    end

    local first, last, item, suffix = string.find(body, "^(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h.-|h)(.*)$")
    if not first then
        first, last, item, suffix = string.find(body, "^(|Hitem:[^|]+|h.-|h)(.*)$")
    end
    if not first then
        first, last, item, suffix = string.find(body, "^(|c%x%x%x%x%x%x%x%x%[[^%]]+%])(.*)$")
    end
    if not first then
        first, last, item, suffix = string.find(body, "^(%[[^%]]+%])(.*)$")
    end
    if not first then return nil end
    if string.sub(suffix, 1, 2) == "|r" then
        item, suffix = item .. "|r", string.sub(suffix, 3)
    elseif string.find(item, "^|c%x%x%x%x%x%x%x%x") then
        item = item .. "|r"
    end

    -- The supplied game adds an already-collected suffix to otherwise normal
    -- self-loot text. Preserve that fact and any existing suffix colors.
    local plainSuffix = string.gsub(suffix, "|c%x%x%x%x%x%x%x%x", "")
    plainSuffix = string.gsub(plainSuffix, "|r", "")
    if plainSuffix == "." then
        suffix = ""
    elseif plainSuffix ~= "" then
        if not string.find(plainSuffix, "^%s+%(already collected%)%.?$") then return nil end
        if suffix == plainSuffix then suffix = GRAY .. suffix .. "|r" end
    end
    return PLUS .. ItemLabel(item) .. suffix
end

CleanerChat.PrettifyMessage = function(text, eventName, speaker, message)
    if type(text) ~= "string" then return text end
    local announcementEvent = not eventName
        or eventName == "CHAT_MSG_SYSTEM"
        or eventName == "CHAT_MSG_MONSTER_EMOTE"
        or eventName == "CHAT_MSG_RAID_BOSS_EMOTE"
    if announcementEvent and (HiddenAnnouncement(text) or (eventName and HiddenAnnouncement(message))) then
        return nil, "hide"
    end
    if eventName == "CHAT_MSG_MONSTER_YELL" then return NpcYell(text, speaker, message) end
    -- The caller supplies an event while native Lua chat handlers run. Direct
    -- client writes have no event; only anchored, recognizable notices match.
    if
        eventName
        and eventName ~= "CHAT_MSG_SYSTEM"
        and eventName ~= "PLAYER_LEVEL_UP"
        and eventName ~= "CHAT_MSG_COMBAT_XP_GAIN"
        and eventName ~= "CHAT_MSG_LOOT"
        and eventName ~= "CHAT_MSG_SKILL"
    then
        return text
    end
    local result, kind
    if not eventName or eventName == "CHAT_MSG_SYSTEM" or eventName == "CHAT_MSG_SKILL" then
        result = AbilityMessage(text)
        if result then return result end
    end
    if
        not eventName
        or eventName == "CHAT_MSG_SYSTEM"
        or eventName == "PLAYER_LEVEL_UP"
        or eventName == "CHAT_MSG_COMBAT_XP_GAIN"
    then
        result, kind = ProgressMessage(text)
        if result then return result, kind end
    end
    -- Recognize native self-loot on the system channel as well as loot events.
    if not eventName or eventName == "CHAT_MSG_LOOT" or eventName == "CHAT_MSG_SYSTEM" then
        result = LootMessage(text)
        if result then return result end
    end
    return text
end
