-- Read-only, session-only frame inspection through the native 1.12 widget API.
DFRL:NewMod("Frame stack", 2, function()
    local INTERVAL, SCAN_LIMIT, STACK_ROWS = 0.2, 10000, 10
    local strataOrder = {
        BACKGROUND = 1,
        LOW = 2,
        MEDIUM = 3,
        HIGH = 4,
        DIALOG = 5,
        FULLSCREEN = 6,
        FULLSCREEN_DIALOG = 7,
        TOOLTIP = 8,
    }
    local enabled, inWorld, elapsed = false, true, 0
    local panel, highlight
    local labels = {}
    local controller = CreateFrame("Frame", nil, UIParent)

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Flag(value) return value == true or value == 1 end
    local function Read(frame, method, index)
        local kind = type(frame)
        if (kind ~= "table" and kind ~= "userdata") or type(frame[method]) ~= "function" then return end
        local ok, a, b, c, d, e
        if index then
            ok, a, b, c, d, e = pcall(frame[method], frame, index)
        else
            ok, a, b, c, d, e = pcall(frame[method], frame)
        end
        if ok then return a, b, c, d, e end
    end
    local function Name(frame)
        if not frame then return "none" end
        local name = Read(frame, "GetName")
        if not name or name == "" then
            name = "(unnamed " .. tostring(Read(frame, "GetObjectType") or "frame") .. ") " .. tostring(frame)
        end
        return (string.gsub(tostring(name), "|", "||"))
    end
    local function Visible(frame)
        if type(frame) ~= "table" and type(frame) ~= "userdata" then return false end
        if frame.IsVisible then return Flag(Read(frame, "IsVisible")) end
        -- IsShown alone does not account for a hidden parent.
        local parent, depth = frame, 0
        while parent and depth < 64 do
            if not Flag(Read(parent, "IsShown")) then return false end
            parent, depth = Read(parent, "GetParent"), depth + 1
        end
        return parent == nil
    end
    local function Bounds(frame, uiScale, uiLeft, uiBottom)
        local scale = Read(frame, "GetEffectiveScale")
        local left, right = Read(frame, "GetLeft"), Read(frame, "GetRight")
        local bottom, top = Read(frame, "GetBottom"), Read(frame, "GetTop")
        if
            not Number(scale)
            or scale <= 0
            or not Number(left)
            or not Number(right)
            or right <= left
            or not Number(bottom)
            or not Number(top)
            or top <= bottom
        then
            return
        end
        local ratio = scale / uiScale
        return {
            left = left * ratio - uiLeft,
            right = right * ratio - uiLeft,
            bottom = bottom * ratio - uiBottom,
            top = top * ratio - uiBottom,
        }
    end
    local function CreateOverlay()
        if panel then return end
        panel = CreateFrame("Frame", "SurvivorsDragonUiFrameStack", UIParent)
        panel:SetFrameStrata("TOOLTIP")
        panel:SetFrameLevel(1000)
        panel:EnableMouse(false)
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        panel:SetBackdropColor(0.025, 0.03, 0.04, 0.94)
        panel:SetBackdropBorderColor(0.73, 0.58, 0.34, 1)
        highlight = CreateFrame("Frame", "SurvivorsDragonUiFrameStackHighlight", UIParent)
        highlight:SetFrameStrata("TOOLTIP")
        highlight:SetFrameLevel(999)
        highlight:EnableMouse(false)
        highlight:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        highlight:SetBackdropBorderColor(1, 0.85, 0.15, 1)
        highlight:Hide()
    end
    local function Display(lines, cursorX, width, height)
        local panelWidth = math.max(100, math.min(620, width - 24))
        local maximumHeight = math.max(14, height - 44)
        local count, contentHeight = 0, 0
        panel:SetWidth(panelWidth)
        panel:ClearAllPoints()
        local side = cursorX > width / 2 and "TOPLEFT" or "TOPRIGHT"
        panel:SetPoint(side, UIParent, side, side == "TOPLEFT" and 12 or -12, -12)
        for i = 1, table.getn(lines) do
            local label = labels[i]
            if not label then
                label = panel:CreateFontString(nil, "OVERLAY")
                label:SetFont("DEFAULT", 11, "OUTLINE")
                label:SetJustifyH("LEFT")
                label:SetJustifyV("TOP")
                label:SetShadowColor(0, 0, 0, 1)
                label:SetShadowOffset(1, -1)
                table.insert(labels, label)
            end
            label:SetWidth(panelWidth - 20)
            label:SetText(lines[i])
            -- The native 1.12 width getter measures the wrapped text; GetHeight
            -- then exposes its height without a later-client GetStringHeight API.
            Read(label, "GetStringWidth")
            local measured = Read(label, "GetHeight")
            local lineHeight = Number(measured) and math.max(14, measured + 2) or 14
            local remaining = i < table.getn(lines) and 14 or 0
            local limited = contentHeight + lineHeight + remaining > maximumHeight
            if limited then
                label:SetText("... screen limit reached; /fstack off to close.")
                lineHeight = 14
            end
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10 - contentHeight)
            label:SetTextColor(1, i == 1 and 0.82 or 1, i == 1 and 0.35 or 1)
            label:Show()
            count, contentHeight = i, contentHeight + lineHeight
            if limited then break end
        end
        for i = count + 1, table.getn(labels) do
            labels[i]:SetText("")
            labels[i]:Hide()
        end
        panel:SetHeight(contentHeight + 20)
        panel:Show()
    end
    local function Refresh()
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        local uiScale = Read(UIParent, "GetEffectiveScale")
        local uiLeft, uiBottom = Read(UIParent, "GetLeft") or 0, Read(UIParent, "GetBottom") or 0
        if not Number(width) or not Number(height) or width <= 0 or height <= 0 then
            panel:Hide()
            highlight:Hide()
            return
        end
        local lines = { "SurvivorsDragonUi frame stack - /fstack to close" }
        highlight:Hide()
        if type(_G.GetCursorPosition) ~= "function" or not Number(uiScale) or uiScale <= 0 then
            table.insert(lines, "Native cursor/scale data is unavailable.")
            Display(lines, 0, width, height)
            return
        end
        local cursorX, cursorY = _G.GetCursorPosition()
        if not Number(cursorX) or not Number(cursorY) then return end
        cursorX, cursorY = cursorX / uiScale - uiLeft, cursorY / uiScale - uiBottom
        local focus
        if type(_G.GetMouseFocus) == "function" then
            local ok, frame = pcall(_G.GetMouseFocus)
            if ok and frame ~= panel and frame ~= highlight then focus = frame end
        end
        local rows, seen = {}, {}
        local function Add(frame, order)
            if frame == panel or frame == highlight or not Visible(frame) then return end
            local bounds = Bounds(frame, uiScale, uiLeft, uiBottom)
            if
                not bounds
                or cursorX < bounds.left
                or cursorX > bounds.right
                or cursorY < bounds.bottom
                or cursorY > bounds.top
            then
                return
            end
            local strata = Read(frame, "GetFrameStrata") or "UNKNOWN"
            local level = Read(frame, "GetFrameLevel")
            table.insert(rows, {
                frame = frame,
                strata = strata,
                rank = strataOrder[strata] or 0,
                level = Number(level) and level or 0,
                order = order,
            })
        end
        local scanned, frame, warning = 0, nil, nil
        if type(_G.EnumerateFrames) == "function" then
            while scanned < SCAN_LIMIT do
                local ok, nextFrame = pcall(_G.EnumerateFrames, frame)
                if not ok or (nextFrame and seen[nextFrame]) then
                    warning = "Frame enumeration stopped; the list may be incomplete."
                    break
                end
                if not nextFrame then break end
                scanned, frame = scanned + 1, nextFrame
                seen[frame] = true
                Add(frame, scanned)
            end
            if scanned == SCAN_LIMIT then warning = "Frame scan limit reached; the list may be incomplete." end
        else
            warning = "EnumerateFrames unavailable; showing mouse focus and parents."
        end
        -- Also include focus on older clients without frame enumeration.
        frame = focus
        for i = 1, 64 do
            if not frame or frame == panel or frame == highlight then break end
            if not seen[frame] then
                seen[frame] = true
                Add(frame, SCAN_LIMIT + 1 - i)
            end
            frame = Read(frame, "GetParent")
        end
        table.sort(rows, function(a, b)
            if a.rank ~= b.rank then return a.rank > b.rank end
            if a.level ~= b.level then return a.level > b.level end
            return a.order > b.order
        end)
        table.insert(lines, "Mouse focus: " .. Name(focus))
        table.insert(lines, "Frames at cursor by strata/level (> = mouse focus):")
        local count = table.getn(rows)
        for i = 1, math.min(count, STACK_ROWS) do
            local row = rows[i]
            table.insert(
                lines,
                (row.frame == focus and "> " or "  ") .. row.strata .. ":" .. row.level .. "  " .. Name(row.frame)
            )
        end
        if count > STACK_ROWS then table.insert(lines, "+ " .. (count - STACK_ROWS) .. " more overlapping frames") end
        if count == 0 then table.insert(lines, "No visible frame bounds at the cursor.") end
        if warning then table.insert(lines, warning) end
        local inspected = focus or (rows[1] and rows[1].frame)
        if inspected then
            table.insert(lines, "")
            table.insert(lines, "Inspect: " .. Name(inspected))
            table.insert(lines, "Parent: " .. Name(Read(inspected, "GetParent")))
            local frameWidth, frameHeight = Read(inspected, "GetWidth"), Read(inspected, "GetHeight")
            local scale = Read(inspected, "GetEffectiveScale")
            if Number(frameWidth) and Number(frameHeight) and Number(scale) then
                table.insert(
                    lines,
                    string.format("Size %.2f x %.2f; effective scale %.3f", frameWidth, frameHeight, scale)
                )
            end
            table.insert(
                lines,
                "Type: "
                    .. tostring(Read(inspected, "GetObjectType") or "unknown")
                    .. "; strata: "
                    .. tostring(Read(inspected, "GetFrameStrata") or "unknown")
                    .. "; level: "
                    .. tostring(Read(inspected, "GetFrameLevel") or "unknown")
            )
            local bounds = Bounds(inspected, uiScale, uiLeft, uiBottom)
            if bounds then
                table.insert(
                    lines,
                    string.format(
                        "UI bounds L %.2f B %.2f R %.2f T %.2f",
                        bounds.left,
                        bounds.bottom,
                        bounds.right,
                        bounds.top
                    )
                )
                if inspected ~= UIParent and inspected ~= WorldFrame then
                    highlight:ClearAllPoints()
                    highlight:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", bounds.left, bounds.top)
                    highlight:SetWidth(bounds.right - bounds.left)
                    highlight:SetHeight(bounds.top - bounds.bottom)
                    highlight:Show()
                end
            end
            local points = Read(inspected, "GetNumPoints")
            if Number(points) then
                for i = 1, math.min(points, 4) do
                    local point, relative, relativePoint, x, y = Read(inspected, "GetPoint", i)
                    if point and Number(x) and Number(y) then
                        table.insert(
                            lines,
                            string.format(
                                "%s -> %s.%s (%.2f, %.2f)",
                                point,
                                Name(relative),
                                tostring(relativePoint),
                                x,
                                y
                            )
                        )
                    end
                end
                if points > 4 then table.insert(lines, "+ " .. (points - 4) .. " more anchors") end
            end
        end
        table.insert(lines, "Bounds overlap is not a native hit-test or exact draw order.")
        Display(lines, cursorX, width, height)
    end
    local function SetEnabled(value)
        enabled, elapsed = value and inWorld, 0
        controller:SetScript("OnUpdate", nil)
        if not enabled then
            if panel then panel:Hide() end
            if highlight then highlight:Hide() end
            for _, label in ipairs(labels) do
                label:SetText("")
            end
            return
        end
        CreateOverlay()
        Refresh()
        controller:SetScript("OnUpdate", function()
            elapsed = elapsed + (arg1 or 0)
            if elapsed < INTERVAL then return end
            elapsed = 0
            Refresh()
        end)
    end
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        inWorld = event == "PLAYER_ENTERING_WORLD"
        if not inWorld then SetEnabled(false) end
    end)
    _G.SLASH_SURVIVORSDRAGONUIFSTACK1 = "/fstack"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList["SURVIVORSDRAGONUIFSTACK"] = function(message)
        local command = string.lower(string.gsub(message or "", "^%s*(.-)%s*$", "%1"))
        if command == "" then
            SetEnabled(not enabled)
        elseif command == "on" or command == "off" then
            SetEnabled(command == "on")
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                "SurvivorsDragonUi: /fstack toggles frame inspection; /fstack on|off sets it."
            )
        end
    end
end)
