setfenv(1, DFRL:GetEnv())

-- Native screen-unit setters now round through 24-bit floats. Their getters
-- need not return the exact Lua number that was set, even at a fixed viewport.
function DFRL.tools.NearlyEqual(a, b)
    return type(a) == "number"
        and type(b) == "number"
        and a - a == 0
        and b - b == 0
        and math.abs(a - b) <= 0.000001 * math.max(1, math.abs(a), math.abs(b))
end

function DFRL.tools.SetTextIfChanged(label, text)
    local language = DFRL.locale
    local binding = language and language.labels[label]
    local value = text
    if binding then
        binding.source = text
        if type(text) == "string" then value = language.Text(text) end
    end
    if type(value) == "number" then value = tostring(value) end
    if (label:GetText() or "") == (value or "") then return false end
    if binding then
        binding.original(label, value)
    else
        label:SetText(text)
    end
    return true
end

local function EdgeExtent(first, last, fallback)
    if type(first) == "number" and type(last) == "number" then
        local extent = last - first
        if extent > 0 and extent - extent == 0 then return extent end
    end
    return fallback
end

-- Native size getters return an authored local size when set, but an already
-- scaled span for anchor-only axes. Edges consistently use the frame's own
-- units. Keep the raw getter as a fallback while edge geometry is unresolved.
function DFRL.tools.GetLocalSize(frame)
    local left, right = frame:GetLeft(), frame:GetRight()
    local bottom, top = frame:GetBottom(), frame:GetTop()
    return EdgeExtent(left, right, frame:GetWidth()), EdgeExtent(bottom, top, frame:GetHeight())
end

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

function DFRL.tools.GetUnitClassColor(unit)
    if type(UnitClass) ~= "function" then return end
    local _, class = UnitClass(unit)
    return classColors[class]
end

function DFRL.tools.GetPlayerClassColor() return T.GetUnitClassColor("player") end

-- Match live native aliases; player names are not party identity.
local playerAndPartyUnits = { "player", "party1", "party2", "party3", "party4" }
function DFRL.tools.IsPlayerOrPartyUnit(unit)
    if not UnitExists(unit) then return false end
    for _, candidate in ipairs(playerAndPartyUnits) do
        if UnitExists(candidate) then
            local same = UnitIsUnit(unit, candidate)
            if same == true or same == 1 then return true end
        end
    end
    return false
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
