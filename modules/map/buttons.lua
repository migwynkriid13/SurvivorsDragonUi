-- Dragon Glyph artwork and preparation: third_party/MinimapGlyph-ARTWORK.md.
DFRL:NewMod("Minimap Buttons", 3, function()
    local buttons, records = {}, {}
    local launcher, StopDrag
    local inWorld = true
    local edge = 8

    _G.GetMinimapShape = function() return "SQUARE" end

    local function Number(value) return type(value) == "number" and value - value == 0 end
    local function Visible() return inWorld and Minimap:IsVisible() and not DFRL.layout.IsHidden("minimap") end
    local function SquareOffset(button, x, y)
        if not Number(x) or not Number(y) or (x == 0 and y == 0) then return end
        local width, height = Minimap:GetWidth(), Minimap:GetHeight()
        local mapScale, buttonScale = Minimap:GetEffectiveScale(), button:GetEffectiveScale()
        if
            not Number(width)
            or not Number(height)
            or not Number(mapScale)
            or not Number(buttonScale)
            or width <= 0
            or height <= 0
            or mapScale <= 0
            or buttonScale <= 0
        then
            return
        end
        local scale = mapScale / buttonScale
        local halfWidth, halfHeight = (width / 2 + edge) * scale, (height / 2 + edge) * scale
        local divisor = math.max(math.abs(x) / halfWidth, math.abs(y) / halfHeight)
        return x / divisor, y / divisor
    end
    local function SetCenter(record, x, y)
        local button = record.button
        if button:GetNumPoints() == 1 then
            local point, relative, relativePoint, oldX, oldY = button:GetPoint(1)
            if
                point == "CENTER"
                and (relative == Minimap or relative == "Minimap")
                and relativePoint == "CENTER"
                and T.NearlyEqual(oldX, x)
                and T.NearlyEqual(oldY, y)
            then
                return
            end
        end
        button:ClearAllPoints()
        record.setPoint(button, "CENTER", Minimap, "CENTER", x, y)
    end
    local function Place(record)
        if not Visible() or not record.button:IsShown() then return end
        local x, y = SquareOffset(record.button, record.x, record.y)
        if x then SetCenter(record, x, y) end
    end
    local function Register(button)
        if records[button] or not button.GetObjectType then return end
        local kind = button:GetObjectType()
        if kind ~= "Button" and kind ~= "CheckButton" then return end
        local name, width, height = button:GetName() or "", button:GetWidth(), button:GetHeight()
        if not Number(width) or not Number(height) or width <= 0 or height <= 0 or width > 64 or height > 64 then
            return
        end
        if
            button ~= launcher
            and not string.find(name, "^LibDBIcon")
            and not (button:GetScript("OnDragStart") and button:GetScript("OnDragStop"))
        then
            return
        end
        local record = { button = button, setPoint = button.SetPoint }
        records[button] = record
        table.insert(buttons, record)
        button.SetPoint = function(self, point, relative, relativePoint, x, y)
            if
                point == "CENTER"
                and (relative == Minimap or relative == "Minimap")
                and relativePoint == "CENTER"
                and Number(x)
                and Number(y)
                and (x ~= 0 or y ~= 0)
            then
                record.x, record.y = x, y
                if Visible() and self:IsShown() then
                    local squareX, squareY = SquareOffset(self, x, y)
                    if squareX then return SetCenter(record, squareX, squareY) end
                end
            else
                record.x, record.y = nil, nil
            end
            return record.setPoint(self, point, relative, relativePoint, x, y)
        end
        HookScript(button, "OnShow", function() Place(record) end)
        if button:GetNumPoints() == 1 then
            local point, relative, relativePoint, x, y = button:GetPoint(1)
            button:SetPoint(point, relative, relativePoint, x, y)
        end
    end
    local function Discover(parent, depth)
        if not parent or not parent.GetChildren then return end
        for _, child in ipairs({ parent:GetChildren() }) do
            Register(child)
            if depth > 0 and child ~= Minimap then Discover(child, depth - 1) end
        end
    end
    local function Refresh()
        if not Visible() then return end
        for _, record in ipairs(buttons) do
            Place(record)
        end
    end
    local function DiscoverButtons()
        Discover(Minimap, 1)
        Discover(MinimapCluster, 1)
        Refresh()
    end

    launcher = CreateFrame("Button", "SurvivorsDragonUiMinimapButton", Minimap)
    launcher:SetWidth(34)
    launcher:SetHeight(34)
    launcher:SetFrameLevel(Minimap:GetFrameLevel() + 20)
    launcher:RegisterForClicks("LeftButtonUp")
    launcher:RegisterForDrag("LeftButton")
    local glyph = launcher:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(DFRL:GetInfoOrCons("tex") .. "minimap\\DragonGlyph.blp")
    glyph:SetBlendMode("ADD")
    glyph:SetAllPoints(launcher)
    local alpha = 0.85
    glyph:SetAlpha(alpha)
    local function SetAlpha(value)
        if alpha == value then return end
        alpha = value
        glyph:SetAlpha(value)
    end
    local function HideTooltip()
        if GameTooltip and GameTooltip:IsOwned(launcher) then GameTooltip:Hide() end
    end
    local dragging, suppressClickUntil = false, 0
    local function Drag()
        if not dragging or not Visible() or DFRL.layout.IsEditing() then
            StopDrag()
            return
        end
        local centerX, centerY = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        if not Number(centerX) or not Number(centerY) or not Number(scale) or scale <= 0 then return end
        if not Number(cursorX) or not Number(cursorY) then return end
        local x, y = cursorX / scale - centerX, cursorY / scale - centerY
        if x == 0 and y == 0 then return end
        launcher:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    StopDrag = function()
        if not dragging then return end
        dragging = false
        launcher:SetScript("OnUpdate", nil)
        suppressClickUntil = GetTime() + 0.15
    end
    launcher:SetScript("OnDragStart", function()
        if not Visible() or DFRL.layout.IsEditing() then return end
        dragging = true
        HideTooltip()
        launcher:SetScript("OnUpdate", Drag)
        Drag()
    end)
    launcher:SetScript("OnDragStop", function()
        Drag()
        StopDrag()
    end)
    launcher:SetScript("OnClick", function()
        if dragging or GetTime() < suppressClickUntil then return end
        HideTooltip()
        DFRL.layout.BeginEdit()
    end)
    launcher:SetScript("OnEnter", function()
        SetAlpha(1)
        if dragging or DFRL.layout.IsEditing() or not GameTooltip then return end
        GameTooltip:SetOwner(launcher, "ANCHOR_LEFT")
        GameTooltip:SetText("SurvivorsDragonUi")
        GameTooltip:AddLine(DFRL.locale.Text("Layout") .. " — /sdui", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave", function()
        SetAlpha(0.85)
        HideTooltip()
    end)
    launcher:SetScript("OnHide", function()
        StopDrag()
        HideTooltip()
    end)
    Register(launcher)
    launcher:SetPoint("CENTER", Minimap, "CENTER", -1, -1)
    HookScript(Minimap, "OnShow", DiscoverButtons)
    HookScript(Minimap, "OnSizeChanged", Refresh)
    HookScript(Minimap, "OnHide", function()
        StopDrag()
        HideTooltip()
    end)
    DFRL.layout.ListenVisibility("minimap", function()
        if Visible() then
            Refresh()
        else
            StopDrag()
            HideTooltip()
        end
    end)
    local controller = CreateFrame("Frame")
    controller:RegisterEvent("ADDON_LOADED")
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            StopDrag()
            HideTooltip()
        elseif event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            DiscoverButtons()
        elseif event == "ADDON_LOADED" then
            DiscoverButtons()
        end
    end)
    DiscoverButtons()
end)
