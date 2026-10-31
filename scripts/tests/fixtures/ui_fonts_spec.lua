-- CI only: production font/display owners, with explicit fake native fonts.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "font fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
-- Native Lua 5.0 globals can lack _G even though the addon environment supplies
-- that alias to module initializers. Font helpers retain their file environment.
env._G = nil
env.setmetatable = setmetatable
local addonEnv = setmetatable({ _G = env, T = env.T }, { __index = env })
function env.DFRL:GetEnv() return addonEnv end
function env.DFRL:NewMod(name, _, initialize)
    context.modules[name] = function()
        setfenv(initialize, self:GetEnv())
        initialize()
    end
end
local make = context.Object
function context:Object(kind, name, parent)
    local object = make(self, kind, name, parent)
    function object:GetObjectType() return self.kind end
    function object:GetShadowColor() return unpack(self.shadowColor or { 0, 0, 0, 0 }) end
    function object:GetShadowOffset() return unpack(self.shadowOffset or { 0, 0 }) end
    local color, offset = object.SetShadowColor, object.SetShadowOffset
    function object:SetShadowColor(r, g, b, a)
        color(self, r, g, b, a)
        self.shadowColor = { r, g, b, a }
    end
    function object:SetShadowOffset(x, y)
        offset(self, x, y)
        self.shadowOffset = { x, y }
    end
    return object
end
env.CreateFont = function(name) return context:Object("Font", name) end
env.GameFontNormal = env.CreateFont("GameFontNormal")
env.GameFontNormal:SetFont("NATIVE_TEST", 13, "OUTLINE")
env.GameFontHighlight = env.CreateFont("GameFontHighlight")
env.GameFontHighlight:SetFont("NATIVE_TEST", 14, "THICKOUTLINE, MONOCHROME")
local font = env.GameFontNormal.SetFont
-- DEFAULT is the legacy alias rejected by newer clients.
local createFont = env.CreateFont
env.CreateFont = function(name)
    local object = createFont(name)
    function object:SetFont(face, size, flags)
        if face == "DEFAULT" then
            self.font = nil
            return false
        end
        return font(self, face, size, flags)
    end
    return object
end
context:Load("core/display.lua", "Display")
context:Load("core/fonts.lua", "Fonts")
assert(env._G == nil, "font initialization introduced a native _G alias")
assert(
    env.STANDARD_TEXT_FONT == "NATIVE_TEST"
        and env.UNIT_NAME_FONT == "NATIVE_TEST"
        and env.DAMAGE_TEXT_FONT == "NATIVE_TEST"
        and env.NAMEPLATE_FONT == "NATIVE_TEST",
    "initialization skipped native font paths without _G"
)
local display, tools = env.DFRL.display, env.T
local root = env.CreateFrame("Frame", nil, env.UIParent)
local label, loot = root:CreateFontString(), root:CreateFontString()
tools.SetFont(label, 11, "OUTLINE")
tools.SetFont(loot, 15, "", "Fonts\\FRIZQT__.TTF")
assert(label:GetFont() == "NATIVE_TEST", "missing setting changed existing addon text")
assert(loot:GetFont() == "Fonts\\FRIZQT__.TTF", "default lost the authored loot face")
assert(display.Get("uiFontOutline") == "OUTLINE" and display.Get("uiFontShadow"), "missing styles lost defaults")
local _, _, lootFlags = loot:GetFont()
local _, nativeSize, nativeFlags = env.GameFontHighlight:GetFont()
assert(lootFlags == "OUTLINE", "new labels missed the selected global outline")
assert(nativeSize == 14 and nativeFlags == "OUTLINE,MONOCHROME", "global outline lost other native font flags")
assert(select(4, label:GetShadowColor()) == 1 and label:GetShadowOffset() == 1, "default black shadow missing")
local independent = root:CreateFontString()
tools.SetFont(independent, 18, "OUTLINE", true)
independent:SetFont("INDEPENDENT_TEST", 18, "OUTLINE")
tools.SetChatShadow(independent)

for _, value in ipairs({ true, 1, "unknown", "friz", "Fonts\\ARIALN.TTF" }) do
    assert(display.Copy({ uiFont = value }).uiFont == "default", "invalid saved face was accepted")
end
for _, value in ipairs({ true, 1, "none", "outline", "MONOCHROME" }) do
    assert(display.Copy({ uiFontOutline = value }).uiFontOutline == "OUTLINE", "invalid saved outline accepted")
end
for _, value in ipairs({ 0, "false", "true" }) do
    assert(display.Copy({ uiFontShadow = value }).uiFontShadow, "invalid saved shadow lost its default")
end
env.SurvivorsDragonUiDisplay = { uiFont = "friz" }
assert(display.Get("uiFont") == "default", "removed saved font did not use Default")
env.SurvivorsDragonUiDisplay = nil
display.BeginEdit()
display.Set("uiFont", "arial")
display.Set("uiFont", "unknown")
assert(display.Get("uiFont") == "arial" and not env.SurvivorsDragonUiDisplay, "preview saved or accepted invalid font")
local face, size, flags = label:GetFont()
assert(face == "Fonts\\ARIALN.TTF" and size == 11 and flags == "OUTLINE", "preview changed size or outline")
assert(loot:GetFont() == face and env.GameFontNormal:GetFont() == face, "preview missed loot or native font objects")
assert(
    env.STANDARD_TEXT_FONT == face
        and env.UNIT_NAME_FONT == face
        and env.DAMAGE_TEXT_FONT == face
        and env.NAMEPLATE_FONT == face,
    "preview skipped native font paths without _G"
)
assert(independent:GetFont() == "INDEPENDENT_TEST", "global choice replaced an independent font")
assert(tools.GetDefaultFont() == "NATIVE_TEST", "global choice changed the independent Default face")
local _, stockSize, stockFlags = env.GameFontNormal:GetFont()
assert(stockSize == 13 and stockFlags == "OUTLINE", "global choice changed stock font styling")
local count = #context.objects
context:ResetCounts()
display.Set("performanceMode", true)
tools.SetFont(label, 11, "OUTLINE")
context:NoPresentationWrites()
assert(#context.objects == count, "font preview allocated drawing objects")
display.FinishEdit(false)
assert(label:GetFont() == "NATIVE_TEST" and loot:GetFont() == "Fonts\\FRIZQT__.TTF", "Cancel lost original faces")
assert(env.STANDARD_TEXT_FONT == "NATIVE_TEST" and env._G == nil, "Cancel lost native font paths without _G")

-- Face and style are independent, and constructor helpers cannot restore a
-- disabled shadow. No-outline still retains unrelated native font flags.
display.BeginEdit()
display.Set("uiFontOutline", "")
display.Set("uiFontShadow", false)
display.Set("uiFontOutline", "invalid")
local _, _, plainFlags = label:GetFont()
local _, _, nativePlainFlags = env.GameFontHighlight:GetFont()
assert(plainFlags == "" and nativePlainFlags == "MONOCHROME", "None lost non-outline flags")
assert(label:GetFont() == "NATIVE_TEST" and loot:GetFont() == "Fonts\\FRIZQT__.TTF", "style changed the face")
assert(select(4, label:GetShadowColor()) == 0 and label:GetShadowOffset() == 0, "shadow toggle did not clear it")
local later = root:CreateFontString()
tools.SetFont(later, 10, "OUTLINE")
tools.SetChatShadow(later)
assert(select(4, later:GetShadowColor()) == 0, "new label helper restored a disabled shadow")
assert(select(4, independent:GetShadowColor()) == 1, "global shadow changed independently styled text")
local _, _, independentFlags = independent:GetFont()
assert(independentFlags == "OUTLINE", "global outline changed independently styled text")
context:ResetCounts()
tools.SetFont(later, 10, "OUTLINE")
tools.SetChatShadow(later)
display.Set("performanceMode", true)
context:NoPresentationWrites()
later.GetShadowColor, later.GetShadowOffset = false, false
tools.SetChatShadow(later)
context:ResetCounts()
tools.SetChatShadow(later)
tools.SetFont(later, 10, "OUTLINE")
context:NoPresentationWrites()
display.FinishEdit(false)
local _, _, restoredFlags = label:GetFont()
assert(restoredFlags == "OUTLINE" and select(4, label:GetShadowColor()) == 1, "Cancel retained preview styling")

-- Hidden views bind before their existing Show handler measures text.
local hidden = env.CreateFrame("Frame", nil, env.UIParent)
local hiddenLabel = hidden:CreateFontString()
tools.SetFont(hiddenLabel, 9, "")
hidden:SetScript("OnShow", function()
    assert(hiddenLabel:GetFont() == "Fonts\\SKURRI.TTF", "Show measured the stale font")
    local _, _, hiddenFlags = hiddenLabel:GetFont()
    assert(hiddenFlags == "THICKOUTLINE", "Show measured the stale outline")
    assert(select(4, hiddenLabel:GetShadowColor()) == 0, "Show retained the stale shadow")
    context.shown = (context.shown or 0) + 1
end)
hidden:Hide()
display.BeginEdit()
display.Set("uiFont", "skurri")
display.Set("uiFontOutline", "THICKOUTLINE")
display.Set("uiFontShadow", false)
assert(hiddenLabel:GetFont() == "NATIVE_TEST", "hidden view performed a font write")
assert(select(4, hiddenLabel:GetShadowColor()) == 1, "hidden view performed a shadow write")
hidden:Show()
assert(context.shown == 1 and not hidden:GetScript("OnUpdate"), "font change replaced Show or added an updater")
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.uiFont == "skurri", "Confirm lost the global choice")
assert(
    env.SurvivorsDragonUiDisplay.uiFontOutline == "THICKOUTLINE" and env.SurvivorsDragonUiDisplay.uiFontShadow == false,
    "Confirm lost global text styling"
)
hidden:Hide()
display.BeginEdit()
display.Load({ uiFont = "friz", sctFont = "diablo" })
assert(
    display.Get("uiFont") == "default"
        and display.Get("uiFontOutline") == "OUTLINE"
        and display.Get("uiFontShadow")
        and label:GetFont() == "NATIVE_TEST"
        and loot:GetFont() == "Fonts\\FRIZQT__.TTF"
        and display.Get("sctFont") == "diablo",
    "removed profile font did not use Default or changed independent choices"
)
display.FinishEdit(false)
assert(
    label:GetFont() == "Fonts\\SKURRI.TTF"
        and display.Get("sctFont") == "default"
        and display.Get("uiFontOutline") == "THICKOUTLINE"
        and display.Get("uiFontShadow") == false,
    "profile discard lost confirmed choices"
)

-- A native shadow rejection stays retryable through the same setter boundary.
local setOffset = label.SetShadowOffset
setOffset(label, 4, 5)
local rejectShadow = true
function label:SetShadowOffset(x, y)
    if rejectShadow then return false end
    return setOffset(self, x, y)
end
assert(not tools.SetChatShadow(label), "failed shadow was reported as applied")
rejectShadow = false
assert(tools.SetFont(label, 11, "OUTLINE") and label:GetShadowOffset() == 0, "shadow failure did not retry")

-- Native rejection may clear a binding: restore usable text, then retry when
-- the existing view calls the shared setter again, without a background worker.
local reject = true
local rejectOutline = true
function label:SetFont(requested, requestedSize, requestedFlags)
    if (requested == "Fonts\\MORPHEUS.TTF" and reject) or (requestedFlags == "" and rejectOutline) then
        self.font = nil
        return false
    end
    return font(self, requested, requestedSize, requestedFlags)
end
display.BeginEdit()
display.Set("uiFontOutline", "")
local fallbackFace, _, fallbackFlags = label:GetFont()
assert(fallbackFace == "NATIVE_TEST" and fallbackFlags == "OUTLINE", "rejected outline left unusable text")
rejectOutline = false
assert(tools.SetFont(label, 11, "OUTLINE"), "rejected outline did not retry")
local _, _, retriedFlags = label:GetFont()
assert(retriedFlags == "", "outline retry lost None")
display.Set("uiFont", "morpheus")
assert(label:GetFont() == "NATIVE_TEST", "failed replacement left unusable text")
reject = false
assert(tools.SetFont(label, 11, "OUTLINE"), "failed font did not retry")
assert(label:GetFont() == "Fonts\\MORPHEUS.TTF", "retry lost the requested face")
display.Reset()
assert(display.Get("uiFont") == "default" and label:GetFont() == "NATIVE_TEST", "reset retained the global font")
assert(display.Get("uiFontOutline") == "OUTLINE" and display.Get("uiFontShadow"), "reset retained global styling")
assert(independent:GetFont() == "INDEPENDENT_TEST", "reset changed independent text")
print("PASS global fonts: face/style transactions, native flags, exclusions, hidden Show, failures and idle writes")
