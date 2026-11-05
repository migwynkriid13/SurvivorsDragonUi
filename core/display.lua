-- Display choices preview in the layout editor and save only with Confirm.
DFRL:NewMod("Display", 0, function()
    local display, listeners, draft = {}, {}, nil
    local defaults = {
        performanceMode = false,
        defaultChat = false,
        meterEnabled = false,
        meterRows = 6,
        layoutShowGrid = true,
        uiFont = "default",
        uiCustomFont = "",
        uiFontOutline = "OUTLINE",
        uiFontShadow = true,
        layoutSnapEnabled = true,
        layoutGridSpacing = 32,
        meterFontSize = 11,
        meterNameFontSize = 11,
        meterDpsWindow = 10,
        meterRefreshRate = 1,
        meterColorMode = "default",
        meterAbilityColor = "CCA147",
        meterProcColor = "4094FF",
        bossRows = 0,
        guardianRows = 0,
        guardianShowDead = true,
        guardianShowCurrentHealth = true,
        guardianShowMaximumHealth = true,
        guardianShowHealthPercentage = false,
        guardianShortHealth = true,
        meterShowDamage = false,
        meterShowDps = true,
        meterShowPercentage = false,
        meterShowIcons = true,
        meterShowRanks = false,
        meterGroupPets = false,
        meterShowTotal = true,
        meterShowTotalDps = true,
        customBanners = true,
        customRunTimer = true,
        attachAffixes = true,
        customBossBars = true,
        bossCombineBars = false,
        lootMode = "sdui",
        lootShowMarks = true,
        rarityOdds = false,
        petRows = 6,
        petSpacing = 4,
        hidePetNames = false,
        hidePetCounts = false,
        hidePetTimers = true,
        bossDebuffs = true,
        bossShowCurrentHealth = true,
        bossShowMaximumHealth = true,
        bossShowHealthPercentage = false,
        bossShortHealth = true,
        runTextRegular = true,
        runTextEndless = true,
        runCurrentRegular = true,
        runCurrentEndless = true,
        runMaximumRegular = true,
        bossCountdownEndless = true,
        bossCountdownRegular = false,
        guardiansInBossBar = false,
        elitesInBossBar = false,
        nameplatesShowBosses = true,
        nameplatesShowGuardians = true,
        nameplatesShowElites = true,
        nameplatesShowRegular = true,
        nameplatesNamesOnly = false,
        nameplateFontSize = 9,
        nameplateDistance = 20,
        targetDebuffsOnTop = false,
        damageIcons = false,
        sctNormalHits = true,
        sctCriticalHits = true,
        sctPetDamage = true,
        sctAutoAttacks = true,
        sctDirectDamage = true,
        sctAreaDamage = true,
        sctPeriodicDamage = true,
        sctReflectedDamage = true,
        sctMisses = true,
        sctClassColors = false,
        sctStyle = "diablo",
        sctFont = "default",
        sctShortNumbers = true,
        sctGroupDamage = false,
        sctShowGroupCount = true,
        sctGroupWindow = 0.5,
        sctDistanceScaling = false,
        sctDistanceReference = 20,
        sctDistanceMinimum = 55,
        sctScale = 0.9,
        hidePortraits = false,
        showPlayerName = true,
        showPlayerLevel = true,
        showTargetName = true,
        showTargetLevel = true,
        showHealthValue = true,
        showHealthPercentage = false,
        unitShortHealth = true,
        roundPlayerPortrait = false,
        playerPortrait3D = false, -- Legacy key; controls player, target and target-of-target.
        flipBuffs = false,
        tooltipAtCursor = false,
        classResources = false,
        classHealth = false,
        healthLossAnimation = true,
        customActionBar = true,
        lockActionButtons = true,
        cooldownNumbers = true,
        showGryphons = false,
        cacheGuidance = false,
        worldCacheIcons = true,
        worldCacheIconMode = "always",
        worldCacheIconDistance = 40,
        worldCacheAffordableOnly = false,
        worldBossIcons = true,
        worldBossIconMode = "always",
        worldBossIconDistance = 40,
        worldEliteIcons = true,
        worldEliteIconMode = "always",
        worldEliteIconDistance = 40,
        worldGuardianIcons = true,
        worldGuardianIconMode = "always",
        worldGuardianIconDistance = 40,
        bossIconStyle = "default",
        guardianIconStyle = "default",
        worldPartyIcons = true,
        partyGuidance = false,
        guardianGuidance = false,
        guardianRespawnGuidance = false,
        keepDefeatedGuardianIcons = false,
        guardianMinimapTimers = false,
        minimapShowClock = true,
        minimapShowLauncher = true,
        mirrorCacheWaypoint = false,
        mirrorGuardianWaypoint = false,
        mirrorPartyWaypoint = false,
        equippedJewelry = true,
        hideNativeBuild = true,
        attachJewelry = true,
        jewelryCustomOrder = false,
        jewelryFrameStyle = "runecarver",
        jewelryOrder = "12345",
        attachXP = true,
        xpShowText = false,
        attachTally = true,
        tallyStyle = DFRL.tallyStyleDefault,
        showTallyKills = true,
        showTallyGold = true,
        showTallyCache = true,
        highlightAffordableCache = true,
    }
    DFRL.display = display
    -- Shared by normalization, the font owner and the Layout selector.
    display.fonts = {
        { value = "default", label = "Default" },
        { value = "arial", label = "Arial Narrow", face = "Fonts\\ARIALN.TTF" },
        { value = "morpheus", label = "Morpheus", face = "Fonts\\MORPHEUS.TTF" },
        { value = "skurri", label = "Skurri", face = "Fonts\\SKURRI.TTF" },
        { value = "custom", label = "Custom" },
    }
    display.jewelrySlots = {
        { value = "1", label = "Ring 1" },
        { value = "2", label = "Ring 2" },
        { value = "3", label = "Neck" },
        { value = "4", label = "Trinket 1" },
        { value = "5", label = "Trinket 2" },
    }
    display.sctGroupWindows = {
        { value = 0.1, label = "0.1 s" },
        { value = 0.25, label = "0.25 s" },
        { value = 0.5, label = "0.5 s" },
        { value = 0.75, label = "0.75 s" },
        { value = 1, label = "1 s" },
    }

    local worldIconDistanceRange = { minimum = 5, maximum = 200, integer = true }
    local ranges = {
        meterRows = { minimum = 1, maximum = 10, integer = true },
        bossRows = { minimum = 0, maximum = 40, integer = true },
        meterFontSize = { minimum = 8, maximum = 18, integer = true },
        meterNameFontSize = { minimum = 8, maximum = 18, integer = true },
        nameplateFontSize = { minimum = 6, maximum = 32, integer = true },
        nameplateDistance = { minimum = 20, maximum = 200, integer = true },
        meterDpsWindow = { minimum = 5, maximum = 120, integer = true },
        meterRefreshRate = { minimum = 0.25, maximum = 2 },
        layoutGridSpacing = { minimum = 8, maximum = 128, integer = true },
        guardianRows = { minimum = 0, maximum = 40, integer = true },
        sctScale = { minimum = 0.25, maximum = 2 },
        sctDistanceReference = { minimum = 1, maximum = 100, integer = true },
        sctDistanceMinimum = { minimum = 25, maximum = 100, integer = true },
        worldCacheIconDistance = worldIconDistanceRange,
        worldBossIconDistance = worldIconDistanceRange,
        worldEliteIconDistance = worldIconDistanceRange,
        worldGuardianIconDistance = worldIconDistanceRange,
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
    local function NormalizeSctStyle(value)
        if value == "enemy" or value == "msbt" or value == "diablo" then return value end
    end
    local function NormalizeSctFont(value)
        if value == "default" or value == "diablo" then return value end
    end
    local function NormalizeSctGroupWindow(value)
        for _, entry in ipairs(display.sctGroupWindows) do
            if value == entry.value then return value end
        end
    end
    local function NormalizeUiFont(value)
        for _, entry in ipairs(display.fonts) do
            if value == entry.value then return value end
        end
    end
    local function NormalizeUiFontOutline(value)
        if value == "" or value == "OUTLINE" or value == "THICKOUTLINE" then return value end
    end
    local colorKeys = { meterAbilityColor = true, meterProcColor = true }
    local function NormalizeColor(value)
        if type(value) ~= "string" then return end
        value = string.gsub(value, "^#", "")
        if string.len(value) == 6 and not string.find(value, "[^%x]") then return string.upper(value) end
    end
    local function NormalizeMeterColorMode(value)
        if value == "default" or value == "custom" then return value end
    end
    local function NormalizeWorldIconMode(value)
        if value == "always" or value == "near" or value == "far" then return value end
    end
    local iconStyleKeys = { bossIconStyle = true, guardianIconStyle = true }
    local function NormalizeIconStyle(value)
        if value == "default" or value == "original" then return value end
    end
    local function NormalizeJewelryFrameStyle(value)
        if value == "runecarver" or value == "original" then return value end
    end
    local tex = DFRL:GetInfoOrCons("tex")
    local originalCrest = tex .. "waypoint\\GuardianClassic.blp"
    local bossSkull = tex .. "waypoint\\WorldQuestBoss.blp"
    local bossArt = {
        default = {
            world = bossSkull,
            crop = { 0, 1, 0, 1 },
            timer = bossSkull,
            halo = tex .. "timer\\WorldQuestBossHalo.blp",
        },
        original = {
            world = originalCrest,
            crop = { 0, 65 / 128, 0, 65 / 128 },
            timer = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
            halo = tex .. "timer\\ClassicBossHalo.blp",
        },
    }
    local function NormalizeJewelryOrder(value)
        if type(value) ~= "string" or string.len(value) ~= 5 then return end
        -- Five positions containing all five keys cannot duplicate an item.
        for index = 1, 5 do
            if not string.find(value, string.sub("12345", index, index), 1, true) then return end
        end
        return value
    end
    function display.ColorRGB(value)
        local hex = NormalizeColor(value)
        if not hex then return end
        return tonumber(string.sub(hex, 1, 2), 16) / 255,
            tonumber(string.sub(hex, 3, 4), 16) / 255,
            tonumber(string.sub(hex, 5, 6), 16) / 255,
            hex
    end
    local function ColorChannel(value)
        return type(value) == "number" and value - value == 0 and value >= 0 and value <= 1
    end
    function display.ColorHex(red, green, blue)
        if not ColorChannel(red) or not ColorChannel(green) or not ColorChannel(blue) then return end
        return string.format(
            "%02X%02X%02X",
            math.floor(red * 255 + 0.5),
            math.floor(green * 255 + 0.5),
            math.floor(blue * 255 + 0.5)
        )
    end
    local worldIconModeKeys = {
        worldCacheIconMode = true,
        worldBossIconMode = true,
        worldEliteIconMode = true,
        worldGuardianIconMode = true,
    }
    -- The old boss settings applied to every encounter kind.
    local legacyEncounterKeys = {
        worldEliteIcons = "worldBossIcons",
        worldEliteIconMode = "worldBossIconMode",
        worldEliteIconDistance = "worldBossIconDistance",
        worldGuardianIcons = "worldBossIcons",
        worldGuardianIconMode = "worldBossIconMode",
        worldGuardianIconDistance = "worldBossIconDistance",
    }
    local function Read(source, key)
        local value
        if type(source) == "table" then
            value = source[key]
            local legacyKey = legacyEncounterKeys[key]
            if value == nil and legacyKey then value = source[legacyKey] end
        end
        if colorKeys[key] then return NormalizeColor(value) or defaults[key] end
        if iconStyleKeys[key] then return NormalizeIconStyle(value) or defaults[key] end
        if key == "jewelryFrameStyle" then return NormalizeJewelryFrameStyle(value) or defaults[key] end
        if key == "jewelryOrder" then return NormalizeJewelryOrder(value) or defaults[key] end
        if key == "meterColorMode" then return NormalizeMeterColorMode(value) or defaults[key] end
        if worldIconModeKeys[key] then return NormalizeWorldIconMode(value) or defaults[key] end
        if ranges[key] then
            local number = NormalizeNumber(key, value)
            if key == "meterNameFontSize" and not number and type(source) == "table" then
                -- Older saves/profiles used one size for every meter label.
                number = NormalizeNumber("meterFontSize", source.meterFontSize)
            end
            return number or defaults[key]
        end
        if key == "tallyStyle" then return NormalizeTallyStyle(value) or defaults[key] end
        if key == "lootMode" then return NormalizeLootMode(value) or defaults[key] end
        if key == "sctFont" then return NormalizeSctFont(value) or defaults[key] end
        if key == "sctGroupWindow" then return NormalizeSctGroupWindow(value) or defaults[key] end
        if key == "uiFont" then return NormalizeUiFont(value) or defaults[key] end
        if key == "uiCustomFont" then return T.NormalizeCustomFontFile(value) or defaults[key] end
        if key == "uiFontOutline" then return NormalizeUiFontOutline(value) or defaults[key] end
        if key == "sctStyle" then
            local style = NormalizeSctStyle(value)
            if style then return style end
            -- Both explicit legacy choices survive the new Diablo default.
            if type(source) == "table" and type(source.sctMSBTStyle) == "boolean" then
                return source.sctMSBTStyle and "msbt" or "enemy"
            end
            return defaults[key]
        end
        if type(value) == "boolean" then return value end
        if
            (key == "nameplatesShowElites" or key == "nameplatesShowRegular")
            and value == nil
            and type(source) == "table"
            and source.nameplatesBossGuardiansOnly == true
        then
            return false
        end
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
    function display.GetRange(key)
        local range = ranges[key]
        if range then return range.minimum, range.maximum end
    end
    function display.BossIcon() return bossArt[DFRL.display.Get("bossIconStyle")] end
    function display.GuardianIcon()
        return DFRL.display.Get("guardianIconStyle") == "original" and originalCrest
            or tex .. "waypoint\\GuardianFloating.blp"
    end
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
        if colorKeys[key] then
            value = NormalizeColor(value)
            if not value then return end
        elseif iconStyleKeys[key] then
            value = NormalizeIconStyle(value)
            if not value then return end
        elseif key == "jewelryFrameStyle" then
            value = NormalizeJewelryFrameStyle(value)
            if not value then return end
        elseif key == "jewelryOrder" then
            value = NormalizeJewelryOrder(value)
            if not value then return end
        elseif key == "meterColorMode" then
            value = NormalizeMeterColorMode(value)
            if not value then return end
        elseif worldIconModeKeys[key] then
            value = NormalizeWorldIconMode(value)
            if not value then return end
        elseif ranges[key] then
            value = NormalizeNumber(key, value)
            if not value then return end
        elseif key == "tallyStyle" then
            value = NormalizeTallyStyle(value)
            if not value then return end
        elseif key == "lootMode" then
            value = NormalizeLootMode(value)
            if not value then return end
        elseif key == "sctStyle" then
            value = NormalizeSctStyle(value)
            if not value then return end
        elseif key == "sctFont" then
            value = NormalizeSctFont(value)
            if not value then return end
        elseif key == "sctGroupWindow" then
            value = NormalizeSctGroupWindow(value)
            if not value then return end
        elseif key == "uiFont" then
            value = NormalizeUiFont(value)
            if not value then return end
        elseif key == "uiCustomFont" then
            value = T.NormalizeCustomFontFile(value)
            if not value then return end
        elseif key == "uiFontOutline" then
            value = NormalizeUiFontOutline(value)
            if not value then return end
        elseif type(value) ~= "boolean" then
            return
        end
        if draft[key] == value then return end
        draft[key] = value
        Notify()
    end
    function display.SetJewelryPosition(position, choice)
        if not draft or not draft.jewelryCustomOrder then return end
        if type(position) ~= "number" or position < 1 or position > 5 or position ~= math.floor(position) then
            return
        end
        if type(choice) ~= "string" or string.len(choice) ~= 1 or not string.find("12345", choice, 1, true) then
            return
        end
        local order = draft.jewelryOrder
        local previous = string.sub(order, position, position)
        if previous == choice then return end
        local source = string.find(order, choice, 1, true)
        local updated = ""
        for index = 1, 5 do
            local item = string.sub(order, index, index)
            if index == position then
                item = choice
            elseif index == source then
                item = previous
            end
            updated = updated .. item
        end
        display.Set("jewelryOrder", updated)
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
