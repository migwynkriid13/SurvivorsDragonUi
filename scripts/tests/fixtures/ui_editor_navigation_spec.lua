-- CI only: the production editor factory, with explicit input/scroll boundaries.
local H = dofile("scripts/tests/fixtures/ui_helpers.lua")
assert(_VERSION == "Lua 5.1", "editor fixtures require CI Lua 5.1")
local context = H.New()
local env = context.env
env.DFRL.locale.code = "en"
env.DFRL.locale.Bind = function(label) return label end
local object = context.Object
context.Object = function(self, kind, name, parent)
    local result = object(self, kind, name, parent)
    local setPoint = result.SetPoint
    function result:SetPoint(...)
        setPoint(self, ...)
        self.point = { ... }
    end
    if kind == "FontString" then
        local justifyH, justifyV = result.SetJustifyH, result.SetJustifyV
        function result:SetJustifyH(value)
            justifyH(self, value)
            self.justifyH = value
        end
        function result:SetJustifyV(value)
            justifyV(self, value)
            self.justifyV = value
        end
        function result:GetStringWidth()
            context.reads.glyphs = (context.reads.glyphs or 0) + 1
            return self.naturalWidth or string.len(self:GetText()) * 6
        end
    end
    if kind == "Texture" then
        local setTexCoord = result.SetTexCoord
        function result:SetTexCoord(...)
            setTexCoord(self, ...)
            self.coords = { ... }
        end
        function result:SetDrawLayer(layer) self.drawLayer = layer end
    end
    return result
end
local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent, template)
    local frame = createFrame(kind, name, parent)
    function frame:GetFrameStrata() return "TOOLTIP" end
    function frame:EnableMouseWheel(value) self.wheel = value end
    function frame:GetScale() return self.scale or 1 end
    function frame:GetEffectiveScale() return self:GetScale() end
    function frame:SetScale(value) self.scale = value end
    function frame:SetMovable(value) self.movable = value end
    function frame:RegisterForDrag(value) self.dragButton = value end
    function frame:StopMovingOrSizing() self.stopped = true end
    if kind == "EditBox" then
        function frame:SetAutoFocus(value) self.autoFocus = value end
        function frame:SetMaxLetters(value) self.maxLetters = value end
        function frame:SetTextInsets(...) self.insets = { ... } end
        function frame:ClearFocus() self.focused = false end
    end
    if kind == "Button" then
        frame.enabled = 1
        function frame:IsEnabled() return self.enabled end
        function frame:Enable() self.enabled = 1 end
        function frame:Disable() self.enabled = 0 end
        function frame:SetHighlightTexture(path, blend)
            assert(not self.highlight, "button recreated its native highlight")
            self.highlight = self:CreateTexture(nil, "HIGHLIGHT")
            self.highlight:SetTexture(path)
            self.highlight.blend = blend
        end
        function frame:GetHighlightTexture() return self.highlight end
        function frame:LockHighlight()
            self.highlightLocked = true
            self.lockWrites = (self.lockWrites or 0) + 1
        end
        function frame:UnlockHighlight()
            self.highlightLocked = false
            self.lockWrites = (self.lockWrites or 0) + 1
        end
    end
    if template == "UIPanelScrollFrameTemplate" then
        local slider = createFrame("Slider", name .. "ScrollBar", frame)
        function slider:GetMinMaxValues() return 0, self.maximum or 0 end
        function slider:GetValue() return self.value or 0 end
        function slider:SetValue(value)
            self.value = value
            frame.offset = value
        end
        function frame:SetScrollChild(child) self.child = child end
        function frame:UpdateScrollChildRect()
            slider.maximum = math.max(0, self.child:GetHeight() - self:GetHeight())
            slider:SetValue(math.min(slider:GetValue(), slider.maximum))
        end
    end
    return frame
end
context:Load("core/editor.lua")
local panel = env.CreateFrame("Frame", nil, env.UIParent)
local sidebar = env.CreateFrame("Frame", nil, panel)
local groups = {
    { key = "layout", label = "Layout" },
    { key = "combat", label = "Combat" },
    { key = "unused", label = "Unused" },
}
local sections = {
    { key = "layout", label = "Layout", group = "layout" },
    { key = "text", label = "Combat text", group = "combat", options = { { "icons", "Damage icons", "Spell icons" } } },
    { key = "meter", label = "Damage meter", group = "combat" },
    { key = "unused", label = "Unused", group = "unused" },
}
local closes, preparations = 0, {}
local navigation = env.T.CreateEditorNavigator(panel, sidebar, groups, sections, {
    width = 684,
    left = 240,
    top = 80,
    height = 552,
    sidebarWidth = 212,
    prepare = function(section, page)
        assert(not preparations[section.key], "section was constructed twice")
        preparations[section.key] = true
        if section.key == "text" then page:SetHeight(600) end
    end,
    onNavigate = function() closes = closes + 1 end,
})
assert(not next(navigation.pages), "navigator eagerly prepared hidden sections")
navigation.Select("layout")
local page = navigation.pages.layout
page.pending = "-12,5"
assert(sections[1].shell:IsShown() and not sections[2].shell)
local allocated = #context.objects
context:ResetCounts()
navigation.Refresh()
context:NoPresentationWrites()
assert(#context.objects == allocated, "unchanged navigation allocated views")

navigation.Select("combat")
allocated = #context.objects
assert(not sections[1].shell:IsShown() and sections[2].shell:IsShown() and sections[3].shell:IsShown())
local slider = env.SurvivorsDragonUiSettingsScrollScrollBar
slider:SetValue(180)
navigation.Select("layout")
navigation.Select("combat")
assert(slider:GetValue() == 180, "category scroll position was lost")
assert(navigation.pages.layout == page and page.pending == "-12,5", "navigation replaced pending input")

assert(not sections[1].heading and sections[1].headingHeight == 0, "Layout repeated its sidebar caption")
assert(sections[2].heading and sections[3].heading, "distinct subsection headings were removed")
assert(
    sections[2].heading.point[1] == "TOP" and sections[2].heading.justifyH == "CENTER",
    "subsection heading was not centered over its controls"
)
assert(not navigation.search and not navigation.query, "the removed search retained runtime state")
assert(navigation.pages.text:GetParent() == sections[2].shell, "navigation moved the real controls")
slider:SetValue(235)
navigation.Refresh(true)
assert(slider:GetValue() == 235, "a geometry refresh lost the current scroll position")

panel:Hide()
context:ResetCounts()
navigation.Refresh()
context:NotifyLocale()
navigation.Select("unused")
assert(not sections[4].shell and #context.objects == allocated, "closed navigation prepared an unvisited category")
navigation.Select("combat")
context:NoPresentationWrites()
panel:Show()
navigation.Refresh()
assert(sections[2].shell:IsShown() and sections[3].shell:IsShown(), "reopen did not restore the category")
assert(page.pending == "-12,5" and #context.objects == allocated, "reopen recreated controls or discarded a draft")
assert(closes > 0, "navigation did not retire its choice popup")
for _, object in ipairs(context.objects) do
    assert(not object:GetScript("OnUpdate"), "navigator added idle polling or animation")
    assert(object.kind ~= "EditBox", "navigator allocated a search input")
end
local toggle = env.T.CreateEditorToggle(panel, "Ability damage", "Show each ability's damage.", 300)
assert(env.T.CompactEditorToggle(toggle) == 64, "single-line toggle did not shrink")
assert(toggle.label:GetHeight() == 16 and toggle.description.point[5] == -26, "caption/help gap was not three units")
context:ResetCounts()
env.T.CompactEditorToggle(toggle)
context:NoPresentationWrites()
toggle.label.naturalWidth = 500
assert(env.T.CompactEditorToggle(toggle) == 76, "wrapped caption did not retain a second line")
assert(toggle.label:GetHeight() == 28 and toggle.description.point[5] == -38, "wrapped caption/help gap changed")
toggle.label.naturalWidth = 0
env.T.CompactEditorToggle(toggle)
assert(not toggle.editorCompactHeight, "unavailable glyph metrics were cached as ready")
toggle.label.naturalWidth = 100
assert(env.T.CompactEditorToggle(toggle) == 64, "available metrics did not repair compact spacing")
local compact = env.T.CreateEditorToggle(panel, "Performance Mode", nil, 232)
compact:SetHeight(36)
compact.label:SetHeight(28)
assert(
    compact.label.point[1] == "LEFT" and compact.label.point[5] == 0 and compact.label.justifyV == "MIDDLE",
    "compact checkbox caption drifted when its height changed"
)
compact:SetHeight(28)
assert(compact.label.point[1] == "LEFT" and compact.label.point[5] == 0, "timer-height choice lost centered alignment")
local input = env.T.CreateEditorInput(panel, 194, 26)
assert(
    #input.editorBorder == 4 and input.maxLetters == 16 and input.autoFocus == false,
    "input skin changed native editing"
)
for _, edge in ipairs(input.editorBorder) do
    assert(edge:GetTexture() == "Interface\\Buttons\\WHITE8X8", "input retained the ornamental border artwork")
end

-- Paired numeric controls retain a separate help and native step-button area.
local function Number(parent)
    local control = env.CreateFrame("Frame", nil, parent)
    control:SetWidth(322)
    control:SetHeight(88)
    control.label = control:CreateFontString(nil, "OVERLAY")
    control.label:SetText("Font size")
    control.label:SetWidth(322)
    control.label:SetHeight(28)
    control.description = control:CreateFontString(nil, "OVERLAY")
    control.description:SetWidth(166)
    control.description:SetHeight(40)
    return control
end
local number = Number(panel)
assert(env.T.CompactEditorNumber(number) == 72, "single-line number did not compact")
assert(number.label:GetHeight() == 16 and number.description.point[5] == -26, "number help gap changed")
context:ResetCounts()
env.T.CompactEditorNumber(number)
context:NoPresentationWrites()
number.label.naturalWidth = 500
assert(env.T.CompactEditorNumber(number) == 84, "wrapped numeric title lost its second line")
assert(number.description.point[5] == -38 and number.description:GetWidth() == 166, "number help overlaps steps")
number.label.naturalWidth = 0
env.T.CompactEditorNumber(number)
assert(not number.editorNumberHeight, "missing numeric glyph metrics were cached")
number.label.naturalWidth = 100
assert(env.T.CompactEditorNumber(number) == 72, "numeric metrics did not recover")

-- Exercise the actual grid helper with mixed heights, odd rows and full-row
-- masters. A spanning control must finish an incomplete pair before placement.
local grid = env.CreateFrame("Frame", nil, panel)
grid:SetWidth(660)
local function GridToggle(width) return env.T.CreateEditorToggle(grid, "Health choice", "Description", width or 322) end
local master, wrapped, odd, full = GridToggle(660), GridToggle(), GridToggle(), GridToggle(660)
wrapped.label.naturalWidth = 500
local pairedNumber, tailNumber = Number(grid), Number(grid)
local controls = {
    { frame = master, span = 2 },
    { frame = wrapped, span = 1 },
    { frame = pairedNumber, span = 1, numeric = true },
    { frame = odd, span = 1 },
    { frame = full, span = 2 },
    { frame = tailNumber, span = 1, numeric = true },
}
local gridAllocated = #context.objects
assert(env.T.LayoutEditorOptions(grid, controls, 2, 16, 12) == 352, "paired scroll extent is wrong")
assert(master.point[4] == 0 and master.point[5] == -12, "master did not start at the section inset")
assert(wrapped.point[4] == 0 and pairedNumber.point[4] == 338, "options are not left-to-right pairs")
assert(wrapped.point[5] == -76 and pairedNumber.point[5] == -76, "paired controls lost their common top")
assert(odd.point[5] == -152, "the next row ignored the taller translated title")
assert(full.point[4] == 0 and full.point[5] == -216, "full row overlapped an unfinished pair")
assert(tailNumber.point[4] == 0 and tailNumber.point[5] == -280, "odd last option is not on the left")
context:ResetCounts()
assert(env.T.LayoutEditorOptions(grid, controls, 2, 16, 12) == 352)
context:NoPresentationWrites()
assert(#context.objects == gridAllocated, "reflow allocated another view")
wrapped.label.naturalWidth = 100
assert(env.T.LayoutEditorOptions(grid, controls, 2, 16, 12) == 348, "locale reflow ignored the numeric row height")
assert(odd.point[5] == -148 and full.point[5] == -212, "locale reflow left gaps or overlaps")
assert(
    env.T.LayoutEditorOptions(grid, { { frame = master, span = 1 } }, 1, 16, 112) == 176,
    "single-control section or mode-selector clearance changed"
)
for _, item in ipairs(context.objects) do
    assert(not item:GetScript("OnUpdate"), "option reflow installed an idle worker")
end

-- The real shared button keeps native click ownership and has no idle worker.
local buttonParent = env.CreateFrame("Frame", nil, env.UIParent)
local button = env.T.CreateEditorButton(buttonParent, "Cancel", 140, 30)
local pieces = button.editorPieces
local clicks = 0
button:SetScript("OnClick", function() clicks = clicks + 1 end)
assert(button.highlight.blend == "ADD" and button.highlight.drawLayer == "ARTWORK", "hover covers the caption")
context:Call(button, "OnEnter")
context:Call(button, "OnMouseDown", "LeftButton")
assert(pieces[1].coords[3] == 0.25, "mouse down did not show the pressed face")
context:Call(button, "OnLeave")
assert(pieces[1].coords[3] == 0, "leaving during a press left the button stuck down")
context:Call(button, "OnMouseDown", "LeftButton")
context:Call(button, "OnMouseUp", "LeftButton")
context:Call(button, "OnClick")
assert(clicks == 1 and pieces[1].coords[3] == 0, "native release/click callback ownership changed")
button:SetSelected(true)
assert(button.highlightLocked and pieces[1].coords[3] == 0.25, "selected choice lost its pressed/highlight state")
local lockWrites = button.lockWrites
local buttonAllocated = #context.objects
context:ResetCounts()
button:SetSelected(true)
context:NoPresentationWrites()
assert(button.lockWrites == lockWrites, "unchanged selection repeated native highlight writes")
button:Disable()
assert(button:IsEnabled() == 0 and not button.highlightLocked, "disabled native 0 stayed highlighted")
assert(pieces[1].coords[3] == 0.5 and button.label.textColor[1] == 0.5, "disabled choice stayed red/gold")
button:Enable()
assert(button.highlightLocked and pieces[1].coords[3] == 0.25, "reenabling discarded the selected choice")
button:SetSelected(false)
button:SetWidth(28)
assert(pieces[1]:GetWidth() < 14 and pieces[3]:GetWidth() < 14, "narrow caps overlap")
button:SetWidth(240)
assert(pieces[1]:GetWidth() == 30 * 114 / 128, "resizing stretched the outside corners")
context:Call(button, "OnMouseDown", "LeftButton")
buttonParent:Hide()
context:ResetCounts()
button:SetSelected(true)
button:SetSelected(false)
context:NoPresentationWrites()
buttonParent:Show()
assert(pieces[1].coords[3] == 0, "hide/show replayed a stale press")
assert(
    #context.objects == buttonAllocated and not button:GetScript("OnUpdate"),
    "button allocated during input or polled"
)
-- Profiles replaces the translated caption with a literal saved profile name.
button.label = button:CreateFontString(nil, "OVERLAY")
button.label:SetText("My profile")
button:SetSelected(true)
assert(
    button.label.textColor[1] == 1 and button.label:GetText() == "My profile",
    "replacement profile caption lost styling or text"
)
print(
    "PASS editor grouping, paired option geometry, compact spacing, scroll memory, retail button input/selection/disabled states, hidden idle and reuse"
)

-- Extracted production constructor over the real navigator, locale, Display and
-- Profiles owners. Only the separate HUD/font-rendering boundaries are faked.
context:Load("core/localization.lua")
context:Load("localization/data.lua")
context:Load("core/tally.lua")
context:Load("core/display.lua", "Display")
local locale, display = env.DFRL.locale, env.DFRL.display
function env.UIParent:GetEffectiveScale() return 1 end
env.UIParent:SetWidth(1280)
env.UIParent:SetHeight(800)
env.T.GetLocalSize = function(frame) return frame:GetWidth(), frame:GetHeight() end
env.T.GetDefaultFont = function() return "DEFAULT_TEST" end

local ruler = env.UIParent:CreateFontString(nil, "OVERLAY")
locale.Bind(ruler)
ruler:SetFont("DEFAULT_TEST", 12, "")
local glyphs = context.reads.glyphs or 0
local measured = locale.Width(ruler, "Size", true)
assert(measured > 0 and context.reads.glyphs == glyphs + 1, "active sizing measured inactive languages")
context:ResetCounts()
assert(locale.Width(ruler, "Size", true) == measured and not context.reads.glyphs, "width was not cached")
context:NoPresentationWrites()
ruler.naturalWidth = 0
assert(locale.Width(ruler, "Font", true) == 0, "missing width was invented")
ruler.naturalWidth = 90
assert(locale.Width(ruler, "Font", true) == 90, "missing glyph width did not retry")
ruler:SetFont("DEFAULT_TEST", 14, "OUTLINE")
glyphs = context.reads.glyphs
locale.Width(ruler, "Size", true)
assert(context.reads.glyphs == glyphs + 1, "font change retained old width")
ruler:SetWidth(180)
glyphs = context.reads.glyphs
locale.Width(ruler, "Size", true)
assert(context.reads.glyphs == glyphs + 1, "width constraint change retained old width")
local nativeScale = env.UIParent.GetEffectiveScale
function env.UIParent:GetEffectiveScale() return 2 end
glyphs = context.reads.glyphs
locale.Width(ruler, "Size", true)
assert(context.reads.glyphs == glyphs + 1, "owner scale change retained old width")
env.UIParent.GetEffectiveScale = nativeScale
locale.Select("de")
glyphs = context.reads.glyphs
locale.Width(ruler, "Size", true)
assert(context.reads.glyphs == glyphs + 1, "language change retained old width")
locale.Select("en")

local layoutBuilds = 0
env.DFRL.layout = {
    CreateControls = function(parent)
        layoutBuilds = layoutBuilds + 1
        parent.pending = "17,5"
    end,
    SetHandlesVisible = function(value) context.editHandles = value end,
    SetConfirmAnchor = function(anchor) context.confirmAnchor = anchor end,
    RegisterEditorWindow = function(window) context.escapeWindow = window end,
    Snapshot = function() return {} end,
    Copy = function(value) return value end,
    Load = function() end,
    CancelEdit = function()
        display.FinishEdit(false)
        env.fontEditor:Hide()
    end,
    Reset = function()
        display.Reset()
        env.fontEditor:Hide()
    end,
}
env.DFRL.runFont = { Copy = function(value) return value end, Snapshot = function() return {} end }
context:Load("core/profiles.lua", "Profiles")
env.DFRL.sct = {
    GetMode = function() return "on" end,
    GetIncoming = function() return true end,
    Listen = function(callback) context.sctListener = callback end,
    SetMode = function() end,
    SetIncoming = function() end,
    NormalizeMode = function(value) return value end,
}
env.fontEditor, env.fontMenu, env.fontSample, env.fontSampleClock = nil, nil, nil, nil
env.incomingControl, env.sctDescription, env.sctSizeLabel = nil, nil, nil
env.displayControls, env.displayNumbers, env.dependentSettings = {}, {}, {}
env.outlineButtons, env.faceButtons, env.sctButtons = {}, {}, {}
env.currentFont = { face = "DEFAULT", size = 12, outline = "", shadow = true }
env.fontDraft = { face = "DEFAULT", size = 12, outline = "", shadow = true }
env.NewClockLabel = function(source)
    source:Hide()
    return { source = source, ruler = source:GetParent():CreateFontString(nil, "OVERLAY"), parts = {} }
end
env.StyleClockLabel = function(clock, settings)
    clock.source:SetFont("DEFAULT_TEST", settings.size, settings.outline)
    clock.ruler:SetFont("DEFAULT_TEST", settings.size, settings.outline)
end
env.RefreshClockLabel = function(clock)
    assert(clock == env.fontSampleClock, "settings updated another clock owner")
    assert(clock.source:GetParent():IsVisible(), "hidden timer sample reached presentation")
    context.fontSampleRefreshes = (context.fontSampleRefreshes or 0) + 1
end
env.runClock, env.bossClock = {}, {}
env.AZS_RUN, env.AZS_RUN_UPDATED = { endl = 0, nb = 30 }, 1
env.RefreshTimerCaptions = function() context.hudCaptionRefreshes = (context.hudCaptionRefreshes or 0) + 1 end
env.PreviewFont = function() context.fontPreviews = (context.fontPreviews or 0) + 1 end
env.ChangeSize = function() end
local source = assert(loadfile(arg[1]))
setfenv(source, env)
local editor = source()
display.Listen(editor.Display)
display.BeginEdit()
env.DFRL.profiles.BeginEdit()
local openingGlyphs = context.reads.glyphs or 0
editor.Create("layout")
local dialog = env.fontEditor
local pages = dialog.navigation.pages
assert(
    context.escapeWindow == dialog and dialog:GetName() == "SurvivorsDragonUiSettings",
    "settings window was not handed to the shared Escape-close owner"
)
assert(not dialog:IsShown() and not next(pages), "shell construction prepared settings pages")
assert(not env.fontSample and not env.fontMenu and layoutBuilds == 0, "shell prepared timer/menu/Layout controls")
assert(context.reads.glyphs == openingGlyphs + 2, "shell measured unrelated or inactive-language captions")
dialog:Show()
assert(context.reads.glyphs == openingGlyphs + 2, "show repeated cached shell sizing")
assert(layoutBuilds == 1 and pages.layout and not pages.units and not pages.profiles, "first open built hidden pages")
editor.Clock(10.5, 1200, true)
assert(
    env.runClock.seconds == 10
        and context.hudCaptionRefreshes == 1
        and not env.fontSampleClock
        and not context.fontSampleRefreshes,
    "live timer updates touched the unbuilt sample or stopped the HUD clock"
)
assert(
    env.displayControls.performanceMode and not env.displayControls.unitShortHealth,
    "first open built hidden options"
)
local layoutPage = pages.layout
dialog.navigation.Select("units")
assert(
    pages.units and pages.pets and pages.auras and not pages.combat and not pages.timer,
    "category built unrelated pages"
)
local healthChoice = env.displayControls.unitShortHealth
assert(healthChoice.editorChecked == true, "new category did not read current defaults")
context:Call(healthChoice, "OnClick")
assert(
    display.Get("unitShortHealth") == false and not env.SurvivorsDragonUiDisplay,
    "lazy option skipped preview/Confirm"
)
local unitObjects = #context.objects
editor.Clock(11.5, 1200, true)
assert(not env.fontSampleClock and not context.fontSampleRefreshes, "non-timer category built or updated the sample")
dialog.navigation.Select("layout")
dialog.navigation.Select("units")
assert(
    #context.objects == unitObjects and pages.layout == layoutPage and layoutPage.pending == "17,5",
    "revisit rebuilt controls or lost input"
)
assert(healthChoice.editorChecked == false, "revisit discarded a pending choice")
display.FinishEdit(false)
dialog:Hide()
display.BeginEdit()
dialog:Show()
assert(
    healthChoice.editorChecked == true and #context.objects == unitObjects,
    "reopen did not discard/catch up without allocation"
)

dialog.navigation.Select("combat")
assert(pages.combat and pages.nameplates and not pages.meter, "Combat still prepares Damage meter")
assert(
    dialog.navigation.buttons.meter and dialog.navigation.buttons.meter.label:GetText() == "Damage meter",
    "meter has no sidebar category"
)
for _, key in ipairs({ "meter", "action", "encounters", "map", "interface", "profiles" }) do
    dialog.navigation.Select(key)
    local samples = context.fontSampleRefreshes or 0
    editor.Clock(12.5, 1200, true)
    assert(
        (context.fontSampleRefreshes or 0) == samples + (key == "encounters" and 1 or 0),
        "live timer update ignored the selected category's sample visibility"
    )
end
local pageCount = 0
for _ in pairs(pages) do
    pageCount = pageCount + 1
end
assert(pageCount == 20 and layoutBuilds == 1, "full category walk lost or rebuilt sections")
assert(env.fontSampleClock and not env.fontMenu, "Encounters eagerly prepared the closed font popup")
local affixes, shadow = env.displayControls.attachAffixes, env.shadowControl
assert(
    affixes:GetHeight() == 28 and shadow:GetHeight() == 28 and affixes.point[5] == shadow.point[5],
    "Attach affixes and Black shadow are not aligned in the same row"
)
assert(
    affixes.label.point[1] == "LEFT"
        and affixes.label.justifyV == "MIDDLE"
        and env.displayControls.performanceMode.label.point[1] == "LEFT",
    "timer or Performance Mode caption overrides shared checkbox alignment"
)
dialog.navigation.Select("encounters")
context:Call(env.faceLabel:GetParent(), "OnClick")
assert(env.fontMenu and env.fontMenu:IsShown() and next(env.faceButtons), "font popup did not prepare on demand")
local fontMenu, complete = env.fontMenu, #context.objects
dialog.navigation.Select("units")
assert(not fontMenu:IsShown(), "category change retained a foreign font popup")
context:Call(healthChoice, "OnClick")
display.FinishEdit(true)
assert(env.SurvivorsDragonUiDisplay.unitShortHealth == false, "Confirm lost a lazy option")
dialog:Hide()
glyphs = context.reads.glyphs
locale.Select("de")
assert(
    context.reads.glyphs == glyphs and #context.objects == complete,
    "closed language change prepared/measured pages"
)
context:ResetCounts()
dialog.RefreshOptionLayout()
editor.Display()
editor.SCT()
editor.Font()
local sampleRefreshes = context.fontSampleRefreshes
editor.Clock(13.5, 1200, true)
assert(context.fontSampleRefreshes == sampleRefreshes, "closed settings refreshed the timer sample")
context:NoPresentationWrites()
dialog:Show()
dialog.navigation.Select("encounters")
context:Call(env.faceLabel:GetParent(), "OnClick")
assert(env.fontMenu == fontMenu and #context.objects == complete, "locale/reopen rebuilt the font menu or pages")
display.BeginEdit()
dialog.navigation.Select("profiles")
display.Set("unitShortHealth", true)
local profileInput
for _, item in ipairs(context.objects) do
    if item.kind == "EditBox" and item:GetParent() == pages.profiles then profileInput = item end
end
assert(profileInput, "profile name field was not prepared")
profileInput:SetText("Unconfirmed profile")
context:Call(profileInput, "OnEscapePressed")
assert(not dialog:IsShown() and display.Get("unitShortHealth") == false, "profile input Escape did not cancel")
for _, item in ipairs(context.objects) do
    assert(not item:GetScript("OnUpdate"), "lazy settings added a background worker")
end
print(
    "PASS real settings constructor laziness, active-language width cache, full category walk, preview/save/discard and popup reuse"
)
