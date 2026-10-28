-- Nameplate discovery and combat-text motion adapted from
-- Ryogin/NameplateSCT-Vanilla v0.5.0b-test (https://github.com/Ryogin/NameplateSCT-Vanilla).
-- Original NameplateSCT copyright (c) 2020 Justwait, MIT License.
-- The full upstream MIT notice is included in parser.lua, shipped with this module.

DFRL:NewMod("NameplateCombatText", 6, function()
    local ParseCombatEvent = T.ParseNameplateCombatEvent
    local plateStyle = T.NameplateStyle
    local BORDER = "Interface\\Tooltips\\Nameplate-Border"
    local FALLBACK_ICON = T.SourceIconFallback
    local ATTACK_ICON = "Interface\\Icons\\INV_Sword_04"
    local TEXT_DURATION = 1.45
    local MSBT = { x = 160, top = 110, height = 220, curve = 48, spacing = 8, settle = 0.06 }
    local EVENT_SETTLE = 0.08
    local EVENT_FALLBACK_DELAY = 0.16
    local DUPLICATE_WINDOW = 0.075
    local RECENT_PLATE_TIME = 0.65
    local LOSS_TIME = 0.25
    local DAMAGE_COLORS = {
        normal = { 0.72, 0.72, 0.72 },
        strong = { 1, 0.82, 0 },
        critical = { 1, 0.45, 0.10 },
    }
    local DAMAGE_SAMPLE_LIMIT, DAMAGE_SAMPLE_TIME = 8, 30
    local DAMAGE_SAMPLE_MINIMUM, STRONG_DAMAGE_RATIO = 3, 1.2
    local DAMAGE_FILTERS = {
        autoattack = "sctAutoAttacks",
        ability = "sctDirectDamage",
        spell = "sctDirectDamage",
        periodic = "sctPeriodicDamage",
        reflected = "sctReflectedDamage",
    }

    local function ShouldShowText(info)
        if info.kind == "damage" then
            if info.sourceIsPet and not DFRL.display.Get("sctPetDamage") then return false end
            local result = info.critical and "sctCriticalHits" or "sctNormalHits"
            if not DFRL.display.Get(result) then return false end
        end
        -- Result and damage-category choices must both allow a damage label.
        -- Miss/avoidance notices retain their independent control.
        local key = info.kind == "miss" and "sctMisses" or DAMAGE_FILTERS[info.damageType]
        return not key or DFRL.display.Get(key)
    end

    local plates = {}
    local shownPlates = {}
    local origins = {}
    local originIndex = { names = {}, dirty = {}, queries = {}, queryPool = {}, queryCount = 0, lossRevision = 0 }
    local activeTexts = {}
    local textPool = {}
    local textRoot
    local scrollRoot, scrollEnabled, scrollHidden
    local pending = {}
    local pendingGroups = {}
    local intakeBuckets = {}
    local spellTextures = {}
    local spellTexturesDirty, spellTexturesRetryAt = true, nil
    local recentDamage = {}
    local discoveredChildren = 0
    local combatDiscoveryNeeded = true
    local arcDirection = 1
    local function IsMode(mode) return mode == "on" or mode == "off" or mode == "default" end
    local sctMode = _G.SurvivorsDragonUiSctMode
    if not IsMode(sctMode) then sctMode = "default" end
    local sct, settingsListeners, settingsDraft = {}, {}, nil
    DFRL.sct = sct
    local observedIncoming
    local function NotifySettings()
        for _, callback in ipairs(settingsListeners) do
            callback()
        end
    end
    local function ActiveMode() return settingsDraft and settingsDraft.mode or sctMode end
    local customEnabled, changingSettings = false, false
    local damageIcons = DFRL.display.Get("damageIcons")
    local nameplatesNamesOnly = DFRL.display.Get("nameplatesNamesOnly")
    local nameplateFontSize = DFRL.display.Get("nameplateFontSize")
    local msbtStyle = DFRL.display.Get("sctMSBTStyle")
    local textScale = DFRL.display.Get("sctScale")
    -- Keep V's visible request separate from the backing coordinate feed. The
    -- native verbs do not write FrameXML's saved NAMEPLATES_ON preference.
    local enemyPlatesEnabled = NAMEPLATES_ON and true or false
    local nativeShowNameplates, nativeHideNameplates = _G.ShowNameplates, _G.HideNameplates
    local inWorld, backingEnabled = true, nil
    local drawLayers = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }
    local trackingSupported = type(nativeShowNameplates) == "function"
        and type(nativeHideNameplates) == "function"
        and WorldFrame
        and WorldFrame.DisableDrawLayer
        and WorldFrame.EnableDrawLayer
        and WorldFrame.GetHitRectInsets
        and WorldFrame.SetHitRectInsets

    local function CustomEnabled() return customEnabled and (not msbtStyle or not scrollHidden) end
    local function UsesPlateOrigins() return CustomEnabled() and not msbtStyle end

    local function IsFiniteNumber(value) return type(value) == "number" and value - value == 0 end

    -- Plate ranges pass through native ceiling/uint32 fields and float32 storage.
    -- Index their exact encodings, never a tolerance or a percentage estimate.
    local function PlateFloat(value)
        local _, exponent = math.frexp(value)
        if exponent > 128 then return end
        local step = math.ldexp(1, math.max(exponent, -125) - 24)
        local scaled = value / step
        local integer = math.floor(scaled)
        local fraction = scaled - integer
        if fraction > 0.5 or (fraction == 0.5 and math.mod(integer, 2) == 1) then integer = integer + 1 end
        if integer == 0 or (exponent == 128 and integer == 16777216) then return end
        return integer * step
    end
    local function AddPlateMaximum(maxima, value, eligible)
        if value and maxima[value] ~= false then maxima[value] = eligible end
    end
    local function IndexPlateMaximum(maxima, maximum, eligible)
        AddPlateMaximum(maxima, maximum, eligible)
        AddPlateMaximum(maxima, PlateFloat(maximum), eligible)
        local unitMaximum = math.min(4294967295, math.ceil(maximum))
        AddPlateMaximum(maxima, unitMaximum, eligible)
        AddPlateMaximum(maxima, PlateFloat(unitMaximum), eligible)
        -- AZSUNITS serializes actor float32 maxima to zero decimal places, but
        -- waking guardians publish ceilf(maximum) to UNIT_FIELD_MAXHEALTH.
        -- A rounded integer can therefore encode a fractional maximum just above
        -- it. Such a float32 exists below 2^22, or at an even tie below 2^23;
        -- above that, float32 has no fractional maximum that rounds to this integer.
        if
            maximum == math.floor(maximum)
            and (maximum < 4194304 or (maximum < 8388608 and math.mod(maximum, 2) == 0))
        then
            AddPlateMaximum(maxima, maximum + 1, eligible)
        end
    end

    local plateFilter = {
        enabled = DFRL.display.Get("nameplatesBossGuardiansOnly"),
        names = {},
        sequence = 0,
        units = 0,
        run = 0,
        barrier = -1,
        age = 0.2,
    }
    function plateFilter.Clear(barrier)
        for name in pairs(plateFilter.names) do
            plateFilter.names[name] = nil
        end
        plateFilter.source, plateFilter.stamp, plateFilter.accepted = nil, nil, nil
        if barrier then plateFilter.barrier = barrier end
    end
    function plateFilter.Receipt(prefix)
        if prefix ~= "AZSUNITS" and prefix ~= "AZSZONE" and prefix ~= "AZSRUN" then return end
        plateFilter.sequence = plateFilter.sequence + 1
        if prefix == "AZSUNITS" then
            plateFilter.units = plateFilter.sequence
        elseif prefix == "AZSRUN" then
            plateFilter.run = plateFilter.sequence
        else
            plateFilter.Clear(plateFilter.sequence)
            plateFilter.zone = plateFilter.sequence
            plateFilter.time = nil
        end
    end
    function plateFilter.Update(elapsed)
        if not plateFilter.enabled then return end
        plateFilter.age = plateFilter.age + (tonumber(elapsed) or 0)
        if plateFilter.age < 0.2 then return end
        plateFilter.age = 0
        -- Only the existing deferred reader observes packets after native parsing.
        if plateFilter.zone then
            if plateFilter.run <= plateFilter.zone then return end
            plateFilter.zone = nil
        end
        local ok, phase
        if type(_G.AZS_GetPhase) == "function" then
            ok, phase = pcall(_G.AZS_GetPhase)
        end
        if not ok or (phase ~= "playing" and phase ~= "choosing" and phase ~= "paused" and phase ~= "victory") then
            plateFilter.Clear(plateFilter.sequence)
            plateFilter.time = nil
            return
        end
        local nativeTime = type(_G.AZS_RUN) == "table" and _G.AZS_RUN.t or nil
        if IsFiniteNumber(nativeTime) and IsFiniteNumber(_G.AZS_RUN_UPDATED) then
            if plateFilter.time and nativeTime < plateFilter.time then plateFilter.Clear(plateFilter.run) end
            plateFilter.time = nativeTime
        end
        local entries, stamp = _G.AZS_UNITS, _G.AZS_UNITS_UPDATED
        if
            plateFilter.units <= plateFilter.barrier
            or not IsFiniteNumber(stamp)
            or stamp < 0
            or type(entries) ~= "table"
            or table.getn(entries) > 40
        then
            plateFilter.Clear()
            return
        end
        if
            plateFilter.source == entries
            and plateFilter.stamp == stamp
            and plateFilter.accepted == plateFilter.units
        then
            return
        end
        for _, entry in ipairs(entries) do
            if
                type(entry) ~= "table"
                or (entry.kind ~= "final" and entry.kind ~= "boss" and entry.kind ~= "guardian" and entry.kind ~= "elite")
                or not IsFiniteNumber(entry.id)
                or entry.id <= 0
                or entry.id ~= math.floor(entry.id)
                or type(entry.name) ~= "string"
                or entry.name == ""
                or not IsFiniteNumber(entry.hp)
                or not IsFiniteNumber(entry.hpm)
                or entry.hpm <= 0
                or entry.hp < 0
                or entry.hp > entry.hpm
            then
                plateFilter.Clear()
                return
            end
        end
        -- Reuse each exact-name bucket while replacing the complete publication.
        for _, maxima in pairs(plateFilter.names) do
            for maximum in pairs(maxima) do
                maxima[maximum] = nil
            end
        end
        for _, entry in ipairs(entries) do
            if entry.hp > 0 then
                local maxima = plateFilter.names[entry.name]
                if not maxima then
                    maxima = {}
                    plateFilter.names[entry.name] = maxima
                end
                -- A published ordinary elite with the same signature is ambiguous.
                IndexPlateMaximum(maxima, entry.hpm, entry.kind ~= "elite")
            end
        end
        for name, maxima in pairs(plateFilter.names) do
            if not next(maxima) then plateFilter.names[name] = nil end
        end
        plateFilter.source, plateFilter.stamp, plateFilter.accepted = entries, stamp, plateFilter.units
    end
    local function PlateName(data, sample)
        if not sample then return data.nameRegion and data.nameRegion:GetText() end
        if not sample.nameRead then
            sample.name = data.nameRegion and data.nameRegion:GetText()
            sample.nameRead = true
        end
        return sample.name
    end
    local function PlateRange(data, sample)
        if not sample then return data.bar:GetMinMaxValues() end
        if not sample.rangeRead then
            sample.minimum, sample.maximum = data.bar:GetMinMaxValues()
            sample.rangeRead = true
        end
        return sample.minimum, sample.maximum
    end
    local function PlateValue(data, sample)
        if not sample.valueRead then
            sample.value = data.bar:GetValue()
            sample.valueRead = true
        end
        return sample.value
    end
    local function PlateColor(data, sample)
        if not sample then return data.bar:GetStatusBarColor() end
        if not sample.colorRead then
            sample.red, sample.green, sample.blue = data.bar:GetStatusBarColor()
            sample.colorRead = true
        end
        return sample.red, sample.green, sample.blue
    end
    function plateFilter.Matches(data, sample)
        local name = PlateName(data, sample)
        local maxima = name and plateFilter.names[name]
        if not maxima then return false end
        local minimum, maximum = PlateRange(data, sample)
        -- Anonymous plates expose no spawn ID; never equate percentage bars to HP.
        return minimum == 0 and maxima[maximum] == true
    end
    DFRL.locale.Listen(function()
        plateFilter.Clear()
        plateFilter.age = 0.2
    end)

    local function IsEnemyPlate(data, sample)
        if not data.bar or not data.bar.GetStatusBarColor then return false end
        local red, green, blue = PlateColor(data, sample)
        if not red or not green or not blue then return false end
        -- Ignore green/blue friendly plates requested by Shift-V.
        return not (green > red + 0.1 and green > blue + 0.1) and not (blue > red + 0.1 and blue > green + 0.1)
    end
    local function MaskFrame(frame, state, masked)
        if not frame.DisableDrawLayer or not frame.EnableDrawLayer then return end
        local hideLayers = masked or state.skinned
        if hideLayers and not state.layers then
            state.layers = {}
            for _, layer in ipairs(drawLayers) do
                -- Stock anonymous plate frames start with all layers enabled.
                -- Use an optional getter where a client exposes one.
                local enabled = true
                if frame.IsDrawLayerEnabled then
                    local value = frame:IsDrawLayerEnabled(layer)
                    enabled = value == true or value == 1
                end
                state.layers[layer] = enabled
                frame:DisableDrawLayer(layer)
            end
        elseif not hideLayers and state.layers then
            for _, layer in ipairs(drawLayers) do
                if state.layers[layer] then
                    frame:EnableDrawLayer(layer)
                else
                    frame:DisableDrawLayer(layer)
                end
            end
            state.layers = nil
        end
        if not frame.GetHitRectInsets or not frame.SetHitRectInsets then return end
        if masked and not state.masked then
            local left, right, top, bottom = frame:GetHitRectInsets()
            state.insets = { left or 0, right or 0, top or 0, bottom or 0 }
            -- An empty mouse rectangle survives native freelook flag changes.
            -- Leave the native mouse-enabled state, size and position intact.
            frame:SetHitRectInsets(1000000, 1000000, 1000000, 1000000)
            state.masked = true
        elseif not masked and state.masked then
            frame:SetHitRectInsets(state.insets[1], state.insets[2], state.insets[3], state.insets[4])
            state.masked, state.insets = nil, nil
        end
    end
    local function SuppressNativeLayers(plate, data)
        if data.nativeLayersSuppressed or not data.style then return end
        if
            not plate.DisableDrawLayer
            or not plate.EnableDrawLayer
            or not data.bar.DisableDrawLayer
            or not data.bar.EnableDrawLayer
        then
            return
        end
        local function Suppress(owner)
            local state = data.presentation[owner] or {}
            data.presentation[owner] = state
            state.skinned = true
            MaskFrame(owner, state, state.masked)
        end
        -- Draw layers belong only to these native owners. The separate skin
        -- children stay enabled, while native values and region shown bits live on.
        Suppress(plate)
        Suppress(data.bar)
        data.nativeLayersSuppressed = true
    end
    local function RestorePresentation(data, retiring)
        for frame, state in pairs(data.presentation) do
            if retiring then state.skinned = nil end
            MaskFrame(frame, state, false)
        end
        if retiring then
            data.nativeLayersSuppressed = nil
            for key in pairs(data.sample) do
                data.sample[key] = nil
            end
        end
        if plateStyle then plateStyle.SetMasked(data, false) end
        data.presentationMasked = false
    end
    local function UpdatePresentation(plate, data, force, sample)
        local hiddenByV = UsesPlateOrigins() and not enemyPlatesEnabled
        local masked = trackingSupported
                and inWorld
                and (hiddenByV or plateFilter.enabled)
                and IsEnemyPlate(data, sample)
                and (hiddenByV or not plateFilter.Matches(data, sample))
            or false
        if data.presentationMasked == masked and not force then return end
        if not masked then
            RestorePresentation(data)
            return
        end
        if plateStyle then plateStyle.SetMasked(data, true) end
        local function Visit(frame)
            local state = data.presentation[frame]
            if not state then
                state = {}
                data.presentation[frame] = state
            end
            MaskFrame(frame, state, masked)
            for _, child in ipairs({ frame:GetChildren() }) do
                Visit(child)
            end
        end
        Visit(plate)
        data.presentationMasked = true
    end
    local function ApplyPlateTracking(force)
        local wanted = enemyPlatesEnabled or (trackingSupported and inWorld and UsesPlateOrigins())
        for plate, data in pairs(plates) do
            UpdatePresentation(plate, data)
        end
        if force or backingEnabled ~= wanted then
            backingEnabled = wanted
            -- Call the captured native verb directly: our visible-toggle hooks
            -- and NAMEPLATES_ON must not observe this internal tracking request.
            if wanted then
                if type(nativeShowNameplates) == "function" then nativeShowNameplates() end
            elseif type(nativeHideNameplates) == "function" then
                nativeHideNameplates()
            end
        end
    end

    local function ReleaseText(text)
        text.holder:Hide()
        text.visual:Hide()
        text.label:SetText("")
        text.label:Hide()
        text.icon:SetTexture(nil)
        text.icon:Hide()
        text.holder:ClearAllPoints()
        text.spell, text.damageType, text.iconTexture = nil, nil, nil
        text.kind = nil
        text.critical = nil
        text.sourceIsPet = nil
        text.color = nil
        text.needsMeasure = nil
        text.scrollOffset, text.scrollY = nil, nil
        text.anchorRoot, text.anchorPoint, text.anchorX, text.anchorY = nil, nil, nil, nil
        table.insert(textPool, text)
    end

    local function ResetDisplay()
        for index = table.getn(activeTexts), 1, -1 do
            ReleaseText(activeTexts[index])
            activeTexts[index] = nil
        end
        table.setn(activeTexts, 0)
        pending = {}
        pendingGroups = {}
        intakeBuckets = {}
        origins = {}
        originIndex.names, originIndex.dirty = {}, {}
        originIndex.retiredAt = nil
        originIndex.ClearQueries()
        recentDamage = {}
        for _, data in pairs(plates) do
            data.origin = nil
        end
        discoveredChildren = 0
        combatDiscoveryNeeded = true
    end

    local function IsShownEnemy(plate, data, sample)
        if not UsesPlateOrigins() or not inWorld or not plate:IsShown() then return false end
        if plate.IsVisible and not plate:IsVisible() then return false end
        return IsEnemyPlate(data, sample)
    end

    local function SampleWorldGeometry(geometry)
        geometry = geometry or {}
        if geometry.valid then return geometry end
        geometry.scale = WorldFrame:GetEffectiveScale() or 1
        geometry.left, geometry.bottom = WorldFrame:GetLeft() or 0, WorldFrame:GetBottom() or 0
        geometry.width, geometry.height = WorldFrame:GetWidth(), WorldFrame:GetHeight()
        geometry.valid = IsFiniteNumber(geometry.scale)
            and geometry.scale > 0
            and IsFiniteNumber(geometry.left)
            and IsFiniteNumber(geometry.bottom)
            and IsFiniteNumber(geometry.width)
            and IsFiniteNumber(geometry.height)
            and geometry.width > 0
            and geometry.height > 0
        return geometry
    end

    local function SamplePosition(plate, origin, now, geometry)
        local x, y = plate:GetCenter()
        if not IsFiniteNumber(x) or not IsFiniteNumber(y) then return end
        geometry = SampleWorldGeometry(geometry)
        if not geometry.valid then return end
        local plateScale = plate:GetEffectiveScale() or geometry.scale
        if not IsFiniteNumber(plateScale) or plateScale <= 0 then return end
        local ratio = plateScale / geometry.scale
        x, y = x * ratio - geometry.left, y * ratio - geometry.bottom
        local width, height = geometry.width, geometry.height
        local halfWidth = (plate:GetWidth() or 0) * ratio * 0.5
        local halfHeight = (plate:GetHeight() or 0) * ratio * 0.5
        if
            not IsFiniteNumber(x)
            or not IsFiniteNumber(y)
            or not IsFiniteNumber(halfWidth)
            or not IsFiniteNumber(halfHeight)
            or halfWidth < 0
            or halfHeight < 0
            or x < -halfWidth
            or x > width + halfWidth
            or y < -halfHeight
            or y > height + halfHeight
        then
            return
        end
        -- Test the center with the native extents, so partly visible plates
        -- at the screen edge remain usable even when their top is outside it.
        local top = plate.GetTop and plate:GetTop()
        if top then
            if not IsFiniteNumber(top) then return end
            y = top * ratio - geometry.bottom
        end
        if not IsFiniteNumber(y) then return end
        -- Keep the previous usable point when projection is unavailable. It
        -- still belongs to this incarnation and never restarts an active hit.
        origin.x, origin.y = x, y
        origin.positionAt = now
    end

    local function SampleHealth(data, origin, now, sample)
        if not data.bar.GetValue or not data.bar.GetMinMaxValues then return end
        local minimum, maximum = PlateRange(data, sample)
        local value = PlateValue(data, sample)
        if not maximum or not minimum or not value or maximum <= minimum then return end
        value = math.max(minimum, math.min(value, maximum))
        if origin.health and origin.maximum == maximum and origin.minimum == minimum then
            local lost = origin.health - value
            if lost > 0 then
                local remaining = 0
                if origin.lossAt and now - origin.lossAt <= LOSS_TIME then remaining = origin.lossRemaining or 0 end
                origin.lossRemaining = remaining + lost
                origin.lossAt = now
            end
        else
            origin.lossRemaining = 0
            origin.lossAt = nil
        end
        origin.health = value
        origin.minimum = minimum
        origin.maximum = maximum
        -- Original Vanilla can expose percentage-only enemy bars. Do not
        -- equate their 0..100 losses to absolute combat-log damage amounts.
        origin.absoluteHealth = maximum - minimum > 100
    end

    local function RetirePlate(plate)
        local data = plates[plate]
        local origin = data and data.origin
        if not origin then return end
        -- Preserve the last valid coordinates/name/health, before the client
        -- resets or reuses this frame. Active text keeps this incarnation.
        origin.live = false
        origin.hiddenAt = GetTime()
        if not originIndex.retiredAt or origin.hiddenAt < originIndex.retiredAt then
            originIndex.retiredAt = origin.hiddenAt
        end
        data.origin = nil
    end

    local function RefreshPlate(plate, data, now, forcePresentation, geometry)
        if not inWorld then return end
        if not plate:IsShown() then
            shownPlates[plate] = nil
            RetirePlate(plate)
            return
        end
        SuppressNativeLayers(plate, data)
        local sample = data.sample
        sample.nameRead, sample.rangeRead, sample.valueRead, sample.colorRead = false, false, false, false
        UpdatePresentation(plate, data, forcePresentation, sample)
        -- Hidden tracking still samples native data, but its skin has no pixels
        -- to refresh. Unmasking updates the skin in this same callback.
        if plateStyle and not data.presentationMasked then
            PlateName(data, sample)
            PlateColor(data, sample)
            if not nameplatesNamesOnly then
                PlateRange(data, sample)
                PlateValue(data, sample)
            end
            plateStyle.Update(plate, data, nameplatesNamesOnly, nameplateFontSize, sample)
        end
        if not IsShownEnemy(plate, data, sample) then
            RetirePlate(plate)
            return
        end
        local name = PlateName(data, sample)
        if not name or name == "" then
            RetirePlate(plate)
            return
        end
        local origin = data.origin
        if origin and origin.name ~= name then
            RetirePlate(plate)
            origin = nil
        end
        if not origin then
            -- A new table for each visibility cycle prevents recycled plates
            -- from moving an old enemy's text onto their new occupant.
            origin = { name = name, live = true, lastSeen = now }
            data.origin = origin
            table.insert(origins, origin)
            local named = originIndex.names[name]
            if not named then
                named = {}
                originIndex.names[name] = named
            end
            table.insert(named, origin)
        end
        origin.lastSeen = now
        SamplePosition(plate, origin, now, geometry)
        SampleHealth(data, origin, now, sample)
    end

    local function DiscoverPlate(plate, now, geometry)
        if not plate or not plate.GetRegions then return end
        if plates[plate] then
            if plate:IsShown() then
                shownPlates[plate] = plates[plate]
            else
                shownPlates[plate] = nil
                RetirePlate(plate)
            end
            return
        end
        local border, glow, name, level, skull, raid = plate:GetRegions()
        local regions = { border, glow, name, level, skull, raid }
        local hasBorder = false
        for index = 1, table.getn(regions) do
            local region = regions[index]
            if
                region
                and region.GetObjectType
                and region:GetObjectType() == "Texture"
                and region.GetTexture
                and region:GetTexture() == BORDER
            then
                hasBorder = true
                break
            end
        end
        if not hasBorder then return end
        if not name or not name.GetObjectType or name:GetObjectType() ~= "FontString" then
            name = nil
            for index = 1, table.getn(regions) do
                local region = regions[index]
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    local value = region:GetText()
                    if value and value ~= "" and value ~= "??" and not string.find(value, "^%d+$") then
                        name = region
                        break
                    end
                end
            end
        end
        local children = { plate:GetChildren() }
        local bar
        for index = 1, table.getn(children) do
            if children[index].GetObjectType and children[index]:GetObjectType() == "StatusBar" then
                bar = children[index]
                break
            end
        end
        if not name or not bar then return end
        local data = { nameRegion = name, bar = bar, nativeRegions = regions, presentation = {}, sample = {} }
        plates[plate] = data
        if plate:IsShown() then shownPlates[plate] = data end
        -- Build the skin before the first recursive mask so V-off tracking
        -- covers every visual child without touching the SCT data sources.
        if plateStyle then plateStyle.Attach(plate, data) end
        HookScript(plate, "OnHide", function()
            shownPlates[plate] = nil
            RetirePlate(plate)
        end)
        HookScript(plate, "OnShow", function()
            shownPlates[plate] = data
            RetirePlate(plate)
            -- Revisit descendants on reuse, including children added while hidden.
            RefreshPlate(plate, data, GetTime(), true)
        end)
        HookScript(bar, "OnValueChanged", function() RefreshPlate(plate, data, GetTime()) end)
        RefreshPlate(plate, data, now, nil, geometry)
    end

    local function DiscoverPlates(force, now, geometry)
        local count = WorldFrame:GetNumChildren() or 0
        if count < discoveredChildren then discoveredChildren = 0 end
        if force or count > discoveredChildren then
            geometry = geometry or {}
            local children = { WorldFrame:GetChildren() }
            local first = force and 1 or discoveredChildren + 1
            for index = first, count do
                DiscoverPlate(children[index], now, geometry)
            end
            discoveredChildren = count
        end
    end

    local function ScanPlates(force)
        if not inWorld or not WorldFrame then return end
        local now = GetTime()
        -- Share root geometry only inside this synchronous pass. Show/health
        -- callbacks keep sampling afresh, including later in the same frame.
        -- Retry invalid geometry and retain each origin's last usable point.
        local geometry = UsesPlateOrigins() and {} or nil
        DiscoverPlates(force, now, geometry)
        -- Snapshot on every frame, rather than every tenth of a second: a
        -- one-shot enemy can disappear between two of the old scans.
        for plate, data in pairs(shownPlates) do
            RefreshPlate(plate, data, now, force, geometry)
        end
        local count, kept = table.getn(origins), 0
        -- Live origins never expire. Only revisit the catalog after its earliest
        -- real retirement can pass the original strict retention boundary.
        if not originIndex.retiredAt or now - originIndex.retiredAt <= RECENT_PLATE_TIME then return end
        originIndex.retiredAt = nil
        for index = 1, count do
            local origin = origins[index]
            if not origin.live and now - (origin.hiddenAt or origin.lastSeen) > RECENT_PLATE_TIME then
                originIndex.dirty[origin.name] = true
            else
                kept = kept + 1
                if kept ~= index then origins[kept] = origin end
                if not origin.live then
                    local retiredAt = origin.hiddenAt or origin.lastSeen
                    if not originIndex.retiredAt or retiredAt < originIndex.retiredAt then
                        originIndex.retiredAt = retiredAt
                    end
                end
            end
        end
        for index = kept + 1, count do
            origins[index] = nil
        end
        if kept ~= count then table.setn(origins, kept) end
        -- Keep the same creation order in each exact-name index. A mass
        -- retirement compacts each affected bucket once, without shifting tails.
        for name in pairs(originIndex.dirty) do
            local named = originIndex.names[name]
            count, kept = table.getn(named), 0
            for index = 1, count do
                local origin = named[index]
                if origin.live or now - (origin.hiddenAt or origin.lastSeen) <= RECENT_PLATE_TIME then
                    kept = kept + 1
                    if kept ~= index then named[kept] = origin end
                end
            end
            for index = kept + 1, count do
                named[index] = nil
            end
            table.setn(named, kept)
            if kept == 0 then originIndex.names[name] = nil end
            originIndex.dirty[name] = nil
        end
    end

    function originIndex.ClearQueries()
        if originIndex.queryCount == 0 then
            originIndex.lossRevision = 0
            return
        end
        for name in pairs(originIndex.queries) do
            originIndex.queries[name] = nil
        end
        for index = 1, originIndex.queryCount do
            local record = originIndex.queryPool[index]
            record.kind, record.amount, record.fallback, record.revision = nil, nil, nil, nil
            record.x, record.y, record.origin = nil, nil, nil
        end
        originIndex.queryCount, originIndex.lossRevision = 0, 0
    end

    function originIndex.RememberQuery(info, fallback, revision, x, y, origin)
        -- Consumed loss already invalidated this result; do not store an answer
        -- that cannot be reused by the next original hit.
        if revision ~= originIndex.lossRevision then return x, y, origin end
        local record = originIndex.queries[info.targetName]
        if not record then
            -- Cache only the latest exact query per name, with bounded reused
            -- records. Extra names retain the original resolver path.
            if originIndex.queryCount == 64 then return x, y, origin end
            originIndex.queryCount = originIndex.queryCount + 1
            record = originIndex.queryPool[originIndex.queryCount] or {}
            originIndex.queryPool[originIndex.queryCount] = record
            originIndex.queries[info.targetName] = record
        end
        record.kind, record.amount, record.fallback, record.revision = info.kind, info.amount, fallback, revision
        record.x, record.y, record.origin = x, y, origin
        return x, y, origin
    end

    local function UseLoss(origin, info)
        if info.kind ~= "damage" then return end
        if origin.absoluteHealth then
            local remaining = origin.lossRemaining or 0
            origin.lossRemaining = math.max(0, remaining - info.amount)
            if origin.lossRemaining ~= remaining then originIndex.lossRevision = originIndex.lossRevision + 1 end
        end
        -- Percentage bars cannot be consumed by absolute amounts. Their loss
        -- remains timing evidence for the whole short combat-message burst.
    end

    local function ResolveOrigin(info, now, allowFallback)
        local revision = originIndex.lossRevision
        local record = originIndex.queries[info.targetName]
        if
            record
            and record.kind == info.kind
            and record.amount == info.amount
            and record.fallback == allowFallback
            and record.revision == revision
        then
            if record.origin then UseLoss(record.origin, info) end
            return record.x, record.y, record.origin
        end
        local candidateCount, lossCount, exactCount = 0, 0, 0
        local candidateOrigin, lossOrigin, exactOrigin
        local candidateX, candidateY, lossX, lossY = 0, 0, 0, 0
        local named = originIndex.names[info.targetName]
        for index = 1, named and table.getn(named) or 0 do
            local origin = named[index]
            if
                origin.x
                and origin.y
                and origin.positionAt
                and now - origin.positionAt <= RECENT_PLATE_TIME
                and (origin.live or now - (origin.hiddenAt or origin.lastSeen) <= RECENT_PLATE_TIME)
            then
                candidateCount = candidateCount + 1
                candidateOrigin = origin
                candidateX, candidateY = candidateX + origin.x, candidateY + origin.y
                if
                    info.kind == "damage"
                    and origin.lossAt
                    and now - origin.lossAt <= LOSS_TIME
                    and (origin.lossRemaining or 0) > 0
                then
                    lossCount = lossCount + 1
                    lossOrigin = origin
                    lossX, lossY = lossX + origin.x, lossY + origin.y
                    if origin.absoluteHealth then
                        local remaining = origin.lossRemaining
                        local lethal = origin.health <= origin.minimum and info.amount >= remaining
                        if math.abs(remaining - info.amount) < 0.5 or lethal then
                            exactCount = exactCount + 1
                            exactOrigin = origin
                        end
                    end
                end
            end
        end
        local origin
        if exactCount == 1 then
            origin = exactOrigin
        elseif lossCount == 1 then
            origin = lossOrigin
        elseif candidateCount == 1 then
            origin = candidateOrigin
        end
        if origin then
            UseLoss(origin, info)
            return originIndex.RememberQuery(info, allowFallback, revision, origin.x, origin.y, origin)
        end
        if not allowFallback then return originIndex.RememberQuery(info, false, revision) end
        -- The 1.12 chat API has no destination GUID. Keep every event visible,
        -- even when it cannot distinguish identical names or no plate was
        -- rendered before a lethal hit. A shared origin avoids claiming
        -- an arbitrary enemy is the exact destination.
        if lossCount > 0 then
            return originIndex.RememberQuery(info, true, revision, lossX / lossCount, lossY / lossCount)
        end
        if candidateCount > 0 then
            return originIndex.RememberQuery(
                info,
                true,
                revision,
                candidateX / candidateCount,
                candidateY / candidateCount
            )
        end
        return originIndex.RememberQuery(
            info,
            true,
            revision,
            WorldFrame:GetWidth() * 0.5,
            WorldFrame:GetHeight() * 0.58
        )
    end

    local auraSpellTextures, talentSpellTextures = {}, {}
    local iconCatalog = T.SpellIconCatalog or {}
    local nativeIconSources = { iconCatalog.game or {}, iconCatalog.abilities or {}, iconCatalog.effects or {} }
    local locale = type(_G.GetLocale) == "function" and _G.GetLocale() or nil
    local localeIconTextures = iconCatalog.locales and iconCatalog.locales[locale] or {}
    local localeSchoolIconTextures = iconCatalog.schools and iconCatalog.schools[locale] or {}
    local iconSourcesDirty = { talents = true, debuffs = true, target = true, mouseover = true }
    local iconScanAt
    local iconTooltip, iconTooltipParent
    local ICON_SCAN_INTERVAL = 0.35
    local ICON_DEBUFF_LIMIT = 16
    -- Accepted metadata changes retire this bounded generation of final answers.
    local SOURCE_ICON_CACHE_LIMIT = 256
    local resolvedIcons, resolvedIconOrder = {}, {}
    local resolvedIconCount, resolvedIconNext, resolvedIconLanguage = 0, 0, nil

    local function ClearResolvedIcons()
        if resolvedIconCount == 0 then return end
        resolvedIcons, resolvedIconOrder = {}, {}
        resolvedIconCount, resolvedIconNext = 0, 0
    end
    local function RememberResolvedIcon(name, school, texture)
        local key = school or false
        local bySchool = resolvedIcons[name]
        local record = bySchool and bySchool[key]
        if not record then
            resolvedIconNext = math.mod(resolvedIconNext, SOURCE_ICON_CACHE_LIMIT) + 1
            local retired = resolvedIconOrder[resolvedIconNext]
            if retired then
                local previous = resolvedIcons[retired.name]
                previous[retired.school] = nil
                if not next(previous) then resolvedIcons[retired.name] = nil end
                bySchool = resolvedIcons[name]
            else
                resolvedIconCount = resolvedIconCount + 1
            end
            bySchool = bySchool or {}
            resolvedIcons[name] = bySchool
            record = { name = name, school = key }
            bySchool[key], resolvedIconOrder[resolvedIconNext] = record, record
        end
        record.texture = texture or FALLBACK_ICON
        record.missingAt = texture == nil and GetTime() or nil
        return record.texture
    end

    local function TextureKey(texture)
        if type(texture) ~= "string" or texture == "" then return nil end
        local key = string.lower(string.gsub(texture, "/", "\\"))
        key = string.gsub(key, "%.blp$", "")
        key = string.gsub(key, "%.tga$", "")
        if key == string.lower(FALLBACK_ICON) then return nil end
        return key
    end

    local function AutoAttackIcon()
        if type(GetInventoryItemTexture) == "function" then
            local ok, texture = pcall(GetInventoryItemTexture, "player", 16)
            if ok and TextureKey(texture) then return texture end
        end
        return ATTACK_ICON
    end

    local function GeneratedTexture(source, name, aliases)
        local texture = source[name]
        if not aliases or texture == false then return texture end
        local key = TextureKey(texture)
        if not key then texture = nil end
        for _, alias in ipairs(aliases) do
            local candidate = source[alias]
            if candidate == false then return false end
            local candidateKey = TextureKey(candidate)
            if candidateKey then
                if key and candidateKey ~= key then return false end
                texture, key = candidate, candidateKey
            end
        end
        return texture
    end

    local function CanRefineGenerated(source, name, aliases)
        local canonical = source[name] ~= nil and name or nil
        if aliases then
            for _, alias in ipairs(aliases) do
                if source[alias] ~= nil then
                    if canonical and canonical ~= alias then return false end
                    canonical = alias
                end
            end
        end
        return canonical ~= nil
    end

    local function NativeGameTexture(name, aliases)
        local texture, key
        for _, source in ipairs(nativeIconSources) do
            local candidate = GeneratedTexture(source, name, aliases)
            if candidate == false then return false end
            local candidateKey = TextureKey(candidate)
            if candidateKey then
                if key and candidateKey ~= key then return false end
                texture, key = candidate, candidateKey
            end
        end
        return texture
    end

    local function LearnSpellTexture(cache, name, texture)
        local key = TextureKey(texture)
        if type(name) ~= "string" or name == "" or not key then return end
        local previous = cache[name]
        -- The 1.12 combat message supplies a localized name, not a spell id.
        -- Conflicting icons within one source tier cannot be disambiguated.
        if previous == false then return end
        if previous and TextureKey(previous) ~= key then
            cache[name] = false
        else
            cache[name] = texture
        end
        if cache[name] ~= previous then ClearResolvedIcons() end
    end

    -- The accepted pet view supplies exact native localized names and its
    -- resolved portrait paths; the shared resolver owns only display metadata.
    local summonIcons, summonLanguage = {}, nil
    local function ClearSummonIcons()
        summonIcons, summonLanguage = {}, nil
        ClearResolvedIcons()
    end
    local function SummonIcons()
        if summonLanguage ~= DFRL.locale.code then
            ClearSummonIcons()
            summonLanguage = DFRL.locale.code
        end
        return summonIcons
    end
    function sct.LearnSummonIcon(name, texture) LearnSpellTexture(SummonIcons(), name, texture) end
    DFRL.locale.Listen(ClearSummonIcons)

    local itemIcons, itemRetryAt, equipmentScanAt, itemLanguage = {}, {}, nil, nil
    local function ClearItemIcons()
        itemIcons, itemRetryAt, equipmentScanAt, itemLanguage = {}, {}, nil, nil
        ClearResolvedIcons()
    end
    local function ItemTexture(value)
        if type(value) ~= "string" or value == "" then return end
        local path = string.gsub(value, "/", "\\")
        if not string.find(string.lower(path), "^interface\\icons\\") then
            if
                not string.find(path, "^INV_")
                and not string.find(path, "^Spell_")
                and not string.find(path, "^Ability_")
                and not string.find(path, "^Trade_")
            then
                return
            end
            path = "Interface\\Icons\\" .. path
        end
        if string.find(string.lower(path), "inv_misc_questionmark", 1, true) then return end
        path = string.gsub(path, "%.[bB][lL][pP]$", "")
        path = string.gsub(path, "%.[tT][gG][aA]$", "")
        return path
    end
    local function RememberItem(name, texture)
        local path = ItemTexture(texture)
        if not path then return end
        LearnSpellTexture(itemIcons, name, path)
        return itemIcons[name] or nil
    end
    local function ItemInfo(reference)
        local name, _, _, _, _, _, _, _, ninth, tenth = GetItemInfo(reference)
        return name, ItemTexture(tenth) or ItemTexture(ninth)
    end
    local function ItemIcon(name)
        if itemLanguage ~= DFRL.locale.code then
            ClearItemIcons()
            itemLanguage = DFRL.locale.code
        end
        if itemIcons[name] ~= nil then return itemIcons[name] or nil end
        local now = GetTime()
        if itemRetryAt[name] and now < itemRetryAt[name] then return end
        itemRetryAt[name] = now + 1
        if type(GetItemInfo) == "function" then
            local ok, resolved, texture = pcall(ItemInfo, name)
            if ok and resolved == name then
                local path = RememberItem(name, texture)
                if path then return path end
            end
        end
        if
            (not equipmentScanAt or now < equipmentScanAt or now - equipmentScanAt >= 1)
            and type(GetInventoryItemLink) == "function"
            and type(GetInventoryItemTexture) == "function"
        then
            equipmentScanAt = now
            for slot = 1, 19 do
                local ok, link = pcall(GetInventoryItemLink, "player", slot)
                if ok and type(link) == "string" then
                    local _, _, itemName = string.find(link, "|h%[(.-)%]|h")
                    if itemName then
                        local loaded, texture = pcall(GetInventoryItemTexture, "player", slot)
                        if loaded then RememberItem(itemName, texture) end
                    end
                end
            end
        end
        return itemIcons[name] or nil
    end
    local function DirtySpellTextures()
        if not spellTexturesDirty then spellTextures = {} end
        spellTexturesDirty, spellTexturesRetryAt = true, nil
        ClearResolvedIcons()
    end
    DFRL.locale.Listen(DirtySpellTextures)
    local function ResetLearnedSpellTextures()
        DirtySpellTextures()
        ClearItemIcons()
        ClearSummonIcons()
        auraSpellTextures, talentSpellTextures = {}, {}
        iconSourcesDirty = { talents = true, debuffs = true, target = true, mouseover = true }
        iconScanAt = nil
        if iconTooltip then iconTooltip:Hide() end
    end

    local function LearnTalentTextures()
        if
            type(_G.GetNumTalentTabs) ~= "function"
            or type(_G.GetNumTalents) ~= "function"
            or type(_G.GetTalentInfo) ~= "function"
        then
            return
        end
        for tab = 1, _G.GetNumTalentTabs() or 0 do
            for index = 1, _G.GetNumTalents(tab) or 0 do
                local name, texture, _, _, rank = _G.GetTalentInfo(tab, index)
                if type(rank) == "number" and rank > 0 then LearnSpellTexture(talentSpellTextures, name, texture) end
            end
        end
    end

    local function LearnNativeDebuffTextures()
        if type(_G.AZS_GetPhase) ~= "function" then return end
        local ok, phase = pcall(_G.AZS_GetPhase)
        -- Read phase before retained native tables, including after reload.
        if
            not ok
            or (
                phase ~= "playing"
                and phase ~= "choosing"
                and phase ~= "paused"
                and phase ~= "dead"
                and phase ~= "victory"
            )
        then
            return
        end
        local stamp = _G.AZS_DEBUFFS_UPDATED
        if not IsFiniteNumber(stamp) or stamp < 0 then return end
        local entries = _G.AZS_DEBUFFS
        if type(entries) ~= "table" then return end
        -- This official snapshot includes untargeted bosses and guardians.
        -- Copy only display metadata, independently of encounter HUD settings.
        for _, entry in pairs(entries) do
            if type(entry) == "table" then LearnSpellTexture(auraSpellTextures, entry.name, entry.icon) end
        end
        return true
    end

    local function GetIconTooltip()
        if iconTooltip == false then return nil end
        if not iconTooltip then
            iconTooltipParent = CreateFrame("Frame", nil, UIParent)
            iconTooltipParent:Hide()
            local ok, tooltip =
                pcall(CreateFrame, "GameTooltip", "DFRL_CombatIconTooltip", iconTooltipParent, "GameTooltipTemplate")
            if
                not ok
                or not tooltip
                or type(tooltip.SetOwner) ~= "function"
                or type(tooltip.SetUnitDebuff) ~= "function"
                or type(tooltip.ClearLines) ~= "function"
            then
                if ok and tooltip then tooltip:Hide() end
                iconTooltip = false
                return nil
            end
            -- Native tooltip builders may Show and reset alpha. The hidden
            -- parent keeps this private scanner out of the visible tooltip UI.
            iconTooltip = tooltip
            iconTooltip:EnableMouse(false)
        end
        return iconTooltip
    end

    local function LearnUnitDebuffTextures(unit)
        if type(_G.UnitDebuff) ~= "function" or type(_G.UnitExists) ~= "function" or not _G.UnitExists(unit) then
            return
        end
        local tooltip = GetIconTooltip()
        if not tooltip then return end
        for index = 1, ICON_DEBUFF_LIMIT do
            local ok, texture = pcall(_G.UnitDebuff, unit, index)
            if not ok or not texture then break end
            if TextureKey(texture) then
                -- Hide clears native ownership and lines: re-own for each slot
                -- and read the title before hiding, never from GameTooltip.
                tooltip:SetOwner(iconTooltipParent, "ANCHOR_NONE")
                tooltip:ClearLines()
                local shown = pcall(tooltip.SetUnitDebuff, tooltip, unit, index)
                local title = _G.DFRL_CombatIconTooltipTextLeft1
                if shown and title and type(title.GetText) == "function" then
                    LearnSpellTexture(auraSpellTextures, title:GetText(), texture)
                end
                tooltip:Hide()
            end
        end
    end

    local function RefreshLearnedSpellTextures()
        if
            not inWorld
            or not (
                iconSourcesDirty.talents
                or iconSourcesDirty.debuffs
                or iconSourcesDirty.target
                or iconSourcesDirty.mouseover
            )
        then
            return
        end
        local now = GetTime()
        -- Dirty events coalesce; never scan native metadata once per AoE hit.
        if iconScanAt and now - iconScanAt < ICON_SCAN_INTERVAL then return end
        iconScanAt = now
        if iconSourcesDirty.talents then
            iconSourcesDirty.talents = false
            LearnTalentTextures()
        end
        if iconSourcesDirty.debuffs then
            -- Keep pending when phase/data is not ready. Snapshot timestamps
            -- are UI time, so distinct received updates may share one value.
            iconSourcesDirty.debuffs = not LearnNativeDebuffTextures()
        end
        if iconSourcesDirty.target then
            iconSourcesDirty.target = false
            LearnUnitDebuffTextures("target")
        end
        if iconSourcesDirty.mouseover then
            iconSourcesDirty.mouseover = false
            LearnUnitDebuffTextures("mouseover")
        end
    end

    local function RebuildSpellTextures()
        if not spellTexturesDirty and not spellTexturesRetryAt then return end
        if spellTexturesRetryAt and GetTime() < spellTexturesRetryAt then return end
        if
            type(_G.GetNumSpellTabs) ~= "function"
            or type(_G.GetSpellTabInfo) ~= "function"
            or type(_G.GetSpellName) ~= "function"
            or type(_G.GetSpellTexture) ~= "function"
        then
            return
        end
        local rebuilt, pendingMetadata = {}, false
        local book = BOOKTYPE_SPELL or "spell"
        for tab = 1, GetNumSpellTabs() or 0 do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local name = GetSpellName(index, book)
                local texture = GetSpellTexture(index, book)
                if name and TextureKey(texture) then
                    rebuilt[name] = texture
                else
                    pendingMetadata = true
                end
            end
        end
        spellTextures, spellTexturesDirty = rebuilt, false
        spellTexturesRetryAt = pendingMetadata and GetTime() + 1 or nil
        ClearResolvedIcons()
    end

    local function NativeItemIcon(name)
        local catalogs = T.SourceItemIconCatalog
        local catalog = catalogs and (catalogs[DFRL.locale.code] or catalogs.en)
        return catalog and catalog[name]
    end

    local function CombatIcon(info)
        if info.spell and info.spell ~= "" then
            if resolvedIconLanguage ~= DFRL.locale.code then
                ClearResolvedIcons()
                resolvedIconLanguage = DFRL.locale.code
            end
            RebuildSpellTextures()
            local texture = spellTextures[info.spell]
            if not texture then
                RefreshLearnedSpellTextures()
                local bySchool = resolvedIcons[info.spell]
                local record = bySchool and bySchool[info.school or false]
                if record then
                    local now = record.missingAt and GetTime()
                    if not now or (now >= record.missingAt and now - record.missingAt < 1) then
                        return record.texture
                    end
                end
                texture = auraSpellTextures[info.spell]
                -- The game's picker can differ from GetLocale(). Read its
                -- current optional aliases only for generated metadata tiers.
                local language = DFRL.locale
                local catalog = language and language.data[language.code]
                local spellNames = catalog and catalog.spellNames
                local aliases = spellNames and spellNames[info.spell]
                -- Observed auras outrank catalog and talent artwork. Preserve
                -- ambiguity within each tier instead of choosing a random icon.
                if texture == nil then texture = SummonIcons()[info.spell] end
                if texture == nil then texture = NativeGameTexture(info.spell, aliases) end
                if texture == nil then texture = NativeItemIcon(info.spell) end
                if texture == nil then texture = talentSpellTextures[info.spell] end
                if texture == nil then
                    local database, schools = localeIconTextures, localeSchoolIconTextures
                    if spellNames then
                        -- These aliases name verified English catalog entries;
                        -- use their English DBC rows and actual-school sets.
                        database = iconCatalog.locales and iconCatalog.locales.enUS or {}
                        schools = iconCatalog.schools and iconCatalog.schools.enUS or {}
                    end
                    texture = GeneratedTexture(database, info.spell, aliases)
                    if texture == false and CanRefineGenerated(database, info.spell, aliases) then
                        -- Only refine the database tier with the actual parsed
                        -- school. School sets cover ambiguous English names,
                        -- not every row in a merged localized-name group.
                        local schoolTextures = schools[info.school]
                        if schoolTextures then
                            local refined = GeneratedTexture(schoolTextures, info.spell, aliases)
                            if refined ~= nil then texture = refined end
                        end
                    end
                end
                if texture == nil then texture = ItemIcon(info.spell) end
                return RememberResolvedIcon(info.spell, info.school, texture)
            end
            return texture
        end
        if info.damageType == "autoattack" then return AutoAttackIcon() end
        return FALLBACK_ICON
    end

    -- Exact native healing records: docs/DAMAGE-METER.md; shared across classes.
    local healingSourceIcons = {
        ["Regeneration"] = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        ["Leech"] = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
        ["Healing on Kill"] = "Interface\\Icons\\Spell_Shadow_DeathPact",
        ["Level Up"] = "Interface\\Icons\\Spell_Holy_HolyBolt",
        ["Soul Link"] = "Interface\\Icons\\Spell_Shadow_GatherShadows",
    }
    local healingNames, healingLanguage = {}, false
    local function NativeHealingIcon(name)
        local code = DFRL.locale.code
        if healingLanguage ~= code then
            healingNames = {}
            for caption, texture in pairs(healingSourceIcons) do
                LearnSpellTexture(healingNames, caption, texture)
                LearnSpellTexture(healingNames, DFRL.locale.Native(caption), texture)
            end
            healingLanguage = code
        end
        return healingNames[name]
    end

    -- Native meter names can share the same metadata resolver without passing
    -- through combat parsing, filtering, grouping or damage attribution.
    function sct.GetSourceIcon(name, healing, proc)
        if type(name) ~= "string" or name == "" then return FALLBACK_ICON end
        if healing and proc ~= 1 then
            local texture = NativeHealingIcon(name)
            if texture ~= nil then return texture or FALLBACK_ICON end
        end
        if name == "Melee" or name == DFRL.locale.Native("Melee") then return AutoAttackIcon() end
        return CombatIcon({ spell = name })
    end

    local function IconIdentityPart(value) return string.len(value) .. ":" .. value end

    local function QueueCombatText(info, now)
        local identity, byAmount, group
        if info.kind == "damage" then
            -- Resolve once even when icons are hidden, so identity and the
            -- eventual displayed icon cannot change while this hit waits.
            info.iconTexture = CombatIcon(info)
            local attack, attackKind = info.spell, "spell"
            if not attack or attack == "" then
                if info.damageType == "autoattack" then
                    attack, attackKind = "", "autoattack"
                else
                    attack = nil
                end
            end
            if attack then
                local source = info.sourceName
                if not source or source == "" then
                    source = type(_G.UnitName) == "function" and _G.UnitName("player") or ""
                end
                identity = IconIdentityPart(attackKind)
                    .. IconIdentityPart(attack)
                    .. IconIdentityPart(source)
                    .. IconIdentityPart(info.sourceIsPet and "pet" or "")
                    .. IconIdentityPart(info.damageType or "")
                    .. IconIdentityPart(info.school or "")
                    .. IconIdentityPart(info.critical and "critical" or "normal")
                    .. IconIdentityPart(TextureKey(info.iconTexture) or FALLBACK_ICON)
                byAmount = intakeBuckets[identity]
                if not byAmount then
                    byAmount = {}
                    intakeBuckets[identity] = byAmount
                end
                -- The first hit fixes the inclusive 75 ms deadline. Joining
                -- hits never slide it forward or change the original amount.
                group = byAmount[info.amount]
                if group and (now < group.time or now > group.closesAt) then group = nil end
            end
        end
        if not group then
            -- The first original hit owns the unchanged value and styling.
            group = {
                info = info,
                time = now,
                closesAt = now + DUPLICATE_WINDOW,
                bucket = byAmount,
                identity = identity,
                remaining = 0,
                count = 0,
                x = 0,
                y = 0,
            }
            table.insert(pendingGroups, group)
            if byAmount then byAmount[info.amount] = group end
        end
        if msbtStyle then
            -- The fixed stream has no per-hit origin to resolve. Retain the
            -- latest member's original age gate without storing each arrival.
            group.count = group.count + 1
            group.lastArrival = math.max(group.lastArrival or now, now)
        else
            group.remaining = group.remaining + 1
            table.insert(pending, { info = info, time = now, group = group })
        end
    end

    local function UpdateIcon(text)
        if damageIcons then
            text.icon:SetTexture(text.iconTexture or CombatIcon(text))
            text.icon:Show()
        else
            text.icon:SetTexture(nil)
            text.icon:Hide()
        end
    end

    local function UpdateTextColor(text)
        local color = text.color or DAMAGE_COLORS.normal
        if text.kind == "damage" and DFRL.display.Get("sctClassColors") then
            color = T.GetPlayerClassColor() or color
        end
        text.label:SetTextColor(color[1], color[2], color[3])
    end

    local function FitText(text)
        -- Natural width is already local to the label. Refit after scaling:
        -- native raster rounding changes with crit pop, and its drawn shadow
        -- can exceed the exact automatic width and replace digits with "...".
        local width = text.label:GetStringWidth()
        text.needsMeasure = not IsFiniteNumber(width) or width <= 0
        width = text.needsMeasure and 240 or math.ceil(width) + 4
        if text.width ~= width then
            text.width = width
            text.label:SetWidth(width)
        end
    end

    local function PositionText(text, relativePoint, x, y)
        local root = msbtStyle and scrollRoot or WorldFrame
        if
            text.anchorRoot == root
            and text.anchorPoint == relativePoint
            and text.anchorX == x
            and text.anchorY == y
        then
            return
        end
        text.holder:SetPoint("CENTER", root, relativePoint, x, y)
        text.anchorRoot, text.anchorPoint, text.anchorX, text.anchorY = root, relativePoint, x, y
    end

    local function EnsureTextRoot()
        if not textRoot then
            -- Keep the growing hit pool out of the native discovery roster.
            textRoot = CreateFrame("Frame", nil, WorldFrame)
            textRoot:SetAllPoints(WorldFrame)
            textRoot:SetFrameStrata("HIGH")
            textRoot:SetFrameLevel(WorldFrame:GetFrameLevel())
            textRoot:EnableMouse(false)
        end
        return textRoot
    end

    local function SyncScrollRoot()
        local enabled = inWorld and customEnabled and msbtStyle
        if enabled and not scrollRoot then
            scrollRoot = CreateFrame("Frame", nil, EnsureTextRoot())
            scrollRoot:Hide()
            scrollRoot:SetFrameStrata("HIGH")
            scrollRoot:SetFrameLevel(textRoot:GetFrameLevel())
            scrollRoot:SetWidth(240)
            scrollRoot:SetHeight(MSBT.height)
            scrollRoot:EnableMouse(false)
            DFRL.layout.Register("sctMSBT", scrollRoot, function()
                scrollRoot:ClearAllPoints()
                scrollRoot:SetPoint("CENTER", WorldFrame, "CENTER", MSBT.x, MSBT.top - MSBT.height / 2)
            end, {
                onlyWhenShown = true,
                onResize = function()
                    if not scrollRoot:IsVisible() then return end
                    for _, text in ipairs(activeTexts) do
                        FitText(text)
                    end
                end,
            })
            DFRL.layout.ListenVisibility("sctMSBT", function(shown)
                scrollHidden = not shown
                if scrollHidden then ResetDisplay() end
            end)
        end
        if scrollRoot and scrollEnabled ~= enabled then
            scrollEnabled = enabled
            if enabled then
                scrollRoot:Show()
            else
                scrollRoot:Hide()
            end
        end
    end

    DFRL.display.Listen(function()
        local scrolling = DFRL.display.Get("sctMSBTStyle")
        if msbtStyle ~= scrolling then
            msbtStyle = scrolling
            -- Do not move old hits between unrelated coordinate systems, or
            -- replay a queued enemy hit in the fixed screen stream.
            ResetDisplay()
            SyncScrollRoot()
            ApplyPlateTracking(false)
            NotifySettings()
        end
        nameplatesNamesOnly = DFRL.display.Get("nameplatesNamesOnly")
        nameplateFontSize = DFRL.display.Get("nameplateFontSize")
        local filtered = DFRL.display.Get("nameplatesBossGuardiansOnly")
        if plateFilter.enabled ~= filtered then
            plateFilter.enabled = filtered
            plateFilter.Clear()
            plateFilter.time = nil
            plateFilter.age = 0.2
            ApplyPlateTracking(false)
        end
        textScale = DFRL.display.Get("sctScale")
        local enabled = DFRL.display.Get("damageIcons")
        local iconsChanged = damageIcons ~= enabled
        damageIcons = enabled
        if iconsChanged and damageIcons and CustomEnabled() then RebuildSpellTextures() end
        for index = table.getn(activeTexts), 1, -1 do
            local text = activeTexts[index]
            if not ShouldShowText(text) then
                ReleaseText(table.remove(activeTexts, index))
            else
                UpdateTextColor(text)
                if iconsChanged then UpdateIcon(text) end
            end
        end
    end)

    local function AcquireText()
        -- Every displayed hit/group gets its full lifetime, including in AoE.
        -- The pool grows to peak concurrency; active entries are never evicted.
        local text = table.remove(textPool)
        local parent = msbtStyle and scrollRoot or EnsureTextRoot()
        if not text then
            local holder = CreateFrame("Frame", nil, parent)
            holder:Hide()
            holder:SetWidth(1)
            holder:SetHeight(1)
            holder:SetFrameStrata("HIGH")
            holder:EnableMouse(false)
            local visual = CreateFrame("Frame", nil, holder)
            visual:SetWidth(240)
            visual:SetHeight(60)
            visual:SetPoint("CENTER", holder, "CENTER", 0, 0)
            visual:EnableMouse(false)
            local label = visual:CreateFontString(nil, "OVERLAY")
            T.SetFont(label, 18, "OUTLINE")
            label:SetShadowOffset(1, -1)
            label:SetPoint("CENTER", visual, "CENTER", 0, 0)
            label:SetHeight(36)
            label:SetJustifyH("CENTER")
            label:SetJustifyV("MIDDLE")
            local icon = visual:CreateTexture(nil, "OVERLAY")
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetPoint("RIGHT", label, "LEFT", -3, 0)
            icon:SetWidth(18)
            icon:SetHeight(18)
            -- SCT contains only the hit and its icon. Repeating the enemy's
            -- name here made fallback hits grow another name during crit pop.
            text = { holder = holder, visual = visual, label = label, icon = icon }
        end
        if text.holder:GetParent() ~= parent then text.holder:SetParent(parent) end
        return text
    end

    local function DamageColor(info, now)
        -- Critical status comes from the parsed native message, never from
        -- damage size. Crits and miss labels do not affect normal-hit averages.
        if info.kind ~= "damage" then return DAMAGE_COLORS.strong end
        if info.critical then return DAMAGE_COLORS.critical end
        if info.damageType ~= "autoattack" and (not info.spell or info.spell == "") then return DAMAGE_COLORS.normal end
        local key = (info.sourceName or "")
            .. "\031"
            .. (info.damageType or "")
            .. "\031"
            .. (info.school or "")
            .. "\031"
            .. (info.spell or "")
        local samples = recentDamage[key]
        if not samples then
            samples = {}
            recentDamage[key] = samples
        end
        local total = 0
        for index = table.getn(samples), 1, -1 do
            local sample = samples[index]
            if now - sample.time > DAMAGE_SAMPLE_TIME then
                table.remove(samples, index)
            else
                total = total + sample.amount
            end
        end
        local count = table.getn(samples)
        local strong = count >= DAMAGE_SAMPLE_MINIMUM and info.amount >= total / count * STRONG_DAMAGE_RATIO
        table.insert(samples, { amount = info.amount, time = now })
        if table.getn(samples) > DAMAGE_SAMPLE_LIMIT then table.remove(samples, 1) end
        return strong and DAMAGE_COLORS.strong or DAMAGE_COLORS.normal
    end

    local function DisplayDamage(info, x, y)
        -- Filter only after every original hit has consumed its matching and
        -- color evidence, including members of a visually collapsed group.
        if not ShouldShowText(info) then return end
        local value = info.text or info.amount
        if not value then return end
        local text = AcquireText()
        -- The enemy layout snapshots its native launch point. The scrolling
        -- layout uses offsets from its movable owner and needs no enemy position.
        if msbtStyle then
            x, y = 0, MSBT.height / 2 - 12
        end
        text.x, text.y = x, y
        text.started = GetTime()
        text.impact = info.critical or info.kind == "miss"
        text.sizeScale = info.critical and 1.5 or 1
        if not msbtStyle then
            text.arcX = arcDirection * math.random(36, 64)
            text.launch = math.random(105, 130)
            text.gravity = text.launch + 65
            arcDirection = -arcDirection
        end
        local displayText = tostring(value)
        if info.kind == "miss" then displayText = DFRL.locale.CombatText(displayText) end
        text.label:SetText(displayText)
        text.label:Show()
        text.spell, text.damageType, text.iconTexture = info.spell, info.damageType, info.iconTexture
        text.kind = info.kind
        text.critical = info.critical
        text.sourceIsPet = info.sourceIsPet
        text.color = info.color
        UpdateTextColor(text)
        UpdateIcon(text)
        local scale = textScale * text.sizeScale * (text.impact and 0.5 or 1)
        if text.scale ~= scale then
            text.scale = scale
            text.visual:SetScale(scale)
        end
        FitText(text)
        text.visual:Show()
        if text.alpha ~= 1 then
            text.alpha = 1
            text.holder:SetAlpha(1)
        end
        -- New holders have no anchor; ReleaseText cleared pooled holders.
        PositionText(text, msbtStyle and "CENTER" or "BOTTOMLEFT", x, y + 12)
        text.holder:Show()
        table.insert(activeTexts, text)
    end

    local function UpdatePending(now)
        local count, groupCount = table.getn(pending), table.getn(pendingGroups)
        if count == 0 and groupCount == 0 then return end
        originIndex.ClearQueries()
        local kept = 0
        for index = 1, count do
            local entry = pending[index]
            local age = now - entry.time
            local resolved = false
            if age >= EVENT_SETTLE then
                local x, y
                if msbtStyle then
                    x, y = 0, 0
                else
                    x, y = ResolveOrigin(entry.info, now, age >= EVENT_FALLBACK_DELAY)
                end
                if x and y then
                    local group = entry.group
                    group.count = group.count + 1
                    group.x, group.y = group.x + x, group.y + y
                    group.remaining = group.remaining - 1
                    resolved = true
                end
            end
            -- Enemy text matches every original hit in native message order;
            -- the fixed stream needs neither plate identity nor health loss.
            if not resolved then
                kept = kept + 1
                pending[kept] = entry
            end
        end
        for index = kept + 1, count do
            pending[index] = nil
        end
        -- Lua 5.0 insert/getn remembers a size independently of cleared slots.
        table.setn(pending, kept)
        -- Presentation below can call native methods. Match reuse belongs only
        -- to this completed synchronous pass, never another frame or callback.
        originIndex.ClearQueries()

        kept = 0
        for index = 1, groupCount do
            local group = pendingGroups[index]
            local bucket = group.bucket
            if bucket and (now < group.time or now > group.closesAt) then
                -- A newer group may already own this key while the old one
                -- finishes matching. Retire only this group's own intake.
                if bucket[group.info.amount] == group then
                    bucket[group.info.amount] = nil
                    if not next(bucket) and intakeBuckets[group.identity] == bucket then
                        intakeBuckets[group.identity] = nil
                    end
                end
                group.bucket, group.identity = nil, nil
            end
            if
                group.remaining == 0
                and not group.bucket
                and (not group.lastArrival or now - group.lastArrival >= EVENT_SETTLE)
            then
                -- Every display keeps its resolved centroid for the full arc.
                DisplayDamage(group.info, group.x / group.count, group.y / group.count)
            else
                kept = kept + 1
                pendingGroups[kept] = group
            end
        end
        for index = kept + 1, groupCount do
            pendingGroups[index] = nil
        end
        table.setn(pendingGroups, kept)
    end

    local function PrepareScrollPositions(now, elapsed)
        local ceiling
        local blend = 1 - math.exp(-math.max(0, elapsed) / MSBT.settle)
        -- Newest first: reserve room for each label's largest crit pop without
        -- allocating lanes, dropping hits or changing their original lifetime.
        for index = table.getn(activeTexts), 1, -1 do
            local text = activeTexts[index]
            local progress = (now - text.started) / TEXT_DURATION
            if progress < 1 then
                local halfHeight = 12 * textScale * text.sizeScale * (text.impact and 2 or 1)
                local y = MSBT.height / 2 - MSBT.height * progress
                local target = ceiling and math.min(y, ceiling - halfHeight - MSBT.spacing) or y
                local offset = y - target
                if text.scrollOffset then
                    text.scrollOffset = text.scrollOffset + (offset - text.scrollOffset) * blend
                else
                    text.scrollOffset = offset
                end
                text.scrollY = y - text.scrollOffset
                ceiling = text.scrollY - halfHeight
            end
        end
    end

    local function UpdateTexts(now, elapsed)
        local count = table.getn(activeTexts)
        if count == 0 then return end
        if msbtStyle then PrepareScrollPositions(now, elapsed) end
        local kept = 0
        for index = 1, count do
            local text = activeTexts[index]
            local progress = (now - text.started) / TEXT_DURATION
            if progress >= 1 then
                ReleaseText(text)
            else
                kept = kept + 1
                activeTexts[kept] = text
                local x, y, relativePoint
                if msbtStyle then
                    x = MSBT.curve * 4 * progress * (1 - progress)
                    y = text.scrollY
                    relativePoint = "CENTER"
                else
                    -- Only the hit's own animation moves its native launch point.
                    x = text.x + text.arcX * progress
                    y = text.y + 12 + text.launch * progress - text.gravity * progress * progress
                    relativePoint = "BOTTOMLEFT"
                end
                -- Replacing CENTER updates the existing anchor in place.
                PositionText(text, relativePoint, x, y)
                local scale = textScale * text.sizeScale
                if text.impact and progress < 1 / 6 then
                    local pop = progress * 6
                    if pop < 0.5 then
                        scale = scale * (0.5 + 1.5 * (1 - math.pow(1 - pop * 2, 5)))
                    else
                        scale = scale * (2 - math.pow((pop - 0.5) * 2, 5))
                    end
                end
                -- Only the inner visual scales: its launch point stays
                -- fixed during crit pop, including after the mob has died.
                if text.scale ~= scale then
                    text.scale = scale
                    text.visual:SetScale(scale)
                    FitText(text)
                elseif text.needsMeasure then
                    FitText(text)
                end
                local alpha = 1
                if progress > 0.68 then alpha = (1 - progress) / 0.32 end
                if text.alpha ~= alpha then
                    text.alpha = alpha
                    text.holder:SetAlpha(alpha)
                end
            end
        end
        for index = kept + 1, count do
            activeTexts[index] = nil
        end
        table.setn(activeTexts, kept)
    end

    local function HandleCombatEvent(eventName, message, eventTime)
        if not inWorld or not CustomEnabled() then return end
        local info = ParseCombatEvent(eventName, message)
        if not info then return end
        if info.kind == "aura" then
            -- Mouseover has no UNIT_AURA fan-out in the native 1.12 client.
            -- An application notice only dirties metadata observations; the
            -- scanner still reads actual unit tokens and never assigns hits.
            iconSourcesDirty.target, iconSourcesDirty.mouseover = true, true
            return
        end
        if not info.targetName or info.targetName == "" then return end
        local now = eventTime or GetTime()
        -- Catch newly allocated plates before a lethal hit can retire them.
        -- Known plates already sample on show/health changes and every frame;
        -- refreshing the entire pack for each combat message multiplies UI work.
        if UsesPlateOrigins() and WorldFrame and combatDiscoveryNeeded then
            combatDiscoveryNeeded = false
            DiscoverPlates(false, now)
        end
        -- Choose once in combat-message order, before plate-matching delays
        -- can reorder the display. An animating hit keeps its chosen color.
        info.color = DamageColor(info, now)
        QueueCombatText(info, now)
    end

    local function ReadNativeDamage() return GetCVar("CombatDamage") end
    local function WriteNativeDamage(value)
        changingSettings = true
        if ReadNativeDamage() ~= value then SetCVar("CombatDamage", value) end
        changingSettings = false
    end
    local function ReadIncoming() return _G.SHOW_COMBAT_TEXT end
    local function WriteIncoming(value)
        changingSettings = true
        _G.SHOW_COMBAT_TEXT = value
        if type(_G.BenillaCombatText_UpdateOrLoad) == "function" then
            _G.BenillaCombatText_UpdateOrLoad()
        else
            if value == "1" and type(_G.UIParentLoadAddOn) == "function" then
                _G.UIParentLoadAddOn("Blizzard_CombatText")
            end
            if type(_G.CombatText_UpdateDisplayedMessages) == "function" then
                _G.CombatText_UpdateDisplayedMessages()
            end
        end
        changingSettings = false
    end

    local function PreviewSetting(key, value, read, write)
        local current = read()
        if current == value then return end
        local preview = settingsDraft[key]
        if not preview or current ~= preview.applied then
            preview = { original = current }
            settingsDraft[key] = preview
        end
        preview.applied = value
        write(value)
    end
    local function RestoreSetting(draft, key, read, write)
        local preview = draft[key]
        draft[key] = nil
        -- Later native choices supersede our preview. Originals, including a
        -- nil incoming preference, live only in this session's transaction.
        if preview and read() == preview.applied and preview.original ~= preview.applied then
            write(preview.original)
        end
    end

    local function SyncGameSettings(force)
        if changingSettings then return end
        -- Observe incoming/self text only to refresh its editor label. It is
        -- independent of the custom outgoing renderer and never selects a mode.
        local incomingText = _G.SHOW_COMBAT_TEXT == "1"
        local incomingChanged = incomingText ~= observedIncoming
        observedIncoming = incomingText
        local damageValue = ReadNativeDamage()
        if settingsDraft then
            if settingsDraft.damage and damageValue ~= settingsDraft.damage.applied then settingsDraft.damage = nil end
            if settingsDraft.incoming and ReadIncoming() ~= settingsDraft.incoming.applied then
                settingsDraft.incoming = nil
            end
        end
        local nativeDamage = damageValue ~= "0"
        local previousMode, previousCommittedMode = ActiveMode(), sctMode
        -- Menu choices take precedence over a previously saved addon mode.
        -- Native target damage has no separate renderer-suppression switch.
        if nativeDamage then
            sctMode = "default"
            if settingsDraft then settingsDraft.mode = nil end
        end
        local enabled = ActiveMode() == "on"
        if
            not force
            and enabled == customEnabled
            and previousMode == ActiveMode()
            and previousCommittedMode == sctMode
        then
            if incomingChanged then NotifySettings() end
            return
        end
        -- Persist only the committed mode, never the effective editor preview.
        _G.SurvivorsDragonUiSctMode = sctMode
        customEnabled = enabled
        ResetDisplay()
        SyncScrollRoot()
        ApplyPlateTracking(true)
        if CustomEnabled() and damageIcons then RebuildSpellTextures() end
        -- Plate appearance stays active even while combat text is disabled.
        ScanPlates(true)
        NotifySettings()
    end

    function sct.GetMode() return ActiveMode() end
    function sct.NormalizeMode(mode) return IsMode(mode) and mode or "default" end
    function sct.GetIncoming() return ReadIncoming() == "1" end
    function sct.BeginEdit()
        if not settingsDraft then settingsDraft = {} end
    end
    function sct.SetMode(mode)
        if not settingsDraft or not IsMode(mode) then return end
        settingsDraft.mode = mode
        if mode == "default" then
            RestoreSetting(settingsDraft, "damage", ReadNativeDamage, WriteNativeDamage)
        else
            PreviewSetting("damage", "0", ReadNativeDamage, WriteNativeDamage)
        end
        SyncGameSettings(true)
    end
    function sct.SetIncoming(enabled)
        if not settingsDraft or type(enabled) ~= "boolean" then return end
        PreviewSetting("incoming", enabled and "1" or "0", ReadIncoming, WriteIncoming)
        SyncGameSettings(false)
    end
    function sct.FinishEdit(save)
        if not settingsDraft then return end
        local selection = settingsDraft
        settingsDraft = nil
        if save then
            if selection.mode then sctMode = selection.mode end
            _G.SurvivorsDragonUiSctMode = sctMode
        else
            RestoreSetting(selection, "damage", ReadNativeDamage, WriteNativeDamage)
            RestoreSetting(selection, "incoming", ReadIncoming, WriteIncoming)
        end
        SyncGameSettings(false)
        NotifySettings()
    end
    function sct.Listen(callback)
        if type(callback) == "function" then table.insert(settingsListeners, callback) end
    end

    local frame = CreateFrame("Frame", "DFRL_NameplateCombatText")
    for eventName in pairs(T.NameplateCombatEventHandlers) do
        frame:RegisterEvent(eventName)
    end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LEAVING_WORLD")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("CVAR_UPDATE")
    frame:SetScript("OnEvent", function()
        local eventTime = T.NameplateCombatEventHandlers[event] and GetTime() or nil
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            DirtySpellTextures()
            plateFilter.age = 0.2
            iconSourcesDirty.talents, iconSourcesDirty.debuffs = true, true
            iconSourcesDirty.target, iconSourcesDirty.mouseover = true, true
            enemyPlatesEnabled = _G.NAMEPLATES_ON and true or false
            SyncGameSettings(true)
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            sct.FinishEdit(false)
            inWorld = false
            SyncScrollRoot()
            plateFilter.Clear(plateFilter.sequence)
            plateFilter.time, plateFilter.zone = nil, nil
            for _, data in pairs(plates) do
                RestorePresentation(data, true)
            end
            ApplyPlateTracking(true)
            ResetDisplay()
            ResetLearnedSpellTextures()
        elseif event == "SPELLS_CHANGED" then
            DirtySpellTextures()
            iconSourcesDirty.talents = true
        elseif event == "CHARACTER_POINTS_CHANGED" then
            iconSourcesDirty.talents = true
        elseif event == "PLAYER_TARGET_CHANGED" then
            iconSourcesDirty.target = true
            ScanPlates(false)
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            iconSourcesDirty.mouseover = true
        elseif event == "UNIT_AURA" then
            if arg1 == "target" or arg1 == "mouseover" then iconSourcesDirty[arg1] = true end
        elseif event == "CHAT_MSG_ADDON" then
            plateFilter.Receipt(arg1)
            if arg1 == "AZSDEBUFFS" then
                iconSourcesDirty.debuffs = true
            elseif arg1 == "AZSZONE" then
                ClearSummonIcons()
                iconSourcesDirty.debuffs = true
            end
        elseif event == "CVAR_UPDATE" then
            SyncGameSettings(false)
        else
            SyncGameSettings(false)
            HandleCombatEvent(event, arg1, eventTime)
        end
    end)
    frame:SetScript("OnUpdate", function()
        if not inWorld then return end
        -- Observe outgoing CVar changes without writing; the independent
        -- incoming/self global is read only for its editor control.
        SyncGameSettings(false)
        plateFilter.Update(arg1)
        ScanPlates(false)
        -- Native plate allocation follows this update. The first accepted hit
        -- in the next event batch must inspect that roster, even if GetTime
        -- still has this update's value; later hits can share the discovery.
        combatDiscoveryNeeded = true
        if not CustomEnabled() then return end
        local now = GetTime()
        UpdatePending(now)
        UpdateTexts(now, arg1)
    end)

    hooksecurefunc("HideNameplates", function()
        enemyPlatesEnabled = false
        -- Keep the backing feed alive while masking hostile plate visuals and
        -- clicks. Existing origins and hit animations continue to track mobs.
        ApplyPlateTracking(true)
    end)
    hooksecurefunc("ShowNameplates", function()
        enemyPlatesEnabled = true
        ApplyPlateTracking(true)
        ScanPlates(true)
    end)

    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            -- Restore native preview values before ReloadUI can serialize them.
            sct.FinishEdit(false)
            inWorld = false
            for _, data in pairs(plates) do
                RestorePresentation(data, true)
            end
            return reloadUI()
        end
    end

    SyncGameSettings(true)
end)
