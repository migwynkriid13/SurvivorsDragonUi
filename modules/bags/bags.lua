DFRL:NewMod("Bags", 1, function()
    PermanentlyDisableFrame(MainMenuBarBackpackButton)
    for i = 0, 3 do
        PermanentlyDisableFrame(_G["CharacterBag" .. i .. "Slot"])
    end
    PermanentlyDisableFrame(KeyRingButton)
end)
