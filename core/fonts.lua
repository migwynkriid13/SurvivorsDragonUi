-- DEFAULT was a port-only filename alias. Newer clients require a real font
-- file and reject SetText on a FontString whose SetFont silently failed.
-- Resolve once before any addon captions or layout handles are constructed.
local defaultFont = CreateFont("SurvivorsDragonUiDefaultFont")
local function TryDefault(face)
    if type(face) ~= "string" or face == "" then return end
    local success, loaded = pcall(defaultFont.SetFont, defaultFont, face, 12, "")
    if success and (loaded or defaultFont:GetFont() == face) then return face end
end
local nativeFace = GameFontNormal and GameFontNormal:GetFont()
local defaultFace = TryDefault("DEFAULT")
    or TryDefault(nativeFace)
    or TryDefault(STANDARD_TEXT_FONT)
    or TryDefault("Fonts\\FRIZQT__.TTF")
if not defaultFace then error("SurvivorsDragonUi: the client has no usable default font") end

function DFRL.tools.GetDefaultFont() return defaultFace end
function DFRL.tools.SetFont(object, size, flags)
    -- A size derived from a not-yet-resolved native region can be zero. On the
    -- current client that frees a FontString's font instead of initializing it.
    if type(size) ~= "number" or size <= 0 or size - size ~= 0 then size = 12 end
    return object:SetFont(defaultFace, size, flags or "")
end

-- Keep stock font sizes and styling while using the resolved game font face.
DFRL:NewMod("Fonts", 0, function()
    _G.STANDARD_TEXT_FONT = defaultFace
    _G.UNIT_NAME_FONT = defaultFace
    _G.DAMAGE_TEXT_FONT = defaultFace
    _G.NAMEPLATE_FONT = defaultFace
    for _, object in pairs(_G) do
        local kind = type(object)
        if
            (kind == "table" or kind == "userdata")
            and object.GetObjectType
            and object:GetObjectType() == "Font"
            and object.GetFont
            and object.SetFont
        then
            local _, size, flags = object:GetFont()
            if type(size) == "number" and size > 0 then T.SetFont(object, size, flags) end
        end
    end
end)
