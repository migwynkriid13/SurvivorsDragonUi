--[[
Shared native-tooltip styling and unit colors.
Adapted implementation source commit: 623eca5893c9d475a7b77bd25808bdbe801d247c.
Source provenance: third_party/Tooltip-STYLE.md.
Targeting text and tooltip health bars are omitted at the user's request.
No Wrath module framework, settings or runtime dependency is used.
Native World of Warcraft interface textures are Copyright Blizzard Entertainment,
Inc.; those game assets are distinct from the MIT-licensed implementation below.

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
]]

setfenv(1, DFRL:GetEnv())

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local BORDER_R, BORDER_G, BORDER_B = 0.6, 0.66, 0.74

function DFRL.tools.StyleHoverCard(frame, red, green, blue)
    if not frame.sduiHoverSkin then
        frame:SetBackdrop(BACKDROP)
        frame.sduiHoverSkin = true
    end
    local r, g, b, a
    if frame.GetBackdropColor then
        r, g, b, a = frame:GetBackdropColor()
    end
    if
        not T.NearlyEqual(r, 0.04)
        or not T.NearlyEqual(g, 0.04)
        or not T.NearlyEqual(b, 0.08)
        or not T.NearlyEqual(a, 0.98)
    then
        frame:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
    end
    red, green, blue = red or BORDER_R, green or BORDER_G, blue or BORDER_B
    r, g, b, a = nil, nil, nil, nil
    if frame.GetBackdropBorderColor then
        r, g, b, a = frame:GetBackdropBorderColor()
    end
    if
        not T.NearlyEqual(r, red)
        or not T.NearlyEqual(g, green)
        or not T.NearlyEqual(b, blue)
        or not T.NearlyEqual(a, 1)
    then
        frame:SetBackdropBorderColor(red, green, blue, 1)
    end
end

function DFRL.tools.CreateHoverCard(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:EnableMouse(false)
    frame:SetFrameStrata("TOOLTIP")
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    DFRL.tools.StyleHoverCard(frame)
    return frame
end

local registeredIcons, iconAnchors, iconSides = {}, {}, {}
local unitAuraIcons = {}
function DFRL.tools.GetUnitAuraIcons(unit) return unitAuraIcons[unit] end
function DFRL.tools.RegisterTooltipIcon(button, icon, side)
    if not button or registeredIcons[button] then return end
    registeredIcons[button] = button
    iconAnchors[button] = icon or button
    iconSides[button] = side
    HookScript(button, "OnHide", function()
        if GameTooltip and GameTooltip:IsOwned(button) and GameTooltip:IsShown() then GameTooltip:Hide() end
    end)
end

local function PositiveScale(value) return type(value) == "number" and value - value == 0 and value > 0 end

function DFRL.tools.PlaceHoverAtCursor(frame)
    if type(_G.GetCursorPosition) ~= "function" then return false end
    local ok, cursorX, cursorY = pcall(_G.GetCursorPosition)
    local scale, uiScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if
        not ok
        or type(cursorX) ~= "number"
        or cursorX - cursorX ~= 0
        or type(cursorY) ~= "number"
        or cursorY - cursorY ~= 0
        or not PositiveScale(scale)
        or not PositiveScale(uiScale)
    then
        return false
    end
    -- Cursor pixels and the relative frame's origin must use this card's scale.
    local x = (cursorX - (UIParent:GetLeft() or 0) * uiScale) / scale + 12
    local y = (cursorY - (UIParent:GetBottom() or 0) * uiScale) / scale + 12
    local point, relative, relativePoint, previousX, previousY = frame:GetPoint(1)
    if
        frame:GetNumPoints() ~= 1
        or point ~= "BOTTOMLEFT"
        or relative ~= UIParent
        or relativePoint ~= "BOTTOMLEFT"
        or not T.NearlyEqual(previousX, x)
        or not T.NearlyEqual(previousY, y)
    then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
    return true
end

DFRL:NewMod("Tooltips", 2, function()
    local tooltip, bar = GameTooltip, GameTooltipStatusBar
    if not tooltip then return end
    local currentUnit
    local lastIconOwner
    local elapsed, inWorld = 0, true
    local editing = false
    -- A stable, passive edit region exists even when no native hover is shown.
    -- Keep GameTooltip's parent and owner native; neither controls this handle.
    local root = CreateFrame("Frame", nil, UIParent)
    root:SetWidth(240)
    root:SetHeight(64)
    root:SetScale(tooltip:GetEffectiveScale() / UIParent:GetEffectiveScale())
    root:EnableMouse(false)

    local function IconOwner(buttons)
        if not buttons then return end
        for _, button in pairs(buttons) do
            if tooltip:IsOwned(button) then return button end
        end
    end

    -- Stock target aura buttons already exist when modules initialize.
    -- Discover their actual extent once instead of repeating native slot counts.
    for _, source in ipairs({
        { "TargetFrameBuff", "target" },
        { "TargetFrameDebuff", "target" },
        { "TargetofTargetFrameDebuff", "targettarget" },
    }) do
        local prefix, unit = source[1], source[2]
        local buttons = unitAuraIcons[unit] or {}
        unitAuraIcons[unit] = buttons
        local index = 1
        while _G[prefix .. index] do
            local button = _G[prefix .. index]
            T.RegisterTooltipIcon(button, nil, "below")
            table.insert(buttons, button)
            index = index + 1
        end
    end

    local function PlaceTooltip()
        if not inWorld or editing or not root:IsVisible() then
            if tooltip:IsShown() then tooltip:Hide() end
            return
        end
        local parent = tooltip:GetParent() or UIParent
        local scale = root:GetEffectiveScale() / parent:GetEffectiveScale()
        if not T.NearlyEqual(tooltip:GetScale(), scale) then tooltip:SetScale(scale) end
        local anchor, target, targetPoint, offsetY = "BOTTOMRIGHT", root, "BOTTOMRIGHT", 0
        -- Native ownership follows registered skill, equipment and HUD icons.
        -- Other hovers keep their shared layout seat.
        local button = lastIconOwner
        if not button or not tooltip:IsOwned(button) then
            button = IconOwner(DFRL.actionButtons) or IconOwner(DFRL.characterItemButtons) or IconOwner(registeredIcons)
            lastIconOwner = button
        end
        if button and not button:IsVisible() then
            tooltip:Hide()
            return
        end
        if
            (DFRL.display.Get("tooltipAtCursor") or (button and iconSides[button] == "cursor"))
            and T.PlaceHoverAtCursor(tooltip)
        then
            return
        end
        if button then
            anchor, target, targetPoint, offsetY = "BOTTOM", iconAnchors[button] or button, "TOP", 12
            if iconSides[button] == "below" then
                anchor, targetPoint, offsetY = "TOP", "BOTTOM", -12
            end
        end
        local point, relative, relativePoint, x, y
        if tooltip:GetNumPoints() == 1 then
            point, relative, relativePoint, x, y = tooltip:GetPoint(1)
        end
        if point ~= anchor or relative ~= target or relativePoint ~= targetPoint or x ~= 0 or y ~= offsetY then
            tooltip:ClearAllPoints()
            tooltip:SetPoint(anchor, target, targetPoint, 0, offsetY)
        end
    end

    DFRL.layout.Register("tooltip", root, function(frame)
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 64)
    end, {
        onEdit = function(active)
            editing = active
            tooltip:Hide()
        end,
        onResize = function()
            if tooltip:IsShown() then PlaceTooltip() end
        end,
        onReset = function() tooltip:Hide() end,
    })
    -- Visibility previews must clear the current hover, without revealing a
    -- retired subject when the user unhides the group later.
    HookScript(root, "OnHide", function() tooltip:Hide() end)
    DFRL.display.Listen(function()
        if tooltip:IsShown() then PlaceTooltip() end
    end)
    if tooltip.SetClampedToScreen then tooltip:SetClampedToScreen(true) end

    -- SetOwner runs before native content builders. Preserve its owner and
    -- return, but prevent owner-relative/cursor placement from reclaiming it.
    local nativeSetOwner = tooltip.SetOwner
    tooltip.SetOwner = function(self, owner, anchor, x, y)
        return nativeSetOwner(self, owner, self == tooltip and inWorld and "ANCHOR_NONE" or anchor, x, y)
    end
    if type(tooltip.FadeOut) == "function" then
        local nativeFadeOut = tooltip.FadeOut
        tooltip.FadeOut = function(self)
            if self == tooltip and inWorld then return self:Hide() end
            return nativeFadeOut(self)
        end
    end
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(frame)
        if frame == tooltip then PlaceTooltip() end
    end)
    HookScript(tooltip, "OnTooltipSetDefaultAnchor", PlaceTooltip)

    local function Exists(unit)
        if type(unit) ~= "string" or type(UnitExists) ~= "function" then return false end
        local ok, exists = pcall(UnitExists, unit)
        return ok and (exists == true or exists == 1)
    end
    local function PlayerColor(unit)
        if type(UnitIsPlayer) ~= "function" or not UnitIsPlayer(unit) or type(UnitClass) ~= "function" then return end
        local _, class = UnitClass(unit)
        local color = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    local function UnitColor(unit)
        local red, green, blue = PlayerColor(unit)
        if red then return red, green, blue end
        local reaction = type(UnitReaction) == "function" and UnitReaction(unit, "player")
        if type(reaction) ~= "number" then return BORDER_R, BORDER_G, BORDER_B end
        if reaction >= 5 then return 0.2, 0.8, 0.2 end
        if reaction == 4 then return 1, 1, 0 end
        return 1, 0.2, 0.2
    end
    local function Refresh()
        if not tooltip:IsVisible() then return end
        if bar and bar:IsShown() then bar:Hide() end
        if inWorld and Exists(currentUnit) then
            local red, green, blue = UnitColor(currentUnit)
            DFRL.tools.StyleHoverCard(tooltip, red, green, blue)
            red, green, blue = PlayerColor(currentUnit)
            if red and GameTooltipTextLeft1 then
                local r, g, b, a = GameTooltipTextLeft1:GetTextColor()
                if
                    not T.NearlyEqual(r, red)
                    or not T.NearlyEqual(g, green)
                    or not T.NearlyEqual(b, blue)
                    or (a and not T.NearlyEqual(a, 1))
                then
                    GameTooltipTextLeft1:SetTextColor(red, green, blue)
                end
            end
        else
            DFRL.tools.StyleHoverCard(tooltip)
        end
    end
    local function Clear()
        currentUnit, lastIconOwner, elapsed = nil, nil, 0
        DFRL.tools.StyleHoverCard(tooltip)
        if bar and bar:IsShown() then bar:Hide() end
    end

    DFRL.tools.StyleHoverCard(tooltip)
    HookScript(tooltip, "OnTooltipCleared", Clear)
    HookScript(tooltip, "OnHide", Clear)
    HookScript(tooltip, "OnShow", function()
        PlaceTooltip()
        Refresh()
    end)
    HookScript(tooltip, "OnUpdate", function()
        if not tooltip:IsVisible() then return end
        -- World hover loss can start a native fade without a Lua FadeOut call.
        if currentUnit == "mouseover" and not Exists("mouseover") then
            tooltip:Hide()
            return
        end
        PlaceTooltip()
        elapsed = elapsed + (type(arg1) == "number" and arg1 or 0)
        if elapsed < 0.2 then return end
        elapsed = 0
        Refresh()
    end)
    if bar then
        if bar:IsShown() then bar:Hide() end
        -- Native unit builders can show it again on every hover rebuild.
        HookScript(bar, "OnShow", function() bar:Hide() end)
    end

    -- 1.12 exposes SetUnit, not Wrath's GetUnit/OnTooltipSetUnit pair.
    -- Preserve SetUnit's native 1-or-nil result and identify only this tooltip.
    if type(tooltip.SetUnit) == "function" then
        local nativeSetUnit = tooltip.SetUnit
        tooltip.SetUnit = function(self, unit)
            local result = nativeSetUnit(self, unit)
            if self == tooltip then
                currentUnit = result and unit or nil
                Refresh()
            end
            return result
        end
    end
    -- FrameXML may recolor the name after SetUnit returns.
    hooksecurefunc("UnitFrame_UpdateTooltip", function()
        if this and Exists(this.unit) and tooltip:IsOwned(this) then
            currentUnit = this.unit
            Refresh()
        end
    end)
    local events = CreateFrame("Frame", nil, UIParent)
    events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LEAVING_WORLD")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            -- The native world-unit builder emits this after rebuilding its
            -- tooltip. Do not guess a unit from a spell/item hover or name text.
            if inWorld and tooltip:IsVisible() and Exists("mouseover") then
                currentUnit = "mouseover"
                Refresh()
            end
        else
            inWorld = false
            tooltip:Hide()
            Clear()
        end
    end)
end)
