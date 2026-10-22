-- Shared ownership of a native HUD preference while its replacement is ready.
function DFRL.tools.NewHudOwner(part, cvar)
    local owner = {}
    local preference, applying

    local function Shown(value)
        if value == true or value == 1 or value == "1" then return true end
        if value == false or value == 0 or value == "0" then return false end
    end
    function owner.Read()
        if type(AZS_IsHudShown) ~= "function" then return nil end
        local ok, value = pcall(AZS_IsHudShown, part)
        if ok then return Shown(value) end
    end
    local function Write(shown)
        if applying or type(AZS_SetHudShown) ~= "function" then return false end
        applying = true
        local ok = pcall(AZS_SetHudShown, part, shown)
        applying = false
        return ok
    end
    function owner.IsCaptured() return preference ~= nil end
    function owner.Acquire()
        if type(AZS_SetHudShown) ~= "function" then return false end
        local shown = owner.Read()
        if shown == nil then return false end
        if preference == nil then preference = shown end
        if shown and (not Write(false) or owner.Read() ~= false) then return false end
        return true
    end
    function owner.Release()
        if preference == nil then return true end
        local current = owner.Read()
        if current == nil then return false end
        -- Restore only our suppression; a later visible external choice wins.
        if current == false and current ~= preference then
            if not Write(preference) or owner.Read() ~= preference then return false end
        end
        preference = nil
        return true
    end
    function owner.Observe(name)
        if applying or type(name) ~= "string" or string.lower(name) ~= string.lower(cvar) then return false end
        if preference ~= nil then
            local shown = owner.Read()
            if shown ~= nil then preference = shown end
        end
        return true
    end
    return owner
end
