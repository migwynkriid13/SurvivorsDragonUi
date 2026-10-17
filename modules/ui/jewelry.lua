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
    local EFFECT_MAX_WIDTH, EFFECT_PADDING = 272, 14
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
    local function CompactEffect(sentence)
        local _, _, percent = string.find(sentence, "^Increases your movement speed by (%d+[.,]?%d*)%%$")
        if percent then return "+ Movement speed: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Reduces the cooldown of your spells by (%d+[.,]?%d*)%%$")
        if percent then return "- " .. percent .. "% Cooldown" end
        _, _, percent = string.find(sentence, "^Reduces all damage taken by (%d+[.,]?%d*)%%$")
        if percent then return "- " .. percent .. "% Damage taken" end
        _, _, percent = string.find(sentence, "^Increases your maximum health by (%d+[.,]?%d*)%%$")
        if percent then return "+ Maximum health: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Improves your chance to get a critical strike by (%d+[.,]?%d*)%%$")
        if percent then return "+ Critical strike chance: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Increases the damage of your critical strikes by (%d+[.,]?%d*)%%$")
        if percent then return "+ Critical damage: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Increases the range you pick up loot from by (%d+[.,]?%d*)%%$")
        if percent then return "+ Loot pickup range: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Increases gold found by (%d+[.,]?%d*)%%$")
        if percent then return "+ Gold found: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Increases your luck by (%d+[.,]?%d*)%%$")
        if percent then return "+ Luck: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Increases the area of effect of your spells by (%d+[.,]?%d*)%%$")
        if percent then return "+ Spell area: " .. percent .. "%" end
        _, _, percent = string.find(sentence, "^Increases all damage you deal by (%d+[.,]?%d*)%%$")
        if percent then return "+ Damage dealt: " .. percent .. "%" end
        _, _, percent =
            string.find(sentence, "^Your damage, haste, shield and thorns buffs are (%d+[.,]?%d*)%% stronger$")
        if percent then return "+ Buff power: " .. percent .. "%" end
        local _, _, health = string.find(sentence, "^Restores (%d+[.,]?%d*) health per second$")
        if health then return "+ Health regen: " .. health .. "/s" end
        local _, _, ability, value = string.find(sentence, "^(%u[^%.!?;]*) strikes %+(%d+) more targets$")
        if ability then return "+ " .. ability .. " targets: " .. value end
        _, _, ability, value = string.find(sentence, "^Increases the damage of (%u[^%.!?;]*) by (%d+[.,]?%d*)%%$")
        if ability then return "+ " .. ability .. " damage: " .. value .. "%" end
        _, _, ability, value =
            string.find(sentence, "^Increases the stun duration of (%u[^%.!?;]*) by (%d+[.,]?%d*)%%$")
        if ability then return "+ " .. ability .. " stun duration: " .. value .. "%" end
        return nil
    end
    local function FormatEffect(description)
        local sentence = string.gsub(description, "%s+", " ")
        sentence = string.gsub(sentence, "%s+$", "")
        sentence = string.gsub(sentence, "%.$", "")
        -- Only a marker supplied by the native description establishes a cap.
        -- Keep unknown descriptions intact, including their marker and wording.
        local core, capCount = string.gsub(sentence, " %(max%)$", "")
        local formatted = CompactEffect(core)
        if formatted then return formatted .. (capCount == 1 and " (max)" or "") end
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
            -- Reuse the shipped Dragonflight diamond-metal chrome and gold
            -- divider. Artwork attribution is carried by core/editor.lua.
            effectPanel = DFRL.tools.CreateEditorPanel(UIParent, EFFECT_MAX_WIDTH + EFFECT_PADDING * 2, 48, 12)
            effectPanel:Hide()
            effectPanel:EnableMouse(false)
            effectPanel:SetFrameStrata("TOOLTIP")
            if effectPanel.SetClampedToScreen then effectPanel:SetClampedToScreen(true) end
            effectPanel.editorHeader:Hide()
            -- The 12-unit border's inner bevel ends near four units. Overlap
            -- the fill beneath it instead of leaving the editor's six-unit gap.
            effectPanel.editorFill:ClearAllPoints()
            effectPanel.editorFill:SetPoint("TOPLEFT", effectPanel, "TOPLEFT", 3, -3)
            effectPanel.editorFill:SetPoint("BOTTOMRIGHT", effectPanel, "BOTTOMRIGHT", -3, 3)
            local accent = DFRL.tools.EditorDivider(effectPanel, EFFECT_MAX_WIDTH)
            accent:SetPoint("TOPLEFT", effectPanel, "TOPLEFT", EFFECT_PADDING, -9)
            accent:SetPoint("TOPRIGHT", effectPanel, "TOPRIGHT", -EFFECT_PADDING, -9)
            effectText = effectPanel:CreateFontString(nil, "OVERLAY")
            effectText:SetFont("DEFAULT", 13, "")
            effectText:SetTextColor(0, 1, 0)
            effectText:SetShadowColor(0, 0, 0, 1)
            effectText:SetShadowOffset(1, -1)
            effectText:SetJustifyH("LEFT")
            effectText:SetJustifyV("TOP")
            effectText:SetWidth(EFFECT_MAX_WIDTH)
            effectText:SetPoint("TOPLEFT", effectPanel, "TOPLEFT", EFFECT_PADDING, -16)
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
        panel:SetHeight(math.max(14, effectText:GetHeight()) + 30)
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
