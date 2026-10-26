-- Design 01 reuses Blizzard's WidgetStatusBar artwork already bundled for the
-- run timer. Source: Gethe/wow-ui-textures d23deaf8f44a7d280dc974a5c9d5321c013db59b,
-- Widgets/WidgetStatusBar.PNG. Blizzard artwork retains its original ownership;
-- the mirror does not grant a new artwork license. Crops: third_party/WidgetStatusBar-SOURCE.md.
-- https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Widgets/WidgetStatusBar.PNG
DFRL:NewMod("Revive", 4, function()
    if type(AZS_GetRevive) ~= "function" or type(AZS_GetPhase) ~= "function" then return end
    local path = DFRL:GetInfoOrCons("tex") .. "timer\\"
    local INTERVAL, MIN_WIDTH, SMOOTH_TIME, FADE_TIME = 0.1, 356, 0.14, 0.18
    local CROSS_COUNT, CROSS_PERIOD = 6, 0.7
    local native = T.NewHudOwner("revive")
    local phases = { playing = true, choosing = true, paused = true, dead = true, victory = true }

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Native(getter)
        if type(getter) ~= "function" then return end
        local ok, value = pcall(getter)
        if ok then return value end
    end
    local function Name(value)
        if type(value) == "string" then return value end
        if Number(value) then return tostring(value) end
        return ""
    end
    local function Texture(parent, name, layer, width, height, right, bottom)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetTexture(path .. name .. ".blp")
        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetTexCoord(0, right, 0, bottom)
        return texture
    end
    local function NewView(parent, name)
        local view = {}
        local root = CreateFrame("Frame", name, parent)
        view.frame = root
        root:SetWidth(MIN_WIDTH)
        root:SetHeight(56)
        root:SetFrameStrata("HIGH")
        root:EnableMouse(false)
        root:Hide()
        local pill = CreateFrame("Frame", nil, root)
        pill:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 4, 0)
        pill:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -52, 0)
        pill:SetHeight(31)
        pill:EnableMouse(false)
        local backgroundLeft = Texture(pill, "BackgroundLeft", "BACKGROUND", 29, 18, 29 / 32, 18 / 32)
        backgroundLeft:SetPoint("LEFT", pill, "LEFT", 6, 0)
        local backgroundRight = Texture(pill, "BackgroundRight", "BACKGROUND", 29, 18, 29 / 32, 18 / 32)
        backgroundRight:SetPoint("RIGHT", pill, "RIGHT", -6, 0)
        local background = Texture(pill, "BackgroundCenter", "BACKGROUND", 230, 18, 1, 18 / 32)
        background:SetPoint("LEFT", backgroundLeft, "RIGHT", 0, 0)
        background:SetPoint("RIGHT", backgroundRight, "LEFT", 0, 0)
        local bar = CreateFrame("StatusBar", nil, pill)
        bar:SetPoint("LEFT", pill, "LEFT", 8, 0)
        bar:SetPoint("RIGHT", pill, "RIGHT", -8, 0)
        bar:SetHeight(15)
        bar:SetMinMaxValues(0, 1)
        bar:SetStatusBarTexture(path .. "FillWhite.blp")
        bar:SetStatusBarColor(0.35, 0.76, 0.44, 1)
        bar:SetValue(0)
        bar:EnableMouse(false)
        local overlay = CreateFrame("Frame", nil, pill)
        overlay:SetAllPoints(pill)
        overlay:SetFrameLevel(bar:GetFrameLevel() + 1)
        overlay:EnableMouse(false)
        local left = Texture(overlay, "BorderLeft", "OVERLAY", 35, 31, 35 / 64, 31 / 32)
        left:SetPoint("LEFT", pill, "LEFT", 0, 0)
        local right = Texture(overlay, "BorderRight", "OVERLAY", 35, 31, 35 / 64, 31 / 32)
        right:SetPoint("RIGHT", pill, "RIGHT", 0, 0)
        local center = Texture(overlay, "BorderCenter", "OVERLAY", 230, 31, 1, 31 / 32)
        center:SetPoint("LEFT", left, "RIGHT", 0, 0)
        center:SetPoint("RIGHT", right, "LEFT", 0, 0)
        local spark = Texture(overlay, "Spark", "OVERLAY", 8, 32, 1, 1)
        spark:SetBlendMode("ADD")
        spark:Hide()
        local crosses = {}
        for index = 1, CROSS_COUNT do
            local cross = {}
            for part = 1, 2 do
                local texture = overlay:CreateTexture(nil, "ARTWORK")
                texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                texture:SetWidth(part == 1 and 6 or 2)
                texture:SetHeight(part == 1 and 2 or 6)
                texture:SetBlendMode("ADD")
                texture:Hide()
                cross[part] = texture
            end
            crosses[index] = cross
        end
        local function Label(size)
            local label = overlay:CreateFontString(nil, "OVERLAY")
            T.SetFont(label, size, "OUTLINE")
            label:SetJustifyH("CENTER")
            label:SetJustifyV("MIDDLE")
            label:SetTextColor(1, 1, 1)
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            return label
        end
        local caption = Label(14)
        caption:SetPoint("BOTTOM", pill, "TOP", 0, 3)
        caption:SetHeight(22)
        local percent = Label(12)
        percent:SetPoint("LEFT", pill, "RIGHT", 8, 0)
        percent:SetWidth(40)
        percent:SetHeight(22)
        percent:SetTextColor(0.91, 0.81, 0.53)
        local measure = Label(14)
        measure:Hide()
        local value, target, origin, identity, displayedPercent
        local paintedValue, sparkX
        local transition, fade, effectAge = 0, 0, 0
        local dirty = true
        local function Paint()
            if paintedValue ~= value then
                bar:SetValue(value)
                paintedValue = value
            end
            local rounded = value == 1 and 100 or math.min(99, math.floor(value * 100 + 0.5))
            if displayedPercent ~= nil then
                rounded = math.max(displayedPercent - 1, math.min(displayedPercent + 1, rounded))
            end
            displayedPercent = rounded
            T.SetTextIfChanged(percent, tostring(rounded) .. "%")
            local x = 8 + (root:GetWidth() - 72) * value
            if sparkX ~= x then
                spark:ClearAllPoints()
                spark:SetPoint("CENTER", pill, "LEFT", x, 0)
                sparkX = x
            end
            if value > 0 and value < 1 then
                if not spark:IsShown() then spark:Show() end
            else
                if spark:IsShown() then spark:Hide() end
            end
            dirty = false
        end
        function view.Clear()
            if not view.active and not view.waiting and value == nil then return end
            root:Hide()
            root:SetAlpha(1)
            bar:SetValue(0)
            paintedValue = 0
            spark:Hide()
            for _, cross in ipairs(crosses) do
                for _, texture in ipairs(cross) do
                    texture:Hide()
                end
            end
            T.SetTextIfChanged(caption, "")
            T.SetTextIfChanged(percent, "")
            value, target, origin, identity, displayedPercent = nil, nil, nil, nil, nil
            transition, fade, effectAge, dirty = 0, 0, 0, true
            view.active, view.waiting = false, false
        end
        function view.Wait()
            if view.waiting then return end
            view.Clear()
            view.waiting = true
            pill:Hide()
            root:Show()
        end
        function view.Set(text, progress, subject)
            local fresh = identity ~= subject or value == nil
            if T.SetTextIfChanged(caption, text) or dirty then
                measure:SetText(text)
                local width = math.max(MIN_WIDTH, math.ceil(measure:GetStringWidth() or 0) + 72)
                if not T.NearlyEqual(width, root:GetWidth()) then
                    root:SetWidth(width)
                    if view.onResize then view.onResize() end
                    dirty = true
                end
                caption:SetWidth(width - 56)
            end
            if fresh then
                value, target, origin, identity = progress, progress, progress, subject
                displayedPercent, transition, fade, effectAge, dirty = nil, 0, 0, 0, true
                root:SetAlpha(0)
            elseif target ~= progress then
                origin, target, transition = value, progress, 0
            end
            view.active, view.waiting = true, false
            if not pill:IsShown() then pill:Show() end
            if fresh then Paint() end
            if not root:IsShown() then root:Show() end
        end
        function view.Animate(elapsed)
            if not view.active or not root:IsShown() then return end
            if fade < 1 then
                fade = math.min(1, fade + elapsed / FADE_TIME)
                root:SetAlpha(1 - (1 - fade) * (1 - fade))
            end
            if value ~= target then
                transition = math.min(SMOOTH_TIME, transition + elapsed)
                local nextValue = transition == SMOOTH_TIME and target
                    or origin + (target - origin) * transition / SMOOTH_TIME
                local step = math.max(-0.01, math.min(0.01, nextValue - value))
                value = math.max(0, math.min(1, value + step))
                dirty = true
            end
            if dirty then Paint() end
            effectAge = effectAge + elapsed
            local width = root:GetWidth() - 72
            local filledRight = 8 + width * value
            for index, cross in ipairs(crosses) do
                local phase = math.mod(effectAge / CROSS_PERIOD + index / CROSS_COUNT, 1)
                local x = 8 + width * (index - 0.5) / CROSS_COUNT
                local y = math.mod(index, 2) == 0 and 2 or -2
                local alpha = 0.45 + math.sin(phase * math.pi * 2) * 0.2
                for part, texture in ipairs(cross) do
                    local partWidth = part == 1 and 6 or 2
                    local left = x - partWidth / 2
                    local visibleWidth = math.min(partWidth, filledRight - left)
                    if visibleWidth > 0 then
                        if texture.reviveWidth ~= visibleWidth then
                            texture:SetWidth(visibleWidth)
                            texture.reviveWidth = visibleWidth
                        end
                        if texture.reviveLeft ~= left then
                            texture:ClearAllPoints()
                            texture:SetPoint("LEFT", pill, "LEFT", left, y)
                            texture.reviveLeft = left
                        end
                        if texture.reviveAlpha ~= alpha then
                            texture:SetVertexColor(0.58, 1, 0.74, alpha)
                            texture.reviveAlpha = alpha
                        end
                        if not texture:IsShown() then texture:Show() end
                    else
                        if texture:IsShown() then texture:Hide() end
                    end
                end
            end
        end
        return view
    end

    local view = NewView(UIParent, "SurvivorsDragonUiRevive")
    local root = view.frame
    local inWorld, age, received = true, 0, 0
    local blockedPacket, blockedStamp, blockedReceived
    local lastPacket, lastStamp, lastReceived
    local dirty = true
    local function Clear()
        native.Release()
        view.Clear()
        dirty = true
    end
    local function SyncNative()
        if inWorld and (view.active or view.waiting) and root:IsShown() then
            native.Acquire()
        else
            native.Release()
        end
    end
    local function Retire()
        blockedPacket, blockedStamp, blockedReceived = _G.AZS_REVIVE, _G.AZS_REVIVE_UPDATED, received
        lastPacket, lastStamp, lastReceived = nil, nil, nil
        Clear()
    end
    local function Refresh()
        if not inWorld then return end
        -- Phase is read before retained snapshots. Receipt markers do not time a revive.
        if not phases[Native(_G.AZS_GetPhase)] then
            Retire()
            return
        end
        local packet, stamp = _G.AZS_REVIVE, _G.AZS_REVIVE_UPDATED
        if type(packet) ~= "table" or not Number(stamp) then
            Clear()
            return
        end
        if packet == blockedPacket and stamp == blockedStamp and received == blockedReceived then
            Clear()
            return
        end
        if not dirty and packet == lastPacket and stamp == lastStamp and received == lastReceived then
            SyncNative()
            return
        end
        local state = Native(_G.AZS_GetRevive)
        if type(state) ~= "table" then
            Clear()
            return
        end
        local text, progress, subject, waiting
        if state.down == 1 then
            local helper = Name(state.by)
            waiting = helper == ""
            if not waiting then text = string.format(DFRL.locale.Text("%s is reviving you!"), helper) end
            progress, subject = state.share, "incoming:" .. helper
        elseif state.down == 0 and Name(state.reviving) ~= "" then
            local friend = Name(state.reviving)
            text = string.format(DFRL.locale.Text("Reviving %s!"), friend)
            progress, subject = state.rshare, "outgoing:" .. friend
        end
        if (not text and not waiting) or not Number(progress) then
            Clear()
            return
        end
        if waiting then
            view.Wait()
        else
            view.Set(text, math.max(0, math.min(1, progress)), subject)
        end
        lastPacket, lastStamp, lastReceived, dirty = packet, stamp, received, false
        SyncNative()
    end
    local controller = CreateFrame("Frame")
    local function Step(elapsed)
        if age >= INTERVAL then
            age = 0
            Refresh()
        end
        view.Animate(elapsed)
    end
    local function Tick()
        local elapsed = math.max(0, tonumber(arg1) or 0)
        age = age + elapsed
        if age < INTERVAL and (not view.active or not root:IsShown()) then return end
        local ok, message = pcall(Step, elapsed)
        if not ok then
            Clear()
            controller:SetScript("OnUpdate", nil)
            if geterrorhandler then geterrorhandler()(message) end
        end
    end
    DFRL.layout.Register("revive", root, function()
        root:ClearAllPoints()
        local _, height = T.GetLocalSize(UIParent)
        root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -(root:GetWidth() - 56) / 2 - 4, (height or 768) * 0.38 - 3.5)
    end, { labelAbove = true, refreshDefault = true, onReset = Clear })
    view.onResize = function() DFRL.layout.Place("revive", root) end
    root:SetScript("OnShow", SyncNative)
    root:SetScript("OnHide", function() native.Release() end)
    DFRL.locale.Listen(function()
        dirty, age = true, INTERVAL
    end)
    for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "CHAT_MSG_ADDON" }) do
        controller:RegisterEvent(name)
    end
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld, age = true, INTERVAL
            Clear()
            controller:SetScript("OnUpdate", Tick)
        elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Retire()
        elseif arg1 == "AZSZONE" then
            Retire()
            age = INTERVAL
        elseif arg1 == "AZSREVIVE" then
            received, age = received + 1, INTERVAL
        end
    end)
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            inWorld = false
            controller:SetScript("OnUpdate", nil)
            Retire()
            return reloadUI()
        end
    end
    controller:SetScript("OnUpdate", Tick)
end)
