-- XP gain animation source research and artwork: third_party/XPBar-ANIMATION.md.
-- The joined shell reuses the bundled action-bar artwork. Blizzard artwork
-- remains Blizzard Entertainment's property; see third_party/XP-ARTWORK.md.
DFRL:NewMod("Xprep", 1, function()
    local texpath = DFRL:GetInfoOrCons("tex") .. "xprep\\"
    local fillTexture = texpath .. "main_soft.tga"
    local defaults = { top = 49, height = 6, borderHeight = 12 }
    DFRL.xpBarDefaults = defaults
    KillFrame(MainMenuBarPerformanceBarFrame)
    KillFrame(MainMenuExpBar)
    KillFrame(ReputationWatchBar)

    local hud = CreateFrame("Frame", "SurvivorsDragonUiXP", UIParent)
    hud:SetHeight(defaults.height)
    hud:SetFrameStrata("LOW")
    hud:EnableMouse(false)
    hud:Hide()
    local detached = CreateFrame("Frame", "SurvivorsDragonUiDetachedXP", UIParent)
    detached:SetHeight(defaults.height)
    detached:SetFrameStrata("LOW")
    detached:EnableMouse(false)
    detached:Hide()

    local bar = CreateFrame("StatusBar", "DFRL_XPBar", hud)
    bar:SetHeight(defaults.height)
    bar:SetFrameStrata("LOW")
    bar:SetStatusBarTexture(fillTexture)
    bar:SetStatusBarColor(0.85, 0.4, 0.85)
    bar:EnableMouse(false)
    bar:Hide()

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    background:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- Border halves stay inside the same horizontal bounds as the bar.
    local leftBorder = bar:CreateTexture(nil, "OVERLAY")
    leftBorder:SetTexture(texpath .. "border_half.tga")
    leftBorder:SetPoint("LEFT", bar, "LEFT", 0, 0)
    leftBorder:SetPoint("RIGHT", bar, "CENTER", 0, 0)
    leftBorder:SetHeight(defaults.borderHeight)

    local rightBorder = bar:CreateTexture(nil, "OVERLAY")
    rightBorder:SetTexture(texpath .. "border_half.tga")
    rightBorder:SetPoint("LEFT", bar, "CENTER", 0, 0)
    rightBorder:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    rightBorder:SetHeight(defaults.borderHeight)
    rightBorder:SetTexCoord(1, 0, 0, 1)

    -- Two passive regions reuse the fill and the native spark already used by
    -- the run timer. Both stay below the original metal border.
    local gain = bar:CreateTexture(nil, "ARTWORK")
    gain:SetTexture(fillTexture)
    gain:SetBlendMode("ADD")
    gain:SetVertexColor(0.9, 0.55, 1)
    gain:SetHeight(defaults.height)
    gain:Hide()
    local spark = bar:CreateTexture(nil, "ARTWORK")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetVertexColor(1, 0.75, 1)
    spark:SetHeight(defaults.height + 4)
    spark:Hide()

    local attached, registered, editing = false, false, false
    local docked
    local inWorld = UnitExists("player") and true or false
    local previousXP, previousMaximum, previousLevel
    local displayed, desired = 0, 0
    local origin, destination, gainStart, age, duration, fadeAge
    local wrapping, pending, instant = false, false, false
    local events = CreateFrame("Frame")
    local OnUpdate

    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end

    local function StopAnimation()
        origin, destination, gainStart, age, duration, fadeAge = nil, nil, nil, nil, nil, nil
        wrapping = false
        displayed = desired
        bar:SetValue(displayed)
        gain:Hide()
        spark:Hide()
        if not pending then events:SetScript("OnUpdate", nil) end
    end

    local function ShowXP(shown)
        if shown and attached then
            if docked then
                detached:Hide()
            else
                detached:Show()
            end
            hud:Show()
            bar:Show()
        else
            bar:Hide()
            hud:Hide()
            detached:Hide()
        end
        if DFRL.SetXPBarJoined then DFRL.SetXPBarJoined(docked and shown and attached or false) end
    end

    local function UpdateAttachment()
        if not attached then return false end
        local joined = DFRL.display.Get("attachXP")
        if docked == joined then return false end
        StopAnimation()
        hud:Hide()
        docked = joined
        local owner = joined and DFRL.mainBar or detached
        hud:SetParent(owner)
        hud:SetScale(1)
        hud:SetFrameLevel(owner:GetFrameLevel() + 2)
        bar:SetFrameLevel(hud:GetFrameLevel() + 1)
        hud:ClearAllPoints()
        bar:ClearAllPoints()
        if joined then
            local action = DFRL.actionBarDefaults
            hud:SetPoint("TOP", owner, "BOTTOM", 0, action.xpTop)
            bar:SetPoint("TOPLEFT", hud, "TOPLEFT", action.xpInset, 0)
            bar:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -action.xpInset, 0)
            leftBorder:Hide()
            rightBorder:Hide()
        else
            hud:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
            bar:SetAllPoints(hud)
            leftBorder:Show()
            rightBorder:Show()
        end
        return true
    end

    local function PaintGlow(alpha)
        local width = T.GetLocalSize(bar)
        local left, right = (gainStart or displayed) * width, displayed * width
        if right > left and alpha > 0 then
            gain:ClearAllPoints()
            gain:SetPoint("LEFT", bar, "LEFT", left, 0)
            gain:SetWidth(right - left)
            gain:SetAlpha(alpha * 0.65)
            gain:Show()
        else
            gain:Hide()
        end
        -- Crop the moving spark at the bar's ends instead of leaking past them.
        local sparkLeft, sparkRight = math.max(0, right - 6), math.min(width, right + 6)
        if sparkRight > sparkLeft and displayed > 0 and alpha > 0 then
            spark:ClearAllPoints()
            spark:SetPoint("LEFT", bar, "LEFT", sparkLeft, 0)
            spark:SetWidth(sparkRight - sparkLeft)
            spark:SetTexCoord((sparkLeft - right + 6) / 12, (sparkRight - right + 6) / 12, 0, 1)
            spark:SetAlpha(alpha)
            spark:Show()
        else
            spark:Hide()
        end
    end

    local function BeginGain(value)
        origin, destination, age, fadeAge = displayed, value, 0, nil
        gainStart = gainStart or displayed
        -- Use retail's distance-based pacing, bounded for this much shorter bar.
        local width = T.GetLocalSize(bar)
        duration = math.max(0.18, math.min(0.45, (value - displayed) * width * 0.008))
        events:SetScript("OnUpdate", OnUpdate)
    end

    local function UpdateXP(animate)
        local currentXP, maximumXP, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
        if not inWorld or not Number(currentXP) or not Number(maximumXP) or maximumXP <= 0 then
            previousXP, previousMaximum, previousLevel = nil, nil, nil
            desired = 0
            StopAnimation()
            ShowXP(false)
            return
        end
        currentXP = math.min(currentXP, maximumXP)
        if not Number(level) or level < 1 then level = nil end
        desired = currentXP / maximumXP
        bar:SetMinMaxValues(0, 1)
        local canAnimate = animate
            and not editing
            and attached
            and bar:IsVisible()
            and previousXP
            and previousLevel
            and level
        if canAnimate and level == previousLevel + 1 and not wrapping then
            -- One observed level transition: finish the known old bar, then show
            -- the received new-level fraction. Never invent intermediate levels.
            wrapping = true
            BeginGain(1)
        elseif canAnimate and level == previousLevel and maximumXP == previousMaximum and currentXP >= previousXP then
            if not wrapping and currentXP > previousXP then BeginGain(desired) end
        else
            StopAnimation()
        end
        previousXP, previousMaximum, previousLevel = currentXP, maximumXP, level
        ShowXP(true)
    end

    OnUpdate = function()
        local elapsed = Number(arg1) and arg1 or 0
        -- Read after native XP/level event delivery so one update sees the latest
        -- native tuple. The updater exists only for pending reads or visible FX.
        if pending then
            local animate = not instant
            pending, instant = false, false
            UpdateXP(animate)
        end
        if not destination then
            if not pending then events:SetScript("OnUpdate", nil) end
            return
        end
        if not bar:IsVisible() then
            StopAnimation()
            return
        end
        if fadeAge then
            fadeAge = fadeAge + elapsed
            if fadeAge >= 0.35 then
                StopAnimation()
                return
            end
            PaintGlow(1 - fadeAge / 0.35)
            return
        end
        age = age + elapsed
        local progress = math.min(age / duration, 1)
        local eased = 1 - (1 - progress) * (1 - progress) * (1 - progress)
        displayed = origin + (destination - origin) * eased
        bar:SetValue(displayed)
        PaintGlow(math.min(1, age / 0.08))
        if progress < 1 then return end
        if wrapping then
            wrapping = false
            displayed, gainStart = 0, nil
            bar:SetValue(0)
            gain:Hide()
            spark:Hide()
            if desired > 0 then
                BeginGain(desired)
            else
                StopAnimation()
            end
        else
            fadeAge = 0
        end
    end

    bar:SetScript("OnHide", StopAnimation)
    bar:SetScript("OnShow", function()
        pending, instant = true, true
        events:SetScript("OnUpdate", OnUpdate)
    end)

    function DFRL.AttachXPBar(mainBar)
        local width = mainBar:GetWidth() + 2 * DFRL.actionBarDefaults.sideInset
        hud:SetWidth(width)
        detached:SetWidth(width)
        if not registered then
            local moveRegion = CreateFrame("Frame", nil, detached)
            local borderInset = (defaults.borderHeight - defaults.height) / 2
            moveRegion:SetPoint("TOPLEFT", detached, "TOPLEFT", 0, borderInset)
            moveRegion:SetPoint("BOTTOMRIGHT", detached, "BOTTOMRIGHT", 0, -borderInset)
            DFRL.layout.Register("xpBar", detached, function()
                detached:ClearAllPoints()
                detached:SetPoint("TOP", UIParent, "BOTTOM", 0, defaults.top)
            end, {
                region = moveRegion,
                onlyWhenShown = true,
                onEdit = function(active)
                    editing = active
                    StopAnimation()
                end,
                onReset = StopAnimation,
            })
            registered = true
        else
            DFRL.layout.Place("xpBar", detached)
        end
        attached = true
        UpdateAttachment()
        UpdateXP(false)
        if DFRL.AttachRunTally then DFRL.AttachRunTally() end
    end

    DFRL.display.Listen(function()
        if UpdateAttachment() then UpdateXP(false) end
    end)
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LEAVING_WORLD")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld, pending, instant = false, false, false
            previousXP, previousMaximum, previousLevel = nil, nil, nil
            desired = 0
            StopAnimation()
            ShowXP(false)
        elseif event ~= "PLAYER_XP_UPDATE" or arg1 == "player" or arg1 == nil then
            if event == "PLAYER_ENTERING_WORLD" then
                inWorld, instant = true, true
                previousXP, previousMaximum, previousLevel = nil, nil, nil
            end
            if inWorld then
                pending = true
                events:SetScript("OnUpdate", OnUpdate)
            end
        end
    end)
    DFRL.xpBar = hud
    -- The bar may already exist, or its world-entry callback will attach us.
    if DFRL.mainBar then DFRL.AttachXPBar(DFRL.mainBar) end
end)
