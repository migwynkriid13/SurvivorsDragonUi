-- Display choices preview in the layout editor and save only with Confirm.
DFRL:NewMod("Display", 0, function()
    local display, listeners, draft = {}, {}, nil
    local defaults = {
        performanceMode = false,
        meterEnabled = false,
        meterRows = 6,
        layoutShowGrid = true,
        meterFontSize = 11,
        meterDpsWindow = 10,
        bossRows = 0,
        guardianRows = 0,
        guardianShowDead = true,
        guardianShowCurrentHealth = true,
        guardianShowMaximumHealth = true,
        meterShowDamage = false,
        meterShowDps = true,
        meterShowPercentage = false,
        meterShowIcons = true,
        meterShowRanks = false,
        meterShowTotal = true,
        meterShowTotalDps = true,
        customBanners = true,
        customRunTimer = true,
        attachAffixes = true,
        customBossBars = true,
        lootMode = "sdui",
        lootShowMarks = true,
        petRows = 6,
        petSpacing = 4,
        hidePetNames = false,
        hidePetCounts = false,
        hidePetTimers = true,
        bossDebuffs = true,
        bossShowCurrentHealth = true,
        bossShowMaximumHealth = true,
        runTextRegular = true,
        runTextEndless = true,
        runCurrentRegular = true,
        runCurrentEndless = true,
        runMaximumRegular = true,
        bossCountdownEndless = true,
        bossCountdownRegular = false,
        guardiansInBossBar = false,
        nameplatesBossGuardiansOnly = false,
        nameplatesNamesOnly = false,
        nameplateFontSize = 9,
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
        sctMSBTStyle = false,
        sctScale = 1,
        hidePortraits = false,
        showPlayerName = true,
        showPlayerLevel = true,
        showTargetName = true,
        showTargetLevel = true,
        showHealthValue = true,
        showHealthPercentage = false,
        roundPlayerPortrait = false,
        playerPortrait3D = false, -- Legacy key; controls player, target and target-of-target.
        flipBuffs = false,
        tooltipAtCursor = false,
        classResources = false,
        classHealth = false,
        healthLossAnimation = true,
        lockActionButtons = true,
        cooldownNumbers = true,
        showGryphons = false,
        cacheGuidance = true,
        guardianGuidance = true,
        keepDefeatedGuardianIcons = false,
        guardianMinimapTimers = false,
        minimapShowClock = false,
        mirrorCacheWaypoint = false,
        mirrorGuardianWaypoint = false,
        equippedJewelry = true,
        hideNativeBuild = true,
        attachJewelry = true,
        attachXP = true,
        attachTally = true,
        tallyStyle = DFRL.tallyStyleDefault,
        showTallyKills = true,
        showTallyGold = true,
        showTallyCache = true,
        highlightAffordableCache = true,
    }
    DFRL.display = display

    local ranges = {
        meterRows = { minimum = 1, maximum = 10, integer = true },
        bossRows = { minimum = 0, maximum = 40, integer = true },
        meterFontSize = { minimum = 8, maximum = 18, integer = true },
        nameplateFontSize = { minimum = 6, maximum = 32, integer = true },
        meterDpsWindow = { minimum = 5, maximum = 120, integer = true },
        guardianRows = { minimum = 0, maximum = 40, integer = true },
        sctScale = { minimum = 0.25, maximum = 2 },
        petRows = { minimum = 1, maximum = 6, integer = true },
        petSpacing = { minimum = 0, maximum = 60, integer = true },
    }
    local function NormalizeNumber(key, value)
        if type(value) ~= "number" or value - value ~= 0 then return nil end
        if key == "meterDpsWindow" and value == 0 then return 0 end
        local range = ranges[key]
        value = math.max(range.minimum, math.min(range.maximum, value))
        return range.integer and math.floor(value + 0.5) or value
    end
    local function NormalizeTallyStyle(value)
        if type(value) == "string" and DFRL.tallyStyleById[value] then return value end
        return nil
    end
    local function NormalizeLootMode(value)
        if value == "sdui" or value == "game" or value == "off" then return value end
    end
    local function Read(source, key)
        local value
        if type(source) == "table" then value = source[key] end
        if ranges[key] then return NormalizeNumber(key, value) or defaults[key] end
        if key == "tallyStyle" then return NormalizeTallyStyle(value) or defaults[key] end
        if key == "lootMode" then return NormalizeLootMode(value) or defaults[key] end
        if type(value) == "boolean" then return value end
        if key == "runTextRegular" or key == "runTextEndless" then
            local legacy = _G.SurvivorsDragonUiRunFont
            if type(legacy) == "table" and type(legacy.showText) == "boolean" then return legacy.showText end
        end
        return defaults[key]
    end
    local function Normalize(source)
        local copy = {}
        for key in pairs(defaults) do
            copy[key] = Read(source, key)
        end
        return copy
    end
    local function Notify()
        for _, callback in ipairs(listeners) do
            callback()
        end
    end

    function display.Get(key) return Read(draft or _G.SurvivorsDragonUiDisplay, key) end
    function display.Copy(source) return Normalize(source) end
    function display.Snapshot() return Normalize(draft or _G.SurvivorsDragonUiDisplay) end
    function display.Load(source)
        if not draft then return end
        draft = Normalize(source)
        Notify()
    end
    function display.BeginEdit()
        if not draft then draft = Normalize(_G.SurvivorsDragonUiDisplay) end
    end
    function display.Set(key, value)
        if not draft or defaults[key] == nil then return end
        if ranges[key] then
            value = NormalizeNumber(key, value)
            if not value then return end
        elseif key == "tallyStyle" then
            value = NormalizeTallyStyle(value)
            if not value then return end
        elseif key == "lootMode" then
            value = NormalizeLootMode(value)
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
