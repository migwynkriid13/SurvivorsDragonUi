setfenv(1, DFRL:GetEnv())

-- One native-circle compatibility path for pet and meter image textures.
-- The caller retains its portrait geometry, rim, metadata and visibility policy.
function DFRL.tools.NewCircularIcon(portrait, size, minimumParts)
    local image, strips = {}, {}
    local parent, radius = portrait:GetParent(), size / 2
    local iconPath, native, failedIcon, scale, used
    local function ClearStrips()
        for _, strip in ipairs(strips) do
            if strip.boundTexture then strip:SetTexture(nil) end
            strip.boundTexture = nil
            if strip:IsShown() then strip:Hide() end
        end
    end
    local function ClearPortrait()
        if portrait:GetTexture() then portrait:SetTexture(nil) end
        if portrait:IsShown() then portrait:Hide() end
        native = false
    end
    function image.Clear()
        ClearPortrait()
        ClearStrips()
        iconPath, failedIcon = nil, nil
    end
    local function BindPortrait(icon)
        _G.SetPortraitToTexture(portrait:GetName(), icon)
        local assigned = portrait:GetTexture()
        return assigned == icon or assigned == string.gsub(icon, "%.[^%.]*$", "")
    end
    function image.Bind(icon, effectiveScale)
        if not icon then
            image.Clear()
            return false
        end
        if native and iconPath == icon then return true end
        effectiveScale = effectiveScale or parent:GetEffectiveScale()
        if type(effectiveScale) ~= "number" or effectiveScale - effectiveScale ~= 0 or effectiveScale <= 0 then
            image.Clear()
            return false
        end
        if iconPath == icon and T.NearlyEqual(scale, effectiveScale) then return true end
        if failedIcon ~= icon and type(_G.SetPortraitToTexture) == "function" then
            local ok, bound = pcall(BindPortrait, icon)
            if ok and bound then
                ClearStrips()
                if not portrait:IsShown() then portrait:Show() end
                iconPath, native, failedIcon = icon, true, nil
                return true
            end
            failedIcon = icon
        end
        ClearPortrait()
        iconPath = nil
        if not T.NearlyEqual(scale, effectiveScale) then
            local parts = math.max(minimumParts or 2, math.ceil(size * effectiveScale))
            local step = size / parts
            used = 0
            for part = 1, parts do
                local top, bottom = (part - 1) * step, part * step
                local edge = math.max(math.abs(top - radius), math.abs(bottom - radius))
                local half = math.sqrt(math.max(0, radius * radius - edge * edge))
                if half > 0 then
                    used = used + 1
                    local strip = strips[used]
                    if not strip then
                        strip = parent:CreateTexture(nil, "ARTWORK")
                        strip:Hide()
                        strips[used] = strip
                    end
                    strip:ClearAllPoints()
                    strip:SetPoint("TOPLEFT", portrait, "TOPLEFT", radius - half, -top)
                    strip:SetWidth(half * 2)
                    strip:SetHeight(step)
                    strip:SetTexCoord((radius - half) / size, (radius + half) / size, top / size, bottom / size)
                end
            end
            scale = effectiveScale
        end
        local usable = true
        local stem = string.gsub(icon, "%.[^%.]*$", "")
        for index, strip in ipairs(strips) do
            if index <= used then
                if strip.boundTexture ~= icon then
                    strip.boundTexture = nil
                    local loaded = strip:SetTexture(icon)
                    local assigned = strip:GetTexture()
                    if loaded ~= false and (loaded == true or loaded == 1 or assigned == icon or assigned == stem) then
                        strip.boundTexture = icon
                    else
                        strip:SetTexture(nil)
                    end
                end
                if not strip.boundTexture then usable = false end
            else
                if strip.boundTexture then strip:SetTexture(nil) end
                strip.boundTexture = nil
                if strip:IsShown() then strip:Hide() end
            end
        end
        for index = 1, used do
            local strip = strips[index]
            if usable then
                if not strip:IsShown() then strip:Show() end
            elseif strip:IsShown() then
                strip:Hide()
            end
        end
        if usable then iconPath = icon end
        return usable
    end
    return image
end

function DFRL.tools.StyleMinimapZoomButton(button, name)
    local path = DFRL:GetInfoOrCons("tex") .. "minimap\\" .. name
    button:SetAlpha(1)
    button:SetNormalTexture(path .. ".blp")
    button:SetDisabledTexture(path .. "-disabled.blp")
    button:SetHighlightTexture(path .. "-over.blp")
    button:SetPushedTexture(path .. "-push.blp")
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

function DFRL.tools.EncounterHealthText(current, maximum, showCurrent, showMaximum, cache, shorten, showPercentage)
    shorten = shorten ~= false
    local percentage
    if showPercentage == true then
        if cache and cache.encounterPercentCurrent == current and cache.encounterPercentMaximum == maximum then
            percentage = cache.encounterPercentage
        elseif
            type(current) == "number"
            and current >= 0
            and current - current == 0
            and type(maximum) == "number"
            and maximum > 0
            and maximum - maximum == 0
        then
            percentage = math.floor(math.max(0, math.min(1, current / maximum)) * 100 + 0.5)
        end
    end
    -- Keep only the latest percentage basis, even when rounding keeps the same
    -- caption. Off does no division and releases those optional cache values.
    if cache then
        local percentCurrent = showPercentage == true and current or nil
        local percentMaximum = showPercentage == true and maximum or nil
        if cache.encounterPercentCurrent ~= percentCurrent then cache.encounterPercentCurrent = percentCurrent end
        if cache.encounterPercentMaximum ~= percentMaximum then cache.encounterPercentMaximum = percentMaximum end
    end
    if showCurrent == false then current = nil end
    if showMaximum == false then maximum = nil end
    if
        cache
        and cache.encounterText ~= nil
        and cache.encounterCurrent == current
        and cache.encounterMaximum == maximum
        and cache.encounterShortHealth == shorten
        and cache.encounterPercentage == percentage
    then
        return cache.encounterText
    end
    local text = current and T.CompactHealth(current, shorten) or ""
    if maximum then text = text .. (current and " / " or "") .. T.CompactHealth(maximum, shorten) end
    if percentage then text = text .. (text ~= "" and " (" or "") .. percentage .. "%" .. (text ~= "" and ")" or "") end
    if cache then
        cache.encounterCurrent, cache.encounterMaximum, cache.encounterText = current, maximum, text
        cache.encounterShortHealth = shorten
        cache.encounterPercentage = percentage
    end
    return text
end

function DFRL.tools.SetEncounterHealthText(label, current, maximum, showCurrent, showMaximum, shorten, showPercentage)
    local text = T.EncounterHealthText(current, maximum, showCurrent, showMaximum, label, shorten, showPercentage)
    T.SetTextIfChanged(label, text)
    if text == "" then
        if label:IsShown() then label:Hide() end
    elseif not label:IsShown() then
        label:Show()
    end
end

-- Retail-style decimal tiers; presentation only, never a health calculation.
function DFRL.tools.CompactHealth(value, shorten)
    if shorten == false or value < 1000 then return string.format("%.0f", math.floor(value)) end
    local divisor, suffix
    if value >= 1000000000000 then
        divisor, suffix = 1000000000000, "T"
    elseif value >= 1000000000 then
        divisor, suffix = 1000000000, "B"
    elseif value >= 1000000 then
        divisor, suffix = 1000000, "M"
    else
        divisor, suffix = 1000, "K"
    end
    local scaled = math.floor(value / (divisor / 10)) / 10
    return string.format(scaled == math.floor(scaled) and "%.0f" or "%.1f", scaled) .. suffix
end

function DFRL.tools.GetUnitHealth(unit, currentOnly)
    if unit == "target" and DFRL.targetHealth then return DFRL.targetHealth.Get() end
    if currentOnly then return UnitHealth(unit) end
    return UnitHealth(unit), UnitHealthMax(unit)
end

-- Preserve the effective class-health choice when native updates recolor a bar.
function DFRL.tools.BindClassHealthColor(bar, unit)
    local healthR, healthG, healthB = 0, 1, 0
    local setColor = bar.SetStatusBarColor
    local function Apply()
        if not bar:IsVisible() then return end
        local red, green, blue, alpha = bar:GetStatusBarColor()
        if
            not T.NearlyEqual(red, healthR)
            or not T.NearlyEqual(green, healthG)
            or not T.NearlyEqual(blue, healthB)
            or (alpha and not T.NearlyEqual(alpha, 1))
        then
            setColor(bar, healthR, healthG, healthB)
        end
    end
    bar.SetStatusBarColor = Apply
    local function Update()
        local color
        if DFRL.display.Get("classHealth") then color = T.GetUnitClassColor(unit) end
        if color then
            healthR, healthG, healthB = unpack(color)
        else
            healthR, healthG, healthB = 0, 1, 0
        end
        Apply()
    end
    DFRL.display.Listen(Update)
    return Update
end

-- Unit health labels and loss fractions share the target's accepted health source.
function DFRL.tools.BindUnitHealthText(bar, label, unit, hideDead)
    local percentage = label:GetParent():CreateFontString(nil, "OVERLAY")
    local _, size, flags = label:GetFont()
    T.SetFont(percentage, size, flags)
    percentage:SetTextColor(1, 1, 1)
    local labels = { percentage = percentage }
    local leftInset, rightInset, centerOffset = 0, 0, 0
    local splitLayout
    local previousCurrent, previousMaximum, previousValueShown, previousPercentShown, previousShortHealth
    local absorbValue, absorbMaximum, previousAbsorb, previousAbsorbMaximum, absorbPending
    local absorbText, absorbPercentText = "", ""
    local valueText, percentText = "", ""

    function labels.Update()
        if not bar:IsVisible() then return end
        local current, maximum
        local valueShown = DFRL.display.Get("showHealthValue")
        local percentShown = DFRL.display.Get("showHealthPercentage")
        local shorten = DFRL.display.Get("unitShortHealth") ~= false
        if UnitExists(unit) and not (hideDead and (UnitIsDead(unit) or UnitIsGhost(unit))) then
            current, maximum = T.GetUnitHealth(unit, not percentShown)
            if type(current) ~= "number" or current < 0 or current - current ~= 0 then current = nil end
        end
        if
            current ~= previousCurrent
            or maximum ~= previousMaximum
            or valueShown ~= previousValueShown
            or percentShown ~= previousPercentShown
            or shorten ~= previousShortHealth
            or absorbValue ~= previousAbsorb
            or absorbMaximum ~= previousAbsorbMaximum
        then
            if
                absorbValue ~= previousAbsorb
                or absorbMaximum ~= previousAbsorbMaximum
                or valueShown ~= previousValueShown
                or percentShown ~= previousPercentShown
                or shorten ~= previousShortHealth
            then
                absorbText, absorbPercentText = "", ""
                if absorbValue then
                    if valueShown then absorbText = "|cffA6D9FF+" .. T.CompactHealth(absorbValue, shorten) .. "|r" end
                    if percentShown then
                        -- Shield capacity is not published. Express current absorb
                        -- against the accepted maximum HP, without the bar's cap.
                        local percent = absorbValue / absorbMaximum * 100
                        if percent - percent == 0 then
                            absorbPercentText = "|cffA6D9FF+"
                                .. string.format("%.0f", math.floor(percent + 0.5))
                                .. "%|r"
                        end
                    end
                end
            end
            previousCurrent, previousMaximum = current, maximum
            previousValueShown, previousPercentShown = valueShown, percentShown
            previousShortHealth = shorten
            previousAbsorb, previousAbsorbMaximum = absorbValue, absorbMaximum
            valueText = current and valueShown and T.CompactHealth(current, shorten) or ""
            percentText = ""
            if current and percentShown and type(maximum) == "number" and maximum > 0 and maximum - maximum == 0 then
                percentText = tostring(math.floor(math.min(1, current / maximum) * 100 + 0.5)) .. "%"
            end
            if current and current > 0 and absorbValue then
                if absorbText ~= "" then valueText = valueText .. " " .. absorbText end
                if absorbPercentText ~= "" then
                    percentText = percentText .. (percentText ~= "" and " " or "") .. absorbPercentText
                end
            end
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
        absorbPending = nil
    end

    function labels.SetAbsorb(value, maximum)
        if
            unit ~= "player"
            or type(value) ~= "number"
            or value <= 0
            or value - value ~= 0
            or type(maximum) ~= "number"
            or maximum <= 0
            or maximum - maximum ~= 0
        then
            value, maximum = nil, nil
        end
        if value == absorbValue and maximum == absorbMaximum and not absorbPending then return end
        absorbValue, absorbMaximum, absorbPending = value, maximum, true
        labels.Update()
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
DFRL.tools.TargetHealthPortraitInset = 8

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
-- Nonzero-alpha bounds in the unchanged 256x128 unit sheets. Keep transparent
-- canvas padding out of editing without changing the native unit/click owner.
local unitBorderBounds = {
    ["UI-TargetingFrameDF.blp"] = { 21, 4, 222, 78 },
    ["UI-TargetingFrameDF1.blp"] = { 23, 11, 218, 75 },
    ["UI-TargetingFrame-Boss.blp"] = { 23, 1, 245, 81 },
    ["UI-TargetingFrame-Elite.blp"] = { 23, 1, 227, 81 },
    ["UI-TargetingFrame-RareElite.blp"] = { 23, 0, 245, 82 },
    ["UI-TargetingFrame-Rare.blp"] = { 23, 0, 227, 82 },
}
local fullUnitBorderBounds = { 0, 0, 256, 128 }
local function UnitCaptionHeight(label)
    local height = label:GetHeight()
    if type(height) == "number" and height > 0 then return height end
    local _, size = label:GetFont()
    return type(size) == "number" and size > 0 and size or 11
end
local function UnitRelativeBounds(child, left, top, scale)
    if not left or not top or not scale or scale <= 0 then return end
    local x1, x2, y1, y2 = child:GetLeft(), child:GetRight(), child:GetTop(), child:GetBottom()
    local childScale = child:GetEffectiveScale()
    if not x1 or not x2 or not y1 or not y2 or not childScale or childScale <= 0 then return end
    local ratio = childScale / scale
    return x1 * ratio - left, top - y1 * ratio, x2 * ratio - left, top - y2 * ratio
end
local function UnitPoint(region, point, owner, x, y)
    local current, relative, relativePoint, oldX, oldY = region:GetPoint(1)
    if
        region:GetNumPoints() == 1
        and current == point
        and (relative == owner or relative == owner:GetName())
        and relativePoint == point
        and T.NearlyEqual(oldX, x)
        and T.NearlyEqual(oldY, y)
    then
        return
    end
    region:ClearAllPoints()
    region:SetPoint(point, owner, point, x, y)
end

function DFRL.tools.CreateUnitBorder(frame, healthBar, portraitTexture, background, texturePath, portraitSide)
    local mirrored = portraitSide == "LEFT"
    local healthFill = DFRL.tools.LargeHealthFill
    local underlap = healthFill.underlap
    local healthWidth, healthTop, portraitInset = 122, 34, 104
    local portraitOverlap = T.UnitPortraitOverlap - (mirrored and 0 or T.TargetHealthPortraitInset)
    local defaultWidth, widthDelta = frame:GetWidth(), 0
    local dividerTop, dividerHeight = 51.5, 4
    local powerDivider, roundRim
    local RefreshEditRegion
    local strips = {}
    local widthPieces = {}
    local portraitPoints = {}
    if not mirrored and frame.portrait then
        for index = 1, frame.portrait:GetNumPoints() do
            local point, relative, relativePoint, x, y = frame.portrait:GetPoint(index)
            if relative == frame or relative == frame:GetName() then
                relativePoint = relativePoint or point
                local factor = string.find(relativePoint, "RIGHT") and 0
                    or (string.find(relativePoint, "LEFT") and 1 or 0.5)
                if factor > 0 then table.insert(portraitPoints, { point, relativePoint, x or 0, y or 0, factor }) end
            end
        end
    end
    local portraitExtended
    local function SetPortraitOverlap(extended)
        -- The pointed player rim also needs a small underlap to close its seam.
        portraitExtended = extended
        local extension = 0
        if not DFRL.display.Get("hidePortraits") then
            extension = extended and portraitOverlap or (mirrored and 2 or 0)
        end
        local width = healthWidth + widthDelta + extension + 2 * underlap
        if not T.NearlyEqual(healthBar:GetWidth(), width) then healthBar:SetWidth(width) end
        if mirrored then
            UnitPoint(healthBar, "TOPLEFT", frame, portraitInset - extension - underlap, -healthTop + underlap)
        else
            UnitPoint(healthBar, "TOPRIGHT", frame, -(portraitInset - extension) + underlap, -healthTop + underlap)
        end
        if powerDivider then
            local dividerWidth = healthBar:GetWidth() - 2 * underlap
            if not T.NearlyEqual(powerDivider:GetWidth(), dividerWidth) then powerDivider:SetWidth(dividerWidth) end
            UnitPoint(powerDivider, "TOPLEFT", healthBar, underlap, healthTop - dividerTop - underlap)
        end
        if roundRim then
            if extended then
                if portraitTexture:IsShown() then portraitTexture:Hide() end
                if not roundRim:IsShown() then roundRim:Show() end
            else
                if not portraitTexture:IsShown() then portraitTexture:Show() end
                if roundRim:IsShown() then roundRim:Hide() end
            end
        end
        if RefreshEditRegion then RefreshEditRegion() end
        return extension
    end
    -- Padding is removed in the prepared artwork; native fill coordinates
    -- must remain untouched so health changes crop and size the bar together.
    healthBar:SetStatusBarTexture(healthFill.texture)
    -- Bleed beneath the existing inner outline; keep the content center fixed.
    healthBar:SetHeight(29 + 2 * underlap)
    healthBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    -- Keep a smaller target overlap beneath the rim; the player opts in below.
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
        portraitTexture:Hide()
    end

    local function AddStrip(x, y, width, height, sourceY, stretch)
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
        if stretch ~= "divider" then
            table.insert(
                widthPieces,
                { texture = strip, x = 256 - x - width, y = -y, width = width, stretch = stretch }
            )
        end
        return strip
    end
    -- Retain the corner contour through x32. Replace only the former divider
    -- rows with a clean neighboring side-edge sample while resources are off.
    -- Keep the outer cap and portrait at native size; only straight spans stretch.
    AddStrip(0, 0, 33, 34)
    AddStrip(33, 0, 119, 34, nil, true)
    AddStrip(0, 63, 33, 65)
    AddStrip(33, 63, 119, 65, nil, true)
    AddStrip(0, healthTop, 33, dividerTop - healthTop)
    local cleanEndCap = AddStrip(0, dividerTop, 33, dividerHeight, dividerTop - dividerHeight)
    AddStrip(0, dividerTop + dividerHeight, 33, healthTop + 29 - dividerTop - dividerHeight)

    local powerEndCap
    if mirrored then
        powerEndCap = AddStrip(0, dividerTop, 30, dividerHeight)
        powerEndCap:Hide()
        -- The shared end cap owns the corners in both modes; sample only the
        -- divider here so enabling resources cannot paint those corners twice.
        powerDivider = AddStrip(30, dividerTop, healthWidth, dividerHeight, nil, "divider")
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

    local portraitless = DFRL.tools.CreatePortraitlessBorder(frame, healthBar, 29, underlap)
    local editRegion = CreateFrame("Frame", nil, frame)
    editRegion:EnableMouse(false)
    local artworkBounds = fullUnitBorderBounds
    RefreshEditRegion = function()
        local top = healthTop - 5
        local nameKey = mirrored and "showPlayerName" or "showTargetName"
        local levelKey = mirrored and "showPlayerLevel" or "showTargetLevel"
        if DFRL.display.Get(nameKey) and frame.name then
            local height = UnitCaptionHeight(frame.name)
            top = math.min(top, mirrored and healthTop - 4 - height or frame:GetHeight() / 2 - 25 - height / 2)
        end
        local level = mirrored and PlayerLevelText or TargetLevelText
        if DFRL.display.Get(levelKey) and level then
            top = math.min(top, frame:GetHeight() / 2 - 25 - UnitCaptionHeight(level) / 2)
        end
        local hidden = DFRL.display.Get("hidePortraits")
        local left, right, bottom
        if hidden then
            left = mirrored and portraitInset - 6 or defaultWidth - portraitInset - healthWidth - 6
            right, bottom = left + healthWidth + widthDelta + 12, healthTop + 33
        else
            left = mirrored and 256 - artworkBounds[3] or defaultWidth - 256 + artworkBounds[1]
            right = mirrored and 256 - artworkBounds[1] + widthDelta or frame:GetWidth() - 256 + artworkBounds[3]
            top, bottom = math.min(artworkBounds[2], top), artworkBounds[4]
        end
        local extra = DFRL.layout.IsEditing() and editRegion.includeFrames and editRegion.includeFrames()
        if hidden or extra then
            local originLeft, originTop, scale = frame:GetLeft(), frame:GetTop(), frame:GetEffectiveScale()
            if hidden then
                local x1, y1, x2, y2 = UnitRelativeBounds(portraitless, originLeft, originTop, scale)
                if x1 then
                    left, top, right, bottom = x1, math.min(top, y1), x2, y2
                end
            end
            if extra then
                for _, child in ipairs(extra) do
                    if child:IsShown() and child:GetAlpha() > 0 then
                        local x1, y1, x2, y2 = UnitRelativeBounds(child, originLeft, originTop, scale)
                        if x1 then
                            left, top = math.min(left, x1), math.min(top, y1)
                            right, bottom = math.max(right, x2), math.max(bottom, y2)
                        end
                    end
                end
            end
        end
        if
            T.NearlyEqual(editRegion.left, left)
            and T.NearlyEqual(editRegion.top, top)
            and T.NearlyEqual(editRegion.right, right)
            and T.NearlyEqual(editRegion.bottom, bottom)
        then
            return
        end
        editRegion.left, editRegion.top, editRegion.right, editRegion.bottom = left, top, right, bottom
        editRegion:ClearAllPoints()
        editRegion:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
        editRegion:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", right, -bottom)
    end
    editRegion.Refresh = RefreshEditRegion
    local function UpdateTexture(path)
        portraitTexture:SetTexture(path)
        if not mirrored and portraitTexture:IsShown() then portraitTexture:Hide() end
        for _, strip in ipairs(strips) do
            strip:SetTexture(path)
        end
        local name = string.gsub(path, "^.*[\\/]", "")
        artworkBounds = unitBorderBounds[name] or fullUnitBorderBounds
        RefreshEditRegion()
    end
    UpdateTexture(texturePath)
    local portraitsHidden
    local function UpdatePortraitVisibility()
        local hidden = DFRL.display.Get("hidePortraits")
        if hidden == portraitsHidden then
            RefreshEditRegion()
            return
        end
        portraitsHidden = hidden
        SetPortraitOverlap(portraitExtended)
        if hidden then
            if borderFrame:IsShown() then borderFrame:Hide() end
            if not portraitless:IsShown() then portraitless:Show() end
        else
            if not borderFrame:IsShown() then borderFrame:Show() end
            if portraitless:IsShown() then portraitless:Hide() end
        end
    end
    DFRL.display.Listen(UpdatePortraitVisibility)
    UpdatePortraitVisibility()
    local function ResizeHealth()
        if not frame:IsVisible() and not DFRL.layout.IsEditing() then return false end
        local delta = frame:GetWidth() - defaultWidth
        if T.NearlyEqual(widthDelta, delta) then return false end
        widthDelta = delta
        local extension = SetPortraitOverlap(portraitExtended)
        for _, piece in ipairs(widthPieces) do
            local width = piece.width + (piece.stretch and delta or 0)
            local x = piece.x + (piece.stretch and 0 or delta)
            if not T.NearlyEqual(piece.texture:GetWidth(), width) then piece.texture:SetWidth(width) end
            UnitPoint(piece.texture, mirrored and "TOPLEFT" or "TOPRIGHT", frame, mirrored and x or -x, piece.y)
        end
        for _, point in ipairs(portraitPoints) do
            frame.portrait:SetPoint(point[1], frame, point[2], point[3] + delta * point[5], point[4])
        end
        return true, extension
    end
    return UpdateTexture, SetPowerShown, SetPortraitOverlap, ResizeHealth, editRegion
end
