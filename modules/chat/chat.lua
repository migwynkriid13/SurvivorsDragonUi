DFRL:NewMod("Chat", 1, function()
    if ChatFrame1Tab then ChatFrame1Tab:SetClampedToScreen(true) end
    local path = DFRL:GetInfoOrCons("tex") .. "chat\\"
    local function SkinButton(button, texture)
        if not button then return end
        button:SetNormalTexture(path .. texture)
        button:SetHighlightTexture(path .. texture)
        button:SetPushedTexture(path .. texture)
        button:SetScale(0.8)
    end
    SkinButton(ChatFrameMenuButton, "chat_menu")
    for i = 1, NUM_CHAT_WINDOWS or 7 do
        SkinButton(_G["ChatFrame" .. i .. "UpButton"], "chat_up")
        SkinButton(_G["ChatFrame" .. i .. "DownButton"], "chat_down")
        SkinButton(_G["ChatFrame" .. i .. "BottomButton"], "chat_down_full")
        local frame = _G["ChatFrame" .. i]
        if frame then
            frame:SetFadeDuration(3)
            frame:SetTimeVisible(180)
        end
    end
end)
