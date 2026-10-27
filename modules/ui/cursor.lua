-- Cursor artwork copyright Blizzard Entertainment. The selected UICursor2x
-- gauntlet is from client build 10.0.0 (45454), mirrored by Gethe/wow-ui-textures
-- at e80e3278cc833c89e1f3fc79557b68315d750935. See third_party/Cursor-ARTWORK.md.
DFRL:NewMod("Cursor", 1, function()
    local setCursor, resetCursor = _G.SetCursor, _G.ResetCursor
    if type(setCursor) ~= "function" or type(resetCursor) ~= "function" then return end
    local isMouselooking = type(_G.IsMouselooking) == "function" and _G.IsMouselooking

    local path = DFRL:GetInfoOrCons("tex") .. "cursor\\Point.blp"
    local active, applying, retryAt = true, false, nil

    local function ApplyCursor()
        if not active or applying then return end
        if isMouselooking and isMouselooking() then return end
        if retryAt and GetTime() < retryAt then return end

        applying = true
        local ok, result = pcall(setCursor, path)
        applying = false
        if not ok then
            active = false
            resetCursor()
            geterrorhandler()("Cursor: " .. tostring(result))
            return
        end
        retryAt = not result and GetTime() + 1 or nil
    end

    -- Preserve the original arguments, errors and complete return tuple. Native
    -- cursor calls still run, then the requested hand replaces their appearance.
    local function CompleteCursorCall(...)
        ApplyCursor()
        return unpack(arg)
    end

    _G.SetCursor = function(...) return CompleteCursorCall(setCursor(unpack(arg))) end
    _G.ResetCursor = function(...) return CompleteCursorCall(resetCursor(unpack(arg))) end

    -- The existing UI monitor calls this before its health-warning throttle.
    -- The world classifier overwrites the displayed mode each frame. Reasserting
    -- this cached native cursor is necessary even when its artwork is unchanged.
    DFRL.cursor = { Update = ApplyCursor }

    local controller = CreateFrame("Frame")
    controller:RegisterEvent("PLAYER_ENTERING_WORLD")
    controller:RegisterEvent("PLAYER_LEAVING_WORLD")
    controller:RegisterEvent("PLAYER_LOGOUT")
    controller:SetScript("OnEvent", function()
        active = event == "PLAYER_ENTERING_WORLD"
        retryAt = nil
        if active then
            ApplyCursor()
        else
            resetCursor()
        end
    end)
    ApplyCursor()
end)
