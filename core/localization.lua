-- Addon text follows received native language evidence; nothing is saved.
local language = { code = "en", data = {}, listeners = {}, labels = {} }
DFRL.locale = language
local aliases = {
    enUS = "en",
    enGB = "en",
    plPL = "pl",
    csCZ = "cs",
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

-- Shared callers can size against every language; lazily built settings use
-- only the active catalog and cache successful measurements on their ruler.
function language.Width(label, source, activeOnly)
    local entry = language.labels[label]
    local setText = entry and entry.original or label.SetText
    if activeOnly then
        local face, size, flags = label:GetFont()
        local parent = label:GetParent()
        local scale = parent and parent:GetEffectiveScale() or 1
        local cache = entry and entry.widths
        if
            not cache
            or cache.code ~= language.code
            or cache.face ~= face
            or cache.size ~= size
            or cache.flags ~= flags
            or cache.scale ~= scale
            or cache.width ~= label:GetWidth()
        then
            cache = {
                code = language.code,
                face = face,
                size = size,
                flags = flags,
                scale = scale,
                width = label:GetWidth(),
                values = {},
            }
            if entry then entry.widths = cache end
        end
        local measured = cache.values[source]
        if measured then return measured end
        setText(label, language.Text(source))
        measured = label:GetStringWidth()
        if not measured or measured <= 0 then return 0 end
        measured = math.ceil(measured)
        cache.values[source] = measured
        return measured
    end
    local width = 0
    for _, catalog in pairs(language.data) do
        setText(label, catalog.ui[source] or source)
        width = math.max(width, label:GetStringWidth() or 0)
    end
    setText(label, language.Text(source))
    return math.ceil(width)
end

-- Lua 5.0's escaped character classes do not match high UTF-8 bytes reliably.
-- Escape only pattern syntax; keep each translated literal's bytes unchanged.
local function EscapePatternLiteral(text) return (string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end

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
            pattern = pattern .. EscapePatternLiteral(string.sub(source, cursor, first - 1)) .. "([^\r\n]-)"
            table.insert(fields, field)
            cursor = last + 1
        end
        compiled = { pattern = pattern .. EscapePatternLiteral(string.sub(source, cursor)) .. "$", fields = fields }
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

local nativeCode, nativeRevision
local function ObserveNativeLanguage()
    if type(_G.AZS_GetMeterCapabilities) ~= "function" then return false end
    local ok, capabilities, failure = pcall(_G.AZS_GetMeterCapabilities)
    if
        not ok
        or failure ~= nil
        or type(capabilities) ~= "table"
        or capabilities.apiVersion ~= 1
        or type(capabilities.languageCode) ~= "string"
        or not language.data[capabilities.languageCode]
        or type(capabilities.languageRevision) ~= "string"
        or capabilities.languageRevision == ""
    then
        return false
    end
    local code, revision = capabilities.languageCode, capabilities.languageRevision
    if nativeCode ~= code or nativeRevision ~= revision or language.code ~= code then
        nativeCode, nativeRevision = code, revision
        language.Select(code)
    end
    return true
end

-- Exact localized zone subtitles distinguish all fourteen game catalogs. Names
-- supplement them; tied/unknown evidence never guesses a language from bytes.
local function ObserveZoneLanguage()
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

function language.ObserveZone() return ObserveNativeLanguage() or ObserveZoneLanguage() end

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
    local pending = false
    if not ObserveNativeLanguage() then
        if type(GetLocale) == "function" then
            local ok, locale = pcall(GetLocale)
            if ok then language.Select(aliases[locale] or locale) end
        end
        pending = not ObserveZoneLanguage()
    end
    local elapsed = 0
    local observer = CreateFrame("Frame")
    local function Tick()
        if not pending then return end
        elapsed = elapsed + (tonumber(arg1) or 0)
        if elapsed < 0.2 then return end
        elapsed = 0
        pending = not language.ObserveZone()
        if not pending then observer:SetScript("OnUpdate", nil) end
    end
    observer:RegisterEvent("PLAYER_ENTERING_WORLD")
    observer:RegisterEvent("PLAYER_LEAVING_WORLD")
    observer:RegisterEvent("PLAYER_LOGOUT")
    observer:RegisterEvent("CHAT_MSG_ADDON")
    observer:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            pending = false
            observer:SetScript("OnUpdate", nil)
        elseif event == "PLAYER_ENTERING_WORLD" or arg1 == "AZSZONE" then
            pending, elapsed = true, 0
            observer:SetScript("OnUpdate", Tick)
        end
    end)
    if pending then observer:SetScript("OnUpdate", Tick) end
end)
