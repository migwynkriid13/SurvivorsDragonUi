DFRL:NewMod("AnimatedPortraits", 2, function()
    local entries = {}
    local inWorld = UnitExists("player") and true or false
    -- Keep the legacy saved key; the choice now covers all three portraits.
    local portraitsHidden = DFRL.display.Get("hidePortraits")
    local portraits3D = DFRL.display.Get("playerPortrait3D") and not portraitsHidden

    local function RestoreStill(entry)
        local alpha = portraitsHidden and 0 or entry.stillAlpha
        if entry.portrait:GetAlpha() ~= alpha then entry.portrait:SetAlpha(alpha) end
    end

    local function DropCopy(entry)
        entry.bound = false
        RestoreStill(entry)
        if entry.model and not entry.copyCleared then entry.copyCleared = pcall(entry.model.ClearModel, entry.model) end
    end

    local function Release(entry)
        DropCopy(entry)
        if entry.model and entry.model:IsShown() then entry.model:Hide() end
    end

    local function PlaceViewport(entry)
        local width, height = T.GetLocalSize(entry.portrait)
        if type(width) ~= "number" or type(height) ~= "number" or width <= 2 or height <= 2 then
            entry.viewportReady = false
            return
        end
        if entry.viewportReady and T.NearlyEqual(entry.width, width) and T.NearlyEqual(entry.height, height) then
            return
        end
        local diameter = math.min(width, height)
        -- Every corner of this native rectangular viewport stays inside the
        -- portrait circle, with one unit of diagonal clearance for the rim.
        local side = (diameter - 2) / math.sqrt(2)
        entry.model:SetWidth(side)
        entry.model:SetHeight(side)
        for _, strip in ipairs(entry.backdrop) do
            local y1, y2 = (strip.index - 1) / 24, strip.index / 24
            local edge = math.max(math.abs(2 * y1 - 1), math.abs(2 * y2 - 1))
            strip.texture:SetWidth(diameter * math.sqrt(1 - edge * edge))
            strip.texture:SetHeight(diameter / 24)
            strip.texture:SetPoint("CENTER", entry.portrait, "CENTER", 0, diameter * (0.5 - (y1 + y2) / 2))
        end
        entry.width, entry.height, entry.viewportReady = width, height, true
    end

    local function Bind(entry)
        if entry.binding or not entry.supported then return end
        if not portraits3D or not inWorld or not entry.owner:IsVisible() or not UnitExists(entry.unit) then
            Release(entry)
            return
        end
        entry.binding = true
        entry.bound = false
        entry.copyCleared = false
        RestoreStill(entry)
        PlaceViewport(entry)
        -- SetUnit captures this token's current identity. Clear the previous copy first:
        -- a missing replacement must never leave the previous target in the portrait.
        local success = pcall(function()
            entry.model:ClearModel()
            entry.model:SetUnit(entry.unit)
            if not portraits3D or not inWorld or not UnitExists(entry.unit) then
                Release(entry)
                return
            end
            entry.bound = true
            entry.model:Show()
            -- Request camera 0 (the standard character headshot) after Show, which may
            -- request another copy. BeNilla #1849 holds this for a pending copy;
            -- older renderers can retain their body view despite accepting it.
            if type(entry.model.SetCamera) == "function" then pcall(entry.model.SetCamera, entry.model, 0) end
        end)
        entry.binding = false
        if not success then
            entry.supported = false
            Release(entry)
        end
    end

    local function CreatePortrait(owner, portrait, unit)
        if not owner or not portrait then return end
        local entry = {
            owner = owner,
            portrait = portrait,
            unit = unit,
            stillAlpha = portrait:GetAlpha(),
        }
        table.insert(entries, entry)
        RestoreStill(entry)
        local success, model = pcall(CreateFrame, "PlayerModel", nil, owner)
        if not success or not model then return end
        entry.model = model
        if type(model.SetUnit) ~= "function" or type(model.ClearModel) ~= "function" then
            model:Hide()
            return
        end

        -- The native viewport is rectangular. Contain it inside the portrait
        -- circle; the client still supplies its authored camera and animation.
        success = pcall(function()
            model:Hide()
            model:SetPoint("CENTER", portrait, "CENTER", 0, 0)
            -- ARTWORK at the portrait's level stays above the extended health
            -- fill and below the existing gold OVERLAY artwork.
            model:SetFrameLevel(portrait:GetParent():GetFrameLevel())
            model:SetAlpha(1)
            model:EnableMouse(false)
            -- Passive native texture strips form a round dark backing without
            -- a square outside the portrait or a new bundled image.
            entry.backdrop = {}
            for index = 2, 23 do
                local texture = model:CreateTexture(nil, "BACKGROUND")
                texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                texture:SetVertexColor(0.015, 0.018, 0.022, 0.72)
                table.insert(entry.backdrop, { texture = texture, index = index })
            end
            PlaceViewport(entry)
            model:SetScript("OnHide", function() DropCopy(entry) end)
            model:SetScript("OnShow", function() Bind(entry) end)
            model:SetScript("OnUpdate", function()
                if not model:IsVisible() then return end
                -- Ordinary updates precede model paint callbacks. Restore the still
                -- every frame; only a current copy's callback may replace it again.
                -- This also recovers when a client has the methods but no renderer.
                PlaceViewport(entry)
                RestoreStill(entry)
                if entry.bound and (not portraits3D or not inWorld or not UnitExists(entry.unit)) then
                    Release(entry)
                end
            end)
            model:SetScript("OnUpdateModel", function()
                -- This is evidence of a copy and a drawable viewport, not a public
                -- promise that every GPU resource has finished displaying.
                if
                    portraits3D
                    and entry.bound
                    and entry.viewportReady
                    and not entry.binding
                    and inWorld
                    and UnitExists(entry.unit)
                    and model:IsVisible()
                then
                    portrait:SetAlpha(0)
                end
            end)
        end)
        if not success then
            Release(entry)
            return
        end
        entry.supported = true
        HookScript(owner, "OnShow", function()
            if not model:IsShown() then Bind(entry) end
        end)
        -- A late player-border initialization can raise the still after this
        -- copy was created. The border may align its level without rebinding it.
        owner.sduiPortraitModel = model

        -- If the player's border has not initialized yet, keep its stock gold
        -- sheet above this copy. A later border build aligns both at its level.
        if unit == "player" and PlayerFrameTexture and PlayerFrameTexture:GetParent() == owner then
            local foreground = CreateFrame("Frame", nil, owner)
            foreground:SetAllPoints(owner)
            foreground:SetFrameLevel(owner:GetFrameLevel() + 1)
            foreground:EnableMouse(false)
            PlayerFrameTexture:SetParent(foreground)
        end
        Bind(entry)
    end

    CreatePortrait(PlayerFrame, PlayerFrame and PlayerFrame.portrait, "player")
    CreatePortrait(TargetFrame, TargetFrame and TargetFrame.portrait, "target")
    CreatePortrait(TargetofTargetFrame, TargetofTargetPortrait, "targettarget")

    DFRL.display.Listen(function()
        local hidden = DFRL.display.Get("hidePortraits")
        local enabled = DFRL.display.Get("playerPortrait3D") and not hidden
        if enabled == portraits3D and hidden == portraitsHidden then return end
        portraits3D, portraitsHidden = enabled, hidden
        for _, entry in ipairs(entries) do
            if enabled then
                Bind(entry)
            else
                Release(entry)
            end
        end
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LEAVING_WORLD")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("UNIT_TARGET")
    events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    events:RegisterEvent("UNIT_INVENTORY_CHANGED")
    events:SetScript("OnEvent", function()
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
            inWorld = false
            for _, entry in ipairs(entries) do
                Release(entry)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            inWorld = true
            for _, entry in ipairs(entries) do
                Bind(entry)
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            for _, entry in ipairs(entries) do
                if entry.unit ~= "player" then Bind(entry) end
            end
        elseif event == "UNIT_TARGET" then
            if arg1 == "target" then
                for _, entry in ipairs(entries) do
                    if entry.unit == "targettarget" then Bind(entry) end
                end
            end
        elseif arg1 then
            for _, entry in ipairs(entries) do
                if arg1 == entry.unit or UnitIsUnit(arg1, entry.unit) then Bind(entry) end
            end
        end
    end)

    if type(_G.ReloadUI) == "function" then
        local reloadUI = _G.ReloadUI
        _G.ReloadUI = function()
            -- Retire copies before downstream edit cleanup can discard drafts
            -- and before the native reload can serialize confirmed preferences.
            inWorld = false
            for _, entry in ipairs(entries) do
                Release(entry)
            end
            return reloadUI()
        end
    end
end)
