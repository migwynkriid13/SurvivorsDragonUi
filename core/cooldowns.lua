setfenv(1, DFRL:GetEnv())

-- Shared ability/jewelry countdown appearance. Visual reference: Turtle
-- Dragonflight by TheLinuxITGuy, with Shagu's cooldown-number styling.
-- https://github.com/DustinChecketts/Turtle-Dragonflight/tree/b2c62e9095e1c859bff0209db09f4ff5b9884f5a
local cooldowns = { interval = 0.1, finalWindow = 0.2 }
DFRL.tools.cooldowns = cooldowns
local units = { { 86400, "d" }, { 3600, "h" }, { 60, "m" }, { 1, "" } }
local function Format(remaining)
    if remaining < 0.1 then return "0" end
    for _, unit in ipairs(units) do
        if remaining >= unit[1] or unit[1] == 1 then
            return math.ceil(remaining / unit[1]) .. DFRL.locale.Text(unit[2])
        end
    end
end

function cooldowns.Create(button, level, visualScale)
    local scale = visualScale or 1
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(level)
    overlay:EnableMouse(false)
    overlay.text = overlay:CreateFontString(nil, "OVERLAY")
    overlay.text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    T.SetFont(overlay.text, math.min(14 / scale, button:GetHeight() * 0.64), "OUTLINE")
    overlay.text:SetShadowColor(0, 0, 0, 1)
    overlay.text:SetShadowOffset(1 / scale, -1 / scale)
    overlay:Hide()
    return overlay
end

function cooldowns.Paint(overlay, remaining)
    if type(remaining) ~= "number" or remaining - remaining ~= 0 or remaining <= 0 then
        if overlay:IsShown() then overlay:Hide() end
        return
    end
    T.SetTextIfChanged(overlay.text, Format(remaining))
    local red, green, blue = 1, 1, 1
    if remaining < 1 then
        green, blue = 85 / 255, 85 / 255
    elseif math.ceil(remaining) < 5 then
        blue = 85 / 255
    end
    local currentRed, currentGreen, currentBlue, currentAlpha = overlay.text:GetTextColor()
    if
        not T.NearlyEqual(currentRed, red)
        or not T.NearlyEqual(currentGreen, green)
        or not T.NearlyEqual(currentBlue, blue)
        or (currentAlpha and not T.NearlyEqual(currentAlpha, 1))
    then
        overlay.text:SetTextColor(red, green, blue)
    end
    if not overlay:IsShown() then overlay:Show() end
    return remaining
end
