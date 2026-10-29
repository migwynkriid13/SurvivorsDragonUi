-- Selected CleanerChat formats; attribution: third_party/CleanerChat-NOTICE.txt.
-- Default chat skips all formatter initialization after the UI reload.
DFRL:NewMod("ChatFormats", 0.25, function()
    if DFRL.display.Get("defaultChat") then return end
    DFRL.CleanerChat = DFRL.CleanerChat or {}
    local CleanerChat = DFRL.CleanerChat

    -- CleanerChat's quest.green, quest.yellow, highlight and quest.gray colors.
    local GREEN = "|cff59c959"
    local YELLOW = "|cffffb226"
    local WHITE = "|cfffafafa"
    local GRAY = "|cff787878"
    local RED = "|cffcc1a1a"
    -- Existing gains join '+' directly to their value; marks use the requested spacing.
    local PLUS = GREEN .. "+|r"

    local StripColors = DFRL.messages.StripColors
    local MarkCounts = DFRL.messages.MarkCounts

    local function MarkGain(amount, spaced)
        local unit = string.find(amount, "^0*1$") and "Mark" or "Marks"
        return PLUS .. (spaced and " " or "") .. WHITE .. amount .. "|r " .. YELLOW .. DFRL.locale.Text(unit) .. "|r"
    end

    local function MarksMessage(text)
        local amount, total = MarkCounts(StripColors(text), true)
        if not amount then return nil end
        return MarkGain(amount, true) .. " - " .. YELLOW .. DFRL.locale.Text("Total") .. "|r " .. WHITE .. total .. "|r"
    end

    local CaptureFormat = DFRL.messages.CaptureFormat

    local function StatGain(amount, label)
        return PLUS .. WHITE .. amount .. "|r " .. GREEN .. DFRL.locale.Text(label) .. "|r"
    end

    local function NumericGain(value)
        if type(value) ~= "string" then return nil end
        value = string.gsub(value, "^%+", "")
        if string.find(value, "^%d+$") or string.find(value, "^%d+[.,]%d+$") then return value end
        return nil
    end

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
        for _, key in ipairs({
            "%s approaches!",
            "%s enters the battlefield!",
            "%s claims its lair once more.",
            "%s refuses to fall!",
            "%s is slain! Its lair yields treasure and its strength, and the other guardians grow stronger.",
        }) do
            local native = DFRL.locale.Native(key)
            if CaptureFormat(plain, native) then return true end
            if string.sub(native, 1, 2) == "%s" and plain == string.gsub(native, "^%%s%s*", "") then return true end
        end
        for _, key in ipairs({
            "Swarm surrounds you!",
            "A stampede charges through!",
            "A wall of foes closes in!",
            "A pack hunts you!",
        }) do
            if plain == DFRL.locale.Native(key) then return true end
        end
        if DFRL.locale.Match("{subtitle} — survive the onslaught!", plain) then return true end
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

    local function PlayerSay(text)
        local name, body
        if type(_G.CHAT_SAY_GET) == "string" then
            name, body = CaptureFormat(text, _G.CHAT_SAY_GET .. "%s")
        end
        if not name then
            name, body = CaptureFormat(text, "%s says: %s")
        end
        if not name or not body then return text end
        -- Remove only the author's display brackets, retaining native player links,
        -- inline colors, language labels and the complete message body.
        name = string.gsub(name, "(|Hplayer:[^|]+|h)%[(.-)%](|h)", "%1%2%3")
        name = string.gsub(name, "^(|c%x%x%x%x%x%x%x%x)%[([^%[%]]+)%](|r)$", "%1%2%3")
        name = string.gsub(name, "^%[([^%[%]]+)%]$", "%1")
        return name .. ": " .. body
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
        for _, key in ipairs({
            "Your {class}s earn {xp} talent experience: 1 new talent point! Spend it in the armory.",
            "Your {class}s earn {xp} talent experience: {n} new talent points! Spend them in the armory.",
            "Your {class}s earn {xp} talent experience.",
        }) do
            local values = DFRL.locale.Match(key, text)
            if values and string.find(values.xp or "", "^%d[%d,%.]*$") and string.find(values.class or "", "%S") then
                local output = PLUS
                    .. WHITE
                    .. values.xp
                    .. "|r "
                    .. WHITE
                    .. DFRL.locale.Text("Talent XP:")
                    .. "|r "
                    .. YELLOW
                    .. values.class
                    .. "|r"
                if key ~= "Your {class}s earn {xp} talent experience." then
                    local points = values.n or "1"
                    if not string.find(points, "^%d+$") then return nil end
                    output = output .. ", " .. StatGain(points, points == "1" and "Talent Point" or "Talent Points")
                    output = output .. GRAY .. " (" .. DFRL.locale.Text("Spend in armory") .. ")|r"
                end
                return output
            end
        end
        -- Capture the game's class label verbatim, including plural/compound names.
        -- Neither a class whitelist nor fixed XP/point amounts belong here.
        local first, last, class, experience, tail =
            string.find(text, "^Your (.-) earns? (%d[%d,]*) talent experience(.*)$")
        if not first or not string.find(class, "%S") then return nil end
        local output = PLUS
            .. WHITE
            .. experience
            .. "|r "
            .. WHITE
            .. DFRL.locale.Text("Talent XP:")
            .. "|r "
            .. YELLOW
            .. class
            .. "|r"
        if tail == "" or tail == "." or tail == "!" then return output end

        local pointFirst, pointLast, points, instruction = string.find(tail, "^:%s*(%d+) new talent points?!(.*)$")
        if not pointFirst then return nil end
        local prompt = string.gsub(instruction, "^%s+", "")
        prompt = string.gsub(prompt, "%.$", "")
        local armory = prompt == "Spend it in the armory" or prompt == "Spend them in the armory"
        if prompt ~= "" and not armory then return nil end

        local label = tonumber(points) == 1 and "Talent Point" or "Talent Points"
        output = output .. ", " .. StatGain(points, label)
        if armory then output = output .. GRAY .. " (" .. DFRL.locale.Text("Spend in armory") .. ")|r" end
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
        if level and string.find(level, "^%d+$") then
            return YELLOW .. DFRL.locale.Text("Level ") .. level .. "|r", "level"
        end

        -- Survivors combines the three gains into one notice. Apply the source
        -- levelup_stat/levelup_hp appearance to each gain without rounding decimals.
        local values = DFRL.locale.Match(
            "You have gained {damage}% damage, {health} maximum health and {regen} health per second.",
            text
        )
        local damage, health, regeneration
        if values then
            damage, health, regeneration = values.damage, values.health, values.regen
        else
            local first, _, oldDamage, oldHealth, oldRegeneration = string.find(
                text,
                "^You have gained %+([%d%.]+)%% damage, %+([%d%.]+) maximum health and %+([%d%.]+) health per second%.?$"
            )
            if not first then return nil end
            damage, health, regeneration = oldDamage, oldHealth, oldRegeneration
        end
        damage, health, regeneration = NumericGain(damage), NumericGain(health), NumericGain(regeneration)
        if damage and health and regeneration then
            return StatGain(damage .. "%", "Damage") .. ", " .. StatGain(health, "HP") .. ", " .. StatGain(
                regeneration,
                "HP/sec"
            ),
                "level_stats"
        end
        return nil
    end

    -- Chat-only presentation of the shared native loot record.
    function CleanerChat.ParseLootMessage(text)
        local entry = DFRL.messages.ParseLootMessage(text)
        if not entry then return end
        entry.chatText = entry.marks and (PLUS .. " " .. entry.item .. " " .. MarkGain(entry.marks, false))
            or (PLUS .. entry.label .. entry.suffix)
        return entry
    end

    CleanerChat.PrettifyMessage = function(text, eventName, speaker, message)
        if type(text) ~= "string" then return text end
        local announcementEvent = not eventName
            or eventName == "CHAT_MSG_SYSTEM"
            or eventName == "CHAT_MSG_MONSTER_EMOTE"
            or eventName == "CHAT_MSG_RAID_BOSS_EMOTE"
        local banners = DFRL.banners
        if
            announcementEvent
            and banners
            and banners.IsActive()
            and (HiddenAnnouncement(text) or (eventName and HiddenAnnouncement(message)))
        then
            return nil, "hide"
        end
        if eventName == "CHAT_MSG_SAY" then return PlayerSay(text) end
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
            result = MarksMessage(text)
            if result then return result end
            local loot = CleanerChat.ParseLootMessage(text)
            if loot then
                if loot.collection == "collected" and not loot.marks then return nil, "hide" end
                return loot.chatText
            end
        end
        return text
    end
end)
