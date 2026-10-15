setfenv(1, DFRL:GetEnv())

function KillFrame(frame)
    if not frame then return end
    frame:Hide()
    if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
    for _, script in ipairs({
        "OnShow",
        "OnHide",
        "OnEnter",
        "OnLeave",
        "OnMouseDown",
        "OnMouseUp",
        "OnClick",
        "OnDragStart",
        "OnDragStop",
        "OnUpdate",
        "OnEvent",
    }) do
        pcall(function() frame:SetScript(script, nil) end)
    end
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
end

function HideFrameTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then region:Hide() end
    end
end

function HookScript(frame, script, handler)
    if not frame then return end
    local previous = frame:GetScript(script)
    frame:SetScript(script, function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
        if previous then previous(a1, a2, a3, a4, a5, a6, a7, a8, a9) end
        handler(a1, a2, a3, a4, a5, a6, a7, a8, a9)
    end)
end

function hooksecurefunc(name, handler)
    local previous = _G[name]
    if type(previous) ~= "function" then return end
    _G[name] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        previous(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        handler(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    end
end
