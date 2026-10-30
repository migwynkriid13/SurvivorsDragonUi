-- DEFAULT was a port-only filename alias. Newer clients require a real font
-- file and reject SetText on a FontString whose SetFont silently failed.
-- Resolve once before any addon captions or layout handles are constructed.
-- File-scope helpers keep the native environment; only the module initializer
-- is rebound. The Lua 5.0 client need not provide its own _G alias.
local globals = getfenv(0)
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

-- Track text explicitly styled by this addon, including the native Font objects
-- it already restyles. Independent selectors opt out through argument four.
local managed = setmetatable({}, { __mode = "k" })
local pendingOwners = setmetatable({}, { __mode = "k" })
local usableFaces = {}
local selectedFace, selectedChoice
local function UsableFace(face)
    if not face then return defaultFace end
    if usableFaces[face] then return usableFaces[face] end
    local loaded = TryDefault(face) or defaultFace
    usableFaces[face] = loaded
    return loaded
end
local function Bind(object, face, size, flags)
    if object.GetFont then
        local currentFace, currentSize, currentFlags = object:GetFont()
        if currentFace == face and DFRL.tools.NearlyEqual(currentSize, size) and (currentFlags or "") == flags then
            return true
        end
    end
    local ok, loaded = pcall(object.SetFont, object, face, size, flags)
    if not ok then return false end
    if loaded then return true end
    if object.GetFont then
        local actualFace, actualSize, actualFlags = object:GetFont()
        return actualFace == face and DFRL.tools.NearlyEqual(actualSize, size) and (actualFlags or "") == flags
    end
    return false
end
local function Apply(object, style)
    local face = selectedFace or UsableFace(style.base)
    local loaded = Bind(object, face, style.size, style.flags)
    -- A rejected native assignment can clear the old binding. Restore readable
    -- text and leave the request retryable through its existing owner.
    if not loaded then Bind(object, defaultFace, style.size, style.flags) end
    style.dirty = not loaded
    return loaded
end
local function RefreshPending(labels)
    for object in pairs(labels) do
        local style = managed[object]
        if style and style.dirty then pcall(Apply, object, style) end
    end
end
local function Defer(object)
    local owner = object
    if object.GetObjectType and object:GetObjectType() == "FontString" then owner = object:GetParent() end
    if not owner or not owner.GetScript or not owner.SetScript then return false end
    if owner:IsVisible() then return false end
    local labels = pendingOwners[owner]
    if not labels then
        labels = setmetatable({}, { __mode = "k" })
        pendingOwners[owner] = labels
        local previous = owner:GetScript("OnShow")
        -- Bind before the view's existing Show work measures its labels.
        owner:SetScript("OnShow", function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
            RefreshPending(labels)
            if previous then previous(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
        end)
    end
    labels[object] = true
    return true
end
local function RefreshFonts()
    local choice = DFRL.display.Get("uiFont")
    if selectedChoice == choice then return end
    selectedChoice, selectedFace = choice, nil
    for _, entry in ipairs(DFRL.display.fonts) do
        if entry.value == choice and entry.face then selectedFace = UsableFace(entry.face) end
    end
    local face = selectedFace or defaultFace
    globals.STANDARD_TEXT_FONT, globals.UNIT_NAME_FONT = face, face
    globals.DAMAGE_TEXT_FONT, globals.NAMEPLATE_FONT = face, face
    for object, style in pairs(managed) do
        style.dirty = true
        -- Retired native wrappers can reject even their visibility reads.
        pcall(function()
            if not Defer(object) then Apply(object, style) end
        end)
    end
end

function DFRL.tools.GetDefaultFont() return defaultFace end
function DFRL.tools.SetFont(object, size, flags, base)
    -- A not-yet-resolved native region can report zero, which frees its font.
    if type(size) ~= "number" or size <= 0 or size - size ~= 0 then size = 12 end
    flags = flags or ""
    if base == true then
        managed[object] = nil
        return Bind(object, defaultFace, size, flags)
    end
    local style = managed[object] or {}
    managed[object] = style
    style.size, style.flags, style.base = size, flags, base
    return Apply(object, style)
end

function DFRL.tools.SetChatFont(frame) DFRL.tools.SetFont(frame, 12, "OUTLINE") end

function DFRL.tools.SetChatShadow(frame)
    if frame.SetShadowColor then
        local r, g, b, a
        if frame.GetShadowColor then
            r, g, b, a = frame:GetShadowColor()
        end
        if r ~= 0 or g ~= 0 or b ~= 0 or a ~= 1 then frame:SetShadowColor(0, 0, 0, 1) end
    end
    if frame.SetShadowOffset then
        local x, y
        if frame.GetShadowOffset then
            x, y = frame:GetShadowOffset()
        end
        if not DFRL.tools.NearlyEqual(x, 1) or not DFRL.tools.NearlyEqual(y, -1) then frame:SetShadowOffset(1, -1) end
    end
end

-- Keep stock font sizes and styling while using the resolved game font face.
DFRL:NewMod("Fonts", 0, function()
    RefreshFonts()
    DFRL.display.Listen(RefreshFonts)
    local function UpdateNativeFont(object)
        if
            object ~= defaultFont
            and object.GetObjectType
            and object:GetObjectType() == "Font"
            and object.GetFont
            and object.SetFont
        then
            local _, size, flags = object:GetFont()
            if type(size) == "number" and size > 0 then T.SetFont(object, size, flags) end
        end
    end
    for _, object in pairs(globals) do
        local kind = type(object)
        -- Native globals can retain retired widget wrappers. Even GetObjectType
        -- can raise on those; skip that object without aborting the font pass.
        if kind == "table" or kind == "userdata" then pcall(UpdateNativeFont, object) end
    end
end)
