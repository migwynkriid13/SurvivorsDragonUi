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

-- Chat and run banners share the same resolved native face and styling.
function DFRL.tools.SetChatFont(frame)
    local font, size, flags
    if frame.GetFont then font, size, flags = frame:GetFont() end
    if font ~= defaultFace or not DFRL.tools.NearlyEqual(size, 12) or flags ~= "OUTLINE" then
        DFRL.tools.SetFont(frame, 12, "OUTLINE")
    end
end

function DFRL.tools.SetChatShadow(frame)
    if frame.SetShadowColor then
        local r, g, b, a
        if frame.GetShadowColor then r, g, b, a = frame:GetShadowColor() end
        if r ~= 0 or g ~= 0 or b ~= 0 or a ~= 1 then frame:SetShadowColor(0, 0, 0, 1) end
    end
    if frame.SetShadowOffset then
        local x, y
        if frame.GetShadowOffset then x, y = frame:GetShadowOffset() end
        if not DFRL.tools.NearlyEqual(x, 1) or not DFRL.tools.NearlyEqual(y, -1) then frame:SetShadowOffset(1, -1) end
    end
end

-- Keep stock font sizes and styling while using the resolved game font face.
DFRL:NewMod("Fonts", 0, function()
    _G.STANDARD_TEXT_FONT = defaultFace
    _G.UNIT_NAME_FONT = defaultFace
    _G.DAMAGE_TEXT_FONT = defaultFace
    _G.NAMEPLATE_FONT = defaultFace
    local function UpdateNativeFont(object)
        if object.GetObjectType and object:GetObjectType() == "Font" and object.GetFont and object.SetFont then
            local _, size, flags = object:GetFont()
            if type(size) == "number" and size > 0 then T.SetFont(object, size, flags) end
        end
    end
    for _, object in pairs(_G) do
        local kind = type(object)
        -- Native globals can retain retired widget wrappers. Even GetObjectType
        -- can raise on those; skip that object without aborting the font pass.
        if kind == "table" or kind == "userdata" then pcall(UpdateNativeFont, object) end
    end
end)
