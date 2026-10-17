-- Equipped jewelry only; the native six-pickup build remains visible for comparison.
--[[
Design 20 (Reliquary) combines original capsule geometry with Blizzard game
artwork. Texture conversion does not change the underlying artwork's ownership.
No upstream Lua is imported. Sources and preparation: third_party/Jewelry-ARTWORK.md.

Gold circular rim: Karl-HeinzSchneider/WoW-DragonflightUI
b8b35451d4621a8097e887385f72ec03e17765f1, Textures/bagborder2.blp.
Filigree: PentSec/DragonUI 623eca5893c9d475a7b77bd25808bdbe801d247c,
DragonUI/Textures/Collections/IconFrameGold.tga, crop (0,90,114,123).
Stone: Stormhand-dev/DragonflightUI-Reforged
2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8,
media/tex/castbar/CastingBarBackground.blp.
Fine trim: already attributed Blizzard WidgetStatusBar border-center artwork.

Applicable source notices (Blizzard artwork is distinct from MIT software):
MIT License
Copyright (c) 2022 Karl-HeinzSchneider
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
]]
DFRL:NewMod("Jewelry", 4, function()
    local WIDTH, HEIGHT, ICON_SIZE, INTERVAL = 317, 88, 32, 0.2
    local SLOT_NAMES = { "NeckSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
    local slots, slotsReady = {}, false
    local inWorld, editing, elapsed = true, false, 0
    local hud = CreateFrame("Frame", "SurvivorsDragonUiJewelry", UIParent)
    hud:SetWidth(WIDTH)
    hud:SetHeight(HEIGHT)
    hud:SetFrameStrata("HIGH")
    hud:EnableMouse(false)
    hud:Hide()

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function HideTooltip(slot)
        if GameTooltip and GameTooltip:IsOwned(slot.button) then GameTooltip:Hide() end
    end
    local function ShowTooltip(slot)
        if not inWorld or editing or not slot.id or not hud:IsVisible() then return end
        if not GameTooltip or type(GameTooltip.SetInventoryItem) ~= "function" then return end
        GameTooltip:SetOwner(slot.button, "ANCHOR_RIGHT")
        local ok, hasItem = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", slot.id)
        if ok and (hasItem == true or hasItem == 1) then
            GameTooltip:Show()
        else
            GameTooltip:Hide()
        end
    end
    for index, name in ipairs(SLOT_NAMES) do
        local button = CreateFrame("Frame", nil, hud)
        button:SetWidth(ICON_SIZE)
        button:SetHeight(ICON_SIZE)
        button:SetPoint("TOPLEFT", hud, "TOPLEFT", 54.5 + (index - 1) * 44, -30.5)
        button:EnableMouse(true)
        local empty = button:CreateTexture(nil, "BACKGROUND")
        empty:SetTexture("Interface\\Buttons\\WHITE8X8")
        empty:SetVertexColor(17 / 255, 24 / 255, 24 / 255)
        empty:SetAllPoints(button)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(3 / 64, 61 / 64, 3 / 64, 61 / 64)
        icon:Hide()
        local slot = { name = name, button = button, icon = icon }
        -- The 1.12 stock cooldown template is a Model, not a retail Cooldown frame.
        if type(CooldownFrame_SetTimer) == "function" then
            local ok, cooldown = pcall(CreateFrame, "Model", nil, button, "CooldownFrameTemplate")
            if ok and cooldown then
                cooldown:ClearAllPoints()
                cooldown:SetAllPoints(button)
                cooldown:EnableMouse(false)
                cooldown:SetFrameLevel(hud:GetFrameLevel() + 2)
                cooldown:Hide()
                slot.cooldown = cooldown
            end
        end
        button:SetScript("OnEnter", function() ShowTooltip(slot) end)
        button:SetScript("OnLeave", function() HideTooltip(slot) end)
        button:SetScript("OnHide", function() HideTooltip(slot) end)
        -- These are read-only hover frames: no equipment-use, pickup or drag handlers.
        table.insert(slots, slot)
    end

    -- Put the opaque socket corners above icons AND native cooldown models.
    -- Circular alpha apertures avoid relying on unavailable retail mask APIs.
    local overlay = CreateFrame("Frame", nil, hud)
    overlay:SetAllPoints(hud)
    overlay:SetFrameLevel(hud:GetFrameLevel() + 3)
    overlay:EnableMouse(false)
    local artwork = overlay:CreateTexture(nil, "OVERLAY")
    artwork:SetTexture(DFRL:GetInfoOrCons("tex") .. "jewelry\\Frame.tga")
    artwork:SetAllPoints(overlay)
    artwork:SetTexCoord(0, WIDTH / 512, 0, HEIGHT / 128)
    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont("DEFAULT", 10, "OUTLINE")
    label:SetTextColor(0.76, 0.67, 0.46)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    label:SetPoint("TOPLEFT", hud, "TOPLEFT", 50, -3)
    label:SetText("JEWELRY")

    local function ClearSlot(slot)
        slot.texture = nil
        slot.icon:Hide()
        slot.icon:SetTexture(nil)
        if slot.cooldown then slot.cooldown:Hide() end
        slot.start, slot.duration, slot.enabled = nil, nil, nil
        HideTooltip(slot)
    end
    local function Clear()
        for _, slot in ipairs(slots) do
            ClearSlot(slot)
        end
        hud:Hide()
    end
    hud:SetScript("OnHide", function()
        for _, slot in ipairs(slots) do
            HideTooltip(slot)
        end
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
        if not slot.cooldown then return end
        if type(GetInventoryItemCooldown) ~= "function" or type(CooldownFrame_SetTimer) ~= "function" then
            slot.cooldown:Hide()
            slot.start, slot.duration, slot.enabled = nil, nil, nil
            return
        end
        local ok, start, duration, enabled = pcall(GetInventoryItemCooldown, "player", slot.id)
        if not ok or not Number(start) or not Number(duration) or not Number(enabled) then
            slot.cooldown:Hide()
            slot.start, slot.duration, slot.enabled = nil, nil, nil
            return
        end
        if slot.start ~= start or slot.duration ~= duration or slot.enabled ~= enabled then
            local applied = pcall(CooldownFrame_SetTimer, slot.cooldown, start, duration, enabled)
            if applied then
                slot.start, slot.duration, slot.enabled = start, duration, enabled
            else
                slot.cooldown:Hide()
            end
        end
    end
    local function Refresh()
        if
            not inWorld
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
                    slot.icon:SetTexture(texture)
                    slot.texture = texture
                    slot.start, slot.duration, slot.enabled = nil, nil, nil
                end
                slot.icon:Show()
                UpdateCooldown(slot)
                if GameTooltip and GameTooltip:IsOwned(slot.button) then ShowTooltip(slot) end
            else
                ClearSlot(slot)
            end
        end
        hud:Show()
    end
    local actionDefaults = DFRL.actionBarDefaults
    local bottom = actionDefaults and actionDefaults.bottom + actionDefaults.height + actionDefaults.topInset + 12 or 117
    DFRL.layout.Register("jewelryBar", hud, function()
        hud:ClearAllPoints()
        hud:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, bottom)
    end, {
        onEdit = function(active)
            editing = active
            if editing then
                for _, slot in ipairs(slots) do
                    HideTooltip(slot)
                end
            end
        end,
    })
    local controller = CreateFrame("Frame", nil, UIParent)
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("UNIT_INVENTORY_CHANGED")
    controller:RegisterEvent("BAG_UPDATE_COOLDOWN")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            elapsed = 0
            Clear()
        elseif event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            elapsed = 0
            Clear()
            Refresh()
        elseif event ~= "UNIT_INVENTORY_CHANGED" or arg1 == "player" then
            elapsed = INTERVAL
        end
    end)
    controller:SetScript("OnUpdate", function()
        if not inWorld then return end
        elapsed = elapsed + arg1
        if elapsed < INTERVAL then return end
        elapsed = 0
        Refresh()
    end)
    Refresh()
end)
