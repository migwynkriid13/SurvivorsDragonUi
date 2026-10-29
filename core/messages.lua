-- Shared native-message parsing and delivery for loot, banners and chat.
-- CleanerChat source attribution: third_party/CleanerChat-NOTICE.txt.
-- No chat frames, hooks, collectors or presentation are initialized here.
setfenv(1, DFRL:GetEnv())
local messages = {}
DFRL.messages = messages
local GREEN, GRAY = "|cff59c959", "|cff787878"
local broadcastTime, broadcasts

local function StripColors(text)
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    return (string.gsub(text, "|r", ""))
end

local function IsMarkAmount(value)
    return type(value) == "string" and (string.find(value, "^%d+$") ~= nil or string.find(value, "^%d+%.%d+$") ~= nil)
end

local function MarkUnit(amount)
    return (string.find(amount, "^0*1$") or string.find(amount, "^0*1%.0+$")) and "Mark" or "Marks"
end

local function MarkCounts(text, earned)
    local values = DFRL.locale.Match(earned and "marks.earned" or "marks.gained", text)
    local amount, total
    if values then
        amount, total = values.n, values.total
    elseif earned then
        local _, _, n, balance = string.find(text, "^You earn ([%d%.]+) marks %(([%d%.]+) in all%)%.$")
        amount, total = n, balance
    else
        local _, _, n = string.find(text, "^%+([%d%.]+) marks$")
        amount = n
    end
    if not IsMarkAmount(amount) or (earned and not IsMarkAmount(total)) then return nil end
    return amount, total
end

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

-- Shared, side-effect-free intake for compact chat and the optional loot view.
function messages.ParseLootMessage(text)
    if type(text) ~= "string" then return nil end
    local body = CaptureFormat(text, _G.LOOT_ITEM_SELF)
    if not body then
        local prefix = DFRL.locale.Native("You receive loot:")
        local first, last = string.find(text, prefix, 1, true)
        if first then
            local leading = string.gsub(string.sub(text, 1, first - 1), "|c%x%x%x%x%x%x%x%x", "")
            leading = string.gsub(leading, "|r", "")
            if leading == "" then body = string.sub(text, last + 1) end
        end
    end
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

    -- Collection status is part of native self-loot text. Recognize both known
    -- statuses while preserving their wording and any existing suffix colors.
    local collection, collectionText, marks
    local plainSuffix = StripColors(suffix)
    if plainSuffix == "." then
        suffix = ""
    elseif plainSuffix ~= "" then
        local statusColor
        local normalized = string.gsub(plainSuffix, "^%s+", "")
        normalized = string.gsub(normalized, "%s+$", "")
        normalized = string.gsub(normalized, "%.$", "")
        local collected = "(" .. DFRL.locale.Native("already collected") .. ")"
        if string.sub(normalized, 1, string.len(collected)) ~= collected then collected = "(already collected)" end
        if string.sub(normalized, 1, string.len(collected)) == collected then
            local reward = string.sub(normalized, string.len(collected) + 1)
            if reward ~= "" then
                if not string.find(reward, "^%s+") then return nil end
                local amount = MarkCounts((string.gsub(reward, "^%s+", "")), false)
                if not amount then return nil end
                if string.find(amount, "[1-9]") then marks = amount end
            end
            statusColor = GRAY
            collection = "collected"
            collectionText = collected
        elseif
            normalized == DFRL.locale.Native("New in your collection!")
            or string.find(plainSuffix, "^%s+New in your collection!$")
        then
            statusColor = GREEN
            collection = "new"
        else
            return nil
        end
        collectionText = collectionText or normalized
        if suffix == plainSuffix then suffix = statusColor .. suffix .. "|r" end
    end
    local label = ItemLabel(item)
    local name = string.gsub(label, "|Hitem:[^|]+|h(.-)|h", "%1")
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    local _, _, reference = string.find(item, "|H(item:[^|]+)|h")
    local _, _, color = string.find(item, "^|c(%x%x%x%x%x%x%x%x)")
    return {
        name = name,
        label = label,
        itemReference = reference,
        color = color,
        collection = collection,
        collectionText = collectionText,
        marks = marks,
        item = item,
        suffix = suffix,
    }
end

local function FirstDelivery(frame, text, eventName, author, message, source, surface)
    local now = GetTime()
    if now ~= broadcastTime then
        broadcastTime, broadcasts = now, {}
    end
    local signature = tostring(source)
        .. "\001"
        .. tostring(eventName)
        .. "\001"
        .. tostring(author)
        .. "\001"
        .. tostring(message)
        .. "\001"
        .. text
    local delivery = broadcasts[signature]
    if not delivery then
        delivery = { counts = {}, maximum = 0 }
        broadcasts[signature] = delivery
    end
    local counts = delivery.counts
    if surface then
        delivery.surfaces = delivery.surfaces or {}
        delivery.surfaces[surface] = delivery.surfaces[surface] or {}
        counts = delivery.surfaces[surface]
    end
    local count = (counts[frame] or 0) + 1
    counts[frame] = count
    -- Additional chat frames receive the same delivery. Repeated identical
    -- messages on one frame remain distinct, including in the same UI tick.
    -- Optional surfaces pair that frame's legacy and regular-chat calls.
    if count <= delivery.maximum then return false end
    delivery.maximum = count
    return true
end

messages.StripColors = StripColors
messages.IsMarkAmount = IsMarkAmount
messages.MarkUnit = MarkUnit
messages.MarkCounts = MarkCounts
messages.CaptureFormat = CaptureFormat
messages.FirstDelivery = FirstDelivery
