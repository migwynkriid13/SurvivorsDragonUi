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
    local origins = {}
    local activeTexts = {}
    local textPool = {}
    local textRoot
    local pending = {}
    local pendingGroups = {}
    local intakeBuckets = {}
    local spellTextures = {}
    local missingSpellTextures = {}
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

    local function CustomEnabled() return customEnabled end
    local function UsesPlateOrigins() return CustomEnabled() and not msbtStyle end

    local function IsFiniteNumber(value) return type(value) == "number" and value - value == 0 end

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
                if maxima[entry.hpm] ~= false then maxima[entry.hpm] = entry.kind ~= "elite" end
            end
        end
        for name, maxima in pairs(plateFilter.names) do
            if not next(maxima) then plateFilter.names[name] = nil end
        end
        plateFilter.source, plateFilter.stamp, plateFilter.accepted = entries, stamp, plateFilter.units
    end
    function plateFilter.Matches(data)
        local name = data.nameRegion and data.nameRegion:GetText()
        local maxima = name and plateFilter.names[name]
        if not maxima then return false end
        local minimum, maximum = data.bar:GetMinMaxValues()
        -- Anonymous plates expose no spawn ID; never equate percentage bars to HP.
        return minimum == 0 and maxima[maximum] == true
    end
    DFRL.locale.Listen(function()
        plateFilter.Clear()
        plateFilter.age = 0.2
    end)

    local function IsEnemyPlate(data)
        if not data.bar or not data.bar.GetStatusBarColor then return false end
        local red, green, blue = data.bar:GetStatusBarColor()
        if not red or not green or not blue then return false end
        -- Ignore green/blue friendly plates requested by Shift-V.
        return not (green > red + 0.1 and green > blue + 0.1) and not (blue > red + 0.1 and blue > green + 0.1)
    end
    local function MaskFrame(frame, state, masked)
        if
            not frame.DisableDrawLayer
            or not frame.EnableDrawLayer
            or not frame.GetHitRectInsets
            or not frame.SetHitRectInsets
        then
            return
        end
        if masked and not state.masked then
            local left, right, top, bottom = frame:GetHitRectInsets()
            state.insets = { left or 0, right or 0, top or 0, bottom or 0 }
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
            -- An empty mouse rectangle survives native freelook flag changes.
            -- Leave the native mouse-enabled state, size and position intact.
            frame:SetHitRectInsets(1000000, 1000000, 1000000, 1000000)
            state.masked = true
        elseif not masked and state.masked then
            for _, layer in ipairs(drawLayers) do
                if state.layers[layer] then
                    frame:EnableDrawLayer(layer)
                else
                    frame:DisableDrawLayer(layer)
                end
            end
            frame:SetHitRectInsets(state.insets[1], state.insets[2], state.insets[3], state.insets[4])
            state.masked, state.layers, state.insets = nil, nil, nil
        end
    end
    local function RestorePresentation(data)
        for frame, state in pairs(data.presentation) do
            MaskFrame(frame, state, false)
        end
        if plateStyle then plateStyle.SetMasked(data, false) end
        data.presentationMasked = false
    end
    local function UpdatePresentation(plate, data, force)
        local hiddenByV = UsesPlateOrigins() and not enemyPlatesEnabled
        local masked = trackingSupported
                and inWorld
                and (hiddenByV or plateFilter.enabled)
                and IsEnemyPlate(data)
                and (hiddenByV or not plateFilter.Matches(data))
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
        text.anchorPoint, text.anchorX, text.anchorY = nil, nil, nil
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
        recentDamage = {}
        for _, data in pairs(plates) do
            data.origin = nil
        end
        discoveredChildren = 0
        combatDiscoveryNeeded = true
    end

    local function IsShownEnemy(plate, data)
        if not UsesPlateOrigins() or not inWorld or not plate:IsShown() then return false end
        if plate.IsVisible and not plate:IsVisible() then return false end
        return IsEnemyPlate(data)
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

    local function SampleHealth(data, origin, now)
        if not data.bar.GetValue or not data.bar.GetMinMaxValues then return end
        local minimum, maximum = data.bar:GetMinMaxValues()
        local value = data.bar:GetValue()
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
        data.origin = nil
    end

    local function RefreshPlate(plate, data, now, forcePresentation, geometry)
        if not plate:IsShown() then
            RetirePlate(plate)
            return
        end
        UpdatePresentation(plate, data, forcePresentation)
        -- Hidden tracking still samples native data, but its skin has no pixels
        -- to refresh. Unmasking updates the skin in this same callback.
        if plateStyle and not data.presentationMasked then
            plateStyle.Update(plate, data, nameplatesNamesOnly, nameplateFontSize)
        end
        if not IsShownEnemy(plate, data) then
            RetirePlate(plate)
            return
        end
        local name = data.nameRegion and data.nameRegion:GetText()
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
        end
        origin.lastSeen = now
        SamplePosition(plate, origin, now, geometry)
        SampleHealth(data, origin, now)
    end

    local function DiscoverPlate(plate, now, geometry)
        if not plate or not plate.GetRegions or plates[plate] then return end
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
        local data = { nameRegion = name, bar = bar, nativeRegions = regions, presentation = {} }
        plates[plate] = data
        -- Build the skin before the first recursive mask so V-off tracking
        -- covers every visual child without touching the SCT data sources.
        if plateStyle then plateStyle.Attach(plate, data) end
        HookScript(plate, "OnHide", function() RetirePlate(plate) end)
        HookScript(plate, "OnShow", function()
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
        for plate, data in pairs(plates) do
            RefreshPlate(plate, data, now, force, geometry)
        end
        for index = table.getn(origins), 1, -1 do
            local origin = origins[index]
            if not origin.live and now - (origin.hiddenAt or origin.lastSeen) > RECENT_PLATE_TIME then
                table.remove(origins, index)
            end
        end
    end

    local function UseLoss(origin, info)
        if info.kind ~= "damage" then return end
        if origin.absoluteHealth then origin.lossRemaining = math.max(0, (origin.lossRemaining or 0) - info.amount) end
        -- Percentage bars cannot be consumed by absolute amounts. Their loss
        -- remains timing evidence for the whole short combat-message burst.
    end

    local function ResolveOrigin(info, now, allowFallback)
        local candidateCount, lossCount, exactCount = 0, 0, 0
        local candidateOrigin, lossOrigin, exactOrigin
        local candidateX, candidateY, lossX, lossY = 0, 0, 0, 0
        for index = 1, table.getn(origins) do
            local origin = origins[index]
            if
                origin.name == info.targetName
                and origin.x
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
            return origin.x, origin.y, origin
        end
        if not allowFallback then return nil end
        -- The 1.12 chat API has no destination GUID. Keep every event visible,
        -- even when it cannot distinguish identical names or no plate was
        -- rendered before a lethal hit. A shared origin avoids claiming
        -- an arbitrary enemy is the exact destination.
        if lossCount > 0 then return lossX / lossCount, lossY / lossCount, nil end
        if candidateCount > 0 then return candidateX / candidateCount, candidateY / candidateCount, nil end
        return WorldFrame:GetWidth() * 0.5, WorldFrame:GetHeight() * 0.58, nil
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
    end

    -- The accepted pet view supplies exact native localized names and its
    -- resolved portrait paths; the shared resolver owns only display metadata.
    local summonIcons, summonLanguage = {}, nil
    local function ClearSummonIcons()
        summonIcons, summonLanguage = {}, nil
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
    local function ResetLearnedSpellTextures()
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

    local function RebuildSpellTextures(keepMisses)
        spellTextures = {}
        if not keepMisses then missingSpellTextures = {} end
        if
            type(_G.GetNumSpellTabs) ~= "function"
            or type(_G.GetSpellTabInfo) ~= "function"
            or type(_G.GetSpellName) ~= "function"
            or type(_G.GetSpellTexture) ~= "function"
        then
            return
        end
        local book = BOOKTYPE_SPELL or "spell"
        for tab = 1, GetNumSpellTabs() or 0 do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local name = GetSpellName(index, book)
                local texture = GetSpellTexture(index, book)
                if name and TextureKey(texture) then spellTextures[name] = texture end
            end
        end
    end

    local function NativeItemIcon(name)
        local catalogs = T.SourceItemIconCatalog
        local catalog = catalogs and (catalogs[DFRL.locale.code] or catalogs.en)
        return catalog and catalog[name]
    end

    local function CombatIcon(info)
        if info.spell and info.spell ~= "" then
            local texture = spellTextures[info.spell]
            if not texture and not missingSpellTextures[info.spell] then
                RebuildSpellTextures(true)
                texture = spellTextures[info.spell]
                missingSpellTextures[info.spell] = not texture
            end
            if not texture then
                RefreshLearnedSpellTextures()
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
            end
            if texture == nil then texture = ItemIcon(info.spell) end
            return texture or FALLBACK_ICON
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
        group.remaining = group.remaining + 1
        table.insert(pending, { info = info, time = now, group = group })
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
        if text.anchorPoint == relativePoint and text.anchorX == x and text.anchorY == y then return end
        text.holder:SetPoint("CENTER", WorldFrame, relativePoint, x, y)
        text.anchorPoint, text.anchorX, text.anchorY = relativePoint, x, y
    end

    DFRL.display.Listen(function()
        local scrolling = DFRL.display.Get("sctMSBTStyle")
        if msbtStyle ~= scrolling then
            msbtStyle = scrolling
            -- Do not move old hits between unrelated coordinate systems, or
            -- replay a queued enemy hit in the fixed screen stream.
            ResetDisplay()
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
        if not text then
            if not textRoot then
                -- Native child-count queries copy the direct-child list. Keep
                -- the growing hit pool out of the nameplate discovery roster.
                textRoot = CreateFrame("Frame", nil, WorldFrame)
                textRoot:SetAllPoints(WorldFrame)
                textRoot:SetFrameStrata("HIGH")
                textRoot:SetFrameLevel(WorldFrame:GetFrameLevel())
                textRoot:EnableMouse(false)
            end
            local holder = CreateFrame("Frame", nil, textRoot)
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
        return text
    end

    local function DamageColor(info, now)
        -- Critical status comes from the parsed native message, never from
        -- damage size. Crits and miss labels do not affect normal-hit averages.
        if info.kind ~= "damage" then return DAMAGE_COLORS.strong end
        if info.critical then return DAMAGE_COLORS.critical end
        if info.damageType ~= "autoattack" and (not info.spell or info.spell == "") then return DAMAGE_COLORS.normal end
        local key = table.concat({
            info.sourceName or "",
            info.damageType or "",
            info.school or "",
            info.spell or "",
        }, "\031")
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
        -- layout uses offsets from screen center and needs no enemy position.
        if msbtStyle then
            x, y = MSBT.x, MSBT.top - 12
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
        local count = table.getn(pending)
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

        local groupCount = table.getn(pendingGroups)
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
            if group.remaining == 0 and not group.bucket then
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
                local y = MSBT.top - MSBT.height * progress
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
        if msbtStyle and count > 0 then PrepareScrollPositions(now, elapsed) end
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
                    x = MSBT.x + MSBT.curve * 4 * progress * (1 - progress)
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
            plateFilter.age = 0.2
            iconSourcesDirty.talents, iconSourcesDirty.debuffs = true, true
            iconSourcesDirty.target, iconSourcesDirty.mouseover = true, true
            enemyPlatesEnabled = _G.NAMEPLATES_ON and true or false
            SyncGameSettings(true)
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            sct.FinishEdit(false)
            inWorld = false
            plateFilter.Clear(plateFilter.sequence)
            plateFilter.time, plateFilter.zone = nil, nil
            for _, data in pairs(plates) do
                RestorePresentation(data)
            end
            ApplyPlateTracking(true)
            ResetDisplay()
            ResetLearnedSpellTextures()
        elseif event == "SPELLS_CHANGED" then
            iconSourcesDirty.talents = true
            if CustomEnabled() and damageIcons then RebuildSpellTextures() end
        elseif event == "CHARACTER_POINTS_CHANGED" then
            iconSourcesDirty.talents = true
        elseif event == "PLAYER_TARGET_CHANGED" then
            iconSourcesDirty.target = true
            ScanPlates(true)
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
            return reloadUI()
        end
    end

    SyncGameSettings(true)
end)
