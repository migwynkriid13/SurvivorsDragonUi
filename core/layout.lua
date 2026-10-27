-- Layout geometry and visibility; the timer owns its separate font preference.
DFRL:NewMod("Layout", 0, function()
    local layout, entries, order, visibilityListeners = {}, {}, {}, {}
    DFRL.layout = layout
    local ready, inWorld, needsRestore = false, true, false
    local needsDefaultPosition = false
    local activeDrag
    local editing, draft, confirm = false, nil, nil
    local handlesOnly, setEditorVisible = false, nil
    local coordinates, selected, RefreshCoordinates, SelectEntry
    local showCoordinates
    local confirmAnchor
    local grid, gridWidth, gridHeight, gridScale, gridFine
    local GRID_SPACING = 32
    local EDITOR_INTERVAL = 0.1
    local SNAP_SPACING, SNAP_CAPTURE, SNAP_RELEASE = GRID_SPACING / 4, 8, 12
    local SNAP_POINTS = { 1, 0, 2 }
    local editorAge, editorDirty = 0, true
    local function RefreshEditorSoon()
        editorDirty = true
        if activeDrag and activeDrag.moving then activeDrag.moving.targetsDirty = true end
    end
    local labels = {
        playerFrame = "Player",
        targetFrame = "Target",
        partyFrames = "Party frames",
        tooltip = "Tooltip",
        bossBars = "Boss health",
        runTimer = "Run timer",
        revive = "Revive",
        banners = "Banners",
        levelUp = "LEVEL UP",
        actionBar = "Action bar",
        jewelryBar = "Equipped jewelry (detached)",
        xpBar = "XP (detached)",
        runTally = "Kills / Gold / Cache (detached)",
        buffs = "Buffs",
        minimap = "Minimap",
        cacheWaypoint = "Cache waypoint",
        guardianWaypoint = "Guardian waypoint",
        guardianTracker = "Guardian tracker",
        damageMeter = "DPS meter",
        petFrames = "Pet frames",
        lootNotifications = "Loot notifications",
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
        if type(geometry) == "table" and type(geometry.hidden) == "boolean" then return geometry.hidden end
        return entry.options.defaultHidden == true
    end
    function layout.IsEditing() return editing end
    function layout.IsHidden(key)
        if entries[key] then return IsHidden(entries[key]) end
        local geometry = GeometryStore()[key]
        return type(geometry) == "table" and geometry.hidden == true
    end
    function layout.ListenVisibility(key, callback)
        local listeners = visibilityListeners[key]
        if not listeners then
            listeners = {}
            visibilityListeners[key] = listeners
        end
        table.insert(listeners, callback)
        if entries[key] then callback(not IsHidden(entries[key])) end
    end
    local function SetHidden(entry, geometry, hidden)
        -- Default-hidden groups need an explicit false to remember an opt-in.
        geometry.hidden = nil
        if hidden or entry.options.defaultHidden == true then geometry.hidden = hidden end
    end
    local function ApplyVisibility(entry)
        local permitted = not IsHidden(entry)
        local shown = permitted and entry.wantsShown
        if shown and not entry.frame:IsShown() then
            entry.nativeShow(entry.frame)
        elseif not shown and entry.frame:IsShown() then
            entry.nativeHide(entry.frame)
        end
        if entry.visibilityPolicy ~= permitted then
            entry.visibilityPolicy = permitted
            local listeners = visibilityListeners[entry.key]
            if listeners then
                for _, callback in ipairs(listeners) do
                    callback(permitted)
                end
            end
        end
    end
    local function CopyGeometry(geometry)
        if not Valid(geometry) then return end
        local copy = { x = geometry.x, y = geometry.y }
        if type(geometry.hidden) == "boolean" then copy.hidden = geometry.hidden end
        for _, field in ipairs({ "scale", "width", "height" }) do
            if Number(geometry[field]) then copy[field] = geometry[field] end
        end
        return copy
    end
    function layout.Copy(source)
        local copy = {}
        for key, geometry in pairs(type(source) == "table" and source or {}) do
            if type(key) == "string" then copy[key] = CopyGeometry(geometry) end
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
    local function HideSnapGuides()
        if not grid or not grid.guides then return end
        for _, guide in ipairs(grid.guides) do
            if guide.shown then guide:Hide() end
            guide.shown = false
        end
    end
    local function ShowSnapGuides(x, y)
        if not grid then return end
        grid.guides = grid.guides or {}
        local width, height = T.GetLocalSize(UIParent)
        local pixel = 1 / Scale(UIParent)
        for index = 1, 2 do
            local guide = grid.guides[index]
            if not guide then
                guide = grid:CreateTexture(nil, "OVERLAY")
                guide:SetTexture("Interface\\Buttons\\WHITE8X8")
                guide:SetVertexColor(1, 0.83, 0.38, 0.95)
                grid.guides[index] = guide
            end
            local vertical = index == 1
            local value = vertical and x or y
            if
                guide.value ~= value
                or guide.pixel ~= pixel
                or guide.viewWidth ~= width
                or guide.viewHeight ~= height
            then
                guide:ClearAllPoints()
                guide:SetPoint(
                    "CENTER",
                    grid,
                    "CENTER",
                    vertical and x - width / 2 or 0,
                    vertical and 0 or y + height / 2
                )
                guide:SetWidth(vertical and pixel or width)
                guide:SetHeight(vertical and height or pixel)
                guide.value, guide.pixel, guide.viewWidth, guide.viewHeight = value, pixel, width, height
            end
            if not guide.shown then guide:Show() end
            guide.shown = true
        end
    end
    local function UpdateGrid()
        if DFRL.display and not DFRL.display.Get("layoutShowGrid") then
            if grid and grid:IsShown() then grid:Hide() end
            return
        end
        local width, height = T.GetLocalSize(UIParent)
        local scale = Scale(UIParent)
        local fine = activeDrag and activeDrag.moving and IsShiftKeyDown() and true or false
        if not Number(width) or not Number(height) or not Number(scale) or width <= 0 or height <= 0 or scale <= 0 then
            if grid then grid:Hide() end
            return
        end
        if not grid then
            grid = CreateFrame("Frame", nil, UIParent)
            grid:Hide()
            grid:SetAllPoints(UIParent)
            grid:SetFrameStrata("BACKGROUND")
            grid:SetFrameLevel(0)
            grid:EnableMouse(false)
            grid.lines = {}
        end
        if
            not T.NearlyEqual(width, gridWidth)
            or not T.NearlyEqual(height, gridHeight)
            or not T.NearlyEqual(scale, gridScale)
            or gridFine ~= fine
        then
            local used, pixel = 0, 1 / scale
            local spacing = fine and SNAP_SPACING or GRID_SPACING
            for axis = 1, 2 do
                local vertical = axis == 1
                local extent = vertical and width or height
                local steps = math.floor(extent / (2 * spacing))
                for step = -steps, steps do
                    used = used + 1
                    local line = grid.lines[used]
                    if not line then
                        line = grid:CreateTexture(nil, "ARTWORK")
                        line:SetTexture("Interface\\Buttons\\WHITE8X8")
                        table.insert(grid.lines, line)
                    end
                    local center = step == 0
                    local thickness = center and 2 * pixel or pixel
                    line:ClearAllPoints()
                    line:SetPoint(
                        "CENTER",
                        grid,
                        "CENTER",
                        vertical and step * spacing or 0,
                        vertical and 0 or step * spacing
                    )
                    line:SetWidth(vertical and thickness or width)
                    line:SetHeight(vertical and height or thickness)
                    if center then
                        line:SetVertexColor(0.87, 0.73, 0.41, 0.8)
                    else
                        local offset = step * spacing
                        local alpha = math.mod(offset, GRID_SPACING * 4) == 0 and 0.28
                            or math.mod(offset, GRID_SPACING) == 0 and 0.13
                            or 0.05
                        line:SetVertexColor(0.75, 0.8, 0.85, alpha)
                    end
                    line:Show()
                end
            end
            for index = used + 1, table.getn(grid.lines) do
                grid.lines[index]:Hide()
            end
            gridWidth, gridHeight, gridScale, gridFine = width, height, scale, fine
        end
        if not grid:IsShown() then grid:Show() end
    end
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
    local function CenterOffsets(frame, uiScale)
        local screenWidth, screenHeight = T.GetLocalSize(UIParent)
        local frameWidth, frameHeight = T.GetLocalSize(frame)
        local ratio = Scale(frame) / uiScale
        return (frameWidth * ratio - screenWidth) / 2, (screenHeight - frameHeight * ratio) / 2
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
        -- Keep all editor movement in the shared layout store.
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
            if options.edgeWidth then
                local fallback = entry.resizing and entry.resizing.frameWidth
                    or (type(options.defaultWidth) == "function" and options.defaultWidth())
                    or entry.defaultWidth
                local requested = geometry.width
                local width = Number(requested) and Clamp(requested, options.minWidth or 120, options.maxWidth or 1200)
                    or fallback
                if not T.NearlyEqual(oldWidth, width) then frame:SetWidth(width) end
            end
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
        SetHidden(entry, geometry, IsHidden(entry))
        if entry.options.resize == "dimensions" then
            geometry.width, geometry.height = entry.frame:GetWidth(), entry.frame:GetHeight()
        else
            geometry.scale = LocalScale(entry.frame)
            if entry.options.edgeWidth then
                local stored = GeometryStore()[entry.key]
                -- Caption-fitted views stay automatic until a side width is chosen.
                if
                    not entry.options.defaultWidth
                    or (entry.resizing and entry.resizing.axis == "width")
                    or (Valid(stored) and Number(stored.width))
                then
                    geometry.width = entry.frame:GetWidth()
                end
            end
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
        -- Variable-width groups may keep a default edge aligned as their text grows.
        if entry.options.refreshDefault and not Valid(position) then
            entry.defaultAnchor(entry.frame)
            entry.defaultPosition = ReadPosition(entry.frame)
        end
        ApplyPosition(entry.frame, Valid(position) and position or entry.defaultPosition)
        ApplyVisibility(entry)
    end
    function layout.IsPlaced(key) return (entries[key] and entries[key].dragging) or Valid(GeometryStore()[key]) end
    local function CanShowHandle(entry)
        return entry.defaultPosition and (not entry.options.onlyWhenShown or entry.wantsShown)
    end
    function layout.Width(key, fallback)
        local entry = entries[key]
        if entry and entry.resizing then return entry.frame:GetWidth() end
        local geometry = GeometryStore()[key]
        if entry and Valid(geometry) and Number(geometry.width) then
            return Clamp(geometry.width, entry.options.minWidth or 120, entry.options.maxWidth or 1200)
        end
        return fallback
    end
    local UpdateMove, UpdateResize
    local function FinishDrag(entry, capture)
        if not entry or not entry.dragging then return end
        if capture and entry.moving then UpdateMove(entry, true) end
        if capture and entry.resizing then UpdateResize(entry, true) end
        entry.frame:StopMovingOrSizing()
        entry.dragging = false
        activeDrag = nil
        if capture then
            local position = entry.pointerPosition or ReadPosition(entry.frame)
            local geometry = ReadGeometry(entry, position)
            if geometry and editing then draft[entry.key] = geometry end
        end
        entry.moving, entry.resizing, entry.pointerPosition = nil, nil, nil
        HideSnapGuides()
        LockFrame(entry.frame)
        layout.Place(entry.key)
        RefreshEditorSoon()
        if capture and editing and coordinates and entry == selected then RefreshCoordinates() end
    end

    local function Cursor()
        local width, height, scale = Viewport()
        local x, y = GetCursorPosition()
        if not width or not Number(x) or not Number(y) then return end
        return x / scale - (UIParent:GetLeft() or 0), y / scale - (UIParent:GetTop() or height)
    end
    local function SnapToGrid(value)
        local cells = value / SNAP_SPACING
        return (cells < 0 and math.ceil(cells - 0.5) or math.floor(cells + 0.5)) * SNAP_SPACING
    end
    local function EditBounds(entry, width, height, uiScale, bounds)
        local region = entry.options.region or entry.frame
        local position = ReadPosition(region)
        local regionWidth, regionHeight = T.GetLocalSize(region)
        if
            not position
            or not Number(regionWidth)
            or not Number(regionHeight)
            or regionWidth <= 0
            or regionHeight <= 0
        then
            return
        end
        local ratio = Scale(region) / uiScale
        local left, top = position.x * width, position.y * height
        local scaledWidth, scaledHeight = regionWidth * ratio, regionHeight * ratio
        local changed = not T.NearlyEqual(bounds.left, left)
            or not T.NearlyEqual(bounds.top, top)
            or not T.NearlyEqual(bounds.width, scaledWidth)
            or not T.NearlyEqual(bounds.height, scaledHeight)
        bounds.left, bounds.top, bounds.width, bounds.height = left, top, scaledWidth, scaledHeight
        return bounds, changed
    end
    local function RefreshSnapTargets(entry, start, width, height, uiScale)
        local source = EditBounds(entry, width, height, uiScale, start.sourceBounds)
        local owner = ReadPosition(entry.frame)
        start.targetsAge, start.targetsDirty = 0, false
        if not source or not owner then
            if start.snapReady then start.targetRevision = start.targetRevision + 1 end
            start.snapReady = false
            return
        end
        -- Cache the visible region's offset from its owner, not its dragged
        -- position. Moving the owner must not invalidate an unchanged shape.
        local offsetX, offsetY = source.left - owner.x * width, source.top - owner.y * height
        local changed = not start.snapReady
            or not T.NearlyEqual(start.offsetX, offsetX)
            or not T.NearlyEqual(start.offsetY, offsetY)
            or not T.NearlyEqual(start.rect.width, source.width)
            or not T.NearlyEqual(start.rect.height, source.height)
        start.offsetX, start.offsetY = offsetX, offsetY
        start.rect.width, start.rect.height = source.width, source.height
        local screen = start.targets[1].rect
        local screenWidth, screenHeight = T.GetLocalSize(UIParent)
        if not T.NearlyEqual(screen.width, screenWidth) or not T.NearlyEqual(screen.height, screenHeight) then
            changed = true
        end
        screen.width, screen.height = screenWidth, screenHeight
        local used = 1
        for _, other in ipairs(order) do
            if other ~= entry and CanShowHandle(other) then
                local index = used + 1
                local target = start.targets[index]
                if not target then
                    target = { rect = {} }
                    start.targets[index] = target
                end
                local bounds, resized = EditBounds(other, width, height, uiScale, target.rect)
                if bounds then
                    if target.key ~= other or resized then changed = true end
                    target.key, used = other, index
                end
            end
        end
        if start.targetCount ~= used then changed = true end
        start.targetCount, start.snapReady = used, true
        if changed then start.targetRevision = start.targetRevision + 1 end
    end
    local function AxisPoint(rect, axis, point)
        if axis == "x" then return rect.left + rect.width * point / 2 end
        return rect.top - rect.height * point / 2
    end
    local function NearAxis(rect, target, axis, reach)
        if axis == "x" then
            return math.max(rect.top - rect.height - target.top, target.top - target.height - rect.top, 0) <= reach
        end
        return math.max(rect.left - target.left - target.width, target.left - rect.left - rect.width, 0) <= reach
    end
    local function SnapAxis(start, rect, axis)
        local targets, screen = start.targets, start.targets[1].rect
        local held = start.snaps[axis]
        if held then
            for index = 1, start.targetCount do
                local target = targets[index]
                if
                    target.key == held.target
                    and (target.key == "screen" or NearAxis(rect, target.rect, axis, GRID_SPACING * 4))
                then
                    local value = AxisPoint(target.rect, axis, held.point)
                    local delta = value - AxisPoint(rect, axis, held.source)
                    if math.abs(delta) <= SNAP_RELEASE then return delta, value end
                    break
                end
            end
            start.snaps[axis] = nil
        end
        local bestTarget, bestSource, bestPoint, bestDistance, bestDelta, bestGuide
        for index = 1, start.targetCount do
            local target = targets[index]
            for _, sourcePoint in ipairs(SNAP_POINTS) do
                local source = AxisPoint(rect, axis, sourcePoint)
                for _, targetPoint in ipairs(SNAP_POINTS) do
                    -- Screen edges keep the complete frame inside the screen.
                    local eligible = target.key == "screen" and sourcePoint == targetPoint
                        or target.key ~= "screen" and NearAxis(rect, target.rect, axis, GRID_SPACING * 3)
                    if eligible then
                        local value = AxisPoint(target.rect, axis, targetPoint)
                        local delta = value - source
                        local distance = math.abs(delta)
                        if distance <= SNAP_CAPTURE and (not bestTarget or distance < bestDistance) then
                            bestTarget, bestSource, bestPoint = target.key, sourcePoint, targetPoint
                            bestDistance, bestDelta, bestGuide = distance, delta, value
                        end
                    end
                end
            end
        end
        if bestTarget then
            local heldPoint = start.snapPool[axis]
            heldPoint.target, heldPoint.source, heldPoint.point = bestTarget, bestSource, bestPoint
            start.snaps[axis] = heldPoint
            return bestDelta, bestGuide
        end
        local origin = axis == "x" and screen.width / 2 or -screen.height / 2
        for _, point in ipairs(SNAP_POINTS) do
            local value = AxisPoint(rect, axis, point)
            local snapped = SnapToGrid(value - origin) + origin
            local delta = snapped - value
            local distance = math.abs(delta)
            if not bestDistance or distance < bestDistance then
                bestDistance, bestDelta, bestGuide = distance, delta, snapped
            end
        end
        return bestDelta, bestGuide
    end
    local function SnapMove(start, x, y)
        if not start.snapReady then
            HideSnapGuides()
            return x, y
        end
        local rect = start.rect
        rect.left, rect.top = x + start.offsetX, y + start.offsetY
        local dx, guideX = SnapAxis(start, rect, "x")
        local dy, guideY = SnapAxis(start, rect, "y")
        ShowSnapGuides(guideX, guideY)
        return x + dx, y + dy
    end
    UpdateMove = function(entry, force)
        local start = entry.moving
        local width, height, uiScale = Viewport()
        local cursorX, cursorY = Cursor()
        if not start or not width or not cursorX then return end
        -- A viewport transition finishes the drag using its last valid position.
        if
            not T.NearlyEqual(width, start.width)
            or not T.NearlyEqual(height, start.height)
            or not T.NearlyEqual(uiScale, start.uiScale)
        then
            return
        end
        local shift = IsShiftKeyDown() and true or false
        start.targetsAge = start.targetsAge + (tonumber(arg1) or 0)
        if shift and (force or start.targetsDirty or start.targetsAge >= EDITOR_INTERVAL) then
            RefreshSnapTargets(entry, start, width, height, uiScale)
        end
        if
            not force
            and start.lastCursorX == cursorX
            and start.lastCursorY == cursorY
            and start.lastShift == shift
            and start.lastRevision == start.targetRevision
        then
            return
        end
        local x, y = start.x + cursorX - start.cursorX, start.y + cursorY - start.cursorY
        if shift then
            x, y = SnapMove(start, x, y)
        else
            start.snaps.x, start.snaps.y = nil, nil
            start.targetsDirty = true
            HideSnapGuides()
        end
        entry.pointerPosition.x, entry.pointerPosition.y = x / width, y / height
        ApplyPosition(entry.frame, entry.pointerPosition)
        start.lastCursorX, start.lastCursorY = cursorX, cursorY
        start.lastShift, start.lastRevision = shift, start.targetRevision
        return true
    end
    local function BeginMove(entry)
        if not ready or not inWorld or not editing then return end
        FinishDrag(activeDrag, true)
        SelectEntry(entry, true)
        local width, height, uiScale = Viewport()
        local cursorX, cursorY = Cursor()
        local position = ReadPosition(entry.frame)
        if not width or not cursorX or not position then return end
        entry.moving = {
            snaps = {},
            snapPool = { x = {}, y = {} },
            sourceBounds = {},
            rect = {},
            targets = { { key = "screen", rect = { left = 0, top = 0 } } },
            targetsAge = 0,
            targetsDirty = true,
            targetRevision = 0,
            cursorX = cursorX,
            cursorY = cursorY,
            x = position.x * width,
            y = position.y * height,
            width = width,
            height = height,
            uiScale = uiScale,
        }
        entry.pointerPosition = position
        entry.dragging, activeDrag = true, entry
        UpdateMove(entry, true)
    end
    local function BeginResize(entry, corner, axis)
        if not ready or not inWorld or not editing then return end
        FinishDrag(activeDrag, true)
        SelectEntry(entry, true)
        local width, height, uiScale = Viewport()
        local x, y = Cursor()
        local region = not axis and entry.options.resizeToRegion and entry.options.region or entry.frame
        local position = ReadPosition(entry.frame)
        local regionPosition = region == entry.frame and position or ReadPosition(region)
        if not x or not position or not regionPosition or not width then return end
        local scale = Scale(region) / uiScale
        local frameWidth, frameHeight = T.GetLocalSize(region)
        entry.resizing = {
            corner = corner,
            axis = axis,
            region = region,
            cursorX = x,
            cursorY = y,
            x = regionPosition.x * width,
            y = regionPosition.y * height,
            width = frameWidth * scale,
            height = frameHeight * scale,
            scale = LocalScale(entry.frame),
            frameWidth = entry.frame:GetWidth(),
            frameHeight = entry.frame:GetHeight(),
            viewWidth = width,
            viewHeight = height,
            uiScale = uiScale,
        }
        entry.pointerPosition = position
        entry.dragging, activeDrag = true, entry
    end
    UpdateResize = function(entry, force)
        local start = entry.resizing
        local width, height, uiScale = Viewport()
        local cursorX, cursorY = Cursor()
        if not start or not width or not cursorX then return end
        if
            not T.NearlyEqual(width, start.viewWidth)
            or not T.NearlyEqual(height, start.viewHeight)
            or not T.NearlyEqual(uiScale, start.uiScale)
        then
            return
        end
        if
            not force
            and start.lastCursorX == cursorX
            and start.lastCursorY == cursorY
            and start.lastWidth == entry.frame:GetWidth()
            and start.lastHeight == entry.frame:GetHeight()
        then
            return
        end
        local right = string.find(start.corner, "RIGHT") ~= nil
        local top = string.find(start.corner, "TOP") ~= nil
        local signX, signY = right and 1 or -1, top and 1 or -1
        local dx, dy = cursorX - start.cursorX, cursorY - start.cursorY
        if start.axis == "height" and entry.options.onHeightDrag then
            local ratio = Scale(entry.frame) / uiScale
            entry.options.onHeightDrag((start.height + signY * dy) / ratio, start)
        elseif entry.options.resize == "dimensions" or start.axis == "width" then
            local ratio = Scale(entry.frame) / uiScale
            ApplySize(entry, {
                scale = start.scale,
                width = start.axis == "height" and start.frameWidth or (start.width + signX * dx) / ratio,
                height = start.axis == "width" and start.frameHeight or (start.height + signY * dy) / ratio,
            })
        else
            -- Project the pointer onto the corner diagonal, preserving artwork
            -- aspect ratios instead of stretching portraits, icons or bars.
            local diagonal = start.width * start.width + start.height * start.height
            if diagonal <= 0 then return end
            local factor = 1 + (signX * dx * start.width + signY * dy * start.height) / diagonal
            ApplySize(entry, { scale = start.scale * factor, width = start.frameWidth })
        end
        local ratio = Scale(start.region) / uiScale
        local frameWidth, frameHeight = T.GetLocalSize(start.region)
        local newWidth, newHeight = frameWidth * ratio, frameHeight * ratio
        -- Keep the visible region's opposite corner fixed, translating its
        -- layout owner by the measured offset instead of resizing empty bounds.
        local x = start.axis == "height" and start.x or (right and start.x or start.x + start.width - newWidth)
        local y = start.axis == "width" and start.y or (top and start.y - start.height + newHeight or start.y)
        local ownerPosition = ReadPosition(entry.frame)
        local regionPosition = start.region == entry.frame and ownerPosition or ReadPosition(start.region)
        if not ownerPosition or not regionPosition then return end
        entry.pointerPosition = {
            x = x / width - (regionPosition.x - ownerPosition.x),
            y = y / height - (regionPosition.y - ownerPosition.y),
        }
        ApplyPosition(entry.frame, entry.pointerPosition)
        start.lastCursorX, start.lastCursorY = cursorX, cursorY
        start.lastWidth, start.lastHeight = entry.frame:GetWidth(), entry.frame:GetHeight()
        return true
    end

    local function MakeEdge(entry, point, axis)
        local grip = CreateFrame("Button", nil, entry.handle)
        grip:SetWidth(axis == "width" and 14 or 20)
        grip:SetHeight(axis == "width" and 20 or 14)
        grip:SetPoint("CENTER", entry.frame, point, 0, 0)
        grip:SetFrameLevel(entry.handle:GetFrameLevel() + 2)
        local mark = grip:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\Buttons\\WHITE8X8")
        mark:SetVertexColor(0.87, 0.73, 0.41, 1)
        mark:SetWidth(axis == "width" and 3 or 14)
        mark:SetHeight(axis == "width" and 14 or 3)
        mark:SetPoint("CENTER", grip, "CENTER", 0, 0)
        grip:RegisterForDrag("LeftButton")
        grip:SetScript("OnDragStart", function() BeginResize(entry, point, axis) end)
        grip:SetScript("OnDragStop", function() FinishDrag(entry, true) end)
        grip:SetScript("OnMouseUp", function() FinishDrag(entry, true) end)
        grip:SetScript("OnHide", function() FinishDrag(entry, true) end)
        grip:EnableMouse(true)
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
        if entry.options.labelAbove then
            label:SetPoint("BOTTOM", handle, "TOP", 0, 6)
        else
            label:SetPoint("CENTER", handle, "CENTER", 0, 0)
        end
        label:SetTextColor(0.87, 0.73, 0.41)
        label:SetText(labels[entry.key] or entry.key)
        handle:SetScript("OnDragStart", function() BeginMove(entry) end)
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
        if entry.options.edgeWidth or entry.options.edgeHandles then
            MakeEdge(entry, "LEFT", "width")
            MakeEdge(entry, "RIGHT", "width")
        end
        if entry.options.onHeightDrag or entry.options.edgeHandles then
            MakeEdge(entry, "TOP", "height")
            MakeEdge(entry, "BOTTOM", "height")
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
    local function RefreshHandle(entry, scale)
        local handle, region = entry.handle, entry.options.region or entry.frame
        local shown = CanShowHandle(entry)
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
        RefreshEditorSoon()
        frame.Show = function(self)
            if not entry.wantsShown then RefreshEditorSoon() end
            entry.wantsShown = true
            if not IsHidden(entry) then entry.nativeShow(self) end
        end
        frame.Hide = function(self)
            if entry.wantsShown then RefreshEditorSoon() end
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
        local offsetX, offsetY = CenterOffsets(entry.frame, uiScale)
        return position.x * width + offsetX, position.y * height + offsetY
    end
    local function SetCoordinateText(field, text)
        -- Remember programmatic text before SetText, including delayed change events.
        coordinates[field].layoutText = text
        T.SetTextIfChanged(coordinates[field], text)
    end
    local coordinateState = {}
    RefreshCoordinates = function(force)
        if not coordinates or not selected then return end
        local x, y = CenterPosition(selected)
        local dimensions = selected.options.resize == "dimensions"
        local width = dimensions and selected.frame:GetWidth()
            or LocalScale(selected.frame) / selected.defaultScale * 100
        local height = selected.frame:GetHeight()
        local hidden, language = IsHidden(selected), DFRL.locale.code
        local gridShown = DFRL.display.Get("layoutShowGrid")
        if
            force == false
            and coordinateState.entry == selected
            and coordinateState.x == x
            and coordinateState.y == y
            and coordinateState.width == width
            and coordinateState.height == height
            and coordinateState.hidden == hidden
            and coordinateState.language == language
            and coordinateState.gridShown == gridShown
        then
            return
        end
        coordinates.refreshing = true
        T.SetTextIfChanged(coordinates.label, labels[selected.key] or selected.key)
        SetCoordinateText("x", x and string.format("%.2f", x) or "")
        SetCoordinateText("y", y and string.format("%.2f", y) or "")
        if not x then
            coordinates.unavailable = true
            T.SetTextIfChanged(coordinates.status, "Frame position is not available yet.")
        elseif coordinates.unavailable then
            coordinates.unavailable = false
            T.SetTextIfChanged(coordinates.status, "")
        end
        T.SetTextIfChanged(
            coordinates.sizeLabel,
            dimensions and "Width / Height (frame units)" or "Scale (%) - 40 to 300"
        )
        SetCoordinateText("width", string.format("%.2f", width))
        SetCoordinateText("height", string.format("%.2f", height))
        if dimensions then
            if not coordinates.height:IsShown() then coordinates.height:Show() end
        else
            if coordinates.height:IsShown() then coordinates.height:Hide() end
        end
        if coordinates.visibility.editorChecked ~= hidden then coordinates.visibility:SetChecked(hidden) end
        if coordinates.grid.editorChecked ~= gridShown then coordinates.grid:SetChecked(gridShown) end
        coordinateState.entry, coordinateState.x, coordinateState.y = selected, x, y
        coordinateState.width, coordinateState.height = width, height
        coordinateState.hidden, coordinateState.language = hidden, language
        coordinateState.gridShown = gridShown
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
            ApplySize(selected, { scale = selected.defaultScale * size / 100, width = frame:GetWidth() })
        end
        local offsetX, offsetY = CenterOffsets(frame, uiScale)
        local position = {
            x = (x - offsetX) / width,
            y = (y - offsetY) / height,
        }
        draft[selected.key] = ReadGeometry(selected, position)
        layout.Place(selected.key)
        RefreshEditorSoon()
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
                SetHidden(selected, geometry, hidden)
                draft[selected.key] = geometry
                ApplyVisibility(selected)
                RefreshEditorSoon()
                coordinates.status:SetText("Preview. Confirm to save.")
            end
        )
        visibility:SetPoint("TOPLEFT", coordinates, "TOPLEFT", 0, -156)
        coordinates.visibility = visibility
        coordinates.grid = T.CreateEditorToggle(
            coordinates,
            "Show grid",
            "Show the alignment grid while editing.",
            width,
            function(shown) DFRL.display.Set("layoutShowGrid", shown) end
        )
        coordinates.grid:SetPoint("TOPLEFT", coordinates, "TOPLEFT", 0, -204)
        DFRL.display.Listen(function()
            RefreshEditorSoon()
            if editing then UpdateGrid() end
            if coordinates and not coordinates.dirty and not coordinates.focused then RefreshCoordinates(false) end
        end)
        local apply = T.CreateEditorButton(coordinates, "Apply position / size", width, 28)
        apply:SetPoint("TOPLEFT", coordinates, "TOPLEFT", 0, -252)
        apply:SetScript("OnClick", ApplyCoordinates)
        coordinates.status = Text("", -290, 10)
        coordinates.status:SetWidth(width)
        coordinates.status:SetHeight(18)
        local refreshElapsed = 0
        coordinates:SetScript("OnUpdate", function()
            refreshElapsed = refreshElapsed + (arg1 or 0)
            if refreshElapsed < EDITOR_INTERVAL then return end
            refreshElapsed = 0
            if not coordinates.dirty and not coordinates.focused then RefreshCoordinates(false) end
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
    local function PrepareDraft()
        FinishDrag(activeDrag, true)
        if coordinates and coordinates.dirty and not ApplyCoordinates() then
            if showCoordinates then showCoordinates() end
            return
        end
        return true
    end
    function layout.Snapshot()
        if not editing or not PrepareDraft() then return end
        local copy = layout.Copy(draft)
        -- Include untouched defaults as well as records for lazy windows.
        for _, entry in ipairs(order) do
            if not copy[entry.key] then copy[entry.key] = ReadGeometry(entry, ReadPosition(entry.frame)) end
        end
        return copy
    end
    function layout.Load(source)
        if not editing then return end
        FinishDrag(activeDrag, false)
        draft = layout.Copy(source)
        if coordinates then
            ClearCoordinateFocus()
            coordinates.dirty = false
            coordinates.status:SetText("")
        end
        for _, entry in ipairs(order) do
            layout.Place(entry.key)
        end
        RefreshEditorSoon()
        if coordinates then RefreshCoordinates() end
    end
    local function CloseEditing(save, restore)
        if not editing then return end
        if save then
            if not PrepareDraft() then return end
        else
            FinishDrag(activeDrag, false)
        end
        if save then _G.SurvivorsDragonUiLayout = draft end
        editing, draft = false, nil
        if grid then grid:Hide() end
        for _, entry in ipairs(order) do
            if entry.options.onEdit then entry.options.onEdit(false, save) end
            LockFrame(entry.frame)
            ShowHandle(entry, false)
        end
        if DFRL.profiles then DFRL.profiles.FinishEdit(save) end
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
        RefreshEditorSoon()
        local starting = not editing
        handlesOnly = onlyHandles == true
        if editing and handlesOnly and coordinates then
            -- Keep staged geometry, but leave no unapplied text behind a hidden dialog.
            FinishDrag(activeDrag, true)
            ClearCoordinateFocus()
            RefreshCoordinates()
        end
        if not editing then
            draft = layout.Copy(Saved())
            editing = true
            for _, entry in ipairs(order) do
                LockFrame(entry.frame)
                layout.Place(entry.key)
                if entry.options.onEdit then entry.options.onEdit(true) end
            end
            if DFRL.profiles then DFRL.profiles.BeginEdit() end
        end
        UpdateGrid()
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
            RefreshEditorSoon()
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
        local dragChanged
        if activeDrag and activeDrag.moving then dragChanged = UpdateMove(activeDrag) end
        if activeDrag and activeDrag.resizing then dragChanged = UpdateResize(activeDrag) end
        if needsDefaultPosition then
            needsDefaultPosition = false
            for _, entry in ipairs(order) do
                if not entry.defaultPosition then
                    layout.Place(entry.key)
                    if entry.defaultPosition then RefreshEditorSoon() end
                end
            end
        end
        -- Settled groups need no handle reads or native visibility writes during
        -- gameplay. Viewport changes and unresolved defaults still run above.
        if not enabled then return end
        editorAge = editorAge + (tonumber(arg1) or 0)
        local fine = activeDrag and activeDrag.moving and IsShiftKeyDown() and true or false
        if editorDirty or editorAge >= EDITOR_INTERVAL or (DFRL.display.Get("layoutShowGrid") and gridFine ~= fine) then
            editorAge, editorDirty = 0, false
            UpdateGrid()
            for _, entry in ipairs(order) do
                RefreshHandle(entry, scale)
            end
        elseif dragChanged and activeDrag then
            -- The dragged outline follows size changes at the render cadence;
            -- other groups only need the bounded editor refresh above.
            RefreshHandle(activeDrag, scale)
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
    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            layout.CancelEdit()
            return reloadUI()
        end
    end
end)

-- Modules may depend on each other's initial anchors. Restore saved positions last.
DFRL:NewMod("Layout Ready", 20, function() DFRL.layout.Ready() end)
