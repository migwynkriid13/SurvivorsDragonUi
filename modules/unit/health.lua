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
        if not Phase() then
            Retire()
            Notify()
            return
        end
        if not TargetFrame:IsVisible() then return end
        local state, stamp = _G.AZS_TARGET, _G.AZS_TARGET_UPDATED
        if state == accepted and stamp == acceptedStamp then return end
        if state == retired and stamp == retiredStamp and received == retiredReceived then return end
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
    local function Schedule()
        if pending or not inWorld or not TargetFrame:IsVisible() then return end
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
            elseif arg1 == "AZSZONE" then
                Retire()
                Notify()
                Schedule()
            elseif arg1 == "AZSRUN" then
                Schedule()
            end
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            Cancel()
            Retire()
            Notify()
        else
            inWorld = true
            Retire()
            provisional = event == "PLAYER_TARGET_CHANGED"
            Notify()
            Schedule()
        end
    end)
    HookScript(TargetFrame, "OnHide", function()
        Cancel()
        provisional = false
        Clear()
    end)
    HookScript(TargetFrame, "OnShow", Schedule)
    Schedule()
end)
