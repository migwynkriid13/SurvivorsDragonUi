-- CI only: production font/display owners, with explicit fake native fonts.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "font fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
-- Native Lua 5.0 globals can lack _G even though the addon environment supplies
-- that alias to module initializers. Font helpers retain their file environment.
env._G = nil
env.setmetatable = setmetatable
local make = context.Object
function context:Object(kind, name, parent)
    local object = make(self, kind, name, parent)
    function object:GetObjectType() return self.kind end
    return object
end
env.CreateFont = function(name) return context:Object("Font", name) end
env.GameFontNormal = env.CreateFont("GameFontNormal")
env.GameFontNormal:SetFont("NATIVE_TEST", 13, "OUTLINE")
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
local independent = root:CreateFontString()
tools.SetFont(independent, 18, "OUTLINE", true)
independent:SetFont("INDEPENDENT_TEST", 18, "OUTLINE")

for _, value in ipairs({ true, 1, "unknown", "Fonts\\ARIALN.TTF" }) do
    assert(display.Copy({ uiFont = value }).uiFont == "default", "invalid saved face was accepted")
end
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

-- Hidden views bind before their existing Show handler measures text.
local hidden = env.CreateFrame("Frame", nil, env.UIParent)
local hiddenLabel = hidden:CreateFontString()
tools.SetFont(hiddenLabel, 9, "")
hidden:SetScript("OnShow", function()
    assert(hiddenLabel:GetFont() == "Fonts\\SKURRI.TTF", "Show measured the stale font")
    context.shown = (context.shown or 0) + 1
end)
hidden:Hide()
display.BeginEdit()
display.Set("uiFont", "skurri")
assert(hiddenLabel:GetFont() == "NATIVE_TEST", "hidden view performed a font write")
hidden:Show()
assert(context.shown == 1 and not hidden:GetScript("OnUpdate"), "font change replaced Show or added an updater")
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.uiFont == "skurri", "Confirm lost the global choice")
hidden:Hide()
display.BeginEdit()
display.Load({ uiFont = "friz", sctFont = "diablo" })
assert(
    label:GetFont() == "Fonts\\FRIZQT__.TTF" and display.Get("sctFont") == "diablo",
    "profile lost independent choices"
)
display.FinishEdit(false)
assert(
    label:GetFont() == "Fonts\\SKURRI.TTF" and display.Get("sctFont") == "default",
    "profile discard lost confirmed choices"
)

-- Native rejection may clear a binding: restore usable text, then retry when
-- the existing view calls the shared setter again, without a background worker.
local reject = true
function label:SetFont(requested, requestedSize, requestedFlags)
    if requested == "Fonts\\MORPHEUS.TTF" and reject then
        self.font = nil
        return false
    end
    return font(self, requested, requestedSize, requestedFlags)
end
display.BeginEdit()
display.Set("uiFont", "morpheus")
assert(label:GetFont() == "NATIVE_TEST", "failed replacement left unusable text")
reject = false
assert(tools.SetFont(label, 11, "OUTLINE"), "failed font did not retry")
assert(label:GetFont() == "Fonts\\MORPHEUS.TTF", "retry lost the requested face")
display.Reset()
assert(display.Get("uiFont") == "default" and label:GetFont() == "NATIVE_TEST", "reset retained the global font")
assert(independent:GetFont() == "INDEPENDENT_TEST", "reset changed independent text")
print("PASS global fonts: transactions, profiles, native styling, exclusions, hidden Show, failures and idle writes")
