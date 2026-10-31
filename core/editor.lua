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
    -- Plain recessed fields match the metal panel without a decorative frame.
    -- Thin native-color edges avoid another full-surface alpha layer.
    box.editorFill = Fill(box, 0.025, 0.028, 0.032, 0.98)
    box.editorFill:ClearAllPoints()
    box.editorFill:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    box.editorFill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    box.editorBorder = {}
    for index, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = box:CreateTexture(nil, "BORDER")
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetPoint(side .. "LEFT", box, side .. "LEFT", 0, 0)
            edge:SetPoint(side .. "RIGHT", box, side .. "RIGHT", 0, 0)
            edge:SetHeight(1)
        else
            edge:SetPoint("TOP" .. side, box, "TOP" .. side, 0, -1)
            edge:SetPoint("BOTTOM" .. side, box, "BOTTOM" .. side, 0, 1)
            edge:SetWidth(1)
        end
        if side == "TOP" then
            edge:SetVertexColor(0.17, 0.19, 0.22, 1)
        elseif side == "BOTTOM" then
            edge:SetVertexColor(0.42, 0.44, 0.46, 0.85)
        else
            edge:SetVertexColor(0.24, 0.27, 0.3, 0.95)
        end
        box.editorBorder[index] = edge
    end
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
    if description then
        button.label:SetPoint("TOPLEFT", button, "TOPLEFT", 32, -7)
    else
        button.label:SetPoint("LEFT", button, "LEFT", 32, 0)
        button.label:SetJustifyV("MIDDLE")
    end
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
    button.editorDivider = divider
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

-- Literal settings search needs the same case folding on both localized
-- metadata and input. Decode only for supported Latin/Cyrillic case pairs;
-- retain every other UTF-8 byte unchanged, including CJK captions.
local function FoldEditorSearch(text)
    local result, index = {}, 1
    while index <= string.len(text) do
        local first = string.byte(text, index)
        local length, code = 1, first
        local second, third = string.byte(text, index + 1), string.byte(text, index + 2)
        if first >= 194 and first <= 223 and second and second >= 128 and second <= 191 then
            length, code = 2, (first - 192) * 64 + second - 128
        elseif
            first >= 224
            and first <= 239
            and second
            and third
            and second >= 128
            and second <= 191
            and third >= 128
            and third <= 191
        then
            length, code = 3, (first - 224) * 4096 + (second - 128) * 64 + third - 128
        end
        local lower = code
        if code >= 65 and code <= 90 then
            lower = code + 32
        elseif (code >= 192 and code <= 214) or (code >= 216 and code <= 222) then
            lower = code + 32
        elseif code == 304 or code == 305 then
            lower = 105
        elseif code == 376 then
            lower = 255
        elseif (code >= 256 and code <= 303) or (code >= 306 and code <= 311) or (code >= 330 and code <= 375) then
            if math.mod(code, 2) == 0 then lower = code + 1 end
        elseif (code >= 313 and code <= 328) or (code >= 377 and code <= 382) then
            if math.mod(code, 2) == 1 then lower = code + 1 end
        elseif code == 536 or code == 538 or code == 1168 then
            lower = code + 1
        elseif code >= 1040 and code <= 1071 then
            lower = code + 32
        elseif code >= 1024 and code <= 1039 then
            lower = code + 80
        end
        local folded
        if code == 223 or code == 7838 then
            folded = "ss"
        elseif lower == code then
            folded = string.sub(text, index, index + length - 1)
        elseif lower < 128 then
            folded = string.char(lower)
        elseif lower < 2048 then
            folded = string.char(192 + math.floor(lower / 64), 128 + math.mod(lower, 64))
        else
            folded = string.char(
                224 + math.floor(lower / 4096),
                128 + math.mod(math.floor(lower / 64), 64),
                128 + math.mod(lower, 64)
            )
        end
        table.insert(result, folded)
        index = index + length
    end
    return table.concat(result)
end

-- Search only redirects to the original controls. Metadata is available before
-- unvisited pages exist; a small result pool reuses the navigator's viewport.
local function CreateEditorSearch(parent, sidebar, scroll, content, navigation, groups, sections, options)
    local owner = { active = false, query = "", page = 1, rows = {}, results = {} }
    local width = options.sidebarWidth
    local resultWidth, resultHeight, resultPitch = math.min(options.width - 24, 360), 42, 46
    local resultFooter = 8 * resultPitch + 8
    local header = CreateFrame("Frame", nil, sidebar)
    header:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, -4)
    header:SetWidth(width)
    header:SetHeight(88)
    local caption = Label(header, 12, "Search settings")
    caption:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -2)
    caption:SetWidth(width)
    caption:SetHeight(18)
    caption:SetJustifyH("LEFT")
    owner.input = T.CreateEditorInput(header, width, 28)
    owner.input:SetMaxLetters(128)
    owner.input:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -24)
    owner.clear = T.CreateEditorButton(header, "Clear search", 112, 28)
    owner.clear:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -60)
    owner.clear:Disable()
    navigation.search = owner.input
    navigation.results, navigation.query = owner.results, ""

    local byGroup, bySection = {}, {}
    for _, group in ipairs(groups) do
        byGroup[group.key] = group
    end
    for _, section in ipairs(sections) do
        bySection[section.key] = section
    end

    local function SyncInput()
        if not parent:IsShown() then return end
        owner.changing = true
        if owner.input:GetText() ~= owner.query then owner.input:SetText(owner.query) end
        owner.changing = nil
        local enabled = owner.query ~= ""
        if owner.clearEnabled ~= enabled then
            owner.clearEnabled = enabled
            if enabled then
                owner.clear:Enable()
            else
                owner.clear:Disable()
            end
        end
    end
    local function RefreshHeader()
        if not parent:IsShown() then return end
        local face, size, flags = owner.clear.label:GetFont()
        local scale = parent:GetEffectiveScale()
        local previous = owner.headerMetrics
        if
            previous
            and previous.code == DFRL.locale.code
            and previous.face == face
            and previous.size == size
            and previous.flags == flags
            and previous.scale == scale
        then
            return
        end
        local measured = owner.clear.label:GetStringWidth()
        if not measured or measured <= 0 then return end
        local clearWidth = math.min(width, math.max(112, math.ceil(measured) + 24))
        if owner.clear:GetWidth() ~= clearWidth then
            owner.clear:SetWidth(clearWidth)
            owner.clear.label:SetWidth(clearWidth - 12)
        end
        owner.headerMetrics = { code = DFRL.locale.code, face = face, size = size, flags = flags, scale = scale }
    end
    owner.RefreshHeader = RefreshHeader
    local function Index()
        if owner.index and owner.language == DFRL.locale.code then return owner.index end
        local index, identities = {}, {}
        local function Add(entry, section, target)
            local groupKey = entry.group or (section and section.group)
            local group = byGroup[groupKey]
            local label = entry.label or (section and section.label)
            if not label then return end
            local identity = (section and section.key or groupKey or "")
                .. ":"
                .. (target or entry.target or entry.key or label)
            local record = identities[identity]
            if not record then
                record = {
                    label = label,
                    section = section and section.key,
                    sectionInfo = section,
                    group = groupKey,
                    entry = entry,
                    target = target or entry.target or entry.key,
                }
                identities[identity] = record
                table.insert(index, record)
            end
            local sources =
                { label, entry.description or "", section and section.label or "", group and group.label or "" }
            for _, term in ipairs(entry.terms or {}) do
                table.insert(sources, term)
            end
            for _, term in ipairs(section and section.terms or {}) do
                table.insert(sources, term)
            end
            local text = {}
            for _, source in ipairs(sources) do
                table.insert(text, source)
                table.insert(text, DFRL.locale.Text(source))
            end
            record.text = (record.text or "") .. " " .. FoldEditorSearch(table.concat(text, " "))
        end
        for _, section in ipairs(sections) do
            Add({ label = section.label }, section)
            for _, entry in ipairs(section.options or {}) do
                Add(
                    { label = entry[2], description = entry[3], offset = entry.offset, terms = entry.terms },
                    section,
                    entry[1]
                )
            end
            if section.mode then
                local mode = section.mode
                Add({ label = mode.label }, section, mode.key)
                for _, entry in ipairs(mode.values) do
                    Add({ label = entry[2], description = entry[3] }, section, mode.key)
                end
            end
            for _, entry in ipairs(section.search or {}) do
                Add(entry, section)
            end
        end
        for _, entry in ipairs(options.searchEntries or {}) do
            Add(entry, bySection[entry.section])
        end
        owner.index, owner.language = index, DFRL.locale.code
        return index
    end
    local function PrepareResults()
        if owner.frame then return end
        local frame = CreateFrame("Frame", nil, content)
        frame:SetWidth(resultWidth)
        frame:SetHeight(1)
        frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        owner.frame = frame
        owner.empty = Label(frame, 12, "No matching settings.")
        owner.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -12)
        owner.empty:SetWidth(resultWidth - 8)
        owner.empty:SetHeight(36)
        owner.count = Label(frame, 11, "")
        owner.count:SetPoint("TOP", frame, "TOP", 0, -resultFooter - 4)
        owner.count:SetWidth(resultWidth - 100)
        owner.count:SetHeight(24)
        owner.count:SetJustifyH("CENTER")
        owner.previous = T.CreateEditorButton(frame, "<", 32, 26)
        owner.previous:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -resultFooter)
        owner.next = T.CreateEditorButton(frame, ">", 32, 26)
        owner.next:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -resultFooter)
        owner.previous:SetScript("OnClick", function()
            if owner.page > 1 then
                owner.page = owner.page - 1
                navigation.Refresh(true)
            end
        end)
        owner.next:SetScript("OnClick", function()
            if owner.page * 8 < table.getn(owner.results) then
                owner.page = owner.page + 1
                navigation.Refresh(true)
            end
        end)
    end
    function owner.Refresh()
        if not parent:IsShown() or not owner.active then return end
        RefreshHeader()
        PrepareResults()
        if not owner.frame:IsShown() then owner.frame:Show() end
        local total = table.getn(owner.results)
        local first = (owner.page - 1) * 8 + 1
        local last = math.min(total, first + 7)
        for slot = 1, 8 do
            local result = owner.results[first + slot - 1]
            local button = owner.rows[slot]
            if result then
                if not button then
                    button = CreateFrame("Button", nil, owner.frame)
                    button:SetWidth(resultWidth)
                    button:SetHeight(resultHeight)
                    button:SetPoint("TOPLEFT", owner.frame, "TOPLEFT", 0, -(slot - 1) * resultPitch)
                    local hover = button:CreateTexture(nil, "BACKGROUND")
                    hover:SetAllPoints(button)
                    hover:SetTexture("Interface\\Buttons\\WHITE8X8")
                    hover:SetVertexColor(1, 0.82, 0, 0.08)
                    hover:Hide()
                    button:SetScript("OnEnter", function()
                        if not hover:IsShown() then hover:Show() end
                    end)
                    local function HideHover()
                        if hover:IsShown() then hover:Hide() end
                    end
                    button:SetScript("OnLeave", HideHover)
                    button:SetScript("OnHide", HideHover)
                    button.label = Label(button, 12, "")
                    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -4)
                    button.label:SetWidth(resultWidth - 20)
                    button.label:SetHeight(18)
                    button.label:SetJustifyH("LEFT")
                    button.label:SetTextColor(1, 0.82, 0)
                    button.path = Label(button, 10, "")
                    button.path:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -24)
                    button.path:SetWidth(resultWidth - 20)
                    button.path:SetHeight(14)
                    button.path:SetJustifyH("LEFT")
                    button.path:SetTextColor(0.65, 0.65, 0.62)
                    button:SetScript("OnClick", function() navigation.OpenResult(button.resultIndex) end)
                    owner.rows[slot] = button
                end
                button.resultIndex = first + slot - 1
                if button.label:GetText() ~= DFRL.locale.Text(result.label) then button.label:SetText(result.label) end
                local group = byGroup[result.group]
                local pathText = group and DFRL.locale.Text(group.label) or ""
                if result.sectionInfo and (not group or result.sectionInfo.label ~= group.label) then
                    pathText = pathText
                        .. (pathText ~= "" and " > " or "")
                        .. DFRL.locale.Text(result.sectionInfo.label)
                end
                T.SetTextIfChanged(button.path, pathText)
                if not button:IsShown() then button:Show() end
            elseif button and button:IsShown() then
                button:Hide()
            end
        end
        if total == 0 then
            if not owner.empty:IsShown() then owner.empty:Show() end
        elseif owner.empty:IsShown() then
            owner.empty:Hide()
        end
        T.SetTextIfChanged(
            owner.count,
            (total == 0 and "0" or tostring(first) .. "-" .. tostring(last)) .. " / " .. tostring(total)
        )
        local previous, nextPage = owner.page > 1, last < total
        if owner.previousEnabled ~= previous then
            owner.previousEnabled = previous
            if previous then
                owner.previous:Enable()
            else
                owner.previous:Disable()
            end
        end
        if owner.nextEnabled ~= nextPage then
            owner.nextEnabled = nextPage
            if nextPage then
                owner.next:Enable()
            else
                owner.next:Disable()
            end
        end
        local height = math.max(scroll:GetHeight(), resultFooter + 36)
        if owner.frame:GetHeight() ~= height then owner.frame:SetHeight(height) end
        if content:GetHeight() ~= height then content:SetHeight(height) end
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end
    function owner.Clear(refresh)
        local changed = owner.active or owner.query ~= ""
        owner.active, owner.query, owner.folded, owner.page = false, "", nil, 1
        navigation.query = ""
        if table.getn(owner.results) > 0 then
            owner.results = {}
            navigation.results = owner.results
        end
        if owner.frame and owner.frame:IsShown() then owner.frame:Hide() end
        owner.input:ClearFocus()
        SyncInput()
        if changed and refresh then
            if options.onNavigate then options.onNavigate(navigation.selected) end
            navigation.Refresh(true)
        end
    end
    function owner.Search(query, force)
        query = type(query) == "string" and query or ""
        local folded = string.gsub(FoldEditorSearch(query), "^%s*(.-)%s*$", "%1")
        if folded == "" then
            owner.Clear(true)
            return
        end
        owner.query, navigation.query = query, query
        if not parent:IsShown() then return end
        SyncInput()
        if not force and owner.active and owner.folded == folded and owner.language == DFRL.locale.code then return end
        if not owner.active then
            navigation.RememberOffset()
            owner.active = true
            if options.onNavigate then options.onNavigate(nil) end
        end
        owner.folded, owner.page = folded, 1
        local results, tokens = {}, {}
        for token in string.gfind(folded, "%S+") do
            table.insert(tokens, token)
        end
        for _, record in ipairs(Index()) do
            local matched = true
            for _, token in ipairs(tokens) do
                if not string.find(record.text, token, 1, true) then
                    matched = false
                    break
                end
            end
            if matched then table.insert(results, record) end
        end
        owner.results, navigation.results = results, results
        navigation.Refresh(true)
    end
    function navigation.OpenResult(index)
        if not parent:IsShown() or not owner.active then return end
        local result = owner.results[index]
        if not result then return end
        local entry, section = result.entry, result.sectionInfo
        owner.Clear(false)
        navigation.Select(result.group or navigation.selected)
        if section then
            local offset = entry.offset or (section.searchOffsets and section.searchOffsets[result.target]) or 0
            navigation.Jump((section.y or 0) + (section.headingHeight or 0) + offset)
        end
    end
    navigation.Search = owner.Search
    navigation.ClearSearch = function() owner.Clear(true) end
    owner.clear:SetScript("OnClick", navigation.ClearSearch)
    owner.input:SetScript("OnTextChanged", function()
        if not owner.changing then owner.Search(owner.input:GetText()) end
    end)
    owner.input:SetScript("OnEnterPressed", function() navigation.OpenResult((owner.page - 1) * 8 + 1) end)
    owner.input:SetScript("OnEscapePressed", function()
        if options.onEscape then
            owner.Clear(false)
            options.onEscape()
        else
            owner.Clear(true)
        end
    end)
    HookScript(header, "OnHide", function() owner.Clear(false) end)
    HookScript(header, "OnShow", function()
        RefreshHeader()
        SyncInput()
        if owner.query ~= "" then owner.Search(owner.query, true) end
    end)
    DFRL.locale.Listen(function()
        owner.index = nil
        if not parent:IsShown() then return end
        RefreshHeader()
        if owner.query ~= "" then owner.Search(owner.query, true) end
    end)
    RefreshHeader()
    return owner
end

-- Related settings share one scroll surface and keep their original owners.
function DFRL.tools.CreateEditorNavigator(parent, sidebar, groups, sections, options)
    local navigation = {
        pages = {},
        buttons = {},
        offsets = {},
        selected = groups[1].key,
        searchHeight = options.search and 96 or 0,
    }
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
        button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, -48 - navigation.searchHeight - (index - 1) * 48)
        button.label:SetHeight(32)
        button.label:SetJustifyV("MIDDLE")
        button:SetScript("OnClick", function() navigation.Select(key) end)
        navigation.buttons[key] = button
    end
    local function PrepareSection(section)
        if navigation.pages[section.key] then return end
        local shell = CreateFrame("Frame", nil, content)
        shell:SetWidth(width - 24)
        shell:Hide()
        -- The selected sidebar button already names the category. Keep only
        -- headings that distinguish an actual subsection within that category.
        local headingHeight = section.label ~= groupLabels[section.group] and 34 or 0
        if headingHeight > 0 then
            local heading = Label(shell, 13, section.label)
            heading:SetTextColor(0.94, 0.79, 0.47)
            heading:SetPoint("TOP", shell, "TOP", 0, -4)
            heading:SetWidth(width - 24)
            heading:SetHeight(20)
            heading:SetJustifyH("CENTER")
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
        if options.prepare then options.prepare(section, page) end
    end
    function navigation.Refresh(force)
        if not parent:IsShown() then
            rendered = nil
            return
        end
        if navigation.searchOwner then navigation.searchOwner.RefreshHeader() end
        if navigation.searchOwner and navigation.searchOwner.active then
            for _, section in ipairs(sections) do
                if section.shell and section.shell:IsShown() then section.shell:Hide() end
            end
            rendered = nil
            navigation.searchOwner.Refresh()
            return
        end
        if rendered == navigation.selected and not force then return end
        if rendered == navigation.selected and slider then
            navigation.offsets[navigation.selected] = slider:GetValue()
        end
        for _, section in ipairs(sections) do
            if section.group == navigation.selected then
                PrepareSection(section)
                if not section.shell:IsShown() then section.shell:Show() end
            elseif section.shell and section.shell:IsShown() then
                section.shell:Hide()
            end
        end
        if options.arrange then options.arrange() end
        local y = 0
        for _, section in ipairs(sections) do
            if section.group == navigation.selected then
                local shell, page = section.shell, navigation.pages[section.key]
                local height = page:GetHeight() + section.headingHeight + 12
                if section.y ~= y then
                    shell:ClearAllPoints()
                    shell:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                    section.y = y
                end
                if shell:GetHeight() ~= height then shell:SetHeight(height) end
                y = y + height
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
        if slider and rendered == navigation.selected then
            navigation.offsets[navigation.selected] = slider:GetValue()
        end
    end
    navigation.RememberOffset = RememberOffset
    function navigation.Jump(value)
        if not slider then return end
        local low, high = slider:GetMinMaxValues()
        local offset = math.max(low, math.min(high, value))
        slider:SetValue(offset)
        navigation.offsets[navigation.selected] = offset
    end
    function navigation.Select(key)
        if not navigation.buttons[key] then return end
        local searching = navigation.searchOwner and navigation.searchOwner.active
        if navigation.searchOwner then navigation.searchOwner.Clear(false) end
        if not searching then RememberOffset() end
        navigation.selected = key
        if options.onNavigate then options.onNavigate(key) end
        navigation.Refresh(true)
    end
    HookScript(scroll, "OnHide", function()
        RememberOffset()
        rendered = nil
    end)
    if options.search then
        navigation.searchOwner =
            CreateEditorSearch(parent, sidebar, scroll, content, navigation, groups, sections, options)
    end
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

-- Numeric steps keep a separate right-hand value/button area. Their captions
-- can still use one title line without reserving a blank second line.
function DFRL.tools.CompactEditorNumber(control)
    local label, description = control.label, control.description
    local natural = label:GetStringWidth()
    local labelHeight = natural and natural > 0 and natural <= label:GetWidth() and 16 or 28
    local descriptionTop = 7 + labelHeight + 3
    local height = math.max(70, descriptionTop + 40 + 6)
    if not natural or natural <= 0 then control.editorNumberHeight = nil end
    if control.editorNumberHeight == height and control:GetHeight() == height then return height end
    label:SetHeight(labelHeight)
    description:ClearAllPoints()
    description:SetPoint("TOPLEFT", control, "TOPLEFT", 0, -descriptionTop)
    control:SetHeight(height)
    control.editorNumberHeight = natural and natural > 0 and height or nil
    return height
end

-- Place existing controls in row-major order, with explicit full-row controls
-- and a shared maximum height for each pair. No idle sampling or extra frames.
function DFRL.tools.LayoutEditorOptions(parent, controls, columns, gap, top)
    local column, height = 0, 0
    local rowWidth = (parent:GetWidth() - gap * (columns - 1)) / columns
    for _, record in ipairs(controls) do
        local control, span = record.frame, record.span
        if span == columns and column > 0 then
            top, column, height = top + height, 0, 0
        end
        local itemHeight = record.numeric and T.CompactEditorNumber(control) or T.CompactEditorToggle(control)
        local x, y = column * (rowWidth + gap), -top
        if record.x ~= x or record.y ~= y then
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
            record.x, record.y = x, y
        end
        height = math.max(height, itemHeight)
        column = column + span
        if column >= columns then
            top, column, height = top + height, 0, 0
        end
    end
    return top + height
end
