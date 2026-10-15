DFRL:NewMod("Ui", 5, function()
    -- locals
    local UnitHealth = UnitHealth
    local UnitHealthMax = UnitHealthMax
    local sin = math.sin

    -- hide stuff
    do
        if PetPaperDollCloseButton then PetPaperDollCloseButton:Hide() end
        if SkillFrameCancelButton then SkillFrameCancelButton:Hide() end
    end

    -- close button
    do
        local closeButtonData = {
            { "CharacterFrame", "CharacterFrameCloseButton", -36, -16 },
            { "SpellBookFrame", "SpellBookCloseButton", -36, -15 },
            { "TalentFrame", "TalentFrameCloseButton", -36, -17 },
            { "QuestLogFrame", "QuestLogFrameCloseButton", -91, -15 },
            { "FriendsFrame", "FriendsFrameCloseButton", -36, -15 },
            { "HelpFrame", "HelpFrameCloseButton", -50, -10 },
            { "QuestFrame", "QuestFrameCloseButton", -34, -22 },
            { "GuildMemberDetailFrame", "GuildMemberDetailCloseButton", -10, -10 },
        }

        for i = 1, 5 do
            table.insert(closeButtonData, { "ContainerFrame" .. i, "ContainerFrame" .. i .. "CloseButton", -8, -8 })
        end

        local path = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\close_normal.tga"
        local pathpushed = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\close_pushed.tga"

        for _, data in ipairs(closeButtonData) do
            local frameName, buttonName, offsetX, offsetY = unpack(data)
            local frame = _G[frameName]
            local button = _G[buttonName]

            if button then
                button:SetNormalTexture(path)
                button:SetPushedTexture(pathpushed)
                button:SetHighlightTexture(path)
                button:SetWidth(17)
                button:SetHeight(17)
                button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", offsetX, offsetY)
            end
        end
    end

    -- questlog
    do
        local questLogFrame = QuestLogFrame
        if questLogFrame then
            local regions = { questLogFrame:GetRegions() }
            for _, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    if texture then
                        if texture == "Interface\\QuestFrame\\UI-QuestLog-Left" then
                            region:SetTexture("Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\questlog_left.tga")
                        elseif texture == "Interface\\QuestFrame\\UI-QuestLog-Right" then
                            region:SetTexture(
                                "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\questlog_right.tga"
                            )
                        end
                    end
                end
            end
        end
    end

    -- characterframe
    do
        local tex = {
            "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_top_left.tga",
            "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_top_right.tga",
            "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_bot_left.tga",
            "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_bot_right.tga",
        }

        local function ReplaceFrameTextures(frame)
            if not frame then return end
            frame:SetFrameStrata("MEDIUM")

            local regions = { frame:GetRegions() }
            local texIndex = 1
            for i = 1, table.getn(regions) do
                local r = regions[i]
                if r and r:IsObjectType("Texture") then
                    local name = r:GetName()
                    if not name or not string.find(name, "Portrait") then
                        r:ClearAllPoints()
                        if texIndex == 1 then
                            r:SetPoint("TOPLEFT", 0, 0)
                        elseif texIndex == 2 then
                            r:SetPoint("TOPLEFT", 256, 0)
                        elseif texIndex == 3 then
                            r:SetPoint("TOPLEFT", 0, -256)
                        elseif texIndex == 4 then
                            r:SetPoint("TOPLEFT", 256, -256)
                        end
                        r:SetTexture(tex[texIndex])
                        texIndex = texIndex + 1
                        if texIndex > table.getn(tex) then break end
                    end
                end
            end
        end

        HookScript(CharacterFrame, "OnShow", function() ReplaceFrameTextures(CharacterFrame) end)

        local subFrames = {
            "PaperDollFrame",
            "PetPaperDollFrame",
            "ReputationFrame",
            "SkillFrame",
            "HonorFrame",
        }

        for i = 1, table.getn(subFrames) do
            local f = getglobal(subFrames[i])
            if f then HookScript(f, "OnShow", function() ReplaceFrameTextures(f) end) end
        end
    end

    -- spellbookframe
    do
        local function ApplyCustomTextures(frame)
            if not frame then return end

            if not frame.customTopLeft then
                frame.customTopLeft = frame:CreateTexture(nil, "OVERLAY")
                frame.customTopLeft:SetTexture(
                    "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_top_left.tga"
                )
                frame.customTopLeft:SetWidth(256)
                frame.customTopLeft:SetHeight(256)
                frame.customTopLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 0)

                frame.customTopRight = frame:CreateTexture(nil, "OVERLAY")
                frame.customTopRight:SetTexture(
                    "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_top_right.tga"
                )
                frame.customTopRight:SetWidth(128)
                frame.customTopRight:SetHeight(256)
                frame.customTopRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, 0)

                frame.customBottomLeft = frame:CreateTexture(nil, "OVERLAY")
                frame.customBottomLeft:SetTexture(
                    "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_bot_left.tga"
                )
                frame.customBottomLeft:SetWidth(256)
                frame.customBottomLeft:SetHeight(256)
                frame.customBottomLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, -256)

                frame.customBottomRight = frame:CreateTexture(nil, "OVERLAY")
                frame.customBottomRight:SetTexture(
                    "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\paperdoll_bot_right.tga"
                )
                frame.customBottomRight:SetWidth(128)
                frame.customBottomRight:SetHeight(256)
                frame.customBottomRight:SetPoint("TOPLEFT", frame, "TOPLEFT", 253, -256)

                for i = 1, 12 do
                    local button = _G["SpellButton" .. i]
                    if button then
                        local bg = _G["SpellButton" .. i .. "Background"]
                        if bg then
                            bg:SetTexture("Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\ui\\spell_bg.tga")
                            bg:SetWidth(44)
                            bg:SetHeight(44)
                        end
                        _G["SpellButton" .. i .. "SubSpellName"]:SetTextColor(0.9, 0.9, 0.8, 0.6)
                    end
                end
            end
        end

        if SpellBookFrame then
            HookScript(SpellBookFrame, "OnShow", function() ApplyCustomTextures(SpellBookFrame) end)
        end

        ApplyCustomTextures(SpellBookFrame)
    end

    if QuestTimerFrame and UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", function()
            QuestTimerFrame:ClearAllPoints()
            QuestTimerFrame:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", -20, 40)
        end)
    end
    SetCVar("CameraDistanceMaxFactor", 3)

    local warning = CreateFrame("Frame", "DFRL_LowHpWarnFrame", UIParent)
    warning:SetAllPoints(UIParent)
    warning:SetFrameStrata("BACKGROUND")
    warning:Hide()
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local texture = warning:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        if side == "TOP" or side == "BOTTOM" then
            texture:SetPoint(side .. "LEFT", warning, side .. "LEFT", 0, 0)
            texture:SetPoint(side .. "RIGHT", warning, side .. "RIGHT", 0, 0)
            texture:SetHeight(64)
        else
            texture:SetPoint("TOP" .. side, warning, "TOP" .. side, 0, 0)
            texture:SetPoint("BOTTOM" .. side, warning, "BOTTOM" .. side, 0, 0)
            texture:SetWidth(64)
        end
        edges[side] = texture
    end
    local elapsed, pulse = 0, 0
    local monitor = CreateFrame("Frame")
    monitor:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed < 0.05 then return end
        local maximum = UnitHealthMax("player")
        local health = maximum > 0 and UnitHealth("player") / maximum * 100 or 100
        if health > 70 or UnitIsDeadOrGhost("player") then
            warning:Hide()
            pulse = 0
        else
            local intensity = math.max(0, math.min(1, (70 - health) / 70))
            pulse = pulse + elapsed * (1 + 7 * intensity)
            local alpha = 0.7 * (0.1 + 0.9 * intensity) * (0.3 + 0.7 * (sin(pulse) + 1) / 2)
            edges.TOP:SetGradientAlpha("VERTICAL", 1, 0, 0, 0, 1, 0, 0, alpha)
            edges.BOTTOM:SetGradientAlpha("VERTICAL", 1, 0, 0, alpha, 1, 0, 0, 0)
            edges.LEFT:SetGradientAlpha("HORIZONTAL", 1, 0, 0, alpha, 1, 0, 0, 0)
            edges.RIGHT:SetGradientAlpha("HORIZONTAL", 1, 0, 0, 0, 1, 0, 0, alpha)
            warning:Show()
        end
        elapsed = 0
    end)
end)
