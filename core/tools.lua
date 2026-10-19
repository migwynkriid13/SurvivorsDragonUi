setfenv(1, DFRL:GetEnv())

-- Original 1.12.1 FrameXML/Fonts.xml RAID_CLASS_COLORS:
-- https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/Fonts.xml
local classColors = {
    HUNTER = { 0.67, 0.83, 0.45 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    PRIEST = { 1, 1, 1 },
    PALADIN = { 0.96, 0.55, 0.73 },
    MAGE = { 0.41, 0.8, 0.94 },
    ROGUE = { 1, 0.96, 0.41 },
    DRUID = { 1, 0.49, 0.04 },
    SHAMAN = { 0, 112 / 255, 221 / 255 }, -- User-requested blue #0070DD.
    WARRIOR = { 0.78, 0.61, 0.43 },
}

function DFRL.tools.GetPlayerClassColor()
    if type(UnitClass) ~= "function" then return end
    local _, class = UnitClass("player")
    return classColors[class]
end

function KillFrame(frame)
    if not frame then return end
    frame:Hide()
    if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
    for _, script in ipairs({
        "OnShow",
        "OnHide",
        "OnEnter",
        "OnLeave",
        "OnMouseDown",
        "OnMouseUp",
        "OnClick",
        "OnDragStart",
        "OnDragStop",
        "OnUpdate",
        "OnEvent",
    }) do
        pcall(function() frame:SetScript(script, nil) end)
    end
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
end

function PermanentlyDisableFrame(frame)
    if not frame then return end
    KillFrame(frame)
    -- Native updates may try to show omitted widgets again.
    frame.Show = frame.Hide
    frame:SetScript("OnShow", function() frame:Hide() end)
end

function HideFrameTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then region:Hide() end
    end
end

function HookScript(frame, script, handler)
    if not frame then return end
    local previous = frame:GetScript(script)
    frame:SetScript(script, function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
        if previous then previous(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
        handler(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    end)
end

function hooksecurefunc(name, handler)
    local previous = _G[name]
    if type(previous) ~= "function" then return end
    _G[name] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        previous(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        handler(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    end
end
