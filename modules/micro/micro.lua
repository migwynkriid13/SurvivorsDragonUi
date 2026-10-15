DFRL:NewMod("Micro", 1, function()
    local path = DFRL:GetInfoOrCons("tex") .. "micromenu\\color_micro\\"
    local container = CreateFrame("Frame", "DFRLMicroMenuContainer", UIParent)
    container:SetWidth(66)
    container:SetHeight(30)
    container:SetScale(0.85)
    container:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -15, 15)
    local entries = {
        { "CharacterMicroButton", "character" },
        { "TalentMicroButton", "talents" },
        { "MainMenuMicroButton", "eye" },
    }
    local previous
    for _, entry in ipairs(entries) do
        local button = _G[entry[1]]
        if button then
            button:SetParent(container)
            button:ClearAllPoints()
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", 3, 0)
            else
                button:SetPoint("LEFT", container, "LEFT", 0, 0)
            end
            button:SetWidth(20)
            button:SetHeight(30)
            if entry[1] == "CharacterMicroButton" then
                local atlas = DFRL:GetInfoOrCons("tex") .. "micromenu\\uimicromenu2x.tga"
                button:SetNormalTexture(atlas)
                button:GetNormalTexture():SetTexCoord(2 / 256, 37 / 256, 324 / 512, 372 / 512)
                button:SetPushedTexture(atlas)
                button:GetPushedTexture():SetTexCoord(82 / 256, 116 / 256, 216 / 512, 264 / 512)
                button:SetHighlightTexture(atlas)
                button:GetHighlightTexture():SetTexCoord(82 / 256, 116 / 256, 216 / 512, 264 / 512)
            else
                for _, state in ipairs({ { "Normal", "regular" }, { "Pushed", "faded" }, { "Highlight", "highlight" } }) do
                    button["Set" .. state[1] .. "Texture"](button, path .. entry[2] .. "-" .. state[2] .. ".tga")
                    local texture = button["Get" .. state[1] .. "Texture"](button)
                    if texture then texture:SetTexCoord(36 / 128, 86 / 128, 29 / 128, 98 / 128) end
                end
            end
            if entry[1] == "MainMenuMicroButton" then
                button.tooltipText = "Main Menu"
                button:SetScript("OnClick", function() ToggleGameMenu(true) end)
            end
            button:Show()
            previous = button
        end
    end
    for _, name in ipairs({
        "SpellbookMicroButton",
        "WorldMapMicroButton",
        "QuestLogMicroButton",
        "SocialsMicroButton",
        "HelpMicroButton",
    }) do
        PermanentlyDisableFrame(_G[name])
    end
    if MicroButtonPortrait then MicroButtonPortrait:Hide() end
    DFRL.microMenuContainer = container
    DFRL.layout.Register("microMenu", container)
end)
