--[[
Tooltip presentation adapted from PentSec/DragonUI, modules/tooltip.lua,
commit 623eca5893c9d475a7b77bd25808bdbe801d247c.
Only its native-tooltip styling and unit colors are adapted.
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
    frame:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
    frame:SetBackdropBorderColor(red or BORDER_R, green or BORDER_G, blue or BORDER_B, 1)
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

DFRL:NewMod("Tooltips", 2, function()
    local tooltip, bar = GameTooltip, GameTooltipStatusBar
    if not tooltip then return end
    local currentUnit
    local elapsed, inWorld = 0, true

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
        if bar then bar:Hide() end
        if inWorld and Exists(currentUnit) then
            local red, green, blue = UnitColor(currentUnit)
            DFRL.tools.StyleHoverCard(tooltip, red, green, blue)
            red, green, blue = PlayerColor(currentUnit)
            if red and GameTooltipTextLeft1 then GameTooltipTextLeft1:SetTextColor(red, green, blue) end
        else
            DFRL.tools.StyleHoverCard(tooltip)
        end
    end
    local function Clear()
        currentUnit, elapsed = nil, 0
        DFRL.tools.StyleHoverCard(tooltip)
        if bar then bar:Hide() end
    end

    DFRL.tools.StyleHoverCard(tooltip)
    HookScript(tooltip, "OnTooltipCleared", Clear)
    HookScript(tooltip, "OnHide", Clear)
    HookScript(tooltip, "OnShow", Refresh)
    HookScript(tooltip, "OnUpdate", function()
        elapsed = elapsed + (type(arg1) == "number" and arg1 or 0)
        if elapsed < 0.2 then return end
        elapsed = 0
        Refresh()
    end)
    if bar then
        bar:Hide()
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
