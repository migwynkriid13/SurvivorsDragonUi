-- Addon text follows received native language evidence; nothing is saved.
local language = { code = "en", data = {}, listeners = {}, labels = {} }
DFRL.locale = language
local aliases = {
    enUS = "en",
    enGB = "en",
    plPL = "pl",
    deDE = "de",
    ptBR = "pt",
    esES = "es",
    esMX = "es",
    frFR = "fr",
    roRO = "ro",
    trTR = "tr",
    ruRU = "ru",
    ukUA = "uk",
    zhCN = "zh",
    jaJP = "ja",
    koKR = "ko",
}

function language.Text(source)
    local catalog = language.data[language.code]
    return catalog and catalog.ui[source] or source
end

function language.Native(key, values)
    local catalog = language.data[language.code] or language.data.en
    local text = catalog and catalog.native[key] or key
    if values then
        text = string.gsub(
            text,
            "{(%w+)}",
            function(field) return values[field] ~= nil and tostring(values[field]) or "{" .. field .. "}" end
        )
    end
    return text
end

-- Bind only addon-owned captions. Never hook native labels, item names or input.
function language.Bind(label)
    if language.labels[label] then return label end
    local original = label.SetText
    local entry = { original = original }
    language.labels[label] = entry
    label.SetText = function(self, text)
        entry.source = text
        return original(self, type(text) == "string" and language.Text(text) or text)
    end
    return label
end

function language.Listen(callback) table.insert(language.listeners, callback) end

function language.CombatText(text)
    for _, key in ipairs({ "MISS", "DODGE", "PARRY", "BLOCK", "ABSORB", "RESIST", "IMMUNE", "EVADE", "DEFLECT" }) do
        if text == key or text == getfenv(0)[key] then return language.Text(key) end
    end
    return text
end

-- Measure real glyphs in every supported language before sizing shared controls.
function language.Width(label, source)
    local entry = language.labels[label]
    local setText = entry and entry.original or label.SetText
    local width = 0
    for _, catalog in pairs(language.data) do
        setText(label, catalog.ui[source] or source)
        width = math.max(width, label:GetStringWidth() or 0)
    end
    setText(label, language.Text(source))
    return math.ceil(width)
end

local templates = {}
function language.Match(key, text)
    if type(text) ~= "string" then return nil end
    local source = language.Native(key)
    local compiled = templates[source]
    if not compiled then
        local pattern, fields, cursor = "^", {}, 1
        while true do
            local first, last, field = string.find(source, "{(%w+)}", cursor)
            if not first then break end
            pattern = pattern .. string.gsub(string.sub(source, cursor, first - 1), "(%W)", "%%%1") .. "([^\r\n]-)"
            table.insert(fields, field)
            cursor = last + 1
        end
        compiled =
            { pattern = pattern .. string.gsub(string.sub(source, cursor), "(%W)", "%%%1") .. "$", fields = fields }
        templates[source] = compiled
    end
    local captures = { string.find(text, compiled.pattern) }
    if not captures[1] then return nil end
    local values = {}
    for index, field in ipairs(compiled.fields) do
        values[field] = captures[index + 2]
    end
    return values
end

function language.Select(code)
    if not language.data[code] or language.code == code then return end
    language.code = code
    for label, entry in pairs(language.labels) do
        if entry.source ~= nil then
            entry.original(label, type(entry.source) == "string" and language.Text(entry.source) or entry.source)
        end
    end
    for _, callback in ipairs(language.listeners) do
        callback()
    end
end

-- Exact localized zone subtitles distinguish all thirteen game catalogs. Names
-- supplement them; tied/unknown evidence never guesses a language from bytes.
function language.ObserveZone()
    if type(AZS_GetPhase) ~= "function" then return end
    local phase = AZS_GetPhase()
    local phases = { ready = true, playing = true, choosing = true, paused = true, dead = true, victory = true }
    if not phases[phase] or type(AZS_ZONE) ~= "table" then return false end
    local zone = AZS_ZONE
    local hints = {}
    if type(zone.zone) == "string" then
        hints["zone." .. zone.zone .. ".name"] = zone.zname
        hints["zone." .. zone.zone .. ".subtitle"] = zone.zsub
    end
    if type(zone.class) == "string" then hints["class." .. zone.class .. ".name"] = zone.cname end
    local best, bestScore, tied = nil, 0, false
    for code, catalog in pairs(language.data) do
        local score = 0
        for key, value in pairs(hints) do
            if type(value) == "string" and value ~= "" and catalog.native[key] == value then score = score + 1 end
        end
        if score > bestScore then
            best, bestScore, tied = code, score, false
        elseif score > 0 and score == bestScore then
            tied = true
        end
    end
    if best and not tied then language.Select(best) end
    return zone.zone ~= nil
end

-- Preserve complete UTF-8 characters when clipping diagnostic previews.
function language.Preview(text, limit)
    local last = math.min(string.len(text), limit)
    if last < string.len(text) then
        local nextByte = string.byte(text, last + 1)
        while last > 0 and nextByte and nextByte >= 128 and nextByte < 192 do
            last = last - 1
            nextByte = string.byte(text, last + 1)
        end
    end
    return string.sub(text, 1, last), last < string.len(text)
end

DFRL:NewMod("Language", -1, function()
    if type(GetLocale) == "function" then
        local ok, locale = pcall(GetLocale)
        if ok then language.Select(aliases[locale] or locale) end
    end
    local pending = not language.ObserveZone()
    local elapsed = 0
    local observer = CreateFrame("Frame")
    observer:RegisterEvent("PLAYER_ENTERING_WORLD")
    observer:RegisterEvent("PLAYER_LEAVING_WORLD")
    observer:RegisterEvent("PLAYER_LOGOUT")
    observer:RegisterEvent("CHAT_MSG_ADDON")
    observer:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            pending = false
        elseif event == "PLAYER_ENTERING_WORLD" or arg1 == "AZSZONE" then
            pending, elapsed = true, 0
        end
    end)
    observer:SetScript("OnUpdate", function()
        if not pending then return end
        elapsed = elapsed + (tonumber(arg1) or 0)
        if elapsed < 0.2 then return end
        elapsed = 0
        pending = not language.ObserveZone()
    end)
end)
