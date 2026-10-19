-- Display choices preview in the layout editor and save only with Confirm.
DFRL:NewMod("Display", 0, function()
    local display, listeners, draft = {}, {}, nil
    local defaults = {
        bossDebuffs = true,
        damageIcons = false,
        sctAutoAttacks = true,
        sctDirectDamage = true,
        sctPeriodicDamage = true,
        sctReflectedDamage = true,
        sctMisses = true,
        classResources = false,
        classHealth = false,
        cooldownNumbers = false,
        cacheGuidance = true,
        guardianGuidance = true,
        equippedJewelry = true,
        hideNativeBuild = true,
        attachJewelry = true,
    }
    DFRL.display = display

    local function Read(source, key)
        if type(source) == "table" and type(source[key]) == "boolean" then return source[key] end
        return defaults[key]
    end
    local function Normalize(source)
        return {
            bossDebuffs = Read(source, "bossDebuffs"),
            damageIcons = Read(source, "damageIcons"),
            sctAutoAttacks = Read(source, "sctAutoAttacks"),
            sctDirectDamage = Read(source, "sctDirectDamage"),
            sctPeriodicDamage = Read(source, "sctPeriodicDamage"),
            sctReflectedDamage = Read(source, "sctReflectedDamage"),
            sctMisses = Read(source, "sctMisses"),
            classResources = Read(source, "classResources"),
            classHealth = Read(source, "classHealth"),
            cooldownNumbers = Read(source, "cooldownNumbers"),
            cacheGuidance = Read(source, "cacheGuidance"),
            guardianGuidance = Read(source, "guardianGuidance"),
            equippedJewelry = Read(source, "equippedJewelry"),
            hideNativeBuild = Read(source, "hideNativeBuild"),
            attachJewelry = Read(source, "attachJewelry"),
        }
    end
    local function Notify()
        for _, callback in ipairs(listeners) do
            callback()
        end
    end

    function display.Get(key) return Read(draft or _G.SurvivorsDragonUiDisplay, key) end
    function display.BeginEdit()
        if not draft then draft = Normalize(_G.SurvivorsDragonUiDisplay) end
    end
    function display.Set(key, value)
        if not draft or defaults[key] == nil or type(value) ~= "boolean" or draft[key] == value then return end
        draft[key] = value
        Notify()
    end
    function display.FinishEdit(save)
        if not draft then return end
        if save then _G.SurvivorsDragonUiDisplay = Normalize(draft) end
        draft = nil
        Notify()
    end
    function display.Reset()
        _G.SurvivorsDragonUiDisplay = nil
        draft = nil
        Notify()
    end
    function display.Listen(callback)
        if type(callback) == "function" then table.insert(listeners, callback) end
    end
end)
