--[[
SDUI artwork uses cropped texture pixels from source commit
623eca5893c9d475a7b77bd25808bdbe801d247c.
Source provenance and pixel coordinates: third_party/SDUI-ARTWORK.md.
Plain settings chrome reuses character/Chrome.blp (Character-ARTWORK.md).
Retail Edit Mode art: Gethe/wow-ui-textures commit
 e80e3278cc833c89e1f3fc79557b68315d750935, Dragonflight 10.0.0.45454.
No source-addon framework, retail atlas API or Edit Mode C API is loaded.
The underlying World of Warcraft artwork is Copyright Blizzard Entertainment,
Inc.; it is not licensed under the MIT notices below.
These helpers use texture pixels directly, without the source addons or atlas APIs.

MIT License

Copyright (c) 2026 NeticSoul and DragonUI contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

MIT License

Copyright (c) 2022 Karl-HeinzSchneider

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

setfenv(1, DFRL:GetEnv())

local path = DFRL:GetInfoOrCons("tex") .. "editor\\"

local function Artwork(parent, file, layer, left, right, top, bottom)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture(path .. file .. ".blp")
    texture:SetTexCoord(left or 0, right or 1, top or 0, bottom or 1)
    return texture
end

local function Fill(parent, red, green, blue, alpha)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(red, green, blue, alpha)
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6)
    texture:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 6)
    return texture
end

local function Border(parent, side)
    local pieces = {}
    for index = 1, 8 do
        local piece = Artwork(parent, "border", "BORDER", (index - 1) / 8, index / 8, 0, 1)
        piece:SetWidth(side)
        piece:SetHeight(side)
        pieces[index] = piece
    end
    local topLeft, topRight, bottomLeft, bottomRight = pieces[1], pieces[2], pieces[3], pieces[4]
    topLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    topRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bottomLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottomRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    pieces[5]:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
    pieces[5]:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT", 0, 0)
    pieces[6]:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT", 0, 0)
    pieces[6]:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT", 0, 0)
    pieces[7]:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
    pieces[7]:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMLEFT", 0, 0)
    pieces[8]:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT", 0, 0)
    pieces[8]:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", 0, 0)
    return pieces
end

local function Label(parent, size, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    DFRL.locale.Bind(label)
    T.SetFont(label, size, "")
    label:SetTextColor(0.88, 0.87, 0.83)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    label:SetText(text or "")
    return label
end

local function Hover(button, inset, alpha)
    local hover = Artwork(button, "choice", "ARTWORK", 0, 187 / 256, 32 / 64, 53 / 64)
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    hover:SetAlpha(alpha)
    hover:Hide()
    button:SetScript("OnEnter", function()
        if not hover:IsShown() then hover:Show() end
    end)
    local function Hide()
        if hover:IsShown() then hover:Hide() end
    end
    button:SetScript("OnLeave", Hide)
    button:SetScript("OnHide", Hide)
end

-- The same Blizzard plain-metal pieces already used by the character window.
-- ButtonFrameTemplateNoPortrait is Dragonflight's actual SettingsFrame border.
function DFRL.tools.CreateEditorPanel(parent, width, height, name)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    frame.editorFill = Fill(frame, 0.065, 0.068, 0.075, 0.98)
    frame.editorFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -18)
    frame.editorFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    local pieces = {}
    local regions = {
        { 0, 0, 150, 150, 75, 75 },
        { 256, 0, 406, 150, 75, 75 },
        { 512, 0, 576, 64, 32, 32 },
        { 640, 0, 704, 64, 32, 32 },
        { 0, 192, 150, 224, 75 },
        { 256, 192, 406, 224, 75 },
        { 768, 0, 832, 150, nil, 75 },
        { 896, 0, 928, 64, nil, 32 },
    }
    for index, region in ipairs(regions) do
        local piece = frame:CreateTexture(nil, "BORDER")
        piece:SetTexture(DFRL:GetInfoOrCons("tex") .. "character\\Chrome.blp")
        piece:SetTexCoord(region[1] / 1024, region[3] / 1024, region[2] / 256, region[4] / 256)
        if region[5] then piece:SetWidth(region[5]) end
        if region[6] then piece:SetHeight(region[6]) end
        pieces[index] = piece
    end
    local tl, tr, bl, br = pieces[1], pieces[2], pieces[3], pieces[4]
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 16)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 16)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -8, -3)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -3)
    pieces[5]:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
    pieces[5]:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
    pieces[6]:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
    pieces[6]:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
    pieces[7]:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
    pieces[7]:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
    pieces[8]:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
    pieces[8]:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    frame.editorBorder = pieces
    return frame
end

-- Exact blue/highlight and gold/selected retail Edit Mode nine-slice pixels.
-- Source/crops: scripts/prepare_editor_art.py and third_party/SDUI-ARTWORK.md.
function DFRL.tools.CreateEditModeSelection(parent)
    local pieces = {}
    for index = 1, 9 do
        local piece = Artwork(parent, "selection", index == 9 and "BACKGROUND" or "BORDER")
        if index <= 8 then
            piece:SetWidth(16)
            piece:SetHeight(16)
        end
        pieces[index] = piece
    end
    local tl, tr, bl, br = pieces[1], pieces[2], pieces[3], pieces[4]
    tl:SetPoint("TOPLEFT", parent, "TOPLEFT", -8, 8)
    tr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 8, 8)
    bl:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -8, -8)
    br:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 8, -8)
    pieces[5]:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
    pieces[5]:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
    pieces[6]:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
    pieces[6]:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    pieces[7]:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
    pieces[7]:SetPoint("BOTTOMRIGHT", bl, "TOPLEFT", 0, 0)
    pieces[8]:SetPoint("TOPLEFT", tr, "BOTTOMLEFT", 0, 0)
    pieces[8]:SetPoint("BOTTOMRIGHT", br, "TOPLEFT", 0, 0)
    pieces[9]:SetAllPoints(parent)
    local selected
    return function(value)
        value = value and true or false
        if selected == value then return end
        selected = value
        local top = value and 32 or 0
        for index, piece in ipairs(pieces) do
            piece:SetTexCoord((index - 1) * 16 / 256, index * 16 / 256, top / 64, (top + 16) / 64)
        end
    end
end

function DFRL.tools.CreateEditorButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    local left = Artwork(button, "button", "BACKGROUND")
    local middle = Artwork(button, "button", "BACKGROUND")
    local right = Artwork(button, "button", "BACKGROUND")
    left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    button.editorPieces = { left, middle, right }
    button:SetHighlightTexture(path .. "button.blp", "ADD")
    local highlight = button:GetHighlightTexture()
    highlight:SetTexCoord(0, 441 / 512, 384 / 512, 1)
    highlight:ClearAllPoints()
    highlight:SetAllPoints(button)
    highlight:SetDrawLayer("ARTWORK")
    button.label = Label(button, 12, text)
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.label:SetWidth(math.max(1, width - 12))
    button.label:SetHeight(16)
    button.label:SetJustifyH("CENTER")
    local hovered, down = false, false
    local lastState, lastFraction, lastWidth, lastHeight, locked
    local lastLabel, lastColor, lastPressed
    local function Refresh(force)
        if not force and not button:IsVisible() then return end
        -- Native clients can report 1/0 rather than true/false.
        local enabled = button:IsEnabled()
        enabled = enabled ~= nil and enabled ~= false and enabled ~= 0
        local state = not enabled and 2 or (down or button.editorSelected) and 1 or 0
        local w, h = button:GetWidth(), button:GetHeight()
        if not w or not h or w <= 0 or h <= 0 then return end
        local cap = math.min(h * 114 / 128, w * 0.4)
        local fraction = cap / (h * 114 / 128)
        if lastWidth ~= w or lastHeight ~= h then
            left:SetWidth(cap)
            right:SetWidth(cap)
            left:SetHeight(h)
            right:SetHeight(h)
            lastWidth, lastHeight = w, h
        end
        if lastState ~= state or lastFraction ~= fraction then
            local top, bottom = state * 128 / 512, (state + 1) * 128 / 512
            -- Narrow +/- and paging buttons crop the inner ends of their caps.
            -- The actual outside corners keep their original height/proportions.
            left:SetTexCoord(0, 114 * fraction / 512, top, bottom)
            middle:SetTexCoord(128 / 512, 192 / 512, top, bottom)
            right:SetTexCoord((322 - 114 * fraction) / 512, 322 / 512, top, bottom)
            lastState, lastFraction = state, fraction
        end
        local selected = enabled and button.editorSelected == true
        if locked ~= selected then
            if selected then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
            locked = selected
        end
        local label = button.label
        local color = not enabled and 3 or (hovered or selected) and 2 or 1
        if lastLabel ~= label or lastColor ~= color then
            if color == 3 then
                label:SetTextColor(0.5, 0.5, 0.5)
            elseif color == 2 then
                label:SetTextColor(1, 1, 1)
            else
                label:SetTextColor(1, 0.82, 0)
            end
            lastColor = color
        end
        local pressed = enabled and down
        if lastLabel ~= label or lastPressed ~= pressed then
            label:ClearAllPoints()
            label:SetPoint("CENTER", button, "CENTER", pressed and 1 or 0, pressed and -1 or 0)
            lastPressed = pressed
        end
        lastLabel = label
    end
    function button:SetSelected(value)
        self.editorSelected = value and true or false
        Refresh()
    end
    local enable, disable, setWidth, setHeight = button.Enable, button.Disable, button.SetWidth, button.SetHeight
    function button:Enable()
        enable(self)
        Refresh()
    end
    function button:Disable()
        disable(self)
        hovered, down = false, false
        Refresh()
    end
    function button:SetWidth(value)
        setWidth(self, value)
        Refresh()
    end
    function button:SetHeight(value)
        setHeight(self, value)
        Refresh()
    end
    button:SetScript("OnEnter", function()
        hovered = true
        Refresh()
    end)
    button:SetScript("OnLeave", function()
        hovered, down = false, false
        Refresh()
    end)
    button:SetScript("OnMouseDown", function()
        if arg1 ~= "LeftButton" then return end
        down = true
        Refresh()
    end)
    button:SetScript("OnMouseUp", function()
        down = false
        Refresh()
    end)
    button:SetScript("OnHide", function()
        hovered, down = false, false
        if locked then button:UnlockHighlight() end
        locked = false
    end)
    button:SetScript("OnShow", function() Refresh() end)
    Refresh(true)
    return button
end

function DFRL.tools.CreateEditorInput(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetWidth(width)
    box:SetHeight(height)
    T.SetFont(box, 12, "")
    box:SetAutoFocus(false)
    box:SetMaxLetters(16)
    box:SetTextInsets(8, 8, 0, 0)
    box.editorFill = Fill(box, 0.055, 0.06, 0.065, 0.93)
    box.editorBorder = Border(box, 12)
    return box
end

function DFRL.tools.CreateEditorCategory(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    local selected = Artwork(button, "choice", "ARTWORK", 0, 187 / 256, 0, 21 / 64)
    selected:SetAllPoints(button)
    selected:SetAlpha(0.55)
    selected:Hide()
    Hover(button, 0, 0.35)
    button.label = Label(button, 12, text)
    button.label:SetPoint("LEFT", button, "LEFT", 16, 0)
    button.label:SetWidth(math.max(1, width - 28))
    button.label:SetJustifyH("LEFT")
    function button:SetSelected(value)
        value = value and true or false
        if self.editorSelected == value then return end
        self.editorSelected = value
        if value then
            selected:Show()
        else
            selected:Hide()
        end
        self.label:SetTextColor(value and 1 or 0.88, value and 0.83 or 0.87, value and 0.38 or 0.83)
    end
    button:SetSelected(false)
    return button
end

function DFRL.tools.EditorDivider(parent, width)
    local divider = Artwork(parent, "divider", "ARTWORK", 0, 630 / 1024, 0, 1)
    divider:SetWidth(width)
    divider:SetHeight(1)
    divider:SetAlpha(0.5)
    return divider
end

function DFRL.tools.CreateEditorToggle(parent, text, description, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(44)
    local checkbox = Artwork(button, "checkbox", "ARTWORK", 0, 30 / 64, 0, 29 / 32)
    checkbox:SetWidth(22)
    checkbox:SetHeight(22 * 29 / 30)
    checkbox:SetPoint("LEFT", button, "LEFT", 2, 0)
    button.editorCheckbox = checkbox
    local mark = Artwork(button, "checkbox", "OVERLAY", 32 / 64, 62 / 64, 0, 29 / 32)
    mark:SetAllPoints(checkbox)
    mark:Hide()
    Hover(button, 2, 0.22)
    button.label = Label(button, 12, text)
    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", 32, description and -7 or -14)
    button.label:SetWidth(math.max(1, width - 36))
    button.label:SetHeight(16)
    button.label:SetJustifyH("LEFT")
    if description then
        button.description = Label(button, 10, description)
        button.description:SetTextColor(0.59, 0.59, 0.56)
        button.description:SetPoint("TOPLEFT", button, "TOPLEFT", 32, -24)
        button.description:SetWidth(math.max(1, width - 36))
        button.description:SetHeight(14)
        button.description:SetJustifyH("LEFT")
    end
    local divider = DFRL.tools.EditorDivider(button, math.max(1, width - 32))
    divider:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    divider:SetAlpha(0.2)
    function button:SetChecked(value)
        self.editorChecked = value and true or false
        if self.editorChecked then
            mark:Show()
            self.label:SetTextColor(1, 0.87, 0.55)
        else
            mark:Hide()
            self.label:SetTextColor(0.88, 0.87, 0.83)
        end
    end
    button:SetChecked(false)
    button:SetScript("OnClick", function()
        button:SetChecked(not button.editorChecked)
        if callback then callback(button.editorChecked, button) end
    end)
    return button
end

-- Related settings share one scroll surface and keep their original owners.
function DFRL.tools.CreateEditorNavigator(parent, sidebar, groups, sections, options)
    local navigation = { pages = {}, buttons = {}, offsets = {}, selected = groups[1].key }
    local width = options.width
    local scroll = CreateFrame("ScrollFrame", "SurvivorsDragonUiSettingsScroll", parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", options.left, -options.top)
    scroll:SetWidth(width)
    scroll:SetHeight(options.height)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(width - 24)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    local slider = _G[scroll:GetName() .. "ScrollBar"]
    local rendered
    local function Scroll(direction)
        if not slider then return end
        local low, high = slider:GetMinMaxValues()
        local value = slider:GetValue() - (direction or arg1 or 0) * 56
        slider:SetValue(math.max(low, math.min(high, value)))
    end
    navigation.Scroll = Scroll
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", Scroll)

    local groupLabels = {}
    for index, group in ipairs(groups) do
        groupLabels[group.key] = group.label
        local key = group.key
        local button = DFRL.tools.CreateEditorCategory(sidebar, group.label, options.sidebarWidth, 42)
        button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, -48 - (index - 1) * 48)
        button.label:SetHeight(32)
        button.label:SetJustifyV("MIDDLE")
        button:SetScript("OnClick", function() navigation.Select(key) end)
        navigation.buttons[key] = button
    end
    for _, section in ipairs(sections) do
        local shell = CreateFrame("Frame", nil, content)
        shell:SetWidth(width - 24)
        shell:Hide()
        -- The selected sidebar button already names the category. Keep only
        -- headings that distinguish an actual subsection within that category.
        local headingHeight = section.label ~= groupLabels[section.group] and 34 or 0
        if headingHeight > 0 then
            local heading = Label(shell, 13, section.label)
            heading:SetTextColor(0.94, 0.79, 0.47)
            heading:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, -4)
            heading:SetWidth(width - 24)
            heading:SetHeight(20)
            heading:SetJustifyH("LEFT")
            local divider = DFRL.tools.EditorDivider(shell, width - 24)
            divider:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, -27)
            section.heading = heading
        end
        local page = CreateFrame("Frame", nil, shell)
        page:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, -headingHeight)
        page:SetWidth(width - 24)
        page:SetHeight(396)
        page:EnableMouseWheel(true)
        page:SetScript("OnMouseWheel", Scroll)
        section.shell, section.headingHeight = shell, headingHeight
        navigation.pages[section.key] = page
    end
    function navigation.Refresh(force)
        if not parent:IsShown() then
            rendered = nil
            return
        end
        if rendered == navigation.selected and not force then return end
        if rendered == navigation.selected and slider then
            navigation.offsets[navigation.selected] = slider:GetValue()
        end
        local y = 0
        for _, section in ipairs(sections) do
            local shell, page = section.shell, navigation.pages[section.key]
            if section.group == navigation.selected then
                local height = page:GetHeight() + section.headingHeight + 12
                if section.y ~= y then
                    shell:ClearAllPoints()
                    shell:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                    section.y = y
                end
                if shell:GetHeight() ~= height then shell:SetHeight(height) end
                if not shell:IsShown() then shell:Show() end
                y = y + height
            elseif shell:IsShown() then
                shell:Hide()
            end
        end
        local height = math.max(scroll:GetHeight(), y)
        if content:GetHeight() ~= height then content:SetHeight(height) end
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        for key, button in pairs(navigation.buttons) do
            local selected = key == navigation.selected
            if button.editorSelected ~= selected then button:SetSelected(selected) end
        end
        if slider then
            local low, high = slider:GetMinMaxValues()
            slider:SetValue(math.max(low, math.min(high, navigation.offsets[navigation.selected] or 0)))
        end
        rendered = navigation.selected
    end
    local function RememberOffset()
        if slider then navigation.offsets[navigation.selected] = slider:GetValue() end
    end
    function navigation.Select(key)
        if not navigation.buttons[key] then return end
        RememberOffset()
        navigation.selected = key
        if options.onNavigate then options.onNavigate(key) end
        navigation.Refresh()
    end
    HookScript(scroll, "OnHide", function()
        RememberOffset()
        rendered = nil
    end)
    return navigation
end

-- Measure the active caption so one-line titles do not reserve a blank second
-- line. Longer translations retain a second line and the same three-unit gap.
function DFRL.tools.CompactEditorToggle(button)
    local label, description = button.label, button.description
    local natural = label:GetStringWidth()
    local labelHeight = natural and natural > 0 and natural <= label:GetWidth() and 16 or 28
    local descriptionTop = 7 + labelHeight + 3
    local height = descriptionTop + 32 + 6
    if not natural or natural <= 0 then button.editorCompactHeight = nil end
    if button.editorCompactHeight == height and button:GetHeight() == height then return height end
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", button, "TOPLEFT", 32, -7)
    label:SetHeight(labelHeight)
    label:SetJustifyV("TOP")
    description:ClearAllPoints()
    description:SetPoint("TOPLEFT", button, "TOPLEFT", 32, -descriptionTop)
    description:SetHeight(32)
    description:SetJustifyV("TOP")
    button.editorCheckbox:ClearAllPoints()
    button.editorCheckbox:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -8)
    button:SetHeight(height)
    button.editorCompactHeight = natural and natural > 0 and height or nil
    return height
end
