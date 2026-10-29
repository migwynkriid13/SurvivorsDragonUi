-- One accepted AZS target publication owns labels, fill and health-loss fractions.
DFRL:NewMod("TargetHealth", 0, function()
    if not TargetFrame or not TargetFrameHealthBar then return end

    local health = {}
    DFRL.targetHealth = health
    local bar, controller = TargetFrameHealthBar, CreateFrame("Frame")
    local listeners = {}
    local inWorld, pending, painting = true, false, false
    local received, retiredReceived, generation = 0, -1, 0
    local retired, retiredStamp, accepted, acceptedStamp
    local current, maximum, name, spawn, kind
    local provisional = false
    local unitNames, unitSeen = {}, {}
    local unitSource, unitStamp, unitAccepted
    local unitReceived, unitParsed = 0, 0
    local blockedUnits, blockedUnitStamp, blockedUnitReceipt
    local runTime, boundaryPending
    local setRange, setValue = bar.SetMinMaxValues, bar.SetValue
    local kinds = { final = true, boss = true, guardian = true, elite = true, normal = true }

    local function Number(value) return type(value) == "number" and value >= 0 and value - value == 0 end
    local function Phase()
        if not inWorld or type(_G.AZS_GetPhase) ~= "function" then return end
        local ok, phase = pcall(_G.AZS_GetPhase)
        return ok and (phase == "playing" or phase == "choosing" or phase == "paused" or phase == "victory")
    end
    local function Enemy()
        return UnitExists("target") and not UnitIsPlayer("target") and UnitCanAttack("player", "target")
    end
    local function Clear()
        accepted, acceptedStamp, current, maximum, name, spawn, kind = nil, nil, nil, nil, nil, nil, nil
        generation = generation + 1
    end
    local function Retire()
        retired, retiredStamp, retiredReceived = _G.AZS_TARGET, _G.AZS_TARGET_UPDATED, received
        provisional = false
        Clear()
    end

    local function ClearRoster()
        local changed = unitAccepted ~= nil
        for unitName in pairs(unitNames) do
            unitNames[unitName] = nil
        end
        for id in pairs(unitSeen) do
            unitSeen[id] = nil
        end
        unitSource, unitStamp, unitAccepted = nil, nil, nil
        return changed
    end
    local function RetireRoster()
        blockedUnits, blockedUnitStamp, blockedUnitReceipt = _G.AZS_UNITS, _G.AZS_UNITS_UPDATED, unitReceived
        return ClearRoster()
    end
    local function ObserveRun()
        local run = _G.AZS_RUN
        if type(run) ~= "table" or not Number(_G.AZS_RUN_UPDATED) or not Number(run.t) then return false end
        local changed = runTime and run.t < runTime and RetireRoster() or false
        runTime = run.t
        return changed
    end
    local function PrepareRoster()
        if unitReceived ~= unitParsed or boundaryPending then return false end
        local source, stamp = _G.AZS_UNITS, _G.AZS_UNITS_UPDATED
        if source == blockedUnits and stamp == blockedUnitStamp and unitReceived == blockedUnitReceipt then
            return false
        end
        if source == unitSource and stamp == unitStamp and unitParsed == unitAccepted then return false end
        local valid = T.EncounterRosterSize(source, stamp) ~= nil and T.ValidateEncounterEntries(source, unitSeen)
        -- Keep the previous publication intact until the entire list is checked.
        for _, maxima in pairs(unitNames) do
            for value in pairs(maxima) do
                maxima[value] = nil
            end
        end
        if valid then
            for _, entry in ipairs(source) do
                if entry.hp > 0 then
                    local maxima = unitNames[entry.name]
                    if not maxima then
                        maxima = {}
                        unitNames[entry.name] = maxima
                    end
                    local borderKind = false
                    if entry.kind == "guardian" then
                        borderKind = "guardian"
                    elseif entry.kind == "boss" or entry.kind == "final" then
                        borderKind = "boss"
                    end
                    T.IndexUnitMaximum(maxima, entry.hpm, borderKind)
                end
            end
        end
        for unitName, maxima in pairs(unitNames) do
            if not next(maxima) then unitNames[unitName] = nil end
        end
        -- Cache invalid publications too; a later table/stamp/receipt retries them.
        unitSource, unitStamp, unitAccepted = source, stamp, unitParsed
        return true
    end

    function health.Get()
        if not inWorld or not UnitExists("target") then return nil, nil, generation end
        if UnitIsDead("target") or UnitIsGhost("target") then return 0, 1, generation end
        if type(_G.AZS_GetPhase) ~= "function" or UnitIsPlayer("target") then
            return UnitHealth("target"), UnitHealthMax("target"), generation
        end
        if not Phase() then
            if not Enemy() then return UnitHealth("target"), UnitHealthMax("target"), generation end
            return nil, nil, generation
        end
        if name and name == UnitName("target") then return current, maximum, generation end
        if not Enemy() then return UnitHealth("target"), UnitHealthMax("target"), generation end
        -- Selection is immediate; the full-precision packet can arrive later.
        -- Read this current unit, never the retired packet for a namesake.
        if provisional then
            local value, total = UnitHealth("target"), UnitHealthMax("target")
            if Number(value) and Number(total) and total > 0 and value <= total then return value, total, generation end
        end
        return nil, nil, generation
    end

    function health.GetKind()
        if
            kind
            and inWorld
            and UnitExists("target")
            and not UnitIsPlayer("target")
            and name == UnitName("target")
            and Phase()
        then
            return kind
        end
    end

    function health.GetBorderKind()
        if not TargetFrame:IsVisible() then return end
        local acceptedKind = health.GetKind()
        if acceptedKind then return acceptedKind end
        if not Phase() then
            RetireRoster()
            runTime = nil
            return
        end
        if
            not UnitExists("target")
            or UnitIsPlayer("target")
            or (type(UnitPlayerControlled) == "function" and UnitPlayerControlled("target"))
        then
            return
        end
        -- A packet being parsed cannot replace the copied roster. Keep its
        -- current cosmetic match until the existing deferred reader settles it.
        if not boundaryPending then ObserveRun() end
        PrepareRoster()
        local maxima = unitNames[UnitName("target")]
        if not maxima then return end
        local nativeMaximum = UnitHealthMax("target")
        if not Number(nativeMaximum) or nativeMaximum <= 0 then return end
        local borderKind = maxima[nativeMaximum]
        if borderKind then return borderKind end
    end

    function health.Listen(callback) table.insert(listeners, callback) end

    function health.Refresh()
        if painting or not bar:IsVisible() then return end
        painting = true
        local value, total = health.Get()
        local fraction = value and total and total > 0 and math.max(0, math.min(1, value / total)) or 0
        local low, high = bar:GetMinMaxValues()
        if low ~= 0 or high ~= 1 then setRange(bar, 0, 1) end
        if not T.NearlyEqual(bar:GetValue(), fraction) then setValue(bar, fraction) end
        painting = false
    end

    -- Native FrameXML still owns the widget and UVs, but its capped UNIT writes
    -- cannot replace the accepted AZS fraction while this view is visible.
    bar.SetMinMaxValues = function(self, low, high)
        if not self:IsVisible() then return setRange(self, low, high) end
        health.Refresh()
    end
    bar.SetValue = function(self, value)
        if not self:IsVisible() then return setValue(self, value) end
        health.Refresh()
    end

    local function Notify()
        health.Refresh()
        for _, callback in ipairs(listeners) do
            callback()
        end
    end
    local function Read()
        controller:SetScript("OnUpdate", nil)
        pending = false
        unitParsed, boundaryPending = unitReceived, false
        if not Phase() then
            RetireRoster()
            runTime = nil
            Retire()
            Notify()
            return
        end
        local rosterChanged = ObserveRun()
        if not TargetFrame:IsVisible() then return end
        rosterChanged = PrepareRoster() or rosterChanged
        local state, stamp = _G.AZS_TARGET, _G.AZS_TARGET_UPDATED
        if
            (state == accepted and stamp == acceptedStamp)
            or (state == retired and stamp == retiredStamp and received == retiredReceived)
        then
            if rosterChanged then Notify() end
            return
        end
        if
            type(state) ~= "table"
            or not Number(stamp)
            or not kinds[state.kind]
            or not Number(state.id)
            or state.id <= 0
            or state.id ~= math.floor(state.id)
            or type(state.name) ~= "string"
            or state.name == ""
            or not Number(state.hp)
            or not Number(state.hpm)
            or state.hpm <= 0
            or state.hp > state.hpm
            or not UnitExists("target")
            or UnitIsPlayer("target")
            or state.name ~= UnitName("target")
        then
            Clear()
            Notify()
            return
        end
        if spawn ~= state.id or name ~= state.name then generation = generation + 1 end
        accepted, acceptedStamp = state, stamp
        current, maximum, name, spawn, kind = state.hp, state.hpm, state.name, state.id, state.kind
        provisional = false
        Notify()
    end
    local function Schedule(retirementOnly)
        if pending or not inWorld or (not TargetFrame:IsVisible() and not retirementOnly) then return end
        pending = true
        controller:SetScript("OnUpdate", Read)
    end
    local function Cancel()
        if pending then controller:SetScript("OnUpdate", nil) end
        pending = false
    end

    for _, eventName in ipairs({
        "CHAT_MSG_ADDON",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEAVING_WORLD",
        "PLAYER_LOGOUT",
    }) do
        controller:RegisterEvent(eventName)
    end
    controller:SetScript("OnEvent", function()
        if event == "CHAT_MSG_ADDON" then
            if arg1 == "AZSTGT" then
                received = received + 1
                Schedule()
            elseif arg1 == "AZSUNITS" then
                unitReceived = unitReceived + 1
                Schedule(true)
            elseif arg1 == "AZSZONE" then
                boundaryPending = true
                RetireRoster()
                runTime = nil
                Retire()
                Notify()
                Schedule(true)
            elseif arg1 == "AZSRUN" then
                boundaryPending = true
                Schedule(true)
            end
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            Cancel()
            RetireRoster()
            runTime = nil
            Retire()
            Notify()
        else
            inWorld = true
            if event == "PLAYER_ENTERING_WORLD" then
                RetireRoster()
                runTime = nil
            end
            Retire()
            provisional = event == "PLAYER_TARGET_CHANGED"
            Notify()
            Schedule()
        end
    end)
    HookScript(TargetFrame, "OnHide", function()
        if unitReceived == unitParsed and not boundaryPending then Cancel() end
        provisional = false
        Clear()
    end)
    HookScript(TargetFrame, "OnShow", Schedule)
    DFRL.locale.Listen(function()
        RetireRoster()
        Notify()
        Schedule()
    end)
    Schedule()
end)
