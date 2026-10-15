DFRL:NewMod("Cast", 1, function()
    -- Casting bars are intentionally omitted from this HUD.
    for _, name in ipairs({ "CastingBarFrame", "PetCastingBarFrame", "DFRLCastbar" }) do
        PermanentlyDisableFrame(_G[name])
    end
    DFRL.castbar = nil
end)
