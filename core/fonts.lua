-- Keep stock font sizes and styling while using the game port's font face.
DFRL:NewMod("Fonts", 0, function()
    _G.STANDARD_TEXT_FONT = "DEFAULT"
    _G.UNIT_NAME_FONT = "DEFAULT"
    _G.DAMAGE_TEXT_FONT = "DEFAULT"
    _G.NAMEPLATE_FONT = "DEFAULT"
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
            object:SetFont("DEFAULT", size or 12, flags or "")
        end
    end
end)
