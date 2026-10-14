-- Only frame locations are saved. Appearance and gameplay state stay in code.
DFRL:NewMod("Layout", 0, function()
    local layout, entries, order = {}, {}, {}
    DFRL.layout = layout
    local ready, inWorld = false, true
    local activeDrag
    local labels = {
        playerFrame = "Player", targetFrame = "Target", bossBars = "Boss health",
        runTimer = "Run timer", actionBar = "Action bar", xpBar = "XP",
        runTally = "Kills / Gold / Cache", microMenu = "Micro menu", buffs = "Buffs",
        minimap = "Minimap", menu = "Main menu", chat = "Chat", castBar = "Cast bar",
        questWatch = "Quest watch", copyWindow = "Copy",
    }

    local function Number(value)
        return type(value) == "number" and value - value == 0
    end
    local function Valid(position)
        return type(position) == "table" and Number(position.x) and Number(position.y)
    end
    local function Saved()
        if type(_G.SurvivorsDragonUiLayout) ~= "table" then
            _G.SurvivorsDragonUiLayout = {}
        end
        return _G.SurvivorsDragonUiLayout
    end
    local function Scale(frame)
        return frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    end
    local function Viewport()
        local width, height, scale = UIParent:GetWidth(), UIParent:GetHeight(), Scale(UIParent)
        if not Number(width) or not Number(height) or not Number(scale)
            or width <= 0 or height <= 0 or scale <= 0 then return end
        return width, height, scale
    end
    local function ReadPosition(frame)
        local width, height, uiScale = Viewport()
        local left, top, scale = frame:GetLeft(), frame:GetTop(), Scale(frame)
        if not width or not Number(left) or not Number(top) or not Number(scale) or scale <= 0 then return end
        return {
            x = (left * scale - (UIParent:GetLeft() or 0) * uiScale) / (width * uiScale),
            y = (top * scale - (UIParent:GetTop() or height) * uiScale) / (height * uiScale),
        }
    end
    local function ApplyPosition(frame, position)
        local width, height, uiScale = Viewport()
        local scale = Scale(frame)
        if not width or not Valid(position) or not Number(scale) or scale <= 0 then return end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
            position.x * width * uiScale / scale, position.y * height * uiScale / scale)
        -- Native StartMoving marks the frame user-placed. Keep a single layout store.
        if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    end
    local function CaptureAnchors(frame)
        local points = {}
        for i = 1, frame:GetNumPoints() do
            local point, relative, relativePoint, x, y = frame:GetPoint(i)
            table.insert(points, {point, relative or UIParent, relativePoint or point, x or 0, y or 0})
        end
        return function()
            frame:ClearAllPoints()
            for _, point in ipairs(points) do
                frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
            end
        end
    end

    function layout.Place(key, frame)
        local entry = entries[key]
        if not ready or not entry or entry.dragging or (frame and frame ~= entry.frame) then return end
        if not entry.defaultPosition then
            -- Late or initially unresolved frames still have their default anchors.
            entry.defaultPosition = ReadPosition(entry.frame)
        end
        if not entry.defaultPosition then return end
        local position = Saved()[key]
        ApplyPosition(entry.frame, Valid(position) and position or entry.defaultPosition)
    end
    function layout.IsPlaced(key)
        return (entries[key] and entries[key].dragging) or Valid(Saved()[key])
    end
    local function FinishDrag(entry, save)
        if not entry or not entry.dragging then return end
        entry.frame:StopMovingOrSizing()
        entry.dragging = false
        activeDrag = nil
        if save then
            local position = ReadPosition(entry.frame)
            if position then Saved()[entry.key] = position end
        end
        if entry.frame.SetUserPlaced then entry.frame:SetUserPlaced(false) end
        layout.Place(entry.key)
    end

    local function MakeHandle(entry)
        local handle = CreateFrame("Button", nil, UIParent)
        handle:SetFrameStrata("TOOLTIP")
        handle:SetFrameLevel(100)
        handle:RegisterForDrag("LeftButton")
        handle:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        handle:SetBackdropBorderColor(0.87, 0.73, 0.41, 0.8)
        local label = handle:CreateFontString(nil, "OVERLAY")
        label:SetFont("DEFAULT", 10, "OUTLINE")
        label:SetPoint("CENTER", handle, "CENTER", 0, 0)
        label:SetTextColor(0.87, 0.73, 0.41)
        label:SetText(labels[entry.key] or entry.key)
        handle:SetScript("OnDragStart", function()
            if not ready or not IsShiftKeyDown() then return end
            FinishDrag(activeDrag, true)
            entry.dragging, activeDrag = true, entry
            entry.frame:StartMoving()
        end)
        handle:SetScript("OnDragStop", function() FinishDrag(entry, true) end)
        handle:SetScript("OnMouseUp", function() FinishDrag(entry, true) end)
        handle:SetScript("OnHide", function() FinishDrag(entry, true) end)
        if entry.options.onMouseWheel or entry.options.wheelFrame then
            handle:EnableMouseWheel(true)
            handle:SetScript("OnMouseWheel", function()
                local direction = arg1 or 0
                if entry.options.onMouseWheel then
                    entry.options.onMouseWheel(direction)
                else
                    local source = entry.options.wheelFrame
                    local callback = source:GetScript("OnMouseWheel")
                    if callback then
                        local previous = _G.this
                        _G.this = source
                        callback()
                        _G.this = previous
                    end
                end
            end)
        end
        handle:EnableMouse(false)
        handle:Hide()
        entry.handle = handle
    end

    function layout.Register(key, frame, defaultAnchor, options)
        if not frame or entries[key] then return end
        local entry = {key = key, frame = frame, options = options or {}}
        entry.defaultAnchor = defaultAnchor or CaptureAnchors(frame)
        entries[key] = entry
        table.insert(order, entry)
        entry.defaultAnchor(frame)
        frame:SetMovable(true)
        if frame.SetUserPlaced then frame:SetUserPlaced(false) end
        MakeHandle(entry)
        if ready then layout.Place(key) end
    end

    local function RestoreDefaults()
        -- Resolve every default before detaching relative anchors or applying saved ones.
        for _, entry in ipairs(order) do
            entry.defaultPosition = nil
            entry.defaultAnchor(entry.frame)
            if entry.frame.SetUserPlaced then entry.frame:SetUserPlaced(false) end
        end
        for _, entry in ipairs(order) do entry.defaultPosition = ReadPosition(entry.frame) end
        for _, entry in ipairs(order) do layout.Place(entry.key) end
    end
    function layout.Reset()
        FinishDrag(activeDrag, false)
        _G.SurvivorsDragonUiLayout = {}
        RestoreDefaults()
    end
    function layout.Ready()
        ready = true
        RestoreDefaults()
    end

    local controller = CreateFrame("Frame", nil, UIParent)
    local lastWidth, lastHeight, lastScale
    controller:SetScript("OnUpdate", function()
        if not ready then return end
        local width, height, scale = Viewport()
        if not width then return end
        if lastWidth and (width ~= lastWidth or height ~= lastHeight or scale ~= lastScale) then
            FinishDrag(activeDrag, true)
            RestoreDefaults()
        end
        lastWidth, lastHeight, lastScale = width, height, scale
        local shift = inWorld and IsShiftKeyDown()
        if activeDrag and not shift then FinishDrag(activeDrag, true) end
        for _, entry in ipairs(order) do
            if not entry.defaultPosition then layout.Place(entry.key) end
            local handle, region = entry.handle, entry.options.region or entry.frame
            local shown = shift and entry.defaultPosition
                and (not entry.options.onlyWhenShown or entry.frame:IsShown())
            if shown then
                local ratio = Scale(region) / scale
                handle:ClearAllPoints()
                handle:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
                handle:SetWidth(math.max(12, region:GetWidth() * ratio))
                handle:SetHeight(math.max(12, region:GetHeight() * ratio))
                handle:EnableMouse(true)
                handle:Show()
            else
                handle:EnableMouse(false)
                handle:Hide()
            end
        end
    end)
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
        else
            inWorld = false
            FinishDrag(activeDrag, true)
            for _, entry in ipairs(order) do entry.handle:Hide() end
        end
    end)

    _G.SLASH_SURVIVORSDRAGONUILAYOUT1 = "/sdui"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList["SURVIVORSDRAGONUILAYOUT"] = function(message)
        local command = string.lower(string.gsub(message or "", "^%s*(.-)%s*$", "%1"))
        if command == "reset" then
            layout.Reset()
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("SurvivorsDragonUi: default layout restored.") end
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Hold SHIFT and left-drag to move frames. /sdui reset restores the default layout.")
        end
    end
end)

-- Modules may depend on each other's initial anchors. Restore saved positions last.
DFRL:NewMod("Layout Ready", 20, function() DFRL.layout.Ready() end)
