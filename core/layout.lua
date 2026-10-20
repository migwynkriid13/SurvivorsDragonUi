-- Layout geometry and visibility; the timer owns its separate font preference.
DFRL:NewMod("Layout", 0, function()
    local layout, entries, order = {}, {}, {}
    DFRL.layout = layout
    local ready, inWorld, needsRestore = false, true, false
    local needsDefaultPosition = false
    local activeDrag
    local editing, draft, confirm = false, nil, nil
    local handlesOnly, setEditorVisible = false, nil
    local coordinates, selected, RefreshCoordinates, SelectEntry
    local showCoordinates
    local confirmAnchor
    local labels = {
        playerFrame = "Player",
        targetFrame = "Target",
        bossBars = "Boss health",
        runTimer = "Run timer",
        levelUp = "Level Up!",
        actionBar = "Action bar",
        jewelryBar = "Equipped jewelry (detached)",
        xpBar = "XP",
        runTally = "Kills / Gold / Cache",
        microMenu = "Micro menu",
        buffs = "Buffs",
        minimap = "Minimap",
        cacheWaypoint = "Cache waypoint",
        guardianWaypoint = "Guardian waypoint",
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
    local function IsHidden(entry)
        local geometry = GeometryStore()[entry.key]
        return type(geometry) == "table" and geometry.hidden == true
    end
    local function ApplyVisibility(entry)
        local shown = not IsHidden(entry) and entry.wantsShown
        if shown and not entry.frame:IsShown() then
            entry.nativeShow(entry.frame)
        elseif not shown and entry.frame:IsShown() then
            entry.nativeHide(entry.frame)
        end
    end
    local function CopyGeometry(geometry)
        if not Valid(geometry) then return end
        local copy = { x = geometry.x, y = geometry.y }
        if geometry.hidden == true then copy.hidden = true end
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
        -- These are the existing saved-position denominators. Rendered screen
        -- extents are read separately for editor math; changing this contract
        -- would reinterpret confirmed layouts saved by the current client.
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
        local x, y = position.x * width * uiScale / scale, position.y * height * uiScale / scale
        local point, relative, relativePoint, oldX, oldY
        if frame:GetNumPoints() == 1 then
            point, relative, relativePoint, oldX, oldY = frame:GetPoint(1)
        end
        if
            point ~= "TOPLEFT"
            or relative ~= UIParent
            or relativePoint ~= "TOPLEFT"
            or not T.NearlyEqual(oldX, x)
            or not T.NearlyEqual(oldY, y)
        then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
        end
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
            local width = Number(geometry.width)
                    and Clamp(geometry.width, options.minWidth or 120, options.maxWidth or 2400)
                or entry.defaultWidth
            local height = Number(geometry.height)
                    and Clamp(geometry.height, options.minHeight or 80, options.maxHeight or 1600)
                or entry.defaultHeight
            if not T.NearlyEqual(oldScale, entry.defaultScale) then frame:SetScale(entry.defaultScale) end
            if not T.NearlyEqual(oldWidth, width) then frame:SetWidth(width) end
            if not T.NearlyEqual(oldHeight, height) then frame:SetHeight(height) end
        else
            local scale = Number(geometry.scale)
                    and Clamp(geometry.scale, entry.defaultScale * 0.4, entry.defaultScale * 3)
                or entry.defaultScale
            if not T.NearlyEqual(oldScale, scale) then frame:SetScale(scale) end
        end
        if
            options.onResize
            and (
                not entry.sizeApplied
                or not T.NearlyEqual(oldScale, LocalScale(frame))
                or not T.NearlyEqual(oldWidth, frame:GetWidth())
                or not T.NearlyEqual(oldHeight, frame:GetHeight())
            )
        then
            options.onResize(frame, frame:GetWidth(), frame:GetHeight())
        end
        entry.sizeApplied = true
    end
    local function ReadGeometry(entry, position)
        if not position then return end
        local geometry = { x = position.x, y = position.y }
        if IsHidden(entry) then geometry.hidden = true end
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
        if not entry.defaultPosition then
            needsDefaultPosition = true
            return
        end
        local position = GeometryStore()[key]
        ApplySize(entry, Valid(position) and position or nil)
        ApplyPosition(entry.frame, Valid(position) and position or entry.defaultPosition)
        ApplyVisibility(entry)
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
        if capture and editing and coordinates and entry == selected then RefreshCoordinates() end
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
        SelectEntry(entry, true)
        local width, height, uiScale = Viewport()
        local x, y = Cursor()
        local position = ReadPosition(entry.frame)
        if not x or not position or not width then return end
        local scale = Scale(entry.frame) / uiScale
        local frameWidth, frameHeight = T.GetLocalSize(entry.frame)
        entry.resizing = {
            corner = corner,
            cursorX = x,
            cursorY = y,
            x = position.x * width,
            y = position.y * height,
            width = frameWidth * scale,
            height = frameHeight * scale,
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
        local frameWidth, frameHeight = T.GetLocalSize(entry.frame)
        local newWidth, newHeight = frameWidth * ratio, frameHeight * ratio
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
        handle:Hide()
        handle:SetFrameStrata("TOOLTIP")
        handle:SetFrameLevel(100)
        handle:RegisterForDrag("LeftButton")
        handle:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        handle:SetBackdropBorderColor(0.87, 0.73, 0.41, 0.8)
        local label = handle:CreateFontString(nil, "OVERLAY")
        DFRL.locale.Bind(label)
        T.SetFont(label, 10, "OUTLINE")
        label:SetPoint("CENTER", handle, "CENTER", 0, 0)
        label:SetTextColor(0.87, 0.73, 0.41)
        label:SetText(labels[entry.key] or entry.key)
        handle:SetScript("OnDragStart", function()
            if not ready or not inWorld or not editing then return end
            FinishDrag(activeDrag, true)
            SelectEntry(entry, true)
            entry.dragging, activeDrag = true, entry
            entry.frame:StartMoving()
            LockFrame(entry.frame)
        end)
        handle:SetScript("OnClick", function() SelectEntry(entry, true) end)
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
        entry.handleShown = false
        for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
            MakeCorner(entry, corner)
        end
    end

    local function ShowHandle(entry, shown)
        if entry.handleShown == shown then return end
        entry.handleShown = shown
        entry.handle:EnableMouse(shown)
        if shown then
            entry.handle:Show()
        else
            entry.handle:Hide()
        end
    end

    function layout.Register(key, frame, defaultAnchor, options)
        if not frame or entries[key] then return end
        local entry = { key = key, frame = frame, options = options or {} }
        entry.defaultScale = LocalScale(frame)
        entry.defaultWidth, entry.defaultHeight = frame:GetWidth(), frame:GetHeight()
        entry.defaultAnchor = defaultAnchor or CaptureAnchors(frame)
        needsDefaultPosition = true
        -- Preserve the module's requested visibility, including conditional frames.
        entry.nativeShow, entry.nativeHide = frame.Show, frame.Hide
        entry.wantsShown = frame:IsShown() and true or false
        -- Complete the handle before publishing the entry to the update loop or
        -- replacing native visibility methods. A setup error must not leave a
        -- half-registered entry whose handle is nil on every following frame.
        entry.defaultAnchor(frame)
        LockFrame(frame)
        MakeHandle(entry)
        entries[key] = entry
        table.insert(order, entry)
        frame.Show = function(self)
            entry.wantsShown = true
            if not IsHidden(entry) then entry.nativeShow(self) end
        end
        frame.Hide = function(self)
            entry.wantsShown = false
            entry.nativeHide(self)
        end
        if ready then layout.Place(key) end
        if editing and entry.options.onEdit then entry.options.onEdit(true) end
    end

    -- Coordinates use UIParent units and the frame's center, independent of its scale.
    local function CenterPosition(entry)
        local width, height, uiScale = Viewport()
        local position = ReadPosition(entry.frame)
        if not width or not position then return end
        local screenWidth, screenHeight = T.GetLocalSize(UIParent)
        local frameWidth, frameHeight = T.GetLocalSize(entry.frame)
        local ratio = Scale(entry.frame) / uiScale
        return position.x * width + frameWidth * ratio / 2 - screenWidth / 2,
            position.y * height - frameHeight * ratio / 2 + screenHeight / 2
    end
    local function SetCoordinateText(field, text)
        -- Remember programmatic text before SetText, including delayed change events.
        coordinates[field].layoutText = text
        coordinates[field]:SetText(text)
    end
    RefreshCoordinates = function()
        if not coordinates or not selected then return end
        coordinates.refreshing = true
        local x, y = CenterPosition(selected)
        coordinates.label:SetText(labels[selected.key] or selected.key)
        SetCoordinateText("x", x and string.format("%.2f", x) or "")
        SetCoordinateText("y", y and string.format("%.2f", y) or "")
        if not x then
            coordinates.unavailable = true
            coordinates.status:SetText("Frame position is not available yet.")
        elseif coordinates.unavailable then
            coordinates.unavailable = false
            coordinates.status:SetText("")
        end
        local dimensions = selected.options.resize == "dimensions"
        coordinates.sizeLabel:SetText(dimensions and "Width / Height (frame units)" or "Scale (%) - 40 to 300")
        SetCoordinateText(
            "width",
            string.format(
                "%.2f",
                dimensions and selected.frame:GetWidth() or LocalScale(selected.frame) / selected.defaultScale * 100
            )
        )
        SetCoordinateText("height", string.format("%.2f", selected.frame:GetHeight()))
        if dimensions then
            coordinates.height:Show()
        else
            coordinates.height:Hide()
        end
        coordinates.visibility:SetChecked(IsHidden(selected))
        coordinates.dirty = false
        coordinates.refreshing = false
    end
    local function ClearCoordinateFocus()
        for _, field in ipairs({ "x", "y", "width", "height" }) do
            coordinates[field]:ClearFocus()
        end
        coordinates.focused = nil
    end
    SelectEntry = function(entry, activate)
        if not editing or not entry then return end
        selected = entry
        if coordinates then
            coordinates.dirty = false
            ClearCoordinateFocus()
            coordinates.status:SetText("")
            RefreshCoordinates()
        end
        if activate and showCoordinates and not handlesOnly then showCoordinates() end
    end
    local function ApplyCoordinates()
        if not editing or not selected then return end
        FinishDrag(activeDrag, true)
        local x = tonumber((string.gsub(coordinates.x:GetText(), ",", ".")))
        local y = tonumber((string.gsub(coordinates.y:GetText(), ",", ".")))
        local size = tonumber((string.gsub(coordinates.width:GetText(), ",", ".")))
        local sizeHeight = tonumber((string.gsub(coordinates.height:GetText(), ",", ".")))
        local dimensions = selected.options.resize == "dimensions"
        if not Number(x) or not Number(y) then
            coordinates.status:SetText("Enter valid X and Y numbers.")
            return
        end
        if not Number(size) or size <= 0 or (dimensions and (not Number(sizeHeight) or sizeHeight <= 0)) then
            coordinates.status:SetText("Enter positive size values.")
            return
        end
        local width, height, uiScale = Viewport()
        if not width or not ReadPosition(selected.frame) then
            coordinates.status:SetText("Frame position is not available yet.")
            return
        end
        local frame = selected.frame
        -- Apply size first so the entered center remains fixed when resizing.
        if dimensions then
            ApplySize(selected, { width = size, height = sizeHeight })
        else
            ApplySize(selected, { scale = selected.defaultScale * size / 100 })
        end
        local screenWidth, screenHeight = T.GetLocalSize(UIParent)
        local frameWidth, frameHeight = T.GetLocalSize(frame)
        local ratio = Scale(frame) / uiScale
        local position = {
            x = (x + screenWidth / 2 - frameWidth * ratio / 2) / width,
            y = (y - screenHeight / 2 + frameHeight * ratio / 2) / height,
        }
        draft[selected.key] = ReadGeometry(selected, position)
        layout.Place(selected.key)
        ClearCoordinateFocus()
        coordinates.status:SetText("Applied. Confirm to save.")
        coordinates.dirty = false
        RefreshCoordinates()
        return true
    end
    -- The community's numeric editor shares the existing dialog and draft store.
    function layout.CreateControls(parent, width, activate)
        coordinates = CreateFrame("Frame", nil, parent)
        coordinates:SetAllPoints(parent)
        showCoordinates = activate
        local function Text(text, y, size)
            local label = coordinates:CreateFontString(nil, "OVERLAY")
            DFRL.locale.Bind(label)
            T.SetFont(label, size or 11, "")
            label:SetPoint("TOP", coordinates, "TOP", 0, y)
            label:SetText(text)
            label:SetTextColor(0.88, 0.87, 0.83)
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            return label
        end
        coordinates.label = Text("", -8, 12)
        coordinates.label:SetWidth(width - 80)
        coordinates.label:SetHeight(16)
        Text("Center relative to screen center (UI units)", -36, 10)
        coordinates.sizeLabel = Text("", -106)
        local gap, inputWidth = 12, (width - 12) / 2
        for _, field in ipairs({ "x", "y", "width", "height" }) do
            local positionField = field == "x" or field == "y"
            local left = field == "x" or field == "width"
            local x = left and 0 or inputWidth + gap
            if positionField then
                local label = Text(left and "X: right +" or "Y: up +", -56)
                label:ClearAllPoints()
                label:SetPoint("TOPLEFT", coordinates, "TOPLEFT", x + 6, -56)
            end
            local box = T.CreateEditorInput(coordinates, inputWidth, 26)
            box:SetPoint("TOPLEFT", coordinates, "TOPLEFT", x, positionField and -72 or -122)
            box:SetScript("OnEditFocusGained", function() coordinates.focused = this end)
            box:SetScript("OnEditFocusLost", function()
                if coordinates.focused == this then coordinates.focused = nil end
            end)
            box:SetScript("OnTextChanged", function()
                if not coordinates.refreshing and this:GetText() ~= this.layoutText then coordinates.dirty = true end
            end)
            box:SetScript("OnEnterPressed", ApplyCoordinates)
            box:SetScript("OnEscapePressed", function() SelectEntry(selected) end)
            coordinates[field] = box
        end
        local fields = { "x", "y", "width", "height" }
        for index, field in ipairs(fields) do
            local nextIndex = index + 1
            coordinates[field]:SetScript("OnTabPressed", function()
                local nextField = fields[nextIndex] or "x"
                if nextField == "height" and selected.options.resize ~= "dimensions" then nextField = "x" end
                this:ClearFocus()
                coordinates[nextField]:SetFocus()
            end)
        end
        for _, step in ipairs({ -1, 1 }) do
            local direction = step
            local button = T.CreateEditorButton(coordinates, direction == -1 and "<" or ">", 30, 28)
            button:SetPoint(
                direction == -1 and "TOPLEFT" or "TOPRIGHT",
                coordinates,
                direction == -1 and "TOPLEFT" or "TOPRIGHT",
                0,
                0
            )
            button:SetScript("OnClick", function()
                FinishDrag(activeDrag, true)
                local index = 1
                for i, entry in ipairs(order) do
                    if entry == selected then index = i end
                end
                index = index + direction
                if index < 1 then index = table.getn(order) end
                if index > table.getn(order) then index = 1 end
                SelectEntry(order[index])
            end)
        end
        local visibility = T.CreateEditorToggle(
            coordinates,
            "Hide frame",
            "Keep this group hidden during gameplay.",
            width,
            function(hidden)
                if not editing or not selected then return end
                FinishDrag(activeDrag, true)
                local geometry = ReadGeometry(selected, ReadPosition(selected.frame))
                if not geometry then
                    coordinates.visibility:SetChecked(IsHidden(selected))
                    coordinates.status:SetText("Frame position is not available yet.")
                    return
                end
                geometry.hidden = hidden or nil
                draft[selected.key] = geometry
                ApplyVisibility(selected)
                coordinates.status:SetText("Preview. Confirm to save.")
            end
        )
        visibility:SetPoint("TOPLEFT", coordinates, "TOPLEFT", 0, -156)
        coordinates.visibility = visibility
        local apply = T.CreateEditorButton(coordinates, "Apply position / size", width, 28)
        apply:SetPoint("TOPLEFT", coordinates, "TOPLEFT", 0, -204)
        apply:SetScript("OnClick", ApplyCoordinates)
        coordinates.status = Text("", -242, 10)
        coordinates.status:SetWidth(width)
        coordinates.status:SetHeight(18)
        local refreshElapsed = 0
        coordinates:SetScript("OnUpdate", function()
            refreshElapsed = refreshElapsed + (arg1 or 0)
            if refreshElapsed < 0.1 then return end
            refreshElapsed = 0
            if not coordinates.dirty and not coordinates.focused then RefreshCoordinates() end
        end)
        coordinates:SetScript("OnShow", function()
            if not coordinates.dirty and not coordinates.focused then RefreshCoordinates() end
        end)
        coordinates:SetScript("OnHide", ClearCoordinateFocus)
        SelectEntry(selected or entries.playerFrame or order[1])
    end

    local function RestoreDefaults()
        needsDefaultPosition = false
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
        -- Capture pointer geometry before deciding whether numeric input needs applying.
        FinishDrag(activeDrag, save)
        if save and coordinates and coordinates.dirty and not ApplyCoordinates() then
            if showCoordinates then showCoordinates() end
            return
        end
        if save then _G.SurvivorsDragonUiLayout = draft end
        editing, draft = false, nil
        for _, entry in ipairs(order) do
            if entry.options.onEdit then entry.options.onEdit(false, save) end
            LockFrame(entry.frame)
            ShowHandle(entry, false)
        end
        if confirm then confirm:Hide() end
        handlesOnly = false
        if restore ~= false then
            for _, entry in ipairs(order) do
                layout.Place(entry.key)
            end
        end
    end
    function layout.CancelEdit() CloseEditing(false, true) end
    local function PlaceConfirm()
        if not confirm then return end
        local anchor = not handlesOnly and confirmAnchor or UIParent
        confirm:SetParent(anchor)
        confirm:SetFrameStrata("TOOLTIP")
        confirm:SetFrameLevel(200)
        confirm:ClearAllPoints()
        confirm:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    end
    function layout.SetConfirmAnchor(anchor)
        confirmAnchor = anchor
        PlaceConfirm()
    end
    function layout.SetEditorVisibilityHandler(callback) setEditorVisible = callback end
    function layout.BeginEdit(onlyHandles)
        if not ready or not inWorld then return end
        local starting = not editing
        handlesOnly = onlyHandles == true
        if editing and handlesOnly and coordinates then
            -- Keep staged geometry, but leave no unapplied text behind a hidden dialog.
            FinishDrag(activeDrag, true)
            ClearCoordinateFocus()
            RefreshCoordinates()
        end
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
                if entry.options.onEdit then entry.options.onEdit(true) end
            end
        end
        if setEditorVisible then setEditorVisible(not handlesOnly) end
        if not confirm then
            confirm = T.CreateEditorButton(confirmAnchor or UIParent, "Confirm", 140, 30, true)
            confirm:SetScript("OnClick", function() CloseEditing(true, true) end)
        end
        PlaceConfirm()
        confirm:Show()
        if starting and coordinates then SelectEntry(selected or entries.playerFrame or order[1]) end
    end
    function layout.Reset()
        CloseEditing(false, false)
        FinishDrag(activeDrag, false)
        _G.SurvivorsDragonUiLayout = {}
        for _, entry in ipairs(order) do
            if entry.options.onReset then entry.options.onReset() end
        end
        RestoreDefaults()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(DFRL.locale.Text("SurvivorsDragonUi: default layout restored."))
        end
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
        if
            not lastWidth
            or not T.NearlyEqual(width, lastWidth)
            or not T.NearlyEqual(height, lastHeight)
            or not T.NearlyEqual(scale, lastScale)
        then
            -- The client applies its saved UI scale after ADDON_LOADED. Rebase
            -- defaults on the first world update too, before using positions
            -- captured during module initialization at the earlier scale.
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
        if needsDefaultPosition then
            needsDefaultPosition = false
            for _, entry in ipairs(order) do
                if not entry.defaultPosition then layout.Place(entry.key) end
            end
        end
        -- Settled groups need no handle reads or native visibility writes during
        -- gameplay. Viewport changes and unresolved defaults still run above.
        if not enabled then return end
        for _, entry in ipairs(order) do
            local handle, region = entry.handle, entry.options.region or entry.frame
            local shown = entry.defaultPosition and (not entry.options.onlyWhenShown or entry.wantsShown)
            if shown then
                local ratio = Scale(region) / scale
                local regionWidth, regionHeight = T.GetLocalSize(region)
                local handleWidth = math.max(12, regionWidth * ratio)
                local handleHeight = math.max(12, regionHeight * ratio)
                if entry.handleRegion ~= region then
                    handle:ClearAllPoints()
                    handle:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
                    entry.handleRegion = region
                end
                if entry.handleWidth ~= handleWidth then
                    handle:SetWidth(handleWidth)
                    entry.handleWidth = handleWidth
                end
                if entry.handleHeight ~= handleHeight then
                    handle:SetHeight(handleHeight)
                    entry.handleHeight = handleHeight
                end
            end
            ShowHandle(entry, shown and true or false)
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
                ShowHandle(entry, false)
            end
        end
    end)

    _G.SLASH_SURVIVORSDRAGONUILAYOUT1 = "/sdui"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList["SURVIVORSDRAGONUILAYOUT"] = function(message)
        local command = string.lower(string.gsub(message or "", "^%s*(.-)%s*$", "%1"))
        if command == "reset" then
            layout.Reset()
        elseif command == "lock" then
            layout.BeginEdit(true)
        elseif command == "" then
            layout.BeginEdit()
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                DFRL.locale.Text(
                    "Use /sdui to edit the layout, then click Confirm to save. /sdui reset restores default positions, sizes and visibility."
                )
            )
        end
    end
end)

-- Modules may depend on each other's initial anchors. Restore saved positions last.
DFRL:NewMod("Layout Ready", 20, function() DFRL.layout.Ready() end)
