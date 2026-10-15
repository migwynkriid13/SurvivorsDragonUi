DFRL:NewMod("Cast", 1, function()
    -- Casting bars are intentionally omitted from this HUD.
    for _, name in ipairs({ "CastingBarFrame", "PetCastingBarFrame", "DFRLCastbar" }) do
        local frame = _G[name]
        if frame then
            KillFrame(frame)
            frame.Show = frame.Hide
            frame:SetScript("OnShow", function() this:Hide() end)
        end
    end
    DFRL.castbar = nil
end)
