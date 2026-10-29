-- Dragonflight 10.2.7 EditModeUtil magnetism, independently implemented for SDUI.
-- Eight physical pixels, adjacent frame edges/corners, then grid/screen lines.
-- Runtime API/frame ownership and source provenance: docs/LAYOUT-HANDLES.md.
setfenv(1, DFRL:GetEnv())

local CHECK_POINTS = { 0, 2, 1 }

local function Point(rect, axis, index)
    return axis == "x" and rect.left + rect.width * index / 2 or rect.top - rect.height * index / 2
end
local function Candidate(best, distance, delta, guide, target)
    distance = math.abs(distance)
    if distance > best.range or best.distance and distance >= best.distance then return end
    best.distance, best.delta, best.guide, best.target = distance, delta, guide, target
end
local function Axis(start, rect, axis, showGrid, spacing, scale, result)
    result.distance, result.delta, result.guide, result.target = nil, nil, nil, nil
    result.range = 8 / scale
    local screen = start.targets[1].rect
    -- Retail checks matching screen edges plus each selection edge/center
    -- against the screen center, even with the visible grid disabled.
    local center = Point(screen, axis, 1)
    for _, index in ipairs(CHECK_POINTS) do
        local from = Point(rect, axis, index)
        if index ~= 1 then
            local to = Point(screen, axis, index)
            Candidate(result, to - from, to - from, to, "screen")
        end
        Candidate(result, center - from, center - from, center, "screen")
        if showGrid then
            local cells = (from - center) / spacing
            local to = center + math.floor(cells + 0.5) * spacing
            Candidate(result, to - from, to - from, to, "grid")
        end
    end
    local frameResult = axis == "x" and start.retail.frameX or start.retail.frameY
    frameResult.distance, frameResult.target = nil, nil
    frameResult.range = result.range
    for index = 2, start.targetCount do
        local target = start.targets[index]
        local other = target.rect
        local bottom, otherBottom = rect.top - rect.height, other.top - other.height
        local right, otherRight = rect.left + rect.width, other.left + other.width
        local eligible, delta, guide
        if axis == "x" and rect.top >= otherBottom and bottom <= other.top then
            if right <= other.left then
                delta, guide = other.left - right, other.left
            elseif rect.left >= otherRight then
                delta, guide = otherRight - rect.left, otherRight
            end
        elseif axis == "y" and rect.left <= otherRight and right >= other.left then
            if bottom >= other.top then
                delta, guide = other.top - bottom, other.top
            elseif rect.top <= otherBottom then
                delta, guide = otherBottom - rect.top, otherBottom
            end
        end
        eligible = delta ~= nil
        if eligible then
            Candidate(result, delta, delta, guide, target.key)
            Candidate(frameResult, delta, delta, guide, target)
        end
    end
end

function DFRL.tools.RetailSnap(start, x, y, showGrid, spacing, scale)
    start.retail = start.retail or { x = {}, y = {}, frameX = {}, frameY = {}, corner = {} }
    local output = start.retail
    output.dx, output.dy, output.guideX, output.guideY, output.target = 0, 0, nil, nil, nil
    if not start.snapReady then return output end
    local rect = start.rect
    rect.left, rect.top = x + start.offsetX, y + start.offsetY
    Axis(start, rect, "x", showGrid, spacing, scale, output.x)
    Axis(start, rect, "y", showGrid, spacing, scale, output.y)
    local corner = output.corner
    corner.distance = nil
    local range = 8 / scale
    for index = 1, 2 do
        local axis = index == 1 and output.frameX or output.frameY
        local target = axis.target
        if target then
            for source = 0, 3 do
                local sx, sy = math.mod(source, 2), math.floor(source / 2)
                for destination = 0, 3 do
                    local tx, ty = math.mod(destination, 2), math.floor(destination / 2)
                    -- Retail excludes diagonally opposed corner connections.
                    if sx == tx or sy == ty then
                        local gx = target.rect.left + tx * target.rect.width
                        local gy = target.rect.top - ty * target.rect.height
                        local dx = gx - rect.left - sx * rect.width
                        local dy = gy - rect.top + sy * rect.height
                        local distance = dx * dx + dy * dy
                        if distance <= range * range * 2 and (not corner.distance or distance < corner.distance) then
                            corner.distance, corner.dx, corner.dy = distance, dx, dy
                            corner.guideX, corner.guideY, corner.target = gx, gy, target.key
                        end
                    end
                end
            end
        end
    end
    if corner.distance then
        output.dx, output.dy = corner.dx, corner.dy
        output.guideX, output.guideY, output.target = corner.guideX, corner.guideY, corner.target
    else
        local horizontal, vertical = output.x, output.y
        local hx = horizontal.target == "screen" or horizontal.target == "grid"
        local vy = vertical.target == "screen" or vertical.target == "grid"
        if horizontal.distance and vertical.distance and hx and vy then
            output.dx, output.dy = horizontal.delta, vertical.delta
            output.guideX, output.guideY = horizontal.guide, vertical.guide
        elseif horizontal.distance and (not vertical.distance or horizontal.distance < vertical.distance) then
            output.dx, output.guideX, output.target = horizontal.delta, horizontal.guide, horizontal.target
        elseif vertical.distance then
            output.dy, output.guideY, output.target = vertical.delta, vertical.guide, vertical.target
        end
    end
    return output
end
