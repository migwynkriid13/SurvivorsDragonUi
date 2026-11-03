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
    local enableMouse = result.EnableMouse
    function result:EnableMouse(value)
        enableMouse(self, value)
        self.mouse = value
    end
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
        local setVertexColor = result.SetVertexColor
        function result:SetVertexColor(...)
            setVertexColor(self, ...)
            self.vertexColor = { ... }
        end
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
        function frame:EnableKeyboard(value) self.keyboard = value end
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
assert(
    navigation.searchHeight == 0 and navigation.buttons.layout.point[5] == -48,
    "search-free categories reserved a search row"
)
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
local function AssertSidebarSearch(navigation, sidebar, width)
    local input = navigation.search
    local header = input:GetParent()
    assert(header:GetParent() == sidebar and header.point[2] == sidebar, "search header left the shared sidebar")
    assert(
        header.point[4] == 6 and header.point[5] == -4 and header:GetWidth() == width and header:GetHeight() == 56,
        "sidebar search header geometry changed"
    )
    assert(navigation.searchHeight == 64, "categories did not reserve the compact sidebar search block")
    assert(input:GetWidth() == width and input:GetHeight() == 28, "sidebar input did not retain the full column width")
    assert(
        input.point[2] == header and input.point[4] == 0 and input.point[5] == -24,
        "sidebar input lost its caption clearance"
    )
    local caption
    for _, item in ipairs(context.objects) do
        if item.kind == "FontString" and item:GetParent() == header then caption = item end
    end
    assert(
        caption and caption:GetHeight() == 18 and caption.point[4] == 0 and caption.point[5] == -2,
        "sidebar search caption moved or wrapped into the input"
    )
    return header
end
local searchScroll = env.SurvivorsDragonUiSettingsScroll
local searchHeader = AssertSidebarSearch(searchNavigation, searchSidebar, 212)
assert(
    searchScroll.point[4] == 240 and searchScroll.point[5] == -80 and searchScroll:GetHeight() == 552,
    "sidebar search consumed the right-hand viewport"
)
for index, group in ipairs(groups) do
    local button = searchNavigation.buttons[group.key]
    assert(
        button:GetParent() == searchSidebar and button.point[5] == -112 - (index - 1) * 48 and button:GetHeight() == 42,
        "sidebar categories overlap the search block"
    )
end
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
assert(
    searchNavigation.searchOwner.frame:GetParent() == searchScroll.child
        and resultButton:GetParent() == searchNavigation.searchOwner.frame,
    "sidebar search moved results out of the main content pane"
)
assert(
    searchHeader:IsVisible() and searchScroll:GetHeight() == 552,
    "results hid the shared sidebar header or reduced the viewport"
)
assert(
    resultButton:GetWidth() == 360 and resultButton:GetHeight() == 42,
    "search results do not use the compact fixed row size"
)
assert(
    not resultButton.editorPieces
        and resultButton.label.justifyH == "LEFT"
        and resultButton.path.justifyH == "LEFT"
        and resultButton.label.point[1] == "TOPLEFT"
        and resultButton.label.point[4] == 10
        and resultButton.label.point[5] == -4
        and resultButton.path.point[4] == 10
        and resultButton.path.point[5] == -24,
    "plain search rows retained the textured button skin or lost their aligned text"
)
local function ResultHighlight(row)
    local highlight, count = nil, 0
    for _, item in ipairs(context.objects) do
        if item.kind == "Texture" and item:GetParent() == row then
            highlight, count = item, count + 1
        end
    end
    assert(
        count == 1 and highlight:GetTexture() == "Interface\\Buttons\\WHITE8X8",
        "result row allocated decorative texture layers"
    )
    return highlight
end
local resultHighlight = ResultHighlight(resultButton)
assert(
    not resultHighlight:IsShown() and resultHighlight.vertexColor and resultHighlight.vertexColor[4] <= 0.1,
    "plain search row draws a persistent or heavy hover fill"
)
local red, green, blue = resultButton.label:GetTextColor()
assert(red >= 0.9 and green >= 0.7 and blue <= 0.5, "result title lost its gold caption")
context:Call(resultButton, "OnEnter")
assert(resultHighlight:IsShown(), "plain result row has no hover feedback")
context:Call(resultButton, "OnLeave")
assert(not resultHighlight:IsShown(), "result hover survives mouse leave")
context:Call(resultButton, "OnMouseDown", "LeftButton")
context:Call(resultButton, "OnMouseUp", "LeftButton")
assert(
    resultButton.label.point[1] == "TOPLEFT" and resultButton.label.point[4] == 10 and resultButton.label.point[5] == -4,
    "plain result row retained the old pressed caption displacement"
)
local resultObjects = #context.objects
context:ResetCounts()
searchNavigation.Refresh(true)
context:NoPresentationWrites()
assert(
    not context.reads.glyphs and #context.objects == resultObjects,
    "settled search results measured text or allocated"
)
local titleFace, titleSize, titleFlags = resultButton.label:GetFont()
resultButton.label.naturalWidth, resultButton.path.naturalWidth = 900, 800
resultButton.label:SetFont("OTHER_RESULT_FACE", titleSize, titleFlags)
resultButton:SetScale(1.25)
context:ResetCounts()
searchNavigation.Refresh(true)
assert(
    resultButton:GetWidth() == 360 and not context.reads.glyphs and #context.objects == resultObjects,
    "result width depends on caption length, font metrics or owner scale"
)
resultButton.label.naturalWidth, resultButton.path.naturalWidth = nil, nil
resultButton.label:SetFont(titleFace, titleSize, titleFlags)
resultButton:SetScale(1)
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
for slot, row in ipairs(searchNavigation.searchOwner.rows) do
    assert(
        row:GetWidth() == 360 and row:GetHeight() == 42 and row.point[5] == -(slot - 1) * 46,
        "paged results lost their fixed list geometry"
    )
    ResultHighlight(row)
end
local retiredHover = ResultHighlight(searchNavigation.searchOwner.rows[3])
context:Call(searchNavigation.searchOwner.rows[3], "OnEnter")
assert(retiredHover:IsShown())
context:Call(searchNavigation.searchOwner.next, "OnClick")
assert(
    not searchNavigation.searchOwner.rows[3]:IsShown() and not retiredHover:IsShown(),
    "retiring a pooled result retained its hover"
)
context:Call(searchNavigation.searchOwner.previous, "OnClick")
context:Call(searchNavigation.searchOwner.previous, "OnClick")
assert(
    searchNavigation.searchOwner.page == 1
        and searchNavigation.searchOwner.rows[1]:GetWidth() == 360
        and #context.objects == searchPool,
    "paging to shorter captions changed the fixed width or rebuilt its pool"
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
assert(resultButton:GetWidth() == 360, "translated result changed its fixed row width")
context:ResetCounts()
searchNavigation.Search("Damage icons")
assert(#searchNavigation.results == 1, "English fallback search disappeared in another language")
assert(not context.reads.glyphs, "plain translated results measured their captions")
env.DFRL.locale.code = "de"
context:NotifyLocale()
searchNavigation.Search("änderung")
assert(#searchNavigation.results == 1, "accented Latin case folding failed")
assert(resultButton:GetWidth() == 360, "shorter active-language captions changed the fixed row width")
searchNavigation.search.focused = true
context:Call(resultButton, "OnEnter")
assert(resultHighlight:IsShown())
searchPanel:Hide()
assert(not resultHighlight:IsShown(), "closing search retained its result hover")
assert(searchNavigation.query == "" and not searchNavigation.search.focused, "close retained search query or focus")
context:ResetCounts()
env.DFRL.locale.code = "ru"
context:NotifyLocale()
searchNavigation.Refresh(true)
context:NoPresentationWrites()
assert(not context.reads.glyphs, "closed search measured result captions")
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
local categoryObjects = #context.objects
for _, key in ipairs({ "layout", "combat", "layout", "combat" }) do
    searchNavigation.Select(key)
    assert(
        searchNavigation.search:GetParent() == searchHeader and searchHeader:IsVisible(),
        "category switch replaced or hid the sidebar search header"
    )
end
assert(#context.objects == categoryObjects, "category switches allocated another search header")
searchPanel:Hide()

local narrowPanel = env.CreateFrame("Frame", nil, env.UIParent)
local narrowSidebar = env.CreateFrame("Frame", nil, narrowPanel)
local narrowNavigation = env.T.CreateEditorNavigator(narrowPanel, narrowSidebar, groups, {
    {
        key = "narrow",
        label = "Combat text",
        group = "combat",
        options = { { "icons", "Damage icons", "Spell icons." } },
    },
}, {
    search = true,
    width = 264,
    left = 0,
    top = 0,
    height = 552,
    sidebarWidth = 212,
})
narrowNavigation.Search("damage icons")
assert(narrowNavigation.searchOwner.rows[1]:GetWidth() == 240, "fixed result row exceeded a narrower content viewport")
narrowPanel:Hide()

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
    control.description:SetWidth(178)
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
assert(number.description.point[5] == -38 and number.description:GetWidth() == 178, "number help overlaps steps")
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
local outgoingMode = "on"
env.DFRL.sct = {
    GetMode = function() return outgoingMode end,
    GetIncoming = function() return true end,
    Listen = function(callback) context.sctListener = callback end,
    SetMode = function(value)
        outgoingMode = value
        if context.sctListener then context.sctListener() end
    end,
    SetIncoming = function() end,
    NormalizeMode = function(value) return value end,
}
env.fontEditor, env.fontMenu, env.fontSample, env.fontSampleClock = nil, nil, nil, nil
env.incomingControl, env.sctDescription, env.sctSizeLabel = nil, nil, nil
env.displayControls, env.displayNumbers, env.dependentSettings = {}, {}, {}
env.faceButtons = {}
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
local function SelectChoice(control, value)
    context:Call(control, "OnClick")
    local menu = dialog.editorDropdownMenu
    if control.dropdownEnabled == false then
        assert(not menu or not menu:IsShown(), "disabled dropdown opened")
        return
    end
    assert(menu and menu:IsShown() and menu.owner == control, "dropdown lost its owner")
    for _, item in ipairs(menu.buttons) do
        if item.choice == value then
            context:Call(item, "OnClick")
            assert(not menu:IsShown() and not menu.owner, "selection retained dropdown ownership")
            return
        end
    end
    error("missing dropdown choice: " .. tostring(value))
end
assert(
    context.escapeWindow == dialog and dialog:GetName() == "SurvivorsDragonUiSettings",
    "settings window was not handed to the shared Escape-close owner"
)
assert(not dialog:IsShown() and not next(pages), "shell construction prepared settings pages")
assert(not env.fontSample and not env.fontMenu and layoutBuilds == 0, "shell prepared timer/menu/Layout controls")
assert(context.reads.glyphs == openingGlyphs + 2, "shell measured unrelated or inactive-language captions")
dialog:Show()
assert(context.reads.glyphs == openingGlyphs + 2, "show measured unrelated settings captions")
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
local dialogSearch = dialog.navigation.search
local dialogSidebar = dialogSearch:GetParent():GetParent()
local dialogSearchHeader = AssertSidebarSearch(dialog.navigation, dialogSidebar, 232)
local performanceControl = env.displayControls.performanceMode
assert(
    performanceControl:GetParent() == dialogSidebar and performanceControl.point[5] == -68,
    "Performance Mode did not move below the sidebar search"
)
assert(
    -dialogSearchHeader.point[5] + dialogSearchHeader:GetHeight() <= -performanceControl.point[5],
    "search header overlaps Performance Mode"
)
local categoryKeys =
    { "layout", "units", "combat", "meter", "action", "jewelry", "encounters", "map", "interface", "profiles" }
local previousBottom = -performanceControl.point[5] + performanceControl:GetHeight()
for index, key in ipairs(categoryKeys) do
    local button = dialog.navigation.buttons[key]
    local top = -button.point[5]
    assert(
        button:GetParent() == dialogSidebar and top == 112 + (index - 1) * 46 and top >= previousBottom,
        "category rows overlap search, Performance Mode or another category"
    )
    previousBottom = top + button:GetHeight()
end
assert(
    previousBottom == 566 and previousBottom <= dialogSidebar:GetHeight(),
    "the tenth sidebar category extends into the footer"
)
local dialogScroll = env.SurvivorsDragonUiSettingsScroll
assert(
    dialogScroll:GetParent() == dialog and dialogScroll.point[5] == -56 and dialogScroll:GetHeight() == 576,
    "search reduced the full settings content viewport"
)
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
assert(dialog.uiFontDropdown.dropdownValue == "default", "Layout did not select the default font")
for _, entry in ipairs(dialog.uiFontDropdown.dropdownChoices) do
    assert(entry.value ~= "friz")
end
SelectChoice(dialog.uiFontDropdown, "arial")
editor.Display()
assert(display.Get("uiFont") == "arial" and not env.SurvivorsDragonUiDisplay, "Layout font saved before Confirm")
assert(dialog.uiFontDropdown.dropdownValue == "arial", "Layout font selection did not refresh")
assert(display.Get("sctFont") == "default", "Layout font changed the independent SCT choice")
local globalShadow = assert(env.displayControls.uiFontShadow, "Layout did not prepare Black shadow")
assert(
    globalShadow.editorChecked and dialog.uiFontOutlineDropdown.dropdownValue == "OUTLINE",
    "Layout lost font-style defaults"
)
local globalFontObjects = #context.objects
for _, performance in ipairs({ false, true }) do
    display.Set("performanceMode", performance)
    for _, outline in ipairs({ "", "OUTLINE", "THICKOUTLINE" }) do
        SelectChoice(dialog.uiFontOutlineDropdown, outline)
        editor.Display()
        assert(display.Get("uiFontOutline") == outline and not env.SurvivorsDragonUiDisplay)
        assert(dialog.uiFontOutlineDropdown.dropdownValue == outline)
        context:ResetCounts()
        dialog.uiFontOutlineDropdown:SetValue(outline)
        editor.Display()
        context:NoPresentationWrites()
    end
    context:Call(globalShadow, "OnClick")
    editor.Display()
    assert(globalShadow.editorChecked == display.Get("uiFontShadow"), "Black shadow did not preview")
    assert(not env.SurvivorsDragonUiDisplay, "Black shadow saved before Confirm")
end
context:Call(globalShadow, "OnClick")
editor.Display()
assert(not globalShadow.editorChecked and not display.Get("uiFontShadow"), "Black shadow could not be disabled")
assert(#context.objects == globalFontObjects, "font-style choices allocated replacement controls")
dialog.navigation.Search("thick outline")
local foundLayoutOutline
for _, result in ipairs(dialog.navigation.results) do
    if result.group == "layout" then
        assert(result.entry.offset == 338, "global outline search does not redirect to its controls")
        foundLayoutOutline = true
    end
end
assert(foundLayoutOutline and not pages.timer, "global outline was missing from search or eagerly prepared Encounters")
dialog.navigation.ClearSearch()
dialog.navigation.Search("black shadow")
local foundLayoutShadow
for _, result in ipairs(dialog.navigation.results) do
    if result.group == "layout" then
        assert(result.target == "uiFontShadow" and result.entry.offset == 454, "global shadow search lost its control")
        foundLayoutShadow = true
    end
end
assert(foundLayoutShadow, "global Black shadow was missing from search")
dialog.navigation.ClearSearch()
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
assert(dialog.uiFontDropdown.dropdownValue == "default", "Layout did not refresh the discarded font on re-entry")
assert(
    display.Get("uiFontOutline") == "OUTLINE"
        and display.Get("uiFontShadow")
        and dialog.uiFontOutlineDropdown.dropdownValue == "OUTLINE"
        and globalShadow.editorChecked,
    "Cancel/reopen retained draft outline or shadow"
)
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
assert(pages.combat:GetHeight() >= 604, "distance scaling clipped the final damage filters")
assert(display.Get("sctAreaDamage") == true, "Area of Effect did not default on")
dialog.navigation.Search("Area of Effect")
assert(
    #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "sctAreaDamage",
    "Area of Effect was absent from settings search"
)
dialog.navigation.OpenResult(1)
assert(
    env.displayControls.sctAreaDamage.label:GetText() == "Area of Effect"
        and not env.displayControls.sctAreaDamage.description
        and env.displayControls.sctAreaDamage:GetHeight() == 28
        and env.displayControls.sctAreaDamage:GetWidth() == env.displayControls.sctPeriodicDamage:GetWidth()
        and env.displayControls.sctAreaDamage.point[5] == env.displayControls.sctPeriodicDamage.point[5]
        and pages.combat:GetHeight() >= 640,
    "Area of Effect did not share the compact damage-category grid"
)
context:Call(env.displayControls.sctAreaDamage, "OnClick")
assert(not display.Get("sctAreaDamage") and not env.SurvivorsDragonUiDisplay, "AoE preview saved before Confirm")
context:Call(env.displayControls.sctAreaDamage, "OnClick")
assert(display.Get("sctAreaDamage"), "AoE preview did not restore on")
dialog.navigation.ClearSearch()
assert(display.Get("sctScale") == 0.9 and env.sctSizeLabel:GetText() == "90%", "default SCT size did not show 90%")
assert(display.Get("sctShortNumbers") == true, "abbreviation was disabled by default")
assert(display.Get("sctDistanceScaling") == false, "distance scaling was enabled by default")
dialog.navigation.Search("Scale damage by distance")
assert(
    #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "sctDistanceScaling",
    "distance choice was absent from search"
)
dialog.navigation.OpenResult(1)
assert(env.displayControls.sctDistanceScaling.description, "distance choice lost its help text")
context:Call(env.displayControls.sctDistanceScaling, "OnClick")
assert(display.Get("sctDistanceScaling") and not env.SurvivorsDragonUiDisplay, "distance preview saved before Confirm")
dialog.navigation.ClearSearch()
assert(pages.combat:GetHeight() >= 736, "distance controls clipped the last filters")
assert(dialog.sctDistanceSettings and #dialog.sctDistanceSettings.controls == 4, "missing numeric distance controls")
assert(display.Get("sctDistanceReference") == 20 and display.Get("sctDistanceMinimum") == 55)
for _, button in ipairs(dialog.sctDistanceSettings.controls) do
    assert(button.mouse, "enabled scaling kept number input disabled")
end
context:Call(dialog.sctDistanceSettings.controls[2], "OnClick")
assert(display.Get("sctDistanceReference") == 21 and not env.SurvivorsDragonUiDisplay, "distance step did not preview")
dialog.navigation.Search("Minimum size (%)")
assert(
    #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "sctDistanceMinimum",
    "minimum size missing from search"
)
dialog.navigation.OpenResult(1)
dialog.navigation.ClearSearch()
display.Set("sctStyle", "msbt")
for _, button in ipairs(dialog.sctDistanceSettings.controls) do
    assert(not button.mouse, "MSBT retained distance input")
end
display.Set("sctStyle", "diablo")
display.Set("sctDistanceScaling", false)
for _, button in ipairs(dialog.sctDistanceSettings.controls) do
    assert(not button.mouse, "off scaling retained distance input")
end
display.Set("sctDistanceScaling", true)
dialog.navigation.Search("Group damage numbers")
assert(
    #dialog.navigation.results >= 1 and dialog.navigation.results[1].target == "sctGroupDamage",
    "grouping toggle was absent from search"
)
dialog.navigation.OpenResult(1)
local grouping = assert(dialog.sctGroupSettings)
local groupingToggle = assert(env.displayControls.sctGroupDamage)
assert(not display.Get("sctGroupDamage") and not grouping.dropdown.mouse, "grouping input did not start off")
dialog.navigation.Search("Show hit count")
assert(
    #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "sctShowGroupCount",
    "hit-count toggle was absent from search"
)
dialog.navigation.OpenResult(1)
local countToggle = assert(env.displayControls.sctShowGroupCount)
assert(countToggle.editorChecked and not countToggle.mouse, "hit count should default on and depend on grouping")
context:Call(groupingToggle, "OnClick")
assert(grouping.dropdown.mouse and grouping.dropdown.dropdownValue == 0.5, "grouping window did not become available")
assert(countToggle.mouse, "enabled grouping kept the hit-count toggle disabled")
context:Call(countToggle, "OnClick")
assert(not display.Get("sctShowGroupCount") and not env.SurvivorsDragonUiDisplay, "hit count did not preview")
SelectChoice(grouping.dropdown, 0.75)
assert(display.Get("sctGroupWindow") == 0.75 and not env.SurvivorsDragonUiDisplay, "window selection did not preview")
context:Call(groupingToggle, "OnClick")
assert(not grouping.dropdown.mouse and display.Get("sctGroupWindow") == 0.75, "off grouping lost its selected window")
assert(not countToggle.mouse and not countToggle.editorChecked, "off grouping lost its hit-count choice")
context:Call(groupingToggle, "OnClick")
dialog.navigation.ClearSearch()
context:Call(env.displayControls.sctShortNumbers, "OnClick")
assert(not display.Get("sctShortNumbers") and not env.SurvivorsDragonUiDisplay, "full numbers did not preview")
local function AssertSctFont(selected)
    assert(display.Get("sctFont") == selected and dialog.sctFontDropdown.dropdownValue == selected)
    assert(not env.SurvivorsDragonUiDisplay, "font choice saved before Confirm")
end
local function AssertSctStyle(selected)
    assert(display.Get("sctStyle") == selected and dialog.sctStyleDropdown.dropdownValue == selected)
end
AssertSctFont("default")
local sctObjects = #context.objects
for _, performance in ipairs({ false, true }) do
    display.Set("performanceMode", performance)
    for _, font in ipairs({ "default", "diablo", "default", "diablo" }) do
        SelectChoice(dialog.sctFontDropdown, font)
        AssertSctFont(font)
    end
    context:ResetCounts()
    dialog.sctFontDropdown:SetValue("diablo")
    editor.Display()
    context:NoPresentationWrites()
    dialog:Hide()
    context:ResetCounts()
    display.Set("sctFont", "default")
    assert(dialog.sctFontDropdown.dropdownValue == "diablo", "hidden font change performed presentation")
    context:NoPresentationWrites()
    dialog:Show()
    AssertSctFont("default")
    SelectChoice(dialog.sctFontDropdown, "diablo")
    AssertSctFont("diablo")
end
assert(#context.objects == sctObjects, "font selection or reopen allocated another control")
for _, mode in ipairs({ "off", "default", "on" }) do
    SelectChoice(dialog.sctModeDropdown, mode)
    editor.SCT()
    assert(outgoingMode == mode and dialog.sctModeDropdown.dropdownValue == mode)
    assert(dialog.sctStyleDropdown.dropdownEnabled == (mode == "on"))
    assert(dialog.sctFontDropdown.dropdownEnabled == (mode == "on"))
    assert(countToggle.mouse == (mode == "on") and not countToggle.editorChecked)
end
AssertSctStyle("diablo")
SelectChoice(dialog.sctStyleDropdown, "enemy")
AssertSctStyle("enemy")
display.FinishEdit(false)
AssertSctStyle("diablo")
AssertSctFont("default")
assert(
    display.Get("sctShortNumbers")
        and not display.Get("sctDistanceScaling")
        and not display.Get("sctGroupDamage")
        and display.Get("sctShowGroupCount")
        and display.Get("sctGroupWindow") == 0.5
        and display.Get("sctScale") == 0.9
        and not display.Get("performanceMode"),
    "Cancel did not restore default combat choices"
)
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
do
    local controls = {}
    for _, object in ipairs(context.objects) do
        if object:GetParent() == pages.meter and object.input and object.pickerButton then
            controls[object.label:GetText()] = object
        end
    end
    local ability, proc = assert(controls["Ability color"]), assert(controls["Proc color"])
    local initial = display.Snapshot()
    local modes = dialog.displayModes.meterColorMode.dropdown
    assert(display.Get("meterColorMode") == "default" and not ability.available and not proc.available)
    SelectChoice(modes, "custom")
    assert(ability.available and proc.available and ability.input.keyboard, "custom colors did not enable RGB input")
    assert(not ability.pickerAvailable, "missing native picker disabled the hex fallback incorrectly")
    dialog.navigation.Search("Proc color")
    local colorResult, modeResult
    for index, result in ipairs(dialog.navigation.results) do
        if result.target == "meterProcColor" then colorResult = index end
        if result.target == "meterColorMode" then modeResult = index end
    end
    assert(
        #dialog.navigation.results == 2 and colorResult and modeResult,
        "proc-color search must include its control and the matching Bar colors description"
    )
    dialog.navigation.OpenResult(colorResult)
    context:Call(ability.input, "OnEditFocusGained")
    ability.input:SetText("#aB1290")
    assert(display.Get("meterAbilityColor") == "AB1290" and not env.SurvivorsDragonUiDisplay)
    ability.input:SetText("bad")
    assert(display.Get("meterAbilityColor") == "AB1290", "partial RGB text changed the preview")
    context:Call(ability.input, "OnEscapePressed")
    context:Call(ability.input, "OnEditFocusLost")
    assert(display.Get("meterAbilityColor") == initial.meterAbilityColor, "Escape retained an unconfirmed hex edit")

    local picker = env.CreateFrame("Frame", nil, env.UIParent)
    picker:Hide()
    function picker:GetFrameStrata() return self.strata or "DIALOG" end
    local setPickerStrata = picker.SetFrameStrata
    function picker:SetFrameStrata(value)
        setPickerStrata(self, value)
        self.strata = value
    end
    function picker:SetColorRGB(red, green, blue)
        self.rgb = { red, green, blue }
        if self.func then self.func() end
    end
    function picker:GetColorRGB() return unpack(self.rgb) end
    local foreignCalls = 0
    local foreign = function() foreignCalls = foreignCalls + 1 end
    local previous = {}
    picker.func, picker.cancelFunc, picker.opacityFunc = foreign, foreign, foreign
    picker.hasOpacity, picker.opacity, picker.previousValues = true, 0.25, previous
    env.ColorPickerFrame = picker
    editor.Display()
    context:Call(ability.pickerButton, "OnClick")
    assert(picker:IsShown() and display.Get("meterAbilityColor") == initial.meterAbilityColor and foreignCalls == 0)
    assert(picker:GetFrameStrata() == "TOOLTIP" and picker:GetFrameLevel() > ability:GetFrameLevel())
    picker:SetColorRGB(1, 0, 0)
    assert(display.Get("meterAbilityColor") == "FF0000" and display.Get("meterProcColor") == initial.meterProcColor)
    picker.cancelFunc()
    assert(not picker:IsShown() and display.Get("meterAbilityColor") == initial.meterAbilityColor)
    assert(
        picker:GetFrameStrata() == "DIALOG" and picker:GetFrameLevel() == 1,
        "picker retirement lost its native layer"
    )
    assert(
        picker.func == foreign
            and picker.opacityFunc == foreign
            and picker.hasOpacity
            and picker.previousValues == previous
    )

    context:Call(proc.pickerButton, "OnClick")
    picker:SetColorRGB(0, 1, 0)
    local hiddenChange = picker.func
    picker:Hide()
    picker.rgb = { 1, 0, 0 }
    hiddenChange()
    assert(display.Get("meterProcColor") == "00FF00", "a hidden picker callback changed the preview")
    SelectChoice(modes, "default")
    assert(not picker:IsShown() and not proc.available and display.Get("meterProcColor") == "00FF00")
    SelectChoice(modes, "custom")
    assert(proc.available and display.Get("meterProcColor") == "00FF00", "Default lost the retained custom color")
    context:Call(proc.pickerButton, "OnClick")
    local retiredChange = picker.func
    picker.func, picker.cancelFunc = foreign, foreign
    picker.rgb = { 1, 1, 1 }
    retiredChange()
    proc:Hide()
    assert(picker:IsShown() and picker.func == foreign and display.Get("meterProcColor") == "00FF00")
    proc:Show()
    picker:Hide()
    env.ColorPickerFrame = nil
    dialog.navigation.ClearSearch()
    display.Load(initial)
end
do
    local normalized = H.New()
    normalized:Load("core/display.lua", "Display")
    local colors = normalized.env.DFRL.display
    assert(colors.Copy({ meterColorMode = "invalid", meterAbilityColor = false }).meterColorMode == "default")
    assert(colors.Copy({ meterAbilityColor = "#ab12CD" }).meterAbilityColor == "AB12CD")
    assert(colors.Copy({ meterAbilityColor = "FFFFFFFF" }).meterAbilityColor == "CCA147")
    assert(colors.ColorHex(0 / 0, 0, 0) == nil and colors.ColorHex(1, math.huge, 0) == nil)
    assert(colors.ColorHex(1, 0, 0) == "FF0000" and colors.ColorHex(0, 1, 0) == "00FF00")
    colors.BeginEdit()
    colors.Set("meterColorMode", "custom")
    colors.Set("meterAbilityColor", "#123456")
    colors.Set("meterProcColor", "abcdef")
    assert(not normalized.env.SurvivorsDragonUiDisplay)
    colors.FinishEdit(true)
    assert(normalized.env.SurvivorsDragonUiDisplay.meterProcColor == "ABCDEF")
    colors.BeginEdit()
    colors.Load({ meterColorMode = "default", meterAbilityColor = "FF0000" })
    colors.FinishEdit(false)
    assert(colors.Get("meterColorMode") == "custom" and colors.Get("meterAbilityColor") == "123456")
    colors.BeginEdit()
    colors.Load({})
    assert(colors.Get("meterColorMode") == "default", "an older profile enabled custom colors")
    colors.FinishEdit(false)
    assert(colors.Get("meterProcColor") == "ABCDEF", "profile discard lost the custom palette")
    colors.Reset()
    assert(colors.Get("meterColorMode") == "default" and colors.Get("meterAbilityColor") == "CCA147")
end
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
dialog.navigation.Search("combine pet damage")
assert(
    #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "meterGroupPets",
    "pet grouping was absent from settings search"
)
dialog.navigation.OpenResult(1)
local petGrouping = assert(env.displayControls.meterGroupPets, "meter did not prepare its pet grouping checkbox")
assert(not petGrouping.editorChecked and not display.Get("meterGroupPets"), "pet grouping defaulted on")
context:Call(petGrouping, "OnClick")
editor.Display()
assert(petGrouping.editorChecked and display.Get("meterGroupPets"), "pet grouping checkbox did not preview")
assert(not env.SurvivorsDragonUiDisplay, "pet grouping checkbox saved before Confirm")
display.FinishEdit(false)
display.BeginEdit()
editor.Display()
assert(display.Get("meterNameFontSize") == 11 and display.Get("meterFontSize") == 11, "Cancel retained font previews")
assert(not petGrouping.editorChecked and not display.Get("meterGroupPets"), "Cancel kept pet grouping enabled")
for _, key in ipairs({ "meter", "action", "encounters", "map", "interface", "profiles" }) do
    dialog.navigation.Select(key)
    local samples = context.fontSampleRefreshes or 0
    editor.Clock(12.5, 1200, true)
    assert(
        (context.fontSampleRefreshes or 0) == samples + (key == "encounters" and 1 or 0),
        "live timer update ignored the selected category's sample visibility"
    )
end
do
    dialog.navigation.Search("Combine boss bars")
    assert(
        #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "bossCombineBars",
        "combined boss layout was missing from settings search"
    )
    dialog.navigation.OpenResult(1)
    local combinedBosses = assert(env.displayControls.bossCombineBars, "missing combined boss checkbox")
    assert(not combinedBosses.editorChecked and not display.Get("bossCombineBars"), "combined bosses defaulted on")
    context:Call(combinedBosses, "OnClick")
    editor.Display()
    assert(combinedBosses.editorChecked and display.Get("bossCombineBars"), "combined bosses did not preview")
    assert(not env.SurvivorsDragonUiDisplay, "combined bosses saved before Confirm")
    display.Set("customBossBars", false)
    editor.Display()
    assert(
        not combinedBosses.mouse and combinedBosses:GetAlpha() == 0.45 and combinedBosses.editorChecked,
        "native boss bars did not disable and retain the combined choice"
    )
    display.FinishEdit(false)
    display.BeginEdit()
    editor.Display()
    assert(not combinedBosses.editorChecked and display.Get("customBossBars"), "Cancel retained combined boss previews")
    dialog.navigation.Search("")
end
-- Prepare every lazy category before counting; the next walk checks reuse.
for _, key in ipairs(categoryKeys) do
    dialog.navigation.Select(key)
end
local pageCount = 0
for _ in pairs(pages) do
    pageCount = pageCount + 1
end
assert(
    pageCount == 22 and pages.cacheIcons and pages.bossIcons and layoutBuilds == 1,
    "full category walk lost or rebuilt sections"
)
local allCategoryObjects = #context.objects
for _, key in ipairs(categoryKeys) do
    dialog.navigation.Select(key)
    assert(
        dialog.navigation.search == dialogSearch
            and dialogSearch:GetParent() == dialogSearchHeader
            and dialogSearchHeader:IsVisible(),
        "an editor category replaced or hid the shared sidebar search"
    )
end
assert(#context.objects == allCategoryObjects, "revisiting all ten categories allocated another sidebar search")
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
dialog.navigation.Select("map")
local affordableOnly = assert(env.displayControls.worldCacheAffordableOnly, "missing affordability checkbox")
assert(
    env.displayControls.worldBossIcons.editorChecked and display.Get("worldBossIcons"),
    "guardian and boss world icons did not default on in settings"
)
assert(
    dialog.navigation.selected == "map" and pages.cacheIcons:IsVisible() and affordableOnly:IsVisible(),
    "affordability case did not open the visible Map & navigation category"
)
assert(not display.Get("worldCacheAffordableOnly") and affordableOnly.mouse, "wrong affordability default/dependency")
context:Call(affordableOnly, "OnClick")
assert(display.Get("worldCacheAffordableOnly"), "affordability checkbox did not preview")
display.Set("worldCacheIcons", false)
editor.Display()
assert(
    affordableOnly:IsVisible()
        and not affordableOnly.mouse
        and affordableOnly.editorAvailable == false
        and affordableOnly.editorChecked
        and affordableOnly:GetAlpha() == 0.45,
    "cache-off did not disable/retain affordability"
)
display.Set("worldCacheIcons", true)
editor.Display()
assert(
    affordableOnly:IsVisible()
        and affordableOnly.mouse
        and affordableOnly.editorAvailable == true
        and affordableOnly.editorChecked
        and affordableOnly:GetAlpha() == 1,
    "cache-on lost affordability input/choice"
)
dialog.navigation.Search("Only show affordable caches")
assert(
    #dialog.navigation.results == 1 and dialog.navigation.results[1].target == "worldCacheAffordableOnly",
    "affordability filter missing from search"
)
dialog.navigation.OpenResult(1)
assert(
    dialog.navigation.selected == "map" and affordableOnly:IsVisible(),
    "affordability search opened a hidden section"
)
dialog.navigation.ClearSearch()
display.Set("worldCacheAffordableOnly", false)
local cacheModes = assert(dialog.displayModes.worldCacheIconMode, "missing cache visibility modes")
local bossModes = assert(dialog.displayModes.worldBossIconMode, "missing encounter visibility modes")
local cacheRange, bossRange
for _, group in ipairs(dialog.worldIconRanges) do
    if group.master == "worldCacheIcons" then
        cacheRange = group
    else
        bossRange = group
    end
end
assert(cacheRange and bossRange and not cacheRange.enabled and not bossRange.enabled)
SelectChoice(cacheModes.dropdown, "near")
editor.Display()
assert(display.Get("worldCacheIconMode") == "near" and cacheRange.enabled, "Nearby did not enable its cutoff")
context:Call(cacheRange.controls[2], "OnClick")
assert(display.Get("worldCacheIconDistance") == 45, "cutoff did not preview in five-yard steps")
display.Set("worldCacheIcons", false)
editor.Display()
assert(not cacheModes.dropdown.mouse and not cacheRange.enabled, "cache-off retained distance input")
SelectChoice(cacheModes.dropdown, "far")
context:Call(cacheRange.controls[2], "OnClick")
assert(display.Get("worldCacheIconMode") == "near" and display.Get("worldCacheIconDistance") == 45)
display.Set("worldCacheIcons", true)
display.Set("worldBossIcons", true)
editor.Display()
SelectChoice(bossModes.dropdown, "far")
editor.Display()
assert(cacheRange.enabled and bossRange.enabled and display.Get("worldBossIconMode") == "far")
dialog.navigation.Search("Nearby only")
assert(#dialog.navigation.results == 2, "distance modes were missing from settings search")
dialog.navigation.OpenResult(1)
assert(dialog.navigation.selected == "map", "distance search did not open Map & navigation")
dialog.navigation.ClearSearch()
display.Set("worldCacheIconMode", "always")
display.Set("worldBossIconMode", "always")
display.Set("worldCacheIconDistance", 40)
display.Set("worldBossIcons", false)
editor.Display()
assert(not cacheRange.enabled and not bossRange.enabled, "Always retained an unnecessary cutoff control")
dialog.navigation.Select("action")
local xpText = assert(env.displayControls.xpShowText, "Action bar did not prepare Show XP text")
assert(not xpText.editorChecked, "XP text was enabled by default")
context:Call(xpText, "OnClick")
editor.Display()
assert(display.Get("xpShowText") and xpText.editorChecked, "XP text checkbox did not preview")
assert(not env.SurvivorsDragonUiDisplay.xpShowText, "XP text checkbox saved before Confirm")
env.DFRL.layout.CancelEdit()
assert(not display.Get("xpShowText"), "Cancel retained the XP text checkbox")
display.BeginEdit()
dialog:Show()
dialog.navigation.Select("action")
local customActionBar = assert(env.displayControls.customActionBar, "Action bar did not prepare the SDUI toggle")
assert(customActionBar.editorChecked, "new setups did not select the SDUI action bar")
context:Call(customActionBar, "OnClick")
editor.Display()
assert(not display.Get("customActionBar") and env.SurvivorsDragonUiDisplay.customActionBar ~= false)
for _, key in ipairs({
    "lockActionButtons",
    "cooldownNumbers",
    "showGryphons",
    "attachXP",
    "xpShowText",
    "attachTally",
}) do
    local control = assert(env.displayControls[key], "missing native-bar dependent control: " .. key)
    assert(control:GetAlpha() == 0.45 and not control.mouse, "native bar left a custom-bar option interactive: " .. key)
end
dialog.navigation.Select("jewelry")
editor.Display()
local attachJewelry = assert(env.displayControls.attachJewelry, "Jewelry did not prepare its attachment control")
assert(attachJewelry:GetAlpha() == 0.45 and not attachJewelry.mouse, "native bar left jewelry attachment interactive")
assert(env.displayControls.hideNativeBuild:GetParent() == pages.jewelry, "native build control stayed on Action bar")
local customJewelry = assert(env.displayControls.jewelryCustomOrder)
local jewelryChoices = assert(dialog.jewelryOrderSettings)
assert(not customJewelry.editorChecked and not jewelryChoices.enabled and #jewelryChoices.controls == 5)
assert(not dialog.editorDropdownMenu:IsShown(), "Jewelry retained a dropdown from another page")
context:Call(customJewelry, "OnClick")
editor.Display()
assert(jewelryChoices.enabled, "custom order incorrectly depends on the SDUI action bar")
SelectChoice(jewelryChoices.rows[1].button, "4")
local jewelryMenu = assert(dialog.editorDropdownMenu)
editor.Display()
assert(display.Get("jewelryOrder") == "42315", "position choice did not swap equipped slots")
assert(jewelryChoices.rows[1].value == "4" and jewelryChoices.rows[4].value == "1")
assert(jewelryChoices.rows[1].button.label:GetText() == locale.Text("Trinket 1"))
local jewelryObjects = #context.objects
context:Call(jewelryChoices.rows[5].button, "OnClick")
assert(dialog.editorDropdownMenu == jewelryMenu and #context.objects == jewelryObjects)
context:Call(jewelryMenu, "OnClick")
assert(not jewelryMenu:IsShown() and not jewelryMenu.owner, "outside click retained the dropdown")
context:Call(jewelryChoices.rows[2].button, "OnClick")
dialog.navigation.Select("action")
assert(not jewelryMenu:IsShown(), "leaving Jewelry retained its dropdown")
dialog.navigation.Select("jewelry")
editor.Display()
context:Call(jewelryChoices.rows[3].button, "OnClick")
context:Call(customJewelry, "OnClick")
editor.Display()
assert(not jewelryMenu:IsShown() and not jewelryChoices.enabled, "disabling custom order retained its dropdown")
context:Call(customJewelry, "OnClick")
editor.Display()
context:Call(jewelryChoices.rows[2].button, "OnClick")
assert(not env.SurvivorsDragonUiDisplay.jewelryCustomOrder, "custom jewelry order saved before Confirm")
assert(display.Get("attachJewelry") and display.Get("attachTally"), "native preview rewrote attachment preferences")
env.DFRL.layout.CancelEdit()
assert(not jewelryMenu:IsShown() and not jewelryMenu.owner, "Cancel retained the jewelry dropdown")
assert(display.Get("customActionBar") and display.Get("attachJewelry") and display.Get("attachTally"))
assert(
    not display.Get("jewelryCustomOrder") and display.Get("jewelryOrder") == "12345",
    "Cancel retained jewelry order"
)
display.BeginEdit()
dialog:Show()
dialog.navigation.Select("action")
editor.Display()
assert(customActionBar.editorChecked, "Cancel did not restore the action-bar toggle")
env.DFRL.layout.CancelEdit()
do
    display.BeginEdit()
    dialog:Show()
    dialog.navigation.Select("action")
    local style = assert(dialog.tallyStyleDropdown)
    for _, entry in ipairs(env.DFRL.tallyStyles) do
        SelectChoice(style, entry.id)
        assert(display.Get("tallyStyle") == entry.id and style.dropdownValue == entry.id)
    end
    local pooled = dialog.editorDropdownMenu
    local firstChoice = pooled.buttons[1]
    dialog.navigation.Select("encounters")
    SelectChoice(dialog.timerOutlineDropdown, "THICKOUTLINE")
    assert(env.fontDraft.outline == "THICKOUTLINE" and dialog.timerOutlineDropdown.dropdownValue == "THICKOUTLINE")
    dialog.navigation.Select("interface")
    local loot = dialog.displayModes.lootMode.dropdown
    for _, mode in ipairs({ "game", "off", "sdui" }) do
        SelectChoice(loot, mode)
        editor.Display()
        assert(display.Get("lootMode") == mode and loot.dropdownEnabled, "loot dropdown disabled its own mode selector")
    end
    assert(
        dialog.editorDropdownMenu == pooled
            and pooled.buttons[1] == firstChoice
            and #pooled.buttons == #env.DFRL.tallyStyles,
        "dropdown lists grew beyond the largest prepared choice list"
    )
    env.DFRL.layout.CancelEdit()
end
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
