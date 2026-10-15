DFRL:NewMod("Player Auras", 2, function()
    if not Minimap or not BuffFrame then return end

    local iconSize, gap, rowGap, columns = 28, 3, 14, 6
    local width = columns * iconSize + (columns - 1) * gap
    local container = CreateFrame("Frame", "DFRL_PlayerAuras", UIParent)
    local function PlaceDefault()
        container:ClearAllPoints()
        -- Match the old position beside the minimap without following map moves.
        container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -238, -6)
    end
    PlaceDefault()
    container:SetWidth(width)
    container:SetHeight(iconSize + rowGap)

    -- Keep the native frames, buttons, and aura updates. Only their layout changes.
    local nativeFrames = {BuffFrame}
    if TemporaryEnchantFrame then table.insert(nativeFrames, TemporaryEnchantFrame) end
    for _, frame in ipairs(nativeFrames) do
        frame:SetParent(container)
        frame:SetScale(1)
    end

    local entries = {}
    local function AddButton(name)
        local button = _G[name]
        if button then table.insert(entries, {button = button, name = name}) end
    end
    -- Native indices 0-15 are helpful auras; 16-23 are harmful auras.
    for i = 0, 23 do AddButton("BuffButton" .. i) end
    AddButton("TempEnchant1")
    AddButton("TempEnchant2")

    local function PlaceNativeFrame(frame)
        local point, relative, relativePoint, x, y = frame:GetPoint(1)
        if frame:GetNumPoints() ~= 1 or point ~= "TOPLEFT" or relative ~= container
            or relativePoint ~= "TOPLEFT" or x ~= 0 or y ~= 0 then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        end
    end

    local function SizeButton(entry)
        local button, name = entry.button, entry.name
        button:SetScale(1)
        button:SetWidth(iconSize)
        button:SetHeight(iconSize)
        local icon = _G[name .. "Icon"]
        if icon then
            icon:ClearAllPoints()
            icon:SetAllPoints(button)
        end
        local border = _G[name .. "Border"]
        if border then
            border:ClearAllPoints()
            border:SetAllPoints(button)
        end
        local duration = _G[name .. "Duration"]
        if duration then
            duration:SetFont("DEFAULT", 9, "OUTLINE")
            duration:ClearAllPoints()
            duration:SetPoint("TOP", button, "BOTTOM", 0, -1)
            duration:SetWidth(iconSize)
            duration:SetHeight(12)
        end
        local count = _G[name .. "Count"]
        if count then
            count:SetFont("DEFAULT", 9, "OUTLINE")
            count:ClearAllPoints()
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        end
    end

    local previousRows
    local function Layout(force)
        -- The native enchant update re-anchors BuffFrame even when no aura changes.
        -- Restore its container anchor each time, independently of icon reflow.
        for _, frame in ipairs(nativeFrames) do PlaceNativeFrame(frame) end
        local slot = 0
        for _, entry in ipairs(entries) do
            if entry.button:IsShown() then
                if force or entry.slot ~= slot then
                    SizeButton(entry)
                    entry.button:ClearAllPoints()
                    entry.button:SetPoint("TOPRIGHT", container, "TOPRIGHT",
                        -math.mod(slot, columns) * (iconSize + gap),
                        -math.floor(slot / columns) * (iconSize + rowGap))
                    entry.slot = slot
                end
                slot = slot + 1
            else
                entry.slot = nil
            end
        end
        local rows = math.max(1, math.ceil(slot / columns))
        if rows ~= previousRows then
            container:SetHeight(rows * (iconSize + rowGap))
            previousRows = rows
        end
    end

    for _, entry in ipairs(entries) do
        HookScript(entry.button, "OnShow", function() Layout(false) end)
        HookScript(entry.button, "OnHide", function() Layout(false) end)
    end
    -- Duration settings rewrite the native second buff row and debuff anchors.
    -- Force those anchors back even when the visible buttons have not changed.
    hooksecurefunc("BuffButtons_UpdatePositions", function() Layout(true) end)
    hooksecurefunc("BuffFrame_Enchant_OnUpdate", function() Layout(false) end)
    hooksecurefunc("UIParent_ManageFramePositions", function() Layout(true) end)
    Layout(true)
    -- Aura updates resize/reflow this container without replacing its own anchor.
    DFRL.layout.Register("buffs", container, PlaceDefault)
end)
