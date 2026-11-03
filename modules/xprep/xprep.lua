-- XP gain animation source research and artwork: third_party/XPBar-ANIMATION.md.
-- The joined shell reuses the bundled action-bar artwork. Blizzard artwork
-- remains Blizzard Entertainment's property; see third_party/XP-ARTWORK.md.
DFRL:NewMod("Xprep", 1, function()
    local texpath = DFRL:GetInfoOrCons("tex") .. "xprep\\"
    local fillTexture = texpath .. "main_soft.blp"
    local defaults = { top = 49, height = 6, borderHeight = 12 }
    DFRL.xpBarDefaults = defaults

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
    bar:SetMinMaxValues(0, 1)
    bar:EnableMouse(false)
    bar:Hide()
    local fill = T.NewClippedFill(bar)
    fill.SetTexture(fillTexture)
    fill.SetColor(0.85, 0.4, 0.85)
    local function SetProgress(value)
        bar:SetValue(value)
        fill.SetFraction(value)
    end

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    background:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- The fill and gain effects each paint through a scroll callback. Keep
    -- the border and caption above both, within the same horizontal bounds.
    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)
    overlay:EnableMouse(false)
    local leftBorder = overlay:CreateTexture(nil, "OVERLAY")
    leftBorder:SetTexture(texpath .. "border_half.blp")
    leftBorder:SetPoint("LEFT", bar, "LEFT", 0, 0)
    leftBorder:SetPoint("RIGHT", bar, "CENTER", 0, 0)
    leftBorder:SetHeight(defaults.borderHeight)

    local rightBorder = overlay:CreateTexture(nil, "OVERLAY")
    rightBorder:SetTexture(texpath .. "border_half.blp")
    rightBorder:SetPoint("LEFT", bar, "CENTER", 0, 0)
    rightBorder:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    rightBorder:SetHeight(defaults.borderHeight)
    rightBorder:SetTexCoord(1, 0, 0, 1)

    -- Two passive regions reuse the fill and the native spark already used by
    -- the run timer. Both stay below the original metal border.
    local gain, spark, sparkClip, sparkCanvas
    local function PrepareEffects()
        if sparkClip then return end
        local sparkHeight = defaults.height + 4
        sparkClip = CreateFrame("ScrollFrame", nil, bar)
        sparkClip:SetFrameLevel(bar:GetFrameLevel() + 1)
        sparkClip:SetPoint("LEFT", bar, "LEFT", 0, 0)
        sparkClip:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        sparkClip:SetHeight(sparkHeight)
        sparkClip:EnableMouse(false)
        sparkClip:Hide()
        sparkCanvas = CreateFrame("Frame", nil, sparkClip)
        sparkCanvas:SetWidth(1)
        sparkCanvas:SetHeight(1)
        sparkCanvas:EnableMouse(false)
        sparkClip:SetScrollChild(sparkCanvas)
        gain = sparkCanvas:CreateTexture(nil, "ARTWORK")
        gain:SetTexture(fillTexture)
        gain:SetBlendMode("ADD")
        gain:SetVertexColor(0.9, 0.55, 1)
        gain:SetHeight(defaults.height)
        gain:Hide()
        spark = sparkCanvas:CreateTexture(nil, "ARTWORK")
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        spark:SetBlendMode("ADD")
        spark:SetVertexColor(1, 0.75, 1)
        spark:SetWidth(12)
        spark:SetHeight(sparkHeight)
    end

    local attached, registered, editing = false, false, false
    local docked
    local inWorld = UnitExists("player") and true or false
    local customActionBar = DFRL.display.Get("customActionBar") ~= false
    local stockXP, stockOwned = {}, false
    -- The native level-cap strip has its own frame, separate from MainMenuExpBar.
    for _, name in ipairs({
        "MainMenuBarPerformanceBarFrame",
        "MainMenuExpBar",
        "MainMenuBarMaxLevelBar",
        "ReputationWatchBar",
    }) do
        local frame = _G[name]
        if frame then table.insert(stockXP, { frame = frame }) end
    end
    local function UpdateStockXP()
        local owned = inWorld and customActionBar
        if stockOwned == owned then return end
        stockOwned = owned
        for _, entry in ipairs(stockXP) do
            -- Lua 5.0 reuses iterator variables; retained callbacks need their
            -- own binding after the loop advances and finally yields nil.
            local state = entry
            local frame = state.frame
            if owned then
                local originalShow, originalHide, originalOnShow = frame.Show, frame.Hide, frame:GetScript("OnShow")
                state.originalShow, state.originalHide, state.originalOnShow =
                    originalShow, originalHide, originalOnShow
                state.shown = frame:IsShown()
                local show, hide, onShow
                show = function(self)
                    if not stockOwned or state.show ~= show then return originalShow(self) end
                    state.shown = true
                    if self:IsShown() then return originalHide(self) end
                end
                hide = function(self)
                    if stockOwned and state.hide == hide then state.shown = false end
                    return originalHide(self)
                end
                onShow = function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
                    local active = stockOwned and state.onShow == onShow
                    if active then state.shown = true end
                    if originalOnShow then originalOnShow(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
                    if active then originalHide(frame) end
                end
                state.show, state.hide, state.onShow = show, hide, onShow
                frame.Show, frame.Hide = show, hide
                frame:SetScript("OnShow", onShow)
                if frame:IsShown() then originalHide(frame) end
            else
                if frame.Show == state.show then frame.Show = state.originalShow end
                if frame.Hide == state.hide then frame.Hide = state.originalHide end
                if frame:GetScript("OnShow") == state.onShow then frame:SetScript("OnShow", state.originalOnShow) end
                if state.shown and not frame:IsShown() then
                    frame:Show()
                elseif not state.shown and frame:IsShown() then
                    frame:Hide()
                end
            end
        end
    end
    local previousXP, previousMaximum, previousLevel
    local displayed, desired = 0, 0
    local origin, destination, gainStart, age, duration, fadeAge
    local wrapping, pending, instant = false, false, false
    local performanceMode = DFRL.display.Get("performanceMode")
    local showText = DFRL.display.Get("xpShowText")
    local xpText
    local events = CreateFrame("Frame")
    local OnUpdate
    local updating = false

    local function SetUpdates(active)
        if updating == active then return end
        events:SetScript("OnUpdate", active and OnUpdate or nil)
        updating = active
    end
    local function Number(value) return type(value) == "number" and value - value == 0 and value >= 0 end

    local function UpdateXPText()
        if
            not showText
            or not customActionBar
            or not inWorld
            or not attached
            or not bar:IsVisible()
            or not previousXP
            or not previousMaximum
        then
            if xpText and xpText:IsShown() then xpText:Hide() end
            return
        end
        if not xpText then
            xpText = overlay:CreateFontString(nil, "OVERLAY")
            xpText:SetPoint("LEFT", bar, "LEFT", 4, 0)
            xpText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
            xpText:SetHeight(12)
            xpText:SetJustifyH("CENTER")
            xpText:SetJustifyV("MIDDLE")
            xpText:SetTextColor(1, 1, 1)
            T.SetChatShadow(xpText)
        end
        T.SetFont(xpText, 9, "OUTLINE")
        if not xpText:GetFont() then return end
        if xpText.current ~= previousXP or xpText.maximum ~= previousMaximum then
            T.SetTextIfChanged(xpText, string.format("%.0f/%.0f", previousXP, previousMaximum))
            xpText.current, xpText.maximum = previousXP, previousMaximum
        end
        if not xpText:IsShown() then xpText:Show() end
    end

    local function StopAnimation()
        origin, destination, gainStart, age, duration, fadeAge = nil, nil, nil, nil, nil, nil
        wrapping = false
        displayed = desired
        if bar:IsVisible() and bar:GetValue() ~= displayed then SetProgress(displayed) end
        if gain and gain:IsShown() then gain:Hide() end
        if sparkClip and sparkClip:IsShown() then sparkClip:Hide() end
        if not pending then SetUpdates(false) end
    end

    local requestedShown, requestedDocked
    local function ShowXP(shown)
        shown = shown and attached and customActionBar and true or false
        if requestedShown == shown and requestedDocked == docked then return end
        requestedShown, requestedDocked = shown, docked
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
        requestedShown = nil
        hud:Hide()
        docked = joined
        local owner = joined and DFRL.mainBar or detached
        hud:SetParent(owner)
        hud:SetScale(1)
        hud:SetFrameLevel(owner:GetFrameLevel() + 2)
        local barLevel = hud:GetFrameLevel() + 1
        bar:SetFrameLevel(barLevel)
        fill.BindViewport()
        if sparkClip then
            sparkClip:SetScrollChild(sparkCanvas)
            sparkClip:SetFrameLevel(barLevel + 1)
        end
        overlay:SetFrameLevel(barLevel + 2)
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
        fill.RefreshWidth()
        return true
    end

    local function PaintGlow(alpha)
        local width = T.GetLocalWidth(bar)
        local left, right = (gainStart or displayed) * width, displayed * width
        if right > left and alpha > 0 then
            if gain.drawnLeft ~= left then
                gain:SetPoint("LEFT", bar, "LEFT", left, 0)
                gain.drawnLeft = left
            end
            if gain.drawnWidth ~= right - left then
                gain:SetWidth(right - left)
                gain.drawnWidth = right - left
            end
            if gain.drawnAlpha ~= alpha * 0.65 then
                gain:SetAlpha(alpha * 0.65)
                gain.drawnAlpha = alpha * 0.65
            end
            if not gain:IsShown() then gain:Show() end
        else
            if gain:IsShown() then gain:Hide() end
        end
        -- The viewport clips the ends without changing the spark's source UVs.
        if width > 0 and displayed > 0 and alpha > 0 then
            local sparkLeft = right - 6
            if spark.drawnLeft ~= sparkLeft then
                spark:SetPoint("LEFT", bar, "LEFT", sparkLeft, 0)
                spark.drawnLeft = sparkLeft
            end
            if spark.drawnAlpha ~= alpha then
                spark:SetAlpha(alpha)
                spark.drawnAlpha = alpha
            end
            if not sparkClip:IsShown() then sparkClip:Show() end
        else
            if sparkClip:IsShown() then sparkClip:Hide() end
        end
    end

    local function BeginGain(value)
        PrepareEffects()
        origin, destination, age, fadeAge = displayed, value, 0, nil
        gainStart = gainStart or displayed
        -- Use retail's distance-based pacing, bounded for this much shorter bar.
        local width = T.GetLocalWidth(bar)
        duration = math.max(0.18, math.min(0.45, (value - displayed) * width * 0.008))
        SetUpdates(true)
    end

    local function UpdateXP(animate)
        if not customActionBar or not inWorld then
            previousXP, previousMaximum, previousLevel = nil, nil, nil
            desired = 0
            StopAnimation()
            ShowXP(false)
            UpdateXPText()
            return
        end
        local currentXP, maximumXP, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
        if not inWorld or not Number(currentXP) or not Number(maximumXP) or maximumXP <= 0 then
            previousXP, previousMaximum, previousLevel = nil, nil, nil
            desired = 0
            StopAnimation()
            ShowXP(false)
            UpdateXPText()
            return
        end
        currentXP = math.min(currentXP, maximumXP)
        if not Number(level) or level < 1 then level = nil end
        desired = currentXP / maximumXP
        local canAnimate = animate
            and not performanceMode
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
        UpdateXPText()
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
            if not pending then SetUpdates(false) end
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
        SetProgress(displayed)
        PaintGlow(math.min(1, age / 0.08))
        if progress < 1 then return end
        if wrapping then
            wrapping = false
            displayed, gainStart = 0, nil
            SetProgress(0)
            gain:Hide()
            sparkClip:Hide()
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
    bar:SetScript("OnSizeChanged", function() fill.RefreshWidth() end)
    bar:SetScript("OnShow", function()
        SetProgress(desired)
        pending, instant = true, true
        SetUpdates(true)
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
        local selectedBar = DFRL.display.Get("customActionBar") ~= false
        local barChanged = customActionBar ~= selectedBar
        customActionBar = selectedBar
        if barChanged then
            StopAnimation()
            UpdateStockXP()
        end
        local selectedText = DFRL.display.Get("xpShowText")
        if showText ~= selectedText then
            showText = selectedText
            UpdateXPText()
        end
        local enabled = DFRL.display.Get("performanceMode")
        local changed = performanceMode ~= enabled
        performanceMode = enabled
        if changed then StopAnimation() end
        if UpdateAttachment() or changed or barChanged then UpdateXP(false) end
    end)
    function DFRL.ReleaseActionBarXP()
        inWorld, pending, instant = false, false, false
        UpdateStockXP()
        previousXP, previousMaximum, previousLevel = nil, nil, nil
        desired = 0
        StopAnimation()
        ShowXP(false)
        UpdateXPText()
    end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LEAVING_WORLD")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            DFRL.ReleaseActionBarXP()
        elseif event ~= "PLAYER_XP_UPDATE" or arg1 == "player" or arg1 == nil then
            if event == "PLAYER_ENTERING_WORLD" then
                inWorld, instant = true, true
                UpdateStockXP()
                previousXP, previousMaximum, previousLevel = nil, nil, nil
            end
            if inWorld and customActionBar then
                pending = true
                SetUpdates(true)
            end
        end
    end)
    DFRL.xpBar = hud
    UpdateStockXP()
    -- The bar may already exist, or its world-entry callback will attach us.
    if DFRL.mainBar then DFRL.AttachXPBar(DFRL.mainBar) end
end)
