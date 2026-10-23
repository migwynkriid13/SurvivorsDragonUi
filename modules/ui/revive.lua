-- Design 01 reuses Blizzard's WidgetStatusBar artwork already bundled for the
-- run timer. Source: Gethe/wow-ui-textures d23deaf8f44a7d280dc974a5c9d5321c013db59b,
-- Widgets/WidgetStatusBar.PNG. Blizzard artwork retains its original ownership;
-- the mirror does not grant a new artwork license. Crops: third_party/WidgetStatusBar-SOURCE.md.
-- https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/Widgets/WidgetStatusBar.PNG
DFRL:NewMod("Revive", 4, function()
    if type(AZS_GetRevive) ~= "function" or type(AZS_GetPhase) ~= "function" then return end
    local path = DFRL:GetInfoOrCons("tex") .. "timer\\"
    local INTERVAL, MIN_WIDTH = 0.1, 356
    local phases = { playing = true, choosing = true, paused = true, dead = true, victory = true }
    local root = CreateFrame("Frame", "SurvivorsDragonUiRevive", UIParent)
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

    local function Texture(parent, name, layer, width, height, right, bottom)
        local texture = parent:CreateTexture(nil, layer)
        texture:SetTexture(path .. name .. ".tga")
        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetTexCoord(0, right, 0, bottom)
        return texture
    end
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
    bar:SetStatusBarTexture(path .. "FillWhite.tga")
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
    local inWorld, age, received = true, 0, 0
    local blockedPacket, blockedStamp, blockedReceived
    local lastPacket, lastStamp, lastReceived, paintedProgress
    local dirty, shown = true, false

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
    local function Clear()
        if shown then
            root:Hide()
            spark:Hide()
            bar:SetValue(0)
            T.SetTextIfChanged(caption, "")
            T.SetTextIfChanged(percent, "")
        end
        shown = false
        paintedProgress, dirty = nil, true
    end
    local function Retire()
        blockedPacket, blockedStamp, blockedReceived = _G.AZS_REVIVE, _G.AZS_REVIVE_UPDATED, received
        lastPacket, lastStamp, lastReceived = nil, nil, nil
        Clear()
    end
    local function Paint(text, progress)
        if T.SetTextIfChanged(caption, text) or dirty then
            measure:SetText(text)
            local width = math.max(MIN_WIDTH, math.ceil(measure:GetStringWidth() or 0) + 72)
            if not T.NearlyEqual(width, root:GetWidth()) then
                root:SetWidth(width)
                DFRL.layout.Place("revive", root)
                paintedProgress = nil
            end
            caption:SetWidth(width - 56)
        end
        if paintedProgress ~= progress then
            bar:SetValue(progress)
            T.SetTextIfChanged(percent, tostring(math.floor(progress * 100 + 0.5)) .. "%")
            spark:ClearAllPoints()
            spark:SetPoint("CENTER", pill, "LEFT", 8 + (root:GetWidth() - 72) * progress, 0)
            if progress > 0 and progress < 1 then
                spark:Show()
            else
                spark:Hide()
            end
            paintedProgress = progress
        end
        if not shown then root:Show() end
        shown = true
        dirty = false
    end
    local function Refresh()
        if not inWorld then return end
        -- Phase is read before any retained revive snapshot. Timestamps are
        -- receipt markers, not an expiry clock or custom event names.
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
        if not dirty and packet == lastPacket and stamp == lastStamp and received == lastReceived then return end
        local state = Native(_G.AZS_GetRevive)
        if type(state) ~= "table" then
            Clear()
            return
        end
        local text, progress
        if state.down == 1 then
            local helper = Name(state.by)
            text = helper ~= "" and string.format(DFRL.locale.Text("%s is bringing you back"), helper)
                or DFRL.locale.Text("Downed — waiting for help")
            progress = state.share
        elseif state.down == 0 and Name(state.reviving) ~= "" then
            text = string.format(DFRL.locale.Text("Bringing %s back"), Name(state.reviving))
            progress = state.rshare
        end
        if not text or not Number(progress) then
            Clear()
            return
        end
        Paint(text, math.max(0, math.min(1, progress)))
        lastPacket, lastStamp, lastReceived = packet, stamp, received
    end
    local controller = CreateFrame("Frame")
    local function Tick()
        age = age + math.max(0, tonumber(arg1) or 0)
        if age < INTERVAL then return end
        age = 0
        Refresh()
    end
    DFRL.layout.Register("revive", root, function()
        root:ClearAllPoints()
        local _, height = T.GetLocalSize(UIParent)
        -- The received native bar is centered at bottom 38% with height 24.
        -- Match its center for comparison; Lua strata cannot suppress Bevy UI.
        root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -(root:GetWidth() - 56) / 2 - 4, (height or 768) * 0.38 - 3.5)
    end, { labelAbove = true, refreshDefault = true, defaultHidden = true, onReset = Clear })
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
        -- Reading on the next OnUpdate lets the native packet parser finish.
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
