-- Five equipped jewelry sockets, attached by default and optionally independent.
--[[
The selected thin-bezel design keeps the Blizzard gold circular rim artwork.
SocketRail.tga joins all upper socket arches and straight spans in one texture
using pixels from the existing HDActionBar.tga. The original bar texture is
unchanged; only its narrow top strip switches while this jewelry row is visible.
No extra inner or lower curved line is drawn beneath the gold circles.
SocketDetached.tga retains the silver-gray circle borders in detached mode.
Texture conversion does not change the underlying artwork's ownership.
No upstream Lua is imported. Sources and preparation: third_party/Jewelry-ARTWORK.md.

Gold circular rim: Karl-HeinzSchneider/WoW-DragonflightUI
b8b35451d4621a8097e887385f72ec03e17765f1, Textures/bagborder2.blp.
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
    local SLOT_NAMES = { "NeckSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
    local slots, slotsReady = {}, false
    local inWorld, editing, attached, elapsed, animationElapsed = true, false, false, 0, 0
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
    -- Native English item-effect templates, not item IDs or computed stats.
    -- Catalog source and all compact forms: docs/JEWELRY-EFFECTS.md.
    local EFFECT_RULES = {
        { "Increases all damage you deal by {p}.", "+ Damage dealt: {p}" },
        { "Reduces the cooldown of your spells by {p}.", "- {p} Cooldown" },
        { "Increases your maximum health by {p}.", "+ Maximum health: {p}" },
        { "Improves your chance to get a critical strike by {p}.", "+ Critical strike chance: {p}" },
        { "Increases the damage of your critical strikes by {p}.", "+ Critical damage: {p}" },
        { "Reduces all damage taken by {p}.", "- {p} Damage taken" },
        { "Restores {v} health per second.", "+ Health regen: {v}/s" },
        { "Increases your movement speed by {p}.", "+ Movement speed: {p}" },
        { "Increases the area of effect of your spells by {p}.", "+ Spell area: {p}" },
        { "Increases the range you pick up loot from by {p}.", "+ Loot pickup range: {p}" },
        { "Increases experience gained by {p}.", "+ Experience gained: {p}" },
        { "Increases gold found by {p}.", "+ Gold found: {p}" },
        { "Increases your luck by {p}.", "+ Luck: {p}" },
        { "Gives your spells a {p} chance to cast twice.", "+ Spell double-cast chance: {p}" },
        { "Heals you for {p} of all damage you deal.", "+ Lifesteal: {p}" },
        { "Each enemy you kill restores {v} health.", "+ Health on kill: {v}" },
        { "Increases your weapon damage by {p}.", "+ Weapon damage: {p}" },
        { "Increases the damage your pets deal by {p}.", "+ Pet damage: {p}" },
        { "Increases damage dealt to crowd-controlled enemies by {p}.", "+ Damage vs crowd-controlled enemies: {p}" },
        { "Increases damage dealt to elites and bosses by {p}.", "+ Damage vs elites / bosses: {p}" },
        { "Increases damage dealt to enemies below 30% health by {p}.", "+ Damage vs enemies below 30% health: {p}" },
        { "Increases damage dealt to afflicted enemies by {p}.", "+ Damage vs afflicted enemies: {p}" },
        {
            "Melee attackers take {p} of the damage they deal you.",
            "Reflect to melee attackers: {p} of their damage to you",
        },
        { "Your damage, haste, shield and thorns buffs are {p} stronger.", "+ Buff power: {p}" },
        { "Restores {p} of your maximum health per second.", "+ Health regen: {p} max health/s" },
        {
            "Increases all damage you deal by {v}% for every 10% damage reduction you have.",
            "+ Damage: {v}% per 10% damage reduction",
        },
        {
            "Each 1% of damage reduction past the cap increases your damage by {v}%.",
            "+ Damage: {v}% per 1% damage reduction above cap",
        },
        { "Raises your damage reduction cap by {p}.", "+ Damage reduction cap: {p}" },
        { "Increases all damage you deal by {p} while a shield holds.", "+ Damage while shielded: {p}" },
        {
            "Your damage over time spells tick {v}% faster: more ticks, and more damage, in the same time. {max}% at most.",
            "+ DoT haste: {v}% (more ticks / damage; same duration; cap {max}%)",
        },
        {
            "Returns you to life at half health when you die. Holds {n} lives at most.",
            "Revive at half health; max {n} lives",
        },
        -- Native subjects include ability names, your hits and critical hits.
        { "Increases the healing of {who} by {g}.", "+ {who} healing: {g}" },
        { "Increases the absorb of {who} by {g}.", "+ {who} absorb: {g}" },
        { "Increases the damage of {who} by {v}.", "+ {who} damage: {v}" },
        { "Reduces the cooldown of {who} by {v}.", "- {who} cooldown: {v}" },
        { "Increases the area of {who} by {v}.", "+ {who} area: {v}" },
        { "Increases the duration of {who} by {v}.", "+ {who} duration: {v}" },
        { "{who} deals an extra {v} of your maximum health.", "{who}: +{v} of your max health as damage" },
        { "{who} deal an extra {v} of your maximum health.", "{who}: +{v} of your max health as damage" },
        { "{who} strikes 1 more target.", "+ {who} targets: 1" },
        { "{who} strikes {n} more targets.", "+ {who} targets: {n}" },
        { "{who} strike 1 more target.", "+ {who} targets: 1" },
        { "{who} strike {n} more targets.", "+ {who} targets: {n}" },
        { "Increases how much {who} weakens enemies by {v}.", "+ {who} weakening: {v}" },
        { "Increases the strength of {who} by {v}.", "+ {who} strength: {v}" },
        { "{who} procs {v} more often.", "+ {who} proc rate: {v}" },
        { "Increases the stun duration of {who} by {v}.", "+ {who} stun duration: {v}" },
        -- Keep each legendary modifier's conditions, ranges and extra values.
        { "{hits} leap to 1 more enemy for {frac}", "{hits}: chain +1 enemy at {frac} damage" },
        { "{hits} leap to {n} more enemies for {frac}", "{hits}: chain +{n} enemies at {frac} damage" },
        { "{chance} chance for {hits} to strike again for {frac}", "{hits}: {chance} chance to hit again for {frac}" },
        { "{chance} chance to stun a melee attacker for {s} sec", "Melee attackers: {chance} stun chance for {s} sec" },
        {
            "A broken shield bursts for {frac} of what it absorbed on enemies within {radius} yd",
            "Shield breaks: {frac} of absorbed damage to enemies within {radius} yd",
        },
        { "{hits} stun for {s} sec", "{hits}: stun {s} sec" },
        { "{hits} root for {s} sec", "{hits}: root {s} sec" },
        {
            "{hits} leave enemies taking {v} more damage for {s} sec",
            "{hits}: enemies take {v} more damage for {s} sec",
        },
        { "{hits} hinder enemies", "{hits}: hinder enemies" },
        { "{hits} burn and bleed for {frac} more over {dur} sec", "{hits}: +{frac} burn and bleed over {dur} sec" },
        { "{hits} splash {frac} on enemies within {radius} yd", "{hits}: splash {frac} to enemies in {radius} yd" },
        {
            "Enemies that die with {spell} on them explode for {frac} of their max health",
            "On enemy death with {spell}: explode for {frac} of its max health",
        },
        {
            "Enemies {spell} kills explode for {frac} of their max health",
            "{spell} kills: explode for {frac} of enemy max health",
        },
        {
            "Enemies you kill explode for {frac} of their max health",
            "On kill: explode for {frac} of enemy max health",
        },
        { "{who} leaps to {n} enemies when its victim dies", "On victim death: {who} leaps to {n} enemies" },
        { "A kill with {who} readies it again at once", "On {who} kill: ready again instantly" },
        { "Every totem pulse heals you {frac} of max health", "Totem pulse: heal {frac} of max health" },
        {
            "A killing blow leaves you at {heal} health instead, once every {cd} sec",
            "Fatal hit: survive at {heal} health (once per {cd} sec)",
        },
        {
            "Enemies you kill during {spell} explode for {frac} of their max health",
            "Kills during {spell}: explode for {frac} of enemy max health",
        },
        {
            "{spell} explodes a second time for {frac} of its damage",
            "{spell}: second explosion for {frac} of its damage",
        },
        {
            "{spell} also shields you for {frac} of your max health",
            "{spell}: also shield for {frac} of your max health",
        },
        {
            "While {spell} heals you, {p} of the damage you deal heals you too",
            "While {spell} heals you: lifesteal {p} of damage dealt",
        },
    }
    local EFFECT_NUMBER = "(%d+[.,]?%d*)"
    local EFFECT_VALUE = "(%d+[.,]?%d*%%?)"
    local EFFECT_SUBJECT = "([%a][^%.!?;:%%]*)"
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
    local function EscapeEffectLiteral(text) return (string.gsub(text, "(%W)", "%%%1")) end
    -- Compile only literal templates and bounded named fields, once per load.
    -- A percent sign already in the template requires a bare numeric capture.
    for _, rule in ipairs(EFFECT_RULES) do
        local source = string.gsub(rule[1], "%.$", "")
        local pattern, fields, cursor = "^", {}, 1
        while true do
            local first, last, field = string.find(source, "{(%w+)}", cursor)
            if not first then break end
            local capture = EFFECT_FIELDS[field]
            if string.sub(source, last + 1, last + 1) == "%" then capture = EFFECT_NUMBER end
            pattern = pattern .. EscapeEffectLiteral(string.sub(source, cursor, first - 1)) .. capture
            table.insert(fields, field)
            cursor = last + 1
        end
        rule[1] = pattern .. EscapeEffectLiteral(string.sub(source, cursor)) .. "$"
        rule[3] = fields
    end
    local function CompactEffect(sentence)
        for _, rule in ipairs(EFFECT_RULES) do
            local matches = { string.find(sentence, rule[1]) }
            if matches[1] then
                local values = {}
                for index, field in ipairs(rule[3]) do
                    local value = matches[index + 2]
                    -- The display supplies the additional-target plus sign.
                    if field == "n" then value = string.gsub(value, "^%+", "") end
                    values[field] = value
                end
                return (string.gsub(rule[2], "{(%w+)}", function(field) return values[field] end))
            end
        end
        return nil
    end
    local function FormatEffect(description)
        local sentence = string.gsub(description, "%s+", " ")
        sentence = string.gsub(sentence, "%s+$", "")
        sentence = string.gsub(sentence, "%.$", "")
        -- Only a marker supplied by the native description establishes a cap.
        -- Keep unknown descriptions intact, including their marker and wording.
        local core, capCount = string.gsub(sentence, " %(max%)$", "")
        -- Native legendary effects can append a separate proc-rate ceiling.
        -- Retain the whole suffix, including its count and time unit.
        local first, _, rateLimit = string.find(core, "(, at most %d+ times a second)$")
        if first then core = string.sub(core, 1, first - 1) end
        core = string.gsub(core, "%.$", "")
        local formatted = CompactEffect(core)
        if formatted then return formatted .. (rateLimit or "") .. (capCount == 1 and " (max)" or "") end
        return description
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
            effectText:SetFont("DEFAULT", 13, "")
            effectText:SetTextColor(0, 1, 0)
            effectText:SetShadowColor(0, 0, 0, 1)
            effectText:SetShadowOffset(1, -1)
            effectText:SetJustifyH("LEFT")
            effectText:SetJustifyV("TOP")
            effectText:SetWidth(EFFECT_MAX_WIDTH)
            effectText:SetPoint("TOPLEFT", effectPanel, "TOPLEFT", EFFECT_PADDING, -EFFECT_PADDING)
        end
        return effectPanel
    end
    local function HideTooltip(slot)
        if hoveredSlot ~= slot then return end
        hoveredSlot = nil
        if effectPanel then
            effectPanel:Hide()
            effectText:SetText("")
        end
    end
    local function ShowTooltip(slot)
        if not inWorld or editing or not slot.id or not slot.texture or not hud:IsVisible() then return end
        hoveredSlot = slot
        local text = ReadEffects(slot)
        if not text then
            if effectPanel then
                effectPanel:Hide()
                effectText:SetText("")
            end
            return
        end
        local panel = GetEffectPanel()
        effectText:SetText(text)
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
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMLEFT", slot.button, "TOPLEFT", -EFFECT_PADDING, 12)
        panel:Show()
    end
    for index, name in ipairs(SLOT_NAMES) do
        local button = CreateFrame("Frame", nil, hud)
        button:SetWidth(ICON_SIZE)
        button:SetHeight(ICON_SIZE)
        button:SetPoint("TOPLEFT", hud, "TOPLEFT", WIDTH / 2 - ICON_SIZE / 2 + (index - 3) * columnPitch, -30.5)
        button:EnableMouse(true)
        local slot = { name = name, button = button, strips = {} }
        local socket = hud:CreateTexture(nil, "BACKGROUND")
        socket:SetTexture(texturePath .. "SocketDetached.tga")
        socket:SetWidth(socketSize)
        socket:SetHeight(socketSize)
        socket:SetPoint("CENTER", button, "CENTER", 0, 0)
        socket:SetTexCoord(0, 160 / 256, 0, 160 / 256)
        socket:Hide()
        slot.socket = socket
        -- Ordinary cropped texture strips leave real transparency outside the
        -- icon's circle, without a black corner cover or retail texture masks.
        for part = 1, 16 do
            local top, bottom = (part - 1) * 2, part * 2
            local edge = math.max(math.abs(top - 16), math.abs(bottom - 16))
            local half = math.sqrt(math.max(0, 256 - edge * edge))
            if half > 0 then
                local strip = button:CreateTexture(nil, "ARTWORK")
                strip:SetWidth(half * 2)
                strip:SetHeight(2)
                strip:SetPoint("TOPLEFT", button, "TOPLEFT", 16 - half, -top)
                strip:SetTexCoord(
                    iconInset + (16 - half) * iconSpan / ICON_SIZE,
                    iconInset + (16 + half) * iconSpan / ICON_SIZE,
                    iconInset + top * iconSpan / ICON_SIZE,
                    iconInset + bottom * iconSpan / ICON_SIZE
                )
                strip:Hide()
                table.insert(slot.strips, strip)
            end
        end
        local cooldown = button:CreateTexture(nil, "OVERLAY")
        cooldown:SetTexture(texturePath .. "Cooldown.tga")
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
        rim:SetTexture(texturePath .. "Frame.tga")
        rim:SetWidth(RIM_SIZE * 72 / 86)
        rim:SetHeight(RIM_SIZE * 72 / 86)
        rim:SetPoint("CENTER", slot.button, "CENTER", 0, 0)
        -- Trim the source rim's uneven clear padding; its visible circle is
        -- centered in this square crop rather than the full source rectangle.
        -- Compensate the crop size to preserve the visible rim's diameter.
        rim:SetTexCoord(106 / 1024, 178 / 1024, 56 / 256, 128 / 256)
    end
    local function ClearSlot(slot)
        if slot.texture then
            for _, strip in ipairs(slot.strips) do
                strip:Hide()
                strip:SetTexture(nil)
            end
        end
        slot.texture = nil
        slot.cooldown:Hide()
        slot.start, slot.duration, slot.painted = nil, nil, nil
        HideTooltip(slot)
    end
    local function Clear()
        for _, slot in ipairs(slots) do
            ClearSlot(slot)
        end
        hud:Hide()
        detached:Hide()
    end
    hud:SetScript("OnHide", function()
        if DFRL.SetJewelryBarShown then DFRL.SetJewelryBarShown(false) end
        for _, slot in ipairs(slots) do
            HideTooltip(slot)
        end
    end)
    hud:SetScript("OnShow", function()
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
        if not hud:IsVisible() then return end
        local now = type(GetTime) == "function" and GetTime() or nil
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
        end
    end
    local function Refresh()
        if
            not inWorld
            or not attached
            or not DFRL.display.Get("equippedJewelry")
            or type(UnitExists) ~= "function"
            or not UnitExists("player")
            or type(GetInventoryItemTexture) ~= "function"
            or not ResolveSlots()
        then
            Clear()
            return
        end
        for _, slot in ipairs(slots) do
            local ok, texture = pcall(GetInventoryItemTexture, "player", slot.id)
            if ok and type(texture) == "string" and texture ~= "" then
                if slot.texture ~= texture then
                    for _, strip in ipairs(slot.strips) do
                        strip:SetTexture(texture)
                        strip:Show()
                    end
                    slot.texture = texture
                end
                UpdateCooldown(slot)
                if hoveredSlot == slot then ShowTooltip(slot) end
            else
                ClearSlot(slot)
            end
        end
        if DFRL.display.Get("attachJewelry") then
            detached:Hide()
        else
            detached:Show()
        end
        hud:Show()
    end
    local function UpdateDisplay()
        local docked = DFRL.display.Get("attachJewelry")
        if attached then
            local owner = docked and DFRL.mainBar or detached
            if hud:GetParent() ~= owner then
                hud:Hide()
                hud:SetParent(owner)
            end
            hud:SetScale(docked and defaultScale or 1)
            hud:SetFrameLevel(owner:GetFrameLevel() + 2)
            hud:ClearAllPoints()
            hud:SetPoint("TOP", owner, "TOP", 0, docked and (46.5 + RIM_SIZE * 20 / 36) or 0)
            for _, slot in ipairs(slots) do
                slot.button:SetFrameLevel(hud:GetFrameLevel() + 1)
                if docked then
                    slot.socket:Hide()
                else
                    slot.socket:Show()
                end
            end
            overlay:SetFrameLevel(hud:GetFrameLevel() + 3)
        end
        local region = DFRL.actionBarMoveRegion
        if region then
            local top = actionDefaults.topInset
            if DFRL.display.Get("equippedJewelry") and docked then
                top = math.max(top, actionDefaults.buttonWidth * 40 / 36)
            end
            region:SetPoint("TOPLEFT", DFRL.mainBar, "TOPLEFT", -actionDefaults.sideInset, top)
        end
        Refresh()
        PaintCooldowns()
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
    controller:SetScript("OnUpdate", function()
        if not inWorld or not DFRL.display.Get("equippedJewelry") then return end
        elapsed = elapsed + arg1
        animationElapsed = animationElapsed + arg1
        if elapsed >= INTERVAL then
            elapsed = 0
            Refresh()
            animationElapsed = ANIMATION_INTERVAL
        end
        if animationElapsed >= ANIMATION_INTERVAL then
            animationElapsed = 0
            PaintCooldowns()
        end
    end)
    DFRL.display.Listen(UpdateDisplay)
    UpdateDisplay()
end)
