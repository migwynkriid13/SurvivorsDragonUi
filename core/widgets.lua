setfenv(1, DFRL:GetEnv())

function DFRL.tools.GradientLine(frame)
    local width = (frame:GetWidth() - 10) / 2
    for _, side in ipairs({"LEFT", "RIGHT"}) do
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        texture:SetPoint("TOP", frame, "TOP", 0, -2)
        texture:SetPoint(side == "LEFT" and "RIGHT" or "LEFT", frame, "TOP", 0, -2)
        texture:SetWidth(width)
        texture:SetHeight(3)
        if side == "LEFT" then
            texture:SetGradientAlpha("HORIZONTAL", 1,0.82,0,0, 1,0.82,0,1)
        else
            texture:SetGradientAlpha("HORIZONTAL", 1,0.82,0,1, 1,0.82,0,0)
        end
    end
end

function DFRL.tools.CreateDFRLFrame(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
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
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    button:SetBackdropColor(0, 0, 0, 0.5)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFont("DEFAULT", 12, "OUTLINE")
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

-- Reuse the original 256x128 portrait sheet, omitting its internal power-bar
-- divider. Both large unit frames share one health fill across the full opening.
function DFRL.tools.CreateHealthOnlyUnitBorder(frame, healthBar, portraitTexture, background, texturePath, portraitSide)
    local mirrored = portraitSide == "LEFT"
    -- Keep the original shading, cropping off the texture's transparent padding.
    healthBar:SetStatusBarTexture(DFRL:GetInfoOrCons("tex") .. "unitframes\\healthDF2.tga")
    healthBar:SetWidth(mirrored and 122 or 137)
    healthBar:SetHeight(29)
    healthBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    healthBar:ClearAllPoints()
    if mirrored then
        healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 104, -34)
    else
        -- Extend beneath the target's curved portrait edge without moving the far end.
        healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -89, -34)
    end

    local function CropHealthFill()
        local fill = healthBar:GetStatusBarTexture()
        if fill then fill:SetTexCoord(4.5 / 128, 123.5 / 128, 5 / 32, 25 / 32) end
    end
    HookScript(healthBar, "OnValueChanged", CropHealthFill)
    CropHealthFill()

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
    if not mirrored then
        -- Keep the face and circular rim above both the extended fill and damage loss.
        portraitTexture:SetParent(borderFrame)
        if frame.portrait then
            frame.portrait:SetParent(borderFrame)
            frame.portrait:SetDrawLayer("ARTWORK")
        end
    end
    portraitTexture:SetWidth(104)
    portraitTexture:SetHeight(128)
    portraitTexture:ClearAllPoints()
    if mirrored then
        portraitTexture:SetTexCoord(1, 152 / 256, 0, 1)
        portraitTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    else
        portraitTexture:SetTexCoord(152 / 256, 1, 0, 1)
        portraitTexture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    end
    portraitTexture:SetVertexColor(1, 1, 1, 1)
    portraitTexture:SetDrawLayer("OVERLAY")

    local strips = {}
    local function AddStrip(x, y, width, height)
        local strip = borderFrame:CreateTexture(nil, "OVERLAY")
        strip:SetWidth(width)
        strip:SetHeight(height)
        if mirrored then
            strip:SetTexCoord((x + width) / 256, x / 256, y / 128, (y + height) / 128)
            strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 256 - x - width, -y)
        else
            strip:SetTexCoord(x / 256, (x + width) / 256, y / 128, (y + height) / 128)
            strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(256 - x - width), -y)
        end
        table.insert(strips, strip)
    end
    -- Retain top/bottom artwork and the outer end cap. The former horizontal
    -- divider lies in the omitted interior (x30..152, y34..63).
    AddStrip(0, 0, 152, 34)
    AddStrip(0, 63, 152, 65)
    AddStrip(0, 34, 30, 29)

    local function UpdateTexture(path)
        portraitTexture:SetTexture(path)
        for _, strip in ipairs(strips) do strip:SetTexture(path) end
    end
    UpdateTexture(texturePath)
    return UpdateTexture
end
