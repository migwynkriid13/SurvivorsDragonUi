--[[
SDUI artwork uses cropped texture pixels from source commit
623eca5893c9d475a7b77bd25808bdbe801d247c.
Source provenance and pixel coordinates: third_party/SDUI-ARTWORK.md.
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
    texture:SetTexture(path .. file .. ".tga")
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

function DFRL.tools.CreateEditorPanel(parent, width, height, borderSize)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    frame.editorFill = Fill(frame, 0.035, 0.038, 0.043, 0.97)
    frame.editorBorder = Border(frame, borderSize or 24)
    local header = Artwork(frame, "header", "ARTWORK", 0, 199 / 256, 0, 1)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -6)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -6)
    header:SetHeight(36)
    header:SetAlpha(0.42)
    frame.editorHeader = header
    return frame
end

function DFRL.tools.CreateEditorButton(parent, text, width, height, primary)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    if primary then
        Fill(button, 0.26, 0.045, 0.025, 0.96)
    else
        Fill(button, 0.055, 0.06, 0.065, 0.93)
    end
    button.editorBorder = Border(button, math.min(12, height / 2))
    local selected = Artwork(button, "choice", "ARTWORK", 0, 187 / 256, 0, 21 / 64)
    selected:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    selected:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    selected:SetAlpha(primary and 0.2 or 0.15)
    selected:Hide()
    local hover = Artwork(button, "choice", "HIGHLIGHT", 0, 187 / 256, 32 / 64, 53 / 64)
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    hover:SetAlpha(0.16)
    button.label = Label(button, 12, text)
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.label:SetWidth(math.max(1, width - 12))
    button.label:SetHeight(16)
    button.label:SetJustifyH("CENTER")
    function button:SetSelected(value)
        self.editorSelected = value and true or false
        if self.editorSelected then
            selected:Show()
        else
            selected:Hide()
        end
        if self.editorSelected or primary then
            self.label:SetTextColor(1, 0.83, 0.38)
        else
            self.label:SetTextColor(0.88, 0.87, 0.83)
        end
    end
    button:SetSelected(false)
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
    local mark = Artwork(button, "checkbox", "OVERLAY", 32 / 64, 62 / 64, 0, 29 / 32)
    mark:SetAllPoints(checkbox)
    mark:Hide()
    local hover = Artwork(button, "choice", "HIGHLIGHT", 0, 187 / 256, 32 / 64, 53 / 64)
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -2)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 2)
    hover:SetAlpha(0.09)
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
