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
        local allowance = button == launcher and 0 or edge
        local halfWidth, halfHeight = (width / 2 + allowance) * scale, (height / 2 + allowance) * scale
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

    local launcherSize = 34
    launcher = CreateFrame("Button", "SurvivorsDragonUiMinimapButton", Minimap)
    launcher:SetWidth(launcherSize)
    launcher:SetHeight(launcherSize)
    launcher:SetFrameLevel(Minimap:GetFrameLevel() + 20)
    launcher:RegisterForClicks("LeftButtonUp")
    launcher:RegisterForDrag("LeftButton")
    local background = launcher:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(DFRL:GetInfoOrCons("tex") .. "minimap\\LauncherBackgroundClean.blp")
    background:SetTexCoord(0, 29 / 32, 3 / 32, 29 / 32)
    background:SetWidth(37)
    background:SetHeight(33)
    background:SetPoint("CENTER", launcher, "CENTER", 0, 0)
    local glyph = launcher:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(DFRL:GetInfoOrCons("tex") .. "minimap\\DragonGlyph.blp")
    glyph:SetBlendMode("ADD")
    glyph:SetWidth(launcherSize)
    glyph:SetHeight(launcherSize)
    glyph:SetPoint("CENTER", launcher, "CENTER", 1.2, -1.3)
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
        if not launcher:IsVisible() or dragging or GetTime() < suppressClickUntil then return end
        HideTooltip()
        DFRL.layout.ToggleEdit()
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
        SetAlpha(0.85)
    end)
    local function RefreshLauncherVisibility()
        local shown = launcher:IsShown() and true or false
        if DFRL.display.Get("minimapShowLauncher") == shown then return end
        if shown then
            launcher:Hide()
        else
            launcher:Show()
        end
    end
    DFRL.display.Listen(RefreshLauncherVisibility)
    RefreshLauncherVisibility()
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
    -- The native graphics preference stays game-owned; only an explicit click writes it.
    local fx = CreateFrame("Button", "SurvivorsDragonUiSpellFxButton", Minimap)
    fx:SetWidth(26)
    fx:SetHeight(26)
    fx:SetFrameLevel(Minimap:GetFrameLevel() + 20)
    fx:RegisterForClicks("LeftButtonUp")
    fx:RegisterForDrag("LeftButton")
    local fxBackgroundPath = DFRL:GetInfoOrCons("tex") .. "minimap\\LauncherBackgroundClean.blp"
    local fxIconPath = "Interface\\Icons\\Spell_Fire_Fireball02"
    local fxBackgroundReady, fxIconReady
    local fxBorder = fx:CreateTexture(nil, "BACKGROUND")
    fxBorder:SetTexCoord(0, 29 / 32, 3 / 32, 29 / 32)
    fxBorder:SetWidth(29)
    fxBorder:SetHeight(26)
    fxBorder:SetPoint("CENTER", fx, "CENTER", 0, 0)
    local fxIcon = fx:CreateTexture(nil, "ARTWORK")
    fxIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fxIcon:SetWidth(18)
    fxIcon:SetHeight(18)
    fxIcon:SetPoint("CENTER", fx, "CENTER", 0, 0)
    local fxOff, fxDragging, fxSuppressUntil = nil, false, 0
    local function PrepareFx()
        if not fxBackgroundReady then
            local loaded = fxBorder:SetTexture(fxBackgroundPath)
            fxBackgroundReady = T.TextureAssigned(loaded, fxBorder:GetTexture(), fxBackgroundPath)
        end
        if not fxIconReady then
            local loaded = fxIcon:SetTexture(fxIconPath)
            fxIconReady = T.TextureAssigned(loaded, fxIcon:GetTexture(), fxIconPath)
        end
        return fxBackgroundReady and fxIconReady
    end
    local function ReadFx()
        if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then return end
        local ok, value = pcall(GetCVar, "noSpellEffects")
        if not ok then return end
        if value == "0" or value == 0 then return false end
        if value == "1" or value == 1 then return true end
    end
    local function HideFxTooltip()
        if GameTooltip and GameTooltip:IsOwned(fx) then GameTooltip:Hide() end
    end
    local function FxTooltip()
        if not Visible() or fxDragging or DFRL.layout.IsEditing() or not GameTooltip then return end
        local off = ReadFx()
        if off == nil then return end
        GameTooltip:SetOwner(fx, "ANCHOR_LEFT")
        GameTooltip:SetText(DFRL.locale.Text("Spell effects") .. ": " .. DFRL.locale.Text(off and "Off" or "On"))
        GameTooltip:AddLine(DFRL.locale.Text("Click to toggle spell effects."), 1, 0.82, 0)
        GameTooltip:AddLine(DFRL.locale.Text("Drag to move."), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end
    local function PaintFx()
        if not Visible() then return end
        local off = ReadFx()
        if off == nil or not PrepareFx() then
            if fx:IsShown() then fx:Hide() end
            return
        end
        if fxOff ~= off then
            fxOff = off
            if fxIcon.SetDesaturated then pcall(fxIcon.SetDesaturated, fxIcon, off and 1 or nil) end
            local tint = off and 0.45 or 1
            fxIcon:SetVertexColor(tint, tint, tint)
        end
        if not fx:IsShown() then fx:Show() end
    end
    local StopFxDrag
    local dragX, dragY
    local function RestoreFxPosition()
        local position = _G.SurvivorsDragonUiSpellFx
        local x, y
        if type(position) == "table" then
            x, y = position.x, position.y
        end
        if not Number(x) or not Number(y) or (x == 0 and y == 0) then
            x, y = 0, -1
        end
        local magnitude = math.max(math.abs(x), math.abs(y))
        fx:SetPoint("CENTER", Minimap, "CENTER", x / magnitude, y / magnitude)
    end
    local function FxDrag()
        if not fxDragging then return end
        if not Visible() or DFRL.layout.IsEditing() then
            StopFxDrag(false)
            return
        end
        local centerX, centerY = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        if not Number(centerX) or not Number(centerY) or not Number(scale) or scale <= 0 then return end
        if not Number(cursorX) or not Number(cursorY) then return end
        local x, y = cursorX / scale - centerX, cursorY / scale - centerY
        if Number(x) and Number(y) and (x ~= 0 or y ~= 0) then
            local magnitude = math.max(math.abs(x), math.abs(y))
            dragX, dragY = x / magnitude, y / magnitude
            fx:SetPoint("CENTER", Minimap, "CENTER", dragX, dragY)
        end
    end
    StopFxDrag = function(sample)
        if not fxDragging then return end
        if sample and Visible() and not DFRL.layout.IsEditing() then FxDrag() end
        if dragX then _G.SurvivorsDragonUiSpellFx = { x = dragX, y = dragY } end
        dragX, dragY = nil, nil
        fxDragging = false
        fx:SetScript("OnUpdate", nil)
        fxSuppressUntil = GetTime() + 0.15
    end
    fx:SetScript("OnDragStart", function()
        if not Visible() or DFRL.layout.IsEditing() then return end
        fxDragging = true
        HideFxTooltip()
        fx:SetScript("OnUpdate", FxDrag)
    end)
    fx:SetScript("OnDragStop", function() StopFxDrag(true) end)
    fx:SetScript("OnClick", function()
        if not Visible() or DFRL.layout.IsEditing() or fxDragging or GetTime() < fxSuppressUntil then return end
        local off = ReadFx()
        if off == nil then return end
        pcall(SetCVar, "noSpellEffects", off and "0" or "1")
        PaintFx()
        if GameTooltip and GameTooltip:IsOwned(fx) then FxTooltip() end
    end)
    fx:SetScript("OnEnter", FxTooltip)
    fx:SetScript("OnLeave", HideFxTooltip)
    fx:SetScript("OnShow", PaintFx)
    fx:SetScript("OnHide", function()
        StopFxDrag(false)
        HideFxTooltip()
    end)
    Register(fx)
    RestoreFxPosition()
    HookScript(Minimap, "OnShow", PaintFx)
    HookScript(Minimap, "OnHide", function()
        StopFxDrag(false)
        HideFxTooltip()
    end)
    DFRL.layout.ListenVisibility("minimap", function()
        if Visible() then
            PaintFx()
        else
            StopFxDrag(false)
            HideFxTooltip()
        end
    end)
    DFRL.locale.Listen(function()
        if Visible() and GameTooltip and GameTooltip:IsOwned(fx) then FxTooltip() end
    end)
    PaintFx()

    local controller = CreateFrame("Frame")
    controller:RegisterEvent("ADDON_LOADED")
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:RegisterEvent("CVAR_UPDATE")
    controller:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            StopDrag()
            HideTooltip()
            StopFxDrag(false)
            HideFxTooltip()
            if fx:IsShown() then fx:Hide() end
        elseif event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            RestoreFxPosition()
            PaintFx()
            DiscoverButtons()
        elseif event == "ADDON_LOADED" then
            if arg1 == "SurvivorsDragonUi" then RestoreFxPosition() end
            DiscoverButtons()
        elseif event == "CVAR_UPDATE" and type(arg1) == "string" and string.lower(arg1) == "nospelleffects" then
            PaintFx()
            if Visible() and GameTooltip and GameTooltip:IsOwned(fx) then FxTooltip() end
        end
    end)
    DiscoverButtons()
end)
