-- CI only: production language selection with the real fourteen-language catalogs.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "native language fixtures require CI Lua 5.1")

local function New(capabilities, failure, zoneLanguage, getterPresent)
    local c = H.New()
    local env = c.env
    -- The native Lua 5.0 environment may lack _G. Only module initializers
    -- receive the addon's _G/T aliases; file-scope language helpers do not.
    env._G = nil
    local addonEnv = setmetatable({ _G = env, T = env.T }, { __index = env })
    function env.DFRL:GetEnv() return addonEnv end
    function env.DFRL:NewMod(name, _, initialize)
        c.modules[name] = function()
            setfenv(initialize, self:GetEnv())
            initialize()
        end
    end
    assert(env.getfenv(0) == env, "fixture getfenv lost the native environment")
    local state = { capabilities = capabilities, failure = failure, reads = 0, localeReads = 0, notifications = 0 }
    env.GetLocale = function()
        state.localeReads = state.localeReads + 1
        return "enUS"
    end
    env.AZS_GetPhase = function() return "playing" end
    if getterPresent ~= false then
        env.AZS_GetMeterCapabilities = function()
            state.reads = state.reads + 1
            if state.failure == "throw" then error("native language unavailable") end
            if state.failure then return nil, { code = "NOT_READY" } end
            return state.capabilities, nil
        end
    end
    c:Load("core/localization.lua")
    c:Load("localization/data.lua")
    local language = env.DFRL.locale
    if zoneLanguage then
        env.AZS_ZONE =
            { zone = "fixture", class = "warrior", cname = language.data[zoneLanguage].native["class.warrior.name"] }
    end
    local label = env.UIParent:CreateFontString(nil, "OVERLAY")
    language.Bind(label)
    label:SetText("Font size")
    language.Listen(function() state.notifications = state.notifications + 1 end)
    c.modules.Language()
    assert(env._G == nil and addonEnv._G == env, "language initialization changed the native _G boundary")
    assert(getfenv(language.ObserveZone) == env, "language helpers did not retain the native file environment")
    state.observer = c:Controller("CHAT_MSG_ADDON")
    function state:Tick(elapsed) c:Call(self.observer, "OnUpdate", elapsed or 0.2) end
    return state, c, env, language, label
end

local s, c, env, language, label =
    New({ apiVersion = 1, languageCode = "pt", languageRevision = "language:1" }, nil, "de")
assert(language.code == "pt" and s.localeReads == 0, "explicit picker language did not outrank locale/zone wording")
assert(label:GetText() == language.data.pt.ui["Font size"], "native language did not refresh existing bound captions")
assert(s.notifications == 1 and not s.observer:GetScript("OnUpdate"), "settled native language retained polling")
local settled = s.notifications
c:ResetCounts()
for _ = 1, 10 do
    assert(language.ObserveZone())
end
assert(s.notifications == settled, "unchanged native language repeated listener notifications")
c:NoPresentationWrites()
s.capabilities.languageRevision = "language:2"
assert(
    language.ObserveZone() and language.code == "pt" and s.notifications == settled,
    "same-language metadata revision changed the selected catalog"
)
s.capabilities.languageCode = "ru"
c:Event(s.observer, "CHAT_MSG_ADDON", "AZSZONE")
s:Tick(0.1)
assert(language.code == "pt", "language packet read before the deferred observer cadence")
s:Tick(0.1)
assert(
    language.code == "ru" and label:GetText() == language.data.ru.ui["Font size"],
    "deferred observer ignored the explicit new picker language"
)
assert(not s.observer:GetScript("OnUpdate"), "native language recovery left its deferred reader attached")
for _, code in ipairs({ "en", "pl", "cs", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko" }) do
    s.capabilities.languageCode, s.capabilities.languageRevision = code, "language:" .. code
    assert(language.ObserveZone() and language.code == code, "native game catalog was not selectable: " .. code)
    assert(label:GetText() == language.data[code].ui["Font size"], "native catalog used an invented caption: " .. code)
end

for _, invalid in ipairs({
    { apiVersion = 2, languageCode = "pt", languageRevision = "language:1" },
    { apiVersion = 1, languageCode = "future", languageRevision = "language:1" },
    { apiVersion = 1, languageCode = "pt" },
    { apiVersion = 1, languageCode = "pt", languageRevision = "" },
    { apiVersion = "1", languageCode = "pt", languageRevision = "language:1" },
}) do
    s, c, env, language = New(invalid, nil, "de")
    assert(language.code == "de" and s.localeReads == 1, "invalid/unknown native language broke legacy zone selection")
end
for _, failure in ipairs({ "waiting", "throw" }) do
    s, c, env, language = New(nil, failure, "de")
    assert(language.code == "de", "unavailable native capabilities prevented the legacy language fallback")
end
s, c, env, language = New(nil, nil, "de", false)
assert(
    language.code == "de" and s.localeReads == 1 and s.reads == 0,
    "an initially absent native getter broke the locale/zone fallback without _G"
)
assert(not s.observer:GetScript("OnUpdate"), "a settled legacy zone kept the absent native getter pending")
s, c, env, language = New(nil, nil, nil, false)
assert(language.code == "en" and s.observer:GetScript("OnUpdate"), "absent native/zone evidence lost locale retry")
env.AZS_ZONE = { zone = "fixture", class = "warrior", cname = language.data.de.native["class.warrior.name"] }
s:Tick()
assert(
    language.code == "de" and s.reads == 0 and not s.observer:GetScript("OnUpdate"),
    "deferred zone evidence did not recover with the native getter absent"
)
s, c, env, language, label = New(nil, nil, nil, false)
local lateState = s
env.AZS_GetMeterCapabilities = function()
    lateState.reads = lateState.reads + 1
    return { apiVersion = 1, languageCode = "ja", languageRevision = "language:late" }, nil
end
s:Tick(0.1)
assert(language.code == "en" and s.reads == 0, "a newly available getter bypassed the deferred cadence")
s:Tick(0.1)
assert(
    language.code == "ja"
        and label:GetText() == language.data.ja.ui["Font size"]
        and s.reads == 1
        and not s.observer:GetScript("OnUpdate"),
    "a getter added after initialization did not recover native language selection without _G"
)
s, c, env, language = New(nil, "waiting")
assert(
    language.code == "en" and s.observer:GetScript("OnUpdate"),
    "missing native/zone evidence lost initial locale or deferred retry"
)
s.failure, s.capabilities = nil, { apiVersion = 1, languageCode = "cs", languageRevision = "language:ready" }
s:Tick()
assert(
    language.code == "cs" and not s.observer:GetScript("OnUpdate"),
    "pending native language did not recover without a new zone"
)
env.AZS_GetMeterCapabilities = nil
env.AZS_ZONE = { zone = "fixture", class = "warrior", cname = language.data.de.native["class.warrior.name"] }
assert(language.ObserveZone() and language.code == "de", "an absent new API removed the established zone fallback")
c:Event(s.observer, "PLAYER_ENTERING_WORLD")
c:Event(s.observer, "PLAYER_LEAVING_WORLD")
s.reads = 0
s:Tick()
assert(not s.observer:GetScript("OnUpdate") and s.reads == 0, "world cleanup kept the language reader active")
print(
    "PASS native game language takes priority with real catalogs, deferred lifecycle, settled writes and safe legacy fallback"
)
