-- Restyle the native character pane without replacing equipment or stat logic.
--[[
World of Warcraft artwork copyright Blizzard Entertainment, Inc.
The artwork is obtained via NeticSoul/DragonUI commit
6d9cc95eedd1de78fab3b965683df13421e21604 and Gethe/wow-ui-textures
commit e80e3278cc833c89e1f3fc79557b68315d750935 (10.0.0 build 45454).
Frame/slot/tab coordinates and assembly are adapted from DragonUI and the
Blizzard CharacterFrame / SharedUIPanelTemplates sources. The DragonUI
notices credit DragonUI_NewEra and Karl-HeinzSchneider/DragonflightUI as
artwork conduits. No source-addon framework or retail atlas API is included.
The license below covers software contributions, not Blizzard artwork.
Exact source regions and preparation: third_party/Character-ARTWORK.md.

MIT License
Copyright (c) 2026 NeticSoul and DragonUI contributors
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
DFRL:NewMod("Character window", 6, function()
    local owner, paper, model = CharacterFrame, PaperDollFrame, CharacterModelFrame
    local attributes = CharacterAttributesFrame
    if not owner or not paper or not model or not attributes then return end

    local WIDTH, LEFT_WIDTH = 624, 338
    local BODY_TOP = 28
    local WEAPON_TOP = BODY_TOP + 373
    local WEAPON_ART_TOP, WEAPON_ART_HEIGHT = 8, 53
    local HEIGHT = WEAPON_TOP - WEAPON_ART_TOP + WEAPON_ART_HEIGHT + 6
    local LEFT_INSET = 12
    local MODEL_HEIGHT = 358
    local CONTENT_WIDTH, ROW_WIDTH = 246, 230
    local COLUMN_GAP = 12
    local COLUMN_WIDTH = (ROW_WIDTH - COLUMN_GAP) / 2
    local path = DFRL:GetInfoOrCons("tex") .. "character\\"
    local sheets = { Chrome = { 1024, 256 }, Parts = { 256, 256 }, Tabs = { 64, 256 }, Close = { 128, 128 } }
    local panes = { "PaperDollFrame", "PetPaperDollFrame", "ReputationFrame", "SkillFrame", "HonorFrame" }
    local primaryNames = {
        "CharacterStatFrame1",
        "CharacterStatFrame2",
        "CharacterStatFrame3",
        "CharacterStatFrame4",
        "CharacterStatFrame5",
        "CharacterArmorFrame",
        "CharacterAttackFrame",
        "CharacterAttackPowerFrame",
        "CharacterDamageFrame",
        "CharacterRangedAttackFrame",
        "CharacterRangedAttackPowerFrame",
        "CharacterRangedDamageFrame",
    }
    local controller = CreateFrame("Frame")
    local refreshing, tabsUpdating, statsQueued = false, false, false
    local wrapped = {}

    local function Cut(parent, sheet, left, top, right, bottom, width, height, layer)
        local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
        texture.sduiCharacterArt = true
        texture:SetTexture(path .. sheet .. (sheet == "Chrome" and ".blp" or ".tga"))
        local size = sheets[sheet]
        texture:SetTexCoord(left / size[1], right / size[1], top / size[2], bottom / size[2])
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        return texture
    end

    local function SetWidth(frame, width)
        if not T.NearlyEqual(frame:GetWidth(), width) then frame:SetWidth(width) end
    end
    local function SetHeight(frame, height)
        if not T.NearlyEqual(frame:GetHeight(), height) then frame:SetHeight(height) end
    end
    local function SetLevel(frame, level)
        if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
    end
    local function Anchor(frame, point, parent, relativePoint, x, y)
        local oldPoint, relative, oldRelativePoint, oldX, oldY
        if frame.GetNumPoints and frame.GetPoint and frame:GetNumPoints() == 1 then
            oldPoint, relative, oldRelativePoint, oldX, oldY = frame:GetPoint(1)
        end
        if
            oldPoint ~= point
            or relative ~= parent
            or oldRelativePoint ~= relativePoint
            or not T.NearlyEqual(oldX, x)
            or not T.NearlyEqual(oldY, y)
        then
            frame:ClearAllPoints()
            frame:SetPoint(point, parent, relativePoint, x, y)
        end
    end
    local function Justify(label, side)
        local current = label.GetJustifyH and label:GetJustifyH() or label.sduiCharacterJustify
        if current ~= side then label:SetJustifyH(side) end
        label.sduiCharacterJustify = side
    end
    local function TextChanged(cache, label)
        local text = label:GetText() or ""
        local font, size, flags = label:GetFont()
        local scale = label:GetParent():GetEffectiveScale()
        local changed = cache.label ~= label
            or cache.text ~= text
            or cache.font ~= font
            or cache.size ~= size
            or cache.flags ~= flags
            or not T.NearlyEqual(cache.scale, scale)
        cache.label, cache.text, cache.font, cache.size, cache.flags, cache.scale =
            label, text, font, size, flags, scale
        return changed
    end
    local function Place(frame, parent, x, y, width, height)
        Anchor(frame, "TOPLEFT", parent, "TOPLEFT", x, y)
        if width then SetWidth(frame, width) end
        if height then SetHeight(frame, height) end
    end

    local function HideStockArt(frame)
        if not frame then return end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:GetObjectType() == "Texture" and not region.sduiCharacterArt then
                local name = region:GetName()
                if not name or not string.find(name, "Portrait", 1, true) then region:SetTexture(nil) end
            end
        end
    end

    local background = owner:CreateTexture(nil, "BACKGROUND")
    background.sduiCharacterArt = true
    background:SetTexture(path .. "Background.tga")
    background:SetTexCoord(0, 450 / 512, 0, 420 / 512)
    background:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, -20)
    background:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)

    local topLeft = Cut(owner, "Chrome", 0, 0, 150, 150, 75, 75, "OVERLAY")
    topLeft:SetPoint("TOPLEFT", owner, "TOPLEFT", -13, 16)
    local topRight = Cut(owner, "Chrome", 256, 0, 406, 150, 75, 75, "OVERLAY")
    topRight:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 4, 16)
    local bottomLeft = Cut(owner, "Chrome", 512, 0, 576, 64, 32, 32, "OVERLAY")
    bottomLeft:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -13, -3)
    local bottomRight = Cut(owner, "Chrome", 640, 0, 704, 64, 32, 32, "OVERLAY")
    bottomRight:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 4, -3)
    local top = Cut(owner, "Chrome", 768, 0, 832, 150, nil, 75, "OVERLAY")
    top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
    top:SetPoint("TOPRIGHT", topRight, "TOPLEFT", 0, 0)
    local bottom = Cut(owner, "Chrome", 896, 0, 928, 64, nil, 32, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", 0, 0)
    local left = Cut(owner, "Chrome", 0, 192, 150, 224, 75, nil, "OVERLAY")
    left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT", 0, 0)
    local right = Cut(owner, "Chrome", 256, 192, 406, 224, 75, nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT", 0, 0)

    local function Trim(frame)
        local corners = {
            { "TOPLEFT", 104, 103, 111, 110 },
            { "TOPRIGHT", 104, 94, 111, 101 },
            { "BOTTOMLEFT", 104, 85, 111, 92 },
            { "BOTTOMRIGHT", 104, 76, 111, 83 },
        }
        local pieces = {}
        for _, entry in ipairs(corners) do
            local texture = Cut(frame, "Parts", entry[2], entry[3], entry[4], entry[5], 7, 7, "OVERLAY")
            texture:SetPoint(entry[1], frame, entry[1], 0, 0)
            pieces[entry[1]] = texture
        end
        local t = Cut(frame, "Parts", 0, 136, 32, 141, nil, 5, "OVERLAY")
        t:SetPoint("TOPLEFT", pieces.TOPLEFT, "TOPRIGHT", 0, 0)
        t:SetPoint("TOPRIGHT", pieces.TOPRIGHT, "TOPLEFT", 0, 0)
        local b = Cut(frame, "Parts", 0, 129, 32, 134, nil, 5, "OVERLAY")
        b:SetPoint("BOTTOMLEFT", pieces.BOTTOMLEFT, "BOTTOMRIGHT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", pieces.BOTTOMRIGHT, "BOTTOMLEFT", 0, 0)
        local l = Cut(frame, "Parts", 65, 128, 70, 160, 5, nil, "OVERLAY")
        l:SetPoint("TOPLEFT", pieces.TOPLEFT, "BOTTOMLEFT", 0, 0)
        l:SetPoint("BOTTOMLEFT", pieces.BOTTOMLEFT, "TOPLEFT", 0, 0)
        local r = Cut(frame, "Parts", 72, 128, 77, 160, 5, nil, "OVERLAY")
        r:SetPoint("TOPRIGHT", pieces.TOPRIGHT, "BOTTOMRIGHT", 0, 0)
        r:SetPoint("BOTTOMRIGHT", pieces.BOTTOMRIGHT, "TOPRIGHT", 0, 0)
    end

    local function Card(frame)
        if frame.sduiCharacterCard then return end
        frame.sduiCharacterCard = true
        local t = Cut(frame, "Parts", 1, 65, 170, 74, nil, 9)
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        local b = Cut(frame, "Parts", 1, 1, 170, 47, nil, 46)
        b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        local middle = Cut(frame, "Parts", 1, 192, 170, 200)
        middle:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 1, 0)
        middle:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, 0)
    end

    local modelBorder = CreateFrame("Frame", nil, paper)
    modelBorder:EnableMouse(false)
    Place(modelBorder, paper, 48, -BODY_TOP - 2, 239, MODEL_HEIGHT + 8)
    Trim(modelBorder)
    Place(model, paper, 52, -BODY_TOP - 6, 231, MODEL_HEIGHT)
    -- Keep the existing model, bindings, rotation, equipment refresh and camera.
    -- These four native race textures are only its background scenery.
    if type(DressUpTexturePath) == "function" then
        local quarters = {
            { 1, 0, 0, 212, 245, 44 / 256, 1, 10 / 255, 1 },
            { 2, 212, 0, 19, 245, 0, 19 / 64, 10 / 255, 1 },
            { 3, 0, 245, 212, 75, 44 / 256, 1, 0, 75 / 128 },
            { 4, 212, 245, 19, 75, 0, 19 / 64, 0, 75 / 128 },
        }
        for _, q in ipairs(quarters) do
            local texture = model:CreateTexture(nil, "BACKGROUND")
            texture:SetTexture(DressUpTexturePath() .. q[1])
            texture:SetTexCoord(q[6], q[7], q[8], q[9])
            texture:SetWidth(q[4])
            texture:SetHeight(q[5] * MODEL_HEIGHT / 320)
            texture:SetPoint("TOPLEFT", model, "TOPLEFT", q[2], -q[3] * MODEL_HEIGHT / 320)
            texture:SetVertexColor(0.38, 0.38, 0.38)
        end
    end

    local slotColumns = {
        {
            names = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" },
            x = 8,
            cut = { 53, 76, 102, 120 },
            offset = -4,
        },
        {
            names = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" },
            x = 293,
            cut = { 1, 76, 51, 120 },
            offset = -9,
        },
    }
    local qualityBorders, itemButtons = {}, {}
    DFRL.characterItemButtons = itemButtons
    local function HideQuality(button)
        local borders = qualityBorders[button]
        if not borders then return end
        for _, border in ipairs(borders) do
            if border:IsShown() then border:Hide() end
        end
        borders.r, borders.g, borders.b = nil, nil, nil
        return borders
    end
    local function UpdateQuality(button)
        local borders = qualityBorders[button]
        if not borders then return end
        if type(GetInventoryItemQuality) ~= "function" then
            HideQuality(button)
            return
        end
        local slot = button:GetID()
        if not GetInventoryItemTexture("player", slot) then
            HideQuality(button)
            return
        end
        local quality = GetInventoryItemQuality("player", slot)
        if type(quality) ~= "number" or quality < 2 then
            HideQuality(button)
            return
        end
        local r, g, b
        if type(GetItemQualityColor) == "function" then
            r, g, b = GetItemQualityColor(quality)
        else
            local color = _G["ITEM_QUALITY" .. quality .. "_COLOR"]
            if color then
                r, g, b = color.r, color.g, color.b
            end
        end
        if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
            HideQuality(button)
            return
        end
        for _, border in ipairs(borders) do
            local oldR, oldG, oldB, oldA = borders.r, borders.g, borders.b, 1
            if border.GetVertexColor then
                oldR, oldG, oldB, oldA = border:GetVertexColor()
            end
            if
                not T.NearlyEqual(oldR, r)
                or not T.NearlyEqual(oldG, g)
                or not T.NearlyEqual(oldB, b)
                or not T.NearlyEqual(oldA, 1)
            then
                border:SetVertexColor(r, g, b, 1)
            end
            if not border:IsShown() then border:Show() end
        end
        borders.r, borders.g, borders.b = r, g, b
    end

    local function QualityEdge(button, blend, alpha, outset)
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetTexture(path .. "QualityBorder.tga")
        border:SetBlendMode(blend)
        border:SetAlpha(alpha)
        border:SetPoint("TOPLEFT", button, "TOPLEFT", -outset, outset)
        border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", outset, -outset)
        border:Hide()
        return border
    end
    local function RegisterItemButton(button)
        table.insert(itemButtons, button)
        -- Keep the native palette and icon clear; brighten and widen only the rim.
        qualityBorders[button] = {
            QualityEdge(button, "BLEND", 1, 0),
            QualityEdge(button, "ADD", 0.4, 0),
            QualityEdge(button, "ADD", 0.3, 1),
        }
    end

    local function RefreshQuality()
        for button in pairs(qualityBorders) do
            UpdateQuality(button)
        end
    end

    local function SlotArt(button, rectangle, x, y, width, height)
        local texture = Cut(button, "Parts", rectangle[1], rectangle[2], rectangle[3], rectangle[4], width, height)
        texture:SetPoint("TOPLEFT", button, "TOPLEFT", x, y)
        local normal = button:GetNormalTexture()
        if normal then normal:SetTexture(nil) end
        RegisterItemButton(button)
    end
    for _, column in ipairs(slotColumns) do
        for index, name in ipairs(column.names) do
            local button = _G["Character" .. name .. "Slot"]
            if button then
                Place(button, paper, column.x, -BODY_TOP - 6 - (index - 1) * 45, 37, 37)
                SlotArt(button, column.cut, column.offset, 0, column.cut[3] - column.cut[1], 44)
            end
        end
    end
    for index, name in ipairs({ "MainHand", "SecondaryHand", "Ranged" }) do
        local button = _G["Character" .. name .. "Slot"]
        if button then
            Place(button, paper, 101 + (index - 1) * 42, -WEAPON_TOP, 37, 37)
            SlotArt(button, { 172, 1, 214, 54 }, -3, WEAPON_ART_TOP, 42, WEAPON_ART_HEIGHT)
        end
    end
    if CharacterAmmoSlot then
        Place(CharacterAmmoSlot, paper, 239, -WEAPON_TOP - 5, 27, 27)
        RegisterItemButton(CharacterAmmoSlot)
    end

    local panel = CreateFrame("Frame", nil, paper)
    Place(panel, paper, LEFT_WIDTH + 4, -BODY_TOP, WIDTH - LEFT_WIDTH - 10, HEIGHT - BODY_TOP - 6)
    panel:EnableMouse(false)
    Trim(panel)
    local scroll = CreateFrame("ScrollFrame", "SurvivorsDragonUiCharacterStatsScroll", panel)
    Place(scroll, panel, 8, -8, CONTENT_WIDTH, HEIGHT - BODY_TOP - 22)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(CONTENT_WIDTH)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    attributes:SetParent(content)
    attributes:SetFrameLevel(content:GetFrameLevel() + 1)
    HideStockArt(attributes)
    Card(attributes)
    local heading = attributes:CreateFontString(nil, "OVERLAY")
    T.SetFont(heading, 12)
    heading:SetTextColor(1, 0.82, 0)
    heading:SetJustifyH("LEFT")
    heading:SetPoint("TOPLEFT", attributes, "TOPLEFT", 8, -8)
    heading:SetWidth(ROW_WIDTH)

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(14)
    slider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -26)
    slider:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 26)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    local thumb = slider:GetThumbTexture()
    thumb:SetWidth(18)
    thumb:SetHeight(24)
    slider:SetValue(0)
    local rail = slider:CreateTexture(nil, "BACKGROUND")
    rail:SetTexture("Interface\\Buttons\\WHITE8X8")
    rail:SetVertexColor(0, 0, 0, 0.65)
    rail:SetAllPoints(slider)
    local up, down, range = nil, nil, 0
    local scrollValue, upEnabled, downEnabled
    local function SetScroll(value, force)
        value = math.max(0, math.min(range, value))
        local current = scroll.GetVerticalScroll and scroll:GetVerticalScroll() or scrollValue
        if force or not T.NearlyEqual(current, value) then scroll:SetVerticalScroll(value) end
        scrollValue = value
        if up then
            local canUp, canDown = value > 0, value < range
            if upEnabled ~= canUp then
                if canUp then
                    up:Enable()
                else
                    up:Disable()
                end
                upEnabled = canUp
            end
            if downEnabled ~= canDown then
                if canDown then
                    down:Enable()
                else
                    down:Disable()
                end
                downEnabled = canDown
            end
        end
    end
    slider:SetScript("OnValueChanged", function() SetScroll(slider:GetValue()) end)
    local function Step(amount) slider:SetValue(slider:GetValue() + amount) end
    local function Arrow(direction, point, offset)
        local button = CreateFrame("Button", nil, panel)
        button:SetWidth(20)
        button:SetHeight(20)
        button:SetPoint(point, panel, point, -3, offset)
        local nativePath = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. direction .. "Button-"
        button:SetNormalTexture(nativePath .. "Up")
        button:SetPushedTexture(nativePath .. "Down")
        button:SetDisabledTexture(nativePath .. "Disabled")
        button:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. direction .. "Button-Highlight")
        button:SetScript("OnClick", function() Step(direction == "Up" and -48 or 48) end)
        return button
    end
    up = Arrow("Up", "TOPRIGHT", -5)
    down = Arrow("Down", "BOTTOMRIGHT", 5)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function() Step(-arg1 * 48) end)

    local rowMetrics = {}
    local function StyleRow(row, x, y)
        local name = row:GetName()
        local label = row.label or (name and _G[name .. "Label"])
        local value = row.value or (name and _G[name .. "StatText"])
        if not label or not value then return 0 end
        local metrics = rowMetrics[row]
        if not metrics then
            metrics = { label = {}, value = {} }
            rowMetrics[row] = metrics
        end
        if metrics.label.label ~= label then T.SetFont(label, 12) end
        if metrics.value.label ~= value then T.SetFont(value, 12) end
        local labelChanged, valueChanged = TextChanged(metrics.label, label), TextChanged(metrics.value, value)
        local measure = not metrics.ready
            or labelChanged
            or valueChanged
            or not T.NearlyEqual(label:GetWidth(), metrics.labelWidth)
            or not T.NearlyEqual(value:GetWidth(), metrics.valueWidth)
        if measure then
            metrics.valueWidth = math.min(COLUMN_WIDTH * 0.48, math.max(24, math.ceil(value:GetStringWidth() or 0) + 2))
            metrics.labelWidth = COLUMN_WIDTH - metrics.valueWidth - 8
        end
        Anchor(label, "LEFT", row, "LEFT", 0, 0)
        SetWidth(label, metrics.labelWidth)
        Justify(label, "LEFT")
        Anchor(value, "RIGHT", row, "RIGHT", 0, 0)
        SetWidth(value, metrics.valueWidth)
        Justify(value, "RIGHT")
        if measure then
            local labelWidth, valueWidth = label:GetStringWidth() or 0, value:GetStringWidth() or 0
            metrics.height = math.max(16, label:GetHeight() + 2, value:GetHeight() + 2)
            metrics.ready = (metrics.label.text == "" or labelWidth > 0)
                and (metrics.value.text == "" or valueWidth > 0)
        end
        -- Native AZS_UpdateMore resets row anchors on every update. Compare the
        -- actual geometry even when text measurements are cached.
        Place(row, row:GetParent(), x, -y, COLUMN_WIDTH)
        SetLevel(row, row:GetParent():GetFrameLevel() + 1)
        local stat = name and _G[name .. "Stat"]
        if stat then
            SetLevel(stat, row:GetFrameLevel() + 1)
            SetWidth(stat, metrics.valueWidth)
            SetHeight(stat, metrics.height)
        end
        if not metrics.mouseEnabled then
            row:EnableMouse(true)
            metrics.mouseEnabled = true
        end
        return metrics.height
    end

    local function LayoutPair(first, second, y)
        local height = StyleRow(first, 8, y)
        if second then height = math.max(height, StyleRow(second, 8 + COLUMN_WIDTH + COLUMN_GAP, y)) end
        SetHeight(first, height)
        if second then SetHeight(second, height) end
        return y + height
    end
    local function LayoutRows(rows, y)
        local first
        for _, row in ipairs(rows) do
            if row:IsShown() then
                if first then
                    y = LayoutPair(first, row, y)
                    first = nil
                else
                    first = row
                end
            end
        end
        if first then y = LayoutPair(first, nil, y) end
        return y
    end

    local function RowIndex(row)
        local _, _, number = string.find(row:GetName() or "", "(%d+)$")
        return tonumber(number) or 0
    end
    local primaryRows, extraRows = {}, {}
    local extraOwner, extraChildCount, extraChildren, extraTitle
    local function MoreRows(more)
        local count = more.GetNumChildren and more:GetNumChildren()
        if more == extraOwner and count and count == extraChildCount then return extraRows end
        local children = { more:GetChildren() }
        local changed = more ~= extraOwner or not extraChildren or table.getn(children) ~= table.getn(extraChildren)
        if not changed then
            for index, child in ipairs(children) do
                if extraChildren[index] ~= child then
                    changed = true
                    break
                end
            end
        end
        if changed then
            for index = table.getn(extraRows), 1, -1 do
                extraRows[index] = nil
            end
            for _, row in ipairs(children) do
                if row.label and row.value then table.insert(extraRows, row) end
            end
            table.sort(extraRows, function(a, b) return RowIndex(a) < RowIndex(b) end)
            extraChildren = children
        end
        extraOwner, extraChildCount = more, count
        return extraRows
    end

    local function RefreshStats()
        if refreshing or not paper:IsVisible() then return end
        refreshing = true
        T.SetTextIfChanged(heading, CharacterFrameTab1 and CharacterFrameTab1:GetText() or CHARACTER or "")
        Place(attributes, content, 0, 0, CONTENT_WIDTH)
        local used = 0
        for _, name in ipairs(primaryNames) do
            local row = _G[name]
            if row then
                used = used + 1
                primaryRows[used] = row
            end
        end
        for index = table.getn(primaryRows), used + 1, -1 do
            primaryRows[index] = nil
        end
        SetHeight(attributes, math.max(60, LayoutRows(primaryRows, 28) + 8))
        local y = attributes:GetHeight() + 8

        -- Move the actual native container and its live rows. No AZS stat values,
        -- tooltip text or conditional visibility are copied or recomputed here.
        local more = _G.AZSMoreStats
        if more then
            if more:GetParent() ~= content then
                more:SetParent(content)
                SetLevel(more, content:GetFrameLevel() + 1)
                more:SetBackdrop(nil)
                Card(more)
            end
            Place(more, content, 0, -y, CONTENT_WIDTH)
            local title = _G.AZSMoreStatsTitle
            if title then
                if extraTitle ~= title then
                    T.SetFont(title, 12)
                    extraTitle = title
                end
                Anchor(title, "TOPLEFT", more, "TOPLEFT", 8, -8)
                SetWidth(title, ROW_WIDTH)
                Justify(title, "LEFT")
            end
            SetHeight(more, math.max(60, LayoutRows(MoreRows(more), 30) + 8))
            if more:IsShown() then y = y + more:GetHeight() + 8 end
        end

        local resistances = CharacterResistanceFrame
        if resistances then
            if resistances:GetParent() ~= content then resistances:SetParent(content) end
            Place(resistances, content, 8, -y, ROW_WIDTH, 34)
            for index = 1, 5 do
                local row = _G["MagicResFrame" .. index]
                if row then Place(row, resistances, (index - 1) * 42, 0) end
            end
            if resistances:IsShown() then y = y + 38 end
        end
        local resized = not T.NearlyEqual(content:GetHeight(), y)
        SetHeight(content, y)
        local nextRange = math.max(0, y - scroll:GetHeight())
        if not T.NearlyEqual(range, nextRange) then
            range = nextRange
            slider:SetMinMaxValues(0, range)
        end
        local value = slider:GetValue()
        if value > range then slider:SetValue(range) end
        SetScroll(slider:GetValue(), resized)
        refreshing = false
    end

    local function CancelStats()
        if not statsQueued then return end
        statsQueued = false
        controller:SetScript("OnUpdate", nil)
    end
    local function FlushStats()
        CancelStats()
        RefreshStats()
    end
    local function QueueStats()
        if statsQueued or not paper:IsVisible() then return end
        statsQueued = true
        controller:SetScript("OnUpdate", FlushStats)
    end

    local function AttachNativeHooks()
        for _, name in ipairs({ "AZS_Update", "AZS_UpdateMore" }) do
            if type(_G[name]) == "function" and _G[name] ~= wrapped[name] then
                hooksecurefunc(name, QueueStats)
                wrapped[name] = _G[name]
            end
        end
    end

    local tabStyles = {
        { "Left", 1, 209, 36, 245, 35, 36, "TOPLEFT", -5 },
        { "Right", 1, 171, 38, 207, 37, 36, "TOPRIGHT", 5 },
        { "LeftDisabled", 1, 127, 36, 169, 35, 42, "TOPLEFT", -4 },
        { "RightDisabled", 1, 83, 38, 125, 37, 42, "TOPRIGHT", 6 },
    }
    local hiddenTabs = { [1] = true, [4] = true, [5] = true }
    local function StyleTab(tab)
        if tab.sduiCharacterTab then return end
        tab.sduiCharacterTab = true
        local name = tab:GetName()
        for _, entry in ipairs(tabStyles) do
            local texture = _G[name .. entry[1]]
            if texture then
                texture:SetTexture(path .. "Tabs.tga")
                texture:SetTexCoord(entry[2] / 64, entry[4] / 64, entry[3] / 256, entry[5] / 256)
                texture:SetWidth(entry[6])
                texture:SetHeight(entry[7])
                texture:ClearAllPoints()
                texture:SetPoint(entry[8], tab, entry[8], entry[9], 0)
            end
        end
        for _, entry in ipairs({ { "", 45, 81, 36 }, { "Disabled", 1, 43, 42 } }) do
            local texture = _G[name .. "Middle" .. entry[1]]
            local l, r = _G[name .. "Left" .. entry[1]], _G[name .. "Right" .. entry[1]]
            if texture and l and r then
                texture:SetTexture(path .. "Tabs.tga")
                texture:SetTexCoord(0, 1 / 64, entry[2] / 256, entry[3] / 256)
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", l, "TOPRIGHT", 0, 0)
                texture:SetPoint("TOPRIGHT", r, "TOPLEFT", 0, 0)
                texture:SetHeight(entry[4])
            end
        end
        local highlight = tab:GetHighlightTexture()
        if highlight then highlight:SetAlpha(0) end
    end

    local function UpdateTabs()
        if tabsUpdating then return end
        tabsUpdating = true
        local x = 12
        for index = 1, 5 do
            local tab = _G["CharacterFrameTab" .. index]
            if tab then
                if hiddenTabs[index] then
                    if tab:IsShown() then tab:Hide() end
                else
                    StyleTab(tab)
                end
                if not hiddenTabs[index] and tab:IsShown() then
                    local text = tab:GetFontString()
                    T.SetFont(text, 11)
                    local width = math.max(72, math.ceil(text:GetStringWidth()) + 30)
                    Place(tab, owner, x, -owner:GetHeight() - 1, width, 32)
                    Anchor(text, "CENTER", tab, "CENTER", 0, owner.selectedTab == index and -2 or 2)
                    x = x + width + 2
                end
            end
        end
        -- Preserve the stock content dimensions on non-character tabs, while
        -- allowing their translated native tab captions to fit underneath.
        SetWidth(owner, paper:IsShown() and math.max(WIDTH, x) or math.max(384, x))
        tabsUpdating = false
    end

    local function HideHeaderContents()
        for _, name in ipairs({
            "CharacterFramePortrait",
            "CharacterGuildText",
            "CharacterTitleText",
        }) do
            local widget = _G[name]
            if widget then
                if widget.Show ~= widget.Hide then widget.Show = widget.Hide end
                if widget:IsShown() then widget:Hide() end
            end
        end
    end

    local nameFrame, nameText, levelText = CharacterNameFrame, CharacterNameText, CharacterLevelText
    if nameFrame and nameText then
        nameFrame:EnableMouse(false)
        for _, name in ipairs({ "CharacterNameText", "CharacterLevelText" }) do
            local text = _G[name]
            if text then
                text:SetParent(nameFrame)
                T.SetFont(text, 12)
                text:SetTextColor(1, 0.82, 0)
                text:SetJustifyH("LEFT")
                text:SetHeight(16)
            end
        end
    end

    HideHeaderContents()
    local headerMetrics = { name = {}, level = {} }
    local function UpdateHeader()
        if not owner:IsVisible() then return end
        HideHeaderContents()
        if not nameFrame or not nameText then return end
        local nameChanged = TextChanged(headerMetrics.name, nameText)
        local levelChanged = levelText and TextChanged(headerMetrics.level, levelText) or false
        local shown, width = paper:IsShown() and true or false, owner:GetWidth()
        if
            not headerMetrics.ready
            or nameChanged
            or levelChanged
            or headerMetrics.paperShown ~= shown
            or not T.NearlyEqual(headerMetrics.width, width)
        then
            SetWidth(nameText, 0)
            local nameWidth = math.ceil(nameText:GetStringWidth() or 0)
            local levelWidth, gap = 0, 0
            if levelText and shown then
                SetWidth(levelText, 0)
                levelWidth = math.ceil(levelText:GetStringWidth() or 0)
                if nameWidth > 0 and levelWidth > 0 then gap = 3 end
            end
            local fit = math.min(1, (width - 72 - gap) / math.max(1, nameWidth + levelWidth))
            headerMetrics.nameWidth, headerMetrics.levelWidth = nameWidth * fit, levelWidth * fit
            headerMetrics.gap, headerMetrics.width, headerMetrics.paperShown = gap, width, shown
            headerMetrics.ready = (headerMetrics.name.text == "" or nameWidth > 0)
                and (not levelText or not shown or headerMetrics.level.text == "" or levelWidth > 0)
        end
        local nameWidth, levelWidth, gap = headerMetrics.nameWidth, headerMetrics.levelWidth, headerMetrics.gap
        SetLevel(nameFrame, owner:GetFrameLevel() + 2)
        Anchor(nameFrame, "TOP", owner, "TOP", -8, -3)
        SetWidth(nameFrame, math.max(1, nameWidth + gap + levelWidth))
        SetHeight(nameFrame, 16)
        Anchor(nameText, "LEFT", nameFrame, "LEFT", 0, 0)
        SetWidth(nameText, nameWidth)
        if levelText then
            Anchor(levelText, "LEFT", nameText, "RIGHT", gap, 0)
            SetWidth(levelText, levelWidth)
            if shown then
                if not levelText:IsShown() then levelText:Show() end
            else
                if levelText:IsShown() then levelText:Hide() end
            end
        end
        if not nameText:IsShown() then nameText:Show() end
        if not nameFrame:IsShown() then nameFrame:Show() end
    end

    local function InsetDefaultPosition()
        if owner:GetNumPoints() ~= 1 then return end
        local point, relative, relativePoint, x, y = owner:GetPoint(1)
        if
            point == "TOPLEFT"
            and (relative == UIParent or relative == "UIParent" or not relative)
            and relativePoint == "TOPLEFT"
            and T.NearlyEqual(x, 0)
            and T.NearlyEqual(y, -104)
        then
            owner:ClearAllPoints()
            owner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", LEFT_INSET, y)
        end
    end

    local function Apply()
        InsetDefaultPosition()
        SetWidth(owner, paper:IsShown() and WIDTH or 384)
        SetHeight(owner, paper:IsShown() and HEIGHT or 512)
        scrollValue = nil
        owner:SetHitRectInsets(0, 0, 0, 0)
        paper:SetHitRectInsets(0, 0, 0, 0)
        HideStockArt(owner)
        for _, name in ipairs(panes) do
            HideStockArt(_G[name])
        end
        local close = CharacterFrameCloseButton
        if close then
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 1, 0)
            close:SetWidth(24)
            close:SetHeight(24)
            for _, entry in ipairs({
                { "Normal", 0, 0 },
                { "Pushed", 64, 0 },
                { "Disabled", 0, 64 },
                { "Highlight", 64, 64 },
            }) do
                close["Set" .. entry[1] .. "Texture"](close, path .. "Close.tga")
                local texture = close["Get" .. entry[1] .. "Texture"](close)
                if texture then
                    texture:SetTexCoord(entry[2] / 128, (entry[2] + 36) / 128, entry[3] / 128, (entry[3] + 38) / 128)
                    texture:ClearAllPoints()
                    texture:SetAllPoints(close)
                    if entry[1] == "Highlight" then texture:SetBlendMode("ADD") end
                end
            end
        end
        UpdateTabs()
        UpdateHeader()
        RefreshQuality()
        AttachNativeHooks()
        QueueStats()
    end

    for _, name in ipairs(panes) do
        local pane = _G[name]
        if pane then HookScript(pane, "OnShow", Apply) end
    end
    for index = 1, 5 do
        local tab = _G["CharacterFrameTab" .. index]
        if tab then
            HookScript(tab, "OnShow", UpdateTabs)
            HookScript(tab, "OnHide", UpdateTabs)
        end
    end
    hooksecurefunc("PanelTemplates_UpdateTabs", function(frame)
        if frame == owner then UpdateTabs() end
    end)
    hooksecurefunc("SetLeftFrame", function(frame)
        if frame == owner then InsetDefaultPosition() end
    end)
    hooksecurefunc("MovePanelToLeft", InsetDefaultPosition)
    hooksecurefunc("PaperDollFrame_SetLevel", UpdateHeader)
    hooksecurefunc("PaperDollItemSlotButton_Update", function()
        if this then UpdateQuality(this) end
    end)
    HookScript(owner, "OnShow", Apply)
    HookScript(owner, "OnEvent", UpdateHeader)
    HookScript(owner, "OnHide", CancelStats)
    HookScript(paper, "OnEvent", QueueStats)
    HookScript(paper, "OnHide", function()
        CancelStats()
        UpdateHeader()
    end)
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        CancelStats()
        slider:SetValue(0)
        for button in pairs(qualityBorders) do
            HideQuality(button)
        end
    end)
    Apply()
end)
