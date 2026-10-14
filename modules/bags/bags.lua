DFRL:NewMod("Bags", 1, function()
    local function HideUnusedButton(button)
        if not button then return end
        KillFrame(button)
        -- Stock bag updates may try to show these buttons again.
        button.Show = button.Hide
        button:SetScript("OnShow", function() this:Hide() end)
    end

    HideUnusedButton(MainMenuBarBackpackButton)
    for i = 0, 3 do
        HideUnusedButton(_G["CharacterBag" .. i .. "Slot"])
    end
    HideUnusedButton(KeyRingButton)
end)
