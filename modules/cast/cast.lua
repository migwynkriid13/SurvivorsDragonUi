DFRL:NewMod("Cast", 1, function()
    local string = string
    local FAILED = FAILED
    local GetTime = GetTime
    local INTERRUPTED = INTERRUPTED

    local Setup = {
        frame       = nil,
        barTexture  = nil,
        spark       = nil,
        flashTex    = nil,
        backdrop    = nil,
        borderframe = nil,
        dropshadow  = nil,
        text        = nil,
        timeText    = nil,

        visuals = {
            width            = 200,
            height           = 16,
            bgTexture        = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\castbar\\CastingBarBackground.blp",
            barTexture       = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\castbar\\CastingBarStandard3.tga",
            dropshadow       = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\castbar\\CastingBarFrameDropShadow.blp",
            flashTex         = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\castbar\\CastingBarFrameFlash.tga",
            borderframe      = "Interface\\AddOns\\SurvivorsDragonUi\\media\\tex\\castbar\\CastingBarFrame.blp",
            spark            = "Interface\\CastingBar\\UI-CastingBar-Spark",
            barColor         = { r = 1, g = 0.82, b = 0 },
            alphaSpeed       = 3.0,
            flashSpeed       = 5.0,
            holdTimeDuration = 1,
            font             = "DEFAULT",
            fontSizeName     = 12,
            fontSizeTime     = 12,
            textColorName    = { r = 1, g = 1, b = 1 },
            textColorTime    = { r = 1, g = 1, b = 1 },
        },

        state = {
            casting    = false,
            channeling = false,
            fadeOut    = false,
            flash      = false,
            holdTime   = 0,
            startTime  = 0,
            maxValue   = 0,
            endTime    = 0,
            duration   = 0,
            flashAlpha = 0,
            currentProgress = 0, -- 0 to 1
        },
    }

    function Setup:Castbar(parent)
        CastingBarFrame:Hide()
        CastingBarFrame:SetScript("OnEvent", nil)
        CastingBarFrame:SetScript("OnUpdate", nil)

        local f = CreateFrame("Frame", "DFRLCastbar", parent or UIParent)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        f:SetHeight(self.visuals.height)
        f:SetWidth(self.visuals.width)
        f:Hide()

        _G.DFRL.castbar = f

        local bd = f:CreateTexture(nil, "BACKGROUND", 7)
        bd:SetAllPoints(f)
        bd:SetTexture(self.visuals.bgTexture)
        self.backdrop = bd

        local bar = f:CreateTexture(nil, "BORDER")
        bar:SetPoint("LEFT", f, "LEFT", 0, 0)
        bar:SetHeight(self.visuals.height)
        bar:SetWidth(0)
        bar:SetTexture(self.visuals.barTexture)
        bar:SetVertexColor(self.visuals.barColor.r, self.visuals.barColor.g, self.visuals.barColor.b)
        self.barTexture = bar

        _G.DFRL.castbar.bar = bar

        local borderFrame = f:CreateTexture(nil, "ARTWORK")
        borderFrame:SetAllPoints(f)
        borderFrame:SetTexture(self.visuals.borderframe)
        self.borderframe = borderFrame

        local dropshadow = f:CreateTexture(nil, "BACKGROUND", 1)
        dropshadow:SetWidth(self.visuals.width + 1)
        dropshadow:SetHeight(self.visuals.height + 9)
        dropshadow:SetPoint("TOP", f, "BOTTOM", 0, 5)
        dropshadow:SetTexture(self.visuals.dropshadow)
        self.dropshadow = dropshadow

        -- spark
        do
            local spark = f:CreateTexture(nil, "OVERLAY")
            spark:SetHeight(self.visuals.height + 15)
            spark:SetWidth(25)
            spark:SetTexture(self.visuals.spark)
            spark:SetBlendMode("ADD")
            spark:Hide()
            self.spark = spark

        end

        -- flash
        do
            local flash = f:CreateTexture(nil, "OVERLAY")
            flash:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 5)
            flash:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, -5)
            flash:SetTexture(self.visuals.flashTex)
            self.flashTex = flash
        end

        -- spellname
        local ts = f:CreateFontString(nil, "OVERLAY")
        ts:SetFont(self.visuals.font, self.visuals.fontSizeName, "OUTLINE")
        ts:SetPoint("LEFT", f, "LEFT", 5, -16)
        ts:SetTextColor(self.visuals.textColorName.r, self.visuals.textColorName.g, self.visuals.textColorName.b)
        self.text = ts

        -- time
        local tt = f:CreateFontString(nil, "OVERLAY")
        tt:SetFont(self.visuals.font, self.visuals.fontSizeTime, "OUTLINE")
        tt:SetPoint("RIGHT", f, "RIGHT", -5, -16)
        tt:SetTextColor(self.visuals.textColorTime.r, self.visuals.textColorTime.g, self.visuals.textColorTime.b)
        self.timeText = tt

        -- events
        f:RegisterEvent("SPELLCAST_STOP")
        f:RegisterEvent("SPELLCAST_START")
        f:RegisterEvent("SPELLCAST_FAILED")
        f:RegisterEvent("SPELLCAST_DELAYED")
        f:RegisterEvent("SPELLCAST_INTERRUPTED")
        f:RegisterEvent("SPELLCAST_CHANNEL_STOP")
        f:RegisterEvent("SPELLCAST_CHANNEL_START")
        f:RegisterEvent("SPELLCAST_CHANNEL_UPDATE")

        f:SetScript("OnEvent", function()
            Setup:HandleEvent(event, arg1, arg2)
        end)

        f:SetScript("OnUpdate", function()
            Setup:OnUpdate(arg1)
        end)

        self.frame = f
    end

    function Setup:UpdateBarVisual(progress)
        progress = math.max(0, math.min(1, progress))
        local width = math.max(0.1, progress * self.visuals.width)
        self.barTexture:SetWidth(width)
        self.barTexture:SetTexCoord(0, progress, 0, 1)
        if progress > 0 and progress < 1 then
            self.spark:SetPoint("CENTER", self.frame, "LEFT", width, 0)
            self.spark:Show()
        else
            self.spark:Hide()
        end
    end

    function Setup:OnUpdate(elapsed)
        local s = self.state
        local c = self.visuals
        local now = GetTime()

        if s.casting then
            local targetProgress = (now - s.startTime) / math.max(0.001, s.maxValue - s.startTime)
            if targetProgress > 1 then targetProgress = 1 end
            if targetProgress < 0 then targetProgress = 0 end

            local progressDiff = targetProgress - s.currentProgress
            local step = elapsed * 2

            -- handle both forward progress and pushback
            if progressDiff > 0 then
                s.currentProgress = s.currentProgress + step
                if s.currentProgress > targetProgress then
                    s.currentProgress = targetProgress
                end
            elseif progressDiff < 0 then
                -- pushback occurred - move bar backward quickly
                s.currentProgress = s.currentProgress + (step * progressDiff * 12)
                if s.currentProgress < targetProgress then
                    s.currentProgress = targetProgress
                end
            end

            self:UpdateBarVisual(s.currentProgress)
            if self.flashTex then self.flashTex:Hide() end

        elseif s.channeling then
            local timeLeft = s.endTime - now
            if timeLeft <= 0 then
            s.channeling = false
            s.fadeOut = true
            s.currentProgress = 0
            self:UpdateBarVisual(0)
            return
            end

            local targetProgress = timeLeft / math.max(0.001, s.endTime - s.startTime)
            if targetProgress < 0 then targetProgress = 0 end
            if targetProgress > 1 then targetProgress = 1 end

            local progressDiff = targetProgress - s.currentProgress
            local step = elapsed * 2

            if progressDiff < 0 then
            s.currentProgress = s.currentProgress + step * progressDiff
            if s.currentProgress < targetProgress then
                s.currentProgress = targetProgress
            end
            end

            self:UpdateBarVisual(s.currentProgress)
            if self.flashTex then self.flashTex:Hide() end

        elseif now < s.holdTime then
            -- hold state - no fade yet
            return

        elseif s.flash and self.flashTex then
            s.flashAlpha = s.flashAlpha + (c.flashSpeed * elapsed)
            if s.flashAlpha > 1 then s.flashAlpha = 1 end

            self.flashTex:SetAlpha(s.flashAlpha)
            self.flashTex:Show()

            if s.flashAlpha >= 1 then
                s.flash = false
                s.fadeOut = true
            end


        elseif s.fadeOut then
            local currentAlpha = self.frame:GetAlpha()
            local newAlpha = currentAlpha - (c.alphaSpeed * elapsed)

            if newAlpha <= 0 then
            s.fadeOut = false
            self.frame:Hide()
            self.frame:SetAlpha(1)
            if self.flashTex then
                self.flashTex:SetAlpha(0)
                self.flashTex:Hide()
            end
            else
            self.frame:SetAlpha(newAlpha)
            end
        end

        -- update time during cast/channel
        if s.casting or s.channeling then
            local remaining
            if s.casting then
            remaining = s.maxValue - now
            else
            remaining = s.endTime - now
            end

            if remaining < 0 then remaining = 0 end

            -- time formatting
            local timeStr
            if remaining >= 10 then
                timeStr = string.format("%.0f", remaining)
            elseif remaining >= 1 then
                timeStr = string.format("%.1f", remaining)
            else
                timeStr = string.format("%.2f", remaining)
            end

            self.timeText:SetText(timeStr)
        end
    end

    function Setup:HandleEvent(event, arg1, arg2)

        local s = self.state
        local c = self.visuals

        if event == "SPELLCAST_START" then
            s.startTime = GetTime()
            s.maxValue = s.startTime + (arg2 / 1000)
            s.currentProgress = 0

            self.barTexture:SetVertexColor(c.barColor.r, c.barColor.g, c.barColor.b)
            self:UpdateBarVisual(0)

            self.text:SetText(arg1)
            s.holdTime = 0
            s.casting = true
            s.channeling = false
            s.fadeOut = false
            s.flash = false
            s.flashAlpha = 0
            self.flashTex:SetVertexColor(1, 1, 1) -- reset to white
            self.frame:SetAlpha(1)
            self.frame:Show()

        elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_CHANNEL_STOP" then
            if self.frame:IsShown() then
            -- complete the bar instantly like blizz
            s.currentProgress = 1
            self:UpdateBarVisual(1)
            self.barTexture:SetVertexColor(0, 1, 0)

            if event == "SPELLCAST_STOP" then
                s.casting = false
            else
                s.channeling = false
            end

            s.flash = true
            s.flashAlpha = 0

            self.flashTex:SetVertexColor(0, 1, 0)
            self.flashTex:Show()

            s.fadeOut = true
            end

        elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
            if self.frame:IsShown() and not s.channeling then
            s.currentProgress = 1
            self:UpdateBarVisual(1)
            self.barTexture:SetVertexColor(1, 0, 0)

            if event == "SPELLCAST_INTERRUPTED" then
                self.flashTex:SetVertexColor(1, 0, 0)
            else
                self.flashTex:SetVertexColor(0, 1, 0)
            end

            if event == "SPELLCAST_FAILED" then
                self.text:SetText(FAILED)
            else
                self.text:SetText(INTERRUPTED)
            end

            s.casting = false
            s.fadeOut = true
            s.holdTime = GetTime() + c.holdTimeDuration
            end

        elseif event == "SPELLCAST_DELAYED" then
            if self.frame:IsShown() then
            s.startTime = s.startTime + (arg1 / 1000)
            s.maxValue = s.maxValue + (arg1 / 1000)
            end

        elseif event == "SPELLCAST_CHANNEL_START" then
            s.startTime = GetTime()
            s.duration = arg1 / 1000
            s.endTime = s.startTime + s.duration
            s.currentProgress = 1 -- channeling starts full

            self.barTexture:SetVertexColor(c.barColor.r, c.barColor.g, c.barColor.b)
            self:UpdateBarVisual(1)

            self.text:SetText(arg2)
            s.holdTime = 0
            s.casting = false
            s.channeling = true
            s.fadeOut = false
            s.flash = false
            s.flashAlpha = 0
            self.frame:SetAlpha(1)
            self.frame:Show()

        elseif event == "SPELLCAST_CHANNEL_UPDATE" then
            if self.frame:IsShown() then
            local origDur = s.endTime - s.startTime
            s.endTime = GetTime() + (arg1 / 1000)
            s.startTime = s.endTime - origDur
            end
        end
    end

    Setup:Castbar()
end)
