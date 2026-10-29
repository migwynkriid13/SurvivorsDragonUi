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
    if kind == "FontString" then
        function result:GetStringWidth() return self.naturalWidth or 100 end
        local setPoint = result.SetPoint
        function result:SetPoint(...)
            setPoint(self, ...)
            self.point = { ... }
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
local groups = { { key = "layout", label = "Layout" }, { key = "combat", label = "Combat" } }
local sections = {
    { key = "layout", label = "Layout", group = "layout" },
    { key = "text", label = "Combat text", group = "combat", options = { { "icons", "Damage icons", "Spell icons" } } },
    { key = "meter", label = "Damage meter", group = "combat" },
}
local closes = 0
local navigation = env.T.CreateEditorNavigator(panel, sidebar, groups, sections, {
    width = 684,
    left = 240,
    top = 80,
    height = 552,
    sidebarWidth = 212,
    onNavigate = function() closes = closes + 1 end,
})
local page = navigation.pages.layout
page.pending = "-12,5"
navigation.pages.text:SetHeight(600)
navigation.Select("layout")
assert(sections[1].shell:IsShown() and not sections[2].shell:IsShown())
local allocated = #context.objects
context:ResetCounts()
navigation.Refresh()
context:NoPresentationWrites()
assert(#context.objects == allocated, "unchanged navigation allocated views")

navigation.Select("combat")
assert(not sections[1].shell:IsShown() and sections[2].shell:IsShown() and sections[3].shell:IsShown())
local slider = env.SurvivorsDragonUiSettingsScrollScrollBar
slider:SetValue(180)
navigation.Select("layout")
navigation.Select("combat")
assert(slider:GetValue() == 180, "category scroll position was lost")
assert(navigation.pages.layout == page and page.pending == "-12,5", "navigation replaced pending input")

assert(not sections[1].heading and sections[1].headingHeight == 0, "Layout repeated its sidebar caption")
assert(sections[2].heading and sections[3].heading, "distinct subsection headings were removed")
assert(not navigation.search and not navigation.query, "the removed search retained runtime state")
assert(navigation.pages.text:GetParent() == sections[2].shell, "navigation moved the real controls")
slider:SetValue(235)
navigation.Refresh(true)
assert(slider:GetValue() == 235, "a geometry refresh lost the current scroll position")

panel:Hide()
context:ResetCounts()
navigation.Refresh()
context:NotifyLocale()
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
    "PASS editor grouping, compact spacing, scroll memory, retail button input/selection/disabled states, hidden idle and reuse"
)
