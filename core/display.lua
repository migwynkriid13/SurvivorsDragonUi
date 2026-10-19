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
        sctClassColors = false,
        sctScale = 1,
        roundPlayerPortrait = false,
        flipBuffs = false,
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

    local function NormalizeScale(value)
        if type(value) ~= "number" or value - value ~= 0 then return nil end
        return math.max(0.25, math.min(2, value))
    end
    local function Read(source, key)
        local value
        if type(source) == "table" then value = source[key] end
        if key == "sctScale" then return NormalizeScale(value) or defaults.sctScale end
        if type(value) == "boolean" then return value end
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
            sctClassColors = Read(source, "sctClassColors"),
            sctScale = Read(source, "sctScale"),
            roundPlayerPortrait = Read(source, "roundPlayerPortrait"),
            flipBuffs = Read(source, "flipBuffs"),
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
        if not draft or defaults[key] == nil then return end
        if key == "sctScale" then
            value = NormalizeScale(value)
            if not value then return end
        elseif type(value) ~= "boolean" then
            return
        end
        if draft[key] == value then return end
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
