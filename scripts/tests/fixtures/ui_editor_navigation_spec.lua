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
        local setText = frame.SetText
        function frame:SetText(value)
            setText(self, value)
            context:Call(self, "OnTextChanged")
        end
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
-- Search indexes metadata before it prepares any destination page and reuses
-- the existing settings owners rather than editing their values itself.
local searchPanel = env.CreateFrame("Frame", nil, env.UIParent)
local searchSidebar = env.CreateFrame("Frame", nil, searchPanel)
local searchSections = {
    { key = "home", label = "Layout", group = "layout" },
    {
        key = "damage",
        label = "Combat text",
        group = "combat",
        options = {
            { "icons", "Damage icons", "Spell icons beside outgoing numbers." },
            { "punctuation", "Literal [test].*", "A punctuation caption." },
        },
        search = { { label = "Diablo IV", description = "Choose a damage number style.", offset = 248 } },
    },
    { key = "unused", label = "Unused", group = "unused", options = {} },
}
for index = 1, 18 do
    table.insert(searchSections[3].options, { "choice" .. index, "Unused choice " .. index, "A pooled result." })
end
searchSections[2].options[1].terms = { "shield", "ABSORB" }
local searchBuilds, escapes, searchNavigations = {}, 0, {}
local searchNavigation = env.T.CreateEditorNavigator(searchPanel, searchSidebar, groups, searchSections, {
    search = true,
    width = 684,
    left = 240,
    top = 80,
    height = 552,
    sidebarWidth = 212,
    prepare = function(section, content)
        searchBuilds[section.key] = (searchBuilds[section.key] or 0) + 1
        content:SetHeight(900)
        content.pending = "-12,5"
        section.searchOffsets = { icons = 316 }
    end,
    searchEntries = { { label = "Performance Mode", group = "layout" } },
    onNavigate = function(key) table.insert(searchNavigations, key or "search") end,
    onEscape = function() escapes = escapes + 1 end,
})
searchNavigation.Select("layout")
local searchSlider = env.SurvivorsDragonUiSettingsScrollScrollBar
searchSlider:SetValue(150)
searchNavigation.Search("damage icons")
assert(
    #searchNavigation.results == 1 and not searchBuilds.damage and not searchBuilds.unused,
    "search built unvisited pages"
)
assert(searchNavigation.results[1].target == "icons" and searchNavigation.results[1].section == "damage")
assert(searchNavigations[#searchNavigations] == "search", "results retained Layout handles")
local resultButton = searchNavigation.searchOwner.rows[1]
assert(resultButton:GetWidth() == 145, "search result retained empty viewport width instead of fitting its longer path")
assert(
    resultButton.label.justifyH == "LEFT"
        and resultButton.path.justifyH == "LEFT"
        and resultButton.label.point[4] == 12
        and resultButton.path.point[4] == 12,
    "search result title and category path do not share their left inset"
)
context:Call(resultButton, "OnMouseDown", "LeftButton")
assert(
    resultButton.label.point[1] == "TOPLEFT"
        and resultButton.label.point[4] == 13
        and resultButton.label.point[5] == -6
        and resultButton.path.point[4] == 12
        and resultButton.path.point[5] == -27,
    "pressing a search result recentered its title or displaced the breadcrumb"
)
context:Call(resultButton, "OnMouseUp", "LeftButton")
assert(
    resultButton.label.point[1] == "TOPLEFT" and resultButton.label.point[4] == 12 and resultButton.label.point[5] == -5,
    "released search result did not restore its compact title anchor"
)
local resultObjects = #context.objects
context:ResetCounts()
searchNavigation.Refresh(true)
context:NoPresentationWrites()
assert(not context.reads.glyphs and #context.objects == resultObjects, "settled search results remeasured or allocated")
local titleFace, titleSize, titleFlags = resultButton.label:GetFont()
local pathFace, pathSize, pathFlags = resultButton.path:GetFont()
resultButton.label.naturalWidth = 210.25
resultButton.path.naturalWidth = 90
resultButton.label:SetFont("WIDER_TITLE_FACE", titleSize, titleFlags)
context:ResetCounts()
searchNavigation.Refresh(true)
assert(resultButton:GetWidth() == 236 and context.reads.glyphs, "gold title did not determine its fitted button width")
resultButton.label.naturalWidth = 60
resultButton.path.naturalWidth = 300.5
resultButton.path:SetFont("WIDER_PATH_FACE", pathSize, pathFlags)
searchNavigation.Refresh(true)
assert(resultButton:GetWidth() == 326, "category breadcrumb was clipped by the title width")
resultButton.label.naturalWidth, resultButton.path.naturalWidth = 900, 800
resultButton.label:SetFont("LONG_RESULT_FACE", titleSize, titleFlags)
searchNavigation.Refresh(true)
assert(resultButton:GetWidth() == 660, "long translated result extended beyond the content viewport")
resultButton.label.naturalWidth, resultButton.path.naturalWidth = nil, nil
resultButton.label:SetFont(titleFace, titleSize, titleFlags)
resultButton.path:SetFont(pathFace, pathSize, pathFlags)
searchNavigation.Refresh(true)
assert(
    resultButton:GetWidth() == 145 and #context.objects == resultObjects,
    "short result did not shrink its existing button"
)
resultButton:SetScale(1.25)
context:ResetCounts()
searchNavigation.Refresh(true)
assert(context.reads.glyphs, "search result reused glyph metrics from another owner scale")
resultButton:SetScale(1)
searchNavigation.Refresh(true)
resultButton.label.naturalWidth = 0
resultButton.label:SetFont("UNREADY_RESULT_FACE", titleSize, titleFlags)
context:ResetCounts()
searchNavigation.Refresh(true)
local unreadyReads = context.reads.glyphs or 0
searchNavigation.Refresh(true)
assert((context.reads.glyphs or 0) > unreadyReads, "unavailable result metrics were cached as ready")
resultButton.label.naturalWidth = 160
searchNavigation.Refresh(true)
assert(resultButton:GetWidth() == 185, "available native metrics did not repair the pooled result width")
resultButton.label.naturalWidth = nil
resultButton.label:SetFont(titleFace, titleSize, titleFlags)
searchNavigation.Refresh(true)
searchNavigation.ClearSearch()
assert(
    searchSlider:GetValue() == 150 and searchNavigation.pages.home.pending == "-12,5",
    "clearing lost category scroll or draft"
)
searchNavigation.search:SetText("SHIELD")
assert(#searchNavigation.results == 1, "metadata search aliases were not indexed")
context:Call(searchNavigation.search, "OnEnterPressed")
assert(searchNavigation.selected == "combat" and searchBuilds.damage == 1 and not searchBuilds.unused)
assert(searchSlider:GetValue() == 350, "result did not use the destination's current option offset")
assert(searchNavigation.query == "" and searchNavigation.search:GetText() == "", "redirect retained the query")
local destination = searchNavigation.pages.damage
searchNavigation.Search("diablo style")
assert(#searchNavigation.results == 1 and searchNavigation.results[1].label == "Diablo IV")
searchNavigation.OpenResult(1)
assert(
    searchSlider:GetValue() == 282 and searchNavigation.pages.damage == destination,
    "custom redirect lost its offset or control owner"
)
searchNavigation.Search("[test].*")
assert(
    #searchNavigation.results == 1 and searchNavigation.results[1].target == "punctuation",
    "search interpreted pattern punctuation"
)
searchNavigation.Search("not-present")
assert(
    #searchNavigation.results == 0 and searchNavigation.searchOwner.empty:IsShown(),
    "empty results were not explained"
)
local beforeNoHit = #context.objects
context:ResetCounts()
searchNavigation.Search("not-present")
context:NoPresentationWrites()
assert(#context.objects == beforeNoHit, "unchanged query allocated views")
searchNavigation.Search("unused choice")
assert(#searchNavigation.results == 18 and #searchNavigation.searchOwner.rows == 8 and not searchBuilds.unused)
local searchPool = #context.objects
context:Call(searchNavigation.searchOwner.next, "OnClick")
assert(searchNavigation.searchOwner.page == 2 and searchNavigation.searchOwner.rows[1].resultIndex == 9)
context:Call(searchNavigation.searchOwner.next, "OnClick")
assert(searchNavigation.searchOwner.page == 3 and searchNavigation.searchOwner.rows[1].resultIndex == 17)
assert(
    not searchNavigation.searchOwner.rows[3]:IsShown() and #context.objects == searchPool,
    "paging expanded the result pool"
)
context:Call(searchNavigation.searchOwner.previous, "OnClick")
assert(searchNavigation.searchOwner.page == 2 and #context.objects == searchPool)
local twoDigitResultWidth = searchNavigation.searchOwner.rows[1]:GetWidth()
context:Call(searchNavigation.searchOwner.previous, "OnClick")
assert(
    searchNavigation.searchOwner.page == 1
        and searchNavigation.searchOwner.rows[1]:GetWidth() < twoDigitResultWidth
        and #context.objects == searchPool,
    "paging to shorter captions retained a wider result or rebuilt its pool"
)
searchNavigation.Search("performance")
searchNavigation.OpenResult(1)
assert(searchNavigation.selected == "layout", "standalone result did not redirect to its existing owner")

local originalText = env.DFRL.locale.Text
local setResultText = resultButton.label.SetText
function resultButton.label:SetText(source) setResultText(self, env.DFRL.locale.Text(source)) end
env.DFRL.locale.Text = function(source)
    if env.DFRL.locale.code == "ru" and source == "Damage icons" then return "ЗНАЧКИ УРОНА" end
    if env.DFRL.locale.code == "de" and source == "Damage icons" then return "ÄNDERUNG" end
    return source
end
env.DFRL.locale.code = "ru"
context:NotifyLocale()
searchNavigation.Search("значки урона")
assert(
    #searchNavigation.results == 1 and searchNavigation.results[1].target == "icons",
    "localized Cyrillic case folding failed"
)
local translatedResultWidth = resultButton:GetWidth()
context:ResetCounts()
searchNavigation.Search("Damage icons")
assert(#searchNavigation.results == 1, "English fallback search disappeared in another language")
assert(not context.reads.glyphs, "unchanged translated result captions were measured again")
env.DFRL.locale.code = "de"
context:NotifyLocale()
searchNavigation.Search("änderung")
assert(#searchNavigation.results == 1, "accented Latin case folding failed")
assert(
    resultButton:GetWidth() < translatedResultWidth,
    "shorter active-language captions kept the previous button width"
)
searchNavigation.search.focused = true
searchPanel:Hide()
assert(searchNavigation.query == "" and not searchNavigation.search.focused, "close retained search query or focus")
context:ResetCounts()
env.DFRL.locale.code = "ru"
context:NotifyLocale()
searchNavigation.Refresh(true)
context:NoPresentationWrites()
assert(not context.reads.glyphs, "closed search measured compact result captions")
local closedSearchPool = #context.objects
searchPanel:Show()
searchNavigation.Refresh(true)
assert(
    searchNavigation.query == "" and #context.objects == closedSearchPool,
    "reopen rebuilt search or replayed results"
)
searchNavigation.Search("diablo")
context:Call(searchNavigation.search, "OnEscapePressed")
assert(escapes == 1 and searchNavigation.query == "", "search Escape skipped the shared close callback")
searchNavigation.Search("unused choice")
searchNavigation.Select("combat")
assert(
    searchNavigation.query == "" and searchNavigation.pages.damage == destination,
    "sidebar navigation retained search or replaced drafts"
)
env.DFRL.locale.Text, env.DFRL.locale.code = originalText, "en"
resultButton.label.SetText = setResultText
searchPanel:Hide()

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
    ConfirmEdit = function()
        context.profileCommits = (context.profileCommits or 0) + 1
        if context.rejectProfileCommit then return false end
        display.FinishEdit(true)
        env.DFRL.profiles.FinishEdit(true)
        env.fontEditor:Hide()
        return true
    end,
    CancelEdit = function()
        display.FinishEdit(false)
        env.DFRL.profiles.FinishEdit(false)
        env.fontEditor:Hide()
    end,
    Reset = function()
        display.Reset()
        env.DFRL.profiles.FinishEdit(false)
        env.fontEditor:Hide()
    end,
}
env.DFRL.runFont = {
    Copy = function(value) return value end,
    Snapshot = function() return context.profileRunFont or {} end,
    Load = function(value) context.profileRunFont = value end,
}
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
assert(context.reads.glyphs == openingGlyphs + 3, "show measured more than the search header and existing shell")
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
assert(dialog.navigation.search and dialog.navigation.search.maxLetters == 128, "settings has no native search input")
dialog.navigation.Search("shield")
assert(
    #dialog.navigation.results == 2 and not pages.units,
    "shield search missed existing health controls or built their page"
)
assert(
    not context.editHandles and not env.SurvivorsDragonUiDisplay,
    "search changed settings or retained Layout overlays"
)
dialog.navigation.ClearSearch()
assert(context.editHandles and pages.layout.pending == "17,5", "clearing search lost Layout state or handles")
dialog.navigation.Search("sct icons")
assert(#dialog.navigation.results == 1 and not pages.combat, "SCT aliases missed damage icons or eagerly built Combat")
assert(dialog.navigation.results[1].target == "damageIcons" and dialog.navigation.results[1].group == "combat")
dialog.navigation.ClearSearch()
dialog.navigation.Search("marks rewards")
assert(#dialog.navigation.results == 1 and not pages.loot, "generic hidden settings were not searchable")
dialog.navigation.ClearSearch()
local layoutPage = pages.layout
assert(dialog.uiFontButtons.default.editorSelected, "Layout did not select the default font")
assert(not dialog.uiFontButtons.friz, "Layout still offers the removed Friz Quadrata choice")
context:Call(dialog.uiFontButtons.arial, "OnClick")
editor.Display()
assert(display.Get("uiFont") == "arial" and not env.SurvivorsDragonUiDisplay, "Layout font saved before Confirm")
assert(dialog.uiFontButtons.arial.editorSelected, "Layout font selection did not refresh")
assert(display.Get("sctFont") == "default", "Layout font changed the independent SCT choice")
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
assert(display.Get("uiFont") == "default", "Cancel retained the Layout font")
dialog.navigation.Select("layout")
assert(dialog.uiFontButtons.default.editorSelected, "Layout did not refresh the discarded font on re-entry")
dialog.navigation.Select("units")
assert(
    healthChoice.editorChecked == true and #context.objects == unitObjects,
    "reopen did not discard/catch up without allocation"
)

dialog.navigation.Select("combat")
assert(pages.combat and pages.nameplates and not pages.meter, "Combat still prepares Damage meter")
dialog.navigation.Search("damage over time")
assert(#dialog.navigation.results == 1, "custom combat filters were absent from search")
dialog.navigation.OpenResult(1)
assert(
    dialog.navigation.selected == "combat" and display.Get("sctPeriodicDamage") and not env.SurvivorsDragonUiDisplay,
    "search result changed the existing filter instead of redirecting"
)
dialog.navigation.Search("Diablo")
assert(#dialog.navigation.results >= 2, "custom style and font choices were absent from search")
dialog.navigation.ClearSearch()
assert(pages.combat:GetHeight() >= 532, "abbreviation clipped the final damage filters")
assert(display.Get("sctShortNumbers") == false, "abbreviation was enabled by default")
context:Call(env.displayControls.sctShortNumbers, "OnClick")
assert(display.Get("sctShortNumbers") and not env.SurvivorsDragonUiDisplay, "abbreviation did not preview")
assert(dialog.sctFontButtons.default.editorSelected, "the game font is not the default")
context:Call(dialog.sctFontButtons.diablo, "OnClick")
editor.SCT()
assert(display.Get("sctFont") == "diablo" and dialog.sctFontButtons.diablo.editorSelected, "font did not preview")
assert(dialog.sctStyleButtons.enemy.editorSelected, "the original enemy style is not selected by default")
context:Call(dialog.sctStyleButtons.diablo, "OnClick")
editor.SCT()
assert(
    display.Get("sctStyle") == "diablo" and dialog.sctStyleButtons.diablo.editorSelected,
    "Diablo selector did not preview"
)
display.FinishEdit(false)
editor.SCT()
assert(
    display.Get("sctStyle") == "enemy" and dialog.sctStyleButtons.enemy.editorSelected,
    "Cancel retained the new style"
)
assert(display.Get("sctFont") == "default" and dialog.sctFontButtons.default.editorSelected, "Cancel retained font")
assert(not display.Get("sctShortNumbers"), "Cancel retained abbreviation")
display.BeginEdit()
assert(
    dialog.navigation.buttons.meter and dialog.navigation.buttons.meter.label:GetText() == "Damage meter",
    "meter has no sidebar category"
)
dialog.navigation.Search("meter name font")
assert(
    #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "meterNameFontSize" and not pages.meter,
    "name-font search missed its original lazy meter control"
)
dialog.navigation.OpenResult(1)
local meterNameValue, meterNumberValue = env.displayNumbers.meterNameFontSize, env.displayNumbers.meterFontSize
assert(meterNameValue and meterNumberValue and dialog.navigation.selected == "meter")
local meterNameControl, meterNumberControl = meterNameValue:GetParent(), meterNumberValue:GetParent()
assert(
    meterNameControl.label:GetText() == "Name font size" and meterNumberControl.label:GetText() == "Number font size",
    "meter font controls do not explain their independent scope"
)
local function IncreaseNumber(control)
    for _, object in ipairs(context.objects) do
        if object.kind == "Button" and object:GetParent() == control and object.label:GetText() == "+" then
            context:Call(object, "OnClick")
            return
        end
    end
    error("missing production numeric step button")
end
IncreaseNumber(meterNameControl)
editor.Display()
assert(
    display.Get("meterNameFontSize") == 12 and display.Get("meterFontSize") == 11 and meterNameValue:GetText() == "12",
    "name font did not preview independently"
)
IncreaseNumber(meterNumberControl)
IncreaseNumber(meterNumberControl)
assert(
    display.Get("meterFontSize") == 13 and display.Get("meterNameFontSize") == 12,
    "number font changed the name choice"
)
assert(not env.SurvivorsDragonUiDisplay, "font step controls saved before Confirm")
local meterObjects = #context.objects
dialog.navigation.Search("meter number font")
assert(#dialog.navigation.results == 1 and dialog.navigation.results[1].target == "meterFontSize")
dialog.navigation.OpenResult(1)
assert(
    #context.objects == meterObjects and env.displayNumbers.meterNameFontSize == meterNameValue,
    "search rebuilt meter settings"
)
display.FinishEdit(false)
display.BeginEdit()
editor.Display()
assert(display.Get("meterNameFontSize") == 11 and display.Get("meterFontSize") == 11, "Cancel retained font previews")
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
display.BeginEdit()
dialog:Show()
dialog.navigation.Select("action")
local xpText = assert(env.displayControls.xpShowText, "Action bar did not prepare Show XP text")
assert(not xpText.editorChecked, "XP text was enabled by default")
context:Call(xpText, "OnClick")
editor.Display()
assert(display.Get("xpShowText") and xpText.editorChecked, "XP text checkbox did not preview")
assert(not env.SurvivorsDragonUiDisplay.xpShowText, "XP text checkbox saved before Confirm")
env.DFRL.layout.CancelEdit()
assert(not display.Get("xpShowText"), "Cancel retained the XP text checkbox")
local function ProfileSaveControls()
    local profiles = env.DFRL.profiles
    local function Open()
        display.BeginEdit()
        profiles.BeginEdit()
        dialog:Show()
        dialog.navigation.Select("profiles")
    end
    local function Button(caption)
        for _, object in ipairs(context.objects) do
            if
                object.kind == "Button"
                and object:GetParent() == pages.profiles
                and object.label
                and object.label:GetText() == locale.Text(caption)
            then
                return object
            end
        end
        error("missing profile button: " .. caption)
    end
    Open()
    local save = Button("Save profile and close")
    profileInput:SetText("")
    context:Call(save, "OnClick")
    assert(dialog:IsShown() and not context.profileCommits, "invalid name committed or closed the editor")
    display.Set("uiFont", "arial")
    display.Set("xpShowText", true)
    profileInput:SetText("Handheld")
    context:Call(save, "OnClick")
    assert(not dialog:IsShown() and context.profileCommits == 1, "profile save did not close through one shared commit")
    assert(env.SurvivorsDragonUiDisplay.uiFont == "arial" and env.SurvivorsDragonUiDisplay.xpShowText)
    assert(env.SurvivorsDragonUiProfiles.Handheld.display.uiFont == "arial", "named snapshot was not committed")
    Open()
    display.Set("uiFont", "skurri")
    context:Call(Button("Overwrite and close"), "OnClick")
    assert(not dialog:IsShown() and context.profileCommits == 2, "overwrite required another Confirm")
    assert(env.SurvivorsDragonUiProfiles.Handheld.display.uiFont == "skurri")
    Open()
    profileInput:SetText("Keyboard")
    context:Call(profileInput, "OnEnterPressed")
    assert(not dialog:IsShown() and context.profileCommits == 3, "Enter did not save and close")
    assert(env.SurvivorsDragonUiProfiles.Keyboard and env.SurvivorsDragonUiProfiles.Handheld)
    Open()
    context.rejectProfileCommit = true
    display.Set("uiFont", "morpheus")
    context:Call(Button("Overwrite and close"), "OnClick")
    assert(
        dialog:IsShown() and env.SurvivorsDragonUiProfiles.Keyboard.display.uiFont == "skurri",
        "failed commit changed saved data"
    )
    assert(not profiles.Save("Rejected", false) and not env.SurvivorsDragonUiProfiles.Rejected)
    for _, name in ipairs(profiles.List()) do
        assert(name ~= "Rejected", "failed new save left a staged profile")
    end
    context.rejectProfileCommit = false
    assert(
        profiles.Load("Keyboard") and display.Get("uiFont") == "skurri",
        "failed overwrite left a staged replacement"
    )
    assert(
        context.profileRunFont == env.SurvivorsDragonUiProfiles.Keyboard.runFont,
        "load skipped the timer-font owner"
    )
    context:Call(Button("Delete profile"), "OnClick")
    assert(dialog:IsShown() and env.SurvivorsDragonUiProfiles.Keyboard, "delete stopped being a preview")
    env.DFRL.layout.CancelEdit()
    assert(env.SurvivorsDragonUiProfiles.Keyboard and env.SurvivorsDragonUiDisplay.uiFont == "skurri")
    for index = 1, 5 do
        Open()
        profileInput:SetText("Paged " .. index)
        context:Call(profileInput, "OnEnterPressed")
    end
    Open()
    local found
    for _, object in ipairs(context.objects) do
        if object:GetParent() == pages.profiles and object.profileName == "Paged 5" and object:IsVisible() then
            found = true
        end
    end
    assert(found and profileInput:GetText() == "Paged 5", "reopening lost the saved profile's selection or page")
    env.DFRL.layout.CancelEdit()
end
ProfileSaveControls()
for _, item in ipairs(context.objects) do
    assert(not item:GetScript("OnUpdate"), "lazy settings added a background worker")
end
print(
    "PASS real settings constructor laziness, active-language width cache, full category walk, preview/save/discard and popup reuse"
)
