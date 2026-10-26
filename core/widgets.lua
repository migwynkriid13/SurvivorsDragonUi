setfenv(1, DFRL:GetEnv())

function DFRL.tools.StyleMinimapZoomButton(button, name, alignGlyph)
    local path = DFRL:GetInfoOrCons("tex") .. "minimap\\" .. name
    button:SetAlpha(1)
    button:SetNormalTexture(path .. ".blp")
    button:SetDisabledTexture(path .. "-disabled.blp")
    button:SetHighlightTexture(path .. "-over.blp")
    button:SetPushedTexture(path .. "-push.blp")
    if not alignGlyph then return end
    -- The normal plus glyph is two pixels left of the other 32px artwork states.
    local normalOffset = name == "ZoomIn32" and button:GetWidth() * 2 / 32 or 0
    for index, texture in ipairs({
        button:GetNormalTexture(),
        button:GetPushedTexture(),
        button:GetHighlightTexture(),
        button:GetDisabledTexture(),
    }) do
        local x = index == 1 and normalOffset or 0
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", button, "TOPLEFT", x, 0)
        texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", x, 0)
    end
end

function DFRL.tools.CreateDefeatedMarkerCheck(marker, size)
    local check = marker:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetVertexColor(0.2, 1, 0.2, 1)
    check:SetWidth(size * 0.6)
    check:SetHeight(size * 0.6)
    check:SetPoint("BOTTOMRIGHT", marker, "BOTTOMRIGHT", 2, -1)
    check:Hide()
    return check
end

function DFRL.tools.StyleDefeatedMarker(icon, check, size, defeated)
    local iconSize = size * (defeated and 0.8 or 1)
    icon:SetWidth(iconSize)
    icon:SetHeight(iconSize)
    icon:SetAlpha(defeated and 0.7 or 1)
    if defeated then
        check:Show()
    else
        check:Hide()
    end
end

-- Encounter health uses the same fill, label style and native values everywhere.
DFRL.tools.EncounterHealthStyle = { red = 0.86, green = 0.12, blue = 0.1, alpha = 1, fontSize = 12 }

function DFRL.tools.StyleEncounterHealth(bar, label)
    local style = T.EncounterHealthStyle
    bar:SetStatusBarColor(style.red, style.green, style.blue, style.alpha)
    T.SetFont(label, style.fontSize, "OUTLINE")
    label:SetTextColor(1, 1, 1)
end

function DFRL.tools.EncounterHealthText(current, maximum)
    return tostring(math.floor(current)) .. " / " .. tostring(math.floor(maximum))
end

-- Unit health labels share display choices without changing native bar values.
function DFRL.tools.BindUnitHealthText(bar, label, unit, hideDead)
    local percentage = label:GetParent():CreateFontString(nil, "OVERLAY")
    local face, size, flags = label:GetFont()
    percentage:SetFont(face, size, flags)
    percentage:SetTextColor(1, 1, 1)
    local labels = { percentage = percentage }
    local leftInset, rightInset, centerOffset = 0, 0, 0
    local splitLayout

    function labels.Update()
        local current, maximum
        if UnitExists(unit) and not (hideDead and (UnitIsDead(unit) or UnitIsGhost(unit))) then
            current = UnitHealth(unit)
            if type(current) ~= "number" or current < 0 or current - current ~= 0 then current = nil end
            if current and DFRL.display.Get("showHealthPercentage") then maximum = UnitHealthMax(unit) end
        end
        local valueText = current and DFRL.display.Get("showHealthValue") and tostring(current) or ""
        local percentText = ""
        if current and type(maximum) == "number" and maximum > 0 and maximum - maximum == 0 then
            percentText = tostring(math.floor(math.min(1, current / maximum) * 100 + 0.5)) .. "%"
        end
        local split = valueText ~= "" and percentText ~= ""
        if split ~= splitLayout then
            splitLayout = split
            label:ClearAllPoints()
            percentage:ClearAllPoints()
            if split then
                label:SetPoint("LEFT", bar, "LEFT", leftInset + 4, 0)
                label:SetJustifyH("LEFT")
                percentage:SetPoint("RIGHT", bar, "RIGHT", -rightInset - 4, 0)
                percentage:SetJustifyH("RIGHT")
            else
                label:SetPoint("CENTER", bar, "CENTER", centerOffset, 0)
                label:SetJustifyH("CENTER")
                percentage:SetPoint("CENTER", bar, "CENTER", centerOffset, 0)
                percentage:SetJustifyH("CENTER")
            end
        end
        T.SetTextIfChanged(label, valueText)
        T.SetTextIfChanged(percentage, percentText)
    end

    function labels.SetInsets(left, right, center)
        if left == leftInset and right == rightInset and center == centerOffset then return end
        leftInset, rightInset, centerOffset = left, right, center
        splitLayout = nil
        labels.Update()
    end

    DFRL.display.Listen(labels.Update)
    labels.Update()
    return labels
end

-- Keep native caption text and Show/Hide decisions; mask only its effective alpha.
function DFRL.tools.BindUnitLabelVisibility(label, key)
    if not label then return end
    local setAlpha, nativeAlpha = label.SetAlpha, label:GetAlpha()
    local function Update()
        local alpha = DFRL.display.Get(key) and nativeAlpha or 0
        if not T.NearlyEqual(label:GetAlpha(), alpha) then setAlpha(label, alpha) end
    end
    label.SetAlpha = function(self, alpha)
        nativeAlpha = alpha
        return setAlpha(self, DFRL.display.Get(key) and alpha or 0)
    end
    DFRL.display.Listen(Update)
    Update()
end

function DFRL.tools.GradientLine(frame)
    local width = (frame:GetWidth() - 10) / 2
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        texture:SetPoint("TOP", frame, "TOP", 0, -2)
        texture:SetPoint(side == "LEFT" and "RIGHT" or "LEFT", frame, "TOP", 0, -2)
        texture:SetWidth(width)
        texture:SetHeight(3)
        if side == "LEFT" then
            texture:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0, 1, 0.82, 0, 1)
        else
            texture:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 1, 1, 0.82, 0, 0)
        end
    end
end

function DFRL.tools.CreateDFRLFrame(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    DFRL.tools.GradientLine(frame)
    return frame
end

function DFRL.tools.CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    button:SetBackdropColor(0, 0, 0, 0.5)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local label = button:CreateFontString(nil, "OVERLAY")
    DFRL.locale.Bind(label)
    T.SetFont(label, 12, "OUTLINE")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetTextColor(1, 1, 1)
    label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -4)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 4)
    highlight:SetBlendMode("ADD")
    return button
end

-- The prepared interior leaves native StatusBar UVs free to track health.
-- The large health fill and its damage-loss overlay share the same artwork.
DFRL.tools.LargeHealthFill = {
    texture = DFRL:GetInfoOrCons("tex") .. "unitframes\\healthDF2Fill.blp",
    texCoords = { 0, 1, 0, 1 },
    underlap = 1,
}
DFRL.tools.UnitPortraitOverlap = 15

local function CreatePortraitRim(parent, owner, path, mirrored, r, g, b, blendMode)
    local artwork = CreateFrame("Frame", nil, parent)
    artwork:SetAllPoints(owner)
    artwork:EnableMouse(false)
    local regions = {}
    -- The circular sheet retains the old divider at x152..154, y52..55.
    -- Omit that stub only; the half-texel margin keeps it out of filtering.
    for _, piece in ipairs({ { 0, 51.5, 104 }, { 51.5, 4, 101.5 }, { 55.5, 72.5, 104 } }) do
        local y, height, width = unpack(piece)
        local texture = artwork:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(path)
        if mirrored then
            texture:SetTexCoord(1, (256 - width) / 256, y / 128, (y + height) / 128)
            texture:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, -y)
        else
            texture:SetTexCoord((256 - width) / 256, 1, y / 128, (y + height) / 128)
            texture:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, -y)
        end
        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetVertexColor(r or 1, g or 1, b or 1)
        if blendMode then texture:SetBlendMode(blendMode) end
        table.insert(regions, texture)
    end
    return artwork, regions
end

function DFRL.tools.CreateRoundPlayerRim(parent, owner, r, g, b, blendMode)
    local path = DFRL:GetInfoOrCons("tex") .. "unitframes\\UI-TargetingFrameDF1.blp"
    local artwork = CreatePortraitRim(parent, owner, path, true, r, g, b, blendMode)
    return artwork
end

-- Close both ends with the existing straight metal edge, without the portrait ring.
function DFRL.tools.CreatePortraitlessBorder(parent, healthBar, height, underlap)
    underlap = underlap or 0
    local border = CreateFrame("Frame", nil, parent)
    border:SetFrameLevel(healthBar:GetFrameLevel() + 2)
    border:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -6 + underlap, 5 - underlap)
    border:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 6 - underlap, 5 - underlap)
    border:SetHeight(height + 9)
    border:EnableMouse(false)
    local path = DFRL:GetInfoOrCons("tex") .. "unitframes\\UI-TargetingFrameDF1.blp"
    local function Piece(x, y, width, pieceHeight, mirrored)
        local texture = border:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(path)
        texture:SetTexCoord(
            (mirrored and x + width or x) / 256,
            (mirrored and x or x + width) / 256,
            y / 128,
            (y + pieceHeight) / 128
        )
        texture:SetWidth(width)
        texture:SetHeight(pieceHeight)
        return texture
    end
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local mirrored = side == "RIGHT"
        local top = Piece(24, 29, 8, 5, mirrored)
        top:SetPoint("TOP" .. side, border, "TOP" .. side, 0, 0)
        local bottom = Piece(24, 63, 8, 4, mirrored)
        bottom:SetPoint("BOTTOM" .. side, border, "BOTTOM" .. side, 0, 0)
        -- Stretch only the uninterrupted side edge; the original lower span
        -- includes the old resource divider's inward-facing stub.
        local middle = Piece(24, 35, 8, 14, mirrored)
        middle:SetPoint("TOP" .. side, top, "BOTTOM" .. side, 0, 0)
        middle:SetPoint("BOTTOM" .. side, bottom, "TOP" .. side, 0, 0)
    end
    local top = Piece(32, 29, 104, 5)
    top:SetPoint("TOPLEFT", border, "TOPLEFT", 8, 0)
    top:SetPoint("TOPRIGHT", border, "TOPRIGHT", -8, 0)
    local bottom = Piece(32, 63, 104, 4)
    bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 8, 0)
    bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -8, 0)
    border:Hide()
    return border
end

-- Reuse the original 256x128 portrait sheet. The full health opening remains
-- the default; the player can restore its original health/power divider.
function DFRL.tools.CreateUnitBorder(frame, healthBar, portraitTexture, background, texturePath, portraitSide)
    local mirrored = portraitSide == "LEFT"
    local healthFill = DFRL.tools.LargeHealthFill
    local underlap = healthFill.underlap
    local healthWidth, healthTop, portraitInset, portraitOverlap = 122, 34, 104, T.UnitPortraitOverlap
    local dividerTop, dividerHeight = 51.5, 4
    local powerDivider, roundRim
    local strips = {}
    local portraitExtended
    local function SetPortraitOverlap(extended)
        -- The pointed player rim also needs a small underlap to close its seam.
        portraitExtended = extended
        local extension = 0
        if not DFRL.display.Get("hidePortraits") then
            extension = extended and portraitOverlap or (mirrored and 2 or 0)
        end
        healthBar:SetWidth(healthWidth + extension + 2 * underlap)
        healthBar:ClearAllPoints()
        if mirrored then
            healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitInset - extension - underlap, -healthTop + underlap)
        else
            healthBar:SetPoint(
                "TOPRIGHT",
                frame,
                "TOPRIGHT",
                -(portraitInset - extension) + underlap,
                -healthTop + underlap
            )
        end
        if powerDivider then
            powerDivider:SetWidth(healthBar:GetWidth() - 2 * underlap)
            powerDivider:ClearAllPoints()
            powerDivider:SetPoint("TOPLEFT", healthBar, "TOPLEFT", underlap, healthTop - dividerTop - underlap)
        end
        if roundRim then
            if extended then
                portraitTexture:SetAlpha(0)
                roundRim:Show()
            else
                portraitTexture:SetAlpha(1)
                roundRim:Hide()
            end
        end
        return extension
    end
    -- Padding is removed in the prepared artwork; native fill coordinates
    -- must remain untouched so health changes crop and size the bar together.
    healthBar:SetStatusBarTexture(healthFill.texture)
    -- Bleed beneath the existing inner outline; keep the content center fixed.
    healthBar:SetHeight(29 + 2 * underlap)
    healthBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    -- The target always overlaps its circular edge; the player opts in below.
    SetPortraitOverlap(not mirrored)

    if not background then background = frame:CreateTexture(nil, "BACKGROUND") end
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetTexCoord(0, 1, 0, 1)
    background:SetVertexColor(0, 0, 0, 0.6)
    background:ClearAllPoints()
    background:SetAllPoints(healthBar)
    background:SetDrawLayer("BACKGROUND")

    local borderFrame = CreateFrame("Frame", nil, frame)
    borderFrame:SetFrameLevel(healthBar:GetFrameLevel() + 2)
    borderFrame:SetAllPoints(frame)

    if not portraitTexture then portraitTexture = frame:CreateTexture(nil, "OVERLAY") end
    -- Keep stills, independent model copies and the rim above an overlapping fill.
    portraitTexture:SetParent(borderFrame)
    if frame.portrait then
        frame.portrait:SetParent(borderFrame)
        frame.portrait:SetDrawLayer("ARTWORK")
    end
    if frame.sduiPortraitModel then frame.sduiPortraitModel:SetFrameLevel(borderFrame:GetFrameLevel()) end
    -- The pointed rim starts at source x153. Its former x152 divider and
    -- the neighboring filtered pixels must not cover the health opening.
    local portraitWidth = mirrored and 102.5 or 104
    portraitTexture:SetWidth(portraitWidth)
    portraitTexture:SetHeight(128)
    portraitTexture:ClearAllPoints()
    if mirrored then
        portraitTexture:SetTexCoord(1, (256 - portraitWidth) / 256, 0, 1)
        portraitTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    else
        portraitTexture:SetTexCoord(152 / 256, 1, 0, 1)
        portraitTexture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    end
    portraitTexture:SetVertexColor(1, 1, 1, 1)
    portraitTexture:SetDrawLayer("OVERLAY")
    if mirrored then
        roundRim = DFRL.tools.CreateRoundPlayerRim(borderFrame, frame)
        roundRim:Hide()
    else
        local targetRim, regions = CreatePortraitRim(borderFrame, frame, texturePath, false)
        targetRim:Show()
        for _, region in ipairs(regions) do
            table.insert(strips, region)
        end
        portraitTexture:SetAlpha(0)
    end

    local function AddStrip(x, y, width, height, sourceY)
        sourceY = sourceY or y
        local strip = borderFrame:CreateTexture(nil, "OVERLAY")
        strip:SetWidth(width)
        strip:SetHeight(height)
        if mirrored then
            strip:SetTexCoord((x + width) / 256, x / 256, sourceY / 128, (sourceY + height) / 128)
            strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 256 - x - width, -y)
        else
            strip:SetTexCoord(x / 256, (x + width) / 256, sourceY / 128, (sourceY + height) / 128)
            strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(256 - x - width), -y)
        end
        table.insert(strips, strip)
        return strip
    end
    -- Retain the corner contour through x32. Replace only the former divider
    -- rows with a clean neighboring side-edge sample while resources are off.
    AddStrip(0, 0, 152, 34)
    AddStrip(0, 63, 152, 65)
    AddStrip(0, healthTop, 33, dividerTop - healthTop)
    local cleanEndCap = AddStrip(0, dividerTop, 33, dividerHeight, dividerTop - dividerHeight)
    AddStrip(0, dividerTop + dividerHeight, 33, healthTop + 29 - dividerTop - dividerHeight)

    local powerEndCap
    if mirrored then
        powerEndCap = AddStrip(0, dividerTop, 30, dividerHeight)
        powerEndCap:Hide()
        -- The shared end cap owns the corners in both modes; sample only the
        -- divider here so enabling resources cannot paint those corners twice.
        powerDivider = AddStrip(30, dividerTop, healthWidth, dividerHeight)
        powerDivider:Hide()
    end

    local powerShown = false
    local function SetPowerShown(shown)
        if not powerDivider or shown == powerShown then return end
        powerShown = shown
        if shown then
            healthBar:SetHeight(19 + 2 * underlap)
            cleanEndCap:Hide()
            powerEndCap:Show()
            powerDivider:Show()
        else
            healthBar:SetHeight(29 + 2 * underlap)
            powerEndCap:Hide()
            cleanEndCap:Show()
            powerDivider:Hide()
        end
    end

    local function UpdateTexture(path)
        portraitTexture:SetTexture(path)
        if not mirrored then portraitTexture:SetAlpha(0) end
        for _, strip in ipairs(strips) do
            strip:SetTexture(path)
        end
    end
    UpdateTexture(texturePath)
    local portraitless = DFRL.tools.CreatePortraitlessBorder(frame, healthBar, 29, underlap)
    local portraitsHidden
    local function UpdatePortraitVisibility()
        local hidden = DFRL.display.Get("hidePortraits")
        if hidden == portraitsHidden then return end
        portraitsHidden = hidden
        SetPortraitOverlap(portraitExtended)
        borderFrame:SetAlpha(hidden and 0 or 1)
        if hidden then
            portraitless:Show()
        else
            portraitless:Hide()
        end
    end
    DFRL.display.Listen(UpdatePortraitVisibility)
    UpdatePortraitVisibility()
    return UpdateTexture, SetPowerShown, SetPortraitOverlap
end
