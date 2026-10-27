-- Five equipped jewelry sockets, attached by default and optionally independent.
--[[
The selected thin-bezel design keeps the Blizzard circular rim artwork, with
native rarity colors for equipped items and the original gold for empty slots.
SocketRail.blp joins all upper socket arches and straight spans in one texture
using pixels from the existing HDActionBar.tga. The original bar texture is
unchanged; only its narrow top strip switches while this jewelry row is visible.
No extra inner or lower curved line is drawn beneath the gold circles.
SocketDetached.blp retains the silver-gray circle borders in detached mode.
EmptyNeck.blp, EmptyRing.blp and EmptyTrinket.blp use Blizzard's original
paper-doll placeholders, fitted inside the circular rim without cropping.
Texture conversion does not change the underlying artwork's ownership.
No upstream Lua is imported. Sources and preparation: third_party/Jewelry-ARTWORK.md.

Gold circular rim source: commit b8b35451d4621a8097e887385f72ec03e17765f1,
Textures/bagborder2.blp; provenance is recorded in the document above.
Empty-slot artwork: Gethe/wow-ui-textures, commit
e80e3278cc833c89e1f3fc79557b68315d750935, PaperDoll/UI-PaperDoll-Slot-
Finger.PNG, -Neck.PNG and -Trinket.PNG. World of Warcraft artwork remains
copyright Blizzard Entertainment, distinct from the software license below.
The transparent circular cooldown atlas is original generated geometry.

Applicable source notices (Blizzard artwork is distinct from MIT software):
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
DFRL:NewMod("Jewelry", 4, function()
    local WIDTH, HEIGHT, ICON_SIZE, INTERVAL = 317, 88, 32, 0.2
    local RIM_SIZE = 43
    local ICON_ZOOM = 1.05
    local iconSpan = 1 / ICON_ZOOM
    local iconInset = (1 - iconSpan) / 2
    local actionDefaults = DFRL.actionBarDefaults
    if
        type(actionDefaults) ~= "table"
        or type(actionDefaults.buttonWidth) ~= "number"
        or actionDefaults.buttonWidth <= 0
        or type(actionDefaults.buttonGap) ~= "number"
        or actionDefaults.buttonGap < 0
    then
        return
    end
    -- Use one ability's width as the scale reference and match button spacing.
    -- The five jewelry slots then span action buttons 2 through 6 exactly.
    local defaultScale = actionDefaults.buttonWidth / RIM_SIZE
    local columnPitch = (actionDefaults.buttonWidth + actionDefaults.buttonGap) / defaultScale
    local socketSize = RIM_SIZE * 40 / 36
    local ANIMATION_INTERVAL = 1 / 30
    local texturePath = DFRL:GetInfoOrCons("tex") .. "jewelry\\"
    local SLOT_NAMES = { "Finger0Slot", "Finger1Slot", "NeckSlot", "Trinket0Slot", "Trinket1Slot" }
    local EMPTY_TEXTURES = {
        "EmptyRing.blp",
        "EmptyRing.blp",
        "EmptyNeck.blp",
        "EmptyTrinket.blp",
        "EmptyTrinket.blp",
    }
    local slots, slotsReady = {}, false
    local inWorld, editing, attached, elapsed, animationElapsed = true, false, false, 0, 0
    local cooldownsActive = false
    local shownWanted, wantedDocked, SyncUpdates, cleared = false, nil, nil, true
    local displayGeometry = {}
    local hud = CreateFrame("Frame", "SurvivorsDragonUiJewelry", UIParent)
    hud:SetWidth(WIDTH)
    hud:SetHeight(HEIGHT)
    hud:SetScale(defaultScale)
    hud:SetFrameStrata("LOW")
    hud:EnableMouse(false)
    hud:Hide()
    local detached = CreateFrame("Frame", "SurvivorsDragonUiDetachedJewelry", UIParent)
    detached:SetWidth(WIDTH)
    detached:SetHeight(HEIGHT)
    detached:SetScale(defaultScale)
    detached:SetFrameStrata("LOW")
    detached:EnableMouse(false)
    detached:Hide()

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local hoveredSlot, effectPanel, effectText, scanner, scannerParent
    local effectSlot, effectValue, effectScale
    local SCANNER_NAME = "SurvivorsDragonUiJewelryScanner"
    local EFFECT_MAX_WIDTH, EFFECT_PADDING = 272, 10
    local EFFECT_PREFIXES = {
        { "ITEM_SPELL_TRIGGER_ONEQUIP", "Equip:" },
        { "ITEM_SPELL_TRIGGER_ONUSE", "Use:" },
        { "ITEM_SPELL_TRIGGER_ONPROC", "Chance on hit:" },
    }
    local function GetScanner()
        if scanner == false then return nil end
        if not scanner then
            scannerParent = CreateFrame("Frame", nil, UIParent)
            scannerParent:Hide()
            local ok, tooltip = pcall(CreateFrame, "GameTooltip", SCANNER_NAME, scannerParent, "GameTooltipTemplate")
            if
                not ok
                or not tooltip
                or type(tooltip.SetInventoryItem) ~= "function"
                or type(tooltip.SetOwner) ~= "function"
                or type(tooltip.ClearLines) ~= "function"
                or type(tooltip.NumLines) ~= "function"
            then
                if ok and tooltip then tooltip:Hide() end
                scanner = false
                return nil
            end
            -- Native builders may Show and reset alpha; the hidden parent keeps
            -- this private reader invisible without touching GameTooltip.
            scanner = tooltip
            scanner:EnableMouse(false)
        end
        return scanner
    end
    -- Localized native templates and reviewed compact forms are text data.
    local EFFECT_NUMBER = "(%d+[.,]?%d*)"
    local EFFECT_VALUE = "(%d+[.,]?%d*%%?)"
    local EFFECT_SUBJECT = "([^%.!?;:%%\r\n]+)"
    local EFFECT_FIELDS = {
        p = "(%d+[.,]?%d*%%)",
        v = EFFECT_VALUE,
        g = EFFECT_VALUE,
        n = "(%+?%d+)",
        who = EFFECT_SUBJECT,
        hits = EFFECT_SUBJECT,
        spell = EFFECT_SUBJECT,
        frac = "(%d+[.,]?%d*%%)",
        chance = "(%d+[.,]?%d*%%)",
        s = EFFECT_NUMBER,
        radius = EFFECT_NUMBER,
        dur = EFFECT_NUMBER,
        heal = EFFECT_VALUE,
        cd = EFFECT_NUMBER,
        max = EFFECT_NUMBER,
    }
    local compiled = {}
    local formattedCache, cacheSize = {}, 0
    local function EscapeEffectLiteral(text) return (string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end
    local function TrimPeriod(text)
        text = string.gsub(text, "%s+$", "")
        if string.sub(text, -3) == "。" then return string.sub(text, 1, -4) end
        return (string.gsub(text, "%.$", ""))
    end
    local function Compile(source, suffix)
        source = TrimPeriod((string.gsub(source, "%s+", " ")))
        local pattern, fields, cursor = suffix and "" or "^", {}, 1
        while true do
            local first, last, field = string.find(source, "{(%w+)}", cursor)
            if not first then break end
            local capture = EFFECT_FIELDS[field]
            if string.sub(source, last + 1, last + 1) == "%" then capture = EFFECT_NUMBER end
            if not capture then return nil end
            pattern = pattern .. EscapeEffectLiteral(string.sub(source, cursor, first - 1)) .. capture
            table.insert(fields, field)
            cursor = last + 1
        end
        return { pattern .. EscapeEffectLiteral(string.sub(source, cursor)) .. "$", fields }
    end
    local function Rules(code)
        if compiled[code] then return compiled[code] end
        local catalog = DFRL.locale.data[code]
        local rules = { caps = catalog.caps, rate = Compile(catalog.rate, true) }
        for _, pair in ipairs(catalog.effects) do
            local rule = Compile(pair[1])
            if rule then
                rule.output = pair[2]
                table.insert(rules, rule)
            end
        end
        compiled[code] = rules
        return rules
    end
    local function FormatFor(description, code)
        local rules = Rules(code)
        local sentence = TrimPeriod((string.gsub(description, "%s+", " ")))
        local cap, rate = "", ""
        for _, marker in ipairs(rules.caps) do
            if marker ~= "" and string.sub(sentence, -string.len(marker)) == marker then
                sentence, cap = string.sub(sentence, 1, string.len(sentence) - string.len(marker)), marker
                break
            end
        end
        if rules.rate then
            local first = string.find(sentence, rules.rate[1])
            if first then
                rate = string.sub(sentence, first)
                sentence = string.sub(sentence, 1, first - 1)
            end
        end
        sentence = TrimPeriod(sentence)
        for _, rule in ipairs(rules) do
            local matches = { string.find(sentence, rule[1]) }
            if matches[1] then
                local values, safe = {}, true
                for index, field in ipairs(rule[2]) do
                    local value = matches[index + 2]
                    if field == "n" then value = string.gsub(value, "^%+", "") end
                    if field == "who" or field == "hits" or field == "spell" then
                        if not string.find(value, "%S") then safe = false end
                        for _, separator in ipairs({ "。", "：", "！", "？", "；" }) do
                            if string.find(value, separator, 1, true) then safe = false end
                        end
                    end
                    values[field] = value
                end
                if safe then
                    local output = string.gsub(rule.output, "{(%w+)}", function(field)
                        if values[field] == nil then safe = false end
                        return values[field] or ""
                    end)
                    if safe then return output .. rate .. cap end
                end
            end
        end
        return nil
    end
    local function FormatEffect(description)
        local code = DFRL.locale.code
        local key = code .. "\n" .. description
        local cached = formattedCache[key]
        if cached ~= nil then return cached or description end
        local function Remember(value)
            if cacheSize >= 128 then
                formattedCache, cacheSize = {}, 0
            end
            formattedCache[key] = value or false
            cacheSize = cacheSize + 1
            return value or description
        end
        local formatted = FormatFor(description, code)
        if formatted then return Remember(formatted) end
        -- Native tooltips can arrive before the zone's language snapshot. Match
        -- complete templates without changing the selected UI language.
        local fallback
        for candidate in pairs(DFRL.locale.data) do
            if candidate ~= code then
                formatted = FormatFor(description, candidate)
                if formatted then
                    if fallback and fallback ~= formatted then return Remember(nil) end
                    fallback = formatted
                end
            end
        end
        return Remember(fallback)
    end
    local function EffectDescription(text)
        if type(text) ~= "string" then return nil end
        local plain = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        plain = string.gsub(plain, "|r", "")
        plain = string.gsub(plain, "^%s+", "")
        for _, entry in ipairs(EFFECT_PREFIXES) do
            local prefix = _G[entry[1]]
            if type(prefix) ~= "string" or prefix == "" then prefix = entry[2] end
            if string.sub(plain, 1, string.len(prefix)) == prefix then
                local description = string.gsub(string.sub(plain, string.len(prefix) + 1), "^%s+", "")
                if description ~= "" then return FormatEffect(description) end
            end
        end
        return nil
    end
    local function ReadEffects(slot)
        local tooltip = GetScanner()
        if not tooltip then return nil end
        -- Hide releases native ownership and clears lines, so re-own for every
        -- read and copy complete wrapped effect rows before hiding the scanner.
        tooltip:SetOwner(scannerParent, "ANCHOR_NONE")
        tooltip:ClearLines()
        local ok, hasItem = pcall(tooltip.SetInventoryItem, tooltip, "player", slot.id)
        local effects = {}
        if ok and (hasItem == true or hasItem == 1) then
            for index = 2, math.min(64, tooltip:NumLines()) do
                local line = _G[SCANNER_NAME .. "TextLeft" .. index]
                local text = line and type(line.GetText) == "function" and line:GetText()
                local description = EffectDescription(text)
                if description then table.insert(effects, description) end
            end
        end
        tooltip:Hide()
        if table.getn(effects) > 0 then return table.concat(effects, "\n\n") end
        return nil
    end
    local function GetEffectPanel()
        if not effectPanel then
            -- Share the native-style hover skin without taking GameTooltip's
            -- ownership or exposing the private inventory reader.
            effectPanel = DFRL.tools.CreateHoverCard(UIParent, EFFECT_MAX_WIDTH + EFFECT_PADDING * 2, 40)
            effectPanel:Hide()
            effectText = effectPanel:CreateFontString(nil, "OVERLAY")
            T.SetFont(effectText, 13, "")
            effectText:SetShadowColor(0, 0, 0, 1)
            effectText:SetShadowOffset(1, -1)
            effectText:SetJustifyH("LEFT")
            effectText:SetJustifyV("TOP")
            effectText:SetWidth(EFFECT_MAX_WIDTH)
            effectText:SetPoint("TOPLEFT", effectPanel, "TOPLEFT", EFFECT_PADDING, -EFFECT_PADDING)
        end
        return effectPanel
    end
    local function PlaceEffectTooltip(slot)
        if DFRL.display.Get("tooltipAtCursor") and T.PlaceHoverAtCursor(effectPanel) then return end
        local point, relative, relativePoint, x, y = effectPanel:GetPoint(1)
        if
            effectPanel:GetNumPoints() ~= 1
            or point ~= "BOTTOMLEFT"
            or relative ~= slot.button
            or relativePoint ~= "TOPLEFT"
            or x ~= -EFFECT_PADDING
            or y ~= 12
        then
            effectPanel:ClearAllPoints()
            effectPanel:SetPoint("BOTTOMLEFT", slot.button, "TOPLEFT", -EFFECT_PADDING, 12)
        end
    end
    local function HideTooltip(slot)
        if hoveredSlot ~= slot then return end
        hoveredSlot = nil
        effectSlot, effectValue, effectScale = nil, nil, nil
        if effectPanel then
            effectPanel:Hide()
            T.SetTextIfChanged(effectText, "")
        end
    end
    local function ShowTooltip(slot)
        if not inWorld or editing or not slot.id or not slot.texture or not hud:IsVisible() then return end
        hoveredSlot = slot
        local text = ReadEffects(slot)
        if not text then
            effectSlot, effectValue, effectScale = nil, nil, nil
            if effectPanel then
                effectPanel:Hide()
                T.SetTextIfChanged(effectText, "")
            end
            return
        end
        local panel = GetEffectPanel()
        local red, green, blue = slot.qualityR or 0, slot.qualityG or 1, slot.qualityB or 0
        -- Color is independent of text/measurements: replacing an item can
        -- change its rarity without changing the native effect description.
        if panel.qualityR ~= red or panel.qualityG ~= green or panel.qualityB ~= blue then
            effectText:SetTextColor(red, green, blue)
            panel.qualityR, panel.qualityG, panel.qualityB = red, green, blue
        end
        local scale = panel:GetEffectiveScale()
        if effectSlot == slot and effectValue == text and T.NearlyEqual(effectScale, scale) then
            PlaceEffectTooltip(slot)
            if not panel:IsShown() then panel:Show() end
            return
        end
        T.SetTextIfChanged(effectText, text)
        -- Native natural width is independent of the previous wrapping width,
        -- so the same pooled card can shrink and grow when changing items.
        local textWidth = effectText:GetStringWidth()
        if not Number(textWidth) or textWidth <= 0 then
            panel:Hide()
            return
        end
        textWidth = math.min(EFFECT_MAX_WIDTH, math.ceil(textWidth) + 1)
        effectText:SetWidth(textWidth)
        panel:SetWidth(textWidth + EFFECT_PADDING * 2)
        -- Measure again at the fitted width before reading wrapped height.
        -- The 1.12 client uses GetHeight rather than GetStringHeight.
        effectText:GetStringWidth()
        panel:SetHeight(math.max(14, effectText:GetHeight()) + EFFECT_PADDING * 2)
        PlaceEffectTooltip(slot)
        effectSlot, effectValue, effectScale = slot, text, scale
        panel:Show()
    end
    local artwork = CreateFrame("Frame", nil, hud)
    artwork:SetAllPoints(hud)
    artwork:SetFrameLevel(hud:GetFrameLevel() + 1)
    artwork:EnableMouse(false)
    local iconProbe = artwork:CreateTexture(nil, "ARTWORK")
    iconProbe:Hide()
    local iconParts, iconPool, iconsDirty = {}, {}, false
    for part = 1, 16 do
        local top, bottom = (part - 1) * 2, part * 2
        local edge = math.max(math.abs(top - 16), math.abs(bottom - 16))
        local half = math.sqrt(math.max(0, 256 - edge * edge))
        if half > 0 then
            table.insert(iconParts, {
                left = 16 - half,
                top = top,
                width = half * 2,
                firstU = iconInset + (16 - half) * iconSpan / ICON_SIZE,
                lastU = iconInset + (16 + half) * iconSpan / ICON_SIZE,
                firstV = iconInset + top * iconSpan / ICON_SIZE,
                lastV = iconInset + bottom * iconSpan / ICON_SIZE,
            })
        end
    end
    local function SetIcon(slot, texture)
        -- A failed native texture assignment keeps the preceding slot artwork.
        -- Probe from empty so a retained image cannot masquerade as success.
        iconProbe:SetTexture(nil)
        local loaded = iconProbe:SetTexture(texture)
        local assigned = iconProbe:GetTexture()
        local stem = string.gsub(texture, "%.[^%.]*$", "")
        if loaded == 1 or loaded == true or assigned == texture or assigned == stem then slot.artTexture = texture end
        iconProbe:SetTexture(nil)
        slot.texture = texture
        iconsDirty = true
    end
    local function PaintIcons()
        if not iconsDirty then return end
        local groups, byTexture = {}, {}
        for _, slot in ipairs(slots) do
            if slot.artTexture then
                local group = byTexture[slot.artTexture]
                if not group then
                    group = { texture = slot.artTexture, slots = {} }
                    byTexture[slot.artTexture] = group
                    table.insert(groups, group)
                end
                table.insert(group.slots, slot)
            end
        end
        local used = 0
        for _, group in ipairs(groups) do
            for _, part in ipairs(iconParts) do
                for _, slot in ipairs(group.slots) do
                    used = used + 1
                    local strip = iconPool[used]
                    if not strip then
                        strip = artwork:CreateTexture(nil, "ARTWORK")
                        strip:Hide()
                        table.insert(iconPool, strip)
                    end
                    if strip.jewelrySlot ~= slot then
                        strip:Hide()
                        strip:SetTexture(nil)
                        strip.jewelryTexture = nil
                        strip:ClearAllPoints()
                        strip:SetPoint("TOPLEFT", slot.button, "TOPLEFT", part.left, -part.top)
                        strip.jewelrySlot = slot
                    elseif strip.jewelryPart ~= part then
                        strip:ClearAllPoints()
                        strip:SetPoint("TOPLEFT", slot.button, "TOPLEFT", part.left, -part.top)
                    end
                    if strip.jewelryPart ~= part then
                        strip:SetWidth(part.width)
                        strip:SetHeight(2)
                        strip:SetTexCoord(part.firstU, part.lastU, part.firstV, part.lastV)
                        strip.jewelryPart = part
                    end
                    if strip.jewelryTexture ~= group.texture then
                        strip:SetTexture(group.texture)
                        strip.jewelryTexture = group.texture
                    end
                    if not strip:IsShown() then strip:Show() end
                end
            end
        end
        for index = used + 1, table.getn(iconPool) do
            local strip = iconPool[index]
            if strip:IsShown() then strip:Hide() end
            if strip.jewelryTexture then strip:SetTexture(nil) end
            strip.jewelryTexture, strip.jewelrySlot, strip.jewelryPart = nil, nil, nil
        end
        iconsDirty = false
    end
    for index, name in ipairs(SLOT_NAMES) do
        local button = CreateFrame("Frame", nil, hud)
        button:SetWidth(ICON_SIZE)
        button:SetHeight(ICON_SIZE)
        button:SetPoint("TOPLEFT", hud, "TOPLEFT", WIDTH / 2 - ICON_SIZE / 2 + (index - 3) * columnPitch, -30.5)
        button:EnableMouse(true)
        local slot = { name = name, button = button }
        local placeholder = button:CreateTexture(nil, "ARTWORK")
        placeholder:SetTexture(texturePath .. EMPTY_TEXTURES[index])
        placeholder:SetAllPoints(button)
        placeholder:Hide()
        slot.placeholder = placeholder
        local socket = hud:CreateTexture(nil, "BACKGROUND")
        socket:SetTexture(texturePath .. "SocketDetached.blp")
        socket:SetWidth(socketSize)
        socket:SetHeight(socketSize)
        socket:SetPoint("CENTER", button, "CENTER", 0, 0)
        socket:SetTexCoord(0, 160 / 256, 0, 160 / 256)
        socket:Hide()
        slot.socket = socket
        local cooldown = button:CreateTexture(nil, "OVERLAY")
        cooldown:SetTexture(texturePath .. "Cooldown.blp")
        cooldown:SetAllPoints(button)
        cooldown:Hide()
        slot.cooldown = cooldown
        button:SetScript("OnEnter", function() ShowTooltip(slot) end)
        button:SetScript("OnLeave", function() HideTooltip(slot) end)
        button:SetScript("OnHide", function() HideTooltip(slot) end)
        -- These are read-only hover frames: no equipment-use, pickup or drag handlers.
        table.insert(slots, slot)
    end

    -- Reuse one rim crop independently so socket spacing can match the buttons.
    local overlay = CreateFrame("Frame", nil, hud)
    overlay:SetAllPoints(hud)
    overlay:SetFrameLevel(hud:GetFrameLevel() + 3)
    overlay:EnableMouse(false)
    for _, slot in ipairs(slots) do
        local rim = overlay:CreateTexture(nil, "OVERLAY")
        rim:SetTexture(texturePath .. "Frame.blp")
        rim:SetWidth(RIM_SIZE * 72 / 86)
        rim:SetHeight(RIM_SIZE * 72 / 86)
        rim:SetPoint("CENTER", slot.button, "CENTER", 0, 0)
        -- Trim the source rim's uneven clear padding; its visible circle is
        -- centered in this square crop rather than the full source rectangle.
        -- Compensate the crop size to preserve the visible rim's diameter.
        rim:SetTexCoord(106 / 1024, 178 / 1024, 56 / 256, 128 / 256)
        slot.rim = rim
    end
    local function SetQuality(slot, quality, red, green, blue)
        if (slot.qualityR ~= nil) ~= (red ~= nil) then
            -- The neutral copy keeps the same shading and alpha without
            -- multiplying rarity colors by the stock gold's yellow channels.
            local left = red ~= nil and 664 or 106
            slot.rim:SetTexCoord(left / 1024, (left + 72) / 1024, 56 / 256, 128 / 256)
        end
        if
            (slot.qualityR or 1) ~= (red or 1)
            or (slot.qualityG or 1) ~= (green or 1)
            or (slot.qualityB or 1) ~= (blue or 1)
        then
            slot.rim:SetVertexColor(red or 1, green or 1, blue or 1, 1)
        end
        slot.quality, slot.qualityR, slot.qualityG, slot.qualityB = quality, red, green, blue
    end
    local function UpdateQuality(slot)
        if type(GetInventoryItemQuality) == "function" then
            local ok, quality = pcall(GetInventoryItemQuality, "player", slot.id)
            if ok and Number(quality) and quality >= 0 and quality == math.floor(quality) then
                if slot.quality == quality and slot.qualityR ~= nil then return end
                local red, green, blue
                if type(GetItemQualityColor) == "function" then
                    ok, red, green, blue = pcall(GetItemQualityColor, quality)
                else
                    local color = _G["ITEM_QUALITY" .. quality .. "_COLOR"]
                    if type(color) == "table" then
                        red, green, blue = color.r, color.g, color.b
                    end
                end
                if
                    ok
                    and Number(red)
                    and red >= 0
                    and red <= 1
                    and Number(green)
                    and green >= 0
                    and green <= 1
                    and Number(blue)
                    and blue >= 0
                    and blue <= 1
                then
                    SetQuality(slot, quality, red, green, blue)
                    return
                end
            end
        end
        -- Unavailable metadata retries at the existing equipment cadence.
        -- Never retain another item's rarity or suppress an otherwise valid icon.
        SetQuality(slot)
    end
    local function ClearSlot(slot)
        slot.placeholder:Hide()
        if slot.texture or slot.artTexture then iconsDirty = true end
        slot.texture, slot.artTexture = nil, nil
        slot.cooldown:Hide()
        slot.start, slot.duration, slot.painted = nil, nil, nil
        SetQuality(slot)
        HideTooltip(slot)
    end
    local function Clear()
        if cleared then return end
        cleared = true
        shownWanted, wantedDocked = false, nil
        formattedCache, cacheSize = {}, 0
        cooldownsActive = false
        for _, slot in ipairs(slots) do
            ClearSlot(slot)
        end
        PaintIcons()
        hud:Hide()
        detached:Hide()
    end
    hud:SetScript("OnHide", function()
        if SyncUpdates then SyncUpdates() end
        if DFRL.SetJewelryBarShown then DFRL.SetJewelryBarShown(false) end
        for _, slot in ipairs(slots) do
            HideTooltip(slot)
        end
    end)
    hud:SetScript("OnShow", function()
        elapsed, animationElapsed = INTERVAL, ANIMATION_INTERVAL
        if SyncUpdates then SyncUpdates() end
        if DFRL.SetJewelryBarShown then DFRL.SetJewelryBarShown(DFRL.display.Get("attachJewelry")) end
    end)
    local function ResolveSlots()
        if slotsReady then return true end
        if type(GetInventorySlotInfo) ~= "function" then return false end
        local ids, seen = {}, {}
        for index, slot in ipairs(slots) do
            local ok, id = pcall(GetInventorySlotInfo, slot.name)
            if not ok or not Number(id) or id <= 0 or id ~= math.floor(id) or seen[id] then return false end
            ids[index], seen[id] = id, true
        end
        for index, slot in ipairs(slots) do
            slot.id = ids[index]
        end
        slotsReady = true
        return true
    end
    local function UpdateCooldown(slot)
        if type(GetInventoryItemCooldown) ~= "function" then
            slot.start, slot.duration = nil, nil
            return
        end
        local ok, start, duration, enabled = pcall(GetInventoryItemCooldown, "player", slot.id)
        if
            not ok
            or not Number(start)
            or not Number(duration)
            or not Number(enabled)
            or start <= 0
            or duration <= 0
            or enabled <= 0
        then
            slot.start, slot.duration = nil, nil
            return
        end
        slot.start, slot.duration = start, duration
    end
    local function PaintCooldowns()
        if not cooldownsActive or not hud:IsVisible() then return end
        local now = type(GetTime) == "function" and GetTime() or nil
        local active = false
        for _, slot in ipairs(slots) do
            local frame
            if slot.texture and Number(now) and slot.start and slot.duration then
                local remaining = slot.duration - (now - slot.start)
                if remaining > 0 then frame = math.ceil(math.min(1, remaining / slot.duration) * 63) end
            end
            if frame then
                if frame ~= slot.painted then
                    local column, row = math.mod(frame, 8), math.floor(frame / 8)
                    slot.cooldown:SetTexCoord(column / 8, (column + 1) / 8, row / 8, (row + 1) / 8)
                    slot.cooldown:Show()
                    slot.painted = frame
                end
            elseif slot.painted then
                slot.cooldown:Hide()
                slot.painted = nil
            end
            if slot.start or slot.painted then active = true end
        end
        cooldownsActive = active
    end
    local function CanPaint()
        local docked = DFRL.display.Get("attachJewelry")
        local owner = docked and DFRL.mainBar or UIParent
        return inWorld
            and attached
            and DFRL.display.Get("equippedJewelry")
            and not DFRL.layout.IsHidden(docked and "actionBar" or "jewelryBar")
            and owner
            and owner:IsVisible()
    end
    local function Refresh()
        if not inWorld or not attached or not DFRL.display.Get("equippedJewelry") then
            Clear()
            return
        end
        local docked = DFRL.display.Get("attachJewelry")
        if not shownWanted or wantedDocked ~= docked then
            cleared = false
            shownWanted, wantedDocked = true, docked
            if docked then
                detached:Hide()
            else
                detached:Show()
            end
            hud:Show()
        end
        if not CanPaint() then return end
        if
            type(UnitExists) ~= "function"
            or not UnitExists("player")
            or type(GetInventoryItemTexture) ~= "function"
            or not ResolveSlots()
        then
            Clear()
            return
        end
        cooldownsActive = false
        for _, slot in ipairs(slots) do
            local ok, texture = pcall(GetInventoryItemTexture, "player", slot.id)
            if ok and type(texture) == "string" and texture ~= "" then
                slot.placeholder:Hide()
                if slot.texture ~= texture then SetIcon(slot, texture) end
                UpdateQuality(slot)
                UpdateCooldown(slot)
                if hoveredSlot == slot then ShowTooltip(slot) end
            else
                ClearSlot(slot)
                if ok and (texture == nil or texture == "") then slot.placeholder:Show() end
            end
            if slot.start or slot.painted then cooldownsActive = true end
        end
        PaintIcons()
    end
    local function UpdateDisplay()
        local docked = DFRL.display.Get("attachJewelry")
        if attached then
            local owner = docked and DFRL.mainBar or detached
            local reparented = hud:GetParent() ~= owner
            if reparented then
                shownWanted = false
                hud:Hide()
                hud:SetParent(owner)
            end
            local scale, level = docked and defaultScale or 1, owner:GetFrameLevel() + 2
            if not T.NearlyEqual(hud:GetScale(), scale) then hud:SetScale(scale) end
            if hud:GetFrameLevel() ~= level then hud:SetFrameLevel(level) end
            level = hud:GetFrameLevel()
            if artwork:GetFrameLevel() ~= level + 1 then artwork:SetFrameLevel(level + 1) end
            if reparented or displayGeometry.owner ~= owner or displayGeometry.docked ~= docked then
                hud:ClearAllPoints()
                hud:SetPoint("TOP", owner, "TOP", 0, docked and (46.5 + RIM_SIZE * 20 / 36) or 0)
                displayGeometry.owner, displayGeometry.docked = owner, docked
            end
            for _, slot in ipairs(slots) do
                if slot.button:GetFrameLevel() ~= level + 1 then slot.button:SetFrameLevel(level + 1) end
                if docked then
                    if slot.socket:IsShown() then slot.socket:Hide() end
                else
                    if not slot.socket:IsShown() then slot.socket:Show() end
                end
            end
            if overlay:GetFrameLevel() ~= level + 3 then overlay:SetFrameLevel(level + 3) end
        end
        if DFRL.SetActionBarJewelryTop then
            local top = actionDefaults.topInset
            if DFRL.display.Get("equippedJewelry") and docked then
                top = math.max(top, actionDefaults.buttonWidth * 40 / 36)
            end
            DFRL.SetActionBarJewelryTop(top)
        end
        Refresh()
        PaintCooldowns()
        if SyncUpdates then SyncUpdates() end
        if DFRL.SetJewelryBarShown then DFRL.SetJewelryBarShown(docked and hud:IsVisible() and true or false) end
    end
    function DFRL.SetJewelryEditing(active)
        editing = active
        if editing then
            for _, slot in ipairs(slots) do
                HideTooltip(slot)
            end
        end
    end
    function DFRL.AttachJewelry(mainBar)
        if attached or not mainBar then return end
        attached = true
        UpdateDisplay()
    end
    local detachedRegion = CreateFrame("Frame", nil, detached)
    detachedRegion:SetWidth(socketSize + columnPitch * 4)
    detachedRegion:SetHeight(socketSize)
    detachedRegion:SetPoint("TOP", detached, "TOP", 0, -(46.5 - socketSize / 2))
    DFRL.layout.Register("jewelryBar", detached, function()
        local artTop = actionDefaults.bottom + actionDefaults.height + actionDefaults.topInset
        local bottom = (artTop + 4) / defaultScale - (HEIGHT - 46.5 - socketSize / 2)
        detached:ClearAllPoints()
        detached:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, bottom)
    end, { region = detachedRegion, onlyWhenShown = true, onEdit = DFRL.SetJewelryEditing })
    if DFRL.mainBar then DFRL.AttachJewelry(DFRL.mainBar) end
    local controller = CreateFrame("Frame", nil, UIParent)
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("UNIT_INVENTORY_CHANGED")
    controller:RegisterEvent("BAG_UPDATE_COOLDOWN")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            elapsed, animationElapsed = 0, 0
            Clear()
        elseif event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            elapsed, animationElapsed = 0, 0
            Clear()
            Refresh()
            PaintCooldowns()
        elseif event ~= "UNIT_INVENTORY_CHANGED" or arg1 == "player" then
            elapsed = INTERVAL
        end
    end)
    local function Tick()
        if not CanPaint() then return end
        if hoveredSlot and effectPanel and effectPanel:IsShown() and DFRL.display.Get("tooltipAtCursor") then
            PlaceEffectTooltip(hoveredSlot)
        end
        elapsed = elapsed + arg1
        animationElapsed = animationElapsed + arg1
        if elapsed >= INTERVAL then
            elapsed = 0
            Refresh()
            animationElapsed = ANIMATION_INTERVAL
        end
        if animationElapsed >= ANIMATION_INTERVAL then
            animationElapsed = 0
            if cooldownsActive then PaintCooldowns() end
        end
    end
    SyncUpdates = function() controller:SetScript("OnUpdate", CanPaint() and Tick or nil) end
    local function VisibilityChanged()
        elapsed, animationElapsed = INTERVAL, ANIMATION_INTERVAL
        SyncUpdates()
    end
    DFRL.layout.ListenVisibility("actionBar", VisibilityChanged)
    DFRL.layout.ListenVisibility("jewelryBar", VisibilityChanged)
    DFRL.display.Listen(function()
        UpdateDisplay()
        if hoveredSlot and effectPanel and effectPanel:IsShown() then PlaceEffectTooltip(hoveredSlot) end
    end)
    UpdateDisplay()
end)
