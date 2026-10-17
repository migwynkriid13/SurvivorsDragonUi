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
                if GameTooltip and GameTooltip:IsOwned(slot.button) then ShowTooltip(slot) end
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
