DFRL:NewMod("AnimatedPortraits", 2, function()
    local entries = {}
    local inWorld = UnitExists("player") and true or false

    local function RestoreStill(entry) entry.portrait:SetAlpha(entry.stillAlpha) end

    local function DropCopy(entry)
        entry.bound = false
        RestoreStill(entry)
        if entry.model then pcall(entry.model.ClearModel, entry.model) end
    end

    local function Release(entry)
        DropCopy(entry)
        if entry.model then entry.model:Hide() end
    end

    local function Bind(entry)
        if entry.binding or not entry.supported then return end
        if not inWorld or not UnitExists(entry.unit) then
            Release(entry)
            return
        end
        entry.binding = true
        entry.bound = false
        RestoreStill(entry)
        -- SetUnit captures this token's current identity. Clear the previous copy first:
        -- a missing replacement must never leave the previous target in the portrait.
        local success = pcall(function()
            entry.model:ClearModel()
            entry.model:SetUnit(entry.unit)
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
        local success, model = pcall(CreateFrame, "PlayerModel", nil, owner)
        if not success or not model then return end
        entry.model = model
        if type(model.SetUnit) ~= "function" or type(model.ClearModel) ~= "function" then
            model:Hide()
            return
        end

        -- Keep the native rectangular viewport at the existing portrait's bounds.
        -- The client supplies its authored camera and animation; no guessed zoom,
        -- model offsets, circular clipping or animation timers are substituted here.
        success = pcall(function()
            model:Hide()
            model:SetAllPoints(portrait)
            -- ARTWORK at the portrait's level stays above the extended health
            -- fill and below the existing gold OVERLAY artwork.
            model:SetFrameLevel(portrait:GetParent():GetFrameLevel())
            model:SetAlpha(1)
            model:EnableMouse(false)
            model:SetScript("OnHide", function() DropCopy(entry) end)
            model:SetScript("OnShow", function() Bind(entry) end)
            model:SetScript("OnUpdate", function()
                -- Ordinary updates precede model paint callbacks. Restore the still
                -- every frame; only a current copy's callback may replace it again.
                -- This also recovers when a client has the methods but no renderer.
                RestoreStill(entry)
                if entry.bound and (not inWorld or not UnitExists(entry.unit)) then Release(entry) end
            end)
            model:SetScript("OnUpdateModel", function()
                -- This is evidence of a copy and a drawable viewport, not a public
                -- promise that every GPU resource has finished displaying.
                if entry.bound and not entry.binding and inWorld and UnitExists(entry.unit) and model:IsVisible() then
                    portrait:SetAlpha(0)
                end
            end)
        end)
        if not success then
            Release(entry)
            return
        end
        entry.supported = true
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
end)
