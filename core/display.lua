-- Display choices preview in the layout editor and save only with Confirm.
DFRL:NewMod("Display", 0, function()
    local display, listeners, draft = {}, {}, nil
    local defaults = {
        customBanners = true,
        petRows = 6,
        petSpacing = 4,
        hidePetNames = false,
        hidePetCounts = false,
        hidePetTimers = true,
        bossDebuffs = true,
        guardiansInBossBar = false,
        targetDebuffsOnTop = false,
        damageIcons = false,
        sctNormalHits = true,
        sctCriticalHits = true,
        sctPetDamage = true,
        sctAutoAttacks = true,
        sctDirectDamage = true,
        sctPeriodicDamage = true,
        sctReflectedDamage = true,
        sctMisses = true,
        sctClassColors = false,
        sctScale = 1,
        hidePortraits = false,
        roundPlayerPortrait = false,
        playerPortrait3D = false, -- Legacy key; controls player, target and target-of-target.
        flipBuffs = false,
        classResources = false,
        classHealth = false,
        healthLossAnimation = true,
        lockActionButtons = true,
        cooldownNumbers = true,
        cacheGuidance = true,
        guardianGuidance = true,
        mirrorCacheWaypoint = false,
        mirrorGuardianWaypoint = false,
        equippedJewelry = true,
        hideNativeBuild = true,
        attachJewelry = true,
        attachXP = true,
    }
    DFRL.display = display

    local ranges = {
        sctScale = { minimum = 0.25, maximum = 2 },
        petRows = { minimum = 1, maximum = 6, integer = true },
        petSpacing = { minimum = 0, maximum = 60, integer = true },
    }
    local function NormalizeNumber(key, value)
        if type(value) ~= "number" or value - value ~= 0 then return nil end
        local range = ranges[key]
        value = math.max(range.minimum, math.min(range.maximum, value))
        return range.integer and math.floor(value + 0.5) or value
    end
    local function Read(source, key)
        local value
        if type(source) == "table" then value = source[key] end
        if ranges[key] then return NormalizeNumber(key, value) or defaults[key] end
        if type(value) == "boolean" then return value end
        return defaults[key]
    end
    local function Normalize(source)
        return {
            customBanners = Read(source, "customBanners"),
            petRows = Read(source, "petRows"),
            petSpacing = Read(source, "petSpacing"),
            hidePetNames = Read(source, "hidePetNames"),
            hidePetCounts = Read(source, "hidePetCounts"),
            hidePetTimers = Read(source, "hidePetTimers"),
            bossDebuffs = Read(source, "bossDebuffs"),
            guardiansInBossBar = Read(source, "guardiansInBossBar"),
            targetDebuffsOnTop = Read(source, "targetDebuffsOnTop"),
            damageIcons = Read(source, "damageIcons"),
            sctNormalHits = Read(source, "sctNormalHits"),
            sctCriticalHits = Read(source, "sctCriticalHits"),
            sctPetDamage = Read(source, "sctPetDamage"),
            sctAutoAttacks = Read(source, "sctAutoAttacks"),
            sctDirectDamage = Read(source, "sctDirectDamage"),
            sctPeriodicDamage = Read(source, "sctPeriodicDamage"),
            sctReflectedDamage = Read(source, "sctReflectedDamage"),
            sctMisses = Read(source, "sctMisses"),
            sctClassColors = Read(source, "sctClassColors"),
            sctScale = Read(source, "sctScale"),
            hidePortraits = Read(source, "hidePortraits"),
            roundPlayerPortrait = Read(source, "roundPlayerPortrait"),
            playerPortrait3D = Read(source, "playerPortrait3D"),
            flipBuffs = Read(source, "flipBuffs"),
            classResources = Read(source, "classResources"),
            classHealth = Read(source, "classHealth"),
            healthLossAnimation = Read(source, "healthLossAnimation"),
            lockActionButtons = Read(source, "lockActionButtons"),
            cooldownNumbers = Read(source, "cooldownNumbers"),
            cacheGuidance = Read(source, "cacheGuidance"),
            guardianGuidance = Read(source, "guardianGuidance"),
            mirrorCacheWaypoint = Read(source, "mirrorCacheWaypoint"),
            mirrorGuardianWaypoint = Read(source, "mirrorGuardianWaypoint"),
            equippedJewelry = Read(source, "equippedJewelry"),
            hideNativeBuild = Read(source, "hideNativeBuild"),
            attachJewelry = Read(source, "attachJewelry"),
            attachXP = Read(source, "attachXP"),
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
        if ranges[key] then
            value = NormalizeNumber(key, value)
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
