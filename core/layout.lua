-- Only frame geometry is saved. Styling and gameplay state stay in code.
DFRL:NewMod("Layout", 0, function()
    local layout, entries, order = {}, {}, {}
    DFRL.layout = layout
    local ready, inWorld, needsRestore = false, true, false
    local activeDrag
    local editing, draft, confirm = false, nil, nil
    local labels = {
        playerFrame = "Player",
        targetFrame = "Target",
        bossBars = "Boss health",
        runTimer = "Run timer",
        actionBar = "Action bar",
        xpBar = "XP",
        runTally = "Kills / Gold / Cache",
        microMenu = "Micro menu",
        buffs = "Buffs",
        minimap = "Minimap",
        menu = "Main menu",
        chat = "Chat",
        copyWindow = "Copy",
    }

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Valid(position) return type(position) == "table" and Number(position.x) and Number(position.y) end
    local function Clamp(value, minimum, maximum) return math.max(minimum, math.min(maximum, value)) end
    local function Saved()
        if type(_G.SurvivorsDragonUiLayout) ~= "table" then _G.SurvivorsDragonUiLayout = {} end
        return _G.SurvivorsDragonUiLayout
    end
    local function GeometryStore() return editing and draft or Saved() end
    local function CopyGeometry(geometry)
        if not Valid(geometry) then return end
        local copy = { x = geometry.x, y = geometry.y }
        for _, field in ipairs({ "scale", "width", "height" }) do
            if Number(geometry[field]) then copy[field] = geometry[field] end
        end
        return copy
    end
    local function LockFrame(frame)
        -- SetUserPlaced requires movability on 1.12. Clear native caching before
        -- locking the frame, so the explicit editor owns both movement and save.
        frame:SetMovable(true)
        if frame.SetUserPlaced then frame:SetUserPlaced(false) end
        frame:SetMovable(editing)
    end
    local function Scale(frame) return frame.GetEffectiveScale and frame:GetEffectiveScale() or 1 end
    local function LocalScale(frame) return frame.GetScale and frame:GetScale() or 1 end
    local function Viewport()
        local width, height, scale = UIParent:GetWidth(), UIParent:GetHeight(), Scale(UIParent)
        if not Number(width) or not Number(height) or not Number(scale) or width <= 0 or height <= 0 or scale <= 0 then
            return
        end
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
        frame:SetPoint(
            "TOPLEFT",
            UIParent,
            "TOPLEFT",
            position.x * width * uiScale / scale,
            position.y * height * uiScale / scale
        )
        -- Native StartMoving marks the frame user-placed. Keep a single layout store.
        LockFrame(frame)
    end
    local function CaptureAnchors(frame)
        local points = {}
        for i = 1, frame:GetNumPoints() do
            local point, relative, relativePoint, x, y = frame:GetPoint(i)
            table.insert(points, { point, relative or UIParent, relativePoint or point, x or 0, y or 0 })
        end
        return function()
            frame:ClearAllPoints()
            for _, point in ipairs(points) do
                frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
            end
        end
    end

    local function ApplySize(entry, geometry)
        local frame, options = entry.frame, entry.options
        local oldScale, oldWidth, oldHeight = LocalScale(frame), frame:GetWidth(), frame:GetHeight()
        geometry = geometry or {}
        if options.resize == "dimensions" then
            frame:SetScale(entry.defaultScale)
            frame:SetWidth(
                Number(geometry.width)
                        and Clamp(geometry.width, options.minWidth or 120, options.maxWidth or 2400)
                    or entry.defaultWidth
            )
            frame:SetHeight(
                Number(geometry.height)
                        and Clamp(geometry.height, options.minHeight or 80, options.maxHeight or 1600)
                    or entry.defaultHeight
            )
        else
            frame:SetScale(
                Number(geometry.scale)
                        and Clamp(geometry.scale, entry.defaultScale * 0.4, entry.defaultScale * 3)
                    or entry.defaultScale
            )
        end
        if
            options.onResize
            and (
                not entry.sizeApplied
                or oldScale ~= LocalScale(frame)
                or oldWidth ~= frame:GetWidth()
                or oldHeight ~= frame:GetHeight()
            )
        then
            options.onResize(frame, frame:GetWidth(), frame:GetHeight())
        end
        entry.sizeApplied = true
    end
    local function ReadGeometry(entry, position)
        if not position then return end
        local geometry = { x = position.x, y = position.y }
        if entry.options.resize == "dimensions" then
            geometry.width, geometry.height = entry.frame:GetWidth(), entry.frame:GetHeight()
        else
            geometry.scale = LocalScale(entry.frame)
        end
        return geometry
    end

    function layout.Place(key, frame)
        local entry = entries[key]
        if not ready or not entry or entry.dragging or (frame and frame ~= entry.frame) then return end
        if not entry.defaultPosition then
            -- Late or initially unresolved frames still have their default anchors.
            entry.defaultPosition = ReadPosition(entry.frame)
        end
        if not entry.defaultPosition then return end
        local position = GeometryStore()[key]
        ApplySize(entry, Valid(position) and position or nil)
        ApplyPosition(entry.frame, Valid(position) and position or entry.defaultPosition)
    end
    function layout.IsPlaced(key) return (entries[key] and entries[key].dragging) or Valid(GeometryStore()[key]) end
    local function FinishDrag(entry, capture)
        if not entry or not entry.dragging then return end
        entry.frame:StopMovingOrSizing()
        entry.dragging = false
        activeDrag = nil
        if capture then
            local position = entry.resizePosition or ReadPosition(entry.frame)
            local geometry = ReadGeometry(entry, position)
            if geometry and editing then draft[entry.key] = geometry end
        end
        entry.resizing, entry.resizePosition = nil, nil
        LockFrame(entry.frame)
        layout.Place(entry.key)
    end

    local function Cursor()
        local width, height, scale = Viewport()
        local x, y = GetCursorPosition()
        if not width or not Number(x) or not Number(y) then return end
        return x / scale - (UIParent:GetLeft() or 0), y / scale - (UIParent:GetTop() or height)
    end
    local function BeginResize(entry, corner)
        if not ready or not inWorld or not editing then return end
        FinishDrag(activeDrag, true)
        local width, height, uiScale = Viewport()
        local x, y = Cursor()
        local position = ReadPosition(entry.frame)
        if not x or not position or not width then return end
        local scale = Scale(entry.frame) / uiScale
        entry.resizing = {
            corner = corner,
            cursorX = x,
            cursorY = y,
            x = position.x * width,
            y = position.y * height,
            width = entry.frame:GetWidth() * scale,
            height = entry.frame:GetHeight() * scale,
            scale = LocalScale(entry.frame),
        }
        entry.resizePosition = position
        entry.dragging, activeDrag = true, entry
    end
    local function UpdateResize(entry)
        local start = entry.resizing
        local width, height, uiScale = Viewport()
        local cursorX, cursorY = Cursor()
        if not start or not width or not cursorX then return end
        local right = string.find(start.corner, "RIGHT") ~= nil
        local top = string.find(start.corner, "TOP") ~= nil
        local signX, signY = right and 1 or -1, top and 1 or -1
        local dx, dy = cursorX - start.cursorX, cursorY - start.cursorY
        if entry.options.resize == "dimensions" then
            local ratio = Scale(entry.frame) / uiScale
            ApplySize(entry, {
                width = (start.width + signX * dx) / ratio,
                height = (start.height + signY * dy) / ratio,
            })
        else
            -- Project the pointer onto the corner diagonal, preserving artwork
            -- aspect ratios instead of stretching portraits, icons or bars.
            local diagonal = start.width * start.width + start.height * start.height
            if diagonal <= 0 then return end
            local factor = 1 + (signX * dx * start.width + signY * dy * start.height) / diagonal
            ApplySize(entry, { scale = start.scale * factor })
        end
        local ratio = Scale(entry.frame) / uiScale
        local newWidth, newHeight = entry.frame:GetWidth() * ratio, entry.frame:GetHeight() * ratio
        -- Keep the opposite corner fixed throughout the resize.
        local x = right and start.x or start.x + start.width - newWidth
        local y = top and start.y - start.height + newHeight or start.y
        entry.resizePosition = { x = x / width, y = y / height }
        ApplyPosition(entry.frame, entry.resizePosition)
    end

    local function MakeCorner(entry, corner)
        local grip = CreateFrame("Button", nil, entry.handle)
        grip:SetWidth(14)
        grip:SetHeight(14)
        grip:SetFrameLevel(entry.handle:GetFrameLevel() + 2)
        local right = string.find(corner, "RIGHT") ~= nil
        local top = string.find(corner, "TOP") ~= nil
        local signX, signY = right and -1 or 1, top and -1 or 1
        grip:SetPoint("CENTER", entry.handle, corner, -signX * 4, -signY * 4)
        -- Draw three nested corner marks with vanilla's solid texture, so the
        -- resize icons need no modern texture APIs or extra assets.
        for index = 0, 2 do
            local length, offset = 10 - index * 3, index * 3
            local horizontal = grip:CreateTexture(nil, "OVERLAY")
            horizontal:SetTexture("Interface\\Buttons\\WHITE8X8")
            horizontal:SetVertexColor(0.87, 0.73, 0.41, 1)
            horizontal:SetWidth(length)
            horizontal:SetHeight(1)
            horizontal:SetPoint(corner, grip, corner, signX * offset, signY * offset)
            local vertical = grip:CreateTexture(nil, "OVERLAY")
            vertical:SetTexture("Interface\\Buttons\\WHITE8X8")
            vertical:SetVertexColor(0.87, 0.73, 0.41, 1)
            vertical:SetWidth(1)
            vertical:SetHeight(length)
            vertical:SetPoint(corner, grip, corner, signX * offset, signY * offset)
        end
        grip:RegisterForDrag("LeftButton")
        grip:SetScript("OnDragStart", function() BeginResize(entry, corner) end)
        grip:SetScript("OnDragStop", function() FinishDrag(entry, true) end)
        grip:SetScript("OnMouseUp", function() FinishDrag(entry, true) end)
        grip:SetScript("OnHide", function() FinishDrag(entry, true) end)
        grip:EnableMouse(true)
    end

    local function MakeHandle(entry)
        local handle = CreateFrame("Button", nil, UIParent)
        handle:SetFrameStrata("TOOLTIP")
        handle:SetFrameLevel(100)
        handle:RegisterForDrag("LeftButton")
        handle:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        handle:SetBackdropBorderColor(0.87, 0.73, 0.41, 0.8)
        local label = handle:CreateFontString(nil, "OVERLAY")
        label:SetFont("DEFAULT", 10, "OUTLINE")
        label:SetPoint("CENTER", handle, "CENTER", 0, 0)
        label:SetTextColor(0.87, 0.73, 0.41)
        label:SetText(labels[entry.key] or entry.key)
        handle:SetScript("OnDragStart", function()
            if not ready or not inWorld or not editing then return end
            FinishDrag(activeDrag, true)
            entry.dragging, activeDrag = true, entry
            entry.frame:StartMoving()
            LockFrame(entry.frame)
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
        for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
            MakeCorner(entry, corner)
        end
    end

    function layout.Register(key, frame, defaultAnchor, options)
        if not frame or entries[key] then return end
        local entry = { key = key, frame = frame, options = options or {} }
        entry.defaultScale = LocalScale(frame)
        entry.defaultWidth, entry.defaultHeight = frame:GetWidth(), frame:GetHeight()
        entry.defaultAnchor = defaultAnchor or CaptureAnchors(frame)
        entries[key] = entry
        table.insert(order, entry)
        entry.defaultAnchor(frame)
        LockFrame(frame)
        MakeHandle(entry)
        if ready then layout.Place(key) end
    end

    local function RestoreDefaults()
        -- Resolve every default before detaching relative anchors or applying saved ones.
        for _, entry in ipairs(order) do
            entry.defaultPosition = nil
            ApplySize(entry, nil)
            entry.defaultAnchor(entry.frame)
            LockFrame(entry.frame)
        end
        for _, entry in ipairs(order) do
            entry.defaultPosition = ReadPosition(entry.frame)
        end
        for _, entry in ipairs(order) do
            layout.Place(entry.key)
        end
    end
    local function CloseEditing(save, restore)
        if not editing then return end
        FinishDrag(activeDrag, save)
        if save then _G.SurvivorsDragonUiLayout = draft end
        editing, draft = false, nil
        for _, entry in ipairs(order) do
            LockFrame(entry.frame)
            entry.handle:EnableMouse(false)
            entry.handle:Hide()
        end
        if confirm then confirm:Hide() end
        if restore ~= false then
            for _, entry in ipairs(order) do
                layout.Place(entry.key)
            end
        end
    end
    function layout.BeginEdit()
        if not ready or not inWorld then return end
        if not editing then
            draft = {}
            -- Preserve lazy-window records too, without aliasing committed data.
            for key, geometry in pairs(Saved()) do
                draft[key] = CopyGeometry(geometry)
            end
            editing = true
            for _, entry in ipairs(order) do
                LockFrame(entry.frame)
                layout.Place(entry.key)
            end
        end
        if not confirm then
            confirm = T.CreateButton(UIParent, "Confirm", 140, 34)
            confirm:SetFrameStrata("TOOLTIP")
            confirm:SetFrameLevel(200)
            confirm:SetScript("OnClick", function() CloseEditing(true, true) end)
        end
        confirm:ClearAllPoints()
        confirm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        confirm:Show()
    end
    function layout.Reset()
        CloseEditing(false, false)
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
        if needsRestore then
            for _, entry in ipairs(order) do
                layout.Place(entry.key)
            end
            needsRestore = false
        end
        lastWidth, lastHeight, lastScale = width, height, scale
        local enabled = inWorld and editing
        if activeDrag and not enabled then FinishDrag(activeDrag, false) end
        if activeDrag and activeDrag.resizing then UpdateResize(activeDrag) end
        for _, entry in ipairs(order) do
            if not entry.defaultPosition then layout.Place(entry.key) end
            local handle, region = entry.handle, entry.options.region or entry.frame
            local shown = enabled
                and entry.defaultPosition
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
            needsRestore = true
        else
            inWorld = false
            CloseEditing(false, true)
            FinishDrag(activeDrag, false)
            for _, entry in ipairs(order) do
                entry.handle:Hide()
            end
        end
    end)

    _G.SLASH_SURVIVORSDRAGONUILAYOUT1 = "/sdui"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList["SURVIVORSDRAGONUILAYOUT"] = function(message)
        local command = string.lower(string.gsub(message or "", "^%s*(.-)%s*$", "%1"))
        if command == "reset" then
            layout.Reset()
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("SurvivorsDragonUi: default layout restored.") end
        elseif command == "" then
            layout.BeginEdit()
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "Use /sdui to edit the layout, then click Confirm to save. /sdui reset restores default positions and sizes."
            )
        end
    end
end)

-- Modules may depend on each other's initial anchors. Restore saved positions last.
DFRL:NewMod("Layout Ready", 20, function() DFRL.layout.Ready() end)
